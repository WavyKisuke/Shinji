from pathlib import Path

player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the UIKit/Metal player surface passive so SwiftUI overlay controls receive taps.
p = p.replace('''                playerSurface()\n                    .zIndex(0)\n                    .contentShape(Rectangle())\n                    .onTapGesture { toggleControls() }\n\n                if showControls && !controlsLocked {''', '''                playerSurface()\n                    .zIndex(0)\n                    .allowsHitTesting(false)\n\n                if !showControls || controlsLocked {\n                    Color.clear\n                        .contentShape(Rectangle())\n                        .onTapGesture { toggleControls() }\n                        .zIndex(1)\n                }\n\n                if showControls && !controlsLocked {''', 1)

p = p.replace('''        .background(.black)\n        .allowsHitTesting(true)\n    }\n\n    private func controlsOverlay()''', '''        .background(.black)\n    }\n\n    private func controlsOverlay()''', 1)

p = p.replace('["cycle", "pause"]', '["set", "pause", isPlaying ? "yes" : "no"]')
p = p.replace('["cycle", "audio"]', '["cycle", "aid"]')
p = p.replace('["cycle", "sub"]', '["cycle", "sid"]')
player.write_text(p, encoding="utf-8")

mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
m = mpv.read_text(encoding="utf-8")

# Run 203 failed because this script assumed an older command bridge. Keep the
# repair idempotent: accept the existing command implementation and only apply
# the UIKit hit-testing change that is still required.
if 'private func command(_ arguments: [String])' not in m and 'func command(_ arguments: [String])' not in m:
    raise SystemExit("Expected MPV command function was not found")

needle = '''        view.backgroundColor = .black\n        metalLayer.frame = view.bounds'''
replacement = '''        view.backgroundColor = .black\n        view.isUserInteractionEnabled = false\n        metalLayer.frame = view.bounds'''
if needle in m and 'view.isUserInteractionEnabled = false' not in m:
    m = m.replace(needle, replacement, 1)

mpv.write_text(m, encoding="utf-8")
