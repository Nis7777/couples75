import XCTest
@testable import Pact

/// Builds facts for a couple that joined on 2026-01-01 10:00 UTC, so Day 1 is 2026-01-02.
private struct Fixture {
    var facts = Facts()
    let a = "member-a"
    let b = "member-b"
    let utc = TimeZone(identifier: "UTC")!
    let joined: Date
    let day1 = LocalDate(year: 2026, month: 1, day: 2)

    init(tzA: String = "UTC", tzB: String = "UTC", mode: RoundMode = .standard, reward: String? = nil) {
        joined = LocalDate(year: 2026, month: 1, day: 1).startInstant(in: TimeZone(identifier: "UTC")!)
            .addingTimeInterval(10 * 3600)
        let subStart = joined.addingTimeInterval(-86_400 * 30)
        let subEnd = joined.addingTimeInterval(86_400 * 3650)
        facts.couple = CoupleFact(id: "couple", createdAt: joined, ownerMemberID: a, title: "Test")
        facts.members = [
            MemberFact(id: a, role: .a, name: "Maya", characterID: "w1", timeZone: tzA, wakeTime: "07:30",
                       fitnessLevel: .somewhatActive, joinedAt: joined.addingTimeInterval(-3600),
                       subscribedUntil: subEnd, subscriptionProduct: Brand.iapMonthly,
                       subscriptionPeriods: [SubscriptionPeriod(start: subStart, end: subEnd)], leftAt: nil),
            MemberFact(id: b, role: .b, name: "Joao", characterID: "m1", timeZone: tzB, wakeTime: "07:30",
                       fitnessLevel: .somewhatActive, joinedAt: joined,
                       subscribedUntil: subEnd, subscriptionProduct: Brand.iapMonthly,
                       subscriptionPeriods: [SubscriptionPeriod(start: subStart, end: subEnd)], leftAt: nil),
        ]
        facts.roundConfigs = [RoundConfigFact(id: "cfg1", fromRound: 1, mode: mode, betText: "Loser plans the date",
                                              rewardText: reward, createdBy: a, createdAt: joined)]
        for (member, prefix) in [(a, "a"), (b, "b")] {
            for p in 1...4 {
                facts.rules.append(RuleFact(id: "\(prefix)\(p)", memberID: member, fromRound: 1, position: p,
                                            libraryKey: "k\(p)", title: "Rule \(p)",
                                            type: p <= 2 ? .photo : .honour, createdAt: joined))
            }
        }
    }

    func member(_ id: MemberID) -> MemberFact { facts.member(id)! }
    func date(_ n: Int) -> LocalDate { day1.adding(n - 1) }
    /// Noon UTC on round day n (for UTC members).
    func noon(_ n: Int) -> Date { date(n).startInstant(in: utc).addingTimeInterval(12 * 3600) }

    mutating func complete(_ member: MemberID, day n: Int, uploadDelay: TimeInterval = 60, warmup: Bool = false) {
        let m = self.member(member)
        let date = self.date(n)
        let captured = date.startInstant(in: m.tz).addingTimeInterval(10 * 3600)
        let prefix = member == a ? "a" : "b"
        for p in 1...4 {
            facts.checkIns.append(CheckInFact(id: "\(member)-\(n)-\(p)", memberID: member, ruleID: "\(prefix)\(p)",
                                              capturedAt: captured, localDate: date.string, stampText: "",
                                              hasPhoto: false, isWarmup: warmup,
                                              uploadedAt: captured.addingTimeInterval(uploadDelay)))
        }
    }

    mutating func completeBoth(_ days: ClosedRange<Int>) {
        for n in days { complete(a, day: n); complete(b, day: n) }
    }

    func state(at now: Date) -> EngineState { RulesEngine.state(facts: facts, now: now) }
}

final class RulesEngineTests: XCTestCase {

