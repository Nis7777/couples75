import XCTest
@testable import Pact

final class HealthMetricTests: XCTestCase {
    private func rule(_ key: String, _ title: String) -> RuleFact {
        RuleFact(id: "r", memberID: "m", fromRound: 1, position: 1, libraryKey: key, title: title, type: .photo,
                 createdAt: Date())
    }

    func testTargetsFromLibraryTitles() {
        XCTAssertEqual(HealthMetric.metric(for: rule("steps", "Steps: 8k")), .steps(8000))
        XCTAssertEqual(HealthMetric.metric(for: rule("water", "Water: 3L")), .waterLiters(3))
        XCTAssertEqual(HealthMetric.metric(for: rule("workout", "Walk: 20 min")), .exerciseMinutes(20))
        XCTAssertEqual(HealthMetric.metric(for: rule("workout", "Workout: 2 × 45 min")), .exerciseMinutes(90))
        XCTAssertEqual(HealthMetric.metric(for: rule("meditate", "Meditate: 15 min")), .mindfulMinutes(15))
        // Older titles still work.
        XCTAssertEqual(HealthMetric.metric(for: rule("steps", "10k steps")), .steps(10000))
        XCTAssertNil(HealthMetric.metric(for: rule("reading", "Read: 10 pages")))
        XCTAssertNil(HealthMetric.metric(for: rule(RuleFact.customKey, "Learn Chinese: 15 min")))
    }
}
