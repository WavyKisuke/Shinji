from pathlib import Path

# Keep the custom floating navigation bar out of the player route so it cannot
# cover or intercept the player's bottom controls. The UIKit tab-bar hiding in
# PlayerView cannot hide this SwiftUI overlay because MainTabView owns it.

main = Path("Shinji/Views/MainTabView.swift")
text = main.read_text(encoding="utf-8")

if "@State private var playerPresented = false" not in text:
    text = text.replace(
        "    @State private var selectedTab = 0\n",
        "    @State private var selectedTab = 0\n    @State private var playerPresented = false\n",
        1,
    )

old = '''            nuvioTabBar
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
'''
new = '''            if !playerPresented {
                nuvioTabBar
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }
'''
if old in text and "if !playerPresented" not in text:
    text = text.replace(old, new, 1)

if "shinjiPlayerVisibility" not in text:
    marker = "        .preferredColorScheme(.dark)\n"
    replacement = '''        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .shinjiPlayerVisibility)) { notification in
            playerPresented = notification.userInfo?["visible"] as? Bool ?? false
        }
'''
    text = text.replace(marker, replacement, 1)

if "static let shinjiPlayerVisibility" not in text:
    text += '''\n\nextension Notification.Name {
    static let shinjiPlayerVisibility = Notification.Name("ShinjiPlayerVisibility")
}
'''

main.write_text(text, encoding="utf-8")

player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")

appear_marker = "            hideParentTabBar(true)\n            startInternalPlayback()"
appear_replacement = "            hideParentTabBar(true)\n            NotificationCenter.default.post(name: .shinjiPlayerVisibility, object: nil, userInfo: [\"visible\": true])\n            startInternalPlayback()"
if appear_marker in p and "userInfo: [\"visible\": true]" not in p:
    p = p.replace(appear_marker, appear_replacement, 1)

disappear_marker = "            hideParentTabBar(false)\n        }"
disappear_replacement = "            hideParentTabBar(false)\n            NotificationCenter.default.post(name: .shinjiPlayerVisibility, object: nil, userInfo: [\"visible\": false])\n        }"
if disappear_marker in p and "userInfo: [\"visible\": false]" not in p:
    p = p.replace(disappear_marker, disappear_replacement, 1)

player.write_text(p, encoding="utf-8")
