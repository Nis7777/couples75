import Foundation

/// The iCloud layout, as code. Import file: `docs/pact.ckdb` (CloudKit Console or `xcrun cktool import-schema`).
///
/// **Public database (Pact's own; nothing counts against the users' iCloud storage):**
/// - `PactItem`: one encrypted record per fact a partner writes (see `RelayStore` / `Relay.swift`).
///   `couple` (String, queryable): the couple's random tag. `payload` (Bytes): the fact, AES-GCM encrypted with the
///   couple's key. `photo` (Asset, optional): the encrypted photo while it travels to the partner.
///   Indexes: `couple` queryable, `modificationDate` (___modTime) queryable + sortable.
///   Security: read for `_icloud` (the data is encrypted), create for `_icloud`, write for `_creator`.
/// - `InviteCode`: record name = the 6-letter code. `couple` (the tag), `sealedKey` (the couple's key locked with
///   the code), `inviterName`, `createdAt`. Deleted once the partner joins.
/// - `Waitlist`: Android waitlist emails. Create only; nobody can read them from an app.
///
/// **Private database (the user's own iCloud, optional backup):**
/// - `ProgressPhoto` in the zone `ProgressPhotos`: daily progress pics. Saved on the phone first; the iCloud copy
///   is best-effort (it's simply skipped when the user's iCloud is full).
enum CloudKitSchema {
    struct RecordType {
        let name: String
        let fields: [String: String]       // field name → CloudKit type (documentation)
    }

    static let pactItem = RecordType(
        name: RelayStore.itemType,
        fields: ["couple": "String", "payload": "Bytes", "photo": "Asset"])

    static let inviteCode = RecordType(
        name: RelayStore.inviteType,
        fields: ["code": "String", "couple": "String", "sealedKey": "Bytes", "inviterName": "String",
                 "createdAt": "Date/Time"])

    static let waitlist = RecordType(
        name: RelayStore.waitlistType,
        fields: ["email": "String", "createdAt": "Date/Time"])

    static let progressPhoto = RecordType(
        name: "ProgressPhoto",
        fields: ["localDate": "String", "dayNumber": "Int(64)", "capturedAt": "Date/Time", "photo": "Asset"])
    static let progressZoneName = "ProgressPhotos"
}
