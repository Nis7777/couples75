import SwiftUI
import UIKit
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
        return true
    }

    static weak var current: AppDelegate?

    /// Outfit in navigation bars and bar buttons (sheets with a NavigationStack).
    static func styleNavigationBars() {
        let ink = UIColor(red: 0x38 / 255, green: 0x2A / 255, blue: 0x22 / 255, alpha: 1)   // espresso
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

    /// A silent push (the partner wrote something): just fetch. `nonisolated` so the (non-Sendable) payload never crosses to the main
    /// actor; only the completion handler does, boxed.
    nonisolated func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let done = FetchCompletion(completionHandler)
        Task { @MainActor in
            await AppDelegate.current?.model.refresh()
            done.call(.newData)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

/// The window scene (kept so the app has one scene configuration).
final class SceneDelegate: NSObject, UIWindowSceneDelegate {}

/// Carries the push completion handler to the main actor. UIKit allows calling it from any thread.
private final class FetchCompletion: @unchecked Sendable {
    private let handler: (UIBackgroundFetchResult) -> Void
    init(_ handler: @escaping (UIBackgroundFetchResult) -> Void) { self.handler = handler }
    func call(_ result: UIBackgroundFetchResult) { handler(result) }
}
