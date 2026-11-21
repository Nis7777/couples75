import SwiftUI
import UIKit
import CloudKit
import BackgroundTasks

@main
struct CouplesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
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
        return true
    }

    static weak var current: AppDelegate?

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
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await model.refresh()
        return .newData
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
