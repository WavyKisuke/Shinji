from pathlib import Path

# Player polish pass: edge-to-edge fullscreen, reliable double-tap seeking,
# and a small helper that keeps the timeline/buttons in sync with MPV.
player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

# Keep the video truly edge-to-edge in landscape/fullscreen instead of leaving
# a safe-area strip that can make controls look vertically misaligned.
needle = '''            .frame(maxWidth: .infinity, maxHeight: .infinity)\n        }\n        .background(.black)'''
replacement = '''            .frame(maxWidth: .infinity, maxHeight: .infinity)\n        }\n        .ignoresSafeArea()\n        .background(.black)'''
if needle in p and ".ignoresSafeArea()" not in p:
    p = p.replace(needle, replacement, 1)

# Add YouTube/Nuvio-style double-tap seek zones. A double tap on the left or
# right third skips 10 seconds; the existing single tap still toggles controls.
old_root = '''            .frame(maxWidth: .infinity, maxHeight: .infinity)\n        }\n        .ignoresSafeArea()\n        .background(.black)'''
new_root = '''            .frame(maxWidth: .infinity, maxHeight: .infinity)\n        }\n        .ignoresSafeArea()\n        .simultaneousGesture(\n            SpatialTapGesture(count: 2)\n                .onEnded { value in\n                    let width = UIScreen.main.bounds.width\n                    guard width > 0 else { return }\n                    if value.location.x < width / 3 {\n                        seekBy(-10)\n                    } else if value.location.x > width * 2 / 3 {\n                        seekBy(10)\n                    }\n                }\n        )\n        .background(.black)'''
if old_root in p and "SpatialTapGesture(count: 2)" not in p:
    p = p.replace(old_root, new_root, 1)

# Centralize seek behavior so buttons and gestures use the same optimistic
# position update and MPV command, avoiding slider snap-back after a seek.
anchor = '''    private func seekButton(seconds: Int) -> some View {'''
helper = '''    private func seekBy(_ seconds: Int) {\n        guard playbackError == nil, !controlsLocked else { return }\n        sendCommand(["seek", String(seconds), "relative"])\n        if duration > 0 {\n            position = max(0, min(duration, position + Double(seconds)))\n            ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n        }\n        showControls = true\n        scheduleHide()\n    }\n\n'''
if anchor in p and "private func seekBy(_ seconds: Int)" not in p:
    p = p.replace(anchor, helper + anchor, 1)

# Use the centralized helper for the visible +/-10 buttons.
old_seek = '''        Button {\n            sendCommand(["seek", String(seconds), "relative"])\n            if duration > 0 {\n                position = max(0, min(duration, position + Double(seconds)))\n                ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n            }\n            scheduleHide()\n        } label: {'''
new_seek = '''        Button {\n            seekBy(seconds)\n        } label: {'''
if old_seek in p:
    p = p.replace(old_seek, new_seek, 1)

# Make the swipe-seek path use the same helper as the buttons/double taps.
old_swipe = '''                    let seconds = value.translation.width > 0 ? -10 : 10\n                    sendCommand(["seek", String(seconds), "relative"])\n                    if duration > 0 {\n                        position = max(0, min(duration, position + Double(seconds)))\n                        ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)\n                    }\n                    showControls = true\n                    scheduleHide()'''
new_swipe = '''                    let seconds = value.translation.width > 0 ? -10 : 10\n                    seekBy(seconds)'''
if old_swipe in p:
    p = p.replace(old_swipe, new_swipe, 1)

player.write_text(p, encoding="utf-8")
