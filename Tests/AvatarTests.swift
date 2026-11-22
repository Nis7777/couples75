import XCTest
@testable import Couples75

final class AvatarTests: XCTestCase {
    func testCatalogueAndPalettes() {
        XCTAssertGreaterThanOrEqual(AvatarParts.hair.count, 20)
        XCTAssertEqual(Set(AvatarParts.hair.map(\.id)).count, AvatarParts.hair.count, "duplicate hair ids")
        XCTAssertEqual(AvatarPalette.skinTones.count, 10)
        XCTAssertEqual(AvatarPalette.hairColors.count, 10)
        XCTAssertEqual(AvatarPalette.clothing.count, 10)
    }

    func testEveryPresetMigratesAndKeepsItsColours() {
        for id in Characters.all {
            let c = AvatarConfig.migrated(from: Avatar(characterID: id))
            XCTAssertTrue(AvatarParts.hair.contains { $0.id == c.hairStyle }, "\(id): unknown hair \(c.hairStyle)")
            XCTAssertTrue(AvatarParts.tops.contains { $0.id == c.top })
        }
        XCTAssertEqual(AvatarConfig.migrated(from: Avatar(characterID: "w5")).hairStyle, "hijab")
        let custom = AvatarConfig.migrated(from: Avatar(characterID: "m2", skin: "#F6D7C3", hair: "#E2B96A", jacket: "#7FA38A"))
        XCTAssertEqual(custom.skinTone, "#F6D7C3")
        XCTAssertEqual(custom.hairColor, "#E2B96A")
        XCTAssertEqual(custom.topColor, "#7FA38A")
        XCTAssertEqual(custom.facialHair, "fullBeard")
    }

    func testOldAvatarJSONStillDecodes() throws {
        let old = #"{"characterID":"w1","skin":"#D9A27C"}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(Avatar.self, from: old)
        XCTAssertNil(a.config)
        XCTAssertEqual(a.resolvedConfig.hairStyle, "wavy")
        let new = Avatar(config: .default)
        let round = try JSONDecoder().decode(Avatar.self, from: JSONEncoder().encode(new))
        XCTAssertEqual(round.config, .default)
    }

    func testRandomLooksUseCataloguedParts() {
        for _ in 0..<50 {
            let c = AvatarConfig.random()
            XCTAssertTrue(AvatarParts.hair.contains { $0.id == c.hairStyle })
            XCTAssertTrue(AvatarParts.shoes.contains { $0.id == c.shoes })
        }
    }

    func testMemberRecordKeepsTheLayeredConfig() {
        var m = MemberFact(id: "a", role: .a, name: "Maya", characterID: "w1", timeZone: "UTC", wakeTime: "07:30",
                           fitnessLevel: .somewhatActive, joinedAt: nil, subscribedUntil: nil, subscriptionProduct: nil,
                           subscriptionPeriods: [], leftAt: nil)
        var cfg = AvatarConfig.default
        cfg.hairStyle = "locs"
        m.avatar = Avatar(config: cfg)
        XCTAssertEqual(m.avatar.resolvedConfig.hairStyle, "locs")
    }
}
