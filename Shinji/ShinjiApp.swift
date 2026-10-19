import SwiftUI

@main
struct ShinjiApp: App {
    @StateObject private var addonStore = AddonStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(addonStore)
                .preferredColorScheme(.dark)
        }
    }
}
