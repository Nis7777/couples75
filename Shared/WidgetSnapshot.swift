import Foundation

/// Small JSON written by the app into the App Group; the widget only reads it. Never contains photos.
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
