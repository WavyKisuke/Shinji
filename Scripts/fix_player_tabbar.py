from pathlib import Path

# Hide Shinji's custom floating tab bar while PlayerView is on screen.
# UIKit tab-bar hiding alone cannot affect this SwiftUI overlay.

main = Path("Shinji/Views/MainTabView.swift")
text = main.read_text(encoding="utf-8")

if "@State private var playerPresented = false" not in text:
    text = text.replace(
        "    @State private var selectedTab = 0\n",
        "    @State private var selectedTab = 0\n    @State private var playerPresented = false\n",
        1,
    )

if "if !playerPresented {" not in text:
    old = '''            tabBar
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
'''
    new = '''            if !playerPresented {
                tabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
'''
    if old in text:
        text = text.replace(old, new, 1)

if "shinjiPlayerVisibility" not in text:
    marker = "        .preferredColorScheme(.dark)\n"
    replacement = '''        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .shinjiPlayerVisibility)) { notification in
            withAnimation(.easeInOut(duration: 0.18)) {
                playerPresented = notification.userInfo?["visible"] as? Bool ?? false
            }
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

if 'userInfo: ["visible": true]' not in p:
    marker = "            hideParentTabBar(true)\n            startInternalPlayback()"
    replacement = "            hideParentTabBar(true)\n            NotificationCenter.default.post(name: .shinjiPlayerVisibility, object: nil, userInfo: [\"visible\": true])\n            startInternalPlayback()"
    p = p.replace(marker, replacement, 1)

if 'userInfo: ["visible": false]' not in p:
    marker = "            hideParentTabBar(false)\n        }"
    replacement = "            hideParentTabBar(false)\n            NotificationCenter.default.post(name: .shinjiPlayerVisibility, object: nil, userInfo: [\"visible\": false])\n        }"
    p = p.replace(marker, replacement, 1)

player.write_text(p, encoding="utf-8")
