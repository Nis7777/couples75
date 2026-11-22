import Foundation

/// Badges and the shared bucket list (the reward when nobody owes the bet).
extension AppModel {
    var badges: [Badge] {
        Badges.all(state: state, facts: facts, meID: meID, progressPhotos: progress.photos.count)
    }

    /// Toast for a newly earned badge (one at a time); every earned badge is remembered.
    func evaluateBadges() {
        guard route == .main, me != nil else { return }
        let earned = badges.filter(\.earned)
        let new = earned.filter { !SeenEvents.contains("badge-\($0.id)") }
        guard !new.isEmpty else { return }
        SeenEvents.insert(new.map { "badge-\($0.id)" })
        if let b = new.first { toast = "Badge unlocked: \(b.title)" }
    }

    var bucketList: [BucketItemFact] {
        facts.bucketItems.sorted { ($0.doneAt != nil ? 1 : 0, $0.createdAt) < ($1.doneAt != nil ? 1 : 0, $1.createdAt) }
    }

    func addBucketItem(_ text: String) async {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !clean.isEmpty else { return }
        await save([.bucketItem(BucketItemFact(id: .newID(), text: clean, addedBy: meID, createdAt: now()))])
    }

    func markBucketItemDone(_ item: BucketItemFact) async {
        var i = item
        i.doneAt = now()
        await save([.bucketItem(i)])
        Haptics.success()
    }

    /// Nobody owes: pick a bucket list item as the shared reward for this round.
    func chooseReward(_ item: BucketItemFact, round: Int) async {
        var i = item
        i.rewardRound = round
        await save([.bucketItem(i)])
        toast = "Reward picked: \(i.text)"
    }

    func reward(for round: Int) -> BucketItemFact? { facts.bucketItems.first { $0.rewardRound == round } }
}
