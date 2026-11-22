import Foundation

// RulesEngine: one pure function, `RulesEngine.state(facts:now:)`, that turns the shared facts into
// everything the app shows. Both phones run it on the same facts, so they always agree.
// No CloudKit, no UIKit, no global state. Implements section 2 of the spec.

// MARK: - Output types

enum DayOutcome: String, Equatable {
    case complete
    case miss
    case paused
    case frozen
}

struct SettledDay: Equatable {
    var date: LocalDate
    /// Day N within the round. nil for paused and frozen days (they don't count).
    var dayNumber: Int?
    var outcome: DayOutcome
    var closedAt: Date
    /// A miss that a shared save covered.
    var coveredBySave: Bool
}

enum RoundStatus: String, Equatable {
    case waiting      // scheduled, Day 1 hasn't started yet
    case active
    case completed
    case failed
    case abandoned
}

struct MemberRoundState: Equatable {
    var memberID: MemberID
    var startDate: LocalDate
    var days: [SettledDay]
    var misses: Int
    /// Number of counted (numbered) days settled so far.
    var countedDays: Int
}

struct SaveEvent: Equatable, Identifiable {
    var id: String
    var roundNumber: Int
    var memberID: MemberID
    var dayNumber: Int
    var date: LocalDate
}

enum PauseStatus: String, Equatable {
    case pending, accepted, declined
}

struct PauseInfo: Equatable {
    var request: PauseRequestFact
    var status: PauseStatus
    var dates: [LocalDate]
    var autoAcceptAt: Date
}

struct TweakInfo: Equatable {
    var tweak: RuleTweakFact
    var status: PauseStatus
    var autoAcceptAt: Date
}

struct RoundState: Equatable, Identifiable {
    var number: Int
    var mode: RoundMode
    var savesAllowed: Int
    var betText: String
    var rewardText: String?
    var status: RoundStatus
    var startedAt: Date
    var endedAt: Date?
    /// Day number of the miss that ended a failed round.
    var failedOnDay: Int?
    var members: [MemberRoundState]
    var savesUsed: Int
    var saveEvents: [SaveEvent]
    /// Who owes the bet. Empty when nobody owes (or the round isn't settled, or was abandoned).
    var owes: [MemberID]
    var rewardUnlocked: Bool
    var paidAt: Date?
    var pause: PauseInfo?
    var susCount: Int
    var bestStreak: Int

    var id: Int { number }
    var savesLeft: Int { max(0, savesAllowed - savesUsed) }
    var isOver: Bool { status == .completed || status == .failed || status == .abandoned }
    func member(_ id: MemberID) -> MemberRoundState? { members.first { $0.memberID == id } }
    func misses(_ id: MemberID) -> Int { member(id)?.misses ?? 0 }
}

enum CheckState: String, Equatable {
    case open        // nothing valid yet
    case done        // reached iCloud in time
    case notSent     // taken, not in iCloud yet, upload window still open (counts if it arrives in time)
}

struct ChecklistItem: Equatable, Identifiable {
    var rule: RuleFact
    var checkIn: CheckInFact?
    var state: CheckState
    var id: String { rule.id }
    var isChecked: Bool { state != .open }
}

struct MemberToday: Equatable {
    var memberID: MemberID
    var localDate: LocalDate
    /// Today's Day N. nil before Day 1, on paused/frozen days, and after this member's Day 75.
    var dayNumber: Int?
    var isPaused: Bool
    var isFrozen: Bool
    var beforeStart: Bool
    var finishedRound: Bool
    var items: [ChecklistItem]

    var isComplete: Bool { !items.isEmpty && items.allSatisfy { $0.isChecked } }
    var remaining: Int { items.filter { !$0.isChecked }.count }
}

