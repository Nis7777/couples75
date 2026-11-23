import Foundation
import CloudKit

/// The real data layer. Everything lives on the phones; Pact's own public iCloud database only passes it between
/// the two partners, encrypted with the couple's key (see `Relay.swift`). Nothing is stored in the users' personal
/// iCloud, so a full iCloud never blocks a couple.
///
/// - Every fact a partner writes is one `PactItem` record (`couple` = the couple's tag, `payload` = the encrypted
///   fact, `photo` = the encrypted photo while it's travelling). Only a record's creator can change it, so each
///   partner writes their own version of a fact; the newest version wins.
/// - Photos: once the partner's phone has a photo it writes a tiny receipt, and the author removes the photo from
///   the record. Photos older than 30 days are removed anyway. Both phones keep their own copy.
/// - Sync: "what changed for our tag since last time?" (by modification date), plus a silent push subscription.
/// - The invite: an `InviteCode` record named by the 6-letter code, holding the couple's key locked with the code.
/// - The couple's tag and key are also kept in the iCloud key-value store (separate from iCloud storage), so a
///   reinstall or a new phone gets the couple back.
@MainActor
final class RelayStore: Store {
    private struct State: Codable {
        var facts = Facts()
        var secret: CoupleSecret?
        var isOwner = false
        var invite: InviteInfo?
        /// Newest modification date seen on the server (the next sync asks for what's newer).
        var lastSync: Date?
        /// Things to upload: "Type|id" (a fact), "Receipt|id", "Gone|Type|id".
        var pending: [String] = []
        /// My photos currently in the cloud (fact id → when uploaded).
        var photosInCloud: [String: Date] = [:]
        /// My facts whose photo has been taken out of the cloud.
        var stripped: Set<String> = []
        /// Partner photos I've confirmed receiving.
        var receipted: Set<String> = []
        var subscribedTag: String?
    }

    static let itemType = "PactItem"
    static let inviteType = "InviteCode"
    static let waitlistType = "Waitlist"
    /// The longest a photo stays in the cloud, even if the partner never opens the app.
    static let photoMaxAge: TimeInterval = 30 * 86_400
    private static let fileName = "relay_state.json"
    private static let backupKey = "pactCoupleSecret"

    private let container = CKContainer(identifier: Brand.cloudKitContainer)
    private var db: CKDatabase { container.publicCloudDatabase }
    private var state: State
    private var isFlushing = false
    private let me: MemberID

    init() {
        state = LocalCache.read(State.self, from: Self.fileName) ?? State()
        me = Identity.memberID(isMock: false)
    }

    var isMock: Bool { false }
    var pendingUploads: Int { state.pending.filter { !$0.hasPrefix("Receipt|") }.count }
    var currentInvite: InviteInfo? { state.invite }

    func cachedFacts() -> Facts { state.facts }

    /// False when the iPhone is full (the data is still in memory, and in the cloud once sent).
    @discardableResult
    private func persist() -> Bool { LocalCache.write(state, to: Self.fileName) }

    // MARK: - Backup of the couple's key (survives reinstalls)

    private struct Backup: Codable { var secret: CoupleSecret; var isOwner: Bool }

