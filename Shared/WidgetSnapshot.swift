import Foundation

/// Small JSON written by the app into the App Group; the widget only reads it. Never contains photos.
/// One of my rules in the widget snapshot.
struct SnapshotRule: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var isHonour: Bool
    var done: Bool
}

struct WidgetSnapshot: Codable, Equatable {
    var nameA: String
    var nameB: String
    var characterA: String
    var characterB: String
    var dayNumber: Int?          // nil before Day 1 / between rounds
    var roundLength: Int
    var doneA: Bool
    var doneB: Bool
    var streak: Int
    var statusLine: String?      // e.g. "Warm-up", "Paused"
    var updatedAt: Date
    /// Full avatars (colour overrides). characterB == "" means B hasn't joined: draw the dashed outline.
    var avatarA: Avatar? = nil
    var avatarB: Avatar? = nil
    /// My rules today, for the interactive widget (honour rules can be ticked off from the Home Screen).
    var myRules: [SnapshotRule] = []
    var myName: String = ""
    var partnerLeft: Int = 0
    var partnerTotal: Int = 0
    var partnerName: String = ""

    var myLeft: Int { myRules.filter { !$0.done }.count }

    /// Optimistic update after a tap in the widget (the app confirms it).
    static func markDone(ruleID: String) {
        guard var s = load(), let i = s.myRules.firstIndex(where: { $0.id == ruleID }) else { return }
        s.myRules[i].done = true
        s.save()
    }

    static let fileName = "widget_snapshot.json"

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(nameA: "Maya", nameB: "Joao", characterA: "w1", characterB: "m1",
                       dayNumber: 14, roundLength: 75, doneA: true, doneB: false, streak: 13,
                       statusLine: nil, updatedAt: Date())
    }

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Brand.appGroup)?
            .appendingPathComponent(fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