enum Phase: Equatable {
    case noCouple
    /// A created the couple; B hasn't finished joining. Warm-up check-ins are allowed.
    case waitingForPartner
    /// Both joined; Day 1 of round 1 hasn't started yet (warm-up).
    case warmup
    case active
    /// The last round ended; the next one is scheduled (or awaits "Start round 2").
    case betweenRounds
    /// A member left the couple.
    case partnerLeft(MemberID)
}

struct EngineState: Equatable {
    var phase: Phase
    var rounds: [RoundState]
    var today: [MemberID: MemberToday]
    var streak: Int
    var bestStreak: Int
    /// Days don't settle right now because the couple's subscription lapsed.
    var isFrozen: Bool
    /// Members whose own subscription isn't active right now.
    var lapsedMembers: [MemberID]
    /// One subscription covers both: the couple is active while ANY member's subscription is.
    var coupleActive: Bool = false
    /// The member whose subscription runs the longest (the one who pays); nil if nobody ever subscribed.
    var payerID: MemberID? = nil
    var pendingPause: PauseInfo?
    var pendingTweak: TweakInfo?
    var roundsPlayed: Int

    var currentRound: RoundState? { rounds.last }
    /// The most recent round that is over (for round-end screens).
    var lastFinishedRound: RoundState? { rounds.last(where: { $0.isOver }) }
    var allSaveEvents: [SaveEvent] { rounds.flatMap { $0.saveEvents } }
}

// MARK: - Engine

enum RulesEngine {

    static func state(facts: Facts, now: Date) -> EngineState {
        var result = EngineState(phase: .noCouple, rounds: [], today: [:], streak: 0, bestStreak: 0,
                                 isFrozen: false, lapsedMembers: [], pendingPause: nil, pendingTweak: nil,
                                 roundsPlayed: 0)
        guard facts.couple != nil, let a = facts.memberA else { return result }

        result.pendingTweak = facts.tweaks
            .sorted { $0.createdAt < $1.createdAt }
            .map { tweakInfo($0, facts: facts, at: now) }
            .last { $0.status == .pending }

        let couplePlan = SubscriptionTimeline(members: facts.members)
        result.coupleActive = couplePlan.active(at: now)
        result.payerID = facts.members.filter { $0.subscribedUntil != nil }
            .max { ($0.subscribedUntil ?? .distantPast) < ($1.subscribedUntil ?? .distantPast) }?.id

        if let leaver = facts.members.first(where: { $0.leftAt != nil }) {
            result.phase = .partnerLeft(leaver.id)
            return result
        }

        guard let b = facts.memberB, let joinedA = a.joinedAt, let joinedB = b.joinedAt else {
            result.phase = .waitingForPartner
            result.today[a.id] = warmupToday(member: a, facts: facts, now: now)
            if let b = facts.memberB { result.today[b.id] = warmupToday(member: b, facts: facts, now: now) }
            return result
        }

        let members = [a, b]
        let timeline = SubscriptionTimeline(members: members)
        result.lapsedMembers = members.filter { !$0.isSubscribed(at: now) }.map { $0.id }
        // Round 1 starts the first local day after B joined, while the couple's subscription is active.
        let activation = max(joinedA, joinedB)
        guard let firstActive = timeline.nextBothActive(from: activation) else {
            result.phase = .warmup
            result.isFrozen = true
            for m in members { result.today[m.id] = warmupToday(member: m, facts: facts, now: now) }
            return result
        }

        var starts: [MemberID: LocalDate] = [:]
        for m in members { starts[m.id] = LocalDate(firstActive, in: m.tz).adding(1) }
        var windowStart = activation
        var roundNumber = 1
        var rounds: [RoundState] = []

        while roundNumber < 10_000 {
            let sim = simulateRound(number: roundNumber, members: members, starts: starts,
                                    windowStart: windowStart, facts: facts, timeline: timeline, now: now)
            rounds.append(sim.round)
            guard sim.round.isOver, let ended = sim.round.endedAt else { break }

            var nextInstant: Date?
            switch sim.round.status {
            case .failed:
                nextInstant = ended
            case .abandoned:
                nextInstant = timeline.nextBothActive(from: ended)
            case .completed:
                if let cfg = facts.roundConfigs.first(where: { $0.fromRound == roundNumber + 1 }) {
                    nextInstant = max(cfg.createdAt, ended)
                }
            default:
                break
            }
            guard let instant = nextInstant else { break }
            // Next round: Day 1 is the day after the local date on which the previous round ended.
            for m in members { starts[m.id] = LocalDate(instant, in: m.tz).adding(1) }
            windowStart = ended
            roundNumber += 1
        }
        result.rounds = rounds
        result.roundsPlayed = rounds.filter { $0.status != .waiting }.count
        guard let current = rounds.last else { return result }

        // Today per member.
        for m in members {
            result.today[m.id] = today(for: m, round: current, facts: facts, timeline: timeline, now: now)
        }

        switch current.status {
        case .waiting:
            result.phase = current.number == 1 ? .warmup : .betweenRounds
            if current.number == 1 {
                for m in members { result.today[m.id] = warmupToday(member: m, facts: facts, now: now) }
            }
        case .active:
            result.phase = .active
            result.isFrozen = !timeline.bothActive(at: now)
        case .completed, .failed, .abandoned:
            result.phase = .betweenRounds
        }
        if current.status == .active || current.status == .waiting, let p = current.pause, p.status == .pending {
            result.pendingPause = p
        }

        // Streaks: consecutive day numbers where both members completed.
        var best = 0
        for (i, r) in rounds.enumerated() {
            var s = trailingStreak(r)
            if i == rounds.count - 1, r.status == .active {
                s += todayBonus(round: r, today: result.today, members: members)
                result.streak = s
            }
            best = max(best, r.bestStreak, s)
        }
        result.bestStreak = best
        return result
    }

