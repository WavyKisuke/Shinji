from pathlib import Path

path = Path("Shinji/Views/MPVPlayerSurface.swift")
text = path.read_text(encoding="utf-8")

old = '''        metalLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)\n'''
text = text.replace(old, '''        metalLayer.anchorPoint = CGPoint(x: 0.0, y: 0.0)\n''', 1)

old_layout = '''        CATransaction.begin()\n        CATransaction.setDisableActions(true)\n        metalLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)\n        metalLayer.bounds = CGRect(origin: .zero, size: bounds.size)\n        metalLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale\n        let scale = metalLayer.contentsScale\n        metalLayer.drawableSize = CGSize(\n            width: max(1, bounds.width * scale),\n            height: max(1, bounds.height * scale)\n        )\n        CATransaction.commit()\n'''
new_layout = '''        CATransaction.begin()\n        CATransaction.setDisableActions(true)\n        metalLayer.frame = bounds\n        metalLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale\n        let scale = metalLayer.contentsScale\n        metalLayer.drawableSize = CGSize(\n            width: max(1, bounds.width * scale),\n            height: max(1, bounds.height * scale)\n        )\n        CATransaction.commit()\n'''
if old_layout in text:
    text = text.replace(old_layout, new_layout, 1)

if "metalLayer.needsDisplayOnBoundsChange" not in text:
    text = text.replace(
        '        metalLayer.framebufferOnly = true\n',
        '        metalLayer.framebufferOnly = true\n        metalLayer.needsDisplayOnBoundsChange = true\n',
        1,
    )

path.write_text(text, encoding="utf-8")
print("Final MPV rotation layout normalization applied.")
