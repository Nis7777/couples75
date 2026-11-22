import Foundation
import CloudKit

/// The real data layer (sections 3.2, 5, 6.4). A (owner) reads and writes the couple zone in its private
/// database; B reads and writes the same zone through its shared database. That difference stays in here.
@MainActor
final class CloudKitStore: Store {
    private struct State: Codable {
        var facts = Facts()
        var zoneName: String?
        var zoneOwner: String?
        var isOwner = false
        var invite: InviteInfo?
        var zoneToken: Data?
        var sharedDBToken: Data?
        /// Facts written locally that haven't reached iCloud yet: "RecordType|id".
        var pending: [String] = []
        var subscribedZone: String?
    }

    private static let fileName = "cloudkit_state.json"
    private let container = CKContainer(identifier: Brand.cloudKitContainer)
    private var state: State
    private var isFlushing = false

    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private var zoneDB: CKDatabase { state.isOwner ? privateDB : sharedDB }

    private var zoneID: CKRecordZone.ID? {
        guard let name = state.zoneName else { return nil }
        return CKRecordZone.ID(zoneName: name, ownerName: state.zoneOwner ?? CKCurrentUserDefaultName)
    }

    init() {
        state = LocalCache.read(State.self, from: Self.fileName) ?? State()
    }

    var isMock: Bool { false }
    var pendingUploads: Int { state.pending.count }
    var currentInvite: InviteInfo? { state.invite }

    private func persist() { LocalCache.write(state, to: Self.fileName) }

    func cachedFacts() -> Facts { state.facts }

    // MARK: - Sync

    func fetchChanges() async throws -> Facts {
        guard let zoneID else { return state.facts }
        // Push queued writes first; a failure here must not stop us from pulling.
        try? await flush()
        if !state.isOwner {
            // Notice the owner deleting the zone (A left) through the shared database.
            if try await sharedZoneWasDeleted(zoneID) {
                markOwnerLeft()
                return state.facts
            }
        }
        do {
            try await fetchZoneChanges(zoneID)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            if state.isOwner {
                state = State()
                persist()
            } else {
                markOwnerLeft()
            }
        } catch let error as CKError where error.code == .changeTokenExpired {
            state.zoneToken = nil
            try await fetchZoneChanges(zoneID)
        } catch {
            throw map(error)
        }
        persist()
        return state.facts
    }

    private func fetchZoneChanges(_ zoneID: CKRecordZone.ID) async throws {
        var token = state.zoneToken.flatMap(Self.unarchiveToken)
        var more = true
        while more {
            let changes = try await zoneDB.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (_, result) in changes.modificationResultsByID {
                if case .success(let mod) = result { ingest(mod.record) }
            }
            for deletion in changes.deletions {
                remove(recordName: deletion.recordID.recordName, type: deletion.recordType)
            }
            token = changes.changeToken
            more = changes.moreComing
            state.zoneToken = Self.archive(changes.changeToken)
        }
    }

    private func sharedZoneWasDeleted(_ zoneID: CKRecordZone.ID) async throws -> Bool {
        var token = state.sharedDBToken.flatMap(Self.unarchiveToken)
        var more = true
        var deleted = false
        do {
            while more {
                let changes = try await sharedDB.databaseChanges(since: token)
                if changes.deletions.contains(where: { $0.zoneID == zoneID }) { deleted = true }
                token = changes.changeToken
                more = changes.moreComing
                state.sharedDBToken = Self.archive(changes.changeToken)
            }
        } catch let error as CKError where error.code == .changeTokenExpired {
            state.sharedDBToken = nil
        }
        return deleted
    }

    private func markOwnerLeft() {
        if var a = state.facts.memberA, a.leftAt == nil {
            a.leftAt = Date()
            state.facts.apply(.member(a))
        }
        state.zoneToken = nil
        state.pending = []
        persist()
    }

