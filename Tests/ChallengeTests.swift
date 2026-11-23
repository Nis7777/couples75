import XCTest
@testable import Pact

/// Couple maxing: daily habits (round 1, no end), a challenge on top, back to habits afterwards.
/// The couple joined on 2026-01-01 10:00 UTC, so habits Day 1 is 2026-01-02.
final class ChallengeTests: XCTestCase {
    private let a = "member-a"
    private let b = "member-b"
    private let utc = TimeZone(identifier: "UTC")!
    private var joined: Date { LocalDate(year: 2026, month: 1, day: 1).startInstant(in: utc).addingTimeInterval(10 * 3600) }
    private let day1 = LocalDate(year: 2026, month: 1, day: 2)

    private func date(_ n: Int) -> LocalDate { day1.adding(n - 1) }
    private func noon(_ n: Int) -> Date { date(n).startInstant(in: utc).addingTimeInterval(12 * 3600) }

    private func habits() -> Facts {
        var f = Facts()
        let subStart = joined.addingTimeInterval(-86_400 * 30), subEnd = joined.addingTimeInterval(86_400 * 3650)
        f.couple = CoupleFact(id: "couple", createdAt: joined, ownerMemberID: a, title: "Test")
        for (id, role) in [(a, MemberRole.a), (b, MemberRole.b)] {
            f.members.append(MemberFact(id: id, role: role, name: id, characterID: "w1", timeZone: "UTC", wakeTime: "07:30",
                                        fitnessLevel: .somewhatActive, joinedAt: joined, subscribedUntil: subEnd,
                                        subscriptionProduct: Brand.iapMonthly,
                                        subscriptionPeriods: [SubscriptionPeriod(start: subStart, end: subEnd)], leftAt: nil))
            f.rules.append(RuleFact(id: "\(id)-h1", memberID: id, fromRound: 1, position: 1, libraryKey: "water",
                                    title: "Water: 3L", type: .photo, createdAt: joined))
        }
        f.roundConfigs = [RoundConfigFact(id: "h1", fromRound: 1, mode: .maintenance, betText: "", rewardText: nil,
                                          createdBy: a, createdAt: joined)]
        return f
    }

    /// Starts a challenge the way `AppModel.startChallenge` does: config n+1 (challenge) and n+2 (habits).
    private func start(_ f: inout Facts, days: Int, saves: Int, bet: String, at: Date) {
        f.roundConfigs.append(RoundConfigFact(id: "c2", fromRound: 2, mode: .standard, betText: bet, rewardText: nil,
                                              createdBy: a, createdAt: at, length: days, saves: saves,
                                              challengeID: "nospend7", proofRequired: false))
        f.roundConfigs.append(RoundConfigFact(id: "h3", fromRound: 3, mode: .maintenance, betText: "", rewardText: nil,
                                              createdBy: a, createdAt: at))
    }

    private func complete(_ f: inout Facts, _ member: MemberID, day n: Int, round: Int, at state: EngineState? = nil) {
        let captured = date(n).startInstant(in: utc).addingTimeInterval(10 * 3600)
        let rules = RulesEngine.effectiveRules(for: member, round: round, facts: f, at: captured)
        for r in rules {
            f.checkIns.append(CheckInFact(id: "\(member)-\(n)-\(r.id)", memberID: member, ruleID: r.id,
                                          capturedAt: captured, localDate: date(n).string, stampText: "",
                                          hasPhoto: false, isWarmup: false, uploadedAt: captured.addingTimeInterval(60)))
        }
    }

    func testHabitsNeverEndAndHaveNoStakes() {
        let f = habits()
        let s = RulesEngine.state(facts: f, now: noon(40))
        XCTAssertEqual(s.currentRound?.mode, .maintenance)
        XCTAssertEqual(s.currentRound?.status, .active)
        XCTAssertEqual(s.phase, .active)
        XCTAssertEqual(s.currentRound?.savesAllowed, 0)
    }

