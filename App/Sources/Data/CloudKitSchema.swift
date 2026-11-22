import Foundation

/// The CloudKit schema, as code (section 6.2).
///
/// Every couple lives in one custom zone `Couple-{uuid}` in the owner's (A's) private database, shared
/// with B through a zone-wide `CKShare`. All records are children of the `Couple` root record.
/// Record names are the fact ids. Field names match the Swift property names.
///
/// In the Development environment CloudKit creates these record types automatically the first time the
/// app saves one ("just-in-time" schema). Deploy them to Production in the CloudKit Console (see README).
enum CloudKitSchema {
    struct RecordType {
        let name: String
        let fields: [String: String]       // field name → CloudKit type (documentation)
        let dateKeys: Set<String>
        let boolKeys: Set<String>
        let jsonKeys: Set<String>          // nested values stored as a JSON string
    }

    static let couple = RecordType(
        name: "Couple",
        fields: ["createdAt": "Date/Time", "ownerMemberID": "String", "title": "String", "invitedName": "String",
                 "invitedAvatar": "String (JSON)", "invitedFitness": "String", "invitedWakeTime": "String"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: ["invitedAvatar"])

    static let member = RecordType(
        name: "Member",
        fields: ["role": "String", "name": "String", "characterID": "String", "timeZone": "String",
                 "wakeTime": "String", "fitnessLevel": "String", "joinedAt": "Date/Time",
                 "subscribedUntil": "Date/Time", "subscriptionProduct": "String",
                 "subscriptionPeriods": "String (JSON)", "leftAt": "Date/Time",
                 "skinColor": "String", "hairColor": "String", "jacketColor": "String"],
        dateKeys: ["joinedAt", "subscribedUntil", "leftAt"], boolKeys: [], jsonKeys: ["subscriptionPeriods"])

    static let roundConfig = RecordType(
        name: "RoundConfig",
        fields: ["fromRound": "Int(64)", "mode": "String", "betText": "String", "rewardText": "String",
                 "createdBy": "String", "createdAt": "Date/Time"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: [])

    static let rule = RecordType(
        name: "Rule",
        fields: ["memberID": "String", "fromRound": "Int(64)", "position": "Int(64)", "libraryKey": "String",
                 "title": "String", "type": "String", "createdAt": "Date/Time"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: [])

    static let ruleTweak = RecordType(
        name: "RuleTweak",
        fields: ["proposedBy": "String", "payload": "String (JSON)", "createdAt": "Date/Time"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: ["payload"])

    static let tweakAnswer = RecordType(
        name: "TweakAnswer",
        fields: ["tweakID": "String", "accepted": "Int(64)", "answeredAt": "Date/Time"],
        dateKeys: ["answeredAt"], boolKeys: ["accepted"], jsonKeys: [])

    /// `uploadedAt` is not stored: it is the record's server `creationDate`.
    static let checkIn = RecordType(
        name: "CheckIn",
        fields: ["memberID": "String", "ruleID": "String", "capturedAt": "Date/Time", "localDate": "String",
                 "stampText": "String", "hasPhoto": "Int(64)", "isWarmup": "Int(64)", "honourFallback": "Int(64)",
                 "photo": "Asset"],
        dateKeys: ["capturedAt", "uploadedAt"], boolKeys: ["hasPhoto", "isWarmup", "honourFallback"], jsonKeys: [])

    static let reaction = RecordType(
        name: "Reaction",
        fields: ["checkInID": "String", "memberID": "String", "kind": "String", "emoji": "String",
                 "comment": "String", "createdAt": "Date/Time"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: [])

    static let pauseRequest = RecordType(
        name: "PauseRequest",
        fields: ["requestedBy": "String", "startDate": "String", "days": "Int(64)", "reason": "String",
                 "createdAt": "Date/Time"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: [])

    static let pauseAnswer = RecordType(
        name: "PauseAnswer",
        fields: ["pauseID": "String", "accepted": "Int(64)", "answeredAt": "Date/Time"],
        dateKeys: ["answeredAt"], boolKeys: ["accepted"], jsonKeys: [])

    static let betPaid = RecordType(
        name: "BetPaid",
        fields: ["roundNumber": "Int(64)", "memberID": "String", "paidAt": "Date/Time"],
        dateKeys: ["paidAt"], boolKeys: [], jsonKeys: [])

    /// Public database only. Record name = the 6-letter code, so lookups need no query index.
    static let inviteCode = RecordType(
        name: "InviteCode",
        fields: ["code": "String", "shareURL": "String", "inviterName": "String", "createdAt": "Date/Time"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: [])

    /// Public database only (Android waitlist).
    static let waitlist = RecordType(
        name: "Waitlist",
        fields: ["email": "String", "createdAt": "Date/Time"],
        dateKeys: ["createdAt"], boolKeys: [], jsonKeys: [])

    static let zoneTypes: [RecordType] = [couple, member, roundConfig, rule, ruleTweak, tweakAnswer, checkIn,
                                          reaction, pauseRequest, pauseAnswer, betPaid]

    static func type(named name: String) -> RecordType? { zoneTypes.first { $0.name == name } }

    static let zonePrefix = "Couple-"
    static let zoneSubscriptionID = "couple-zone-changes"
    static let sharedSubscriptionID = "shared-db-changes"
}