    /// Converts a server record into a fact and merges it (facts are append-only; server wins).
    private func ingest(_ record: CKRecord) {
        guard let type = CloudKitSchema.type(named: record.recordType) else { return }
        // A local edit still waiting to upload wins over an older server copy.
        if state.pending.contains("\(type.name)|\(record.recordID.recordName)") { return }
        guard var dict = Self.dictionary(from: record, type: type) else { return }
        let id = record.recordID.recordName
        dict["id"] = id
        if type.name == CloudKitSchema.checkIn.name {
            dict["uploadedAt"] = Self.iso.string(from: record.creationDate ?? Date())
            if let asset = record["photo"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url) {
                LocalCache.savePhoto(data, checkInID: id)
            }
        }
        if type.name == CloudKitSchema.progressShare.name,
           let asset = record["photo"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url) {
            LocalCache.savePhoto(data, checkInID: id)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        let d = LocalCache.decoder
        switch type.name {
        case "Couple": if let f = try? d.decode(CoupleFact.self, from: data) { state.facts.apply(.couple(f)) }
        case "Member": if let f = try? d.decode(MemberFact.self, from: data) { state.facts.apply(.member(f)) }
        case "RoundConfig": if let f = try? d.decode(RoundConfigFact.self, from: data) { state.facts.apply(.roundConfig(f)) }
        case "Rule": if let f = try? d.decode(RuleFact.self, from: data) { state.facts.apply(.rule(f)) }
        case "RuleTweak": if let f = try? d.decode(RuleTweakFact.self, from: data) { state.facts.apply(.tweak(f)) }
        case "TweakAnswer": if let f = try? d.decode(TweakAnswerFact.self, from: data) { state.facts.apply(.tweakAnswer(f)) }
        case "CheckIn": if let f = try? d.decode(CheckInFact.self, from: data) { state.facts.apply(.checkIn(f, photo: nil)) }
        case "Reaction": if let f = try? d.decode(ReactionFact.self, from: data) { state.facts.apply(.reaction(f)) }
        case "PauseRequest": if let f = try? d.decode(PauseRequestFact.self, from: data) { state.facts.apply(.pause(f)) }
        case "PauseAnswer": if let f = try? d.decode(PauseAnswerFact.self, from: data) { state.facts.apply(.pauseAnswer(f)) }
        case "BetPaid": if let f = try? d.decode(BetPaidFact.self, from: data) { state.facts.apply(.betPaid(f)) }
        case "RuleProposal": if let f = try? d.decode(RuleProposalFact.self, from: data) { state.facts.apply(.ruleProposal(f)) }
        case "RuleAnswer": if let f = try? d.decode(RuleAnswerFact.self, from: data) { state.facts.apply(.ruleAnswer(f)) }
        case "ProgressShare":
            if let f = try? d.decode(ProgressShareFact.self, from: data) { state.facts.apply(.progressShare(f, photo: nil)) }
        case "Nudge": if let f = try? d.decode(NudgeFact.self, from: data) { state.facts.apply(.nudge(f)) }
        default: break
        }
    }

    private func remove(recordName: String, type: CKRecord.RecordType) {
        var f = state.facts
        switch type {
        case "Couple": f.couple = nil
        case "Member": f.members.removeAll { $0.id == recordName }
        case "CheckIn": f.checkIns.removeAll { $0.id == recordName }
        case "Reaction": f.reactions.removeAll { $0.id == recordName }
        case "ProgressShare":
            f.progressShares.removeAll { $0.id == recordName }
            LocalCache.deletePhoto(recordName)
        default: break
        }
        state.facts = f
    }

    // MARK: - Writes (queued, retried)

    func save(_ records: [FactRecord]) async throws -> Facts {
        for r in records {
            if case .checkIn(_, let photo) = r, let photo { LocalCache.savePhoto(photo, checkInID: r.id) }
            if case .progressShare(_, let photo) = r, let photo { LocalCache.savePhoto(photo, checkInID: r.id) }
            state.facts.apply(r)
            let key = "\(Self.typeName(r))|\(r.id)"
            if !state.pending.contains(key) { state.pending.append(key) }
        }
        persist()
        do {
            try await flush()
        } catch let e as StoreError {
            if case .network = e { return state.facts }   // queued; retried on the next sync
            throw e
        }
        return state.facts
    }

    /// Uploads queued facts. Network errors keep them queued.
    private func flush(retrying: Bool = true) async throws {
        guard !isFlushing, !state.pending.isEmpty, let zoneID, let rootName = state.facts.couple?.id else { return }
        isFlushing = true
        defer { isFlushing = false }
        let rootID = CKRecord.ID(recordName: rootName, zoneID: zoneID)
        var records: [CKRecord] = []
        for key in state.pending {
            if let rec = makeRecord(key: key, zoneID: zoneID, rootID: rootID) { records.append(rec) }
        }
        guard !records.isEmpty else { state.pending = []; persist(); return }
        do {
            let result = try await zoneDB.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys,
                                                        atomically: false)
            var firstError: Error?
            for (id, r) in result.saveResults {
                switch r {
                case .success(let saved):
                    state.pending.removeAll { $0.hasSuffix("|\(id.recordName)") }
                    if saved.recordType == CloudKitSchema.checkIn.name,
                       var c = state.facts.checkIns.first(where: { $0.id == id.recordName }) {
                        c.uploadedAt = saved.creationDate ?? Date()
                        state.facts.apply(.checkIn(c, photo: nil))
                    }
                case .failure(let e):
                    if firstError == nil { firstError = e }
                    if let ck = e as? CKError, ck.code == .quotaExceeded {
                        // The photo can't be stored: drop it so the user can use an honour tap instead.
                        state.pending.removeAll { $0.hasSuffix("|\(id.recordName)") }
                        state.facts.checkIns.removeAll { $0.id == id.recordName }
                    }
                }
            }
            persist()
            if let firstError { throw firstError }
        } catch let ck as CKError where ck.code == .zoneBusy || ck.code == .serviceUnavailable
                    || ck.code == .requestRateLimited || ck.retryAfterSeconds != nil {
            guard retrying else { throw StoreError.network }
            let delay = ck.retryAfterSeconds ?? 2
            isFlushing = false
            try? await Task.sleep(nanoseconds: UInt64(min(delay, 30) * 1_000_000_000))
            try await flush(retrying: false)
        } catch let ck as CKError where ck.code == .serverRecordChanged {
            // Facts are append-only; keep the server copy.
            if let server = ck.serverRecord { ingest(server) }
            persist()
        } catch {
            throw map(error)
        }
    }