    func testNormalCompleteDay() {
        var f = Fixture()
        f.completeBoth(1...1)
        let s = f.state(at: f.noon(2))
        XCTAssertEqual(s.phase, .active)
        let r = s.currentRound!
        XCTAssertEqual(r.status, .active)
        XCTAssertEqual(r.savesUsed, 0)
        XCTAssertEqual(r.member(f.a)?.days.first?.outcome, .complete)
        XCTAssertEqual(r.member(f.b)?.days.first?.outcome, .complete)
        XCTAssertEqual(s.today[f.a]?.dayNumber, 2)
        XCTAssertEqual(s.streak, 1)
    }

    func testBeforeDayOneIsWarmup() {
        let f = Fixture()
        let s = f.state(at: f.joined.addingTimeInterval(3600))
        XCTAssertEqual(s.phase, .warmup)
        XCTAssertNil(s.today[f.a]?.dayNumber)
    }

    func testOneMissUsesASave() {
        var f = Fixture()
        f.complete(f.a, day: 1)
        let s = f.state(at: f.noon(2))
        let r = s.currentRound!
        XCTAssertEqual(r.savesUsed, 1)
        XCTAssertEqual(r.savesLeft, 2)
        XCTAssertEqual(r.misses(f.b), 1)
        XCTAssertEqual(r.misses(f.a), 0)
        XCTAssertEqual(r.saveEvents.count, 1)
        XCTAssertEqual(r.saveEvents.first?.dayNumber, 1)
        XCTAssertEqual(r.member(f.b)?.days.first?.coveredBySave, true)
    }

    func testFourthMissEndsRoundAndStartsNext() {
        var f = Fixture()
        for n in 1...4 { f.complete(f.a, day: n) }
        let s = f.state(at: f.noon(5))
        XCTAssertEqual(s.rounds.count, 2)
        let r1 = s.rounds[0]
        XCTAssertEqual(r1.status, .failed)
        XCTAssertEqual(r1.failedOnDay, 4)
        XCTAssertEqual(r1.misses(f.b), 4)
        XCTAssertEqual(r1.owes, [f.b])
        let r2 = s.rounds[1]
        XCTAssertEqual(r2.status, .waiting)
        XCTAssertEqual(r2.member(f.a)?.startDate, f.date(6))
        XCTAssertEqual(r2.betText, "Loser plans the date")
        XCTAssertEqual(s.phase, .betweenRounds)

        // Round 2 runs with the same rules once its Day 1 arrives.
        let later = f.state(at: f.noon(6))
        XCTAssertEqual(later.phase, .active)
        XCTAssertEqual(later.today[f.a]?.dayNumber, 1)
        XCTAssertEqual(later.currentRound?.number, 2)
    }

    func testBothMissSameDay() {
        var f = Fixture()
        // Both miss day 1 (2 saves), A misses day 2 (3rd save), both miss day 3 -> out of saves.
        f.complete(f.b, day: 2)
        let s = f.state(at: f.noon(4))
        let r1 = s.rounds[0]
        XCTAssertEqual(r1.status, .failed)
        XCTAssertEqual(r1.failedOnDay, 3)
        XCTAssertEqual(r1.misses(f.a), 3)
        XCTAssertEqual(r1.misses(f.b), 2)
        XCTAssertEqual(r1.owes, [f.a])
    }

    func testBothMissFirstDayUsesTwoSaves() {
        let f = Fixture()
        let r = f.state(at: f.noon(2)).currentRound!
        XCTAssertEqual(r.savesUsed, 2)
        XCTAssertEqual(r.misses(f.a), 1)
        XCTAssertEqual(r.misses(f.b), 1)
    }

    func testHardModeOneMissEndsRound() {
        var f = Fixture(mode: .hard)
        f.complete(f.a, day: 1)
        let r1 = f.state(at: f.noon(2)).rounds[0]
        XCTAssertEqual(r1.savesAllowed, 0)
        XCTAssertEqual(r1.status, .failed)
        XCTAssertEqual(r1.failedOnDay, 1)
        XCTAssertEqual(r1.owes, [f.b])
    }

    func testTieAboveZeroBothOwe() {
        let f = Fixture(mode: .hard)
        let r1 = f.state(at: f.noon(2)).rounds[0]
        XCTAssertEqual(r1.status, .failed)
        XCTAssertEqual(Set(r1.owes), Set([f.a, f.b]))
    }

