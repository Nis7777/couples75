import Foundation

// Facts are the only things ever stored in the couple's shared zone.
// Everything else (day numbers, saves, score, status, who owes) is computed by RulesEngine.
// All types are plain Codable values with no CloudKit imports.

typealias MemberID = String

/// Draft rules A writes for the partner before B joins use this placeholder member id.
enum PendingPartner {
    static let id = "pending-partner"
}

enum MemberRole: String, Codable, Equatable {
    case a = "A"
    case b = "B"
}

enum RuleType: String, Codable, Equatable {
    case photo
    case honour
}

enum RoundMode: String, Codable, Equatable {
    case standard
    case hard
}

enum FitnessLevel: String, Codable, CaseIterable, Equatable {
    case justStarting
    case somewhatActive
    case veryActive

    var title: String {
        switch self {
        case .justStarting: return "Just starting"
        case .somewhatActive: return "Somewhat active"
        case .veryActive: return "Very active"
        }
    }

    var intensity: Intensity {
        switch self {
        case .justStarting: return .gentle
        case .somewhatActive: return .standard
        case .veryActive: return .hard
        }
    }
}

/// Rule intensity, shown to users as "Gentle" / "Couples 75" / "Hard mode".
enum Intensity: String, Codable, CaseIterable, Equatable {
    case gentle
    case standard
    case hard
}

/// A continuous stretch during which a member's subscription was active.
struct SubscriptionPeriod: Codable, Equatable {
    var start: Date
    var end: Date
}

struct CoupleFact: Codable, Equatable {
    var id: String
    var createdAt: Date
    var ownerMemberID: MemberID
    var title: String
    /// The partner's name as A typed it ("Who's in this with you?"). B's member record uses it.
    var invitedName: String?
    /// What B chose on A's phone ("Hand the phone to {B}"); B sees it already made when joining.
    var invitedAvatar: Avatar?
    var invitedFitness: FitnessLevel?
    var invitedWakeTime: String?
}

struct MemberFact: Codable, Equatable, Identifiable {
    var id: MemberID
    var role: MemberRole
    var name: String
    var characterID: String
    var timeZone: String
    var wakeTime: String            // "HH:mm"
    var fitnessLevel: FitnessLevel
    /// When this member finished joining (A: after paying; B: after "I'm in", which follows paying).
    var joinedAt: Date?
    var subscribedUntil: Date?
    var subscriptionProduct: String?
    var subscriptionPeriods: [SubscriptionPeriod]
    var leftAt: Date?
    /// Avatar colour overrides ("#RRGGBB"); nil = the character's original colour.
    var skinColor: String?
    var hairColor: String?
    var jacketColor: String?

    var avatar: Avatar {
        get { Avatar(characterID: characterID, skin: skinColor, hair: hairColor, jacket: jacketColor) }
        set {
            characterID = newValue.characterID
            skinColor = newValue.skin
            hairColor = newValue.hair
            jacketColor = newValue.jacket
        }
    }

    var tz: TimeZone { TimeZone(identifier: timeZone) ?? .current }

    func isSubscribed(at date: Date) -> Bool {
        subscriptionPeriods.contains { $0.start <= date && date < $0.end }
    }

    /// Merges a new entitlement into the period list (self-reported subscription history).
    mutating func recordSubscription(product: String, purchaseDate: Date, expiration: Date) {
        subscriptionProduct = product
        subscribedUntil = max(subscribedUntil ?? expiration, expiration)
        // Small tolerance so a renewal that lands a few minutes late is one continuous period.
        let tolerance: TimeInterval = 60 * 60
        if var last = subscriptionPeriods.last, purchaseDate <= last.end.addingTimeInterval(tolerance) {
            last.end = max(last.end, expiration)
            last.start = min(last.start, purchaseDate)
            subscriptionPeriods[subscriptionPeriods.count - 1] = last
        } else {
            subscriptionPeriods.append(SubscriptionPeriod(start: purchaseDate, end: expiration))
        }
    }
}

struct RoundConfigFact: Codable, Equatable, Identifiable {
    var id: String
    var fromRound: Int
    var mode: RoundMode
    var betText: String
    var rewardText: String?
    var createdBy: MemberID
    var createdAt: Date
}

struct RuleFact: Codable, Equatable, Identifiable {
    var id: String
    var memberID: MemberID
    var fromRound: Int
    var position: Int               // 1...4
    var libraryKey: String
    var title: String
    var type: RuleType
    var createdAt: Date
    /// A custom rule's "what to photograph" hint (Write your own). Library rules use the library's prompt.
    var photoHint: String? = nil

