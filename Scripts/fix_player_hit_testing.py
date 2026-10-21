from pathlib import Path

player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the UIKit/Metal player surface passive so SwiftUI overlay controls receive taps.
p = p.replace('["cycle", "audio"]', '["cycle", "aid"]')
p = p.replace('["cycle", "sub"]', '["cycle", "sid"]')
p = p.replace('["cycle", "aid"]', '["cycle", "aid"]')
p = p.replace('["cycle", "sid"]', '["cycle", "sid"]')
p = p.replace('["cycle", "pause"]', '["set", "pause", isPlaying ? "yes" : "no"]')

# Make the actual player and every overlay use the exact current GeometryReader
# bounds. This prevents the rotated UIViewRepresentable from retaining the old
# portrait width and appearing shifted to one side in landscape/fullscreen.
p = p.replace('''                playerSurface()\n                    .frame(maxWidth: .infinity, maxHeight: .infinity)\n                    .contentShape(Rectangle())\n                    .onTapGesture { toggleControls() }\n                    .zIndex(1)''', '''                playerSurface()\n                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)\n                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)\n                    .contentShape(Rectangle())\n                    .onTapGesture { toggleControls() }\n                    .zIndex(1)''', 1)

p = p.replace('''                    controlsOverlay(isLandscape: landscape)\n                        .zIndex(10)''', '''                    controlsOverlay(isLandscape: landscape)\n                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)\n                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)\n                        .zIndex(10)''', 1)

# The overlay itself should not introduce a second unconstrained coordinate space.
p = p.replace('''        .frame(maxWidth: .infinity, maxHeight: .infinity)\n        .foregroundStyle(.white)''', '''        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)\n        .clipped()\n        .foregroundStyle(.white)''', 1)

player.write_text(p, encoding="utf-8")

mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
m = mpv.read_text(encoding="utf-8")
m = m.replace('["cycle", "audio"]', '["cycle", "aid"]')
m = m.replace('["cycle", "sub"]', '["cycle", "sid"]')
needle = '''        view.backgroundColor = .black\n        metalLayer.frame = view.bounds'''
replacement = '''        view.backgroundColor = .black\n        view.isUserInteractionEnabled = false\n        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]\n        metalLayer.frame = view.bounds'''
if needle in m:
    m = m.replace(needle, replacement, 1)
mpv.write_text(m, encoding="utf-8")
