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

# Refresh tracks when a stream loads and whenever MPV reports a property change.
m = m.replace(
    '                    self.publishStatus("Stream loaded")\n                    self.publishPlaybackState(handle)',
    '                    self.publishStatus("Stream loaded")\n                    self.publishTracks(handle)\n                    self.publishPlaybackState(handle)',
    1,
)
m = m.replace(
    '                case MPV_EVENT_PROPERTY_CHANGE:\n                    self.publishPlaybackState(handle)',
    '                case MPV_EVENT_PROPERTY_CHANGE:\n                    self.publishTracks(handle)\n                    self.publishPlaybackState(handle)',
    1,
)

path.write_text(m, encoding="utf-8")
