import Foundation

// The Pact Card's data, the couple map and the milestone share cards, all derived from the shared facts and the
// engine state (no state of their own besides "which milestone moments this phone has shown").

extension AppModel {

    // MARK: - Pact Card

    /// The card from the current couple (or, during onboarding, from the draft).
    var pactCard: PactCardData {
        let a = memberA
        let b = memberB
        let grid = pactGrid
        return PactCardData(
            nameA: a?.name ?? (draft.myName.isEmpty ? "You" : draft.myName),
            nameB: b?.name ?? (draft.partnerName.isEmpty ? nameB : draft.partnerName),
            avatarA: sceneA.avatar,
            avatarB: sceneBBuilt?.avatar,
            signedA: facts.couple?.createdAt ?? now(),
            signedB: b?.joinedAt,
            rank: xp.rank,
            streak: state.streak,
            cardNumber: PactCardData.number(for: facts.couple?.id ?? draft.coupleID ?? ""),
            mode: pactMode,
            startDate: facts.couple?.createdAt ?? now(),
            grid: grid.cells,
            gridTitle: grid.title,
            week: pactWeek)
    }

    /// "Daily pact", or the running challenge's name.
    var pactMode: String {
        guard let r = currentRound, !r.mode.isMaintenance, !r.isOver else { return "Daily pact" }
        if let c = Challenges.challenge(r.challengeID) { return c.title }
        return r.length == Challenges.the75.days ? Challenges.the75.title : "Challenge"
    }

    private var pactToday: LocalDate { LocalDate(now(), in: me?.tz ?? .current) }

    /// Today counts as done when everyone who's in today has finished.
    private var pactTodayDone: Bool {
        let todays = [todayA, todayB].compactMap { $0 }.filter { $0.dayNumber != nil }
        return !todays.isEmpty && todays.allSatisfy(\.isComplete)
    }

    /// Dates on which both partners completed their day (just A's, before B is in a round).
    private var bothCompleteDates: Set<LocalDate> {
        var perMember: [MemberID: Set<LocalDate>] = [:]
        for r in state.rounds {
            for m in r.members {
                perMember[m.memberID, default: []].formUnion(m.days.filter { $0.outcome == .complete }.map(\.date))
            }
        }
        guard let first = perMember.values.first else { return [] }
        return perMember.values.dropFirst().reduce(first) { $0.intersection($1) }
    }

    /// One cell per day of a running challenge; on daily habits the first 30 days, then the last 30.
    private var pactGrid: (cells: [PactDay], title: String) {
        let todayDone = pactTodayDone
        if let r = currentRound, !r.mode.isMaintenance, !r.isOver {
            let dayNow = myToday?.dayNumber ?? todayA?.dayNumber
            var perMember: [Set<Int>] = r.members.map { m in
                Set(m.days.filter { $0.outcome == .complete }.compactMap(\.dayNumber))
            }
            if perMember.isEmpty { perMember = [[]] }
            let done = perMember.dropFirst().reduce(perMember[0]) { $0.intersection($1) }
            let cells: [PactDay] = (1...max(r.length, 1)).map { n in
                if let d = dayNow, n == d { return todayDone ? .todayDone : .today }
                if done.contains(n) { return .done }
                if let d = dayNow, n < d { return .open }
                return .future
            }
            return (cells, "Day \(dayNow ?? 0) of \(r.length)")
        }
        let today = pactToday
        guard let start = currentRound?.members.map(\.startDate).min() else {
            return (Array(repeating: .future, count: 30), "Your first 30 days")
        }
        let first = start.days(until: today) >= 30 ? today.adding(-29) : start
        let done = bothCompleteDates
        let cells: [PactDay] = (0..<30).map { i in
            let d = first.adding(i)
            if d == today { return todayDone ? .todayDone : .today }
            if d > today { return .future }
            return done.contains(d) ? .done : .open
        }
        return (cells, first == start ? "Your first 30 days" : "Last 30 days")
    }

    /// This week, Sunday to Saturday.
    private var pactWeek: [PactDay] {
        let today = pactToday
        let sunday = today.adding(-(today.weekday - 1))
        let start = currentRound?.members.map(\.startDate).min()
        let done = bothCompleteDates
        let todayDone = pactTodayDone
        return (0..<7).map { i in
            let d = sunday.adding(i)
            if d == today { return todayDone ? .todayDone : .today }
            if d > today { return .future }
            if let start, d >= start { return done.contains(d) ? .done : .open }
            return .future
        }
    }

    // MARK: - Couple map

    /// Habit keys each partner started with (their first round's habits).
    private func startingHabitKeys(_ id: MemberID?) -> [String] {
        guard let id else { return [] }
        let rs = facts.rules.filter { $0.memberID == id }
        guard let first = rs.map(\.fromRound).min() else { return [] }
        return rs.filter { $0.fromRound == first }.map(\.libraryKey)
    }

