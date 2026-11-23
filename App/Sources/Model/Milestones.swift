import Foundation

/// A moment worth sharing: a streak day, a new rank, or a finished challenge.
struct PactMilestone: Identifiable, Equatable {
    enum Kind: Equatable {
        case streak(Int)
        case rank(Rank)
        case challenge(round: Int, title: String, days: Int)
    }

    var kind: Kind

    var id: String {
        switch kind {
        case .streak(let n): return "streak-\(n)"
        case .rank(let r): return "rank-\(r.id)"
        case .challenge(let round, _, _): return "challenge-\(round)"
        }
    }

    /// The big line on the card: "Day 30", "Flame", "The 75".
    var headline: String {
        switch kind {
        case .streak(let n): return "Day \(n)"
        case .rank(let r): return r.title
        case .challenge(_, let title, _): return title
        }
    }

    /// Under the big line.
    var subtitle: String {
        switch kind {
        case .streak: return "of our pact"
        case .rank(let r): return "Our new rank · Level \(r.level)"
        case .challenge(_, _, let days): return "\(days) days, done together"
        }
    }

    /// The text that goes with the image when sharing.
    var shareText: String {
        switch kind {
        case .streak(let n): return "Day \(n) of our pact 🤝"
        case .rank(let r): return "We just hit \(r.title) on our pact 🤝"
        case .challenge(_, let title, _): return "We finished \(title) together 🤝"
        }
    }

    /// Progress → Milestones: the small label under the tile.
    var tileLabel: String {
        switch kind {
        case .streak: return "streak"
        case .rank: return "rank"
        case .challenge: return "finished"
        }
    }
}

enum PactMilestones {
    /// Streak days that get a moment. 90 is the daily-habits plan; a finished challenge (The 75 on day 75) has its
    /// own moment.
    static let streakDays = [7, 30, 50, 90]

    static func streak(_ n: Int) -> PactMilestone { PactMilestone(kind: .streak(n)) }
    static func rank(_ r: Rank) -> PactMilestone { PactMilestone(kind: .rank(r)) }

    /// Everything reached so far: streak days up to the best streak, every rank above Spark up to the current one,
    /// every finished challenge.
    static func unlocked(bestStreak: Int, rank: Rank,
                         finished: [(round: Int, title: String, length: Int)]) -> [PactMilestone] {
        let streaks = streakDays.filter { bestStreak >= $0 }.map(streak)
        let ranks = Ranks.all.filter { $0.level > 1 && $0.level <= rank.level }.map(Self.rank)
        let challenges = finished.map { PactMilestone(kind: .challenge(round: $0.round, title: $0.title, days: $0.length)) }
        return (streaks + ranks + challenges).reversed()
    }
}
