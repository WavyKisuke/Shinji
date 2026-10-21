from pathlib import Path

# Normalize the native MPV/Metal surface so it always follows the rotated
# UIViewController bounds instead of retaining the portrait position.
mpv_path = Path("Shinji/Views/MPVPlayerSurface.swift")
text = mpv_path.read_text(encoding="utf-8")

text = text.replace(
    '        metalLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)\n',
    '        metalLayer.anchorPoint = CGPoint(x: 0.0, y: 0.0)\n',
    1,
)

old_layout = '''        CATransaction.begin()\n        CATransaction.setDisableActions(true)\n        metalLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)\n        metalLayer.bounds = CGRect(origin: .zero, size: bounds.size)\n        metalLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale\n        let scale = metalLayer.contentsScale\n        metalLayer.drawableSize = CGSize(\n            width: max(1, bounds.width * scale),\n            height: max(1, bounds.height * scale)\n        )\n        CATransaction.commit()\n'''
new_layout = '''        CATransaction.begin()\n        CATransaction.setDisableActions(true)\n        metalLayer.frame = bounds\n        metalLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale\n        let scale = metalLayer.contentsScale\n        metalLayer.drawableSize = CGSize(\n            width: max(1, bounds.width * scale),\n            height: max(1, bounds.height * scale)\n        )\n        CATransaction.commit()\n\n        let landscape = bounds.width > bounds.height\n        guard landscape != lastPanscanLandscape else { return }\n        lastPanscanLandscape = landscape\n        mpvQueue.async { [weak self] in\n            guard let self, let handle = self.activeHandle() else { return }\n            self.execute(["set", "panscan", landscape ? "1" : "0"], on: handle)\n            self.execute(["set", "video-pan-x", "0"], on: handle)\n            self.execute(["set", "video-pan-y", "0"], on: handle)\n        }\n'''
if old_layout in text:
    text = text.replace(old_layout, new_layout, 1)

if "metalLayer.needsDisplayOnBoundsChange" not in text:
    text = text.replace(
        '        metalLayer.framebufferOnly = true\n',
        '        metalLayer.framebufferOnly = true\n        metalLayer.needsDisplayOnBoundsChange = true\n        metalLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]\n',
        1,
    )

# Keep aspect ratio while using dynamic pan-and-scan only in landscape.
if '"panscan", "1.0"' in text:
    text = text.replace(
        '        _ = mpv_set_option_string(handle, "panscan", "1.0")\n',
        '        _ = mpv_set_option_string(handle, "keepaspect", "yes")\n',
        1,
    )
elif '"keepaspect", "yes"' not in text:
    text = text.replace(
        '        _ = mpv_set_option_string(handle, "video-rotate", "no")\n',
        '        _ = mpv_set_option_string(handle, "video-rotate", "no")\n        _ = mpv_set_option_string(handle, "keepaspect", "yes")\n',
        1,
    )

# Xcode 16 rejects the old argument order for this SwiftUI frame overload.
# Keep this repair here because several player-polish scripts can recreate the line.
player_path = Path("Shinji/Views/PlayerView.swift")
player = player_path.read_text(encoding="utf-8")
player = player.replace(
    '.frame(maxWidth: .infinity, minWidth: 0, alignment: .leading)',
    '.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)',
)
player_path.write_text(player, encoding="utf-8")

print("Final player rotation, dynamic landscape video fill, and SwiftUI frame normalization applied.")
