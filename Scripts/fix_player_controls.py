from pathlib import Path

player = Path("Shinji/Views/PlayerView.swift")
text = player.read_text(encoding="utf-8")

# MPV uses the track-selection properties `aid` and `sid` for embedded
# audio/subtitle tracks. Keep the UI Nuvio-style, but never translate these
# into the invalid `audio`/`sub` command names.
text = text.replace('["cycle", "audio"]', '["cycle", "aid"]')
text = text.replace('["cycle", "sub"]', '["cycle", "sid"]')
text = text.replace('["cycle", "aid"]', '["cycle", "aid"]')
text = text.replace('["cycle", "sid"]', '["cycle", "sid"]')
text = text.replace('sendCommand(["cycle", "pause"])', 'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])')

# Nuvio-style player: one dedicated playback-speed control, with speed choices
# in a popup rather than duplicated inside the general settings sheet.
import re

text = re.sub(r'\n\s*@State private var showPlaybackSpeed = false\n', '\n', text)
text = text.replace('    @State private var showSettings = false\n',
                    '    @State private var showSettings = false\n    @State private var showPlaybackSpeed = false\n', 1)

text = re.sub(r'\nprivate struct PlaybackSpeedSheet: View \{.*?\n\}\n\nprivate struct PlayerSettingsSheet',
              '\nprivate struct PlayerSettingsSheet', text, flags=re.S)

speed_sheet = '''
private struct PlaybackSpeedSheet: View {
    let sendCommand: ([String]) -> Void
    @Environment(\\.dismiss) private var dismiss

    private let speeds: [(String, String)] = [
        ("0.5×", "0.5"),
        ("0.75×", "0.75"),
        ("Normal", "1"),
        ("1.25×", "1.25"),
        ("1.5×", "1.5"),
        ("1.75×", "1.75"),
        ("2×", "2")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(speeds, id: \\.1) { speed in
                    Button(speed.0) {
                        sendCommand(["set", "speed", speed.1])
                        dismiss()
                    }
                }
            }
            .navigationTitle("Playback Speed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PlayerSettingsSheet'''
marker = '\nprivate struct PlayerSettingsSheet'
if marker in text:
    text = text.replace(marker, '\n' + speed_sheet, 1)

start = '                Section("Playback") {'
while start in text:
    begin = text.find(start)
    brace = text.find('{', begin)
    depth = 0
    end = None
    for i in range(brace, len(text)):
        if text[i] == '{': depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None: break
    text = text[:begin] + text[end:]

text = re.sub(
    r'\n\s*bottomButton\("speedometer", "Playback Speed"\) \{.*?\n\s*\}\n',
    '\n', text, flags=re.S
)
speed_button = '''                bottomButton("speedometer", "Playback Speed") {
                    showPlaybackSpeed = true
                }
'''
settings_button = '                bottomButton("gearshape", "Settings") { showSettings = true }\n'
if settings_button in text and speed_button not in text:
    text = text.replace(settings_button, speed_button + settings_button, 1)

text = re.sub(
    r'\n\s*\.sheet\(isPresented: \$showPlaybackSpeed\) \{.*?\n\s*\}\n(?=\s*\.sheet\(isPresented: \$showSettings\))',
    '\n', text, flags=re.S
)
speed_presenter = '''        .sheet(isPresented: $showPlaybackSpeed) {
            PlaybackSpeedSheet(sendCommand: sendCommand)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
'''
settings_sheet = '        .sheet(isPresented: $showSettings) {'
if settings_sheet in text and speed_presenter not in text:
    text = text.replace(settings_sheet, speed_presenter + settings_sheet, 1)

if 'temporaryDoubleSpeed' not in text:
    text = text.replace('    @State private var showPlaybackSpeed = false\n',
                        '    @State private var showPlaybackSpeed = false\n    @State private var temporaryDoubleSpeed = false\n', 1)

player.write_text(text, encoding="utf-8")

# Keep the player bridge's command vocabulary compatible with MPV.
mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
mpv_text = mpv.read_text(encoding="utf-8")
mpv_text = mpv_text.replace('["cycle", "audio"]', '["cycle", "aid"]')
mpv_text = mpv_text.replace('["cycle", "sub"]', '["cycle", "sid"]')
mpv.write_text(mpv_text, encoding="utf-8")
