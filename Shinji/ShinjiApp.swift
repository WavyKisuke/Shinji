import SwiftUI

@main
struct ShinjiApp: App {
    @UIApplicationDelegateAdaptor(OrientationLockAppDelegate.self) private var orientationDelegate
    @StateObject private var addonStore = AddonStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(addonStore)
                .preferredColorScheme(.dark)
        }
    }
}
