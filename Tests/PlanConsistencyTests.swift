import XCTest
@testable import Couples75

/// One source of truth for rules: the plan review, the stored rules, B's copy when joining and the
/// RulesEngine (Today, invite card, widgets) must always show the same rules for both partners.
final class PlanConsistencyTests: XCTestCase {
    private let a = "member-a"
    private let b = "member-b"
    private let utc = TimeZone(identifier: "UTC")!

    private func draft() -> OnboardingDraft {
        var d = OnboardingDraft()
        d.myName = "Maya"
        d.partnerName = "Joao"
        d.goals = [.fitness, .discipline]
        d.personalGoals = [.instrument]
        d.customGoals = [CustomGoal(text: "Learn to speak chinese", name: GoalNamer.keywordName("Learn to speak chinese"))]
        d.fitness = .veryActive          // A: Hard intensity on Pact
        d.partnerFitness = nil           // B: Gentle until B answers
        d.partnerGoals = [.sleep, .money] // B picked their own goals on A's phone
        d.level = .couples75
        d.generatePlan()
        return d
    }

    /// Facts as written by "Set the stakes" (A) and "I'm in" (B), joined on 2026-01-01.
    private func facts(from d: OnboardingDraft) -> (Facts, Date) {
        let joined = LocalDate(year: 2026, month: 1, day: 1).startInstant(in: utc).addingTimeInterval(10 * 3600)
        let end = joined.addingTimeInterval(86_400 * 365)
        let periods = [SubscriptionPeriod(start: joined.addingTimeInterval(-86_400), end: end)]
        var f = Facts()
        f.couple = CoupleFact(id: "couple", createdAt: joined, ownerMemberID: a, title: "Test")
        f.members = [
            MemberFact(id: a, role: .a, name: "Maya", characterID: "w1", timeZone: "UTC", wakeTime: "07:30",
                       fitnessLevel: .veryActive, joinedAt: joined.addingTimeInterval(-3600), subscribedUntil: end,
                       subscriptionProduct: Brand.iapYearly, subscriptionPeriods: periods, leftAt: nil),
            MemberFact(id: b, role: .b, name: "Joao", characterID: "m1", timeZone: "UTC", wakeTime: "07:30",
                       fitnessLevel: .veryActive, joinedAt: joined, subscribedUntil: nil,
                       subscriptionProduct: nil, subscriptionPeriods: [], leftAt: nil),
        ]
        f.roundConfigs = [RoundConfigFact(id: "cfg", fromRound: 1, mode: d.level.mode, betText: d.betText,
                                          rewardText: nil, createdBy: a, createdAt: joined)]
        let built = d.makeRuleFacts(memberA: a, now: joined)
        f.rules = built.rules
        // B joins: an exact copy of what A's plan stored for B (B's own fitness answer doesn't regenerate them).
        let pendingForB = RulesEngine.effectiveRules(for: PendingPartner.id, round: 1, facts: f, at: joined)
        f.rules += PlanGenerator.joinerRules(from: pendingForB, memberID: b, now: joined)
        return (f, joined)
    }

    func testPlanReviewMatchesStoredRulesAndToday() {
        let d = draft()
        let (f, joined) = facts(from: d)
        let noonDay1 = joined.addingTimeInterval(26 * 3600)
        let rows = d.planRows

        let storedA = RulesEngine.effectiveRules(for: a, round: 1, facts: f, at: noonDay1).map(\.title)
        let storedB = RulesEngine.effectiveRules(for: b, round: 1, facts: f, at: noonDay1).map(\.title)
        XCTAssertEqual(storedA, rows.map(\.left), "Plan review and stored rules differ for A")
        // B's habits come from B's own goals, never from A's.
        XCTAssertEqual(storedB, d.partnerPlan?.map(\.title), "B's stored habits aren't B's own plan")

        // Today (and the widgets, which read the same engine state).
        let state = RulesEngine.state(facts: f, now: noonDay1)
        XCTAssertEqual(state.today[a]?.items.map(\.rule.title), rows.map(\.left))
        XCTAssertEqual(state.today[b]?.items.map(\.rule.title), d.partnerPlan?.map(\.title))

        // Rule types match too.
        XCTAssertEqual(RulesEngine.effectiveRules(for: a, round: 1, facts: f, at: noonDay1).map(\.type),
                       d.planRules.map(\.a.type))
    }