    private func backUpSecret() {
        guard let secret = state.secret,
              let data = try? JSONEncoder().encode(Backup(secret: secret, isOwner: state.isOwner)) else { return }
        NSUbiquitousKeyValueStore.default.set(data, forKey: Self.backupKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func clearBackup() {
        NSUbiquitousKeyValueStore.default.removeObject(forKey: Self.backupKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// After a reinstall (or on a new phone): pick the couple back up from the key-value store.
    private func restoreIfNeeded() {
        guard state.secret == nil,
              let data = NSUbiquitousKeyValueStore.default.data(forKey: Self.backupKey),
              let backup = try? JSONDecoder().decode(Backup.self, from: data) else { return }
        state = State()
        state.secret = backup.secret
        state.isOwner = backup.isOwner
        persist()
    }

    // MARK: - Sync

    func fetchChanges() async throws -> Facts {
        restoreIfNeeded()
        guard let secret = state.secret else { return state.facts }
        // Push queued writes first; a failure here must not stop us from pulling.
        try? await flush()
        do {
            try await pull(secret)
        } catch {
            throw map(error)
        }
        queuePhotoCleanup()
        try? await flush()
        persist()
        return state.facts
    }

    /// Everything for our tag newer than the last sync, oldest first (so the newest version of a fact wins).
    private func pull(_ secret: CoupleSecret) async throws {
        let predicate: NSPredicate
        if let since = state.lastSync {
            // A small overlap: reading a record twice is harmless.
            predicate = NSPredicate(format: "couple == %@ AND modificationDate >= %@", secret.tag,
                                    since.addingTimeInterval(-5) as NSDate)
        } else {
            predicate = NSPredicate(format: "couple == %@", secret.tag)
        }
        let query = CKQuery(recordType: Self.itemType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: true)]
        var (results, cursor) = try await db.records(matching: query, resultsLimit: 200)
        while true {
            for (_, result) in results {
                if case .success(let record) = result { ingest(record, secret: secret) }
            }
            guard let next = cursor else { break }
            (results, cursor) = try await db.records(continuingMatchFrom: next, resultsLimit: 200)
        }
    }

    private func ingest(_ record: CKRecord, secret: CoupleSecret) {
        if let date = record.modificationDate, date > (state.lastSync ?? .distantPast) { state.lastSync = date }
        let name = record.recordID.recordName
        guard let payload = record["payload"] as? Data,
              let plain = try? RelayCrypto.open(payload, with: secret, context: name),
              let env = try? JSONDecoder().decode(RelayEnvelope.self, from: plain) else { return }
        switch env.kind {
        case .fact:
            guard var fact = RelayCodec.record(from: env), let type = env.type else { return }
            // A local edit still waiting to upload wins over an older server copy.
            if state.pending.contains("\(type)|\(fact.id)") { return }
            if case .checkIn(var c, _) = fact {
                // When it reached the cloud (the server's time: a check-in counts if it's sent within 6 hours).
                c.uploadedAt = record.creationDate ?? Date()
                fact = .checkIn(c, photo: nil)
            }
            savePhotoIfAny(record, factID: fact.id, writer: env.writer, secret: secret)
            state.facts.apply(fact)
        case .receipt:
            // My partner has my photo: take it out of the cloud.
            guard env.writer != me, let id = env.id, state.photosInCloud[id] != nil else { return }
            stripPhoto(id)
        case .left:
            guard var m = state.facts.member(env.writer), m.leftAt == nil else { return }
            m.leftAt = env.at ?? Date()
            state.facts.apply(.member(m))
        case .gone:
            guard let type = env.type, let id = env.id else { return }
            RelayCodec.remove(type: type, id: id, from: &state.facts)
            LocalCache.deletePhoto(id)
        }
    }

    /// Decrypts a travelling photo into the local cache, and tells the author we've got it.
    private func savePhotoIfAny(_ record: CKRecord, factID: String, writer: String, secret: CoupleSecret) {
        guard writer != me, LocalCache.photo(factID) == nil,
              let asset = record["photo"] as? CKAsset, let url = asset.fileURL,
              let sealed = try? Data(contentsOf: url),
              let photo = try? RelayCrypto.open(sealed, with: secret,
                                                context: RelayCodec.photoContext(record.recordID.recordName)) else { return }
        LocalCache.savePhoto(photo, checkInID: factID)
        if !state.receipted.contains(factID) {
            state.receipted.insert(factID)
            enqueue("Receipt|\(factID)")
        }
    }

    // MARK: - Photos in the cloud

    private func stripPhoto(_ id: String) {
        guard let type = typeOfMyPhotoFact(id) else { state.photosInCloud[id] = nil; return }
        state.stripped.insert(id)
        state.photosInCloud[id] = nil
        enqueue("\(type)|\(id)")   // re-upload my version without the photo
    }

    private func typeOfMyPhotoFact(_ id: String) -> String? {
        if state.facts.checkIns.contains(where: { $0.id == id }) { return "CheckIn" }
        if state.facts.progressShares.contains(where: { $0.id == id }) { return "ProgressShare" }
        return nil
    }

    /// Photos that have been in the cloud for 30 days leave it, delivered or not.
    private func queuePhotoCleanup() {
        let cutoff = Date().addingTimeInterval(-Self.photoMaxAge)
        for (id, at) in state.photosInCloud where at < cutoff { stripPhoto(id) }
    }

    // MARK: - Writes (queued, retried)

    private func enqueue(_ key: String) {
        if !state.pending.contains(key) { state.pending.append(key) }
    }

    func save(_ records: [FactRecord]) async throws -> Facts {
        // Photos first: if the iPhone is full, say so instead of sending a check-in without its photo.
        for r in records {
            if case .checkIn(_, let photo) = r, let photo, !LocalCache.savePhoto(photo, checkInID: r.id) {
                throw StoreError.deviceFull
            }
            if case .progressShare(_, let photo) = r, let photo, !LocalCache.savePhoto(photo, checkInID: r.id) {
                throw StoreError.deviceFull
            }
        }
        for r in records {
            state.facts.apply(r)
            enqueue("\(RelayCodec.typeName(r))|\(r.id)")
        }
        let saved = persist()
        do {
            try await flush()
        } catch let e as StoreError {
            // Offline and the iPhone is full: it's neither sent nor safely saved, so say so.
            if case .network = e { if saved { return state.facts } else { throw StoreError.deviceFull } }
            throw e
        }
        return state.facts
    }

    /// Uploads what's queued. Network errors keep it queued.
    private func flush() async throws {
        guard !isFlushing, !state.pending.isEmpty, let secret = state.secret else { return }
        isFlushing = true
        defer { isFlushing = false }
        var built: [(key: String, record: CKRecord, photoFile: URL?)] = []
        for key in state.pending {
            if let item = makeRecord(key: key, secret: secret) {
                built.append((key, item.record, item.photoFile))
            } else {
                state.pending.removeAll { $0 == key }   // the fact no longer exists locally
            }
        }
        defer { for b in built { if let f = b.photoFile { try? FileManager.default.removeItem(at: f) } } }
        guard !built.isEmpty else { persist(); return }
        var firstError: Error?
        for chunk in stride(from: 0, to: built.count, by: 200).map({ Array(built[$0..<min($0 + 200, built.count)]) }) {
            do {
                let result = try await db.modifyRecords(saving: chunk.map(\.record), deleting: [],
                                                        savePolicy: .allKeys, atomically: false)
                for b in chunk {
                    switch result.saveResults[b.record.recordID] {
                    case .success(let saved):
                        state.pending.removeAll { $0 == b.key }
                        didUpload(key: b.key, saved: saved, hadPhoto: b.photoFile != nil)
                    case .failure(let e):
                        if firstError == nil { firstError = e }
                    case nil:
                        break
                    }
                }
            } catch {
                if firstError == nil { firstError = error }
                break
            }
        }
        persist()
        if let firstError { throw map(firstError) }
    }

    private func didUpload(key: String, saved: CKRecord, hadPhoto: Bool) {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 2 else { return }
        let (type, id) = (parts[0], parts[1])
        if hadPhoto { state.photosInCloud[id] = saved.creationDate ?? Date() }
        if type == "CheckIn", var c = state.facts.checkIns.first(where: { $0.id == id }), c.uploadedAt == nil {
            c.uploadedAt = saved.creationDate ?? Date()
            state.facts.apply(.checkIn(c, photo: nil))
        }
    }

    /// Builds the encrypted record behind a queued key (and the encrypted photo file, if one travels with it).
    private func makeRecord(key: String, secret: CoupleSecret) -> (record: CKRecord, photoFile: URL?)? {
        let parts = key.split(separator: "|").map(String.init)
        let env: RelayEnvelope
        let name: String
        var photoID: String?
        switch parts.first {
        case "Receipt" where parts.count == 2:
            name = RelayCodec.receiptRecordName(id: parts[1], writer: me)
            env = RelayEnvelope(kind: .receipt, writer: me, type: nil, id: parts[1], fact: nil, at: nil)
        case "Gone" where parts.count == 3:
            name = RelayCodec.goneRecordName(id: parts[2], writer: me)
            env = RelayEnvelope(kind: .gone, writer: me, type: parts[1], id: parts[2], fact: nil, at: nil)
        case .some(let type) where parts.count == 2:
            let id = parts[1]
            guard let fact = RelayCodec.localRecord(type: type, id: id, in: state.facts, photo: nil),
                  let e = try? RelayCodec.envelope(fact, writer: me) else { return nil }
            name = RelayCodec.factRecordName(id: id, writer: me)
            env = e
            // A photo travels with my check-in / shared progress photo until my partner has it.
            if (type == "CheckIn" || type == "ProgressShare"), !state.stripped.contains(id), LocalCache.photo(id) != nil {
                photoID = id
            }
        default:
            return nil
        }
        guard let plain = try? JSONEncoder().encode(env),
              let payload = try? RelayCrypto.seal(plain, with: secret, context: name) else { return nil }
        let record = CKRecord(recordType: Self.itemType, recordID: CKRecord.ID(recordName: name))
        record["couple"] = secret.tag as NSString
        record["payload"] = payload as NSData
        var photoFile: URL?
        if let photoID, let photo = LocalCache.photo(photoID),
           let sealed = try? RelayCrypto.seal(photo, with: secret, context: RelayCodec.photoContext(name)) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("relay-\(UUID().uuidString).bin")
            if (try? sealed.write(to: url, options: .atomic)) != nil {
                record["photo"] = CKAsset(fileURL: url)
                photoFile = url
            }
        } else {
            record["photo"] = nil
        }
        return (record, photoFile)
    }

    // MARK: - Couple and invite code (3.2)

    func createCouple(couple: CoupleFact, records: [FactRecord], inviterName: String) async throws -> InviteInfo {
        // A retry after a failed setup: everything is already saved here and queued; send it and make the invite.
        if state.isOwner, state.secret != nil, state.facts.couple?.id == couple.id {
            return try await ensureInvite(inviterName: inviterName, force: true)
        }
        state = State()
        state.secret = RelayCrypto.newSecret()
        state.isOwner = true
        state.facts.couple = couple
        state.pending = ["Couple|\(couple.id)"]
        for r in records {
            state.facts.apply(r)
            enqueue("\(RelayCodec.typeName(r))|\(r.id)")
        }
        persist()
        backUpSecret()
        do {
            try await flush()
            let invite = try await makeInvite(inviterName: inviterName)
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

    /// The link that goes with the code: a page that says how to join (and opens Pact if it's installed).
    static func joinLink(code: String) -> URL? { URL(string: "https://nis7777.github.io/pact/join.html?code=\(code)") }

    private func makeInvite(inviterName: String) async throws -> InviteInfo {
        guard let secret = state.secret else { throw StoreError.noCouple }
        for _ in 0..<5 {
            let code = InviteCodes.generate()
            let rec = CKRecord(recordType: Self.inviteType, recordID: CKRecord.ID(recordName: code))
            rec["code"] = code as NSString
            rec["couple"] = secret.tag as NSString
            rec["sealedKey"] = try RelayCrypto.wrapKey(secret, code: code) as NSData
            rec["inviterName"] = inviterName as NSString
            rec["createdAt"] = Date() as NSDate
            do {
                let op = try await db.modifyRecords(saving: [rec], deleting: [], savePolicy: .ifServerRecordUnchanged,
                                                    atomically: false)
                if case .failure(let e) = op.saveResults[rec.recordID] { throw e }
                return InviteInfo(code: code, shareURL: Self.joinLink(code: code))
            } catch let ck as CKError where ck.code == .serverRecordChanged {
                continue  // code already taken
            }
        }
        throw StoreError.other("Couldn't create an invite code. Try again.")
    }

    func regenerateInvite(inviterName: String) async throws -> InviteInfo {
        guard state.secret != nil, state.isOwner else { throw StoreError.noCouple }
        do {
            if let old = state.invite?.code {
                _ = try? await db.deleteRecord(withID: CKRecord.ID(recordName: old))
            }
            let invite = try await makeInvite(inviterName: inviterName)
            state.invite = invite
            persist()
            return invite
        } catch let e as StoreError {
            throw e
        } catch {
            throw map(error)
        }
    }

    func ensureInvite(inviterName: String, force: Bool) async throws -> InviteInfo {
        guard state.secret != nil, state.isOwner else { throw StoreError.noCouple }
        if let invite = state.invite { return invite }
        do {
            try await flush()
            let invite = try await makeInvite(inviterName: inviterName)
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

    func closeInvite() async {
        guard state.isOwner, let code = state.invite?.code else { return }
        _ = try? await db.deleteRecord(withID: CKRecord.ID(recordName: code))
        state.invite = nil
        persist()
    }

    // MARK: - Joining (3.5)

    func lookupInvite(code: String) async throws -> InviteLookup {
        let clean = InviteCodes.normalize(code)
        guard clean.count == 6 else { throw StoreError.codeNotFound }
        do {
            let rec = try await db.record(for: CKRecord.ID(recordName: clean))
            guard rec["sealedKey"] is Data else { throw StoreError.codeNotFound }
            return InviteLookup(code: clean, inviterName: rec["inviterName"] as? String ?? "Your partner",
                                shareURL: Self.joinLink(code: clean))
        } catch let ck as CKError where ck.code == .unknownItem {
            throw StoreError.codeNotFound
        } catch let e as StoreError {
            throw e
        } catch {
            throw map(error)
        }
    }

    func acceptInvite(_ lookup: InviteLookup) async throws -> Facts {
        let code = InviteCodes.normalize(lookup.code)
        guard code.count == 6 else { throw StoreError.codeNotFound }
        do {
            let rec = try await db.record(for: CKRecord.ID(recordName: code))
            guard let tag = rec["couple"] as? String, let sealed = rec["sealedKey"] as? Data,
                  let secret = try? RelayCrypto.unwrapKey(sealed, code: code, tag: tag) else {
                throw StoreError.codeNotFound
            }
            state = State()
            state.secret = secret
            state.isOwner = false
            try await pull(secret)
            if let b = state.facts.memberB, b.id != me {
                // Only one partner can join.
                state = State()
                persist()
                throw StoreError.coupleFull
            }
            persist()
            backUpSecret()
            await registerForChanges()
            return state.facts
        } catch let ck as CKError where ck.code == .unknownItem {
            throw StoreError.codeNotFound
        } catch let e as StoreError {
            throw e
        } catch {
            throw map(error)
        }
    }

    // MARK: - Photos

    func photoData(for checkIn: CheckInFact) async -> Data? {
        if let cached = LocalCache.photo(checkIn.id) { return cached }
        guard checkIn.hasPhoto else { return nil }
        return await fetchPhoto(id: checkIn.id, writer: checkIn.memberID)
    }

    func cachedPhotoData(for checkInID: String) -> Data? { LocalCache.photo(checkInID) }

    func progressSharePhotoData(id: String) async -> Data? {
        if let cached = LocalCache.photo(id) { return cached }
        guard let share = state.facts.progressShares.first(where: { $0.id == id }) else { return nil }
        return await fetchPhoto(id: id, writer: share.memberID)
    }

    /// A photo that wasn't picked up with the sync (e.g. it arrived while the app was closed): fetch it directly.
    private func fetchPhoto(id: String, writer: String) async -> Data? {
        guard let secret = state.secret,
              let rec = try? await db.record(for: CKRecord.ID(recordName: RelayCodec.factRecordName(id: id, writer: writer)))
        else { return nil }
        savePhotoIfAny(rec, factID: id, writer: writer, secret: secret)
        persist()
        return LocalCache.photo(id)
    }

    func deleteProgressShares(ids: [String]) async {
        guard !ids.isEmpty else { return }
        let set = Set(ids)
        state.facts.progressShares.removeAll { set.contains($0.id) }
        state.pending.removeAll { key in set.contains { key == "ProgressShare|\($0)" } }
        for id in ids {
            LocalCache.deletePhoto(id)
            state.photosInCloud[id] = nil
            enqueue("Gone|ProgressShare|\(id)")
        }
        persist()
        let recordIDs = ids.map { CKRecord.ID(recordName: RelayCodec.factRecordName(id: $0, writer: me)) }
        _ = try? await db.modifyRecords(saving: [], deleting: recordIDs, savePolicy: .allKeys, atomically: false)
        try? await flush()
    }

    // MARK: - Leaving (6.5)

    /// Deletes everything I wrote, and leaves one small encrypted "left" marker so my partner's phone knows.
    func leaveCouple(me member: MemberFact) async throws {
        guard let secret = state.secret else { wipeLocalData(); return }
        do {
            if state.isOwner, let code = state.invite?.code {
                _ = try? await db.deleteRecord(withID: CKRecord.ID(recordName: code))
            }
            let mine = try await myRecordIDs(secret)
            let leftName = RelayCodec.leftRecordName(member: member.id)
            let env = RelayEnvelope(kind: .left, writer: member.id, type: nil, id: nil, fact: nil, at: Date())
            let left = CKRecord(recordType: Self.itemType, recordID: CKRecord.ID(recordName: leftName))
            left["couple"] = secret.tag as NSString
            left["payload"] = try RelayCrypto.seal(JSONEncoder().encode(env), with: secret, context: leftName) as NSData
            let deleting = mine.filter { $0.recordName != leftName }
            _ = try await db.modifyRecords(saving: [left], deleting: [], savePolicy: .allKeys, atomically: false)
            for start in stride(from: 0, to: deleting.count, by: 200) {
                _ = try await db.modifyRecords(saving: [], deleting: Array(deleting[start..<min(start + 200, deleting.count)]),
                                               savePolicy: .allKeys, atomically: false)
            }
        } catch let e as StoreError {
            throw e
        } catch {
            throw map(error)
        }
        wipeLocalData()
    }

    /// Every record for our tag that this iCloud user created.
    private func myRecordIDs(_ secret: CoupleSecret) async throws -> [CKRecord.ID] {
        let userID = try await container.userRecordID()
        let query = CKQuery(recordType: Self.itemType, predicate: NSPredicate(format: "couple == %@", secret.tag))
        var ids: [CKRecord.ID] = []
        var (results, cursor) = try await db.records(matching: query, desiredKeys: [], resultsLimit: 200)
        while true {
            for (id, result) in results {
                if case .success(let rec) = result, rec.creatorUserRecordID?.recordName == userID.recordName
                    || rec.creatorUserRecordID?.recordName == CKCurrentUserDefaultName {
                    ids.append(id)
                }
            }
            guard let next = cursor else { break }
            (results, cursor) = try await db.records(continuingMatchFrom: next, desiredKeys: [], resultsLimit: 200)
        }
        return ids
    }

    func wipeLocalData() {
        state = State()
        LocalCache.wipe()
        clearBackup()
    }

    func saveWaitlist(email: String) async throws {
        let rec = CKRecord(recordType: Self.waitlistType)
        rec["email"] = email as NSString
        rec["createdAt"] = Date() as NSDate
        do {
            _ = try await db.save(rec)
        } catch {
            throw map(error)
        }
    }

    // MARK: - Silent pushes

    /// A query subscription on our tag: the partner's new records wake the app to sync.
    func registerForChanges() async {
        guard let secret = state.secret, state.subscribedTag != secret.tag else { return }
        let sub = CKQuerySubscription(recordType: Self.itemType,
                                      predicate: NSPredicate(format: "couple == %@", secret.tag),
                                      subscriptionID: "pact-\(secret.tag.prefix(16))",
                                      options: [.firesOnRecordCreation, .firesOnRecordUpdate])
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info
        do {
            _ = try await db.modifySubscriptions(saving: [sub], deleting: [])
            state.subscribedTag = secret.tag
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
        case .notAuthenticated:
            return .notAuthenticated
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .network
        case .quotaExceeded:
            // Pact's own allowance (not the user's iCloud). Very unlikely; keep it queued and retry later.
            return .network
        case .partialFailure:
            if let first = ck.partialErrorsByItemID?.values.first { return map(first) }
            return .other(ck.localizedDescription)
        default:
            return .other(ck.localizedDescription)
        }
    }
}
