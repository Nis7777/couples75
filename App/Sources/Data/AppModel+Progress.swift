import Foundation
import SwiftUI

/// Daily progress photos (Part 4): private by default, optionally shared with the partner.
extension AppModel {
    static let milestoneDays = [25, 50, 75]

    /// Habits: 30, 100 and 365 days. The 75: Day 25 and 50 (Day 75 has its own screen). Other challenges of
    /// 3 weeks or more: halfway.
    static func milestones(for r: RoundState) -> [Int] {
        if r.mode.isMaintenance { return [30, 100, 365] }
        if r.length == Brand.roundLengthDays { return [25, 50] }
        return r.length >= 21 ? [r.length / 2] : []
    }

    var myLocalDate: String { LocalDate(now(), in: me?.tz ?? .current).string }

    var myProgressToday: ProgressPhoto? { progress.photo(on: myLocalDate) }

    /// Day 1's (the first) progress photo, shown as the ghost overlay in the camera.
    var ghostProgressImage: UIImage? { progress.first.flatMap { progress.image(for: $0) } }

    var shareProgressPhotos: Bool { Prefs.shareProgressPhotos }

    /// The partner's progress photos, only when they chose to share them. Oldest first.
    var partnerProgressShares: [ProgressShareFact] {
        guard let p = partner else { return [] }
        return facts.progressShares.filter { $0.memberID == p.id }.sorted { $0.capturedAt < $1.capturedAt }
    }

    /// Saves today's progress photo (replacing an earlier one from today). Shares a copy if sharing is on.
    func saveProgressPhoto(_ jpeg: Data) async {
        let now = self.now()
        let day = isWarmup ? nil : myToday?.dayNumber
        let result = await progress.save(jpeg, localDate: myLocalDate, dayNumber: day, at: now)
        if shareProgressPhotos, let m = me {
            if let old = result.replaced { await store.deleteProgressShares(ids: [old]) }
            let f = ProgressShareFact(id: result.photo.id, memberID: m.id, localDate: result.photo.localDate,
                                      dayNumber: day, capturedAt: now)
            await save([.progressShare(f, photo: jpeg)])
        }
        Haptics.success()
        await NotificationManager.shared.reschedule(model: self)
    }

    /// Profile → "Share progress pics with partner". On: copies of every progress photo go to the couple's
    /// shared zone. Off: those copies are deleted from the shared zone (the originals stay private).
    func setShareProgressPhotos(_ on: Bool) async {
        Prefs.shareProgressPhotos = on
        guard let m = me else { return }
        if on {
            let existing = Set(facts.progressShares.map(\.id))
            var records: [FactRecord] = []
            for p in progress.sorted where !existing.contains(p.id) {
                guard let data = progress.data(for: p) else { continue }
                records.append(.progressShare(ProgressShareFact(id: p.id, memberID: m.id, localDate: p.localDate,
                                                                dayNumber: p.dayNumber, capturedAt: p.capturedAt),
                                              photo: data))
            }
            if !records.isEmpty { await save(records) }
            toast = "\(partnerName) can now see your progress pics."
        } else {
            await store.deleteProgressShares(ids: facts.progressShares.filter { $0.memberID == m.id }.map(\.id))
            apply(store.cachedFacts())
            toast = "Your progress pics are private again."
        }
    }

    func partnerProgressImage(_ f: ProgressShareFact) async -> UIImage? {
        await store.progressSharePhotoData(id: f.id).flatMap(UIImage.init(data:))
    }

    /// Milestones (see `milestones(for:)`): a celebration with Day 1 next to today, once per milestone and round.
    func evaluateMilestone() {
        guard route == .main, presentedMilestone == nil, let r = currentRound,
              let n = myToday?.dayNumber,
              Self.milestones(for: r).contains(n), !progress.photos.isEmpty else { return }
        let key = "milestone-\(currentRound?.number ?? 1)-\(n)"
        guard !SeenEvents.contains(key) else { return }
        SeenEvents.insert([key])
        presentedMilestone = n
    }
}