    func testUnequalMissesLoserOwes() {
        var f = Fixture()
        // B misses 3, A misses 1 (day 4), round fails on day 4.
        f.complete(f.a, day: 1); f.complete(f.a, day: 2); f.complete(f.a, day: 3)
        f.complete(f.b, day: 4)
        let r1 = f.state(at: f.noon(5)).rounds[0]
        XCTAssertEqual(r1.status, .failed)
        XCTAssertEqual(r1.misses(f.a), 1)
        XCTAssertEqual(r1.misses(f.b), 3)
        XCTAssertEqual(r1.owes, [f.b])
    }

    func testDay75CompletionTieAtZeroUnlocksReward() {
        var f = Fixture(reward: "Weekend away")
        f.completeBoth(1...75)
        let s = f.state(at: f.noon(76))
        let r = s.rounds[0]
        XCTAssertEqual(r.status, .completed)
        XCTAssertEqual(r.member(f.a)?.countedDays, 75)
        XCTAssertEqual(r.owes, [])
        XCTAssertTrue(r.rewardUnlocked)
        XCTAssertEqual(s.phase, .betweenRounds)
        XCTAssertEqual(s.bestStreak, 75)
        XCTAssertEqual(s.rounds.count, 1, "Round 2 only starts after Start round 2")
    }

    func testCompletedRoundStartsRoundTwoAfterNewConfig() {
        var f = Fixture()
        f.completeBoth(1...75)
        f.facts.roundConfigs.append(RoundConfigFact(id: "cfg2", fromRound: 2, mode: .hard, betText: "Loser cooks",
                                                    rewardText: nil, createdBy: f.a, createdAt: f.noon(76)))
        let s = f.state(at: f.noon(77))
        XCTAssertEqual(s.rounds.count, 2)
        XCTAssertEqual(s.rounds[1].mode, .hard)
        XCTAssertEqual(s.rounds[1].member(f.a)?.startDate, f.date(77))
        XCTAssertEqual(s.today[f.a]?.dayNumber, 1)
    }

    // MARK: Pauses

    private func addPause(_ f: inout Fixture, start: Int, days: Int, createdAt: Date) -> String {
        let id = "pause-\(start)"
        f.facts.pauses.append(PauseRequestFact(id: id, requestedBy: f.a, startDate: f.date(start).string,
                                               days: days, reason: "Sick", createdAt: createdAt))
        return id
    }

    func testPauseAccepted() {
        var f = Fixture()
        f.completeBoth(1...1)
        let id = addPause(&f, start: 2, days: 2, createdAt: f.date(2).startInstant(in: f.utc).addingTimeInterval(3600))
        f.facts.pauseAnswers.append(PauseAnswerFact(id: "ans", pauseID: id, accepted: true,
                                                    answeredAt: f.date(2).startInstant(in: f.utc).addingTimeInterval(7200)))
        f.completeBoth(4...4)
        let s = f.state(at: f.noon(5))
        let r = s.currentRound!
        XCTAssertEqual(r.savesUsed, 0)
        let aDays = r.member(f.a)!.days
        XCTAssertEqual(aDays.map { $0.outcome }, [.complete, .paused, .paused, .complete])
        XCTAssertEqual(aDays.last?.dayNumber, 2)
        XCTAssertEqual(s.today[f.a]?.dayNumber, 3)
        XCTAssertNil(s.pendingPause)
    }

    func testPauseDeclinedDoesNotPauseAndDoesNotUseThePause() {
        var f = Fixture()
        f.completeBoth(1...1)
        let id = addPause(&f, start: 2, days: 1, createdAt: f.date(2).startInstant(in: f.utc).addingTimeInterval(3600))
        f.facts.pauseAnswers.append(PauseAnswerFact(id: "ans", pauseID: id, accepted: false,
                                                    answeredAt: f.date(2).startInstant(in: f.utc).addingTimeInterval(7200)))
        // A second request later in the round is still allowed.
        let id2 = addPause(&f, start: 4, days: 1, createdAt: f.date(4).startInstant(in: f.utc).addingTimeInterval(3600))
        f.completeBoth(3...3)
        let s = f.state(at: f.noon(5))
        let r = s.currentRound!
        XCTAssertEqual(r.savesUsed, 2, "Both missed day 2")
        XCTAssertEqual(r.pause?.request.id, id2)
        XCTAssertEqual(r.member(f.a)?.days.last?.outcome, .paused)
    }

