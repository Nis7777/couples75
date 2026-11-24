import XCTest
@testable import Pact

/// The encrypted relay: keys, encryption, the invite and facts ⇄ envelopes.
final class RelayTests: XCTestCase {

    func testSealOpenRoundTrip() throws {
        let secret = RelayCrypto.newSecret()
        let plain = Data("Workout 45m · 07:12".utf8)
        let sealed = try RelayCrypto.seal(plain, with: secret, context: "abc.member")
        XCTAssertNotEqual(sealed, plain)
        XCTAssertEqual(try RelayCrypto.open(sealed, with: secret, context: "abc.member"), plain)
    }

    func testWrongKeyOrRecordFails() throws {
        let secret = RelayCrypto.newSecret()
        let sealed = try RelayCrypto.seal(Data("hi".utf8), with: secret, context: "one")
        // Moved to another record: rejected.
        XCTAssertThrowsError(try RelayCrypto.open(sealed, with: secret, context: "two"))
        // Another couple's key: rejected.
        XCTAssertThrowsError(try RelayCrypto.open(sealed, with: RelayCrypto.newSecret(), context: "one"))
    }

    func testNewSecretsAreRandom() {
        let a = RelayCrypto.newSecret(), b = RelayCrypto.newSecret()
        XCTAssertNotEqual(a.tag, b.tag)
        XCTAssertNotEqual(a.key, b.key)
        XCTAssertEqual(a.key.count, 32)
        XCTAssertEqual(a.tag.count, 32)
    }

    func testInviteKeyNeedsTheCode() throws {
        let secret = RelayCrypto.newSecret()
        let wrapped = try RelayCrypto.wrapKey(secret, code: "K7M2QP")
        XCTAssertEqual(try RelayCrypto.unwrapKey(wrapped, code: "K7M2QP", tag: secret.tag), secret)
        XCTAssertEqual(try RelayCrypto.unwrapKey(wrapped, code: "k7m2qp", tag: secret.tag), secret)
        XCTAssertThrowsError(try RelayCrypto.unwrapKey(wrapped, code: "K7M2QR", tag: secret.tag))
    }

    func testCheckInRoundTripsWithoutThePhoto() throws {
        let c = CheckInFact(id: "c1", memberID: "a", ruleID: "r1", capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
                            localDate: "2027-01-15", stampText: "Day 3 · 07:12", hasPhoto: true, isWarmup: false,
                            uploadedAt: nil)
        let env = try RelayCodec.envelope(.checkIn(c, photo: Data([1, 2, 3])), writer: "a")
        XCTAssertEqual(env.kind, .fact)
        XCTAssertEqual(env.type, "CheckIn")
        XCTAssertEqual(env.writer, "a")
        // Through JSON, like the real records.
        let back = try JSONDecoder().decode(RelayEnvelope.self, from: JSONEncoder().encode(env))
        guard case .checkIn(let decoded, let photo)? = RelayCodec.record(from: back) else {
            return XCTFail("not a check-in")
        }
        XCTAssertEqual(decoded, c)
        XCTAssertNil(photo)
    }

    func testEveryFactTypeRoundTrips() throws {
        var f = Facts()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rule = RuleFact(id: "r1", memberID: "a", fromRound: 1, position: 1, libraryKey: "workout",
                            title: "Workout: 45 min", type: .photo, createdAt: now)
        f.apply(.rule(rule))
        let records: [FactRecord] = [
            .rule(rule),
            .reaction(ReactionFact(id: "x1", checkInID: "c1", memberID: "b", kind: .approve, emoji: nil, comment: nil,
                                   createdAt: now)),
        ]
        for r in records {
            let env = try RelayCodec.envelope(r, writer: "a")
            let back = RelayCodec.record(from: env)
            XCTAssertNotNil(back, RelayCodec.typeName(r))
            XCTAssertEqual(back?.id, r.id)
        }
        // The local copy behind a queued "Rule|r1".
        XCTAssertEqual(RelayCodec.localRecord(type: "Rule", id: "r1", in: f, photo: nil)?.id, "r1")
        XCTAssertNil(RelayCodec.localRecord(type: "Rule", id: "nope", in: f, photo: nil))
    }

    func testRecordNamesPerWriter() {
        XCTAssertNotEqual(RelayCodec.factRecordName(id: "f", writer: "a"), RelayCodec.factRecordName(id: "f", writer: "b"))
        XCTAssertNotEqual(RelayCodec.factRecordName(id: "f", writer: "a"), RelayCodec.receiptRecordName(id: "f", writer: "a"))
        XCTAssertNotEqual(RelayCodec.factRecordName(id: "f", writer: "a"),
                          RelayCodec.photoContext(RelayCodec.factRecordName(id: "f", writer: "a")))
    }

    func testGoneRemovesASharedProgressPhoto() {
        var f = Facts()
        f.apply(.progressShare(ProgressShareFact(id: "p1", memberID: "a", localDate: "2027-01-15", dayNumber: 3,
                                                 capturedAt: Date()), photo: nil))
        RelayCodec.remove(type: "ProgressShare", id: "p1", from: &f)
        XCTAssertTrue(f.progressShares.isEmpty)
    }

    /// The invite record is never named by the code itself, so a listing can't leak open codes.
    func testInviteRecordNameHidesTheCode() {
        let name = RelayCrypto.inviteRecordName(code: "K7M2QP")
        XCTAssertFalse(name.contains("K7M2QP"))
        XCTAssertEqual(name, RelayCrypto.inviteRecordName(code: "k7m2qp"))
        XCTAssertNotEqual(name, RelayCrypto.inviteRecordName(code: "K7M2QR"))
        XCTAssertTrue(name.hasPrefix("inv."))
    }

    /// The inviter's name is unreadable without the code; old plain names still work.
    func testInviterNameIsSealedWithTheCode() throws {
        let sealed = try RelayCrypto.sealInviterName("Maya", code: "K7M2QP", tag: "t1")
        XCTAssertFalse(sealed.contains("Maya"))
        XCTAssertEqual(RelayCrypto.openInviterName(sealed, code: "K7M2QP", tag: "t1"), "Maya")
        XCTAssertNil(RelayCrypto.openInviterName(sealed, code: "K7M2QR", tag: "t1"))
        XCTAssertEqual(RelayCrypto.openInviterName("Maya", code: "K7M2QP", tag: "t1"), "Maya")
    }

    /// The share link keeps the code and the name in the fragment (never sent to the web server).
    func testJoinLinkKeepsCodeAndNameInTheFragment() {
        let url = RelayStore.joinLink(code: "K7M2QP", name: "Maya Rose")
        XCTAssertNil(url?.query)
        XCTAssertEqual(url?.fragment, "code=K7M2QP&from=Maya%20Rose")
    }
}