    // MARK: Rules

    /// The member's 4 rules for a round, with B's tweak applied as of `at` (pending counts as proposed),
    /// then the approved rule proposals (Part 8) for the local `date` (default: the member's date at `at`).
    /// Pending or declined proposals never count: the original rule stays active.
    static func effectiveRules(for memberID: MemberID, round: Int, facts: Facts, at: Date,
                               date: LocalDate? = nil) -> [RuleFact] {
        let mine = facts.rules.filter { $0.memberID == memberID && $0.fromRound <= round }
        guard let from = mine.map({ $0.fromRound }).max() else { return [] }
        var byPosition: [Int: RuleFact] = [:]
        for r in mine where r.fromRound == from {
            if let existing = byPosition[r.position], existing.createdAt >= r.createdAt { continue }
            byPosition[r.position] = r
        }
        for t in facts.tweaks.sorted(by: { $0.createdAt < $1.createdAt }) where t.proposedBy == memberID {
            guard let pos = t.payload.swappedPosition, let newRule = t.payload.newRule,
                  newRule.fromRound <= round, newRule.fromRound >= from else { continue }
            if tweakInfo(t, facts: facts, at: at).status != .declined {
                byPosition[pos] = newRule
            }
        }
        let tz = facts.member(memberID)?.tz ?? .current
        let day = date ?? LocalDate(at, in: tz)
        for (p, start) in approvedProposals(for: memberID, facts: facts, at: at) {
            let r = p.rule
            guard r.fromRound <= round, r.fromRound >= from, (1...Brand.rulesPerMember).contains(r.position),
                  day >= start else { continue }
            var applied = r
            applied.memberID = memberID
            byPosition[r.position] = applied
        }
        return byPosition.keys.sorted().compactMap { byPosition[$0] }
    }

    // MARK: Rule proposals (double approval)

    /// Proposals made for the partner before they joined target the placeholder id; they belong to B.
    static func resolvedMember(_ id: MemberID, facts: Facts) -> MemberID {
        id == PendingPartner.id ? (facts.memberB?.id ?? id) : id
    }

