import Foundation

#if DEBUG
/// Debug menu actions (section 7). They only write ordinary facts, so the same RulesEngine computes everything.
extension AppModel {

    func debugActAs(_ role: MemberRole) {
        guard isMock, let target = facts.members.first(where: { $0.role == role }) else { return }
        Identity.setMockActing(target.id)
        meIDReset()
        onboardingDone = true
        recompute()
        writeWidgetSnapshot()
    }

    /// A is waiting: make the simulated partner join (with a subscription).
    func debugSimulatePartnerJoin() async {
        guard isMock, let a = memberA, memberB == nil || memberB?.joinedAt == nil else { return }
        let now = self.now()
        let periods = MockData.farFutureSubscription(from: now)
        var b = MemberFact(id: a.id == MockData.simulatedB ? MockData.simulatedA : MockData.simulatedB, role: .b,
                           name: facts.couple?.invitedName ?? "Joao", characterID: "m1",
                           timeZone: TimeZone.current.identifier, wakeTime: "07:30", fitnessLevel: .somewhatActive,
                           joinedAt: now, subscribedUntil: periods.last?.end,
                           subscriptionProduct: Brand.iapMonthly, subscriptionPeriods: periods, leftAt: nil)
        // Exactly the rules A's plan stored for B (one source of truth).
        var rules = PlanGenerator.joinerRules(from: draftRulesForB, memberID: b.id, now: now)
        if rules.isEmpty {
            rules = PlanGenerator.rules(keys: PlanGenerator.ruleKeys(goals: [.fitness]), memberID: b.id,
                                        intensity: .gentle, round: 1, now: now)
        }
        if let avatar = facts.couple?.invitedAvatar { b.avatar = avatar }
        await save([FactRecord.member(b)] + rules.map { FactRecord.rule($0) })
    }

    func debugPartnerCheckIn() async {
        guard isMock, let p = partner, let today = state.today[p.id] else { return }
        guard let item = today.items.first(where: { !$0.isChecked }) ?? today.items.first else { return }
        let now = self.now()
        let warm = today.beforeStart
        let photo = item.rule.type == .photo
            ? ImageTools.placeholderPhoto(title: item.rule.title,
                                          stamp: stampText(dayNumber: warm ? nil : today.dayNumber, at: now, tz: p.tz))
            : nil
        let c = CheckInFact(id: .newID(), memberID: p.id, ruleID: item.rule.id, capturedAt: now,
                            localDate: LocalDate(now, in: p.tz).string,
                            stampText: stampText(dayNumber: warm ? nil : today.dayNumber, at: now, tz: p.tz),
                            hasPhoto: photo != nil, isWarmup: warm, uploadedAt: now)
        await save([.checkIn(c, photo: photo)])
    }

    private var myLatestCheckIn: CheckInFact? { checkIns(of: meID).first }

    func debugPartnerReaction() async {
        guard isMock, let p = partner, let c = myLatestCheckIn else { toast = "Check in first."; return }
        let now = self.now()
        await save([
            .reaction(ReactionFact(id: .newID(), checkInID: c.id, memberID: p.id, kind: .approve, emoji: nil,
                                   comment: nil, createdAt: now)),
            .reaction(ReactionFact(id: .newID(), checkInID: c.id, memberID: p.id, kind: .emoji, emoji: "🔥",
                                   comment: nil, createdAt: now)),
            .reaction(ReactionFact(id: .newID(), checkInID: c.id, memberID: p.id, kind: .comment, emoji: nil,
                                   comment: "Look at you go", createdAt: now)),
        ])
    }

    func debugPartnerSus() async {
        guard isMock, let p = partner, let c = myLatestCheckIn else { toast = "Check in first."; return }
        await save([.reaction(ReactionFact(id: .newID(), checkInID: c.id, memberID: p.id, kind: .sus, emoji: nil,
                                           comment: nil, createdAt: now()))])
    }

    /// Moves the clock to 08:00 tomorrow, which settles today.
    func debugAdvanceDay() async {
        guard let mock = mockStore else { return }
        let tz = me?.tz ?? .current
        let tomorrow = LocalDate(now(), in: tz).adding(1)
        let target = tomorrow.startInstant(in: tz).addingTimeInterval(8 * 3600)
        await shiftClock(by: target.timeIntervalSince(now()), mock: mock)
    }

    /// The partner misses today, then the day settles.
    func debugSimulateMiss() async {
        guard let mock = mockStore, let p = partner, let today = state.today[p.id] else { return }
        var f = facts
        f.checkIns.removeAll { $0.memberID == p.id && $0.localDate == today.localDate.string && !$0.isWarmup }
        mock.replaceFacts(f)
        apply(f)
        await debugAdvanceDay()
    }

