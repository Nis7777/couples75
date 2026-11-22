import SwiftUI
import UIKit
import CloudKit
import BackgroundTasks

@main
struct CouplesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    /// The opening animation runs once per launch, on top of the app (which loads underneath it).
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView { showSplash = false }
                        .zIndex(100)
                }
            }
                .environment(delegate.model)
                .onOpenURL { delegate.model.handle(url: $0) }
                .task { await delegate.model.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task { await delegate.model.refresh() }
                    case .background:
                        AppDelegate.scheduleBackgroundRefresh()
                    default:
                        break
                    }
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    let model = AppModel()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationManager.shared.configure()
        AppDelegate.styleNavigationBars()
        NotificationManager.shared.onRoute = { [weak self] route in self?.model.handle(route: route) }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Brand.backgroundRefreshID, using: nil) { task in
            Task { @MainActor in
                AppDelegate.scheduleBackgroundRefresh()
                await AppDelegate.current?.model.refresh()
                task.setTaskCompleted(success: true)
            }
        }
        if !model.isMock { application.registerForRemoteNotifications() }
        AppDelegate.current = self
        // Interactive widget taps run in the app's process and become real check-ins.
        let appModel = self.model
        WidgetCheckIns.appHandler = { ruleID, date in await appModel.checkInFromWidget(ruleID: ruleID, at: date) }
        // Apple Watch: honour check-ins from the wrist.
        WatchSync.shared.onCheckIn = { ruleID, date in
            Task { @MainActor in _ = await appModel.checkInFromWidget(ruleID: ruleID, at: date) }
        }
        WatchSync.shared.activate()
        return true
    }

    static weak var current: AppDelegate?

    /// Outfit in navigation bars and bar buttons (sheets with a NavigationStack).
    static func styleNavigationBars() {
        let ink = UIColor(red: 0x2A / 255, green: 0x18 / 255, blue: 0x14 / 255, alpha: 1)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.font: AppFont.uiFont(17, .semibold), .foregroundColor: ink]
        appearance.largeTitleTextAttributes = [.font: AppFont.uiFont(30, .bold), .foregroundColor: ink]
        let buttons = UIBarButtonItemAppearance()
        buttons.normal.titleTextAttributes = [.font: AppFont.uiFont(17, .medium)]
        appearance.buttonAppearance = buttons
        appearance.doneButtonAppearance = buttons
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Brand.backgroundRefreshID)
        request.earliestBeginDate = Date().addingTimeInterval(60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    /// CloudKit silent push: fetch changes and post local notifications.
    /// CloudKit silent push. The completion-handler form is called on the main actor, so the (non-Sendable)
    /// payload never crosses actors. The payload itself isn't needed: the app fetches the changes.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            await model.refresh()
            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

/// Receives iCloud share links ("userDidAcceptCloudKitShareWith").
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            accept(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        accept(cloudKitShareMetadata)
    }

    private func accept(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            guard let model = AppDelegate.current?.model else { return }
            await model.acceptShare(metadata)
        }
    }
}