    func testPauseAutoAcceptedAfterTwelveHours() {
        var f = Fixture()
        f.completeBoth(1...1)
        _ = addPause(&f, start: 2, days: 1, createdAt: f.date(2).startInstant(in: f.utc).addingTimeInterval(3600))
        let s = f.state(at: f.noon(3))
        XCTAssertEqual(s.currentRound?.pause?.status, .accepted)
        XCTAssertEqual(s.currentRound?.member(f.b)?.days.last?.outcome, .paused)
        XCTAssertEqual(s.currentRound?.savesUsed, 0)
    }

    func testPausePendingAtMidnightWaits() {
        var f = Fixture()
        f.completeBoth(1...1)
        let created = f.date(2).startInstant(in: f.utc).addingTimeInterval(23 * 3600)
        let id = addPause(&f, start: 2, days: 1, createdAt: created)
        let pending = f.state(at: created.addingTimeInterval(2 * 3600))
        XCTAssertEqual(pending.currentRound?.member(f.a)?.days.count, 1, "Day 2 must not settle yet")
        XCTAssertEqual(pending.currentRound?.savesUsed, 0)
        XCTAssertNotNil(pending.pendingPause)

        f.facts.pauseAnswers.append(PauseAnswerFact(id: "ans", pauseID: id, accepted: true,
                                                    answeredAt: created.addingTimeInterval(3 * 3600)))
        let resolved = f.state(at: created.addingTimeInterval(4 * 3600))
        XCTAssertEqual(resolved.currentRound?.member(f.a)?.days.last?.outcome, .paused)
        XCTAssertEqual(resolved.currentRound?.savesUsed, 0)
        XCTAssertNil(resolved.pendingPause)
    }

    // MARK: Time zones and validity

    func testTimeZonesEightHoursApart() {
        var f = Fixture(tzA: "UTC", tzB: "Asia/Shanghai")
        f.complete(f.b, day: 1)
        // Jan 2 20:00 UTC = Jan 3 04:00 in Shanghai: B's day 1 is final, A's isn't.
        let now = f.date(1).startInstant(in: f.utc).addingTimeInterval(20 * 3600)
        let s = f.state(at: now)
        let r = s.currentRound!
        XCTAssertEqual(r.member(f.b)?.days.count, 1)
        XCTAssertEqual(r.member(f.b)?.days.first?.outcome, .complete)
        XCTAssertEqual(r.member(f.a)?.days.count, 0)
        XCTAssertEqual(s.today[f.a]?.dayNumber, 1)
        XCTAssertEqual(s.today[f.b]?.dayNumber, 2)
        XCTAssertEqual(s.today[f.b]?.localDate, f.date(2))
        XCTAssertEqual(r.savesUsed, 0)
    }

    func testLateUploadIsIgnored() {
        var f = Fixture()
        f.complete(f.a, day: 1, uploadDelay: 7 * 3600)
        f.complete(f.b, day: 1)
        let r = f.state(at: f.noon(2)).currentRound!
        XCTAssertEqual(r.misses(f.a), 1)
        XCTAssertEqual(r.misses(f.b), 0)
    }

    func testNotYetUploadedShowsNotSentThenExpires() {
        var f = Fixture()
        let captured = f.noon(1)
        f.facts.checkIns.append(CheckInFact(id: "x", memberID: f.a, ruleID: "a1", capturedAt: captured,
                                            localDate: f.date(1).string, stampText: "", hasPhoto: true,
                                            isWarmup: false, uploadedAt: nil))
        let soon = f.state(at: captured.addingTimeInterval(3600))
        XCTAssertEqual(soon.today[f.a]?.items.first?.state, .notSent)
        let late = f.state(at: captured.addingTimeInterval(7 * 3600))
        XCTAssertEqual(late.today[f.a]?.items.first?.state, .open)
    }

