import Foundation

/// Couple maxing: daily habits, challenges on top, shared XP and ranks.
extension AppModel {

    // MARK: Reading

    /// The challenge being played right now (nil while on daily habits).
    var activeChallenge: Challenge? {
        guard let r = currentRound, !r.mode.isMaintenance, !r.isOver else { return nil }
        return Challenges.challenge(r.challengeID) ?? (r.length == Challenges.the75.days ? Challenges.the75 : nil)
    }

    /// A challenge that was just set up and starts tomorrow (habits still count today).
    var upcomingChallenge: Challenge? {
        guard let r = currentRound else { return nil }
        // The newest challenge set up for after these habits, unless it was cancelled since.
        if r.mode.isMaintenance, let next = facts.roundConfigs.filter({ $0.fromRound == r.number + 1 })
            .max(by: { $0.createdAt < $1.createdAt }), next.mode != .maintenance {
            let cancelled = facts.roundConfigs.contains {
                $0.fromRound == r.number + 2 && $0.quitBy != nil && $0.createdAt > next.createdAt
            }
            return cancelled ? nil : Challenges.challenge(next.challengeID)
        }
        if r.status == .waiting, !r.mode.isMaintenance { return Challenges.challenge(r.challengeID) }
        return nil
    }

    /// True while on daily habits (no challenge running or about to start).
    var onHabits: Bool { activeChallenge == nil && upcomingChallenge == nil }

    /// Photo rules need a real photo only in challenges that require proof (The 75). Elsewhere proof is
    /// optional but recommended.
    var photoProofRequired: Bool {
        guard let r = currentRound, !r.mode.isMaintenance else { return false }
        return r.proofRequired
    }

    /// Finished challenges, newest first (for Progress and badges).
    var finishedChallenges: [RoundState] {
        Array(state.rounds.filter { !$0.mode.isMaintenance && $0.status == .completed }.reversed())
    }

    func timesCompleted(_ c: Challenge) -> Int {
        state.rounds.filter { $0.challengeID == c.id && $0.status == .completed }.count
    }

    /// Can a new challenge be started right now? Only from daily habits, once the partner has joined.
    var canStartChallenge: Bool {
        guard facts.memberB?.joinedAt != nil, let r = currentRound else { return false }
        return r.mode.isMaintenance && !r.isOver && upcomingChallenge == nil
    }

    // MARK: Starting and giving up

    /// Starts a challenge tomorrow: today's habits still count. Writes the challenge round and, right after it,
    /// the habits round the couple returns to when it ends (finished, failed or given up).
    func startChallenge(_ c: Challenge, bet: String, reward: String?) async {
        guard canStartChallenge, let round = currentRound else { return }
        let now = self.now()
        let n = round.number + 1
        let cleanBet = String(bet.trimmingCharacters(in: .whitespaces).prefix(BetOption.customMaxLength))
        let cleanReward = reward.map { String($0.trimmingCharacters(in: .whitespaces).prefix(60)) }
        var records: [FactRecord] = [
            .roundConfig(RoundConfigFact(id: .newID(), fromRound: n, mode: .standard, betText: cleanBet,
                                         rewardText: cleanReward?.isEmpty == false ? cleanReward : nil,
                                         createdBy: meID, createdAt: now, length: c.days, saves: c.saves,
                                         challengeID: c.id, proofRequired: c.proofRequired)),
            .roundConfig(RoundConfigFact(id: .newID(), fromRound: n + 1, mode: .maintenance, betText: "",
                                         rewardText: nil, createdBy: meID, createdAt: now)),
        ]
        for m in facts.members {
            let habits = RulesEngine.effectiveRules(for: m.id, round: round.number, facts: facts, at: now)
            let intensity = m.fitnessLevel.intensity
            var ideas: [RuleIdea] = []
            for rule in c.rules {
                // A challenge rule at the member's own level when it's a fitness rule, else as written.
                let level = ["workout", "steps", "water"].contains(rule.key) && !c.proofRequired ? intensity : rule.intensity
                if let idea = RuleIdea.library(rule.key, intensity: level) { ideas.append(idea) }
            }
            // Create your own: the same rules for both, fitness ones at each person's level.
            for idea in c.customIdeas {
                if let key = idea.libraryKey, ["workout", "steps", "water"].contains(key),
                   let leveled = RuleIdea.library(key, intensity: intensity) {
                    ideas.append(leveled)
                } else {
                    ideas.append(idea)
                }
            }
            let challengeKeys = Set(ideas.compactMap(\.libraryKey))
            let kept = c.replacesHabits ? [] : habits.filter { !challengeKeys.contains($0.libraryKey) }
            var position = 1
            for r in kept {
                var copy = r
                copy.id = .newID()
                copy.fromRound = n
                copy.position = position
                copy.createdAt = now
                records.append(.rule(copy))
                position += 1
            }
            for idea in ideas {
                records.append(.rule(idea.ruleFact(memberID: m.id, position: position, round: n, now: now)))
                position += 1
            }
            // Back to the same habits afterwards.
            for (i, r) in habits.enumerated() {
                var copy = r
                copy.id = .newID()
                copy.fromRound = n + 1
                copy.position = i + 1
                copy.createdAt = now
                records.append(.rule(copy))
            }
        }
        if await save(records) {
            Haptics.success()
            toast = "\(c.title) starts tomorrow. Today's habits still count."
        }
    }

    /// Gives up the running challenge: it ends now, lost by me (I owe the bet, if there is one), and we go
    /// back to daily habits tomorrow. Before Day 1 it simply cancels it (no bet, nothing lost).
    func giveUpChallenge() async {
        guard let r = currentRound, !r.isOver, activeChallenge != nil || upcomingChallenge != nil else { return }
        let now = self.now()
        // On habits with a challenge set up for tomorrow, the habits round after it is two rounds on.
        let back = r.mode.isMaintenance ? r.number + 2 : r.number + 1
        var records: [FactRecord] = [
            .roundConfig(RoundConfigFact(id: .newID(), fromRound: back, mode: .maintenance, betText: "",
                                         rewardText: nil, createdBy: meID, createdAt: now, quitBy: meID)),
        ]
        // The habits from before the challenge (already written for the next round) stay; nothing else to copy
        // unless they are missing (older rounds).
        if !facts.rules.contains(where: { $0.fromRound == back }) {
            for m in facts.members {
                let current = RulesEngine.effectiveRules(for: m.id, round: r.number, facts: facts, at: now)
                for (i, rule) in current.enumerated() {
                    var copy = rule
                    copy.id = .newID()
                    copy.fromRound = back
                    copy.position = i + 1
                    copy.createdAt = now
                    records.append(.rule(copy))
                }
            }
        }
        if await save(records) {
            toast = r.mode.isMaintenance || r.status == .waiting ? "Challenge cancelled." : "Back to your daily habits tomorrow."
        }
    }

    // MARK: Ranks

    /// Shows the rank-up celebration once per rank. The first time this phone sees a rank it just remembers it.
    func evaluateRankUp() {
        guard route == .main, me != nil, presentedRankUp == nil, presentedDay75 == nil, presentedRoundEnd == nil,
              presentedSave == nil, presentedMilestone == nil, presentedPactMilestone == nil,
              !presentedPartnerJoined else { return }
        let key = "rank-seen-level"
        let seen = UserDefaults.standard.integer(forKey: key)
        let level = xp.rank.level
        if seen == 0 {
            UserDefaults.standard.set(level, forKey: key)
        } else if level > seen {
            UserDefaults.standard.set(level, forKey: key)
            presentedRankUp = xp.rank
            Haptics.success()
        }
    }
}
