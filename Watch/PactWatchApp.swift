import SwiftUI
import WatchConnectivity
import WatchKit

@main
struct PactWatchApp: App {
    @StateObject private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchTodayView()
                .environmentObject(store)
        }
    }
}

/// The Pact palette on the Watch's black background (docs/BRAND.md): coral for done/progress, sage for the
/// partner, sand for the day number.
enum WatchColors {
    static let coral = Color(red: 0xE2 / 255, green: 0x70 / 255, blue: 0x4C / 255)
    static let sage = Color(red: 0x90 / 255, green: 0x9C / 255, blue: 0x78 / 255)
    static let gold = Color(red: 0xE6 / 255, green: 0xC2 / 255, blue: 0x8E / 255)
}

/// Receives today's payload from the iPhone and sends honour check-ins back.
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var payload: WatchPayload?
    @Published var sentRuleIDs: Set<String> = []

    private static let cacheKey = "watchPayload"

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) { payload = WatchPayload.decode(data) }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func checkIn(_ rule: WatchPayload.Rule) {
        let info: [String: Any] = [WatchMessage.checkInRuleID: rule.id, WatchMessage.checkInAt: Date().timeIntervalSince1970]
        sentRuleIDs.insert(rule.id)
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(info, replyHandler: nil) { _ in session.transferUserInfo(info) }
        } else {
            // Delivered when the phone is back; the tap time travels with it.
            session.transferUserInfo(info)
        }
        WKInterfaceDeviceHaptic.success()
    }

    private func apply(_ context: [String: Any]) {
        guard let data = context[WatchPayload.contextKey] as? Data, let p = WatchPayload.decode(data) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
        DispatchQueue.main.async {
            self.payload = p
            self.sentRuleIDs = self.sentRuleIDs.filter { id in p.rules.contains { $0.id == id && !$0.done } }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }
}

/// WatchKit haptics without importing WatchKit everywhere.
enum WKInterfaceDeviceHaptic {
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }
}
