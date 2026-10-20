import SwiftUI
import UIKit
import Metal
import Libmpv

struct MPVPlayerSurface: UIViewRepresentable {
    let url: URL
    let headers: [String: String]
    var muted: Bool = false
    var commandID: Int = 0
    var command: String?
    var onStatus: (String) -> Void
    var onError: (String) -> Void
    var onPlaybackUpdate: (Double, Double, Bool) -> Void = { _, _, _ in }

    func makeUIView(context: Context) -> MPVMetalView {
        let view = MPVMetalView()
        view.isUserInteractionEnabled = false
        context.coordinator.attach(view: view, url: url, headers: headers, muted: muted)
        context.coordinator.onStatus = onStatus
        context.coordinator.onError = onError
        context.coordinator.onPlaybackUpdate = onPlaybackUpdate
        return view
    }

    func updateUIView(_ uiView: MPVMetalView, context: Context) {
        uiView.isUserInteractionEnabled = false
        context.coordinator.onStatus = onStatus
        context.coordinator.onError = onError
        context.coordinator.onPlaybackUpdate = onPlaybackUpdate
        context.coordinator.setMuted(muted)
        context.coordinator.handleCommand(commandID: commandID, command: command)
    }

    static func dismantleUIView(_ uiView: MPVMetalView, coordinator: Coordinator) {
        coordinator.shutdown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var mpv: OpaquePointer?
        private weak var surface: MPVMetalView?
        private var started = false
        private var lastCommandID = 0
        private var isShuttingDown = false
        private let stateLock = NSLock()

        var onStatus: ((String) -> Void)?
        var onError: ((String) -> Void)?
        var onPlaybackUpdate: ((Double, Double, Bool) -> Void)?

        func attach(view: MPVMetalView, url: URL, headers: [String: String], muted: Bool) {
            stateLock.lock()
            guard !started else { stateLock.unlock(); return }
            started = true
            isShuttingDown = false
            stateLock.unlock()

            surface = view
            guard let handle = mpv_create() else {
                DispatchQueue.main.async { self.onError?("MPV could not create a playback instance.") }
                return
            }

            stateLock.lock()
            mpv = handle
            stateLock.unlock()

            _ = mpv_request_log_messages(handle, "warn")
            var layerPointer = Int64(Int(bitPattern: Unmanaged.passUnretained(view.metalLayer).toOpaque()))
            _ = mpv_set_option(handle, "wid", MPV_FORMAT_INT64, &layerPointer)
            let options: [(String, String)] = [
                ("vo", "gpu-next"), ("gpu-api", "vulkan"), ("gpu-context", "moltenvk"),
                ("hwdec", "videotoolbox"), ("ao", "audiounit"),
                ("audio-channels", "auto"), ("audio-fallback-to-null", "yes"),
                ("vulkan-swap-mode", "fifo"), ("vulkan-queue-count", "1"),
                ("vulkan-async-compute", "no"), ("vulkan-async-transfer", "no"),
                ("vulkan-disable-interop", "yes"), ("keep-open", "yes"),
                ("target-colorspace-hint", "yes"), ("tone-mapping", "auto"),
                ("hdr-compute-peak", "yes"), ("video-rotate", "no"),
                ("http-reconnect", "yes"), ("cache", "yes"), ("osd-level", "0")
            ]
            for (key, value) in options { _ = mpv_set_option_string(handle, key, value) }

            let initResult = mpv_initialize(handle)
            guard initResult >= 0 else {
                let message = String(cString: mpv_error_string(initResult))
                DispatchQueue.main.async { self.onError?("MPV initialization failed: \(message)") }
                stateLock.lock(); mpv = nil; stateLock.unlock()
                mpv_terminate_destroy(handle)
                return
            }

            applyRequestHeaders(headers, to: handle)
            setMuted(muted)
            _ = mpv_observe_property(handle, 1, "time-pos", MPV_FORMAT_DOUBLE)
            _ = mpv_observe_property(handle, 2, "duration", MPV_FORMAT_DOUBLE)
            _ = mpv_observe_property(handle, 3, "pause", MPV_FORMAT_FLAG)

            DispatchQueue.main.async { self.onStatus?("MPV initialized; waiting for video surface…") }
            view.onReadyForPlayback = { [weak self] in
                guard let self else { return }
                self.issue(["loadfile", url.absoluteString, "replace"])
                DispatchQueue.main.async { self.onStatus?("MPV opening stream…") }
            }

            view.setNeedsLayout()
            view.layoutIfNeeded()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.readEvents(handle: handle) }
        }

        func handleCommand(commandID: Int, command: String?) {
            stateLock.lock()
            let shouldSend = commandID != lastCommandID && !isShuttingDown
            if shouldSend { lastCommandID = commandID }
            stateLock.unlock()
            guard shouldSend, let command, !command.isEmpty else { return }
            issue(command.split(separator: " ").map(String.init))
        }

