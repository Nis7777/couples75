import Foundation

/// What A shares with B: a 6-letter code and the iCloud share link.
struct InviteInfo: Codable, Equatable {
    var code: String
    var shareURL: URL?
}

/// Result of looking up a 6-letter code.
struct InviteLookup: Equatable {
    var code: String
    var inviterName: String
    var shareURL: URL?
}

enum StoreError: LocalizedError, Equatable {
    case codeNotFound
    case coupleFull
    case notAuthenticated
    case quotaExceeded(ownerName: String)
    case participantNeedsVerification
    case network
    case noCouple
    case other(String)

    var errorDescription: String? {
        switch self {
        case .codeNotFound: return "We couldn't find that code. Check the 6 letters and try again."
        case .coupleFull: return "This couple is already full."
        case .notAuthenticated: return "You're signed out of iCloud. Turn on iCloud in Settings to keep syncing."
        case .quotaExceeded(let owner):
            return "\(owner)'s iCloud is full, so photos can't be saved. Free up space or check in with an honour tap today."
        case .participantNeedsVerification:
            return "iCloud needs to verify your account before you can join. Open the link in Messages or Mail and try again."
        case .network: return "You're offline. We'll send it as soon as you're connected."
        case .noCouple: return "You're not in a couple yet."
        case .other(let s): return s
        }
    }
}

/// The app's data layer. `CloudKitStore` talks to iCloud; `MockStore` keeps everything in a local JSON file.
/// Both hold only facts; RulesEngine computes the rest.
@MainActor
protocol Store: AnyObject {
    var isMock: Bool { get }
    /// Writes made on this phone that haven't reached iCloud yet.
    var pendingUploads: Int { get }

    /// The last known facts (local cache), available instantly and offline.
    func cachedFacts() -> Facts
    /// Pulls changes from the server (and pushes queued writes). Returns the merged facts.
    func fetchChanges() async throws -> Facts
    /// Appends or replaces facts. Writes made offline are queued and retried.
    func save(_ records: [FactRecord]) async throws -> Facts

    /// A, after paying: create the zone, root record, share and invite code.
    func createCouple(couple: CoupleFact, records: [FactRecord], inviterName: String) async throws -> InviteInfo
    var currentInvite: InviteInfo? { get }
    /// A: new code and new share link; the old ones stop working.
    func regenerateInvite(inviterName: String) async throws -> InviteInfo
    /// A, once B has joined: stop anyone else joining with the old link or code.
    func closeInvite() async

    /// B: resolve a 6-letter code.
    func lookupInvite(code: String) async throws -> InviteLookup
    /// B: accept the share behind a code or link and download the couple.
    func acceptInvite(_ lookup: InviteLookup) async throws -> Facts

    /// Photo bytes for a check-in (downloaded and cached).
    func photoData(for checkIn: CheckInFact) async -> Data?
    /// Locally cached photo bytes, if any (no network).
    func cachedPhotoData(for checkInID: String) -> Data?
    /// Photo bytes of a shared progress photo (downloaded and cached).
    func progressSharePhotoData(id: String) async -> Data?
    /// Removes shared progress photo copies from the couple's zone (sharing turned off, leaving).
    func deleteProgressShares(ids: [String]) async

    /// Leave the couple. The owner deletes the zone; the participant writes leftAt and leaves the share.
    func leaveCouple(me: MemberFact) async throws
    /// Clears every local cache.
    func wipeLocalData()

    func saveWaitlist(email: String) async throws
    /// Subscribes to silent pushes for changes in the couple zone.
    func registerForChanges() async
}
