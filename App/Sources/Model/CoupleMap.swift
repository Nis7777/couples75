import Foundation

// The couple map: six axes per partner, 0–100. Starting values come from each partner's own habits (synced to both
// phones, so both phones draw the same map); after that they move with real check-ins, never more than 5 points a
// day. Every number lives in `CoupleMapScoring`.

enum MapAxis: String, CaseIterable, Identifiable {
    case body, mind, rest, fuel, connection, discipline
    var id: String { rawValue }

    var title: String {
        switch self {
        case .body: return "Body"
        case .mind: return "Mind"
        case .rest: return "Rest"
        case .fuel: return "Fuel"
        case .connection: return "Connection"
        case .discipline: return "Discipline"
        }
    }
}

typealias MapScores = [MapAxis: Double]

enum CoupleMapScoring {
    /// Where every axis starts before habits are taken into account.
    static let base: MapScores = [.body: 56, .mind: 58, .rest: 55, .fuel: 54, .connection: 60, .discipline: 52]
    /// Each habit you have in an area means you want to work on it: that axis starts lower by this much.
    static let perHabitDrop: Double = 9
    static let floor: Double = 18
    /// Fastest change per day once real check-ins come in.
    static let maxDailyStep: Double = 5
    /// Check-ins in the last N days drive the targets.
    static let window = 14
    /// How far above or below the start a perfect / an empty record pushes an axis.
    static let swing: Double = 38

    /// The axis a habit (library key) works on. Custom habits count as Discipline.
    static func axis(for libraryKey: String) -> MapAxis {
        switch libraryKey {
        case "workout", "steps", "posture", "stretch", "coldShower": return .body
        case "noJunk", "noSugar", "water", "protein", "cookAtHome", "noAlcohol", "noTakeaway": return .fuel
        case "sleep23", "bedtime", "noPhoneInBed", "meditate": return .rest
        case "reading", "skill", "study", "language", "instrument", "journal", "lessSocial", "noSocialNight": return .mind
        default: return .discipline   // noSpend, saveMoney, skincare, progressPic, custom
        }
    }

    /// Connection's start: longer together starts higher; a harder level means you're up for more.
    static func connectionStart(together: String?, level: String?) -> Double {
        var v = 58.0
        switch together {
        case "<1 yr": v = 54
        case "1–3 yrs": v = 60
        case "3+ yrs": v = 66
        default: break
        }
        switch level {
        case "gentle": v -= 4
        case "hard": v += 4
        default: break
        }
        return v
    }

    /// Day 1 values for one partner from their habit keys.
    static func start(habitKeys: [String], together: String?, level: String?) -> MapScores {
        var s = base
        for key in habitKeys {
            let a = axis(for: key)
            s[a] = max(floor, (s[a] ?? 50) - perHabitDrop)
        }
        s[.connection] = connectionStart(together: together, level: level)
        return s
    }

    /// What 90 days of checking in every day would do (the onboarding projection): every axis you have habits in
    /// rises most; the rest rise a little; Connection rises with doing it together.
    static func projected(from start: MapScores, habitKeys: [String]) -> MapScores {
        let worked = Set(habitKeys.map(axis(for:)))
        var out: MapScores = [:]
        for a in MapAxis.allCases {
            let v = start[a] ?? 50
            let gain: Double = a == .connection ? 26 : (worked.contains(a) ? 36 : 14)
            out[a] = min(96, v + gain)
        }
        return out
    }
}

/// One partner's map over time, from real data.
struct CoupleMapHistory {
    var start: MapScores
    var now: MapScores

    /// Walks the given days (yyyy-MM-dd, oldest first): each day every axis moves (≤ 5 points) toward a target set
    /// by the last 14 days of check-ins in that area (done ÷ planned). Axes without habits stay where they started;
    /// Connection's target rises with the days you both checked in and cheered each other on (`connectionByDay`, 0…1).
    static func compute(start: MapScores, dailyHabitCount: [MapAxis: Int],
                        doneByDay: [String: [MapAxis: Int]], connectionByDay: [String: Double],
                        days: [String]) -> CoupleMapHistory {
        var value = start
        for i in days.indices {
            let window = days[max(0, i - CoupleMapScoring.window + 1)...i]
            for a in MapAxis.allCases {
                let s = start[a] ?? 50
                let target: Double
                if a == .connection {
                    let c = window.map { connectionByDay[$0] ?? 0 }.reduce(0, +) / Double(window.count)
                    target = min(98, s + CoupleMapScoring.swing * c)
                } else {
                    let planned = (dailyHabitCount[a] ?? 0) * window.count
                    guard planned > 0 else { continue }
                    let done = window.map { doneByDay[$0]?[a] ?? 0 }.reduce(0, +)
                    let rate = min(1, Double(done) / Double(planned))
                    target = min(98, max(CoupleMapScoring.floor, s + CoupleMapScoring.swing * (rate * 2 - 1) / 2 + 10 * rate))
                }
                let v = value[a] ?? s
                let step = max(-CoupleMapScoring.maxDailyStep, min(CoupleMapScoring.maxDailyStep, target - v))
                value[a] = v + step
            }
        }
        return CoupleMapHistory(start: start, now: value)
    }
}

/// What the map shows for the couple: each partner's Day 1 and Now (nil for a partner who hasn't answered yet).
struct CoupleMapData: Equatable {
    var nameA: String
    var nameB: String
    var startA: MapScores
    var nowA: MapScores
    var startB: MapScores?
    var nowB: MapScores?
}