    func testTypedGoalBecomesARuleForBoth() {
        let d = draft()
        XCTAssertTrue(d.planRows.contains { $0.left == "Learn Chinese: 15 min" && $0.right == "Learn Chinese: 15 min" })
        XCTAssertTrue(d.planRows.contains { $0.left == "Instrument: 15 min" })
        var hard = d
        hard.level = .hard
        hard.generatePlan()
        XCTAssertTrue(hard.planRows.contains { $0.left == "Learn Chinese: 30 min" })
        var gentle = d
        gentle.level = .gentle
        gentle.generatePlan()
        XCTAssertTrue(gentle.planRows.contains { $0.left == "Learn Chinese: 10 min" })
    }

    /// Without the partner's own answers, nothing is stored for them: they pick their habits when joining.
    func testPartnerHabitsAreNeverChosenForThem() {
        var d = draft()
        d.partnerGoals = nil
        d.generatePlan()
        XCTAssertNil(d.partnerPlan)
        let built = d.makeRuleFacts(memberA: a, now: Date())
        XCTAssertFalse(built.rules.contains { $0.memberID == PendingPartner.id })
        // B's own goals make B's own habits at B's level.
        var jd = JoinDraft()
        jd.fitness = .justStarting
        jd.goals = [.skin, .money]
        jd.generatePlan()
        XCTAssertTrue(jd.plan?.contains { $0.libraryKey == "skincare" } ?? false)
        XCTAssertFalse(jd.plan?.contains { $0.libraryKey == "workout" && $0.title.contains("45") } ?? true)
        XCTAssertGreaterThanOrEqual(jd.plan?.count ?? 0, Brand.minRules)
    }

    func testRegeneratingOnlyHappensOnPurpose() {
        var d = draft()
        let before = d.planRows
        d.partnerFitness = .veryActive      // later answers don't silently change the stored plan
        XCTAssertEqual(d.planRows, before)
    }

    func testFourToSixRulesAndTrimming() {
        var d = OnboardingDraft()
        d.goals = Goal.allCases
        d.personalGoals = [.language, .meditate, .journal]
        d.generatePlan()
        XCTAssertGreaterThan(d.planRules.count, Brand.maxRules)
        XCTAssertGreaterThan(d.tooManyRules, 0)
        while d.tooManyRules > 0 {
            guard let i = d.planRules.indices.first(where: { d.canRemove($0) }) else { return XCTFail("Can't trim") }
            d.removeRow(i)
        }
        XCTAssertEqual(d.planRules.count, Brand.maxRules)
        XCTAssertGreaterThanOrEqual(d.planRules.filter { $0.a.type == .photo }.count, Brand.minPhotoRules)

        var small = OnboardingDraft()
        small.goals = [.sleep, .diet]
        small.generatePlan()
        XCTAssertGreaterThanOrEqual(small.planRules.count, Brand.minRules)
        XCTAssertGreaterThanOrEqual(small.planRules.filter { $0.a.type == .photo }.count, Brand.minPhotoRules)
    }

    func testGoalNames() {
        XCTAssertEqual(GoalNamer.keywordName("Learn to speak chinese"), "Learn Chinese")
        XCTAssertEqual(GoalNamer.keywordName("practise spanish on Duolingo"), "Learn Spanish")
        XCTAssertEqual(GoalNamer.keywordName("learn to draw"), "Learn to draw")
        XCTAssertEqual(GoalNamer.keywordName("I want to get better at guitar"), "Practise guitar")
        XCTAssertFalse(GoalNamer.keywordName("less instagram and tiktok").lowercased().contains("instagram"))
    }
}
