import AppIntents
import WidgetKit
import Foundation

/// Tick off an honour rule from the interactive widget. Conforms to `LiveActivityIntent` so iOS runs it in the
/// app's process (the app saves a real check-in to iCloud). If the app can't take it right then, the tap is
/// queued in the App Group with its time and saved on the app's next launch or refresh.
struct CheckHonourRuleIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Check off a rule"
    static var description = IntentDescription("Ticks off one of today's honour rules.")
    static var isDiscoverable = false

    @Parameter(title: "Rule ID") var ruleID: String

    init() {}
    init(ruleID: String) { self.ruleID = ruleID }

    func perform() async throws -> some IntentResult {
        await WidgetCheckIns.handle(ruleID: ruleID, at: Date())
        return .result()
    }
}

/// Widget taps that still need to become check-ins.
struct QueuedCheckIn: Codable, Equatable {
    var ruleID: String
    var at: Date
}

enum WidgetCheckIns {
    /// Set by the app at launch: saves the check-in for real. nil inside the widget extension.
    @MainActor static var appHandler: ((String, Date) async -> Bool)?

    static let fileName = "widget_checkins.json"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Brand.appGroup)?
            .appendingPathComponent(fileName)
    }

    @MainActor
    static func handle(ruleID: String, at date: Date) async {
        WidgetSnapshot.markDone(ruleID: ruleID)
        var saved = false
        if let handler = appHandler { saved = await handler(ruleID, date) }
        if !saved { enqueue(QueuedCheckIn(ruleID: ruleID, at: date)) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> [QueuedCheckIn] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return (try? d.decode([QueuedCheckIn].self, from: data)) ?? []
    }

    static func enqueue(_ item: QueuedCheckIn) {
        var list = load()
        guard !list.contains(where: { $0.ruleID == item.ruleID }) else { return }
        list.append(item)
        write(list)
    }

    /// Takes everything queued (the app saves them).
    static func drain() -> [QueuedCheckIn] {
        let list = load()
        if !list.isEmpty { write([]) }
        return list
    }

    private static func write(_ list: [QueuedCheckIn]) {
        guard let url = fileURL else { return }
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        if let data = try? e.encode(list) { try? data.write(to: url, options: .atomic) }
    }
}
