import Foundation

/// One entry of the seeded rule library (section 2.1).
struct LibraryRule: Identifiable, Equatable {
    var key: String
    var type: RuleType
    var gentle: String
    var standard: String
    var hard: String
    /// Shown under the rule title in the camera. Keeps photos non-intimate.
    var photoPrompt: String

    var id: String { key }

    func title(for intensity: Intensity) -> String {
        switch intensity {
        case .gentle: return gentle
        case .standard: return standard
        case .hard: return hard
        }
    }
}

enum RuleLibrary {
    static let all: [LibraryRule] = [
        LibraryRule(key: "workout", type: .photo, gentle: "20 min walk", standard: "45 min workout",
                    hard: "Two 45 min workouts",
                    photoPrompt: "Photo of where you trained, your gear or your shoes after."),
        LibraryRule(key: "water", type: .photo, gentle: "2L of water", standard: "3L of water", hard: "4L of water",
                    photoPrompt: "Photo of your bottle or today's glasses."),
        LibraryRule(key: "reading", type: .photo, gentle: "Read 5 pages", standard: "Read 10 pages",
                    hard: "Read 20 pages",
                    photoPrompt: "Photo of the page you got to."),
        LibraryRule(key: "coldShower", type: .photo, gentle: "Cold shower", standard: "Cold shower",
                    hard: "Cold shower",
                    photoPrompt: "Photo of the running shower or your face after. Never your body."),
        LibraryRule(key: "steps", type: .photo, gentle: "6k steps", standard: "8k steps", hard: "10k steps",
                    photoPrompt: "Photo of your step counter."),
        LibraryRule(key: "noSugar", type: .honour, gentle: "No sugar", standard: "No sugar", hard: "No sugar",
                    photoPrompt: ""),
        LibraryRule(key: "noAlcohol", type: .honour, gentle: "No alcohol", standard: "No alcohol",
                    hard: "No alcohol", photoPrompt: ""),
        LibraryRule(key: "noPhoneInBed", type: .honour, gentle: "No phone in bed", standard: "No phone in bed",
                    hard: "No phone in bed", photoPrompt: ""),
        LibraryRule(key: "noJunk", type: .honour, gentle: "No junk food", standard: "No junk food",
                    hard: "No junk food", photoPrompt: ""),
        LibraryRule(key: "bedtime", type: .honour, gentle: "In bed by 23:30", standard: "In bed by 23:30",
                    hard: "In bed by 23:30", photoPrompt: ""),
        LibraryRule(key: "noTakeaway", type: .honour, gentle: "No takeaway spending", standard: "No takeaway spending",
                    hard: "No takeaway spending", photoPrompt: ""),
        // Personal goals (Part 8): the curated recommendations, Gentle / Couples 75 / Hard.
        LibraryRule(key: "language", type: .photo, gentle: "10 min language practice",
                    standard: "15 min language practice", hard: "30 min language practice",
                    photoPrompt: "Photo of your lesson, app streak or notebook."),
        LibraryRule(key: "meditate", type: .honour, gentle: "5 min meditation", standard: "10 min meditation",
                    hard: "20 min meditation", photoPrompt: ""),
        LibraryRule(key: "lessSocial", type: .photo, gentle: "Under 1h social media",
                    standard: "Under 45 min social media", hard: "Under 30 min social media",
                    photoPrompt: "Screenshot or photo of today's Screen Time."),
        LibraryRule(key: "instrument", type: .photo, gentle: "10 min instrument practice",
                    standard: "20 min instrument practice", hard: "30 min instrument practice",
                    photoPrompt: "Photo of your instrument or sheet music."),
        LibraryRule(key: "cookAtHome", type: .photo, gentle: "Cook one meal", standard: "Cook one meal",
                    hard: "Cook one meal", photoPrompt: "Photo of the meal you cooked."),
        LibraryRule(key: "journal", type: .photo, gentle: "Journal 3 lines", standard: "Journal 5 lines",
                    hard: "Journal 10 lines", photoPrompt: "Photo of today's page (cover the words if you like)."),
        LibraryRule(key: "stretch", type: .photo, gentle: "5 min stretch", standard: "10 min stretch",
                    hard: "15 min stretch", photoPrompt: "Photo of your mat or where you stretched."),
        LibraryRule(key: "study", type: .photo, gentle: "25 min study", standard: "50 min study",
                    hard: "90 min study", photoPrompt: "Photo of your desk or notes."),
    ]

    static func rule(_ key: String) -> LibraryRule? { all.first { $0.key == key } }

    static func photoPrompt(for libraryKey: String) -> String {
        rule(libraryKey)?.photoPrompt ?? "Snap something that proves it. Never your body."
    }

    /// The prompt under the camera: a custom rule's own hint, else the library's.
    static func photoPrompt(for rule: RuleFact) -> String {
        if let hint = rule.photoHint?.trimmingCharacters(in: .whitespaces), !hint.isEmpty { return hint }
        return photoPrompt(for: rule.libraryKey)
    }

    static let customTitleMaxLength = 40
}

/// "Anything personal you want to work on?" (Part 8). Each maps to a curated library rule.
enum PersonalGoal: String, Codable, CaseIterable, Identifiable {
    case language, readMore, meditate, saveMoney, lessSocial, instrument, study, cookAtHome, journal, stretch
    var id: String { rawValue }

