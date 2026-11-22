import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// The evening Live Activity: today's progress for both of us on the Lock Screen and in the Dynamic Island.
struct TodayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var myLeft: Int
        var myTotal: Int
        var partnerLeft: Int
        var partnerTotal: Int
        var day: Int?
    }

    var myName: String
    var partnerName: String
}
#endif
