import Foundation

/// Badges, computed from what happened (nothing is stored).
struct Badge: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var icon: String
    var earned: Bool
}

enum Badges {
    static func all(state: EngineState, facts: Facts, meID: MemberID, progressPhotos: Int) -> [Badge] {
        let mine = facts.checkIns.filter { $0.memberID == meID && !$0.isWarmup }
        let mainRounds = state.rounds.filter { !$0.mode.isMaintenance }
        let finished = mainRounds.filter { $0.status == .completed }
        let finishedIDs = Set(finished.compactMap(\.challengeID))
        let the75 = finished.contains { $0.challengeID == Challenges.the75.id || ($0.challengeID == nil && $0.length == Brand.roundLengthDays) }
        let areas = Set(finishedIDs.compactMap { Challenges.challenge($0)?.area })
        let habitDays = state.rounds.filter(\.mode.isMaintenance).compactMap { $0.member(meID)?.countedDays }.reduce(0, +)
        let given = facts.reactions.filter { $0.memberID == meID && ($0.kind == .approve || $0.kind == .emoji) }.count
        let notes = facts.nudges.filter { $0.from == meID && $0.kind == .note }.count
        let flawless = mainRounds.contains { $0.status == .completed && $0.savesUsed == 0 && $0.savesAllowed > 0 }
        let bucketDone = facts.bucketItems.filter { $0.doneAt != nil }.count
        let health = mine.contains { $0.healthProof != nil }

        return [
            Badge(id: "first-proof", title: "First proof", detail: "Your first check-in", icon: "checkmark.seal.fill",
                  earned: !mine.isEmpty),
            Badge(id: "week", title: "7 together", detail: "A 7-day streak together", icon: "flame.fill",
                  earned: state.bestStreak >= 7),
            Badge(id: "shield", title: "Shielded", detail: "Earn a streak shield", icon: "shield.fill",
                  earned: state.bestStreak >= RulesEngine.shieldEvery),
            Badge(id: "first-challenge", title: "Challenger", detail: "Finish your first challenge", icon: "flag.checkered",
                  earned: !finished.isEmpty),
            Badge(id: "all-areas", title: "All-rounder", detail: "Finish a Body, a Looks and a Mind & money challenge",
                  icon: "circle.hexagongrid.fill", earned: areas.count == Area.allCases.count),
            Badge(id: "day75", title: "The 75", detail: "Finish The 75 together", icon: "trophy.fill", earned: the75),
            Badge(id: "habits100", title: "Habit machine", detail: "100 days of daily habits", icon: "repeat.circle.fill",
                  earned: habitDays >= 100),
            Badge(id: "streak30", title: "30-day streak", detail: "30 days in a row together", icon: "bolt.heart.fill",
                  earned: state.bestStreak >= 30),
            Badge(id: "flawless", title: "Flawless", detail: "Finish a challenge without using a save", icon: "sparkles",
                  earned: flawless),
            Badge(id: "shutterbug", title: "Shutterbug", detail: "50 photo check-ins", icon: "camera.fill",
                  earned: mine.filter(\.hasPhoto).count >= 50),
            Badge(id: "cheerleader", title: "Cheerleader", detail: "Cheer your partner 25 times", icon: "hands.clap.fill",
                  earned: given >= 25),
            Badge(id: "notes", title: "Sweet talker", detail: "Send 10 love notes", icon: "heart.text.square.fill",
                  earned: notes >= 10),
            Badge(id: "transformation", title: "Glow-up", detail: "10 progress pics", icon: "person.crop.rectangle.stack.fill",
                  earned: progressPhotos >= 10),
            Badge(id: "health", title: "In sync", detail: "A rule proved by Apple Health", icon: "heart.circle.fill",
                  earned: health),
            Badge(id: "bucket", title: "Dream big", detail: "Tick off a bucket list item", icon: "star.fill",
                  earned: bucketDone >= 1),
        ]
    }
}
