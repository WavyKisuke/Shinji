from pathlib import Path
import re

# Final player normalization layer. This runs after the other compatibility
# patches so the player ends up with one consistent Nuvio-style interaction
# surface instead of several patches competing with each other.

player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the canonical commands used by Shinji's MPV bridge.
p = p.replace('["cycle", "aid"]', '["cycle", "audio"]')
p = p.replace('["cycle", "sid"]', '["cycle", "sub"]')
p = p.replace('sendCommand(["cycle", "pause"])', 'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])')

# Make the whole video surface respond to horizontal swipe seeking, matching
# the gesture-first interaction used by Nuvio mobile.
old_surface = '''        .frame(maxWidth: .infinity, maxHeight: .infinity)\n        .background(.black)\n        .allowsHitTesting(true)'''
new_surface = '''        .frame(maxWidth: .infinity, maxHeight: .infinity)\n        .background(.black)\n        .allowsHitTesting(true)\n        .simultaneousGesture(\n            DragGesture(minimumDistance: 28)\n                .onEnded { value in\n                    guard !controlsLocked, abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) > 55 else { return }\n                    let seconds = value.translation.width > 0 ? -10 : 10\n                    sendCommand(["seek", String(seconds), "relative"])\n                    if duration > 0 {\n                        position = max(0, min(duration, position + Double(seconds)))\n                        ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n                    }\n                    showControls = true\n                    scheduleHide()\n                }\n        )'''
if old_surface in p and '.simultaneousGesture(' not in p:
    p = p.replace(old_surface, new_surface, 1)

# The speed control is owned here. Remove every prior speed state/sheet/button
# and install exactly one Nuvio-style dedicated speed control.
p = re.sub(r'\n\s*@State private var showPlaybackSpeed = false\n', '\n', p)
p = p.replace('    @State private var showSettings = false\n',
              '    @State private var showSettings = false\n    @State private var showPlaybackSpeed = false\n', 1)
p = re.sub(r'\nprivate struct PlaybackSpeedSheet: View \{.*?\n\}\n\nprivate struct PlayerSettingsSheet',
           '\nprivate struct PlayerSettingsSheet', p, flags=re.S)

