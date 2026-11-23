import XCTest
@testable import Pact

/// The pact card number, the couple map's scoring and the milestones.
final class PactCardsTests: XCTestCase {

    // MARK: Card number

    func testCardNumberIsStableAndFourDigits() {
        let n = PactCardData.number(for: "8D3F1C2A-0000-4000-8000-123456789ABC")
        XCTAssertEqual(n, PactCardData.number(for: "8D3F1C2A-0000-4000-8000-123456789ABC"))
        XCTAssertEqual(n.count, 4)
        XCTAssertNotEqual(n, "0000")
        XCTAssertNotEqual(PactCardData.number(for: "couple-1"), PactCardData.number(for: "couple-2"))
    }

    // MARK: Couple map

    func testHabitsLowerTheirAxisAtTheStart() {
        let none = CoupleMapScoring.start(habitKeys: [], together: nil, level: nil)
        let fit = CoupleMapScoring.start(habitKeys: ["workout", "steps"], together: nil, level: nil)
        XCTAssertLessThan(fit[.body]!, none[.body]!)
        XCTAssertEqual(fit[.mind], none[.mind])
        let custom = CoupleMapScoring.start(habitKeys: ["custom"], together: nil, level: nil)
        XCTAssertLessThan(custom[.discipline]!, none[.discipline]!)
    }

    func testStartIsDeterministicAndInRange() {
        let keys = ["workout", "water", "reading", "sleep23", "noSpend", "skincare", "protein", "steps", "posture"]
        let a = CoupleMapScoring.start(habitKeys: keys, together: "3+ yrs", level: "hard")
        XCTAssertEqual(a, CoupleMapScoring.start(habitKeys: keys, together: "3+ yrs", level: "hard"))
        for axis in MapAxis.allCases {
            XCTAssertGreaterThanOrEqual(a[axis]!, CoupleMapScoring.floor)
            XCTAssertLessThanOrEqual(a[axis]!, 100)
        }
    }

    func testConnectionStartsHigherWhenTogetherLonger() {
        XCTAssertLessThan(CoupleMapScoring.connectionStart(together: "<1 yr", level: "steady"),
                          CoupleMapScoring.connectionStart(together: "3+ yrs", level: "steady"))
    }

    func testDailyMovesAreCappedAndFollowCheckIns() {
        let start = CoupleMapScoring.start(habitKeys: ["workout"], together: "1–3 yrs", level: "steady")
        let days = (0..<20).map { LocalDate(year: 2026, month: 3, day: 1).adding($0).string }
        let perfect = Dictionary(uniqueKeysWithValues: days.map { ($0, [MapAxis.body: 1]) })
        let oneDay = CoupleMapHistory.compute(start: start, dailyHabitCount: [.body: 1], doneByDay: perfect,
                                              connectionByDay: [:], days: [days[0]])
        XCTAssertLessThanOrEqual(oneDay.now[.body]! - start[.body]!, CoupleMapScoring.maxDailyStep + 0.0001)

        let good = CoupleMapHistory.compute(start: start, dailyHabitCount: [.body: 1], doneByDay: perfect,
                                            connectionByDay: [:], days: days)
        let bad = CoupleMapHistory.compute(start: start, dailyHabitCount: [.body: 1], doneByDay: [:],
                                           connectionByDay: [:], days: days)
        XCTAssertGreaterThan(good.now[.body]!, start[.body]!)
        XCTAssertLessThan(bad.now[.body]!, start[.body]!)
        // No habits in an area: it stays where it started.
        XCTAssertEqual(good.now[.mind], start[.mind])
    }

    func testConnectionRisesWhenYouBothCheckIn() {
        let start = CoupleMapScoring.start(habitKeys: [], together: nil, level: nil)
        let days = (0..<10).map { LocalDate(year: 2026, month: 3, day: 1).adding($0).string }
        let both = Dictionary(uniqueKeysWithValues: days.map { ($0, 1.0) })
        let h = CoupleMapHistory.compute(start: start, dailyHabitCount: [:], doneByDay: [:], connectionByDay: both,
                                         days: days)
        XCTAssertGreaterThan(h.now[.connection]!, start[.connection]!)
    }

    func testProjectionRaisesEveryAxis() {
        let keys = ["workout", "reading"]
        let start = CoupleMapScoring.start(habitKeys: keys, together: nil, level: nil)
        let later = CoupleMapScoring.projected(from: start, habitKeys: keys)
        for axis in MapAxis.allCases { XCTAssertGreaterThan(later[axis]!, start[axis]!) }
        XCTAssertGreaterThan(later[.body]! - start[.body]!, later[.rest]! - start[.rest]!)
    }

    // MARK: Milestones

    func testUnlockedMilestones() {
        let flame = Ranks.all[2]
        let m = PactMilestones.unlocked(bestStreak: 31, rank: flame,
                                        finished: [(round: 2, title: "The 75", length: 75)])
        let ids = Set(m.map(\.id))
        XCTAssertTrue(ids.contains("streak-7"))
        XCTAssertTrue(ids.contains("streak-30"))
        XCTAssertFalse(ids.contains("streak-50"))
        XCTAssertTrue(ids.contains("rank-\(Ranks.all[1].id)"))
        XCTAssertTrue(ids.contains("rank-\(flame.id)"))
        XCTAssertFalse(ids.contains("rank-\(Ranks.all[0].id)"))   // Spark is where you start, not a milestone
        XCTAssertTrue(ids.contains("challenge-2"))
    }

    func testShareText() {
        XCTAssertEqual(PactMilestones.streak(30).shareText, "Day 30 of our pact 🤝")
        XCTAssertEqual(PactMilestones.streak(30).headline, "Day 30")
    }
}