    private static func typeName(_ r: FactRecord) -> String {
        switch r {
        case .couple: return CloudKitSchema.couple.name
        case .member: return CloudKitSchema.member.name
        case .roundConfig: return CloudKitSchema.roundConfig.name
        case .rule: return CloudKitSchema.rule.name
        case .tweak: return CloudKitSchema.ruleTweak.name
        case .tweakAnswer: return CloudKitSchema.tweakAnswer.name
        case .checkIn: return CloudKitSchema.checkIn.name
        case .reaction: return CloudKitSchema.reaction.name
        case .pause: return CloudKitSchema.pauseRequest.name
        case .pauseAnswer: return CloudKitSchema.pauseAnswer.name
        case .betPaid: return CloudKitSchema.betPaid.name
        case .ruleProposal: return CloudKitSchema.ruleProposal.name
        case .ruleAnswer: return CloudKitSchema.ruleAnswer.name
        case .progressShare: return CloudKitSchema.progressShare.name
        case .nudge: return CloudKitSchema.nudge.name
        }
    }

    /// Builds a CKRecord from the current local fact behind a pending key.
    private func makeRecord(key: String, zoneID: CKRecordZone.ID, rootID: CKRecord.ID) -> CKRecord? {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let type = CloudKitSchema.type(named: parts[0]) else { return nil }
        let id = parts[1]
        let f = state.facts
        let e = LocalCache.encoder
        let data: Data?
        switch type.name {
        case "Couple": data = f.couple.flatMap { try? e.encode($0) }
        case "Member": data = f.members.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "RoundConfig": data = f.roundConfigs.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "Rule": data = f.rules.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "RuleTweak": data = f.tweaks.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "TweakAnswer": data = f.tweakAnswers.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "CheckIn": data = f.checkIns.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "Reaction": data = f.reactions.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "PauseRequest": data = f.pauses.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "PauseAnswer": data = f.pauseAnswers.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "BetPaid": data = f.betPayments.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "RuleProposal": data = f.ruleProposals.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "RuleAnswer": data = f.ruleAnswers.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "ProgressShare": data = f.progressShares.first { $0.id == id }.flatMap { try? e.encode($0) }
        case "Nudge": data = f.nudges.first { $0.id == id }.flatMap { try? e.encode($0) }
        default: data = nil
        }
        guard let data, let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let record = CKRecord(recordType: type.name, recordID: CKRecord.ID(recordName: id, zoneID: zoneID))
        Self.fill(record, from: dict, type: type)
        if type.name != CloudKitSchema.couple.name {
            record.parent = CKRecord.Reference(recordID: rootID, action: .none)
        }
        if type.name == CloudKitSchema.checkIn.name || type.name == CloudKitSchema.progressShare.name,
           LocalCache.photo(id) != nil {
            record["photo"] = CKAsset(fileURL: LocalCache.photoURL(id))
        }
        return record
    }

