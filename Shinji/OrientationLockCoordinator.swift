import UIKit

private let lockPlayerToLandscapeNotification = Notification.Name("ShinjiPlayerLockLandscape")
private let unlockPlayerOrientationNotification = Notification.Name("ShinjiPlayerUnlockOrientation")
private let playerDidAppearNotification = Notification.Name("ShinjiPlayerDidAppear")

final class OrientationLockAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        OrientationLockCoordinator.shared.start()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLockCoordinator.shared.supportedOrientations
    }
}

final class OrientationLockCoordinator {
    static let shared = OrientationLockCoordinator()

    private(set) var supportedOrientations: UIInterfaceOrientationMask = .portrait
    private var observers: [NSObjectProtocol] = []
    private var playerIsActive = false
    private var playerWantsLandscape = false

    private init() {}

    func start() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: playerDidAppearNotification, object: nil, queue: .main) { [weak self] _ in
                self?.playerIsActive = true
            }
        )
        observers.append(
            center.addObserver(forName: lockPlayerToLandscapeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.playerIsActive = true
                self?.playerWantsLandscape = true
                self?.setPlayerOrientation(landscape: true)
            }
        )
        observers.append(
            center.addObserver(forName: unlockPlayerOrientationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.playerIsActive = false
                self?.playerWantsLandscape = false
                self?.setPlayerOrientation(landscape: false)
            }
        )
        observers.append(
            center.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.playerIsActive else { return }
                switch UIDevice.current.orientation {
                case .landscapeLeft, .landscapeRight:
                    if !self.playerWantsLandscape {
                        self.playerWantsLandscape = true
                        self.setPlayerOrientation(landscape: true)
                    }
                case .portrait, .portraitUpsideDown:
                    if self.playerWantsLandscape {
                        self.playerWantsLandscape = false
                        self.setPlayerOrientation(landscape: false)
                    }
                default:
                    break
                }
            }
        )
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    static func playerDidAppear() {
        NotificationCenter.default.post(name: playerDidAppearNotification, object: nil)
    }

    static func setPlayerFullscreen(_ enabled: Bool) {
        NotificationCenter.default.post(
            name: enabled ? lockPlayerToLandscapeNotification : unlockPlayerOrientationNotification,
            object: nil
        )
    }

    private func setPlayerOrientation(landscape: Bool) {
        supportedOrientations = landscape ? .landscape : .portrait

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        windowScene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }

        if #available(iOS 16.0, *) {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: supportedOrientations)
            windowScene.requestGeometryUpdate(preferences) { error in
                if let error {
                    print("[OrientationLockCoordinator] Geometry update failed: \(error.localizedDescription)")
                }
            }
        }

        let orientation: UIInterfaceOrientation = landscape ? preferredLandscapeOrientation : .portrait
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

    private var preferredLandscapeOrientation: UIInterfaceOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            if let sceneOrientation = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.interfaceOrientation })
                .first(where: { $0.isLandscape }) {
                return sceneOrientation
            }
            return .landscapeRight
        }
    }
}
