import Foundation

/// "Our week": the last 7 settled local days for both partners (pure, computed from the engine state).
struct WeeklyRecap: Equatable, Identifiable {
    struct Person: Equatable {
        var name: String
        var completeDays: Int
        var countedDays: Int
        var photos: Int
        var reactionsReceived: Int
    }

    var weekStart: LocalDate          // the first of the 7 days
    var me: Person
    var partner: Person?
    var savesUsed: Int
    var streak: Int
    var id: String { weekStart.string }

    /// Both complete on the same day, for "x of 7 together".
    var bothCompleteDays: Int

    var headline: String {
        let mine = me.completeDays
        switch mine {
        case 7: return "A perfect week."
        case 5...6: return "A strong week."
        case 3...4: return "Halfway there. Next week's yours."
        default: return "A tough week. Fresh start today."
        }
    }

    /// The 7 days ending yesterday (my time zone).
    static func make(state: EngineState, facts: Facts, meID: MemberID, partnerID: MemberID?, today: LocalDate) -> WeeklyRecap? {
        let start = today.adding(-7)
        let window = (0..<7).map { start.adding($0) }
        let windowSet = Set(window.map(\.string))
        func person(_ id: MemberID) -> (Person, Set<String>) {
            let days = state.rounds.flatMap { $0.member(id)?.days ?? [] }.filter { windowSet.contains($0.date.string) }
            let counted = days.filter { $0.dayNumber != nil }
            let completeDates = Set(counted.filter { $0.outcome == .complete }.map(\.date.string))
            let checkIns = facts.checkIns.filter { $0.memberID == id && windowSet.contains($0.localDate) && !$0.isWarmup }
            let ids = Set(checkIns.map(\.id))
            let reactions = facts.reactions.filter { ids.contains($0.checkInID) && $0.memberID != id && $0.kind != .seen }
            let name = facts.member(id)?.name ?? ""
            return (Person(name: name, completeDays: completeDates.count, countedDays: counted.count,
                           photos: checkIns.filter(\.hasPhoto).count, reactionsReceived: reactions.count), completeDates)
        }
        let (mine, myDates) = person(meID)
        guard mine.countedDays > 0 else { return nil }
        var partner: Person?
        var both = 0
        if let p = partnerID {
            let (pp, pDates) = person(p)
            partner = pp
            both = myDates.intersection(pDates).count
        }
        let saves = state.rounds.flatMap(\.saveEvents).filter { windowSet.contains($0.date.string) }.count
        return WeeklyRecap(weekStart: start, me: mine, partner: partner, savesUsed: saves, streak: state.streak,
                           bothCompleteDays: both)
    }
}

/// Per-rule reminder times ("Meditate at 07:00"). Stored on this phone; reminders are local notifications.
enum RuleReminders {
    private static let key = "ruleReminderTimes"

    /// Stable across rounds: position + title.
    static func key(for rule: RuleFact) -> String { "\(rule.position)|\(rule.title)" }

    static var all: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func time(for rule: RuleFact) -> String? { all[key(for: rule)] }

    static func set(_ time: String?, for rule: RuleFact) {
        var a = all
        a[key(for: rule)] = time
        all = a
    }

    static func wipe() { UserDefaults.standard.removeObject(forKey: key) }
}
