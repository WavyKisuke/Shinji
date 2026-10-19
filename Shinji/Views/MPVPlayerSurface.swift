import SwiftUI
import UIKit
import Metal
import Libmpv

/// A lightweight libmpv surface based on the rendering setup used by Nuvio.
/// This is an original bridge rather than a copy of Nuvio's app-specific controller.
struct MPVPlayerSurface: UIViewRepresentable {
    let url: URL
    let headers: [String: String]
    var muted: Bool = false
    var onStatus: (String) -> Void
    var onError: (String) -> Void

    func makeUIView(context: Context) -> MPVMetalView {
        let view = MPVMetalView()
        context.coordinator.attach(view: view, url: url, headers: headers, muted: muted)
        context.coordinator.onStatus = onStatus
        context.coordinator.onError = onError
        return view
    }

    func updateUIView(_ uiView: MPVMetalView, context: Context) {
        context.coordinator.onStatus = onStatus
        context.coordinator.onError = onError
        context.coordinator.setMuted(muted)
    }

    static func dismantleUIView(_ uiView: MPVMetalView, coordinator: Coordinator) {
        coordinator.shutdown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var mpv: OpaquePointer?
        private weak var surface: MPVMetalView?
        private var started = false
        var onStatus: ((String) -> Void)?
        var onError: ((String) -> Void)?

        func attach(view: MPVMetalView, url: URL, headers: [String: String], muted: Bool) {
            guard !started else { return }
            started = true
            surface = view
            guard let handle = mpv_create() else {
                DispatchQueue.main.async { self.onError?("MPV could not create a playback instance.") }
                return
            }
            mpv = handle
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
                ("http-reconnect", "yes"), ("cache", "yes")
            ]
            for (key, value) in options { _ = mpv_set_option_string(handle, key, value) }
            let safeHeaders = headers.filter { !$0.key.contains("\r") && !$0.key.contains("\n") && !$0.value.contains("\r") && !$0.value.contains("\n") }
            if !safeHeaders.isEmpty {
                let fields = safeHeaders.map { "\($0.key): \($0.value)" }.joined(separator: ",")
                _ = mpv_set_option_string(handle, "http-header-fields", fields)
            }
            let initResult = mpv_initialize(handle)
            guard initResult >= 0 else {
                let message = String(cString: mpv_error_string(initResult))
                DispatchQueue.main.async { self.onError?("MPV initialization failed: \(message)") }
                mpv_terminate_destroy(handle)
                mpv = nil
                return
            }
            setMuted(muted)
            DispatchQueue.main.async { self.onStatus?("MPV player initialized; opening stream…") }
            issue(["loadfile", url.absoluteString, "replace"])
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.readEvents(handle: handle) }
        }

        private func issue(_ arguments: [String]) {
            guard let mpv else { return }
            var pointers: [UnsafePointer<CChar>?] = arguments.map { value in
                guard let pointer = strdup(value) else { return nil }
                return UnsafePointer(pointer)
            }
            pointers.append(nil)
            defer {
                for pointer in pointers {
                    if let pointer { free(UnsafeMutablePointer(mutating: pointer)) }
                }
            }
            let result = pointers.withUnsafeMutableBufferPointer { buffer in
                mpv_command(mpv, buffer.baseAddress)
            }
            if result < 0 {
                let message = String(cString: mpv_error_string(result))
                DispatchQueue.main.async { self.onError?("MPV command failed: \(message)") }
            }
        }

        func setMuted(_ muted: Bool) {
            guard let mpv else { return }
            var value: Int32 = muted ? 1 : 0
            _ = mpv_set_property(mpv, "mute", MPV_FORMAT_FLAG, &value)
        }

        private func readEvents(handle: OpaquePointer) {
            while true {
                guard mpv != nil else { return }
                guard let event = mpv_wait_event(handle, 0.25) else { continue }
                if event.pointee.event_id == MPV_EVENT_NONE { continue }
                if event.pointee.event_id == MPV_EVENT_SHUTDOWN { return }
                if event.pointee.event_id == MPV_EVENT_FILE_LOADED {
                    DispatchQueue.main.async { self.onStatus?("Stream loaded by MPV") }
                } else if event.pointee.event_id == MPV_EVENT_END_FILE {
                    if let data = event.pointee.data?.assumingMemoryBound(to: mpv_event_end_file.self).pointee,
                       data.error < 0 {
                        let message = String(cString: mpv_error_string(data.error))
                        DispatchQueue.main.async { self.onError?("MPV couldn't play this stream: \(message)") }
                    }
                } else if event.pointee.event_id == MPV_EVENT_LOG_MESSAGE {
                    // Detailed logging is intentionally left to the native MPV logger.
                }
            }
        }

        func shutdown() {
            guard let handle = mpv else { return }
            mpv = nil
            var stopCommand: [UnsafePointer<CChar>?] = ["stop".withCString { strdup($0).map(UnsafePointer.init) }, nil]
            _ = stopCommand.withUnsafeMutableBufferPointer { buffer in
                mpv_command(handle, buffer.baseAddress)
            }
            if let pointer = stopCommand[0] { free(UnsafeMutablePointer(mutating: pointer)) }
            mpv_terminate_destroy(handle)
        }
    }
}

final class MPVMetalView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.contentsScale = UIScreen.main.scale
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.contentsScale = UIScreen.main.scale
    }
}