        private func issue(_ arguments: [String]) {
            var pointers: [UnsafePointer<CChar>?] = arguments.map { value in
                guard let pointer = strdup(value) else { return nil }
                return UnsafePointer(pointer)
            }
            pointers.append(nil)
            defer { for pointer in pointers { if let pointer { free(UnsafeMutablePointer(mutating: pointer)) } } }

            stateLock.lock()
            guard let handle = mpv, !isShuttingDown else { stateLock.unlock(); return }
            let result = pointers.withUnsafeMutableBufferPointer { buffer in mpv_command(handle, buffer.baseAddress) }
            stateLock.unlock()

            if result < 0 {
                let message = String(cString: mpv_error_string(result))
                DispatchQueue.main.async { self.onError?("MPV command failed: \(message)") }
            }
        }

        private func applyRequestHeaders(_ headers: [String: String], to handle: OpaquePointer) {
            let safeHeaders = headers.filter { !$0.key.contains("\r") && !$0.key.contains("\n") && !$0.value.contains("\r") && !$0.value.contains("\n") }
            let fields = safeHeaders
                .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
                .map { key, value in
                    let escapedValue = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ",", with: "\\,")
                    return "\(key): \(escapedValue)"
                }
                .joined(separator: ",")
            _ = mpv_set_property_string(handle, "http-header-fields", fields)
        }

        func setMuted(_ muted: Bool) {
            stateLock.lock()
            guard let handle = mpv, !isShuttingDown else { stateLock.unlock(); return }
            var value: Int32 = muted ? 1 : 0
            _ = mpv_set_property(handle, "mute", MPV_FORMAT_FLAG, &value)
            stateLock.unlock()
        }

        private func readEvents(handle: OpaquePointer) {
            while true {
                stateLock.lock(); let shuttingDown = isShuttingDown; stateLock.unlock()
                if shuttingDown { mpv_terminate_destroy(handle); return }

                guard let event = mpv_wait_event(handle, 0.25) else { continue }

                stateLock.lock(); let shouldStop = isShuttingDown; stateLock.unlock()
                if shouldStop { mpv_terminate_destroy(handle); return }

                if event.pointee.event_id == MPV_EVENT_NONE {
                    publishPlaybackState(handle)
                    continue
                }
                if event.pointee.event_id == MPV_EVENT_SHUTDOWN { mpv_terminate_destroy(handle); return }
                if event.pointee.event_id == MPV_EVENT_FILE_LOADED {
                    DispatchQueue.main.async { self.onStatus?("Stream loaded by MPV") }
                } else if event.pointee.event_id == MPV_EVENT_END_FILE {
                    if let data = event.pointee.data?.assumingMemoryBound(to: mpv_event_end_file.self).pointee, data.error < 0 {
                        let message = String(cString: mpv_error_string(data.error))
                        DispatchQueue.main.async { self.onError?("MPV couldn't play this stream: \(message)") }
                    }
                }
                publishPlaybackState(handle)
            }
        }

        private func publishPlaybackState(_ handle: OpaquePointer) {
            var time: Double = 0
            var duration: Double = 0
            var paused: Int32 = 1
            _ = mpv_get_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &time)
            _ = mpv_get_property(handle, "duration", MPV_FORMAT_DOUBLE, &duration)
            _ = mpv_get_property(handle, "pause", MPV_FORMAT_FLAG, &paused)
            guard time.isFinite, duration.isFinite else { return }
            DispatchQueue.main.async { self.onPlaybackUpdate?(max(0, time), max(0, duration), paused != 0) }
        }

        func shutdown() {
            stateLock.lock()
            guard let handle = mpv, !isShuttingDown else { stateLock.unlock(); return }
            isShuttingDown = true
            mpv = nil
            stateLock.unlock()
            surface?.onReadyForPlayback = nil
            mpv_wakeup(handle)
        }
    }
}

final class MPVMetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set { if Int(newValue.width) > 1 && Int(newValue.height) > 1 { super.drawableSize = newValue } }
    }

    override var wantsExtendedDynamicRangeContent: Bool {
        get { super.wantsExtendedDynamicRangeContent }
        set {
            if Thread.isMainThread { super.wantsExtendedDynamicRangeContent = newValue }
            else { DispatchQueue.main.sync { super.wantsExtendedDynamicRangeContent = newValue } }
        }
    }
}

final class MPVMetalView: UIView {
    override class var layerClass: AnyClass { MPVMetalLayer.self }
    var metalLayer: MPVMetalLayer { layer as! MPVMetalLayer }
    var onReadyForPlayback: (() -> Void)?
    private var didSignalReadyForPlayback = false

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        metalLayer.contentsScale = scale
        let size = CGSize(
            width: (bounds.width * scale).rounded(.toNearestOrAwayFromZero),
            height: (bounds.height * scale).rounded(.toNearestOrAwayFromZero)
        )
        if size.width > 1, size.height > 1, metalLayer.drawableSize != size { metalLayer.drawableSize = size }
        if !didSignalReadyForPlayback, window != nil, bounds.width > 1, bounds.height > 1 {
            didSignalReadyForPlayback = true
            onReadyForPlayback?()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.wantsExtendedDynamicRangeContent = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        isUserInteractionEnabled = false
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.wantsExtendedDynamicRangeContent = true
    }
}
