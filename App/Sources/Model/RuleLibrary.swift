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
    /// Titles use the short "Name: amount" format so they fit on Today ("Instrument: 30 min").
    static let all: [LibraryRule] = [
        LibraryRule(key: "workout", type: .photo, gentle: "Walk: 20 min", standard: "Workout: 45 min",
                    hard: "Workout: 2 × 45 min",
                    photoPrompt: "Photo of where you trained, your gear or your shoes after."),
        LibraryRule(key: "water", type: .photo, gentle: "Water: 2L", standard: "Water: 3L", hard: "Water: 4L",
                    photoPrompt: "Photo of your bottle or today's glasses."),
        LibraryRule(key: "reading", type: .photo, gentle: "Read: 5 pages", standard: "Read: 10 pages",
                    hard: "Read: 20 pages",
                    photoPrompt: "Photo of the page you got to."),
        LibraryRule(key: "coldShower", type: .photo, gentle: "Cold shower", standard: "Cold shower",
                    hard: "Cold shower",
                    photoPrompt: "Photo of the running shower or your face after. Never your body."),
        LibraryRule(key: "steps", type: .photo, gentle: "Steps: 6k", standard: "Steps: 8k", hard: "Steps: 10k",
                    photoPrompt: "Photo of your step counter."),
        LibraryRule(key: "noSugar", type: .honour, gentle: "No sugar", standard: "No sugar", hard: "No sugar",
                    photoPrompt: ""),
        LibraryRule(key: "noAlcohol", type: .honour, gentle: "No alcohol", standard: "No alcohol",
                    hard: "No alcohol", photoPrompt: ""),
        LibraryRule(key: "noPhoneInBed", type: .honour, gentle: "No phone in bed", standard: "No phone in bed",
                    hard: "No phone in bed", photoPrompt: ""),
        LibraryRule(key: "noJunk", type: .honour, gentle: "No junk food", standard: "No junk food",
                    hard: "No junk food", photoPrompt: ""),
        LibraryRule(key: "bedtime", type: .honour, gentle: "Bed by 23:30", standard: "Bed by 23:30",
                    hard: "Bed by 23:30", photoPrompt: ""),
        LibraryRule(key: "noTakeaway", type: .honour, gentle: "No takeaway spending", standard: "No takeaway spending",
                    hard: "No takeaway spending", photoPrompt: ""),
        // Personal goals: Gentle 10 min, Steady 15 min, Hard mode 30 min (set by the level, see PlanGenerator).
        LibraryRule(key: "language", type: .photo, gentle: "Language: 10 min", standard: "Language: 15 min",
                    hard: "Language: 30 min",
                    photoPrompt: "Photo of your lesson, app streak or notebook."),
        LibraryRule(key: "meditate", type: .honour, gentle: "Meditate: 10 min", standard: "Meditate: 15 min",
                    hard: "Meditate: 30 min", photoPrompt: ""),
        LibraryRule(key: "lessSocial", type: .photo, gentle: "Social media: max 1h",
                    standard: "Social media: max 45 min", hard: "Social media: max 30 min",
                    photoPrompt: "Screenshot or photo of today's Screen Time."),
        LibraryRule(key: "instrument", type: .photo, gentle: "Instrument: 10 min", standard: "Instrument: 15 min",
                    hard: "Instrument: 30 min",
                    photoPrompt: "Photo of your instrument or sheet music."),
        LibraryRule(key: "cookAtHome", type: .photo, gentle: "Cook one meal", standard: "Cook one meal",
                    hard: "Cook one meal", photoPrompt: "Photo of the meal you cooked."),
        LibraryRule(key: "journal", type: .photo, gentle: "Journal: 10 min", standard: "Journal: 15 min",
                    hard: "Journal: 30 min", photoPrompt: "Photo of today's page (cover the words if you like)."),
        LibraryRule(key: "stretch", type: .photo, gentle: "Stretch: 10 min", standard: "Stretch: 15 min",
                    hard: "Stretch: 30 min", photoPrompt: "Photo of your mat or where you stretched."),
        LibraryRule(key: "study", type: .photo, gentle: "Study: 10 min", standard: "Study: 15 min",
                    hard: "Study: 30 min", photoPrompt: "Photo of your desk or notes."),
        // Couple maxing: looks, sleep, money and growth.
        LibraryRule(key: "skincare", type: .photo, gentle: "Skincare: PM", standard: "Skincare: AM + PM",
                    hard: "Skincare: AM + PM", photoPrompt: "Photo of your products lined up. Not your face if you'd rather not."),
        LibraryRule(key: "sleep23", type: .honour, gentle: "Bed by 23:30", standard: "Bed by 23:00",
                    hard: "Bed by 22:30", photoPrompt: ""),
        LibraryRule(key: "noSpend", type: .honour, gentle: "No impulse buys", standard: "No-spend day",
                    hard: "No-spend day", photoPrompt: ""),
        LibraryRule(key: "noSocialNight", type: .honour, gentle: "No socials after 22:00",
                    standard: "No socials after 21:00", hard: "No socials after 20:00", photoPrompt: ""),
        LibraryRule(key: "skill", type: .photo, gentle: "New skill: 10 min", standard: "New skill: 20 min",
                    hard: "New skill: 30 min", photoPrompt: "Photo of what you're learning: screen, notes or tools."),
        LibraryRule(key: "progressPic", type: .photo, gentle: "Progress pic", standard: "Progress pic",
                    hard: "Progress pic", photoPrompt: "Same spot, same light. Clothes on, it's for you two."),
        LibraryRule(key: "protein", type: .photo, gentle: "Protein: 100 g", standard: "Protein: 130 g",
                    hard: "Protein: 160 g", photoPrompt: "Photo of a meal or your tracker."),
        LibraryRule(key: "saveMoney", type: .photo, gentle: "Save: 5 a day", standard: "Save: 10 a day",
                    hard: "Save: 20 a day", photoPrompt: "Screenshot of the transfer (hide the balance)."),
        LibraryRule(key: "posture", type: .photo, gentle: "Mobility: 5 min", standard: "Mobility: 10 min",
                    hard: "Mobility: 20 min", photoPrompt: "Photo of your mat or where you did it."),
    ]

    static func rule(_ key: String) -> LibraryRule? { all.first { $0.key == key } }

    /// An SF Symbol for a habit row (custom habits: camera or hand, by type).
    static func icon(for key: String?, type: RuleType) -> String {
        switch key ?? "" {
        case "workout": return "dumbbell.fill"
        case "water": return "drop.fill"
        case "reading": return "book.fill"
        case "coldShower": return "shower.fill"
        case "steps": return "figure.walk"
        case "noSugar": return "birthday.cake"
        case "noAlcohol": return "wineglass"
        case "noPhoneInBed", "noSocialNight", "lessSocial": return "iphone.slash"
        case "noJunk": return "takeoutbag.and.cup.and.straw"
        case "bedtime", "sleep23": return "moon.zzz.fill"
        case "noTakeaway", "noSpend": return "creditcard.fill"
        case "saveMoney": return "banknote.fill"
        case "language": return "character.bubble"
        case "meditate": return "brain.head.profile"
        case "instrument": return "music.note"
        case "cookAtHome", "protein": return "fork.knife"
        case "journal": return "pencil.line"
        case "stretch", "posture": return "figure.cooldown"
        case "study", "skill": return "graduationcap.fill"
        case "skincare": return "sparkles"
        case "progressPic": return "camera.fill"
        default: return type == .photo ? "camera.fill" : "hand.raised.fill"
        }
    }

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

