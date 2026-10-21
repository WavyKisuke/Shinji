from pathlib import Path

path = Path("Shinji/Views/MPVPlayerSurface.swift")
m = path.read_text(encoding="utf-8")

# The picker needs a callback on the representable itself and on the MPV
# controller. Keep these repairs independent so an earlier script cannot
# prevent the bridge from being completed.
if "var onTracks: ([MPVPlayerTrack]) -> Void = { _ in }" not in m:
    m = m.replace(
        "    var onPlaybackUpdate: (Double, Double, Bool) -> Void = { _, _, _ in }\n",
        "    var onPlaybackUpdate: (Double, Double, Bool) -> Void = { _, _, _ in }\n    var onTracks: ([MPVPlayerTrack]) -> Void = { _ in }\n",
        1,
    )

m = m.replace(
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        context.coordinator.player = player",
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        context.coordinator.player = player",
    1,
)

m = m.replace(
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.setMuted(muted)",
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        player.setMuted(muted)",
    1,
)

if "var onTracks: (([MPVPlayerTrack]) -> Void)?" not in m:
    m = m.replace(
        "    var onPlaybackUpdate: ((Double, Double, Bool) -> Void)?\n",
        "    var onPlaybackUpdate: ((Double, Double, Bool) -> Void)?\n    var onTracks: (([MPVPlayerTrack]) -> Void)?\n",
        1,
    )

if "struct MPVPlayerTrack: Identifiable, Hashable" not in m:
    model = '''struct MPVPlayerTrack: Identifiable, Hashable {
    let id: Int
    let title: String
    let language: String?
    let type: String
    let isSelected: Bool
}

'''
    m = m.replace(
        "struct MPVPlayerSurface: UIViewControllerRepresentable {",
        model + "struct MPVPlayerSurface: UIViewControllerRepresentable {",
        1,
    )

# Observe the properties that actually change when MPV finishes discovering
# embedded/external tracks. FILE_LOADED alone can race track discovery.
if '"track-list/count"' not in m.split("private func setupMpv", 1)[1].split("mpv_set_wakeup_callback", 1)[0]:
    m = m.replace(
        '        _ = mpv_observe_property(handle, 3, "pause", MPV_FORMAT_FLAG)\n',
        '        _ = mpv_observe_property(handle, 3, "pause", MPV_FORMAT_FLAG)\n        _ = mpv_observe_property(handle, 4, "track-list/count", MPV_FORMAT_INT64)\n        _ = mpv_observe_property(handle, 5, "aid", MPV_FORMAT_INT64)\n        _ = mpv_observe_property(handle, 6, "sid", MPV_FORMAT_INT64)\n',
        1,
    )

if "private func publishTracks(_ handle: OpaquePointer)" not in m:
    methods = '''    private func publishTracks(_ handle: OpaquePointer) {
        var count: Int64 = 0
        guard mpv_get_property(handle, "track-list/count", MPV_FORMAT_INT64, &count) >= 0 else { return }

        var tracks: [MPVPlayerTrack] = []
        for index in 0..<max(0, Int(count)) {
            let prefix = "track-list/\\(index)"
            guard let type = stringProperty(handle, "\\(prefix)/type"), type == "audio" || type == "sub" else { continue }
            let id = intProperty(handle, "\\(prefix)/id") ?? (index + 1)
            let title = stringProperty(handle, "\\(prefix)/title") ?? ""
            let language = stringProperty(handle, "\\(prefix)/lang")
            let selected = intProperty(handle, type == "audio" ? "aid" : "sid") == id
            tracks.append(MPVPlayerTrack(id: id, title: title, language: language, type: type, isSelected: selected))
        }

        DispatchQueue.main.async { [weak self] in
            self?.onTracks?(tracks)
        }
    }

    private func refreshTracksSoon(_ handle: OpaquePointer) {
        publishTracks(handle)
        for delay in [0.25, 0.75, 1.5] {
            mpvQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let active = self.activeHandle(), active == handle else { return }
                self.publishTracks(active)
            }
        }
    }

    private func stringProperty(_ handle: OpaquePointer, _ name: String) -> String? {
        var value: UnsafeMutablePointer<CChar>?
        guard mpv_get_property(handle, name, MPV_FORMAT_STRING, &value) >= 0, let value else { return nil }
        defer { mpv_free(value) }
        return String(cString: value)
    }

    private func intProperty(_ handle: OpaquePointer, _ name: String) -> Int? {
        var value: Int64 = 0
        guard mpv_get_property(handle, name, MPV_FORMAT_INT64, &value) >= 0 else { return nil }
        return Int(value)
    }

'''
    m = m.replace(
        "    private func publishPlaybackState(_ handle: OpaquePointer) {",
        methods + "    private func publishPlaybackState(_ handle: OpaquePointer) {",
        1,
)
else:
    # Upgrade an existing bridge from a single FILE_LOADED refresh to retries.
    if "private func refreshTracksSoon" not in m:
        methods = '''    private func refreshTracksSoon(_ handle: OpaquePointer) {
        publishTracks(handle)
        for delay in [0.25, 0.75, 1.5] {
            mpvQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let active = self.activeHandle(), active == handle else { return }
                self.publishTracks(active)
            }
        }
    }

'''
        m = m.replace("    private func publishPlaybackState(_ handle: OpaquePointer) {", methods + "    private func publishPlaybackState(_ handle: OpaquePointer) {", 1)

m = m.replace(
    '                    self.publishStatus("Stream loaded")\n                    self.publishTracks(handle)\n                    self.publishPlaybackState(handle)',
    '                    self.publishStatus("Stream loaded")\n                    self.refreshTracksSoon(handle)\n                    self.publishPlaybackState(handle)',
    1,
)
m = m.replace(
    '                case MPV_EVENT_PROPERTY_CHANGE:\n                    self.publishTracks(handle)\n                    self.publishPlaybackState(handle)',
    '                case MPV_EVENT_PROPERTY_CHANGE:\n                    self.publishTracks(handle)\n                    self.publishPlaybackState(handle)',
    1,
)

# MPVKit's public headers do not expose MPV_EVENT_TRACKS_CHANGED. Track-list
# changes are already covered by the observed track-list/count, aid and sid
# properties plus the post-load retries above. Never emit an unavailable
# enum reference into the generated Swift source.
m = m.replace(
    '                case MPV_EVENT_TRACKS_CHANGED:\n                    self.refreshTracksSoon(handle)\n',
    '',
)

path.write_text(m, encoding="utf-8")