    func testChallengeStartsTomorrowAndTodaysHabitsStillCount() {
        var f = habits()
        start(&f, days: 7, saves: 0, bet: "", at: noon(5))
        for n in 1...5 { complete(&f, a, day: n, round: 1); complete(&f, b, day: n, round: 1) }
        // Later on Day 5: still on habits, today still open.
        let s = RulesEngine.state(facts: f, now: noon(5).addingTimeInterval(3600))
        XCTAssertEqual(s.currentRound?.number, 1)
        XCTAssertEqual(s.currentRound?.status, .active)
        // Day 6: the challenge has started (habits Day 5 settled as complete).
        let s6 = RulesEngine.state(facts: f, now: noon(6))
        XCTAssertEqual(s6.rounds.first?.status, .completed)
        XCTAssertEqual(s6.rounds.first?.member(a)?.days.last?.outcome, .complete)
        XCTAssertEqual(s6.currentRound?.number, 2)
        XCTAssertEqual(s6.currentRound?.length, 7)
        XCTAssertEqual(s6.currentRound?.challengeID, "nospend7")
        XCTAssertEqual(s6.today[a]?.dayNumber, 1)
        // One couple streak: the 5 habit days carry into the challenge.
        XCTAssertEqual(s6.streak, 5)
    }

    func testFinishedChallengeGoesBackToHabits() {
        var f = habits()
        start(&f, days: 7, saves: 0, bet: "Loser cooks", at: noon(5))
        for n in 6...12 { complete(&f, a, day: n, round: 2); complete(&f, b, day: n, round: 2) }
        let s = RulesEngine.state(facts: f, now: noon(14))
        XCTAssertEqual(s.rounds[1].status, .completed)
        XCTAssertTrue(s.rounds[1].owes.isEmpty)
        XCTAssertEqual(s.currentRound?.number, 3)
        XCTAssertEqual(s.currentRound?.mode, .maintenance)
        // XP includes the finished challenge.
        let xp = XP.compute(state: s, facts: f, now: noon(14))
        XCTAssertGreaterThanOrEqual(xp.total, Challenges.challenge("nospend7")!.xpReward)
    }

    func testNoBetMeansNobodyOwes() {
        var f = habits()
        start(&f, days: 7, saves: 0, bet: "", at: noon(5))
        complete(&f, b, day: 6, round: 2)  // A misses Day 6: out of saves, fails
        let s = RulesEngine.state(facts: f, now: noon(8))
        XCTAssertEqual(s.rounds[1].status, .failed)
        XCTAssertTrue(s.rounds[1].owes.isEmpty)
        XCTAssertEqual(s.currentRound?.mode, .maintenance)
    }

    func testGivingUpLosesTheBet() {
        var f = habits()
        start(&f, days: 30, saves: 2, bet: "Loser cooks", at: noon(5))
        for n in 6...8 { complete(&f, a, day: n, round: 2); complete(&f, b, day: n, round: 2) }
        f.roundConfigs.append(RoundConfigFact(id: "q", fromRound: 3, mode: .maintenance, betText: "", rewardText: nil,
                                              createdBy: b, createdAt: noon(9), quitBy: b))
        let s = RulesEngine.state(facts: f, now: noon(10))
        XCTAssertEqual(s.rounds[1].status, .failed)
        XCTAssertEqual(s.rounds[1].owes, [b])
        XCTAssertEqual(s.currentRound?.number, 3)
        XCTAssertEqual(s.currentRound?.mode, .maintenance)
    }

    func testCancellingBeforeDay1CostsNothing() {
        var f = habits()
        start(&f, days: 30, saves: 2, bet: "Loser cooks", at: noon(5))
        f.roundConfigs.append(RoundConfigFact(id: "q", fromRound: 3, mode: .maintenance, betText: "", rewardText: nil,
                                              createdBy: a, createdAt: noon(5).addingTimeInterval(1800), quitBy: a))
        let s = RulesEngine.state(facts: f, now: noon(7))
        XCTAssertEqual(s.rounds[1].status, .abandoned)
        XCTAssertTrue(s.rounds[1].owes.isEmpty)
        XCTAssertEqual(s.currentRound?.mode, .maintenance)
    }

    func testRanks() {
        XCTAssertEqual(Ranks.rank(for: 0).id, "spark")
        XCTAssertEqual(Ranks.rank(for: 760).id, "flame")
        XCTAssertEqual(Ranks.rank(for: 50_000).id, "legend")
        XCTAssertNil(Ranks.next(after: Ranks.rank(for: 50_000)))
        XCTAssertTrue(Challenges.all.allSatisfy { !$0.ruleIdeas().isEmpty }, "Every challenge rule is in the library")
        XCTAssertEqual(Set(Challenges.all.map(\.id)).count, Challenges.all.count)
    }
}