    func testWarmupCheckInsAreIgnored() {
        var f = Fixture()
        f.complete(f.a, day: 1, warmup: true)
        f.complete(f.b, day: 1)
        let r = f.state(at: f.noon(2)).currentRound!
        XCTAssertEqual(r.misses(f.a), 1)
    }

    // MARK: Subscriptions

    private func lapse(_ f: inout Fixture, member: MemberID, at end: Date, renewAt: Date? = nil) {
        let i = f.facts.members.firstIndex { $0.id == member }!
        var periods = [SubscriptionPeriod(start: f.joined.addingTimeInterval(-86_400 * 30), end: end)]
        if let r = renewAt { periods.append(SubscriptionPeriod(start: r, end: r.addingTimeInterval(86_400 * 365))) }
        f.facts.members[i].subscriptionPeriods = periods
        f.facts.members[i].subscribedUntil = periods.last!.end
    }

    func testOneSubscriptionCoversBoth() {
        var f = Fixture()
        // B never subscribes: A's subscription covers the couple.
        let i = f.facts.members.firstIndex { $0.id == f.b }!
        f.facts.members[i].subscriptionPeriods = []
        f.facts.members[i].subscribedUntil = nil
        f.completeBoth(1...2)
        let s = f.state(at: f.noon(3))
        XCTAssertTrue(s.coupleActive)
        XCTAssertFalse(s.isFrozen)
        XCTAssertEqual(s.payerID, f.a)
        XCTAssertEqual(s.currentRound?.member(f.b)?.days.count, 2)
        XCTAssertEqual(s.today[f.b]?.dayNumber, 3)
    }

    func testPartnerLapseAloneDoesNotFreeze() {
        var f = Fixture()
        f.completeBoth(1...2)
        lapse(&f, member: f.b, at: f.date(3).startInstant(in: f.utc))
        let s = f.state(at: f.noon(3))
        XCTAssertFalse(s.isFrozen)
        XCTAssertTrue(s.coupleActive)
    }

    func testSubscriptionLapseFreezes() {
        var f = Fixture()
        f.completeBoth(1...2)
        lapse(&f, member: f.a, at: f.date(3).startInstant(in: f.utc))
        lapse(&f, member: f.b, at: f.date(3).startInstant(in: f.utc))
        let s = f.state(at: f.noon(5))
        let r = s.currentRound!
        XCTAssertEqual(r.status, .active)
        XCTAssertTrue(s.isFrozen)
        XCTAssertFalse(s.coupleActive)
        XCTAssertEqual(Set(s.lapsedMembers), Set([f.a, f.b]))
        XCTAssertEqual(r.savesUsed, 0)
        XCTAssertEqual(r.member(f.a)?.days.map { $0.outcome }, [.complete, .complete, .frozen, .frozen])
    }

    func testSubscriptionLapseAbandonsAfterGrace() {
        var f = Fixture()
        f.completeBoth(1...2)
        let end = f.date(3).startInstant(in: f.utc)
        lapse(&f, member: f.a, at: end)
        lapse(&f, member: f.b, at: end)
        let s = f.state(at: end.addingTimeInterval(86_400 * 8))
        let r = s.rounds[0]
        XCTAssertEqual(r.status, .abandoned)
        XCTAssertEqual(r.owes, [])
        XCTAssertEqual(r.endedAt, end.addingTimeInterval(86_400 * 7))
        XCTAssertEqual(s.rounds.count, 1)
        XCTAssertEqual(s.phase, .betweenRounds)
    }

