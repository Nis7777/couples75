import Foundation
import SwiftUI
import CloudKit

extension AppModel {

    // MARK: - Subscriptions (2.6)

    /// Writes subscribedUntil / subscriptionProduct to my Member record after every entitlement change.
    func entitlementChanged(_ ent: Entitlement?) async {
        guard let ent, var m = me else { recompute(); return }
        let (start, end) = mockAdjusted(ent)
        let before = m
        m.recordSubscription(product: ent.productID, purchaseDate: start, expiration: end)
        if m != before { await save([.member(m)]) } else { recompute() }
    }

    /// In Mock mode, time travel shifts "now"; shift the subscription with it so it doesn't look lapsed.
    func mockAdjusted(_ ent: Entitlement) -> (Date, Date) {
        let offset = mockStore?.clockOffset ?? 0
        return (ent.purchaseDate.addingTimeInterval(offset), ent.expirationDate.addingTimeInterval(offset))
    }

    var hasActiveSubscription: Bool {
        guard let ent = purchases.entitlement else { return false }
        return mockAdjusted(ent).1 > now()
    }

    // MARK: - Person A (3.1–3.3)

    /// After A pays: create the couple, rules and invite.
    func createCouple() async -> Bool {
        let now = now()
        let fitness = draft.fitness ?? .somewhatActive
        var a = MemberFact(id: meID, role: .a, name: draft.myName.trimmingCharacters(in: .whitespaces),
                           characterID: draft.characterID, timeZone: TimeZone.current.identifier,
                           wakeTime: draft.wakeTime, fitnessLevel: fitness, joinedAt: now,
                           subscribedUntil: nil, subscriptionProduct: nil, subscriptionPeriods: [], leftAt: nil)
        if let ent = purchases.entitlement {
            let (s, e) = mockAdjusted(ent)
            a.recordSubscription(product: ent.productID, purchaseDate: min(s, now), expiration: e)
        }
        let couple = CoupleFact(id: .newID(), createdAt: now, ownerMemberID: meID,
                                title: "\(a.name)'s \(Brand.appName)",
                                invitedName: draft.partnerName.trimmingCharacters(in: .whitespaces))
        let config = RoundConfigFact(id: .newID(), fromRound: 1, mode: draft.level.mode, betText: draft.betText,
                                     rewardText: nil, createdBy: meID, createdAt: now)
        let keys = draft.ruleKeys
        let rulesA = PlanGenerator.rules(keys: keys, memberID: meID, intensity: draft.myIntensity, round: 1, now: now)
        let rulesB = PlanGenerator.rules(keys: keys, memberID: PendingPartner.id,
                                         intensity: draft.partnerIntensity, round: 1, now: now)
        var records: [FactRecord] = [.member(a), .roundConfig(config)]
        records += rulesA.map { .rule($0) } + rulesB.map { .rule($0) }
        do {
            invite = try await store.createCouple(couple: couple, records: records, inviterName: a.name)
            UserDefaults.standard.set(now, forKey: Prefs.invitePaidAtKey)
            apply(store.cachedFacts())
            await afterStateChange()
            return true
        } catch {
            errorMessage = (error as? StoreError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func regenerateInvite() async {
        do {
            invite = try await store.regenerateInvite(inviterName: nameA)
            toast = "New invite ready."
        } catch {
            errorMessage = (error as? StoreError)?.errorDescription ?? error.localizedDescription
        }
    }

    func joinWaitlist(email: String) async -> Bool {
        do {
            try await store.saveWaitlist(email: email)
            return true
        } catch {
            errorMessage = (error as? StoreError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    /// Invite text for the share sheet (3.2).
    func inviteMessage() -> String {
        let code = invite?.code ?? ""
        let link = invite?.shareURL?.absoluteString ?? ""
        return "I just signed us up for 75 days. \(currentBet). You in? Download \(Brand.appName), then tap this link: \(link) (or enter code \(code))"
    }

    // MARK: - Person B (3.5)

    func lookupCode(_ code: String) async -> InviteLookup? {
        do {
            return try await store.lookupInvite(code: code)
        } catch {
            errorMessage = (error as? StoreError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    /// Accepts the share behind a code and starts B's joining flow.
    func join(_ lookup: InviteLookup) async -> Bool {
        do {
            let f = try await store.acceptInvite(lookup)
            if let b = f.memberB, b.id != meID {
                throw StoreError.coupleFull
            }
            pendingInvite = lookup
            if joinDraft == nil { joinDraft = JoinDraft(code: lookup.code) }
            seenCodeEntry = true
            apply(f)
            return true
        } catch {
            errorMessage = (error as? StoreError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    /// The iCloud share link was tapped (CloudKit only).
    func acceptShare(_ metadata: CKShare.Metadata) async {
        guard let cloud = store as? CloudKitStore else { return }
        do {
            let f = try await cloud.accept(metadata: metadata)
            if let b = f.memberB, b.id != meID { throw StoreError.coupleFull }
            let inviter = f.memberA?.name ?? "Your partner"
            pendingInvite = InviteLookup(code: "", inviterName: inviter, shareURL: metadata.share.url)
            if joinDraft == nil { joinDraft = JoinDraft() }
            seenCodeEntry = true
            apply(f)
        } catch {
            errorMessage = (error as? StoreError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// The rules A drafted for B.
    var draftRulesForB: [RuleFact] {
        RulesEngine.effectiveRules(for: PendingPartner.id, round: 1, facts: facts, at: now())
    }

    /// B's own rules from B's fitness level (same library keys A picked), with an optional swap.
    func proposedRulesForMe(_ jd: JoinDraft) -> [RuleFact] {
        let keys = draftRulesForB.map { $0.libraryKey }
        let level = Level(mode: RulesEngine.config(for: 1, facts: facts)?.mode ?? .standard)
        let intensity = level.adjust((jd.fitness ?? .somewhatActive).intensity)
        var rules = PlanGenerator.rules(keys: keys.isEmpty ? PlanGenerator.ruleKeys(goals: [.fitness, .discipline]) : keys,
                                        memberID: meID, intensity: intensity, round: 1, now: now())
        if let pos = jd.swappedPosition, let key = jd.swapKey, let lib = RuleLibrary.rule(key),
           let i = rules.firstIndex(where: { $0.position == pos }) {
            rules[i] = RuleFact(id: rules[i].id, memberID: meID, fromRound: 1, position: pos, libraryKey: key,
                                title: lib.title(for: intensity), type: lib.type, createdAt: now())
        }
        return rules
    }

    /// Whether a swap keeps at least 2 photo rules.
    func swapAllowed(_ jd: JoinDraft, position: Int, key: String) -> Bool {
        var probe = jd
        probe.swappedPosition = position
        probe.swapKey = key
        return proposedRulesForMe(probe).filter { $0.type == .photo }.count >= 2
    }

    /// B accepts or tweaks: writes B's member record, rules and (if changed) a RuleTweak for A to answer.
    func submitJoinPlan() async -> Bool {
        guard let jd = joinDraft else { return false }
        let now = now()
        let b = MemberFact(id: meID, role: .b, name: facts.couple?.invitedName ?? "Partner",
                           characterID: jd.characterID, timeZone: TimeZone.current.identifier,
                           wakeTime: jd.wakeTime, fitnessLevel: jd.fitness ?? .somewhatActive, joinedAt: nil,
                           subscribedUntil: me?.subscribedUntil, subscriptionProduct: me?.subscriptionProduct,
                           subscriptionPeriods: me?.subscriptionPeriods ?? [], leftAt: nil)
        var base = jd
        base.swappedPosition = nil
        base.swapKey = nil
        let baseRules = proposedRulesForMe(base)
        var records: [FactRecord] = [.member(b)] + baseRules.map { .rule($0) }
        let swapped = jd.swappedPosition != nil && jd.swapKey != nil
        let newBet = jd.changeBet && !jd.betText.isEmpty && jd.betText != currentBet ? jd.betText : nil
        if swapped || newBet != nil {
            var newRule: RuleFact?
            if swapped, let pos = jd.swappedPosition {
                newRule = proposedRulesForMe(jd).first { $0.position == pos }
                newRule?.id = .newID()
            }
            let tweak = RuleTweakFact(id: .newID(), proposedBy: meID,
                                      payload: RuleTweakPayload(swappedPosition: swapped ? jd.swappedPosition : nil,
                                                                newRule: newRule, newBet: newBet),
                                      createdAt: now)
            records.append(.tweak(tweak))
        }
        return await save(records)
    }

    /// B, after subscribing: "I'm in". Day 1 is the next local day.
    func finishJoining() async -> Bool {
        guard var b = me else { return false }
        if let ent = purchases.entitlement {
            let (s, e) = mockAdjusted(ent)
            b.recordSubscription(product: ent.productID, purchaseDate: s, expiration: e)
        }
        b.joinedAt = now()
        let ok = await save([.member(b)])
        if ok {
            pendingInvite = nil
        }
        return ok
    }

    func finishOnboarding() {
        onboardingDone = true
        joinDraft = nil
        pendingInvite = nil
        tab = .today
        recompute()
    }

    // MARK: - Tweaks

    var tweakForMeToAnswer: TweakInfo? {
        guard let t = state.pendingTweak, t.tweak.proposedBy != meID else { return nil }
        return t
    }

    func answerTweak(_ info: TweakInfo, accepted: Bool) async {
        await save([.tweakAnswer(TweakAnswerFact(id: .newID(), tweakID: info.tweak.id, accepted: accepted,
                                                 answeredAt: now()))])
    }

    // MARK: - Check-ins (4.1–4.3)

    func stampText(dayNumber: Int?, at date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "EEE d MMM"
        let day = f.string(from: date).uppercased()
        f.dateFormat = "HH:mm"
        let time = f.string(from: date)
        let prefix = dayNumber.map { "DAY \($0)" } ?? "WARM-UP"
        return "\(prefix) · \(day) · \(time)"
    }

    var isWarmup: Bool {
        switch state.phase {
        case .waitingForPartner, .warmup: return true
        default: return myToday?.beforeStart ?? false
        }
    }

    /// Saves a check-in for today. `photo` is the stamped, compressed JPEG for photo rules.
    @discardableResult
    func checkIn(rule: RuleFact, photo: Data?, honourFallback: Bool = false) async -> Bool {
        guard let m = me else { return false }
        let now = now()
        let warm = isWarmup
        let date = LocalDate(now, in: m.tz)
        let c = CheckInFact(id: .newID(), memberID: m.id, ruleID: rule.id, capturedAt: now, localDate: date.string,
                            stampText: stampText(dayNumber: warm ? nil : myToday?.dayNumber, at: now, tz: m.tz),
                            hasPhoto: photo != nil, isWarmup: warm,
                            uploadedAt: isMock ? now : nil, honourFallback: honourFallback)
        let ok = await save([.checkIn(c, photo: photo)])
        if ok { Haptics.success() }
        return ok
    }

    func checkIns(of memberID: MemberID) -> [CheckInFact] {
        facts.checkIns.filter { $0.memberID == memberID }.sorted { $0.capturedAt > $1.capturedAt }
    }

    func reactions(for checkInID: String) -> [ReactionFact] {
        facts.reactions.filter { $0.checkInID == checkInID }.sorted { $0.createdAt < $1.createdAt }
    }

    func react(to checkIn: CheckInFact, kind: ReactionKind, emoji: String? = nil, comment: String? = nil) async {
        let r = ReactionFact(id: .newID(), checkInID: checkIn.id, memberID: meID, kind: kind, emoji: emoji,
                             comment: comment.map { String($0.prefix(80)) }, createdAt: now())
        await save([.reaction(r)])
    }

    func markSeen(_ checkIn: CheckInFact) async {
        guard checkIn.memberID != meID,
              !facts.reactions.contains(where: { $0.checkInID == checkIn.id && $0.memberID == meID && $0.kind == .seen })
        else { return }
        await react(to: checkIn, kind: .seen)
    }

    /// "Approved" when the partner approved, "Seen" when they opened it, nil otherwise.
    func partnerStatus(of checkIn: CheckInFact) -> String? {
        let others = reactions(for: checkIn.id).filter { $0.memberID != checkIn.memberID }
        if others.contains(where: { $0.kind == .approve }) { return "Approved" }
        if others.contains(where: { $0.kind == .seen }) { return "Seen" }
        return nil
    }

    /// Day N of a check-in (from the settled days, or today's number).
    func dayNumber(of checkIn: CheckInFact) -> Int? {
        if checkIn.isWarmup { return nil }
        for round in state.rounds.reversed() {
            if let day = round.member(checkIn.memberID)?.days.first(where: { $0.date.string == checkIn.localDate }) {
                return day.dayNumber
            }
        }
        if let t = state.today[checkIn.memberID], t.localDate.string == checkIn.localDate { return t.dayNumber }
        return nil
    }

    func photoData(for checkIn: CheckInFact) async -> Data? {
        await store.photoData(for: checkIn)
    }

    func cachedPhoto(_ checkInID: String) -> Data? {
        store.cachedPhotoData(for: checkInID)
    }

    // MARK: - Pause (4.9)

    var pauseUsedThisRound: Bool {
        guard let p = currentRound?.pause else { return false }
        return p.status == .accepted || p.status == .pending
    }

    func requestPause(days: Int, startTomorrow: Bool, reason: String) async -> Bool {
        guard let m = me else { return false }
        let start = LocalDate(now(), in: m.tz).adding(startTomorrow ? 1 : 0)
        let p = PauseRequestFact(id: .newID(), requestedBy: m.id, startDate: start.string,
                                 days: min(max(days, 1), Brand.maxPauseDays),
                                 reason: String(reason.prefix(60)), createdAt: now())
        return await save([.pause(p)])
    }

    var pauseForMeToAnswer: PauseInfo? {
        guard let p = state.pendingPause, p.request.requestedBy != meID,
              !facts.pauseAnswers.contains(where: { $0.pauseID == p.request.id }) else { return nil }
        return p
    }

    func answerPause(_ info: PauseInfo, accepted: Bool) async {
        await save([.pauseAnswer(PauseAnswerFact(id: .newID(), pauseID: info.request.id, accepted: accepted,
                                                 answeredAt: now()))])
    }

    // MARK: - Bet and rounds

    func markPaid(_ round: RoundState) async {
        await save([.betPaid(BetPaidFact(id: .newID(), roundNumber: round.number, memberID: meID, paidAt: now()))])
    }

    /// "Start round 2" after Day 75: new wake time and level; both members' rules follow the new level.
    func startNextRound(after round: RoundState, level: Level, wakeTime: String) async {
        let now = now()
        let next = round.number + 1
        var records: [FactRecord] = [
            .roundConfig(RoundConfigFact(id: .newID(), fromRound: next, mode: level.mode, betText: round.betText,
                                         rewardText: round.rewardText, createdBy: meID, createdAt: now))
        ]
        for m in facts.members {
            let current = RulesEngine.effectiveRules(for: m.id, round: round.number, facts: facts, at: now)
            let intensity = level.adjust(m.fitnessLevel.intensity)
            records += PlanGenerator.rules(keys: current.map { $0.libraryKey }, memberID: m.id,
                                           intensity: intensity, round: next, now: now).map { .rule($0) }
        }
        if var mine = me {
            mine.wakeTime = wakeTime
            records.append(.member(mine))
        }
        await save(records)
        presentedDay75 = nil
        SeenEvents.insert(["day75-\(round.number)", "roundend-\(round.number)"])
    }

    // MARK: - Profile settings

    func setWakeTime(_ hhmm: String) async {
        guard var m = me else { return }
        m.wakeTime = hhmm
        await save([.member(m)])
    }

    func setEveningWarning(_ on: Bool) async {
        Prefs.eveningWarningOn = on
        await NotificationManager.shared.reschedule(model: self)
    }

    // MARK: - Leave / delete (6.5)

    func leaveCouple() async -> Bool {
        guard let m = me else { return false }
        do {
            try await store.leaveCouple(me: m)
            resetLocalCoupleState()
            return true
        } catch {
            errorMessage = (error as? StoreError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    /// Leave couple, then clear every local cache and the iCloud key-value store, then back to the hook.
    func deleteMyData() async {
        if me != nil { _ = await leaveCouple() }
        store.wipeLocalData()
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
        meIDReset()
        apply(store.cachedFacts())
        writeWidgetSnapshot()
    }

    /// After the partner left: start over with a new partner.
    func startOver() async {
        // The owner also deletes the old zone in iCloud; a participant leaves the share.
        if let m = me { try? await store.leaveCouple(me: m) }
        store.wipeLocalData()
        resetLocalCoupleState()
    }

    private func resetLocalCoupleState() {
        draft = OnboardingDraft()
        joinDraft = nil
        pendingInvite = nil
        invite = nil
        onboardingDone = false
        seenCodeEntry = true
        if isMock { Identity.setMockActing(nil); meIDReset() }
        apply(store.cachedFacts())
        writeWidgetSnapshot()
    }

    // MARK: - URLs and deep links

    /// couples75://join?code=K7M2QP
    func handle(url: URL) {
        guard url.scheme == Brand.urlScheme else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if url.host == "join", let code = items.first(where: { $0.name == "code" })?.value, me == nil {
            Task {
                if let lookup = await lookupCode(code) { _ = await join(lookup) }
            }
        } else if url.host == "today" {
            deepLink = .today
        }
    }

    func handle(route: String) {
        if route.hasPrefix("checkin:") {
            deepLink = .checkIn(String(route.dropFirst("checkin:".count)))
        } else if route == "pause" {
            deepLink = .pause
        } else if route == "tweak" {
            deepLink = .tweak
        } else if route == "progress" {
            deepLink = .progress
        } else {
            deepLink = .today
        }
    }
}
