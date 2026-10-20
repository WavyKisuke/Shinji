import SwiftUI
import UIKit
import Libmpv

struct MPVPlayerSurface: UIViewRepresentable {
    let url: URL
    let headers: [String: String]
    var muted: Bool = false
    var commandID: Int = 0
    var command: [String]?
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
        private var lastCommandID = -1
        private var lastMuted: Bool?
        private var isShuttingDown = false
        private let stateLock = NSLock()
        private let mpvQueue = DispatchQueue(label: "shinji.mpv", qos: .userInitiated)

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
                publishError("MPV could not create a playback instance.")
                return
            }

            stateLock.lock()
            mpv = handle
            stateLock.unlock()

            configure(handle: handle, layer: view.metalLayer, headers: headers, muted: muted)

            let result = mpv_initialize(handle)
            guard result >= 0 else {
                let message = String(cString: mpv_error_string(result))
                publishError("MPV initialization failed: \(message)")
                shutdownHandle(handle)
                return
            }

            _ = mpv_observe_property(handle, 1, "time-pos", MPV_FORMAT_DOUBLE)
            _ = mpv_observe_property(handle, 2, "duration", MPV_FORMAT_DOUBLE)
            _ = mpv_observe_property(handle, 3, "pause", MPV_FORMAT_FLAG)

            mpv_set_wakeup_callback(
                handle,
                { context in
                    guard let context else { return }
                    let coordinator = Unmanaged<Coordinator>.fromOpaque(context).takeUnretainedValue()
                    coordinator.readEvents()
                },
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )

            view.onReadyForPlayback = { [weak self] in
                guard let self else { return }
                self.load(url: url)
            }

            publishStatus("MPV ready")
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        private func configure(handle: OpaquePointer, layer: MPVMetalLayer, headers: [String: String], muted: Bool) {
            _ = mpv_request_log_messages(handle, "warn")

            // This is the same simple iOS rendering path used by the public MPVKit demo:
            // gpu-next + Vulkan/MoltenVK + VideoToolbox on a CAMetalLayer.
            var layerReference: Int64 = Int64(Int(bitPattern: Unmanaged.passUnretained(layer).toOpaque()))
            _ = mpv_set_option(handle, "wid", MPV_FORMAT_INT64, &layerReference)
            _ = mpv_set_option_string(handle, "vo", "gpu-next")
            _ = mpv_set_option_string(handle, "gpu-api", "vulkan")
            _ = mpv_set_option_string(handle, "gpu-context", "moltenvk")
            _ = mpv_set_option_string(handle, "hwdec", "videotoolbox")
            _ = mpv_set_option_string(handle, "video-rotate", "no")
            _ = mpv_set_option_string(handle, "subs-match-os-language", "yes")
            _ = mpv_set_option_string(handle, "subs-fallback", "yes")
            _ = mpv_set_option_string(handle, "keep-open", "yes")
            _ = mpv_set_option_string(handle, "osd-level", "0")
            _ = mpv_set_option_string(handle, "http-reconnect", "yes")
            _ = mpv_set_option_string(handle, "cache", "yes")
            applyRequestHeaders(headers, to: handle)

            var muteValue: Int32 = muted ? 1 : 0
            _ = mpv_set_property(handle, "mute", MPV_FORMAT_FLAG, &muteValue)
            lastMuted = muted
        }

        private func applyRequestHeaders(_ headers: [String: String], to handle: OpaquePointer) {
            let safeHeaders = headers.filter {
                !$0.key.contains("\r") && !$0.key.contains("\n") &&
                !$0.value.contains("\r") && !$0.value.contains("\n")
            }
            let fields = safeHeaders
                .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
                .map { key, value in
                    let escaped = value
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: ",", with: "\\,")
                    return "\(key): \(escaped)"
                }
                .joined(separator: ",")
            _ = mpv_set_property_string(handle, "http-header-fields", fields)
        }

        private func load(url: URL) {
            mpvQueue.async { [weak self] in
                guard let self else { return }
                guard let handle = self.activeHandle() else { return }
                self.commandOnQueue(handle, ["loadfile", url.absoluteString, "replace"])
                self.publishStatus("Opening stream…")
            }
        }

        func handleCommand(commandID: Int, command: [String]?) {
            stateLock.lock()
            let shouldSend = commandID != lastCommandID && !isShuttingDown
            if shouldSend { lastCommandID = commandID }
            stateLock.unlock()

            guard shouldSend, let command, !command.isEmpty else { return }

            mpvQueue.async { [weak self] in
                guard let self, let handle = self.activeHandle() else { return }
                self.commandOnQueue(handle, command)
            }
        }

        func setMuted(_ muted: Bool) {
            stateLock.lock()
            guard lastMuted != muted, !isShuttingDown else { stateLock.unlock(); return }
            lastMuted = muted
            stateLock.unlock()

            mpvQueue.async { [weak self] in
                guard let self, let handle = self.activeHandle() else { return }
                var value: Int32 = muted ? 1 : 0
                let result = mpv_set_property(handle, "mute", MPV_FORMAT_FLAG, &value)
                if result < 0 {
                    self.publishError("MPV mute command failed: \(String(cString: mpv_error_string(result)))")
                }
            }
        }

        private func commandOnQueue(_ handle: OpaquePointer, _ arguments: [String]) {
            guard !arguments.isEmpty else { return }

            var cargs: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
            cargs.append(nil)
            defer {
                for pointer in cargs {
                    if let pointer { free(pointer) }
                }
            }

            let result = cargs.withUnsafeMutableBufferPointer { buffer in
                mpv_command(handle, buffer.baseAddress)
            }

            if result < 0 {
                publishError("MPV command failed: \(String(cString: mpv_error_string(result)))")
            }
        }

        private func readEvents() {
            mpvQueue.async { [weak self] in
                guard let self else { return }
                guard let handle = self.activeHandle() else { return }

                while true {
                    let event = mpv_wait_event(handle, 0)
                    guard let event else { break }

                    switch event.pointee.event_id {
                    case MPV_EVENT_NONE:
                        return

                    case MPV_EVENT_PROPERTY_CHANGE:
                        self.handlePropertyChange(event)

                    case MPV_EVENT_FILE_LOADED:
                        self.publishStatus("Stream loaded")
                        self.publishPlaybackState(handle)

                    case MPV_EVENT_END_FILE:
                        if let data = event.pointee.data?.assumingMemoryBound(to: mpv_event_end_file.self).pointee,
                           data.error < 0 {
                            self.publishError("MPV couldn't play this stream: \(String(cString: mpv_error_string(data.error)))")
                        }
                        self.publishPlaybackState(handle)

                    case MPV_EVENT_SHUTDOWN:
                        return

                    default:
                        self.publishPlaybackState(handle)
                    }
                }
            }
        }

        private func handlePropertyChange(_ event: UnsafePointer<mpv_event>) {
            guard let rawData = event.pointee.data else { return }
            let property = rawData.assumingMemoryBound(to: mpv_event_property.self).pointee
            guard let namePointer = property.name else { return }
            let name = String(cString: namePointer)

            switch name {
            case "time-pos", "duration", "pause":
                if let handle = activeHandle() {
                    publishPlaybackState(handle)
                }
            default:
                break
            }
        }

        private func publishPlaybackState(_ handle: OpaquePointer) {
            var time: Double = 0
            var duration: Double = 0
            var paused: Int32 = 1
            _ = mpv_get_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &time)
            _ = mpv_get_property(handle, "duration", MPV_FORMAT_DOUBLE, &duration)
            _ = mpv_get_property(handle, "pause", MPV_FORMAT_FLAG, &paused)

            let safeTime = time.isFinite ? max(0, time) : 0
            let safeDuration = duration.isFinite ? max(0, duration) : 0
            DispatchQueue.main.async { [weak self] in
                self?.onPlaybackUpdate?(safeTime, safeDuration, paused != 0)
            }
        }

        private func activeHandle() -> OpaquePointer? {
            stateLock.lock()
            let handle = mpv
            let shuttingDown = isShuttingDown
            stateLock.unlock()
            return shuttingDown ? nil : handle
        }

        private func shutdownHandle(_ handle: OpaquePointer) {
            stateLock.lock()
            isShuttingDown = true
            mpv = nil
            stateLock.unlock()
            mpv_terminate_destroy(handle)
        }

        func shutdown() {
            stateLock.lock()
            guard let handle = mpv, !isShuttingDown else { stateLock.unlock(); return }
            isShuttingDown = true
            mpv = nil
            stateLock.unlock()

            surface?.onReadyForPlayback = nil
            mpv_wakeup(handle)
            mpv_terminate_destroy(handle)
        }

        private func publishStatus(_ message: String) {
            DispatchQueue.main.async { [weak self] in self?.onStatus?(message) }
        }

        private func publishError(_ message: String) {
            DispatchQueue.main.async { [weak self] in self?.onError?(message) }
        }
    }
}

final class MPVMetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            if Int(newValue.width) > 1 && Int(newValue.height) > 1 {
                super.drawableSize = newValue
            }
        }
    }

    override var wantsExtendedDynamicRangeContent: Bool {
        get { super.wantsExtendedDynamicRangeContent }
        set {
            if Thread.isMainThread {
                super.wantsExtendedDynamicRangeContent = newValue
            } else {
                DispatchQueue.main.sync { super.wantsExtendedDynamicRangeContent = newValue }
            }
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
        if size.width > 1, size.height > 1, metalLayer.drawableSize != size {
            metalLayer.drawableSize = size
        }

        if !didSignalReadyForPlayback, window != nil, bounds.width > 1, bounds.height > 1 {
            didSignalReadyForPlayback = true
            onReadyForPlayback?()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    private func configureLayer() {
        backgroundColor = .black
        isUserInteractionEnabled = false
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.wantsExtendedDynamicRangeContent = true
    }
}
