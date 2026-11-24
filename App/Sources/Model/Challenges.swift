import Foundation

// Couple maxing: daily habits are the base (an endless no-stakes round). On top of them the couple can start a
// challenge from the catalogue. A challenge is a round with its own length, rules, saves, proof rule and bet.
// When it ends (finished, failed or given up) the couple goes straight back to their habits.

/// The three areas the app covers (not the relationship itself).
enum Area: String, Codable, CaseIterable, Identifiable {
    case body, looks, mind
    var id: String { rawValue }

    var title: String {
        switch self {
        case .body: return "Body"
        case .looks: return "Looks"
        case .mind: return "Mind & money"
        }
    }

    var subtitle: String {
        switch self {
        case .body: return "Gym, diet, sleep"
        case .looks: return "Skin, style, glow-up"
        case .mind: return "Focus, skills, money"
        }
    }

    /// SF Symbol fallback; a custom image named `area_{rawValue}` replaces it (see docs/IMAGE_PROMPTS.md).
    var icon: String {
        switch self {
        case .body: return "dumbbell.fill"
        case .looks: return "sparkles"
        case .mind: return "brain.head.profile"
        }
    }

    var asset: String { "area_\(rawValue)" }
}

/// One rule a challenge adds: a library rule at a fixed intensity.
struct ChallengeRule: Equatable {
    var key: String
    var intensity: Intensity = .standard

    var idea: RuleIdea? { RuleIdea.library(key, intensity: intensity) }
}

struct Challenge: Identifiable, Equatable {
    var id: String
    var title: String
    var tagline: String
    var area: Area?
    var days: Int
    var rules: [ChallengeRule]
    /// Shared saves (misses that don't end the challenge).
    var saves: Int
    /// The 75: photo rules need a photo and the bet is part of it.
    var proofRequired = false
    var stakesRequired = false
    /// The 75 replaces the daily habits for its length; every other challenge adds its rules on top.
    var replacesHabits = false
    var icon: String
    var isSignature = false
    /// "Create your own": the rules the couple picked (the same for both of you).
    var customIdeas: [RuleIdea] = []

    var isCustom: Bool { id.hasPrefix(Challenges.customPrefix) }

    /// Custom image named `challenge_{id}` replaces the SF Symbol when it's in the asset catalogue.
    var asset: String { "challenge_\(id)" }

    /// XP for finishing it together.
    var xpReward: Int { days * 20 + (proofRequired ? 500 : 0) }

    var lengthText: String { days % 7 == 0 && days <= 28 ? "\(days / 7) week\(days == 7 ? "" : "s")" : "\(days) days" }
    var savesText: String { saves == 0 ? "No saves" : "\(saves) shared save\(saves == 1 ? "" : "s")" }

    func ruleIdeas() -> [RuleIdea] { customIdeas.isEmpty ? rules.compactMap(\.idea) : customIdeas }
}

enum Challenges {
    static let the75 = Challenge(
        id: "the75", title: "The 75", tagline: "The hardest thing you'll do together.",
        area: nil, days: 75,
        rules: [ChallengeRule(key: "workout", intensity: .hard), ChallengeRule(key: "water", intensity: .hard),
                ChallengeRule(key: "reading", intensity: .standard), ChallengeRule(key: "noAlcohol"),
                ChallengeRule(key: "noJunk"), ChallengeRule(key: "progressPic")],
        saves: 0, proofRequired: true, stakesRequired: true, replacesHabits: true,
        icon: "flame.fill", isSignature: true)