    // MARK: - Couple, share and invite code (3.2)

    func createCouple(couple: CoupleFact, records: [FactRecord], inviterName: String) async throws -> InviteInfo {
        let zone = CKRecordZone(zoneName: CloudKitSchema.zonePrefix + couple.id)
        do {
            _ = try await privateDB.save(zone)
            state = State()
            state.zoneName = zone.zoneID.zoneName
            state.zoneOwner = zone.zoneID.ownerName
            state.isOwner = true
            state.facts.couple = couple
            state.pending = ["\(CloudKitSchema.couple.name)|\(couple.id)"]
            for r in records {
                state.facts.apply(r)
                state.pending.append("\(Self.typeName(r))|\(r.id)")
            }
            persist()
            try await flush()
            let invite = try await createShareAndCode(inviterName: inviterName)
            state.invite = invite
            persist()
            await registerForChanges()
            return invite
        } catch let e as StoreError {
            throw e
        } catch {
            throw map(error)
        }
    }

    private func createShareAndCode(inviterName: String) async throws -> InviteInfo {
        guard let zoneID else { throw StoreError.noCouple }
        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = "\(inviterName)'s \(Brand.appName)" as NSString
        let saved = try await privateDB.save(share)
        guard let url = (saved as? CKShare)?.url else { throw StoreError.other("Couldn't create the invite link.") }
        // Find a free 6-letter code.
        for _ in 0..<5 {
            let code = InviteCodes.generate()
            let rec = CKRecord(recordType: CloudKitSchema.inviteCode.name, recordID: CKRecord.ID(recordName: code))
            rec["code"] = code as NSString
            rec["shareURL"] = url.absoluteString as NSString
            rec["inviterName"] = inviterName as NSString
            rec["createdAt"] = Date() as NSDate
            do {
                _ = try await publicDB.save(rec)
                return InviteInfo(code: code, shareURL: url)
            } catch let ck as CKError where ck.code == .serverRecordChanged {
                continue  // code already taken
            }
        }
        throw StoreError.other("Couldn't create an invite code. Try again.")
    }

