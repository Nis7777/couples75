import Foundation

#if DEBUG
/// Mock mode (section 7): both members' facts live in one local JSON file.
/// Used in the Simulator, with the DEBUG `-mock` launch argument, or when DEBUG builds have no iCloud.
@MainActor
final class MockStore: Store {
    struct State: Codable {
        var facts = Facts()
        var invite: InviteInfo?
        /// Debug time travel ("Advance to next day").
        var clockOffset: TimeInterval = 0
        var waitlist: [String] = []
    }

    private static let fileName = "mock_state.json"
    private(set) var state: State

    init() {
        state = LocalCache.read(State.self, from: Self.fileName) ?? State()
    }

    var isMock: Bool { true }
    var pendingUploads: Int { 0 }
    var clockOffset: TimeInterval {
        get { state.clockOffset }
        set { state.clockOffset = newValue; persist() }
    }

    private func persist() { LocalCache.write(state, to: Self.fileName) }

    func cachedFacts() -> Facts { state.facts }

    func fetchChanges() async throws -> Facts { state.facts }

    func save(_ records: [FactRecord]) async throws -> Facts {
        for r in records {
            if case .checkIn(_, let photo) = r, let photo {
                LocalCache.savePhoto(photo, checkInID: r.id)
            }
            if case .progressShare(_, let photo) = r, let photo {
                LocalCache.savePhoto(photo, checkInID: r.id)
            }
            state.facts.apply(r)
        }
        persist()
        return state.facts
    }

    /// Replaces all facts (debug tools).
    func replaceFacts(_ facts: Facts) {
        state.facts = facts
        persist()
    }

    func createCouple(couple: CoupleFact, records: [FactRecord], inviterName: String) async throws -> InviteInfo {
        state.facts = Facts()
        state.facts.couple = couple
        for r in records { state.facts.apply(r) }
        let invite = InviteInfo(code: InviteCodes.generate(),
                                shareURL: URL(string: "https://www.icloud.com/share/mock-\(couple.id)"))
        state.invite = invite
        persist()
        return invite
    }

    var currentInvite: InviteInfo? { state.invite }

    func regenerateInvite(inviterName: String) async throws -> InviteInfo {
        let invite = InviteInfo(code: InviteCodes.generate(),
                                shareURL: URL(string: "https://www.icloud.com/share/mock-\(String.newID())"))
        state.invite = invite
        persist()
        return invite
    }

    func closeInvite() async {
        state.invite = nil
        persist()
    }

    /// In Mock mode any well-formed code resolves to an invite from a simulated partner "Maya".
    func lookupInvite(code: String) async throws -> InviteLookup {
        let clean = InviteCodes.normalize(code)
        guard clean.count == 6 else { throw StoreError.codeNotFound }
        if state.facts.couple != nil, state.facts.memberB?.joinedAt != nil {
            throw StoreError.coupleFull
        }
        let name = state.facts.memberA?.name ?? "Maya"
        return InviteLookup(code: clean, inviterName: name, shareURL: URL(string: "https://www.icloud.com/share/mock"))
    }

    /// Builds a couple created by a simulated A (unless one already exists) and returns it.
    func acceptInvite(_ lookup: InviteLookup) async throws -> Facts {
        if state.facts.couple == nil || state.facts.memberA == nil {
            state.facts = MockData.coupleInvitedBySimulatedA(now: Date().addingTimeInterval(state.clockOffset))
            persist()
        }
        return state.facts
    }

    func photoData(for checkIn: CheckInFact) async -> Data? { LocalCache.photo(checkIn.id) }

    func cachedPhotoData(for checkInID: String) -> Data? { LocalCache.photo(checkInID) }

    func progressSharePhotoData(id: String) async -> Data? { LocalCache.photo(id) }

    func deleteProgressShares(ids: [String]) async {
        let set = Set(ids)
        state.facts.progressShares.removeAll { set.contains($0.id) }
        for id in ids { LocalCache.deletePhoto(id) }
        persist()
    }

    func leaveCouple(me: MemberFact) async throws {
        state.facts = Facts()
        state.invite = nil
        persist()
    }

    func wipeLocalData() {
        state = State()
        LocalCache.wipe()
    }

    func saveWaitlist(email: String) async throws {
        state.waitlist.append(email)
        persist()
    }

    func registerForChanges() async {}
}

enum InviteCodes {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }

    static func normalize(_ s: String) -> String {
        String(s.uppercased().filter { alphabet.contains($0) }.prefix(6))
    }
}

/// Seed data for Mock mode.
enum MockData {
    static let simulatedA = "mock-member-a"
    static let simulatedB = "mock-member-b"

    static func farFutureSubscription(from now: Date) -> [SubscriptionPeriod] {
        [SubscriptionPeriod(start: now.addingTimeInterval(-86_400 * 400), end: now.addingTimeInterval(86_400 * 3650))]
    }

    /// A couple created by "Maya" (A) waiting for the user to join as B.
    static func coupleInvitedBySimulatedA(now: Date) -> Facts {
        var f = Facts()
        let coupleID = String.newID()
        let created = now.addingTimeInterval(-3600)
        f.couple = CoupleFact(id: coupleID, createdAt: created, ownerMemberID: simulatedA, title: "Maya's Pact")
        let periods = farFutureSubscription(from: now)
        f.members = [MemberFact(id: simulatedA, role: .a, name: "Maya", characterID: "w1",
                                timeZone: TimeZone.current.identifier, wakeTime: "07:00",
                                fitnessLevel: .somewhatActive, joinedAt: created,
                                subscribedUntil: periods.last?.end, subscriptionProduct: Brand.iapMonthly,
                                subscriptionPeriods: periods, leftAt: nil)]
        f.roundConfigs = [RoundConfigFact(id: .newID(), fromRound: 1, mode: .maintenance, betText: "",
                                          rewardText: nil, createdBy: simulatedA, createdAt: created)]
        let keys = PlanGenerator.ruleKeys(goals: [.fitness, .discipline])
        f.rules = PlanGenerator.rules(keys: keys, memberID: simulatedA, intensity: .standard, round: 1, now: created)
            + PlanGenerator.rules(keys: keys, memberID: PendingPartner.id, intensity: .standard, round: 1, now: created)
        return f
    }
}
#endif
