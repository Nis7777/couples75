import Foundation

/// Weekly recap (shown once on Monday) and the App Store review prompt.
extension AppModel {
    /// "Our week" for the 7 days ending yesterday.
    var weeklyRecap: WeeklyRecap? {
        guard let me else { return nil }
        return WeeklyRecap.make(state: state, facts: facts, meID: me.id, partnerID: partner?.id,
                                today: LocalDate(now(), in: me.tz))
    }

    /// On the first open of a Monday, show last week's recap once.
    func evaluateRecap() {
        guard route == .main, presentedRecap == nil, presentedMilestone == nil, let me else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = me.tz
        guard cal.component(.weekday, from: now()) == 2, let recap = weeklyRecap else { return }
        let key = "recap-\(recap.id)"
        guard !SeenEvents.contains(key) else { return }
        SeenEvents.insert([key])
        presentedRecap = recap
    }
}

/// Asks for an App Store rating at a happy moment (a good week, a milestone), at most every 120 days.
enum ReviewPrompt {
    private static let key = "lastReviewPromptAt"
    static let minimumInterval: TimeInterval = 120 * 86_400

    static var canAsk: Bool {
        guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return true }
        return Date().timeIntervalSince(last) > minimumInterval
    }

    static func markAsked() { UserDefaults.standard.set(Date(), forKey: key) }
}
