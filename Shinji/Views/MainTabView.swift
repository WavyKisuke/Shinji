import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            LibraryView(kind: .movies)
                .tabItem { Label("Movies", systemImage: "film") }
            LibraryView(kind: .shows)
                .tabItem { Label("Shows", systemImage: "tv") }
            LibraryView(kind: .live)
                .tabItem { Label("Live TV", systemImage: "dot.radiowaves.left.and.right") }
            AddonsView()
                .tabItem { Label("Add-ons", systemImage: "puzzlepiece.extension") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Color(hex: UserDefaults.standard.string(forKey: "shinjiAccentHex") ?? "B64DFF"))
    }
}
