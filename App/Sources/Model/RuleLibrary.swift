import Foundation

/// One entry of the seeded rule library (section 2.1).
struct LibraryRule: Identifiable, Equatable {
    var key: String
    var type: RuleType
    var easy: String
    var standard: String
    var hard: String
    /// Shown under the rule title in the camera. Keeps photos non-intimate.
    var photoPrompt: String

    var id: String { key }

    func title(for intensity: Intensity) -> String {
        switch intensity {
        case .easy: return easy
        case .standard: return standard
        case .hard: return hard
        }
    }
}

enum RuleLibrary {
    static let all: [LibraryRule] = [
        LibraryRule(key: "workout", type: .photo, easy: "20 min walk", standard: "45 min workout",
                    hard: "Two 45 min workouts",
                    photoPrompt: "Photo of where you trained, your gear or your shoes after."),
        LibraryRule(key: "water", type: .photo, easy: "2L of water", standard: "3L of water", hard: "4L of water",
                    photoPrompt: "Photo of your bottle or today's glasses."),
        LibraryRule(key: "reading", type: .photo, easy: "Read 5 pages", standard: "Read 10 pages",
                    hard: "Read 20 pages",
                    photoPrompt: "Photo of the page you got to."),
        LibraryRule(key: "coldShower", type: .photo, easy: "Cold shower", standard: "Cold shower",
                    hard: "Cold shower",
                    photoPrompt: "Photo of the running shower or your face after. Never your body."),
        LibraryRule(key: "steps", type: .photo, easy: "6k steps", standard: "8k steps", hard: "10k steps",
                    photoPrompt: "Photo of your step counter."),
        LibraryRule(key: "noSugar", type: .honour, easy: "No sugar", standard: "No sugar", hard: "No sugar",
                    photoPrompt: ""),
        LibraryRule(key: "noAlcohol", type: .honour, easy: "No alcohol", standard: "No alcohol",
                    hard: "No alcohol", photoPrompt: ""),
        LibraryRule(key: "noPhoneInBed", type: .honour, easy: "No phone in bed", standard: "No phone in bed",
                    hard: "No phone in bed", photoPrompt: ""),
        LibraryRule(key: "noJunk", type: .honour, easy: "No junk food", standard: "No junk food",
                    hard: "No junk food", photoPrompt: ""),
        LibraryRule(key: "bedtime", type: .honour, easy: "In bed by 23:30", standard: "In bed by 23:30",
                    hard: "In bed by 23:30", photoPrompt: ""),
    ]

    static func rule(_ key: String) -> LibraryRule? { all.first { $0.key == key } }

    static func photoPrompt(for libraryKey: String) -> String {
        rule(libraryKey)?.photoPrompt ?? "Snap something that proves it. Never your body."
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case fitness, money, phoneTime, discipline, sleep, diet
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fitness: return "Fitness"
        case .money: return "Money"
        case .phoneTime: return "Phone time"
        case .discipline: return "Discipline"
        case .sleep: return "Sleep"
        case .diet: return "Diet"
        }
    }

    var icon: String {
        switch self {
        case .fitness: return "figure.run"
        case .money: return "eurosign.circle"
        case .phoneTime: return "iphone"
        case .discipline: return "target"
        case .sleep: return "moon.zzz"
        case .diet: return "leaf"
        }
    }

    /// Library keys this goal suggests, in priority order.
    var ruleKeys: [String] {
        switch self {
        case .fitness: return ["workout", "water"]
        case .discipline: return ["reading", "noPhoneInBed"]
        case .sleep: return ["bedtime"]
        case .diet: return ["noSugar", "noJunk"]
        case .phoneTime: return ["noPhoneInBed"]
        case .money: return ["noJunk"]
        }
    }
}

/// The level picked in onboarding (step 12): shown as "Easy", "Couples 75", "Hard mode".
enum Level: String, Codable, CaseIterable, Identifiable {
    case easy, couples75, hard
    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .couples75: return "Couples 75"
        case .hard: return "Hard mode"
        }
    }

    var mode: RoundMode { self == .hard ? .hard : .standard }

    /// Easy lowers each member's intensity one step, Hard mode raises it one step.
    func adjust(_ intensity: Intensity) -> Intensity {
        let order: [Intensity] = [.easy, .standard, .hard]
        let i = order.firstIndex(of: intensity) ?? 1
        switch self {
        case .easy: return order[max(0, i - 1)]
        case .couples75: return intensity
        case .hard: return order[min(2, i + 1)]
        }
    }

    init(mode: RoundMode) { self = mode == .hard ? .hard : .couples75 }
}

enum PlanGenerator {
    /// 4 rules (library keys) for the selected goals, at least 2 of them photo rules.
    static func ruleKeys(goals: [Goal]) -> [String] {
        var suggested: [String] = []
        for g in Goal.allCases where goals.contains(g) {
            for k in g.ruleKeys where !suggested.contains(k) { suggested.append(k) }
        }
        let photoFillers = ["workout", "water", "reading", "steps", "coldShower"]
        var photos = suggested.filter { RuleLibrary.rule($0)?.type == .photo }
        for k in photoFillers where !photos.contains(k) { photos.append(k) }
        let honours = suggested.filter { RuleLibrary.rule($0)?.type == .honour }
        let honourCount = min(honours.count, 2)
        return Array(photos.prefix(4 - honourCount)) + Array(honours.prefix(honourCount))
    }

    static func rules(keys: [String], memberID: MemberID, intensity: Intensity, round: Int, now: Date) -> [RuleFact] {
        keys.prefix(4).enumerated().compactMap { index, key in
            guard let lib = RuleLibrary.rule(key) else { return nil }
            return RuleFact(id: .newID(), memberID: memberID, fromRound: round, position: index + 1,
                            libraryKey: key, title: lib.title(for: intensity), type: lib.type, createdAt: now)
        }
    }

    static func titles(keys: [String], intensity: Intensity) -> [String] {
        keys.compactMap { RuleLibrary.rule($0)?.title(for: intensity) }
    }
}

/// Bet presets (step 15 / "Change the bet").
enum BetOption: String, Codable, CaseIterable, Identifiable {
    case date, dinner, trip, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: return "Loser plans the date"
        case .dinner: return "Loser cooks dinner for a week"
        case .trip: return "Loser plans the trip"
        case .custom: return "Custom"
        }
    }

    static let customMaxLength = 40

    static func from(text: String) -> (BetOption, String) {
        if let o = allCases.first(where: { $0 != .custom && $0.title == text }) { return (o, "") }
        return (.custom, text)
    }
}