    func testRenewalWithinGraceContinuesRun() {
        var f = Fixture()
        f.completeBoth(1...2)
        let end = f.date(3).startInstant(in: f.utc)
        lapse(&f, member: f.a, at: end, renewAt: end.addingTimeInterval(86_400 * 2 + 3600))
        lapse(&f, member: f.b, at: end)
        f.completeBoth(5...5)
        let s = f.state(at: f.noon(6))
        let r = s.currentRound!
        XCTAssertEqual(r.status, .active)
        XCTAssertFalse(s.isFrozen)
        XCTAssertEqual(r.savesUsed, 0)
        XCTAssertEqual(r.member(f.a)?.days.map { $0.outcome }, [.complete, .complete, .frozen, .frozen, .complete])
        XCTAssertEqual(s.today[f.a]?.dayNumber, 4)
    }

    // MARK: Tweaks

    func testTweakSwapsRuleAndBetUnlessDeclined() {
        var f = Fixture()
        let newRule = RuleFact(id: "b-new", memberID: f.b, fromRound: 1, position: 4, libraryKey: "sleep",
                               title: "In bed by 23:30", type: .honour, createdAt: f.joined)
        f.facts.tweaks.append(RuleTweakFact(id: "t1", proposedBy: f.b,
                                            payload: RuleTweakPayload(swappedPosition: 4, newRule: newRule,
                                                                      newBet: "Loser cooks dinner for a week"),
                                            createdAt: f.joined))
        let rules = RulesEngine.effectiveRules(for: f.b, round: 1, facts: f.facts, at: f.noon(1))
        XCTAssertEqual(rules.map { $0.id }, ["b1", "b2", "b3", "b-new"])
        XCTAssertEqual(RulesEngine.betText(for: 1, facts: f.facts, at: f.noon(1)), "Loser cooks dinner for a week")

        f.facts.tweakAnswers.append(TweakAnswerFact(id: "ta", tweakID: "t1", accepted: false,
                                                    answeredAt: f.joined.addingTimeInterval(3600)))
        let declined = RulesEngine.effectiveRules(for: f.b, round: 1, facts: f.facts, at: f.noon(1))
        XCTAssertEqual(declined.map { $0.id }, ["b1", "b2", "b3", "b4"])
        XCTAssertEqual(RulesEngine.betText(for: 1, facts: f.facts, at: f.noon(1)), "Loser plans the date")
    }

    // MARK: Rule proposals (double approval)

    private func swap(_ id: String, for member: MemberID, by proposer: MemberID, position: Int, f: Fixture,
                      createdAt: Date, effectiveFrom: LocalDate?) -> RuleProposalFact {
        let rule = RuleFact(id: "rule-\(id)", memberID: member, fromRound: 1, position: position,
                            libraryKey: RuleFact.customKey, title: "Custom \(id)", type: .honour, createdAt: createdAt)
        return RuleProposalFact(id: id, proposedBy: proposer, forMember: member, ruleJSON: rule,
                                effectiveFrom: effectiveFrom?.string, createdAt: createdAt)
    }

    func testPendingProposalDoesNotCount() {
        var f = Fixture()
        f.facts.ruleProposals.append(swap("p1", for: f.a, by: f.a, position: 4, f: f,
                                          createdAt: f.joined, effectiveFrom: nil))
        // Never auto-approved, however long it waits: the original rule stays active.
        let rules = RulesEngine.effectiveRules(for: f.a, round: 1, facts: f.facts, at: f.noon(30))
        XCTAssertEqual(rules.map { $0.id }, ["a1", "a2", "a3", "a4"])
        XCTAssertEqual(RulesEngine.pendingProposals(facts: f.facts, at: f.noon(30)).map { $0.id }, ["p1"])
        // Pending never blocks Day 1: the original rules settle the day.
        f.completeBoth(1...1)
        XCTAssertEqual(f.state(at: f.noon(2)).currentRound?.member(f.a)?.days.first?.outcome, .complete)

        // Declined also keeps the original.
        f.facts.ruleAnswers.append(RuleAnswerFact(id: "ra", proposalID: "p1", accepted: false, answeredAt: f.noon(1)))
        XCTAssertEqual(RulesEngine.effectiveRules(for: f.a, round: 1, facts: f.facts, at: f.noon(5)).map { $0.id },
                       ["a1", "a2", "a3", "a4"])
    }

