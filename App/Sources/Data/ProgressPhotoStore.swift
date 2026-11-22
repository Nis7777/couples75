import Foundation
import CloudKit
import UIKit

/// One daily progress photo (not a rule check-in). One per person per local day.
struct ProgressPhoto: Codable, Equatable, Identifiable {
    var id: String
    var localDate: String           // yyyy-MM-dd in the owner's time zone
    var dayNumber: Int?             // nil before Day 1 (warm-up)
    var capturedAt: Date
}

/// The user's own progress photos. **Private by default**: stored on this phone (Application Support, not the
/// App Group the widget reads) and in the user's own private CloudKit database (zone `ProgressPhotos`), never
/// in the couple's shared zone. Copies are shared with the partner only when "Share progress pics with
/// partner" is on (see `AppModel.setShareProgressPhotos`).
@MainActor
@Observable
final class ProgressPhotoStore {
    private(set) var photos: [ProgressPhoto] = []
    /// No iCloud in Mock mode: everything stays on the phone.
    var cloudEnabled = true

    @ObservationIgnored private var zoneReady = false
    /// Created only when iCloud is actually used (never in Mock mode / the Simulator): creating a CKContainer
    /// in a build without that iCloud container crashes the app at launch.
    private var db: CKDatabase { CKContainer(identifier: Brand.cloudKitContainer).privateCloudDatabase }
    private var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: CloudKitSchema.progressZoneName, ownerName: CKCurrentUserDefaultName) }

    private static let indexName = "progress-photos.json"

    static var directory: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressPhotos", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    init() {
        let url = Self.directory.appendingPathComponent(Self.indexName)
        if let data = try? Data(contentsOf: url), let list = try? LocalCache.decoder.decode([ProgressPhoto].self, from: data) {
            photos = list.sorted { $0.capturedAt < $1.capturedAt }
        }
    }

    // MARK: Reading

    /// Oldest first.
    var sorted: [ProgressPhoto] { photos.sorted { $0.capturedAt < $1.capturedAt } }
    var first: ProgressPhoto? { sorted.first }
    var latest: ProgressPhoto? { sorted.last }

    func photo(on localDate: String) -> ProgressPhoto? { photos.first { $0.localDate == localDate } }

    static func fileURL(_ id: String) -> URL { directory.appendingPathComponent("\(id).jpg") }

    func data(for p: ProgressPhoto) -> Data? { try? Data(contentsOf: Self.fileURL(p.id)) }

    func image(for p: ProgressPhoto) -> UIImage? { data(for: p).flatMap(UIImage.init(data:)) }

    // MARK: Writing

    /// Saves today's photo. A second photo on the same day replaces the first (one per person per day).
    /// Returns the replaced photo's id, if any, so a shared copy can be replaced too.
    @discardableResult
    func save(_ jpeg: Data, localDate: String, dayNumber: Int?, at date: Date) async -> (photo: ProgressPhoto, replaced: String?) {
        let old = photo(on: localDate)
        if let old { removeLocal(old.id) }
        let p = ProgressPhoto(id: .newID(), localDate: localDate, dayNumber: dayNumber, capturedAt: date)
        try? jpeg.write(to: Self.fileURL(p.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        photos.append(p)
        persist()
        if cloudEnabled {
            await ensureZone()
            let rec = CKRecord(recordType: CloudKitSchema.progressPhoto.name,
                               recordID: CKRecord.ID(recordName: p.id, zoneID: zoneID))
            rec["localDate"] = p.localDate as NSString
            if let n = p.dayNumber { rec["dayNumber"] = NSNumber(value: n) }
            rec["capturedAt"] = p.capturedAt as NSDate
            rec["photo"] = CKAsset(fileURL: Self.fileURL(p.id))
            let deleting = old.map { [CKRecord.ID(recordName: $0.id, zoneID: zoneID)] } ?? []
            _ = try? await db.modifyRecords(saving: [rec], deleting: deleting, savePolicy: .allKeys)
        }
        return (p, old?.id)
    }

    /// Pulls photos taken on this user's other devices or before a reinstall.
    func refresh() async {
        guard cloudEnabled else { return }
        guard let changes = try? await db.recordZoneChanges(inZoneWith: zoneID, since: nil) else { return }
        var changed = false
        for (_, result) in changes.modificationResultsByID {
            guard case .success(let mod) = result else { continue }
            let rec = mod.record
            let id = rec.recordID.recordName
            guard !photos.contains(where: { $0.id == id }),
                  let date = rec["localDate"] as? String, let at = rec["capturedAt"] as? Date else { continue }
            if let asset = rec["photo"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url) {
                try? data.write(to: Self.fileURL(id), options: .atomic)
            }
            photos.append(ProgressPhoto(id: id, localDate: date, dayNumber: (rec["dayNumber"] as? NSNumber)?.intValue,
                                        capturedAt: at))
            changed = true
        }
        if changed { persist() }
    }

    /// Delete my data: removes every progress photo here and in iCloud.
    func deleteAll() async {
        let ids = photos.map(\.id)
        for id in ids { try? FileManager.default.removeItem(at: Self.fileURL(id)) }
        photos = []
        try? FileManager.default.removeItem(at: Self.directory)
        if cloudEnabled {
            _ = try? await db.deleteRecordZone(withID: zoneID)
            zoneReady = false
        }
    }

    // MARK: Private

    private func removeLocal(_ id: String) {
        try? FileManager.default.removeItem(at: Self.fileURL(id))
        photos.removeAll { $0.id == id }
    }

    private func persist() {
        if let data = try? LocalCache.encoder.encode(photos) {
            try? data.write(to: Self.directory.appendingPathComponent(Self.indexName), options: .atomic)
        }
    }

    private func ensureZone() async {
        guard !zoneReady else { return }
        if (try? await db.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])) != nil {
            zoneReady = true
        }
    }
}
