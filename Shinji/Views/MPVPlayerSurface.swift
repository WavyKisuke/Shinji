import SwiftUI
import UIKit
import Libmpv

struct MPVPlayerSurface: UIViewControllerRepresentable {
    let url: URL
    let headers: [String: String]
    var muted: Bool = false
    var commandID: Int = 0
    var command: [String]?
    var onStatus: (String) -> Void
    var onError: (String) -> Void
    var onPlaybackUpdate: (Double, Double, Bool) -> Void = { _, _, _ in }

    func makeUIViewController(context: Context) -> MPVMetalViewController {
        let player = MPVMetalViewController()
        player.playUrl = url
        player.requestHeaders = headers
        player.initialMuted = muted
        player.onStatus = onStatus
        player.onError = onError
        player.onPlaybackUpdate = onPlaybackUpdate
        context.coordinator.player = player
        return player
    }

    func updateUIViewController(_ player: MPVMetalViewController, context: Context) {
        player.onStatus = onStatus
        player.onError = onError
        player.onPlaybackUpdate = onPlaybackUpdate
        player.setMuted(muted)

        guard commandID != context.coordinator.lastCommandID else { return }
        context.coordinator.lastCommandID = commandID
        if let command, !command.isEmpty {
            player.command(command)
        }
    }

    static func dismantleUIViewController(_ player: MPVMetalViewController, coordinator: Coordinator) {
        player.shutdown()
        coordinator.player = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var player: MPVMetalViewController?
        var lastCommandID = -1
    }
}

final class MPVMetalViewController: UIViewController {
    private let metalLayer = ShinjiMetalLayer()
    private let mpvQueue = DispatchQueue(label: "shinji.mpv", qos: .userInitiated)
    private var mpv: OpaquePointer?
    private var isShuttingDown = false
    private var didLoadFile = false
    private var lastMuted: Bool?