    func testApprovedSwapStartsTheNextLocalDay() {
        var f = Fixture()
        f.completeBoth(1...3)
        f.facts.ruleProposals.append(swap("p1", for: f.a, by: f.a, position: 4, f: f,
                                          createdAt: f.noon(3), effectiveFrom: f.date(4)))
        // Approved by B in the evening of Day 4: still the old rule on Day 4, the new one from Day 5.
        f.facts.ruleAnswers.append(RuleAnswerFact(id: "ra", proposalID: "p1", accepted: true,
                                                  answeredAt: f.noon(4).addingTimeInterval(6 * 3600)))
        let day4 = RulesEngine.effectiveRules(for: f.a, round: 1, facts: f.facts, at: f.noon(5), date: f.date(4))
        XCTAssertEqual(day4.map { $0.id }, ["a1", "a2", "a3", "a4"])
        let day5 = RulesEngine.effectiveRules(for: f.a, round: 1, facts: f.facts, at: f.noon(5), date: f.date(5))
        XCTAssertEqual(day5.map { $0.id }, ["a1", "a2", "a3", "rule-p1"])
        XCTAssertEqual(f.state(at: f.noon(5)).today[f.a]?.items.map { $0.rule.id }, ["a1", "a2", "a3", "rule-p1"])

        // Day 4 is judged on the old rules (all done), Day 5 on the new one (a4 no longer counts).
        f.complete(f.a, day: 4); f.complete(f.b, day: 4)
        f.complete(f.a, day: 5); f.complete(f.b, day: 5)
        let s = f.state(at: f.noon(6))
        let a = s.currentRound?.member(f.a)?.days
        XCTAssertEqual(a?.first { $0.dayNumber == 4 }?.outcome, .complete)
        XCTAssertEqual(a?.first { $0.dayNumber == 5 }?.outcome, .miss)
    }

    func testSecondSwapInARoundIsRejected() {
        var f = Fixture()
        f.facts.ruleProposals.append(swap("p1", for: f.a, by: f.a, position: 4, f: f,
                                          createdAt: f.noon(2), effectiveFrom: f.date(3)))
        f.facts.ruleProposals.append(swap("p2", for: f.a, by: f.a, position: 3, f: f,
                                          createdAt: f.noon(3), effectiveFrom: f.date(4)))
        XCTAssertTrue(RulesEngine.swapUsed(by: f.a, round: 1, facts: f.facts, at: f.noon(2)))
        f.facts.ruleAnswers.append(RuleAnswerFact(id: "r1", proposalID: "p1", accepted: true, answeredAt: f.noon(2)))
        f.facts.ruleAnswers.append(RuleAnswerFact(id: "r2", proposalID: "p2", accepted: true, answeredAt: f.noon(3)))
        let rules = RulesEngine.effectiveRules(for: f.a, round: 1, facts: f.facts, at: f.noon(10), date: f.date(10))
        XCTAssertEqual(rules.map { $0.id }, ["a1", "a2", "a3", "rule-p1"])
        // B's swap is B's own: unaffected by A's.
        XCTAssertFalse(RulesEngine.swapUsed(by: f.b, round: 1, facts: f.facts, at: f.noon(3)))
    }

    func testProposalForPendingPartnerBelongsToB() {
        var f = Fixture()
        f.facts.ruleProposals.append(swap("p1", for: PendingPartner.id, by: f.a, position: 2, f: f,
                                          createdAt: f.joined.addingTimeInterval(-7200), effectiveFrom: nil))
        f.facts.ruleAnswers.append(RuleAnswerFact(id: "r1", proposalID: "p1", accepted: true,
                                                  answeredAt: f.joined.addingTimeInterval(600)))
        // Approved on the warm-up day: starts on Day 1.
        let rules = RulesEngine.effectiveRules(for: f.b, round: 1, facts: f.facts, at: f.noon(1), date: f.date(1))
        XCTAssertEqual(rules.map { $0.id }, ["b1", "rule-p1", "b3", "b4"])
        XCTAssertEqual(rules[1].memberID, f.b)
    }

    // MARK: Streak shields

