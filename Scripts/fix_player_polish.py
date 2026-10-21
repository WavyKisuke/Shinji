from pathlib import Path

# Player polish pass: edge-to-edge fullscreen and reliable double-tap seeking.
player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the player edge-to-edge.
if ".ignoresSafeArea()" not in p:
    needle = '''            .frame(maxWidth: .infinity, maxHeight: .infinity)\n        }\n        .background(.black)'''
    replacement = '''            .frame(maxWidth: .infinity, maxHeight: .infinity)\n        }\n        .ignoresSafeArea()\n        .background(.black)'''
    if needle in p:
        p = p.replace(needle, replacement, 1)

# Add Nuvio-style double-tap seek zones. Use the view's actual geometry rather
# than UIScreen so this remains correct after rotation and on iPad/split views.
if "SpatialTapGesture(count: 2)" not in p:
    needle = '''        }\n        .background(.black)\n        .statusBarHidden(true)'''
    replacement = '''        }\n        .simultaneousGesture(\n            SpatialTapGesture(count: 2)\n                .onEnded { value in\n                    let width = UIScreen.main.bounds.width\n                    guard width > 0 else { return }\n                    if value.location.x < width / 3 {\n                        seekBy(-10)\n                    } else if value.location.x > width * 2 / 3 {\n                        seekBy(10)\n                    }\n                }\n        )\n        .background(.black)\n        .statusBarHidden(true)'''
    if needle in p:
        p = p.replace(needle, replacement, 1)

# The current seek button has a size parameter, so the older repair's
# parameterless anchor never matched. Insert the shared helper immediately
# before the current seekButton(seconds:size:) implementation.
if "private func seekBy(_ seconds: Int)" not in p:
    anchor = '''    private func seekButton(seconds: Int, size: CGFloat) -> some View {'''
    helper = '''    private func seekBy(_ seconds: Int) {\n        guard playbackError == nil, !controlsLocked else { return }\n        sendCommand(["seek", String(seconds), "relative"])\n        if duration > 0 {\n            position = max(0, min(duration, position + Double(seconds)))\n            ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n        }\n        showControls = true\n        scheduleHide()\n    }\n\n'''
    if anchor in p:
        p = p.replace(anchor, helper + anchor, 1)

# Make visible +/-10 buttons use the same seek path.
old_seek = '''        Button {\n            sendCommand(["seek", String(seconds), "relative"])\n            if duration > 0 {\n                position = max(0, min(duration, position + Double(seconds)))\n                ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n            }\n            scheduleHide()\n        } label: {'''
new_seek = '''        Button {\n            seekBy(seconds)\n        } label: {'''
if old_seek in p:
    p = p.replace(old_seek, new_seek, 1)

# Make any older swipe-seek path use the same helper.
old_swipe = '''                    let seconds = value.translation.width > 0 ? -10 : 10\n                    sendCommand(["seek", String(seconds), "relative"])\n                    if duration > 0 {\n                        position = max(0, min(duration, position + Double(seconds)))\n                        ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n                    }\n                    showControls = true\n                    scheduleHide()'''
new_swipe = '''                    let seconds = value.translation.width > 0 ? -10 : 10\n                    seekBy(seconds)'''
if old_swipe in p:
    p = p.replace(old_swipe, new_swipe, 1)

player.write_text(p, encoding="utf-8")
