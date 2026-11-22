import Foundation
import ActivityKit

/// The evening Live Activity: from 17:00, while rules are left today, both partners' progress sits on the
/// Lock Screen and in the Dynamic Island. It ends when I'm done or at midnight. Started and updated by the
/// app (there is no push server), so it appears the first time the app is opened after 17:00.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    static let startHour = 17

    func update(model: AppModel) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let current = Activity<TodayActivityAttributes>.activities
        guard Prefs.liveActivityOn, let today = model.myToday, today.dayNumber != nil,
              !model.state.isFrozen, !today.isPaused else {
            await endAll(current)
            return
        }
        let partner = model.partnerToday
        let state = TodayActivityAttributes.ContentState(
            myLeft: today.remaining, myTotal: today.items.count,
            partnerLeft: partner?.remaining ?? 0, partnerTotal: partner?.items.count ?? 0,
            day: today.dayNumber)
        let tz = model.me?.tz ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let now = Date()
        let midnight = cal.startOfDay(for: now).addingTimeInterval(86_400)
        let content = ActivityContent(state: state, staleDate: midnight)

        if today.remaining == 0 {
            for a in current { await a.end(content, dismissalPolicy: .after(now.addingTimeInterval(30 * 60))) }
            return
        }
        if let a = current.first {
            await a.update(content)
            return
        }
        guard cal.component(.hour, from: now) >= Self.startHour else { return }
        let attributes = TodayActivityAttributes(myName: model.me?.name ?? "", partnerName: model.partnerName)
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    private func endAll(_ list: [Activity<TodayActivityAttributes>]) async {
        for a in list { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