    /// Both partners' Day 1 and current maps. In onboarding, from the draft's plan (B only if they answered here).
    var coupleMap: CoupleMapData {
        let together = facts.couple?.together ?? draft.together
        let level = facts.couple?.level ?? draft.level.rawValue
        var keysA = startingHabitKeys(memberA?.id)
        if keysA.isEmpty { keysA = draft.planRules.map { $0.a.libraryKey ?? "custom" } }
        var keysB = startingHabitKeys(memberB?.id)
        if keysB.isEmpty, memberB == nil { keysB = draft.partnerPlan?.map { $0.libraryKey ?? "custom" } ?? [] }
        let startA = CoupleMapScoring.start(habitKeys: keysA, together: together, level: level)
        let startB = keysB.isEmpty ? nil : CoupleMapScoring.start(habitKeys: keysB, together: together, level: level)
        return CoupleMapData(nameA: nameA, nameB: nameB,
                             startA: startA, nowA: memberA.map { history($0.id, start: startA) } ?? startA,
                             startB: startB, nowB: startB.map { s in memberB.map { history($0.id, start: s) } ?? s })
    }

    /// Walks the member's days up to yesterday (the map updates once a day).
    private func history(_ id: MemberID, start: MapScores) -> MapScores {
        guard let member = facts.member(id),
              let first = state.rounds.compactMap({ $0.member(id)?.startDate }).min() else { return start }
        let today = LocalDate(now(), in: member.tz)
        let count = min(first.days(until: today), 400)
        guard count > 0 else { return start }
        let days = (0..<count).map { first.adding($0).string }

        let keyByRule = Dictionary(facts.rules.map { ($0.id, $0.libraryKey) }, uniquingKeysWith: { a, _ in a })
        var perAxis: [MapAxis: Int] = [:]
        for r in rules(for: id) { perAxis[CoupleMapScoring.axis(for: r.libraryKey), default: 0] += 1 }

        let valid = facts.checkIns.filter { RulesEngine.isValid($0) && !$0.isWarmup }
        var done: [String: [MapAxis: Int]] = [:]
        var checkedIn: [String: Set<MemberID>] = [:]
        for c in valid {
            checkedIn[c.localDate, default: []].insert(c.memberID)
            guard c.memberID == id, let key = keyByRule[c.ruleID] else { continue }
            done[c.localDate, default: [:]][CoupleMapScoring.axis(for: key), default: 0] += 1
        }
        // Connection: both of you checked in that day, plus approvals and reactions between you.
        var cheers: [String: Int] = [:]
        for r in facts.reactions where r.kind != .sus && r.kind != .seen {
            cheers[LocalDate(r.createdAt, in: member.tz).string, default: 0] += 1
        }
        let both = facts.members.filter { $0.leftAt == nil }.count
        var connection: [String: Double] = [:]
        for d in days {
            let bothIn = both >= 2 && (checkedIn[d]?.count ?? 0) >= 2 ? 1.0 : 0
            connection[d] = min(1, 0.6 * bothIn + 0.4 * min(1, Double(cheers[d] ?? 0) / 2))
        }
        return CoupleMapHistory.compute(start: start, dailyHabitCount: perAxis, doneByDay: done,
                                        connectionByDay: connection, days: days).now
    }

    // MARK: - Milestones

    /// Every milestone this couple has reached, newest kind first (for Progress → Milestones).
    var unlockedMilestones: [PactMilestone] {
        let finished = state.rounds.filter { $0.status == .completed && !$0.mode.isMaintenance }.map { r in
            (round: r.number, title: Challenges.challenge(r.challengeID)?.title
                ?? (r.length == Challenges.the75.days ? Challenges.the75.title : "the challenge"), length: r.length)
        }
        return PactMilestones.unlocked(bestStreak: state.bestStreak, rank: xp.rank, finished: finished)
    }

    private var milestoneKeyPrefix: String { "pm-\(facts.couple?.id ?? "none")" }

    /// A streak milestone reached today: the celebration and the share card, once per phone. Rank-ups and finished
    /// challenges have their own celebration screens, which offer the same share card.
    func evaluatePactMilestone() {
        guard route == .main, me != nil, presentedPactMilestone == nil, presentedRankUp == nil,
              presentedDay75 == nil, presentedRoundEnd == nil, presentedSave == nil, presentedMilestone == nil,
              !presentedPartnerJoined, facts.couple != nil else { return }
        let reached = PactMilestones.streakDays.filter { state.streak >= $0 }
        let keys = reached.map { "\(milestoneKeyPrefix)-streak-\($0)" }
        let unseen = zip(reached, keys).filter { !SeenEvents.contains($0.1) }
        guard let top = unseen.last else { return }
        SeenEvents.insert(keys)
        presentedPactMilestone = PactMilestones.streak(top.0)
        Haptics.success()
    }

    /// The most recent proof photo either of you took (for "Include a proof photo"), if it's on this phone.
    var latestProofPhoto: Data? {
        facts.checkIns.filter { $0.hasPhoto && RulesEngine.isValid($0) }
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(10)
            .lazy
            .compactMap { self.cachedPhoto($0.id) }
            .first
    }
}