    /// Fills every day but the last of the current challenge (habits: 29 days) with complete check-ins for both
    /// and moves the clock to its last day.
    func debugJumpToDay74() async {
        guard let mock = mockStore, let round = currentRound, round.status == .active || round.status == .waiting
        else { toast = "Start a round first."; return }
        var f = facts
        let current = now()
        var target = current
        let days = round.mode.isMaintenance ? 29 : max(1, round.length - 1)
        for ms in round.members {
            guard let m = f.member(ms.memberID) else { continue }
            let rules = RulesEngine.effectiveRules(for: m.id, round: round.number, facts: f, at: current)
            for n in 0..<days {
                let date = ms.startDate.adding(n)
                let captured = date.startInstant(in: m.tz).addingTimeInterval(12 * 3600)
                for r in rules where !f.checkIns.contains(where: {
                    $0.memberID == m.id && $0.ruleID == r.id && $0.localDate == date.string && RulesEngine.isValid($0)
                }) {
                    f.checkIns.append(CheckInFact(id: .newID(), memberID: m.id, ruleID: r.id, capturedAt: captured,
                                                  localDate: date.string, stampText: "DAY \(n + 1)",
                                                  hasPhoto: false, isWarmup: false,
                                                  uploadedAt: captured.addingTimeInterval(30)))
                }
            }
            if m.id == meID {
                target = ms.startDate.adding(days).startInstant(in: m.tz).addingTimeInterval(9 * 3600)
            }
        }
        mock.replaceFacts(f)
        apply(f)
        await shiftClock(by: max(0, target.timeIntervalSince(current)), mock: mock)
    }

    func debugPauseRequest() async {
        guard isMock, let p = partner else { return }
        let start = LocalDate(now(), in: p.tz).adding(1)
        await save([.pause(PauseRequestFact(id: .newID(), requestedBy: p.id, startDate: start.string, days: 2,
                                            reason: "Travelling", createdAt: now()))])
    }

    func debugTweakProposal() async {
        guard isMock, let p = partner else { return }
        let lib = RuleLibrary.rule("bedtime")!
        let newRule = RuleFact(id: .newID(), memberID: p.id, fromRound: currentRound?.number ?? 1, position: 4,
                               libraryKey: lib.key, title: lib.standard, type: lib.type, createdAt: now())
        await save([.tweak(RuleTweakFact(id: .newID(), proposedBy: p.id,
                                         payload: RuleTweakPayload(swappedPosition: 4, newRule: newRule,
                                                                   newBet: BetOption.dinner.title),
                                         createdAt: now()))])
    }

    func debugPartnerLapse() async {
        guard isMock, var p = partner else { return }
        let now = self.now()
        p.subscriptionPeriods = p.subscriptionPeriods.compactMap { period in
            if period.start >= now { return nil }
            return SubscriptionPeriod(start: period.start, end: min(period.end, now))
        }
        p.subscribedUntil = now
        await save([.member(p)])
    }

    func debugPartnerRenew() async {
        guard isMock, var p = partner else { return }
        let now = self.now()
        p.recordSubscription(product: Brand.iapMonthly, purchaseDate: now, expiration: now.addingTimeInterval(86_400 * 3650))
        await save([.member(p)])
    }

    func debugResetEverything() async {
        guard let mock = mockStore else { return }
        mock.wipeLocalData()
        SeenEvents.wipe()
        Prefs.wipe()
        Identity.wipe()
        NotificationManager.shared.cancelAll()
        draft = OnboardingDraft()
        joinDraft = nil
        pendingInvite = nil
        invite = nil
        onboardingDone = false
        seenCodeEntry = true
        tab = .today
        meIDReset()
        apply(mock.cachedFacts())
        writeWidgetSnapshot()
    }

    /// Time travel, keeping everyone's subscription valid across the jump.
    private func shiftClock(by delta: TimeInterval, mock: MockStore) async {
        guard delta > 0 else { return }
        var f = facts
        for i in f.members.indices {
            f.members[i].subscriptionPeriods = f.members[i].subscriptionPeriods.map { p in
                p.end > now() ? SubscriptionPeriod(start: p.start, end: p.end.addingTimeInterval(delta)) : p
            }
            if let until = f.members[i].subscribedUntil, until > now() {
                f.members[i].subscribedUntil = until.addingTimeInterval(delta)
            }
        }
        mock.replaceFacts(f)
        mock.clockOffset += delta
        apply(f)
        await afterStateChange()
    }
}
#endif
