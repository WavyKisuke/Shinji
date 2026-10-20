from pathlib import Path

# Keep the player interaction layer aligned with Nuvio's mobile-player pattern:
# top toolbar, centered transport controls, bottom timeline/actions, gesture seeking,
# and direct libmpv property writes for the commands users press most often.

player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the corrected libmpv track commands. Do not reintroduce aid/sid aliases.
p = p.replace('["cycle", "aid"]', '["cycle", "audio"]')
p = p.replace('["cycle", "sid"]', '["cycle", "sub"]')
p = p.replace('sendCommand(["cycle", "pause"])', 'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])')

# Make the whole video surface respond to horizontal swipe seeking, matching Nuvio mobile gestures.
old_surface = '''        .frame(maxWidth: .infinity, maxHeight: .infinity)\n        .background(.black)\n        .allowsHitTesting(true)'''
new_surface = '''        .frame(maxWidth: .infinity, maxHeight: .infinity)\n        .background(.black)\n        .allowsHitTesting(true)\n        .simultaneousGesture(\n            DragGesture(minimumDistance: 28)\n                .onEnded { value in\n                    guard !controlsLocked, abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) > 55 else { return }\n                    let seconds = value.translation.width > 0 ? -10 : 10\n                    sendCommand(["seek", String(seconds), "relative"])\n                    if duration > 0 {\n                        position = max(0, min(duration, position + Double(seconds)))\n                        ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n                    }\n                    showControls = true\n                    scheduleHide()\n                }\n        )'''
if old_surface in p and '.simultaneousGesture(' not in p:
    p = p.replace(old_surface, new_surface, 1)

# Playback speed is owned by fix_player_controls.py. Never inject another speed button here.
# This prevents the duplicate speed controls that appeared in earlier builds.

player.write_text(p, encoding="utf-8")

# Make play/pause, seeking, mute and speed deterministic by writing mpv properties directly.
mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
m = mpv.read_text(encoding="utf-8")

old_command = '''    func command(_ arguments: [String]) {\n        guard !arguments.isEmpty else { return }\n        mpvQueue.async { [weak self] in\n            guard let self, let handle = self.activeHandle() else { return }\n            self.execute(arguments, on: handle)\n        }\n    }'''
new_command = '''    func command(_ arguments: [String]) {\n        guard !arguments.isEmpty else { return }\n        mpvQueue.async { [weak self] in\n            guard let self, let handle = self.activeHandle() else { return }\n\n            if arguments.count == 3, arguments[0] == "set" {\n                let property = arguments[1]\n                let value = arguments[2]\n                switch property {\n                case "pause":\n                    var paused: Int32 = value == "yes" ? 1 : 0\n                    let result = mpv_set_property(handle, "pause", MPV_FORMAT_FLAG, &paused)\n                    if result < 0 { self.publishError("MPV pause command failed: \\(String(cString: mpv_error_string(result)))") }\n                    self.publishPlaybackState(handle)\n                    return\n                case "mute":\n                    var muted: Int32 = value == "yes" ? 1 : 0\n                    let result = mpv_set_property(handle, "mute", MPV_FORMAT_FLAG, &muted)\n                    if result < 0 { self.publishError("MPV mute command failed: \\(String(cString: mpv_error_string(result)))") }\n                    return\n                case "speed":\n                    var speed = Double(value) ?? 1.0\n                    let result = mpv_set_property(handle, "speed", MPV_FORMAT_DOUBLE, &speed)\n                    if result < 0 { self.publishError("MPV speed command failed: \\(String(cString: mpv_error_string(result)))") }\n                    return\n                case "video-zoom":\n                    var zoom = Double(value) ?? 0.0\n                    let result = mpv_set_property(handle, "video-zoom", MPV_FORMAT_DOUBLE, &zoom)\n                    if result < 0 { self.publishError("MPV zoom command failed: \\(String(cString: mpv_error_string(result)))") }\n                    return\n                case "video-unscaled":\n                    var unscaled: Int32 = value == "yes" ? 1 : 0\n                    let result = mpv_set_property(handle, "video-unscaled", MPV_FORMAT_FLAG, &unscaled)\n                    if result < 0 { self.publishError("MPV sizing command failed: \\(String(cString: mpv_error_string(result)))") }\n                    return\n                default:\n                    break\n                }\n            }\n\n            if arguments.count == 3, arguments[0] == "seek" {\n                let amount = Double(arguments[1]) ?? 0\n                let mode = arguments[2]\n                if mode == "absolute" {\n                    var target = amount\n                    let result = mpv_set_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &target)\n                    if result < 0 { self.publishError("MPV seek command failed: \\(String(cString: mpv_error_string(result)))") }\n                } else {\n                    var current = 0.0\n                    _ = mpv_get_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &current)\n                    var target = max(0, current + amount)\n                    let result = mpv_set_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &target)\n                    if result < 0 { self.publishError("MPV seek command failed: \\(String(cString: mpv_error_string(result)))") }\n                }\n                self.publishPlaybackState(handle)\n                return\n            }\n\n            self.execute(arguments, on: handle)\n        }\n    }'''
if old_command in m:
    m = m.replace(old_command, new_command, 1)

m = m.replace('["cycle", "aid"]', '["cycle", "audio"]')
m = m.replace('["cycle", "sid"]', '["cycle", "sub"]')
mpv.write_text(m, encoding="utf-8")