    /// Approved only by an answer (never automatically); the first answer counts.
    static func proposalStatus(_ p: RuleProposalFact, facts: Facts, at: Date) -> PauseStatus {
        guard let answer = facts.ruleAnswers
            .filter({ $0.proposalID == p.id && $0.answeredAt <= at })
            .min(by: { $0.answeredAt < $1.answeredAt }) else { return .pending }
        return answer.accepted ? .accepted : .declined
    }

    /// The approved proposals for a member, oldest approval first, with the local date each starts:
    /// the day after the approval (and never before `effectiveFrom`). Only the first approved in-round
    /// swap per round counts; a second one in the same round is rejected.
    static func approvedProposals(for memberID: MemberID, facts: Facts, at: Date) -> [(RuleProposalFact, LocalDate)] {
        let tz = facts.member(memberID)?.tz ?? .current
        var result: [(RuleProposalFact, LocalDate, Date)] = []
        var swapRounds = Set<Int>()
        let answered = facts.ruleProposals
            .filter { resolvedMember($0.forMember, facts: facts) == memberID }
            .compactMap { p -> (RuleProposalFact, Date)? in
                guard let a = facts.ruleAnswers
                    .filter({ $0.proposalID == p.id && $0.answeredAt <= at })
                    .min(by: { $0.answeredAt < $1.answeredAt }), a.accepted else { return nil }
                return (p, a.answeredAt)
            }
            .sorted { ($0.1, $0.0.createdAt) < ($1.1, $1.0.createdAt) }
        for (p, answeredAt) in answered {
            if p.isSwap {
                guard !swapRounds.contains(p.rule.fromRound) else { continue }
                swapRounds.insert(p.rule.fromRound)
            }
            var start = LocalDate(answeredAt, in: tz).adding(1)
            if let from = p.effectiveFrom.flatMap(LocalDate.init(string:)), from > start { start = from }
            result.append((p, start, answeredAt))
        }
        return result.map { ($0.0, $0.1) }
    }

