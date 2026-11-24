import Foundation
import CryptoKit

// The couple's data travels through Pact's own public iCloud database (never the users' personal iCloud, so a
// full iCloud can't block anyone), encrypted on the phones with a key only the two partners have. This file is
// the pure part: the key, the encryption and the message format. `RelayStore` does the iCloud calls.

/// The couple's secret: a random tag that groups its records in the database, and the AES-256 key.
struct CoupleSecret: Codable, Equatable {
    var tag: String
    var key: Data

    var symmetricKey: SymmetricKey { SymmetricKey(data: key) }
}

enum RelayCrypto {
    enum Failure: Error { case badData }

    static func newSecret() -> CoupleSecret {
        let tagBytes = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        return CoupleSecret(tag: tagBytes.map { String(format: "%02x", $0) }.joined(), key: key)
    }

    /// AES-GCM. `context` (the record's name) is authenticated, so a ciphertext can't be moved to another record.
    static func seal(_ data: Data, with secret: CoupleSecret, context: String) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: secret.symmetricKey,
                                              authenticating: Data(context.utf8)).combined else {
            throw Failure.badData
        }
        return combined
    }

    static func open(_ data: Data, with secret: CoupleSecret, context: String) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: secret.symmetricKey, authenticating: Data(context.utf8))
    }

    /// The invite: the couple's key, locked with a key derived from the 6-letter code (so only someone with
    /// the code can join). The invite record is deleted once the partner has joined.
    static func wrapKey(_ secret: CoupleSecret, code: String) throws -> Data {
        guard let combined = try AES.GCM.seal(secret.key, using: inviteKey(code: code, tag: secret.tag)).combined else {
            throw Failure.badData
        }
        return combined
    }

    static func unwrapKey(_ data: Data, code: String, tag: String) throws -> CoupleSecret {
        let box = try AES.GCM.SealedBox(combined: data)
        let key = try AES.GCM.open(box, using: inviteKey(code: code, tag: tag))
        return CoupleSecret(tag: tag, key: key)
    }

    /// The invite record's name: a hash of the code, never the code itself, so a listing of the public database
    /// can't reveal open codes (and with them the couple's key).
    static func inviteRecordName(code: String) -> String {
        let digest = SHA256.hash(data: Data("pact-invite-name-v2|\(code.uppercased())".utf8))
        return "inv." + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func inviteKey(code: String, tag: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(code.uppercased().utf8)),
                               salt: Data("pact-invite-v1".utf8), info: Data(tag.utf8), outputByteCount: 32)
    }
}

/// What one encrypted record carries.
struct RelayEnvelope: Codable, Equatable {
    enum Kind: String, Codable {
        /// A fact (check-in, habit, reaction…). The newest version of a fact wins.
        case fact
        /// "I've got your photo": the author removes it from the cloud.
        case receipt
        /// A member left the couple.
        case left
        /// A fact was deleted (a shared progress photo taken back).
        case gone
    }

    var kind: Kind
    /// Who wrote it (member id).
    var writer: String
    /// The fact's type ("CheckIn"), for facts and `gone`.
    var type: String?
    /// The fact's id, for receipts and `gone`.
    var id: String?
    /// The fact itself (JSON).
    var fact: Data?
    /// When a member left.
    var at: Date?
}

/// Facts ⇄ envelopes, and the record names.
enum RelayCodec {
    static func typeName(_ r: FactRecord) -> String {
        switch r {
        case .couple: return "Couple"
        case .member: return "Member"
        case .roundConfig: return "RoundConfig"
        case .rule: return "Rule"
        case .tweak: return "RuleTweak"
        case .tweakAnswer: return "TweakAnswer"
        case .checkIn: return "CheckIn"
        case .reaction: return "Reaction"
        case .pause: return "PauseRequest"
        case .pauseAnswer: return "PauseAnswer"
        case .betPaid: return "BetPaid"
        case .ruleProposal: return "RuleProposal"
        case .ruleAnswer: return "RuleAnswer"
        case .progressShare: return "ProgressShare"
        case .nudge: return "Nudge"
        case .bucketItem: return "BucketItem"
        }
    }

    /// Each partner writes their own version of a fact (only a record's creator may change it in the public
    /// database); the newest version wins when reading.
    static func factRecordName(id: String, writer: String) -> String { "\(id).\(writer)" }
    static func receiptRecordName(id: String, writer: String) -> String { "rcpt.\(id).\(writer)" }
    static func goneRecordName(id: String, writer: String) -> String { "gone.\(id).\(writer)" }
    static func leftRecordName(member: String) -> String { "left.\(member)" }
    /// The photo's own encryption context, so it can't be swapped with the record's data.
    static func photoContext(_ recordName: String) -> String { "photo.\(recordName)" }

