import Foundation

// Everything the pre-paywall onboarding screens SAY lives here, so copy can be edited in one place:
// the mirror lines and tiny wins, the couple score, the FAQ and the testimonials.

// MARK: - Mirror (echoes their answers)

enum MirrorCopy {
    /// "You picked Gym and Phone time for you and Sara." Only the person onboarding answered, so it never
    /// claims the partner chose them.
    static func goalsLine(_ goals: [Goal], partner: String) -> String {
        let names = goals.map(\.title)
        let us = partner.isEmpty ? "the two of you" : "you and \(partner)"
        switch names.count {
        case 0: return "You're about to level up, \(us)."
        case 1: return "You picked \(names[0]) for \(us)."
        case 2: return "You picked \(names[0]) and \(names[1]) for \(us)."
        case 3: return "You picked \(names[0]), \(names[1]) and \(names[2]) for \(us)."
        default: return "You picked \(names[0]), \(names[1]) and \(names.count - 2) more for \(us)."
        }
    }

    /// Based on "How long have you been together?" (`<1 yr`, `1–3 yrs`, `3+ yrs`).
    static func togetherLine(_ together: String?) -> String? {
        switch together {
        case "<1 yr": return "New couples who build habits together build the relationship too."
        case "1–3 yrs": return "This is when couples either grow together or settle into routines."
        case "3+ yrs": return "After years together, it's easy to let each other slide."
        default: return nil
        }
    }

    /// Shown when they said they're long distance.
    static let longDistanceLine = "Miles apart, same team: you'll see each other's check-ins the moment they happen."

    static let reframe = "Here's what most couples don't realize: you don't lack motivation. You lack someone watching. That's what \(Brand.appName) fixes."

    /// A tiny win for tomorrow. Long distance gets versions you can do apart (same time, a call, a photo).
    static func tinyWin(_ goal: Goal, longDistance: Bool = false) -> String {
        switch goal {
        case .fitness: return longDistance ? "A 10-minute walk each, on a call if you like" : "A 10-minute walk together counts"
        case .diet: return longDistance ? "Cook one meal each and swap photos" : "Cook one meal together"
        case .sleep: return longDistance ? "Say goodnight, then lights out, same night" : "Same bedtime, one night"
        case .steps: return "Take the stairs all day, both of you"
        case .skin: return longDistance ? "Wash your faces before bed, then say goodnight" : "Wash your faces before bed, side by side"
        case .glowUp: return "A full bottle of water before lunch"
        case .posture: return longDistance ? "Five minutes of stretching each, at the same time" : "Five minutes of stretching together"
        case .money: return "No-spend day tomorrow"
        case .phoneTime: return "No phones in bed tonight"
        case .discipline: return "Ten pages each before bed"
        case .skills: return "Twenty minutes on something new"
        }
    }

    /// Used when they picked fewer than 3 goals.
    static let fillerWins = ["Both make the bed before 9am", "A glass of water as soon as you wake up",
                             "One honest compliment each"]

    /// Three tiny first wins for tomorrow, from their goals in the order they picked them.
    static func tinyWins(_ goals: [Goal], longDistance: Bool = false) -> [String] {
        Array((goals.map { tinyWin($0, longDistance: longDistance) } + fillerWins).prefix(3))
    }
}

// MARK: - Couple score (a projection shown before the paywall)

/// Five onboarding-only stats. "Today" is derived from their answers (lower in the areas they want to work on);
/// "in 90 days" is what daily check-ins add, most in the areas they picked. Deterministic: the same answers always
/// give the same numbers. It's a projection, never shown as a promise.
enum CoupleStat: String, CaseIterable, Identifiable {
    case discipline, fitness, focus, connection, consistency
    var id: String { rawValue }

    var title: String {
        switch self {
        case .discipline: return "Discipline"
        case .fitness: return "Fitness"
        case .focus: return "Focus"
        case .connection: return "Connection"
        case .consistency: return "Consistency"
        }
    }

    var icon: String {
        switch self {
        case .discipline: return "target"
        case .fitness: return "dumbbell.fill"
        case .focus: return "scope"
        case .connection: return "heart.fill"
        case .consistency: return "flame.fill"
        }
    }

    var base: Int {
        switch self {
        case .discipline: return 48
        case .fitness: return 52
        case .focus: return 50
        case .connection: return 63
        case .consistency: return 45
        }
    }