# Remove old Playback sections from the settings sheet so speed is never shown twice.
start = '                Section("Playback") {'
while start in p:
    begin = p.find(start)
    brace = p.find('{', begin)
    depth = 0
    end = None
    for i in range(brace, len(p)):
        if p[i] == '{':
            depth += 1
        elif p[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        break
    p = p[:begin] + p[end:]

p = re.sub(
    r'\n\s*bottomButton\("speedometer", "Playback Speed"\) \{.*?\n\s*\}\n',
    '\n', p, flags=re.S
)

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
if marker in p:
    p = p.replace(marker, '\n' + speed_sheet, 1)

settings_button = '                bottomButton("gearshape", "Settings") { showSettings = true }\n'
speed_button = '''                bottomButton("speedometer", "Playback Speed") {
                    showPlaybackSpeed = true
                }
'''
if settings_button in p and speed_button not in p:
    p = p.replace(settings_button, speed_button + settings_button, 1)

# Attach exactly one dedicated speed sheet before the general settings sheet.
p = re.sub(
    r'\n\s*\.sheet\(isPresented: \$showPlaybackSpeed\) \{.*?\n\s*\}\n(?=\s*\.sheet\(isPresented: \$showSettings\))',
    '\n', p, flags=re.S
)
speed_presenter = '''        .sheet(isPresented: $showPlaybackSpeed) {
            PlaybackSpeedSheet(sendCommand: sendCommand)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
'''
settings_sheet = '        .sheet(isPresented: $showSettings) {'
if settings_sheet in p and speed_presenter not in p:
    p = p.replace(settings_sheet, speed_presenter + settings_sheet, 1)

# Nuvio-style long press: temporarily play at 2× while holding the video.
if 'temporaryDoubleSpeed' not in p:
    p = p.replace('    @State private var showPlaybackSpeed = false\n',
                  '    @State private var showPlaybackSpeed = false\n    @State private var temporaryDoubleSpeed = false\n', 1)
    anchor = '                    .onTapGesture { toggleControls() }\n'
    replacement = '''                    .onTapGesture { toggleControls() }
                    .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 24, pressing: { pressing in
                        guard playbackError == nil else { return }
                        if pressing && !temporaryDoubleSpeed {
                            temporaryDoubleSpeed = true
                            sendCommand(["set", "speed", "2"])
                        } else if !pressing && temporaryDoubleSpeed {
                            temporaryDoubleSpeed = false
                            sendCommand(["set", "speed", "1"])
                        }
                    }, perform: {})
'''
    p = p.replace(anchor, replacement, 1)

player.write_text(p, encoding="utf-8")

# Harden the MPV bridge so transport commands use direct properties where
# possible. Track cycling remains exposed through the normal MPV command path.
mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
m = mpv.read_text(encoding="utf-8")

old_command = '''    func command(_ arguments: [String]) {\n        guard !arguments.isEmpty else { return }\n        mpvQueue.async { [weak self] in\n            guard let self, let handle = self.activeHandle() else { return }\n            self.execute(arguments, on: handle)\n        }\n    }'''
new_command = '''    func command(_ arguments: [String]) {
        guard !arguments.isEmpty else { return }
        mpvQueue.async { [weak self] in
            guard let self, let handle = self.activeHandle() else { return }

            if arguments.count == 3, arguments[0] == "set" {
                let property = arguments[1]
                let value = arguments[2]
                switch property {
                case "pause":
                    var paused: Int32 = value == "yes" ? 1 : 0
                    let result = mpv_set_property(handle, "pause", MPV_FORMAT_FLAG, &paused)
                    if result < 0 { self.publishError("MPV pause command failed: \\(String(cString: mpv_error_string(result)))") }
                    self.publishPlaybackState(handle)
                    return
                case "mute":
                    var muted: Int32 = value == "yes" ? 1 : 0
                    let result = mpv_set_property(handle, "mute", MPV_FORMAT_FLAG, &muted)
                    if result < 0 { self.publishError("MPV mute command failed: \\(String(cString: mpv_error_string(result)))") }
                    return
                case "speed":
                    var speed = Double(value) ?? 1.0
                    let result = mpv_set_property(handle, "speed", MPV_FORMAT_DOUBLE, &speed)
                    if result < 0 { self.publishError("MPV speed command failed: \\(String(cString: mpv_error_string(result)))") }
                    return
                case "video-zoom":
                    var zoom = Double(value) ?? 0.0
                    let result = mpv_set_property(handle, "video-zoom", MPV_FORMAT_DOUBLE, &zoom)
                    if result < 0 { self.publishError("MPV zoom command failed: \\(String(cString: mpv_error_string(result)))") }
                    return
                case "video-unscaled":
                    var unscaled: Int32 = value == "yes" ? 1 : 0
                    let result = mpv_set_property(handle, "video-unscaled", MPV_FORMAT_FLAG, &unscaled)
                    if result < 0 { self.publishError("MPV sizing command failed: \\(String(cString: mpv_error_string(result)))") }
                    return
                default:
                    break
                }
            }

            if arguments.count == 3, arguments[0] == "seek" {
                let amount = Double(arguments[1]) ?? 0
                let mode = arguments[2]
                if mode == "absolute" {
                    var target = amount
                    let result = mpv_set_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &target)
                    if result < 0 { self.publishError("MPV seek command failed: \\(String(cString: mpv_error_string(result)))") }
                } else {
                    var current = 0.0
                    _ = mpv_get_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &current)
                    var target = max(0, current + amount)
                    let result = mpv_set_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &target)
                    if result < 0 { self.publishError("MPV seek command failed: \\(String(cString: mpv_error_string(result)))") }
                }
                self.publishPlaybackState(handle)
                return
            }

            self.execute(arguments, on: handle)
        }
    }'''
if old_command in m:
    m = m.replace(old_command, new_command, 1)

m = m.replace('["cycle", "aid"]', '["cycle", "audio"]')
m = m.replace('["cycle", "sid"]', '["cycle", "sub"]')
mpv.write_text(m, encoding="utf-8")