/// "What do you want to level up?" in onboarding, grouped by area (Body, Looks, Mind & money).
enum Goal: String, Codable, CaseIterable, Identifiable {
    // Body
    case fitness, diet, sleep, steps
    // Looks
    case skin, glowUp, posture
    // Mind & money
    case money, phoneTime, discipline, skills
    var id: String { rawValue }

    var area: Area {
        switch self {
        case .fitness, .diet, .sleep, .steps: return .body
        case .skin, .glowUp, .posture: return .looks
        case .money, .phoneTime, .discipline, .skills: return .mind
        }
    }

    var title: String {
        switch self {
        case .fitness: return "Gym"
        case .diet: return "Eat clean"
        case .sleep: return "Sleep"
        case .steps: return "Move more"
        case .skin: return "Skin"
        case .glowUp: return "Glow-up"
        case .posture: return "Posture"
        case .money: return "Money"
        case .phoneTime: return "Phone time"
        case .discipline: return "Read more"
        case .skills: return "New skill"
        }
    }

    var icon: String {
        switch self {
        case .fitness: return "dumbbell.fill"
        case .diet: return "leaf.fill"
        case .sleep: return "moon.zzz.fill"
        case .steps: return "figure.walk"
        case .skin: return "drop.fill"
        case .glowUp: return "sparkles"
        case .posture: return "figure.stand"
        case .money: return "banknote.fill"
        case .phoneTime: return "iphone"
        case .discipline: return "book.fill"
        case .skills: return "graduationcap.fill"
        }
    }