    /// The stat a goal works on.
    static func stat(for goal: Goal) -> CoupleStat {
        switch goal {
        case .fitness, .steps, .diet: return .fitness
        case .phoneTime, .discipline, .skills: return .focus
        case .sleep: return .consistency
        case .money, .skin, .glowUp, .posture: return .discipline
        }
    }
}

struct CoupleScore {
    var today: [CoupleStat: Int]
    var later: [CoupleStat: Int]
    /// The rank 90 perfect days really earn with the app's XP rules.
    var laterRank: Rank
    static let days = 90

    static func make(goals: [Goal], quitFrequency: Double, names: String, rulesPerPerson: Int) -> CoupleScore {
        let picked = Set(goals.map(CoupleStat.stat(for:)))
        var today: [CoupleStat: Int] = [:], later: [CoupleStat: Int] = [:]
        for (i, s) in CoupleStat.allCases.enumerated() {
            let hits = goals.filter { CoupleStat.stat(for: $0) == s }.count
            var v = s.base - 8 * hits + jitter(names, i)
            if s == .consistency { v -= Int(quitFrequency.rounded()) * 4 }   // "How often do you quit?"
            v = min(max(v, 22), 74)
            today[s] = v
            later[s] = min(97, v + (picked.contains(s) ? 41 : 24) + abs(jitter(names, i + 7)))
        }
        return CoupleScore(today: today, later: later,
                           laterRank: Ranks.rank(for: XP.projected(days: days, rulesPerPerson: rulesPerPerson)))
    }

    /// −4…4 from the names (FNV-1a: stable across launches, unlike `hashValue`).
    private static func jitter(_ s: String, _ salt: Int) -> Int {
        var h: UInt32 = 2_166_136_261 &+ UInt32(salt)
        for b in s.lowercased().utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return Int(h % 9) - 4
    }
}

extension XP {
    /// XP for `days` perfect days together (every rule checked in by both, both complete every day).
    static func projected(days: Int, rulesPerPerson: Int) -> Int {
        days * (2 * rulesPerPerson * perCheckIn + 2 * perCompleteDay + perCoupleDay)
    }
}

// MARK: - FAQ (answers follow how the app really works)

struct FAQItem: Identifiable {
    var question: String
    var answer: String
    var id: String { question }
}

enum OnboardingFAQ {
    static let items: [FAQItem] = [
        FAQItem(question: "What if one of us misses a day?",
                answer: "Your couple streak only grows on days you both finish. Every 7 days you both complete earns a streak shield (you can bank 2), and a shield covers a missed day so the streak doesn't break. Daily habits have no penalty beyond that. In a challenge, you share a few saves that cover missed days (The 75 has none)."),
        FAQItem(question: "What if my partner stops doing it?",
                answer: "You each complete your own day, and your partner can't fail yours. The couple streak and your shared rank only grow when you both finish, so you feel it. They get reminders, and you can nudge them or send a note with one tap."),
        FAQItem(question: "Does one subscription cover both of us?",
                answer: "Yes. One subscription covers you both. Your partner joins free."),
        FAQItem(question: "Can we change our habits later?",
                answer: "Any time, together. Suggest a change and it starts the day after your partner approves it."),
        FAQItem(question: "When does a new day start?",
                answer: "At midnight in your own time zone, so it works even if you live apart."),
        FAQItem(question: "Is The 75 included?",
                answer: "Yes. The 75 is our hardest challenge: 75 days, photo proof and a bet, no saves. Start it, or any shorter challenge, whenever you're both ready."),
    ]
}

// MARK: - Testimonials (placeholders only: replace with real reviews before release)

struct Testimonial: Identifiable {
    var quote: String
    var name: String
    /// Placeholders are shown in DEBUG builds only, so nothing fake ever ships.
    var isPlaceholder: Bool
    var id: String { quote + name }
}

enum Testimonials {
    /// Edit here. Set `isPlaceholder: false` only for real reviews you have permission to use.
    static let all: [Testimonial] = [
        Testimonial(quote: "Placeholder: replace with a real review.", name: "Placeholder name", isPlaceholder: true),
        Testimonial(quote: "Placeholder: replace with a real review.", name: "Placeholder name", isPlaceholder: true),
        Testimonial(quote: "Placeholder: replace with a real review.", name: "Placeholder name", isPlaceholder: true),
    ]

    static var shown: [Testimonial] {
        #if DEBUG
        return all
        #else
        return all.filter { !$0.isPlaceholder }
        #endif
    }
}
