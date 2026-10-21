from pathlib import Path

player_path = Path("Shinji/Views/PlayerView.swift")
p = player_path.read_text(encoding="utf-8")

# Use direct pause state instead of cycling it.
p = p.replace('sendCommand(["cycle", "pause"])', 'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])')

# Real Nuvio-style audio/subtitle selection state.
if "@State private var showAudioPicker = false" not in p:
    p = p.replace(
        "    @State private var showSettings = false\n",
        """    @State private var showSettings = false
    @State private var showAudioPicker = false
    @State private var showSubtitlePicker = false
    @State private var audioTracks: [MPVPlayerTrack] = []
    @State private var subtitleTracks: [MPVPlayerTrack] = []
    @State private var selectedAudioTrackID: Int?
    @State private var selectedSubtitleTrackID: Int?
""", 1)

# Replace blind cycling with pickers.
p = p.replace('sendCommand(["cycle", "audio"])', 'showAudioPicker = true')
p = p.replace('sendCommand(["cycle", "aid"])', 'showAudioPicker = true')
p = p.replace('sendCommand(["cycle", "sub"])', 'showSubtitlePicker = true')
p = p.replace('sendCommand(["cycle", "sid"])', 'showSubtitlePicker = true')

# Receive the MPV track list.
anchor = '''            onPlaybackUpdate: { time, total, paused in
                // Don't let mpv's position fight the slider while scrubbing or just after a seek.
                if !isScrubbing && Date() >= ignorePositionUpdatesUntil { position = time }
                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }
            }
'''
if anchor in p and "onTracks: { tracks in" not in p:
    p = p.replace(anchor, anchor + ''',
            onTracks: { tracks in
                audioTracks = tracks.filter { $0.type == "audio" }
                subtitleTracks = tracks.filter { $0.type == "sub" }
                selectedAudioTrackID = tracks.first(where: { $0.type == "audio" && $0.isSelected })?.id
                selectedSubtitleTrackID = tracks.first(where: { $0.type == "sub" && $0.isSelected })?.id
            }
''', 1)

# Insert the track rails before the settings sheet.
marker = '''        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet(sendCommand: sendCommand)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
'''
if marker in p and ".fullScreenCover(isPresented: $showAudioPicker)" not in p:
    picker = '''        .fullScreenCover(isPresented: $showAudioPicker) {
            NuvioPlayerTrackPicker(
                title: "Audio",
                tracks: audioTracks.map { NuvioPlayerTrack(id: $0.id, title: $0.title, language: $0.language, type: $0.type) },
                selectedID: selectedAudioTrackID,
                offOption: false,
                onSelect: { id in
                    if let id {
                        selectedAudioTrackID = id
                        sendCommand(["set", "aid", String(id)])
                    }
                    showAudioPicker = false
                    scheduleHide()
                },
                onDismiss: { showAudioPicker = false }
            )
            .background(.black)
        }
        .fullScreenCover(isPresented: $showSubtitlePicker) {
            NuvioPlayerTrackPicker(
                title: "Subtitles",
                tracks: subtitleTracks.map { NuvioPlayerTrack(id: $0.id, title: $0.title, language: $0.language, type: $0.type) },
                selectedID: selectedSubtitleTrackID,
                offOption: true,
                onSelect: { id in
                    selectedSubtitleTrackID = id
                    sendCommand(["set", "sid", id.map(String.init) ?? "no"])
                    showSubtitlePicker = false
                    scheduleHide()
                },
                onDismiss: { showSubtitlePicker = false }
            )
            .background(.black)
        }
'''
    p = p.replace(marker, picker + marker, 1)

player_path.write_text(p, encoding="utf-8")

# MPV bridge: expose track-list metadata and selected IDs.
mpv_path = Path("Shinji/Views/MPVPlayerSurface.swift")
m = mpv_path.read_text(encoding="utf-8")

if "var onTracks: ([MPVPlayerTrack]) -> Void" not in m:
    m = m.replace(
        "    var onPlaybackUpdate: ((Double, Double, Bool) -> Void) = { _, _, _ in }\n",
        "    var onPlaybackUpdate: ((Double, Double, Bool) -> Void) = { _, _, _ in }\n    var onTracks: ([MPVPlayerTrack]) -> Void = { _ in }\n", 1)
    m = m.replace("        player.onPlaybackUpdate = onPlaybackUpdate\n        context.coordinator.player = player", "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        context.coordinator.player = player", 1)
    m = m.replace("        player.onPlaybackUpdate = onPlaybackUpdate\n        player.setMuted(muted)", "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        player.setMuted(muted)", 1)
    m = m.replace("    var onPlaybackUpdate: ((Double, Double, Bool) -> Void)?\n", "    var onPlaybackUpdate: ((Double, Double, Bool) -> Void)?\n    var onTracks: (([MPVPlayerTrack]) -> Void)?\n", 1)
    m = m.replace('                    self.publishStatus("Stream loaded")\n                    self.publishPlaybackState(handle)', '                    self.publishStatus("Stream loaded")\n                    self.publishTracks(handle)\n                    self.publishPlaybackState(handle)', 1)
    m = m.replace('                case MPV_EVENT_PROPERTY_CHANGE:\n                    self.publishPlaybackState(handle)', '                case MPV_EVENT_PROPERTY_CHANGE:\n                    self.publishTracks(handle)\n                    self.publishPlaybackState(handle)', 1)

    model = '''struct MPVPlayerTrack: Identifiable, Hashable {
    let id: Int
    let title: String
    let language: String?
    let type: String
    let isSelected: Bool
}

'''
    m = m.replace('struct MPVPlayerSurface: UIViewControllerRepresentable {', model + 'struct MPVPlayerSurface: UIViewControllerRepresentable {', 1)

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
        DispatchQueue.main.async { [weak self] in self?.onTracks?(tracks) }
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
    m = m.replace('    private func publishPlaybackState(_ handle: OpaquePointer) {', methods + '    private func publishPlaybackState(_ handle: OpaquePointer) {', 1)

mpv_path.write_text(m, encoding="utf-8")