    /// Proposals nobody has answered yet.
    static func pendingProposals(facts: Facts, at: Date) -> [RuleProposalFact] {
        facts.ruleProposals
            .filter { proposalStatus($0, facts: facts, at: at) == .pending }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Whether the member already used (or is waiting on) this round's one swap.
    static func swapUsed(by memberID: MemberID, round: Int, facts: Facts, at: Date) -> Bool {
        facts.ruleProposals.contains { p in
            p.isSwap && p.rule.fromRound == round && resolvedMember(p.forMember, facts: facts) == memberID
                && proposalStatus(p, facts: facts, at: at) != .declined
        }
    }

    static func config(for round: Int, facts: Facts) -> RoundConfigFact? {
        facts.roundConfigs
            .filter { $0.fromRound <= round }
            .max { ($0.fromRound, $0.createdAt) < ($1.fromRound, $1.createdAt) }
    }

    /// The bet for a round: the config's bet, overridden by a non-declined tweak made after that config.
    static func betText(for round: Int, facts: Facts, at: Date) -> String {
        guard let cfg = config(for: round, facts: facts) else { return "" }
        var bet = cfg.betText
        for t in facts.tweaks.sorted(by: { $0.createdAt < $1.createdAt })
        where t.createdAt >= cfg.createdAt {
            if let newBet = t.payload.newBet, !newBet.isEmpty,
               tweakInfo(t, facts: facts, at: at).status != .declined {
                bet = newBet
            }
        }
        return bet
    }

    // MARK: Pauses and tweaks

    static func pauseStatus(_ p: PauseRequestFact, facts: Facts, at: Date) -> PauseStatus {
        let deadline = p.createdAt.addingTimeInterval(Brand.pauseAutoAcceptHours * 3600)
        if let answer = facts.pauseAnswers
            .filter({ $0.pauseID == p.id && $0.answeredAt < deadline && $0.answeredAt <= at })
            .min(by: { $0.answeredAt < $1.answeredAt }) {
            return answer.accepted ? .accepted : .declined
        }
        return at >= deadline ? .accepted : .pending
    }

    static func pauseInfo(_ p: PauseRequestFact, facts: Facts, at: Date) -> PauseInfo {
        let days = min(max(p.days, 1), Brand.maxPauseDays)
        let start = LocalDate(string: p.startDate) ?? LocalDate(p.createdAt, in: .current)
        return PauseInfo(request: p, status: pauseStatus(p, facts: facts, at: at),
                         dates: (0..<days).map { start.adding($0) },
                         autoAcceptAt: p.createdAt.addingTimeInterval(Brand.pauseAutoAcceptHours * 3600))
    }

    static func tweakInfo(_ t: RuleTweakFact, facts: Facts, at: Date) -> TweakInfo {
        let deadline = t.createdAt.addingTimeInterval(Brand.tweakAutoAcceptHours * 3600)
        var status: PauseStatus = at >= deadline ? .accepted : .pending
        if let answer = facts.tweakAnswers
            .filter({ $0.tweakID == t.id && $0.answeredAt < deadline && $0.answeredAt <= at })
            .min(by: { $0.answeredAt < $1.answeredAt }) {
            status = answer.accepted ? .accepted : .declined
        }
        return TweakInfo(tweak: t, status: status, autoAcceptAt: deadline)
    }

    // MARK: Check-ins

    static func isValid(_ c: CheckInFact) -> Bool {
        guard !c.isWarmup, let uploaded = c.uploadedAt else { return false }
        return uploaded.timeIntervalSince(c.capturedAt) <= Brand.checkInUploadWindowHours * 3600
            && uploaded >= c.capturedAt.addingTimeInterval(-300)
    }

    static func checkState(_ c: CheckInFact, now: Date) -> CheckState {
        if isValid(c) { return .done }
        if c.uploadedAt == nil, !c.isWarmup,
           now.timeIntervalSince(c.capturedAt) < Brand.checkInUploadWindowHours * 3600 {
            return .notSent
        }
        return .open
    }

    // MARK: Round simulation

    private struct SimResult {
        var round: RoundState
        var halted: Bool
    }

    private struct Cursor {
        var member: MemberFact
        var date: LocalDate
        var counted = 0
        var misses = 0
        var days: [SettledDay] = []
        var finished = false
    }

    private static func simulateRound(number: Int, members: [MemberFact], starts: [MemberID: LocalDate],
                                      windowStart: Date, facts: Facts, timeline: SubscriptionTimeline,
                                      now: Date) -> SimResult {
        let cfg = config(for: number, facts: facts)
        let mode = cfg?.mode ?? .standard
        let savesAllowed = mode == .hard ? 0 : Brand.savesPerRound
        var cursors = members.map { Cursor(member: $0, date: starts[$0.id] ?? LocalDate(now, in: $0.tz)) }
        let startInstant = cursors.map { $0.date.startInstant(in: $0.member.tz) }.min() ?? now

        // Valid check-ins indexed by member + local date.
        var valid: [String: Set<String>] = [:]
        for c in facts.checkIns where isValid(c) {
            valid["\(c.memberID)|\(c.localDate)", default: []].insert(c.ruleID)
        }

        // The round's pause: the first request in this round's window that wasn't declined.
        let pause = facts.pauses
            .filter { $0.createdAt >= windowStart }
            .sorted { $0.createdAt < $1.createdAt }
            .map { pauseInfo($0, facts: facts, at: now) }
            .first { $0.status != .declined }
        let pausedDates = Set(pause?.dates.map { $0.string } ?? [])

        let abandonAt = timeline.abandonInstant(after: startInstant)

        var status: RoundStatus = .active
        var endedAt: Date?
        var failedOnDay: Int?
        var savesUsed = 0
        var saveEvents: [SaveEvent] = []
        var halted = false

        simulation: while true {
            let open = cursors.indices.filter { !cursors[$0].finished }
            if open.isEmpty { break }
            let closes = open.map { cursors[$0].date.closeInstant(in: cursors[$0].member.tz) }
            guard let t = closes.min() else { break }

            if let ab = abandonAt, ab <= t, ab <= now {
                status = .abandoned
                endedAt = ab
                break
            }
            if t > now { break }

            var groupMisses: [(index: Int, day: Int, date: LocalDate)] = []
            for (k, i) in open.enumerated() where closes[k] == t {
                let date = cursors[i].date
                if pausedDates.contains(date.string), let p = pause {
                    if p.status == .pending { halted = true; break simulation }
                    cursors[i].days.append(SettledDay(date: date, dayNumber: nil, outcome: .paused,
                                                      closedAt: t, coveredBySave: false))
                } else if !timeline.bothActive(at: t.addingTimeInterval(-1)) {
                    cursors[i].days.append(SettledDay(date: date, dayNumber: nil, outcome: .frozen,
                                                      closedAt: t, coveredBySave: false))
                } else {
                    cursors[i].counted += 1
                    let n = cursors[i].counted
                    let rules = effectiveRules(for: cursors[i].member.id, round: number, facts: facts, at: t, date: date)
                    let done = valid["\(cursors[i].member.id)|\(date.string)"] ?? []
                    let complete = !rules.isEmpty && rules.allSatisfy { done.contains($0.id) }
                    cursors[i].days.append(SettledDay(date: date, dayNumber: n,
                                                      outcome: complete ? .complete : .miss,
                                                      closedAt: t, coveredBySave: false))
                    if !complete { groupMisses.append((i, n, date)) }
                    if n >= Brand.roundLengthDays { cursors[i].finished = true }
                }
                cursors[i].date = date.adding(1)
            }

            // Misses at the same instant are all counted, then saves are drawn in order.
            for miss in groupMisses {
                cursors[miss.index].misses += 1
                if savesUsed < savesAllowed {
                    savesUsed += 1
                    if let last = cursors[miss.index].days.indices.last {
                        cursors[miss.index].days[last].coveredBySave = true
                    }
                    let mid = cursors[miss.index].member.id
                    saveEvents.append(SaveEvent(id: "save-r\(number)-\(mid)-\(miss.date.string)",
                                                roundNumber: number, memberID: mid,
                                                dayNumber: miss.day, date: miss.date))
                } else if status != .failed {
                    status = .failed
                    failedOnDay = miss.day
                }
            }
            if status == .failed { endedAt = t; break }
            if cursors.allSatisfy({ $0.finished }) {
                status = .completed
                endedAt = t
                break
            }
        }

        if status == .active, let ab = abandonAt, ab <= now, endedAt == nil {
            status = .abandoned
            endedAt = ab
        }
        if status == .active,
           cursors.allSatisfy({ $0.days.isEmpty && now < $0.date.startInstant(in: $0.member.tz) }) {
            status = .waiting
        }

        let memberStates = cursors.map {
            MemberRoundState(memberID: $0.member.id, startDate: starts[$0.member.id] ?? $0.date,
                             days: $0.days, misses: $0.misses, countedDays: $0.counted)
        }

        // Settle the bet once, when the round ends (never for abandoned rounds).
        var owes: [MemberID] = []
        var rewardUnlocked = false
        if status == .completed || status == .failed, memberStates.count == 2 {
            let m0 = memberStates[0], m1 = memberStates[1]
            if m0.misses > m1.misses { owes = [m0.memberID] }
            else if m1.misses > m0.misses { owes = [m1.memberID] }
            else if m0.misses > 0 { owes = [m0.memberID, m1.memberID] }
            else { rewardUnlocked = !(cfg?.rewardText ?? "").isEmpty }
        }

        let roundEnd = endedAt ?? now
        let sus = facts.reactions.filter {
            $0.kind == .sus && $0.createdAt >= startInstant && $0.createdAt <= roundEnd
        }.count
        let paid = facts.betPayments.filter { $0.roundNumber == number }.map { $0.paidAt }.min()

        var round = RoundState(number: number, mode: mode, savesAllowed: savesAllowed,
                               betText: betText(for: number, facts: facts, at: roundEnd),
                               rewardText: cfg?.rewardText, status: status, startedAt: startInstant,
                               endedAt: endedAt, failedOnDay: failedOnDay, members: memberStates,
                               savesUsed: savesUsed, saveEvents: saveEvents, owes: owes,
                               rewardUnlocked: rewardUnlocked, paidAt: paid, pause: pause,
                               susCount: sus, bestStreak: 0)
        round.bestStreak = bestRun(round)
        return SimResult(round: round, halted: halted)
    }

    // MARK: Today

    private static func today(for m: MemberFact, round: RoundState, facts: Facts,
                              timeline: SubscriptionTimeline, now: Date) -> MemberToday {
        let todayDate = LocalDate(now, in: m.tz)
        let items = checklist(member: m, round: round.number, date: todayDate, warmup: false, facts: facts, now: now)
        guard let ms = round.member(m.id) else {
            return MemberToday(memberID: m.id, localDate: todayDate, dayNumber: nil, isPaused: false,
                               isFrozen: false, beforeStart: true, finishedRound: false, items: items)
        }
        if round.isOver {
            return MemberToday(memberID: m.id, localDate: todayDate, dayNumber: nil, isPaused: false,
                               isFrozen: false, beforeStart: false, finishedRound: true, items: items)
        }
        if todayDate < ms.startDate {
            return MemberToday(memberID: m.id, localDate: todayDate, dayNumber: nil, isPaused: false,
                               isFrozen: false, beforeStart: true, finishedRound: false, items: items)
        }
        if ms.countedDays >= Brand.roundLengthDays {
            return MemberToday(memberID: m.id, localDate: todayDate, dayNumber: nil, isPaused: false,
                               isFrozen: false, beforeStart: false, finishedRound: true, items: items)
        }
        let paused = Set(round.pause?.dates.map { $0.string } ?? [])
        let frozen = !timeline.bothActive(at: now)
        // Count numbered days between the first unsettled day and today.
        let firstOpen = ms.days.last.map { $0.date.adding(1) } ?? ms.startDate
        var n = ms.countedDays
        var d = firstOpen
        while d <= todayDate {
            if !paused.contains(d.string) { n += 1 }
            d = d.adding(1)
        }
        let isPaused = paused.contains(todayDate.string)
        return MemberToday(memberID: m.id, localDate: todayDate,
                           dayNumber: (isPaused || frozen) ? nil : min(n, Brand.roundLengthDays),
                           isPaused: isPaused, isFrozen: frozen, beforeStart: false,
                           finishedRound: false, items: items)
    }

    private static func warmupToday(member m: MemberFact, facts: Facts, now: Date) -> MemberToday {
        let todayDate = LocalDate(now, in: m.tz)
        let items = checklist(member: m, round: 1, date: todayDate, warmup: true, facts: facts, now: now)
        return MemberToday(memberID: m.id, localDate: todayDate, dayNumber: nil, isPaused: false,
                           isFrozen: false, beforeStart: true, finishedRound: false, items: items)
    }

    static func checklist(member m: MemberFact, round: Int, date: LocalDate, warmup: Bool,
                          facts: Facts, now: Date) -> [ChecklistItem] {
        let rules = effectiveRules(for: m.id, round: round, facts: facts, at: now, date: date)
        let mine = facts.checkIns.filter {
            $0.memberID == m.id && $0.localDate == date.string && $0.isWarmup == warmup
        }
        return rules.map { rule in
            let candidates = mine.filter { $0.ruleID == rule.id }
            if warmup {
                let c = candidates.max { $0.capturedAt < $1.capturedAt }
                return ChecklistItem(rule: rule, checkIn: c, state: c == nil ? .open : .done)
            }
            let best = candidates
                .map { ($0, checkState($0, now: now)) }
                .max { rank($0.1) < rank($1.1) }
            return ChecklistItem(rule: rule, checkIn: best?.0, state: best?.1 ?? .open)
        }
    }

    private static func rank(_ s: CheckState) -> Int {
        switch s { case .open: return 0; case .notSent: return 1; case .done: return 2 }
    }

    // MARK: Streaks

    /// For each day number, whether both members completed it.
    private static func coupleDays(_ r: RoundState) -> [Bool] {
        guard r.members.count == 2 else { return [] }
        let a = r.members[0].days.compactMap { $0.dayNumber == nil ? nil : $0.outcome == .complete }
        let b = r.members[1].days.compactMap { $0.dayNumber == nil ? nil : $0.outcome == .complete }
        return zip(a, b).map { $0 && $1 }
    }

    private static func trailingStreak(_ r: RoundState) -> Int {
        var s = 0
        for v in coupleDays(r).reversed() { if v { s += 1 } else { break } }
        return s
    }

    private static func bestRun(_ r: RoundState) -> Int {
        var best = 0, run = 0
        for v in coupleDays(r) { run = v ? run + 1 : 0; best = max(best, run) }
        return best
    }

    private static func todayBonus(round: RoundState, today: [MemberID: MemberToday], members: [MemberFact]) -> Int {
        let all = members.compactMap { today[$0.id] }
        guard all.count == 2, all.allSatisfy({ $0.dayNumber != nil && $0.isComplete }) else { return 0 }
        return 1
    }
}

// MARK: - Subscription timeline

/// When the couple's subscription was active. One subscription covers both partners, so the couple is active
/// whenever ANY member's subscription is.
struct SubscriptionTimeline {
    /// Sorted, non-overlapping intervals during which at least one member was subscribed.
    let intervals: [SubscriptionPeriod]