    /// Custom icon `goal_{rawValue}` (docs/IMAGE_PROMPTS.md) replaces the SF Symbol when it's in the assets.
    var asset: String { "goal_\(rawValue)" }

    /// The habit this goal adds (the second choice is used when the first is already taken).
    var ruleKeys: [String] {
        switch self {
        case .fitness: return ["workout"]
        case .diet: return ["noJunk", "noSugar"]
        case .sleep: return ["sleep23", "bedtime"]
        case .steps: return ["steps"]
        case .skin: return ["skincare"]
        case .glowUp: return ["progressPic", "water"]
        case .posture: return ["posture", "stretch"]
        case .money: return ["noSpend", "saveMoney"]
        case .phoneTime: return ["noSocialNight", "noPhoneInBed"]
        case .discipline: return ["reading"]
        case .skills: return ["skill"]
        }
    }
}

/// The level picked in onboarding (step 12): shown as "Gentle", "Steady", "Hard mode".
enum Level: String, Codable, CaseIterable, Identifiable {
    case gentle, steady, hard
    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .steady: return "Steady"
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
        case .steady: return intensity
        case .hard: return order[min(2, i + 1)]
        }
    }

    init(mode: RoundMode) { self = mode == .hard ? .hard : .steady }

    /// Personal and typed goals: Gentle 10 min, Steady 15 min, Hard mode 30 min.
    var personalIntensity: Intensity {
        switch self {
        case .gentle: return .gentle
        case .steady: return .standard
        case .hard: return .hard
        }
    }

    var personalMinutes: Int {
        switch self {
        case .gentle: return 10
        case .steady: return 15
        case .hard: return 30
        }
    }
}

/// A goal typed into "Something else?": "Learn to speak chinese" → name "Learn Chinese" → "Learn Chinese: 15 min".
struct CustomGoal: Codable, Equatable, Hashable, Identifiable {
    var text: String
    /// Clean, short, capitalised name without brands (GoalNamer).
    var name: String
    var type: RuleType = .photo
    var id: String { text.lowercased() }

    func title(level: Level) -> String {
        String("\(name): \(level.personalMinutes) min".prefix(RuleLibrary.customTitleMaxLength))
    }

    var photoHint: String { "Photo that shows you did it today." }
}

/// One rule in a generated plan and why it's there.
struct PlannedRule: Equatable {
    var key: String
    /// The goal that added it; nil for personal goals and fillers.
    var goal: Goal?
    /// A personal goal's title, for rules that came from "Anything personal you want to work on?".
    var personal: String? = nil
    var custom: CustomGoal? = nil

    var reason: String {
        if let goal { return "Because you picked \(goal.title)" }
        if let personal { return "Because you picked \(personal)" }
        if let custom { return "Because you picked \(custom.name)" }
        return "To round out your plan"
    }

    var isPhoto: Bool {
        if let custom { return custom.type == .photo }
        return RuleLibrary.rule(key)?.type == .photo
    }
}

/// One row of a plan: the same rule for both partners, each at their own intensity. Generated ONCE
/// (when the plan is built) and stored; the plan review, the rules written at "Set the stakes", B's rules
/// when joining, Today, the invite card and the widgets all come from these stored rows.
struct PlanRuleRow: Codable, Equatable, Identifiable {
    var id: String
    var reason: String
    var a: RuleIdea
    var b: RuleIdea
}

enum PlanGenerator {
    /// Photo rules added when there aren't 4 rules or 2 photo rules yet. A workout only comes last.
    static let photoFillers = ["reading", "water", "steps", "coldShower", "workout"]

    /// Every chosen goal, personal goal and typed goal becomes a rule; fillers bring it to at least 4 rules
    /// with at least 2 photo rules. More than 6 is allowed here: the plan review asks the user to trim.
    static func plan(goals: [Goal], personal: [PersonalGoal] = [], custom: [CustomGoal] = []) -> [PlannedRule] {
        var picked: [PlannedRule] = []
        for g in Goal.allCases where goals.contains(g) {
            if let key = g.ruleKeys.first(where: { k in !picked.contains { $0.key == k } }) {
                picked.append(PlannedRule(key: key, goal: g))
            }
        }
        for p in PersonalGoal.allCases where personal.contains(p) && !picked.contains(where: { $0.key == p.ruleKey }) {
            picked.append(PlannedRule(key: p.ruleKey, goal: nil, personal: p.title))
        }
        for c in custom where !picked.contains(where: { $0.custom?.id == c.id }) {
            picked.append(PlannedRule(key: RuleFact.customKey, goal: nil, custom: c))
        }
        return complete(picked)
    }