    func regenerateInvite(inviterName: String) async throws -> InviteInfo {
        guard let zoneID, state.isOwner else { throw StoreError.noCouple }
        do {
            if let old = state.invite?.code {
                _ = try? await publicDB.deleteRecord(withID: CKRecord.ID(recordName: old))
            }
            _ = try? await privateDB.deleteRecord(withID: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID))
            let invite = try await createShareAndCode(inviterName: inviterName)
            state.invite = invite
            persist()
            return invite
        } catch let e as StoreError {
            throw e
        } catch {
            throw map(error)
        }
    }

    func closeInvite() async {
        guard state.isOwner, let zoneID else { return }
        if let code = state.invite?.code {
            _ = try? await publicDB.deleteRecord(withID: CKRecord.ID(recordName: code))
        }
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if let share = try? await privateDB.record(for: shareID) as? CKShare {
            share.publicPermission = .none
            _ = try? await privateDB.save(share)
        }
        state.invite = nil
        persist()
    }

    // MARK: - Joining (3.5)

    func lookupInvite(code: String) async throws -> InviteLookup {
        let clean = InviteCodes.normalize(code)
        guard clean.count == 6 else { throw StoreError.codeNotFound }
        do {
            let rec = try await publicDB.record(for: CKRecord.ID(recordName: clean))
            guard let urlString = rec["shareURL"] as? String, let url = URL(string: urlString) else {
                throw StoreError.codeNotFound
            }
            return InviteLookup(code: clean, inviterName: rec["inviterName"] as? String ?? "Your partner", shareURL: url)
        } catch let ck as CKError where ck.code == .unknownItem {
            throw StoreError.codeNotFound
        } catch let e as StoreError {
            throw e
        } catch {
            throw map(error)
        }
    }

    func acceptInvite(_ lookup: InviteLookup) async throws -> Facts {
        guard let url = lookup.shareURL else { throw StoreError.codeNotFound }
        let metadata = try await fetchShareMetadata(url)
        return try await accept(metadata: metadata)
    }

    /// Accepts a share (from a code or a tapped link) and downloads the couple.
    func accept(metadata: CKShare.Metadata) async throws -> Facts {
        do {
            if metadata.participantRole != .owner {
                try await acceptShare(metadata)
            }
            let zoneID = metadata.share.recordID.zoneID
            state = State()
            state.zoneName = zoneID.zoneName
            state.zoneOwner = zoneID.ownerName
            state.isOwner = metadata.participantRole == .owner
            persist()
            try await fetchZoneChanges(zoneID)
            persist()
            let me = Identity.memberID(isMock: false)
            if let b = state.facts.memberB, b.id != me {
                // Only one partner can join.
                _ = try? await sharedDB.deleteRecordZone(withID: zoneID)
                state = State()
                persist()
                throw StoreError.coupleFull
            }
            await registerForChanges()
            return state.facts
        } catch let e as StoreError {
            throw e
        } catch let ck as CKError where ck.code == .unknownItem || ck.code == .permissionFailure {
            throw StoreError.coupleFull
        } catch {
            throw map(error)
        }
    }

    private func fetchShareMetadata(_ url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CKShare.Metadata, Error>) in
            var found: CKShare.Metadata?
            var failure: Error?
            let op = CKFetchShareMetadataOperation(shareURLs: [url])
            op.shouldFetchRootRecord = false
            op.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let md): found = md
                case .failure(let e): failure = e
                }
            }
            op.fetchShareMetadataResultBlock = { result in
                if case .failure(let e) = result { failure = failure ?? e }
                if let found { cont.resume(returning: found) } else {
                    let err = failure ?? StoreError.codeNotFound
                    if let ck = err as? CKError, ck.code == .unknownItem || ck.code == .permissionFailure {
                        cont.resume(throwing: StoreError.coupleFull)
                    } else {
                        cont.resume(throwing: err)
                    }
                }
            }
            container.add(op)
        }
    }

    private func acceptShare(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var failure: Error?
            let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
            op.perShareResultBlock = { _, result in
                if case .failure(let e) = result { failure = e }
            }
            op.acceptSharesResultBlock = { result in
                if case .failure(let e) = result { failure = failure ?? e }
                if let failure { cont.resume(throwing: failure) } else { cont.resume() }
            }
            container.add(op)
        }
    }

    // MARK: - Photos

    func progressSharePhotoData(id: String) async -> Data? {
        if let cached = LocalCache.photo(id) { return cached }
        guard let zoneID else { return nil }
        guard let rec = try? await zoneDB.record(for: CKRecord.ID(recordName: id, zoneID: zoneID)),
              let asset = rec["photo"] as? CKAsset, let url = asset.fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        LocalCache.savePhoto(data, checkInID: id)
        return data
    }

    func deleteProgressShares(ids: [String]) async {
        guard !ids.isEmpty else { return }
        let set = Set(ids)
        state.facts.progressShares.removeAll { set.contains($0.id) }
        state.pending.removeAll { key in set.contains { key == "\(CloudKitSchema.progressShare.name)|\($0)" } }
        for id in ids { LocalCache.deletePhoto(id) }
        persist()
        guard let zoneID else { return }
        let recordIDs = ids.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        _ = try? await zoneDB.modifyRecords(saving: [], deleting: recordIDs)
    }

    func photoData(for checkIn: CheckInFact) async -> Data? {
        if let cached = LocalCache.photo(checkIn.id) { return cached }
        guard checkIn.hasPhoto, let zoneID else { return nil }
        let id = CKRecord.ID(recordName: checkIn.id, zoneID: zoneID)
        guard let rec = try? await zoneDB.record(for: id),
              let asset = rec["photo"] as? CKAsset, let url = asset.fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        LocalCache.savePhoto(data, checkInID: checkIn.id)
        return data
    }

    func cachedPhotoData(for checkInID: String) -> Data? { LocalCache.photo(checkInID) }

    // MARK: - Leaving (6.5)

    func leaveCouple(me: MemberFact) async throws {
        guard let zoneID else { wipeLocalData(); return }
        do {
            if state.isOwner {
                if let code = state.invite?.code {
                    _ = try? await publicDB.deleteRecord(withID: CKRecord.ID(recordName: code))
                }
                _ = try await privateDB.deleteRecordZone(withID: zoneID)
            } else {
                var m = me
                m.leftAt = Date()
                _ = try? await save([.member(m)])
                _ = try await sharedDB.deleteRecordZone(withID: zoneID)
            }
        } catch let ck as CKError where ck.code == .zoneNotFound || ck.code == .userDeletedZone || ck.code == .unknownItem {
            // Already gone.
        } catch {
            throw map(error)
        }
        wipeLocalData()
    }

    func wipeLocalData() {
        state = State()
        LocalCache.wipe()
    }

    func saveWaitlist(email: String) async throws {
        let rec = CKRecord(recordType: CloudKitSchema.waitlist.name)
        rec["email"] = email as NSString
        rec["createdAt"] = Date() as NSDate
        do {
            _ = try await publicDB.save(rec)
        } catch {
            throw map(error)
        }
    }

    // MARK: - Silent pushes (section 5)

    /// A subscribes to its couple zone in the private database; B to the shared database.
    func registerForChanges() async {
        guard let zoneID, state.subscribedZone != zoneID.zoneName else { return }
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        do {
            if state.isOwner {
                let sub = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: CloudKitSchema.zoneSubscriptionID)
                sub.notificationInfo = info
                _ = try await privateDB.modifySubscriptions(saving: [sub], deleting: [])
            } else {
                let sub = CKDatabaseSubscription(subscriptionID: CloudKitSchema.sharedSubscriptionID)
                sub.notificationInfo = info
                _ = try await sharedDB.modifySubscriptions(saving: [sub], deleting: [])
            }
            state.subscribedZone = zoneID.zoneName
            persist()
        } catch {
            // Retried on the next launch. Changes are also fetched on open, foreground and background refresh.
        }
    }

    // MARK: - Errors

    private func map(_ error: Error) -> StoreError {
        if let e = error as? StoreError { return e }
        guard let ck = error as? CKError else { return .other(error.localizedDescription) }
        switch ck.code {
        case .quotaExceeded:
            return .quotaExceeded(ownerName: state.facts.memberA?.name ?? "The couple owner")
        case .notAuthenticated:
            return .notAuthenticated
        case .participantMayNeedVerification:
            return .participantNeedsVerification
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .network
        case .partialFailure:
            if let first = ck.partialErrorsByItemID?.values.first { return map(first) }
            return .other(ck.localizedDescription)
        default:
            return .other(ck.localizedDescription)
        }
    }

    // MARK: - Record <-> dictionary

    private static let iso: ISO8601DateFormatter = ISO8601DateFormatter()

    /// JSON dictionary (from a Codable fact) → record fields.
    private static func fill(_ record: CKRecord, from dict: [String: Any], type: CloudKitSchema.RecordType) {
        for (key, value) in dict where key != "id" && key != "uploadedAt" {
            if type.dateKeys.contains(key), let s = value as? String, let date = iso.date(from: s) {
                record[key] = date as NSDate
            } else if type.jsonKeys.contains(key) {
                if let data = try? JSONSerialization.data(withJSONObject: value),
                   let s = String(data: data, encoding: .utf8) {
                    record[key] = s as NSString
                }
            } else if type.boolKeys.contains(key), let b = value as? Bool {
                record[key] = NSNumber(value: b ? 1 : 0)
            } else if let s = value as? String {
                record[key] = s as NSString
            } else if let n = value as? NSNumber {
                record[key] = n
            }
        }
    }

    /// Record fields → JSON dictionary that decodes into the fact type.
    private static func dictionary(from record: CKRecord, type: CloudKitSchema.RecordType) -> [String: Any]? {
        var dict: [String: Any] = [:]
        for key in record.allKeys() where key != "photo" {
            let value = record[key]
            if let date = value as? Date {
                dict[key] = iso.string(from: date)
            } else if type.boolKeys.contains(key), let n = value as? NSNumber {
                dict[key] = n.intValue != 0
            } else if type.jsonKeys.contains(key), let s = value as? String,
                      let data = s.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) {
                dict[key] = obj
            } else if let s = value as? String {
                dict[key] = s
            } else if let n = value as? NSNumber {
                dict[key] = n
            }
        }
        for key in type.boolKeys where dict[key] == nil { dict[key] = false }
        return dict
    }

    private static func archive(_ token: CKServerChangeToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private static func unarchiveToken(_ data: Data) -> CKServerChangeToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }
}