    var playUrl: URL?
    var requestHeaders: [String: String] = [:]
    var initialMuted = false
    var onStatus: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onPlaybackUpdate: ((Double, Double, Bool) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        metalLayer.frame = view.bounds
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.backgroundColor = UIColor.black.cgColor
        metalLayer.framebufferOnly = true
        view.layer.addSublayer(metalLayer)

        setupMpv()
        if let url = playUrl {
            loadFile(url)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        metalLayer.frame = view.bounds
        metalLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        let scale = metalLayer.contentsScale
        let size = CGSize(width: max(1, view.bounds.width * scale), height: max(1, view.bounds.height * scale))
        if size.width > 1 && size.height > 1 {
            metalLayer.drawableSize = size
        }
    }

    private func setupMpv() {
        guard let handle = mpv_create() else {
            publishError("MPV could not create a playback instance.")
            return
        }
        mpv = handle

        _ = mpv_request_log_messages(handle, "warn")

        // Simple iOS libmpv path: GPU-next -> Vulkan/MoltenVK -> VideoToolbox.
        var layerReference: Int64 = Int64(Int(bitPattern: Unmanaged.passUnretained(metalLayer).toOpaque()))
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

        applyRequestHeaders(handle)
        setMutedInternal(initialMuted, handle: handle)

        let result = mpv_initialize(handle)
        guard result >= 0 else {
            publishError("MPV initialization failed: \(String(cString: mpv_error_string(result)))")
            shutdown()
            return
        }

        _ = mpv_observe_property(handle, 1, "time-pos", MPV_FORMAT_DOUBLE)
        _ = mpv_observe_property(handle, 2, "duration", MPV_FORMAT_DOUBLE)
        _ = mpv_observe_property(handle, 3, "pause", MPV_FORMAT_FLAG)

        mpv_set_wakeup_callback(
            handle,
            { context in
                guard let context else { return }
                let player = Unmanaged<MPVMetalViewController>.fromOpaque(context).takeUnretainedValue()
                player.readEvents()
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        publishStatus("MPV ready")
    }

    private func applyRequestHeaders(_ handle: OpaquePointer) {
        let safe = requestHeaders.filter {
            !$0.key.contains("\r") && !$0.key.contains("\n") &&
            !$0.value.contains("\r") && !$0.value.contains("\n")
        }
        let fields = safe
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { key, value in
                let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ",", with: "\\,")
                return "\(key): \(escaped)"
            }
            .joined(separator: ",")
        _ = mpv_set_property_string(handle, "http-header-fields", fields)
    }

    func loadFile(_ url: URL) {
        mpvQueue.async { [weak self] in
            guard let self, let handle = self.activeHandle() else { return }
            self.execute(["loadfile", url.absoluteString, "replace"], on: handle)
            self.didLoadFile = true
            self.publishStatus("Opening stream…")
        }
    }

    func command(_ arguments: [String]) {
        guard !arguments.isEmpty else { return }
        mpvQueue.async { [weak self] in
            guard let self, let handle = self.activeHandle() else { return }
            self.execute(arguments, on: handle)
        }
    }

    func setMuted(_ muted: Bool) {
        guard lastMuted != muted else { return }
        lastMuted = muted
        mpvQueue.async { [weak self] in
            guard let self, let handle = self.activeHandle() else { return }
            self.setMutedInternal(muted, handle: handle)
        }
    }

    private func setMutedInternal(_ muted: Bool, handle: OpaquePointer) {
        var value: Int32 = muted ? 1 : 0
        let result = mpv_set_property(handle, "mute", MPV_FORMAT_FLAG, &value)
        if result < 0 {
            publishError("MPV mute command failed: \(String(cString: mpv_error_string(result)))")
        }
        lastMuted = muted
    }

    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        var cargs: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        cargs.append(nil)
        defer {
            for pointer in cargs where pointer != nil {
                free(pointer)
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
            guard let self, let handle = self.activeHandle() else { return }
            while true {
                guard let event = mpv_wait_event(handle, 0) else { return }
                switch event.pointee.event_id {
                case MPV_EVENT_NONE:
                    return
                case MPV_EVENT_FILE_LOADED:
                    self.publishStatus("Stream loaded")
                    self.publishPlaybackState(handle)
                case MPV_EVENT_PROPERTY_CHANGE:
                    self.publishPlaybackState(handle)
                case MPV_EVENT_END_FILE:
                    if let raw = event.pointee.data {
                        let data = raw.assumingMemoryBound(to: mpv_event_end_file.self).pointee
                        if data.error < 0 {
                            self.publishError("MPV couldn't play this stream: \(String(cString: mpv_error_string(data.error)))")
                        }
                    }
                    self.publishPlaybackState(handle)
                case MPV_EVENT_SHUTDOWN:
                    return
                default:
                    break
                }
            }
        }
    }

    private func publishPlaybackState(_ handle: OpaquePointer) {
        var time = 0.0
        var duration = 0.0
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
        guard !isShuttingDown else { return nil }
        return mpv
    }

    @objc private func enteredBackground() {
        command(["set", "vid", "no"])
        command(["set", "pause", "yes"])
    }

    @objc private func enteredForeground() {
        command(["set", "vid", "auto"])
        command(["set", "pause", "no"])
    }

    func shutdown() {
        guard !isShuttingDown else { return }
        isShuttingDown = true
        NotificationCenter.default.removeObserver(self)
        guard let handle = mpv else { return }
        mpv = nil
        mpv_set_wakeup_callback(handle, nil, nil)
        mpv_terminate_destroy(handle)
    }

    deinit {
        shutdown()
    }

    private func publishStatus(_ value: String) {
        DispatchQueue.main.async { [weak self] in self?.onStatus?(value) }
    }

    private func publishError(_ value: String) {
        DispatchQueue.main.async { [weak self] in self?.onError?(value) }
    }
}

final class ShinjiMetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            if newValue.width > 1 && newValue.height > 1 {
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
