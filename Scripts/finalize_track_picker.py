from pathlib import Path

path = Path("Shinji/Views/PlayerView.swift")
p = path.read_text(encoding="utf-8")

# State required by the real track picker.
state_anchor = '    @State private var showSettings = false\n'
state_block = '''    @State private var showSettings = false
    @State private var showAudioPicker = false
    @State private var showSubtitlePicker = false
    @State private var audioTracks: [MPVPlayerTrack] = []
    @State private var subtitleTracks: [MPVPlayerTrack] = []
    @State private var selectedAudioTrackID: Int?
    @State private var selectedSubtitleTrackID: Int?
'''
if 'showAudioPicker' not in p and state_anchor in p:
    p = p.replace(state_anchor, state_block, 1)

# Buttons must open a picker; cycling cannot show a selectable list.
p = p.replace('sendCommand(["cycle", "audio"])', 'showAudioPicker = true')
p = p.replace('sendCommand(["cycle", "aid"])', 'showAudioPicker = true')
p = p.replace('sendCommand(["cycle", "sub"])', 'showSubtitlePicker = true')
p = p.replace('sendCommand(["cycle", "sid"])', 'showSubtitlePicker = true')

# Feed MPV's actual track list into SwiftUI state.
anchor = '''            onPlaybackUpdate: { time, total, paused in
                // Don't let mpv's position fight the slider while scrubbing or just after a seek.
                if !isScrubbing && Date() >= ignorePositionUpdatesUntil { position = time }
                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }
            }
'''
track_callback = '''            onPlaybackUpdate: { time, total, paused in
                // Don't let mpv's position fight the slider while scrubbing or just after a seek.
                if !isScrubbing && Date() >= ignorePositionUpdatesUntil { position = time }
                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }
            },
            onTracks: { tracks in
                audioTracks = tracks.filter { $0.type == "audio" }
                subtitleTracks = tracks.filter { $0.type == "sub" }
                selectedAudioTrackID = tracks.first(where: { $0.type == "audio" && $0.isSelected })?.id
                selectedSubtitleTrackID = tracks.first(where: { $0.type == "sub" && $0.isSelected })?.id
            }
'''
if 'onTracks: { tracks in' not in p and anchor in p:
    p = p.replace(anchor, track_callback, 1)

# Add the full-screen Nuvio-style pickers once.
sheet_anchor = '''        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet(sendCommand: sendCommand)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
'''
picker = '''        .fullScreenCover(isPresented: $showAudioPicker) {
            NuvioPlayerTrackPicker(
                title: "Audio",
                tracks: audioTracks.map { NuvioPlayerTrack(id: $0.id, title: $0.title, language: $0.language, type: $0.type) },
                selectedID: selectedAudioTrackID,
                offOption: false,
                onSelect: { id in
                    guard let id else { return }
                    selectedAudioTrackID = id
                    sendCommand(["set", "aid", String(id)])
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
        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet(sendCommand: sendCommand)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
'''
if 'fullScreenCover(isPresented: $showAudioPicker)' not in p and sheet_anchor in p:
    p = p.replace(sheet_anchor, picker, 1)

path.write_text(p, encoding="utf-8")