    func testStreakShields() {
        // 7 complete days earn a shield; the 8th day missed uses it, so the streak survives.
        let r1 = RulesEngine.streakRun(Array(repeating: true, count: 7) + [false, true])
        XCTAssertEqual(r1.current, 8)
        XCTAssertEqual(r1.shieldsUsed, 1)
        XCTAssertEqual(r1.shields, 0)
        // Without a shield a miss resets it.
        let r2 = RulesEngine.streakRun([true, true, false, true])
        XCTAssertEqual(r2.current, 1)
        XCTAssertEqual(r2.best, 2)
        // At most 2 shields are banked.
        XCTAssertEqual(RulesEngine.streakRun(Array(repeating: true, count: 30)).shields, 2)
    }

    // MARK: Maintenance mode

    func testMaintenanceHasNoStakesAndEndsWhenANewRoundStarts() {
        var f = Fixture()
        f.completeBoth(1...75)
        f.facts.roundConfigs.append(RoundConfigFact(id: "cfg2", fromRound: 2, mode: .maintenance, betText: "",
                                                    rewardText: nil, createdBy: f.a, createdAt: f.noon(76)))
        // Days 77–79 missed by both: maintenance never fails and uses no saves.
        let s = f.state(at: f.noon(80))
        XCTAssertEqual(s.rounds.first?.status, .completed)
        let m = s.currentRound
        XCTAssertEqual(m?.number, 2)
        XCTAssertEqual(m?.mode, .maintenance)
        XCTAssertEqual(m?.status, .active)
        XCTAssertEqual(m?.savesUsed, 0)
        XCTAssertEqual(m?.misses(f.a), 3)
        XCTAssertTrue(m?.owes.isEmpty ?? false)

        // A new 75 ends maintenance (no bet) and starts the next day.
        f.facts.roundConfigs.append(RoundConfigFact(id: "cfg3", fromRound: 3, mode: .standard, betText: "Loser cooks",
                                                    rewardText: nil, createdBy: f.a, createdAt: f.noon(81)))
        let later = f.state(at: f.noon(83))
        XCTAssertEqual(later.rounds[1].status, .completed)
        XCTAssertTrue(later.rounds[1].owes.isEmpty)
        XCTAssertEqual(later.currentRound?.number, 3)
        XCTAssertEqual(later.currentRound?.mode, .standard)
    }

    // MARK: Weekly recap

    func testWeeklyRecapCountsTheLastSevenDays() {
        var f = Fixture()
        f.completeBoth(1...7)
        let s = f.state(at: f.noon(9))
        // Window: Day 2 … Day 8 (the 7 days ending yesterday). Day 8 was missed by both.
        let r = WeeklyRecap.make(state: s, facts: f.facts, meID: f.a, partnerID: f.b, today: f.date(9))
        XCTAssertEqual(r?.me.countedDays, 7)
        XCTAssertEqual(r?.me.completeDays, 6)
        XCTAssertEqual(r?.partner?.completeDays, 6)
        XCTAssertEqual(r?.bothCompleteDays, 6)
        XCTAssertEqual(r?.weekStart, f.date(2))
        // Nothing counted yet: no recap.
        XCTAssertNil(WeeklyRecap.make(state: f.state(at: f.joined), facts: f.facts, meID: f.a, partnerID: f.b,
                                      today: f.date(0)))
    }

    // MARK: Determinism

    func testSameFactsSameState() {
        var f = Fixture()
        f.completeBoth(1...3)
        f.complete(f.a, day: 4)
        let now = f.noon(6)
        let s1 = f.state(at: now)
        var shuffled = f.facts
        shuffled.checkIns.reverse()
        shuffled.rules.reverse()
        shuffled.members.reverse()
        let s2 = RulesEngine.state(facts: shuffled, now: now)
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(s1, f.state(at: now))
    }

    func testLocalDateRoundTrip() {
        let d = LocalDate(string: "2026-11-21")!
        XCTAssertEqual(d.string, "2026-11-21")
        XCTAssertEqual(d.adding(10).string, "2026-12-01")
        XCTAssertEqual(d.weekday, 7) // Saturday
    }
}
