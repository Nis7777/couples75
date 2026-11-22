import Foundation

/// What the iPhone sends to the Apple Watch (WatchConnectivity application context): today at a glance.
/// Compiled into both the iPhone app and the Watch app.
struct WatchPayload: Codable, Equatable {
    struct Rule: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var isHonour: Bool
        var done: Bool
    }

    var day: Int?
    var roundLength: Int
    var streak: Int
    var myName: String
    var partnerName: String
    var partnerLeft: Int
    var partnerTotal: Int
    var rules: [Rule]
    var updatedAt: Date

    var myLeft: Int { rules.filter { !$0.done }.count }

    static let contextKey = "payload"

    func encoded() -> Data? {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return try? e.encode(self)
    }

    static func decode(_ data: Data) -> WatchPayload? {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(WatchPayload.self, from: data)
    }
}

/// Watch → iPhone: tick off an honour rule (sent as a message, or as queued user info when the phone is away).
enum WatchMessage {
    static let checkInRuleID = "checkInRuleID"
    static let checkInAt = "checkInAt"
    /// Honour rules open at 18:00 local, same as on the phone.
    static let honourOpensAtHour = 18
}
