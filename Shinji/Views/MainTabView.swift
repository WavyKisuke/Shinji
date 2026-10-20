import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeLibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
            UnifiedLibraryView(kind: .movies)
                .tabItem { Label("Movies", systemImage: "film") }
            UnifiedLibraryView(kind: .tvShows)
                .tabItem { Label("TV Shows", systemImage: "play.tv") }
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