    static func envelope(_ r: FactRecord, writer: String) throws -> RelayEnvelope {
        let e = LocalCache.encoder
        let data: Data
        switch r {
        case .couple(let f): data = try e.encode(f)
        case .member(let f): data = try e.encode(f)
        case .roundConfig(let f): data = try e.encode(f)
        case .rule(let f): data = try e.encode(f)
        case .tweak(let f): data = try e.encode(f)
        case .tweakAnswer(let f): data = try e.encode(f)
        case .checkIn(let f, _): data = try e.encode(f)
        case .reaction(let f): data = try e.encode(f)
        case .pause(let f): data = try e.encode(f)
        case .pauseAnswer(let f): data = try e.encode(f)
        case .betPaid(let f): data = try e.encode(f)
        case .ruleProposal(let f): data = try e.encode(f)
        case .ruleAnswer(let f): data = try e.encode(f)
        case .progressShare(let f, _): data = try e.encode(f)
        case .nudge(let f): data = try e.encode(f)
        case .bucketItem(let f): data = try e.encode(f)
        }
        return RelayEnvelope(kind: .fact, writer: writer, type: typeName(r), id: r.id, fact: data, at: nil)
    }

    /// The fact in an envelope (photos come separately).
    static func record(from env: RelayEnvelope) -> FactRecord? {
        guard env.kind == .fact, let type = env.type, let data = env.fact else { return nil }
        let d = LocalCache.decoder
        switch type {
        case "Couple": return (try? d.decode(CoupleFact.self, from: data)).map { .couple($0) }
        case "Member": return (try? d.decode(MemberFact.self, from: data)).map { .member($0) }
        case "RoundConfig": return (try? d.decode(RoundConfigFact.self, from: data)).map { .roundConfig($0) }
        case "Rule": return (try? d.decode(RuleFact.self, from: data)).map { .rule($0) }
        case "RuleTweak": return (try? d.decode(RuleTweakFact.self, from: data)).map { .tweak($0) }
        case "TweakAnswer": return (try? d.decode(TweakAnswerFact.self, from: data)).map { .tweakAnswer($0) }
        case "CheckIn": return (try? d.decode(CheckInFact.self, from: data)).map { .checkIn($0, photo: nil) }
        case "Reaction": return (try? d.decode(ReactionFact.self, from: data)).map { .reaction($0) }
        case "PauseRequest": return (try? d.decode(PauseRequestFact.self, from: data)).map { .pause($0) }
        case "PauseAnswer": return (try? d.decode(PauseAnswerFact.self, from: data)).map { .pauseAnswer($0) }
        case "BetPaid": return (try? d.decode(BetPaidFact.self, from: data)).map { .betPaid($0) }
        case "RuleProposal": return (try? d.decode(RuleProposalFact.self, from: data)).map { .ruleProposal($0) }
        case "RuleAnswer": return (try? d.decode(RuleAnswerFact.self, from: data)).map { .ruleAnswer($0) }
        case "ProgressShare": return (try? d.decode(ProgressShareFact.self, from: data)).map { .progressShare($0, photo: nil) }
        case "Nudge": return (try? d.decode(NudgeFact.self, from: data)).map { .nudge($0) }
        case "BucketItem": return (try? d.decode(BucketItemFact.self, from: data)).map { .bucketItem($0) }
        default: return nil
        }
    }

    /// The current local copy of a fact, by type and id (to upload it).
    static func localRecord(type: String, id: String, in f: Facts, photo: Data?) -> FactRecord? {
        switch type {
        case "Couple": return f.couple.flatMap { c -> FactRecord? in c.id == id ? FactRecord.couple(c) : nil }
        case "Member": return f.members.first { $0.id == id }.map { .member($0) }
        case "RoundConfig": return f.roundConfigs.first { $0.id == id }.map { .roundConfig($0) }
        case "Rule": return f.rules.first { $0.id == id }.map { .rule($0) }
        case "RuleTweak": return f.tweaks.first { $0.id == id }.map { .tweak($0) }
        case "TweakAnswer": return f.tweakAnswers.first { $0.id == id }.map { .tweakAnswer($0) }
        case "CheckIn": return f.checkIns.first { $0.id == id }.map { .checkIn($0, photo: photo) }
        case "Reaction": return f.reactions.first { $0.id == id }.map { .reaction($0) }
        case "PauseRequest": return f.pauses.first { $0.id == id }.map { .pause($0) }
        case "PauseAnswer": return f.pauseAnswers.first { $0.id == id }.map { .pauseAnswer($0) }
        case "BetPaid": return f.betPayments.first { $0.id == id }.map { .betPaid($0) }
        case "RuleProposal": return f.ruleProposals.first { $0.id == id }.map { .ruleProposal($0) }
        case "RuleAnswer": return f.ruleAnswers.first { $0.id == id }.map { .ruleAnswer($0) }
        case "ProgressShare": return f.progressShares.first { $0.id == id }.map { .progressShare($0, photo: photo) }
        case "Nudge": return f.nudges.first { $0.id == id }.map { .nudge($0) }
        case "BucketItem": return f.bucketItems.first { $0.id == id }.map { .bucketItem($0) }
        default: return nil
        }
    }

    /// Removes a fact (a `gone` marker).
    static func remove(type: String, id: String, from f: inout Facts) {
        switch type {
        case "ProgressShare": f.progressShares.removeAll { $0.id == id }
        case "CheckIn": f.checkIns.removeAll { $0.id == id }
        case "Reaction": f.reactions.removeAll { $0.id == id }
        case "BucketItem": f.bucketItems.removeAll { $0.id == id }
        case "Nudge": f.nudges.removeAll { $0.id == id }
        default: break
        }
    }
}
