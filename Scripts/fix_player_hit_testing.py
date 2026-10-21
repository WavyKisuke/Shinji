from pathlib import Path

player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the UIKit/Metal player surface passive so SwiftUI overlay controls receive taps.
# IMPORTANT: MPV's embedded track properties are `aid` and `sid`; `audio` and `sub`
# are not valid MPV track properties.
p = p.replace('["cycle", "audio"]', '["cycle", "aid"]')
p = p.replace('["cycle", "sub"]', '["cycle", "sid"]')
p = p.replace('["cycle", "aid"]', '["cycle", "aid"]')
p = p.replace('["cycle", "sid"]', '["cycle", "sid"]')
p = p.replace('["cycle", "pause"]', '["set", "pause", isPlaying ? "yes" : "no"]')

p = p.replace('''                playerSurface()\n                    .zIndex(0)\n                    .contentShape(Rectangle())\n                    .onTapGesture { toggleControls() }\n\n                if showControls && !controlsLocked {''', '''                playerSurface()\n                    .zIndex(0)\n                    .allowsHitTesting(false)\n\n                if !showControls || controlsLocked {\n                    Color.clear\n                        .contentShape(Rectangle())\n                        .onTapGesture { toggleControls() }\n                        .zIndex(1)\n                }\n\n                if showControls && !controlsLocked {''', 1)

p = p.replace('''        .background(.black)\n        .allowsHitTesting(true)\n    }\n\n    private func controlsOverlay()''', '''        .background(.black)\n    }\n\n    private func controlsOverlay()''', 1)
player.write_text(p, encoding="utf-8")

mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
m = mpv.read_text(encoding="utf-8")
m = m.replace('["cycle", "audio"]', '["cycle", "aid"]')
m = m.replace('["cycle", "sub"]', '["cycle", "sid"]')
needle = '''        view.backgroundColor = .black\n        metalLayer.frame = view.bounds'''
replacement = '''        view.backgroundColor = .black\n        view.isUserInteractionEnabled = false\n        metalLayer.frame = view.bounds'''
if needle in m and 'view.isUserInteractionEnabled = false' not in m:
    m = m.replace(needle, replacement, 1)
mpv.write_text(m, encoding="utf-8")
