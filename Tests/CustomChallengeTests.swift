import XCTest
@testable import Pact

/// "Create your own": the name, length and saves survive in the round's challenge id.
final class CustomChallengeTests: XCTestCase {
    func testCustomChallengeRoundTripsThroughItsID() {
        let idea = RuleIdea.library("reading", intensity: .standard)!
        let c = Challenges.custom(title: "  Summer | Shred  ", days: 30, saves: 2, ideas: [idea])
        XCTAssertTrue(c.isCustom)
        XCTAssertEqual(c.title, "Summer | Shred")
        XCTAssertEqual(c.ruleIdeas(), [idea])
        let back = Challenges.challenge(c.id)
        XCTAssertEqual(back?.title, "Summer | Shred")
        XCTAssertEqual(back?.days, 30)
        XCTAssertEqual(back?.saves, 2)
        XCTAssertEqual(back?.xpReward, 600)
    }

    func testEmptyNameGetsADefault() {
        XCTAssertEqual(Challenges.custom(title: "   ", days: 7, saves: 0, ideas: []).title, "Our challenge")
    }

    func testBuiltInChallengesStillResolve() {
        XCTAssertEqual(Challenges.challenge("the75")?.title, "The 75")
        XCTAssertNil(Challenges.challenge("custom|oops"))
    }
}
