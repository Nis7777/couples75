import Foundation
import WatchConnectivity

/// Keeps the Apple Watch app up to date (today's rules, the day, the partner) and turns honour check-ins
/// made on the watch into real check-ins, with the time they were tapped.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()
    /// Set by the app: saves a watch tap as a check-in.
    var onCheckIn: ((String, Date) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(_ payload: WatchPayload) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled,
              let data = payload.encoded() else { return }
        try? WCSession.default.updateApplicationContext([WatchPayload.contextKey: data])
    }

    private func handle(_ info: [String: Any]) {
        guard let id = info[WatchMessage.checkInRuleID] as? String else { return }
        let at = (info[WatchMessage.checkInAt] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        DispatchQueue.main.async { self.onCheckIn?(id, at) }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { handle(message) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { handle(userInfo) }
}
