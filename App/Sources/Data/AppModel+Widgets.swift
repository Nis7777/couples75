import Foundation

/// Interactive widget taps (honour rules ticked off from the Home Screen).
extension AppModel {
    /// Called by `CheckHonourRuleIntent` in the app's process. Saves a real check-in for a tap made at `at`.
    func checkInFromWidget(ruleID: String, at date: Date) async -> Bool {
        guard let item = myToday?.items.first(where: { $0.rule.id == ruleID }) else { return false }
        if item.isChecked { return true }
        guard item.rule.type == .honour else { return false }
        return await checkIn(rule: item.rule, photo: nil, at: date)
    }

    /// Taps the widget couldn't hand to the app right away. Each keeps the time it was made, so the day it
    /// counts for is the day of the tap (and the 6-hour upload window still applies).
    func saveQueuedWidgetCheckIns() async {
        let queued = WidgetCheckIns.drain()
        for q in queued {
            if !(await checkInFromWidget(ruleID: q.ruleID, at: q.at)) {
                // Not today's rule any more (or not honour): drop it.
                continue
            }
        }
    }
}