    static let customKey = "custom"
}

/// A custom or changed rule waiting for the partner's approval (Part 8: double approval).
/// The rule replaces `ruleJSON.position` for `forMember` once the partner (never the proposer) approves.
/// - `effectiveFrom` nil: a change made before Day 1, or one for the next round (`ruleJSON.fromRound`).
/// - `effectiveFrom` set: the in-round swap (one per person per round), from that local date at the earliest.
/// An approved rule always starts the local day after the approval. Nothing is ever auto-approved.
struct RuleProposalFact: Codable, Equatable, Identifiable {
    var id: String
    var proposedBy: MemberID
    var forMember: MemberID
    var ruleJSON: RuleFact
    var effectiveFrom: String?      // yyyy-MM-dd in forMember's time zone
    var createdAt: Date

    var rule: RuleFact { ruleJSON }
    var isSwap: Bool { effectiveFrom != nil }
}

/// A copy of a progress photo shared with the partner ("Share progress pics with partner" is on).
/// Progress photos are private by default and live in the owner's own private database (ProgressPhotoStore);
/// only these copies are in the couple's shared zone, and they are deleted when sharing is turned off.
struct ProgressShareFact: Codable, Equatable, Identifiable {
    var id: String                  // = the private photo's id
    var memberID: MemberID
    var localDate: String
    var dayNumber: Int?
    var capturedAt: Date
}

struct RuleAnswerFact: Codable, Equatable, Identifiable {
    var id: String
    var proposalID: String
    var accepted: Bool
    var answeredAt: Date
}

/// B's proposal while joining: swap one rule and/or change the bet.
struct RuleTweakPayload: Codable, Equatable {
    var swappedPosition: Int?
    var newRule: RuleFact?
    var newBet: String?
}

struct RuleTweakFact: Codable, Equatable, Identifiable {
    var id: String
    var proposedBy: MemberID
    var payload: RuleTweakPayload
    var createdAt: Date
}

struct TweakAnswerFact: Codable, Equatable, Identifiable {
    var id: String
    var tweakID: String
    var accepted: Bool
    var answeredAt: Date
}

struct CheckInFact: Codable, Equatable, Identifiable {
    var id: String
    var memberID: MemberID
    var ruleID: String
    var capturedAt: Date
    var localDate: String           // yyyy-MM-dd in the member's time zone at capture
    var stampText: String
    var hasPhoto: Bool
    var isWarmup: Bool
    /// Server creationDate. nil while the record has not reached iCloud yet.
    var uploadedAt: Date?
    /// Photo rule submitted as an honour tap because the owner's iCloud was full.
    var honourFallback: Bool = false
}

enum ReactionKind: String, Codable, Equatable {
    case approve, emoji, sus, comment, seen
}

struct ReactionFact: Codable, Equatable, Identifiable {
    var id: String
    var checkInID: String
    var memberID: MemberID
    var kind: ReactionKind
    var emoji: String?
    var comment: String?
    var createdAt: Date
}

struct PauseRequestFact: Codable, Equatable, Identifiable {
    var id: String
    var requestedBy: MemberID
    var startDate: String           // yyyy-MM-dd (requester's local date)
    var days: Int
    var reason: String
    var createdAt: Date
}

struct PauseAnswerFact: Codable, Equatable, Identifiable {
    var id: String
    var pauseID: String
    var accepted: Bool
    var answeredAt: Date
}

struct BetPaidFact: Codable, Equatable, Identifiable {
    var id: String
    var roundNumber: Int
    var memberID: MemberID
    var paidAt: Date
}

/// Everything known about one couple.
struct Facts: Codable, Equatable {
    var couple: CoupleFact?
    var members: [MemberFact] = []
    var roundConfigs: [RoundConfigFact] = []
    var rules: [RuleFact] = []
    var tweaks: [RuleTweakFact] = []
    var tweakAnswers: [TweakAnswerFact] = []
    var checkIns: [CheckInFact] = []
    var reactions: [ReactionFact] = []
    var pauses: [PauseRequestFact] = []
    var pauseAnswers: [PauseAnswerFact] = []
    var betPayments: [BetPaidFact] = []
    var ruleProposals: [RuleProposalFact] = []
    var ruleAnswers: [RuleAnswerFact] = []
    var progressShares: [ProgressShareFact] = []

    static let empty = Facts()