    static let all: [Challenge] = [
        the75,
        // Body
        Challenge(id: "shred21", title: "21-Day Shred", tagline: "Train, eat clean, repeat.", area: .body, days: 21,
                  rules: [ChallengeRule(key: "workout"), ChallengeRule(key: "noJunk")], saves: 1,
                  icon: "figure.strengthtraining.traditional"),
        Challenge(id: "steps14", title: "10k Steps", tagline: "Two weeks of 10,000 steps each.", area: .body, days: 14,
                  rules: [ChallengeRule(key: "steps", intensity: .hard)], saves: 1, icon: "figure.walk"),
        Challenge(id: "dry30", title: "Dry 30", tagline: "Thirty days, no alcohol.", area: .body, days: 30,
                  rules: [ChallengeRule(key: "noAlcohol")], saves: 1, icon: "wineglass"),
        Challenge(id: "sleep14", title: "Sleep Reset", tagline: "Early nights, no phones in bed.", area: .body, days: 14,
                  rules: [ChallengeRule(key: "sleep23"), ChallengeRule(key: "noPhoneInBed")], saves: 1,
                  icon: "moon.zzz.fill"),
        Challenge(id: "protein21", title: "Protein Month", tagline: "Hit your protein every day.", area: .body, days: 21,
                  rules: [ChallengeRule(key: "protein")], saves: 1, icon: "fork.knife"),
        // Looks
        Challenge(id: "glow30", title: "30-Day Glow-Up", tagline: "Skin, water and a daily progress pic.", area: .looks,
                  days: 30,
                  rules: [ChallengeRule(key: "skincare"), ChallengeRule(key: "water"), ChallengeRule(key: "progressPic")],
                  saves: 2, icon: "sparkles"),
        Challenge(id: "skin14", title: "Clear Skin", tagline: "Routine twice a day, no sugar.", area: .looks, days: 14,
                  rules: [ChallengeRule(key: "skincare"), ChallengeRule(key: "noSugar")], saves: 1,
                  icon: "drop.fill"),
        Challenge(id: "posture21", title: "Stand Tall", tagline: "Mobility every day for better posture.",
                  area: .looks, days: 21, rules: [ChallengeRule(key: "posture")], saves: 1,
                  icon: "figure.cooldown"),
        // Mind & money
        Challenge(id: "nospend7", title: "No-Spend Week", tagline: "Only the essentials for seven days.", area: .mind,
                  days: 7, rules: [ChallengeRule(key: "noSpend")], saves: 0, icon: "creditcard.fill"),
        Challenge(id: "save30", title: "Savings Sprint", tagline: "Put money away every single day.", area: .mind,
                  days: 30, rules: [ChallengeRule(key: "saveMoney")], saves: 2, icon: "banknote.fill"),
        Challenge(id: "read30", title: "Read 30", tagline: "Twenty pages a day each.", area: .mind, days: 30,
                  rules: [ChallengeRule(key: "reading", intensity: .hard)], saves: 2, icon: "book.fill"),
        Challenge(id: "detox7", title: "Phone Detox", tagline: "Less scrolling, more living.", area: .mind, days: 7,
                  rules: [ChallengeRule(key: "lessSocial", intensity: .hard), ChallengeRule(key: "noSocialNight")],
                  saves: 0, icon: "iphone.slash"),
        Challenge(id: "skill30", title: "Skill Sprint", tagline: "Learn one new thing, 20 minutes a day.",
                  area: .mind, days: 30, rules: [ChallengeRule(key: "skill")], saves: 2, icon: "graduationcap.fill"),
    ]

    static func challenge(_ id: String?) -> Challenge? {
        guard let id else { return nil }
        if id.hasPrefix(customPrefix) { return custom(fromID: id) }
        return all.first { $0.id == id }
    }

    // MARK: Create your own

    /// A custom challenge keeps its name, length and saves in its id ("custom|30|1|Summer Shred"), so every screen
    /// that looks a challenge up by id (finish screen, milestones, share card) shows it like the built-in ones.
    /// Its rules are stored as the couple's rules for that round.
    static let customPrefix = "custom|"
    static let customLengths = [7, 14, 21, 30, 60, 75]
    static let customMaxRules = 3

    static func custom(title: String, days: Int, saves: Int, ideas: [RuleIdea]) -> Challenge {
        let name = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        let clean = name.isEmpty ? "Our challenge" : name
        var c = Challenge(id: "\(customPrefix)\(days)|\(saves)|\(clean)", title: clean,
                          tagline: "Your own challenge, the same rules for both of you.", area: nil, days: days,
                          rules: [], saves: saves, icon: "star.fill")
        c.customIdeas = ideas
        return c
    }

