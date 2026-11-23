import XCTest
@testable import Couples75

/// The pre-paywall screens: mirror copy, the couple score projection and editing the week-1 plan.
final class OnboardingCopyTests: XCTestCase {

    func testMirrorEchoesGoalsAndPicksThreeWins() {
        XCTAssertEqual(MirrorCopy.goalsLine([.fitness, .phoneTime], partner: "Sara"),
                       "You picked Gym and Phone time for you and Sara.")
        XCTAssertEqual(MirrorCopy.tinyWins([.phoneTime]).first, "Phones out of the bedroom tonight")
        XCTAssertEqual(MirrorCopy.tinyWins([.phoneTime]).count, 3)
        XCTAssertEqual(MirrorCopy.tinyWins(Goal.allCases).count, 3)
        XCTAssertNotNil(MirrorCopy.togetherLine("3+ yrs"))
        XCTAssertNil(MirrorCopy.togetherLine(nil))
        // Every goal has its own win.
        XCTAssertEqual(Set(Goal.allCases.map(MirrorCopy.tinyWin)).count, Goal.allCases.count)
    }

    func testScoreIsDeterministicLowerWhereTheyPickedAndHonest() {
        let a = CoupleScore.make(goals: [.fitness, .diet], quitFrequency: 2, names: "MayaJoao", rulesPerPerson: 5)
        let b = CoupleScore.make(goals: [.fitness, .diet], quitFrequency: 2, names: "MayaJoao", rulesPerPerson: 5)
        XCTAssertEqual(a.today, b.today)
        XCTAssertEqual(a.later, b.later)
        let none = CoupleScore.make(goals: [], quitFrequency: 2, names: "MayaJoao", rulesPerPerson: 5)
        XCTAssertLessThan(a.today[.fitness]!, none.today[.fitness]!)
        for s in CoupleStat.allCases { XCTAssertGreaterThan(a.later[s]!, a.today[s]!) }
        // The picked area goes up the most.
        let gain = { (s: CoupleStat) in a.later[s]! - a.today[s]! }
        XCTAssertGreaterThan(gain(.fitness), gain(.connection))
        // 90 perfect days with 5 habits each really earn Forge (level 5), not Legend.
        XCTAssertEqual(a.laterRank.id, "forge")
    }

    func testWeekOnePlanEditsPersistInThePlan() {
        var d = OnboardingDraft()
        d.goals = [.fitness, .sleep]
        d.generatePlan()
        let before = d.planRules.count
        let idea = RuleIdea.library("skincare", intensity: .standard)!
        d.addRow(idea)
        XCTAssertEqual(d.planRules.count, before + 1)
        XCTAssertEqual(d.planRules.last?.a.libraryKey, "skincare")
        // The added habit is what gets stored as a rule for both of us.
        let facts = d.makeRuleFacts(memberA: "a", now: Date())
        XCTAssertTrue(facts.rules.contains { $0.memberID == "a" && $0.libraryKey == "skincare" })
        XCTAssertTrue(facts.rules.contains { $0.memberID == PendingPartner.id && $0.libraryKey == "skincare" })
        // Never more than 6.
        while d.canAddRow { d.addRow(RuleIdea(title: "Extra \(d.planRules.count)", type: .honour, libraryKey: nil, photoHint: nil)) }
        XCTAssertEqual(d.planRules.count, Brand.maxRules)
    }
}