    var memberA: MemberFact? { members.first { $0.role == .a } }
    var memberB: MemberFact? { members.first { $0.role == .b } }
    func member(_ id: MemberID) -> MemberFact? { members.first { $0.id == id } }
    func partner(of id: MemberID) -> MemberFact? { members.first { $0.id != id } }

    /// Inserts or replaces a fact by id.
    mutating func apply(_ record: FactRecord) {
        switch record {
        case .couple(let f): couple = f
        case .member(let f): Self.upsert(&members, f)
        case .roundConfig(let f): Self.upsert(&roundConfigs, f)
        case .rule(let f): Self.upsert(&rules, f)
        case .tweak(let f): Self.upsert(&tweaks, f)
        case .tweakAnswer(let f): Self.upsert(&tweakAnswers, f)
        case .checkIn(let f, _): Self.upsert(&checkIns, f)
        case .reaction(let f): Self.upsert(&reactions, f)
        case .pause(let f): Self.upsert(&pauses, f)
        case .pauseAnswer(let f): Self.upsert(&pauseAnswers, f)
        case .betPaid(let f): Self.upsert(&betPayments, f)
        case .ruleProposal(let f): Self.upsert(&ruleProposals, f)
        case .ruleAnswer(let f): Self.upsert(&ruleAnswers, f)
        case .progressShare(let f, _): Self.upsert(&progressShares, f)
        }
    }

    private static func upsert<T: Identifiable>(_ list: inout [T], _ item: T) where T.ID == String {
        if let i = list.firstIndex(where: { $0.id == item.id }) { list[i] = item } else { list.append(item) }
    }
}

/// One fact to write. Check-ins may carry photo bytes that become a CKAsset.
enum FactRecord {
    case couple(CoupleFact)
    case member(MemberFact)
    case roundConfig(RoundConfigFact)
    case rule(RuleFact)
    case tweak(RuleTweakFact)
    case tweakAnswer(TweakAnswerFact)
    case checkIn(CheckInFact, photo: Data?)
    case reaction(ReactionFact)
    case pause(PauseRequestFact)
    case pauseAnswer(PauseAnswerFact)
    case betPaid(BetPaidFact)
    case ruleProposal(RuleProposalFact)
    case ruleAnswer(RuleAnswerFact)
    case progressShare(ProgressShareFact, photo: Data?)

    var id: String {
        switch self {
        case .couple(let f): return f.id
        case .member(let f): return f.id
        case .roundConfig(let f): return f.id
        case .rule(let f): return f.id
        case .tweak(let f): return f.id
        case .tweakAnswer(let f): return f.id
        case .checkIn(let f, _): return f.id
        case .reaction(let f): return f.id
        case .pause(let f): return f.id
        case .pauseAnswer(let f): return f.id
        case .betPaid(let f): return f.id
        case .ruleProposal(let f): return f.id
        case .ruleAnswer(let f): return f.id
        case .progressShare(let f, _): return f.id
        }
    }
}

extension Facts {
    /// Lenient decoding: caches written by older builds lack the newer lists.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        couple = try c.decodeIfPresent(CoupleFact.self, forKey: .couple)
        members = try c.decodeIfPresent([MemberFact].self, forKey: .members) ?? []
        roundConfigs = try c.decodeIfPresent([RoundConfigFact].self, forKey: .roundConfigs) ?? []
        rules = try c.decodeIfPresent([RuleFact].self, forKey: .rules) ?? []
        tweaks = try c.decodeIfPresent([RuleTweakFact].self, forKey: .tweaks) ?? []
        tweakAnswers = try c.decodeIfPresent([TweakAnswerFact].self, forKey: .tweakAnswers) ?? []
        checkIns = try c.decodeIfPresent([CheckInFact].self, forKey: .checkIns) ?? []
        reactions = try c.decodeIfPresent([ReactionFact].self, forKey: .reactions) ?? []
        pauses = try c.decodeIfPresent([PauseRequestFact].self, forKey: .pauses) ?? []
        pauseAnswers = try c.decodeIfPresent([PauseAnswerFact].self, forKey: .pauseAnswers) ?? []
        betPayments = try c.decodeIfPresent([BetPaidFact].self, forKey: .betPayments) ?? []
        ruleProposals = try c.decodeIfPresent([RuleProposalFact].self, forKey: .ruleProposals) ?? []
        ruleAnswers = try c.decodeIfPresent([RuleAnswerFact].self, forKey: .ruleAnswers) ?? []
        progressShares = try c.decodeIfPresent([ProgressShareFact].self, forKey: .progressShares) ?? []
    }
}

extension String {
    static func newID() -> String { UUID().uuidString }
}
