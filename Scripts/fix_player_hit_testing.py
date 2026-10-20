from pathlib import Path

player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the Metal/UIView player completely passive. A UIKit-backed player surface can
# otherwise win the hit-test race over SwiftUI's overlay buttons on some iOS versions.
p = p.replace('''                playerSurface()\n                    .zIndex(0)\n                    .contentShape(Rectangle())\n                    .onTapGesture { toggleControls() }\n\n                if showControls && !controlsLocked {''', '''                playerSurface()\n                    .zIndex(0)\n                    .allowsHitTesting(false)\n\n                // Dedicated SwiftUI interaction surface. It sits above the video but\n                // below the actual controls, guaranteeing taps reach SwiftUI buttons.\n                if !showControls || controlsLocked {\n                    Color.clear\n                        .contentShape(Rectangle())\n                        .onTapGesture { toggleControls() }\n                        .zIndex(1)\n                }\n\n                if showControls && !controlsLocked {''', 1)

p = p.replace('''        .background(.black)\n        .allowsHitTesting(true)\n    }\n\n    private func controlsOverlay()''', '''        .background(.black)\n    }\n\n    private func controlsOverlay()''', 1)

# Use explicit mpv properties for transport and track selection instead of relying on
# command aliases that vary across libmpv builds.
p = p.replace('["cycle", "pause"]', '["set", "pause", isPlaying ? "yes" : "no"]')
p = p.replace('["cycle", "audio"]', '["cycle", "aid"]')
p = p.replace('["cycle", "sub"]', '["cycle", "sid"]')

player.write_text(p, encoding="utf-8")

mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
m = mpv.read_text(encoding="utf-8")

# Make the common controls deterministic at the libmpv property layer.
needle = '''    func command(_ arguments: [String]) {\n        guard !arguments.isEmpty else { return }\n        mpvQueue.async { [weak self] in\n            guard let self, let handle = self.activeHandle() else { return }\n            self.execute(arguments, on: handle)\n        }\n    }'''
replacement = '''    func command(_ arguments: [String]) {\n        guard !arguments.isEmpty else { return }\n        mpvQueue.async { [weak self] in\n            guard let self, let handle = self.activeHandle() else { return }\n\n            if arguments.count == 3, arguments[0] == "set" {\n                let property = arguments[1]\n                let value = arguments[2]\n                switch property {\n                case "pause", "mute":\n                    var flag: Int32 = value == "yes" ? 1 : 0\n                    let result = mpv_set_property(handle, property, MPV_FORMAT_FLAG, &flag)\n                    if result < 0 { self.publishError("MPV \\(property) command failed: \\(String(cString: mpv_error_string(result)))") }\n                    self.publishPlaybackState(handle)\n                    return\n                case "speed", "video-zoom":\n                    var number = Double(value) ?? (property == "speed" ? 1.0 : 0.0)\n                    let result = mpv_set_property(handle, property, MPV_FORMAT_DOUBLE, &number)\n                    if result < 0 { self.publishError("MPV \\(property) command failed: \\(String(cString: mpv_error_string(result)))") }\n                    return\n                case "video-unscaled":\n                    var flag: Int32 = value == "yes" ? 1 : 0\n                    let result = mpv_set_property(handle, property, MPV_FORMAT_FLAG, &flag)\n                    if result < 0 { self.publishError("MPV sizing command failed: \\(String(cString: mpv_error_string(result)))") }\n                    return\n                default:\n                    break\n                }\n            }\n\n            if arguments.count == 3, arguments[0] == "seek" {\n                let amount = Double(arguments[1]) ?? 0\n                var target = amount\n                if arguments[2] == "relative" {\n                    var current = 0.0\n                    _ = mpv_get_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &current)\n                    target = max(0, current + amount)\n                }\n                let result = mpv_set_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &target)\n                if result < 0 { self.publishError("MPV seek command failed: \\(String(cString: mpv_error_string(result)))") }\n                self.publishPlaybackState(handle)\n                return\n            }\n\n            self.execute(arguments, on: handle)\n        }\n    }'''
if needle in m:
    m = m.replace(needle, replacement, 1)
else:
    raise SystemExit("Expected command function was not found")

mpv.write_text(m, encoding="utf-8")