    private static func custom(fromID id: String) -> Challenge? {
        let parts = id.dropFirst(customPrefix.count).split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3, let days = Int(parts[0]), let saves = Int(parts[1]) else { return nil }
        return custom(title: parts[2], days: days, saves: saves, ideas: [])
    }

    static func inArea(_ area: Area) -> [Challenge] { all.filter { $0.area == area } }
}

// MARK: - XP and ranks

/// Seven shared ranks. A custom badge image named `rank_{id}` replaces the SF Symbol when it's in the assets.
struct Rank: Identifiable, Equatable {
    var level: Int
    var id: String
    var title: String
    var minXP: Int
    var icon: String
    var asset: String { "rank_\(id)" }
}

enum Ranks {
    static let all: [Rank] = [
        Rank(level: 1, id: "spark", title: "Spark", minXP: 0, icon: "sparkle"),
        Rank(level: 2, id: "kindle", title: "Kindle", minXP: 250, icon: "flame"),
        Rank(level: 3, id: "flame", title: "Flame", minXP: 750, icon: "flame.fill"),
        Rank(level: 4, id: "blaze", title: "Blaze", minXP: 1_750, icon: "bolt.fill"),
        Rank(level: 5, id: "forge", title: "Forge", minXP: 3_500, icon: "hammer.fill"),
        Rank(level: 6, id: "summit", title: "Summit", minXP: 6_500, icon: "mountain.2.fill"),
        Rank(level: 7, id: "legend", title: "Legend", minXP: 11_000, icon: "crown.fill"),
    ]

    static func rank(for xp: Int) -> Rank { all.last { xp >= $0.minXP } ?? all[0] }
    static func next(after r: Rank) -> Rank? { all.first { $0.level == r.level + 1 } }
}

/// The couple's shared XP (pure team: one number, one rank, computed from the facts, never stored).
struct CoupleXP: Equatable {
    var total: Int
    var today: Int
    var rank: Rank
    var next: Rank?

    /// 0…1 through the current rank.
    var progress: Double {
        guard let next else { return 1 }
        return Double(total - rank.minXP) / Double(max(1, next.minXP - rank.minXP))
    }

    var toNext: Int { next.map { max(0, $0.minXP - total) } ?? 0 }
}

enum XP {
    static let perCheckIn = 2
    static let perCompleteDay = 10
    /// Bonus when you BOTH complete a day.
    static let perCoupleDay = 10

    static func compute(state: EngineState, facts: Facts, now: Date) -> CoupleXP {
        let checkIns = facts.checkIns.filter { RulesEngine.isValid($0) }.count
        var total = checkIns * perCheckIn
        for r in state.rounds {
            let completes = r.members.map { m in m.days.filter { $0.dayNumber != nil && $0.outcome == .complete } }
            total += completes.map(\.count).reduce(0, +) * perCompleteDay
            if completes.count == 2 {
                let a = Set(completes[0].compactMap(\.dayNumber)), b = Set(completes[1].compactMap(\.dayNumber))
                total += a.intersection(b).count * perCoupleDay
            }
            if r.status == .completed, !r.mode.isMaintenance {
                total += Challenges.challenge(r.challengeID)?.xpReward ?? r.length * 20
            }
        }
        // Today (not settled yet), so checking off feels instant.
        let todays = state.today.values.filter { $0.dayNumber != nil }
        let done = todays.filter(\.isComplete).count
        var today = done * perCompleteDay + (done == 2 ? perCoupleDay : 0)
        let startOfToday = Calendar.current.startOfDay(for: now)
        today += facts.checkIns.filter { RulesEngine.isValid($0) && $0.capturedAt >= startOfToday }.count * perCheckIn
        total += done * perCompleteDay + (done == 2 ? perCoupleDay : 0)
        let rank = Ranks.rank(for: total)
        return CoupleXP(total: total, today: today, rank: rank, next: Ranks.next(after: rank))
    }
}