    static func complete(_ picked: [PlannedRule]) -> [PlannedRule] {
        var result = picked
        var photos = result.filter(\.isPhoto).count
        for k in photoFillers where result.count < Brand.minRules || photos < Brand.minPhotoRules {
            guard !result.contains(where: { $0.key == k }) else { continue }
            result.append(PlannedRule(key: k, goal: nil))
            photos += 1
        }
        return result
    }

    /// The stored rows for a plan. Personal and typed goals follow the level (10 / 15 / 30 min);
    /// the quiz goals follow each partner's intensity.
    static func rows(goals: [Goal], personal: [PersonalGoal], custom: [CustomGoal], level: Level,
                     intensityA: Intensity, intensityB: Intensity) -> [PlanRuleRow] {
        plan(goals: goals, personal: personal, custom: custom).map { p in
            PlanRuleRow(id: .newID(), reason: p.reason,
                        a: idea(p, level: level, intensity: intensityA),
                        b: idea(p, level: level, intensity: intensityB))
        }
    }

    static func idea(_ p: PlannedRule, level: Level, intensity: Intensity) -> RuleIdea {
        if let c = p.custom {
            return RuleIdea(title: c.title(level: level), type: c.type, libraryKey: nil,
                            photoHint: c.type == .photo ? c.photoHint : nil)
        }
        let personal = p.personal != nil
        return RuleIdea.library(p.key, intensity: personal ? level.personalIntensity : intensity)
            ?? RuleIdea(title: p.key, type: .honour, libraryKey: nil, photoHint: nil)
    }

    static func ruleKeys(goals: [Goal]) -> [String] { plan(goals: goals).map { $0.key } }

    static func rules(keys: [String], memberID: MemberID, intensity: Intensity, round: Int, now: Date) -> [RuleFact] {
        keys.prefix(Brand.maxRules).enumerated().compactMap { index, key in
            guard let lib = RuleLibrary.rule(key) else { return nil }
            return RuleFact(id: .newID(), memberID: memberID, fromRound: round, position: index + 1,
                            libraryKey: key, title: lib.title(for: intensity), type: lib.type, createdAt: now)
        }
    }

    /// The stored rows as rule facts for one side (positions 1…n).
    static func ruleFacts(rows: [PlanRuleRow], partner: Bool, memberID: MemberID, now: Date) -> [RuleFact] {
        rows.enumerated().map { i, r in
            (partner ? r.b : r.a).ruleFact(memberID: memberID, position: i + 1, round: 1, now: now)
        }
    }

    /// B's rules when joining: an exact copy of the rules A stored for B (same titles, types and positions).
    static func joinerRules(from pending: [RuleFact], memberID: MemberID, now: Date) -> [RuleFact] {
        pending.sorted { $0.position < $1.position }.map { r in
            var copy = r
            copy.id = .newID()
            copy.memberID = memberID
            copy.createdAt = now
            return copy
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
        case .dinner: return "Loser treats the winner to dinner"
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

/// Short habit labels for tight spaces (Today's cards): "Skincare: AM + PM" → "Skincare AM+PM",
/// "Workout: 45 min" → "Workout 45m", "Social media: max 30 min" → "Socials ≤30m". Display only: the stored
/// title never changes, and the full one shows on tap and to VoiceOver.
enum RuleTitle {
    static func short(_ title: String) -> String {
        var s = title
        let words: [(String, String)] = [("Social media", "Socials"), ("No takeaway spending", "No takeaway"),
                                         ("max ", "≤"), (" + ", "+"), (": ", " "), ("≤ ", "≤")]
        for (a, b) in words { s = s.replacingOccurrences(of: a, with: b) }
        let patterns: [(String, String)] = [(#"(\d+) ?min\b"#, "$1m"), (#"(\d+) × "#, "$1×"),
                                            (#"(\d+) g\b"#, "$1g"), (#"(\d+) (hours|hour|hrs|hr)\b"#, "$1h")]
        for (p, r) in patterns {
            s = s.replacingOccurrences(of: p, with: r, options: .regularExpression)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