    var title: String {
        switch self {
        case .language: return "Learn a language"
        case .readMore: return "Read more"
        case .meditate: return "Meditate"
        case .saveMoney: return "Save money"
        case .lessSocial: return "Less social media"
        case .instrument: return "Practise an instrument"
        case .study: return "Study"
        case .cookAtHome: return "Cook at home"
        case .journal: return "Journal"
        case .stretch: return "Stretch"
        }
    }

    var ruleKey: String {
        switch self {
        case .readMore: return "reading"
        case .saveMoney: return "noTakeaway"
        default: return rawValue
        }
    }

    static let otherMaxLength = 60
}

/// One rule the Change sheet can offer: a library rule (key) or a custom one.
struct RuleIdea: Identifiable, Equatable, Hashable, Codable {
    var title: String
    var type: RuleType
    var libraryKey: String?
    var photoHint: String?
    var id: String { (libraryKey ?? "custom") + "|" + title }

    static func library(_ key: String, intensity: Intensity) -> RuleIdea? {
        guard let lib = RuleLibrary.rule(key) else { return nil }
        return RuleIdea(title: lib.title(for: intensity), type: lib.type, libraryKey: key, photoHint: nil)
    }

    /// The rule fact this idea becomes for a member and position.
    func ruleFact(memberID: MemberID, position: Int, round: Int, now: Date) -> RuleFact {
        RuleFact(id: .newID(), memberID: memberID, fromRound: round, position: position,
                 libraryKey: libraryKey ?? RuleFact.customKey,
                 title: String(title.trimmingCharacters(in: .whitespaces).prefix(RuleLibrary.customTitleMaxLength)),
                 type: type, createdAt: now,
                 photoHint: type == .photo ? photoHint.flatMap { $0.isEmpty ? nil : $0 } : nil)
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

    /// The rule this goal adds (Diet's second choice is used when the first is already taken).
    var ruleKeys: [String] {
        switch self {
        case .fitness: return ["workout"]
        case .discipline: return ["reading"]
        case .sleep: return ["bedtime"]
        case .diet: return ["noJunk", "noSugar"]
        case .phoneTime: return ["noPhoneInBed"]
        case .money: return ["noTakeaway"]
        }
    }
}

/// The level picked in onboarding (step 12): shown as "Gentle", "Couples 75", "Hard mode".
enum Level: String, Codable, CaseIterable, Identifiable {
    case gentle, couples75, hard
    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .couples75: return "Couples 75"
        case .hard: return "Hard mode"
        }
    }

    var mode: RoundMode { self == .hard ? .hard : .standard }

    /// Gentle lowers each member's intensity one step, Hard mode raises it one step.
    func adjust(_ intensity: Intensity) -> Intensity {
        let order: [Intensity] = [.gentle, .standard, .hard]
        let i = order.firstIndex(of: intensity) ?? 1
        switch self {
        case .gentle: return order[max(0, i - 1)]
        case .couples75: return intensity
        case .hard: return order[min(2, i + 1)]
        }
    }

    init(mode: RoundMode) { self = mode == .hard ? .hard : .couples75 }
}

/// One rule in a generated plan and why it's there.
struct PlannedRule: Equatable {
    var key: String
    /// The goal that added it; nil for a filler (to keep 2 photo rules or reach 4 rules).
    var goal: Goal?
    /// A personal goal's title, for rules that came from "Anything personal you want to work on?".
    var personal: String? = nil

    var reason: String {
        if let goal { return "Because you picked \(goal.title)" }
        if let personal { return "Because you picked \(personal)" }
        return "To round out your plan"
    }
}

enum PlanGenerator {
    /// Photo rules added when there aren't enough rules or photo rules. A workout only comes last.
    static let photoFillers = ["reading", "water", "steps", "coldShower", "workout"]

    /// The plan follows the quiz: each chosen goal maps to one rule; 4 rules, at least 2 photo rules.
    /// Personal goals come after the quiz goals (and before fillers).
    static func plan(goals: [Goal], personal: [PersonalGoal] = []) -> [PlannedRule] {
        var picked: [PlannedRule] = []
        for g in Goal.allCases where goals.contains(g) {
            if let key = g.ruleKeys.first(where: { k in !picked.contains { $0.key == k } }) {
                picked.append(PlannedRule(key: key, goal: g))
            }
        }
        for p in PersonalGoal.allCases where personal.contains(p) && !picked.contains(where: { $0.key == p.ruleKey }) {
            picked.append(PlannedRule(key: p.ruleKey, goal: nil, personal: p.title))
        }
        return complete(picked)
    }

    /// Trims or fills a list of planned rules to exactly 4 with at least 2 photo rules (goal rules first).
    static func complete(_ picked: [PlannedRule]) -> [PlannedRule] {
        func isPhoto(_ r: PlannedRule) -> Bool { RuleLibrary.rule(r.key)?.type == .photo }
        var photos = picked.filter(isPhoto)
        let honours = picked.filter { !isPhoto($0) }
        let honourCount = min(honours.count, 4 - max(2, min(photos.count, 4)))
        let needed = 4 - honourCount
        for k in photoFillers where photos.count < needed && !picked.contains(where: { $0.key == k }) {
            photos.append(PlannedRule(key: k, goal: nil))
        }
        let chosen = Array(photos.prefix(needed)) + Array(honours.prefix(honourCount))
        // Keep the quiz order (goal rules in the order they were picked, fillers last).
        return picked.filter { p in chosen.contains(p) } + chosen.filter { c in !picked.contains(c) }
    }

    static func ruleKeys(goals: [Goal]) -> [String] { plan(goals: goals).map { $0.key } }

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