    init(members: [MemberFact]) {
        intervals = Self.merge(members.flatMap { $0.subscriptionPeriods })
    }

    func active(at t: Date) -> Bool { bothActive(at: t) }

    /// Whether the couple's subscription covers instant `t`.
    func bothActive(at t: Date) -> Bool {
        intervals.contains { $0.start <= t && t < $0.end }
    }

    /// `t` if both are active at `t`, otherwise the start of the next interval when both are.
    func nextBothActive(from t: Date) -> Date? {
        if bothActive(at: t) { return t }
        return intervals.first { $0.start > t }?.start
    }

    /// If, after `start`, a stretch without both subscriptions lasts longer than the grace period,
    /// the instant the grace period runs out.
    func abandonInstant(after start: Date) -> Date? {
        let grace = TimeInterval(Brand.lapseGraceDays) * 86_400
        var gapStart: Date? = bothActive(at: start) ? nil : start
        for iv in intervals {
            if iv.end <= start { continue }
            if let g = gapStart {
                if iv.start.timeIntervalSince(g) > grace { return g.addingTimeInterval(grace) }
                gapStart = nil
            }
            gapStart = iv.end
        }
        if let g = gapStart { return g.addingTimeInterval(grace) }
        return nil
    }

    private static func merge(_ periods: [SubscriptionPeriod]) -> [SubscriptionPeriod] {
        var out: [SubscriptionPeriod] = []
        for p in periods.sorted(by: { $0.start < $1.start }) where p.end > p.start {
            if var last = out.last, p.start <= last.end {
                last.end = max(last.end, p.end)
                out[out.count - 1] = last
            } else {
                out.append(p)
            }
        }
        return out
    }

}
