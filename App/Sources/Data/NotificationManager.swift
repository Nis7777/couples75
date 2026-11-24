import Foundation
import UserNotifications

/// Local notifications (section 5). Partner events arrive as CloudKit silent pushes (or on any fetch)
/// and are turned into local notifications here.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    /// Called when the user taps a notification. Set by the app.
    var onRoute: ((String) -> Void)?

    private enum ID {
        static let wakePrefix = "wake-"
        static let evening = "evening-warning"
        static let rulePrefix = "rule-reminder-"
        static let recap = "weekly-recap"
        static let nudgePrefix = "invite-nudge-"
    }

    override private init() {
        super.init()
    }

    func configure() {
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Trial reminder

    private static let trialEndKey = "trialEndsAt"

    /// "We'll remind you 1 day before your trial ends" (the paywall's promise).
    /// Stored so it's (re)scheduled once notifications are allowed.
    func scheduleTrialReminder(trialEnd: Date) {
        UserDefaults.standard.set(trialEnd, forKey: Self.trialEndKey)
        Task { await addTrialReminderIfNeeded() }
    }

    private func addTrialReminderIfNeeded() async {
        guard let end = UserDefaults.standard.object(forKey: Self.trialEndKey) as? Date else { return }
        let fire = max(end.addingTimeInterval(-24 * 3600), Date().addingTimeInterval(3600))
        guard fire < end, await authorizationStatus() == .authorized else { return }
        schedule(id: "trial-reminder", title: Brand.appName,
                 body: "Your free trial ends tomorrow. Nothing to do if you're staying; you can cancel anytime in Settings.",
                 at: fire, route: "profile")
    }

    // MARK: - Scheduled reminders

    /// Rebuilds the wake-up reminder, the 21:00 warning and A's invite nudges from the current state.
    func reschedule(model: AppModel) async {
        guard await authorizationStatus() == .authorized else { return }
        let pending = await center.pendingNotificationRequests().map { $0.identifier }
        let ours = pending.filter { $0.hasPrefix(ID.wakePrefix) || $0 == ID.evening || $0.hasPrefix(ID.nudgePrefix)
            || $0.hasPrefix(ID.rulePrefix) || $0 == ID.recap }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        await addTrialReminderIfNeeded()
        guard let me = model.me, me.leftAt == nil else { return }

        let now = Date()
        let cal = Calendar.current
        let today = model.myToday
        let ruleCount = today?.items.count ?? 4

        // Wake-up reminder ("Daily reminder"): today (if still ahead) and tomorrow.
        for offset in 0...1 where Prefs.dailyReminderOn {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let fire = ClockTime.date(from: me.wakeTime, on: day)
            guard fire > now else { continue }
            var dayNumber = today?.dayNumber
            if offset == 1, let n = dayNumber { dayNumber = n + 1 }
            if model.state.phase != .active && model.state.phase != .warmup && model.state.phase != .betweenRounds {
                continue
            }
            var body = dayNumber.map { "Day \($0). \(ruleCount) rules today." } ?? "\(ruleCount) rules today."
            if offset == 0, let p = model.partnerToday, p.items.contains(where: { $0.isChecked }) {
                body += " \(model.partnerName) is already up."
            }
            schedule(id: ID.wakePrefix + "\(offset)", title: Brand.appName, body: body, at: fire, route: "today")
        }

        // 21:00 warning, only if rules are left today (or the daily progress pic, for people who take them).
        let picMissing = !model.progress.photos.isEmpty && model.myProgressToday == nil
        if Prefs.eveningWarningOn, let t = today, t.dayNumber != nil, t.remaining > 0 || picMissing {
            let fire = ClockTime.date(from: Brand.eveningWarning, on: now)
            if fire > now {
                let hours = max(1, Int(ceil(cal.startOfDay(for: now).addingTimeInterval(86_400).timeIntervalSince(fire) / 3600)))
                let body: String
                if t.remaining > 0 {
                    let rules = t.remaining == 1 ? "1 rule" : "\(t.remaining) rules"
                    body = "\(rules) left\(picMissing ? " and your progress pic" : ""). \(hours) hours to go."
                } else {
                    body = "Rules done. Just your progress pic left. \(hours) hours to go."
                }
                schedule(id: ID.evening, title: Brand.appName, body: body, at: fire, route: "today")
            }
        }

        // Per-rule reminder times: today (if the rule isn't done yet) and tomorrow.
        if let t = today, t.dayNumber != nil || model.isWarmup {
            for item in t.items {
                guard let time = RuleReminders.time(for: item.rule) else { continue }
                for offset in 0...1 {
                    if offset == 0 && item.isChecked { continue }
                    guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
                    let fire = ClockTime.date(from: time, on: day)
                    guard fire > now else { continue }
                    schedule(id: ID.rulePrefix + "\(item.rule.position)-\(offset)", title: Brand.appName,
                             body: "Time for \(item.rule.title).", at: fire, route: "today")
                }
            }
        }

        // Weekly recap: Monday 09:00 local.
        if model.partner?.joinedAt != nil, Prefs.weeklyRecapOn {
            var comps = DateComponents()
            comps.weekday = 2
            comps.hour = 9
            if let fire = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) {
                schedule(id: ID.recap, title: Brand.appName, body: "Your week together is ready. See your recap.",
                         at: fire, route: "progress")
            }
        }

        // A's invite nudges on days 1, 3 and 6 after paying.
        if model.isOwner, model.memberB?.joinedAt == nil,
           let paid = UserDefaults.standard.object(forKey: Prefs.invitePaidAtKey) as? Date {
            for d in [1, 3, 6] {
                guard let day = cal.date(byAdding: .day, value: d, to: paid) else { continue }
                let fire = cal.date(bySettingHour: 18, minute: 30, second: 0, of: day) ?? day
                if fire > now {
                    schedule(id: ID.nudgePrefix + "\(d)", title: Brand.appName,
                             body: "Nudge \(model.nameB)? Your plan is waiting.", at: fire, route: "today")
                }
            }
        }
    }

    private func schedule(id: String, title: String, body: String, at date: Date, route: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["route": route]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func post(_ body: String, route: String) {
        let content = UNMutableNotificationContent()
        content.title = Brand.appName
        content.body = body
        content.sound = .default
        content.userInfo = ["route": route]
        center.add(UNNotificationRequest(identifier: "event-\(UUID().uuidString)", content: content, trigger: nil))
    }

    // MARK: - Partner events

    /// Compares facts/state before and after a fetch and posts a local notification for each partner event.
    func postPartnerEvents(oldFacts: Facts, newFacts: Facts, oldState: EngineState, newState: EngineState,
                           meID: MemberID, isInitial: Bool) async {
        guard !isInitial, oldFacts != newFacts || oldState != newState else { return }
        guard await authorizationStatus() == .authorized else { return }
        guard let partner = newFacts.members.first(where: { $0.id != meID }) else { return }
        let name = partner.name
        func ruleTitle(_ id: String) -> String { newFacts.rules.first { $0.id == id }?.title ?? "a rule" }

        let oldCheckIns = Set(oldFacts.checkIns.map { $0.id })
        for c in newFacts.checkIns where Prefs.partnerCheckInNotifsOn && !oldCheckIns.contains(c.id)
            && c.memberID == partner.id {
            // Only a photo asks for a look; a tap is just news.
            post(c.hasPhoto ? "\(name) finished \(ruleTitle(c.ruleID)). Take a look?" : "\(name) finished \(ruleTitle(c.ruleID)) ✓",
                 route: "checkin:\(c.id)")
        }

        let oldReactions = Set(oldFacts.reactions.map { $0.id })
        let myCheckIns = Dictionary(uniqueKeysWithValues: newFacts.checkIns.filter { $0.memberID == meID }.map { ($0.id, $0) })
        for r in newFacts.reactions where !oldReactions.contains(r.id) && r.memberID == partner.id {
            guard let c = myCheckIns[r.checkInID] else { continue }
            let rule = ruleTitle(c.ruleID)
            switch r.kind {
            case .approve: post("\(name) approved your \(rule) ❤️", route: "checkin:\(c.id)")
            case .emoji: post("\(name) reacted \(r.emoji ?? "") to your \(rule)", route: "checkin:\(c.id)")
            case .comment: post("\(name): \"\(r.comment ?? "")\"", route: "checkin:\(c.id)")
            case .sus: post("\(name) thinks that's sus 🤨", route: "checkin:\(c.id)")
            case .seen: break
            }
        }

        let oldPauses = Set(oldFacts.pauses.map { $0.id })
        for p in newFacts.pauses where !oldPauses.contains(p.id) && p.requestedBy == partner.id {
            post("\(name) asked to pause. Agree?", route: "pause")
        }
        let oldPauseAnswers = Set(oldFacts.pauseAnswers.map { $0.id })
        for a in newFacts.pauseAnswers where !oldPauseAnswers.contains(a.id) {
            guard newFacts.pauses.first(where: { $0.id == a.pauseID })?.requestedBy == meID else { continue }
            post(a.accepted ? "\(name) agreed to pause." : "\(name) said not now to the pause.", route: "today")
        }

        let oldTweaks = Set(oldFacts.tweaks.map { $0.id })
        for t in newFacts.tweaks where !oldTweaks.contains(t.id) && t.proposedBy == partner.id {
            post("\(name) suggested a change to the plan.", route: "tweak")
        }
        let oldTweakAnswers = Set(oldFacts.tweakAnswers.map { $0.id })
        for a in newFacts.tweakAnswers where !oldTweakAnswers.contains(a.id) {
            guard newFacts.tweaks.first(where: { $0.id == a.tweakID })?.proposedBy == meID else { continue }
            post(a.accepted ? "\(name) accepted your change." : "\(name) kept the original plan.", route: "today")
        }

        let oldNudges = Set(oldFacts.nudges.map { $0.id })
        for n in newFacts.nudges where !oldNudges.contains(n.id) && n.from == partner.id && n.to == meID {
            switch n.kind {
            case .nudge: post("\(name) nudged you 👀 \(n.text ?? "Your rules are waiting.")", route: "today")
            case .note: post("\(name): \(n.text ?? "❤️")", route: "today")
            }
        }

        let oldProposals = Set(oldFacts.ruleProposals.map { $0.id })
        for p in newFacts.ruleProposals where !oldProposals.contains(p.id) && p.proposedBy == partner.id {
            post("\(name) suggested a new rule. Approve?", route: "proof")
        }
        let oldRuleAnswers = Set(oldFacts.ruleAnswers.map { $0.id })
        for a in newFacts.ruleAnswers where !oldRuleAnswers.contains(a.id) {
            guard let p = newFacts.ruleProposals.first(where: { $0.id == a.proposalID }), p.proposedBy == meID else { continue }
            post(a.accepted ? "\(name) approved \(p.rule.title). It starts tomorrow." : "\(name) kept the original rule.",
                 route: a.accepted ? "today" : "proof")
        }

        if oldFacts.memberB?.joinedAt == nil, let b = newFacts.memberB, b.joinedAt != nil, b.id != meID {
            post("\(b.name) joined! Day 1 starts tomorrow.", route: "today")
        }

        // Only when the COUPLE's subscription actually ends and the partner was the one paying. (Not when the
        // partner merely has no subscription of their own: the invited partner never pays, the payer covers both.)
        if oldState.coupleActive, !newState.coupleActive, partner.joinedAt != nil,
           (oldState.payerID ?? newState.payerID) == partner.id {
            post("\(name)'s subscription ended. Your run is paused until they renew.", route: "today")
        }

        let oldSaves = Set(oldState.allSaveEvents.map { $0.id })
        for s in newState.allSaveEvents where !oldSaves.contains(s.id) {
            let who = s.memberID == meID ? "You" : name
            post("Save used. \(who) missed a rule on Day \(s.dayNumber).", route: "today")
        }

        if let r = newState.lastFinishedRound, oldState.lastFinishedRound?.number != r.number {
            switch r.status {
            case .completed where !r.mode.isMaintenance:
                post("Day \(r.length). You finished \(Challenges.challenge(r.challengeID)?.title ?? "the challenge")!", route: "today")
            case .failed:
                post("\(Challenges.challenge(r.challengeID)?.title ?? "The challenge") is over on Day \(r.failedOnDay ?? 0). Back to your habits tomorrow.", route: "today")
            default: break
            }
        }

        if oldFacts.member(partner.id)?.leftAt == nil, partner.leftAt != nil {
            post("\(name) left the couple.", route: "today")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let route = response.notification.request.content.userInfo["route"] as? String ?? "today"
        Task { @MainActor in
            NotificationManager.shared.onRoute?(route)
        }
        completionHandler()
    }
}
