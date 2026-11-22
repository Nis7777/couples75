import Foundation

/// Nudges and small love notes between partners.
extension AppModel {
    static let notePresets = ["Proud of you ❤️", "You've got this 💪", "Thanks for doing this with me", "Miss you 😘"]
    static let noteMaxLength = 80
    /// At most one nudge every 2 hours, so it stays playful.
    static let nudgeCooldown: TimeInterval = 2 * 3600

    private var lastNudgeFromMe: NudgeFact? {
        facts.nudges.filter { $0.from == meID && $0.kind == .nudge }.max { $0.createdAt < $1.createdAt }
    }

    /// The partner still has rules left today and I haven't nudged them in the last 2 hours.
    var canNudgePartner: Bool {
        guard let p = partner, p.joinedAt != nil, let t = partnerToday, t.dayNumber != nil, t.remaining > 0 else { return false }
        if let last = lastNudgeFromMe, now().timeIntervalSince(last.createdAt) < Self.nudgeCooldown { return false }
        return true
    }

    func sendNudge() async {
        guard let p = partner, let t = partnerToday else { return }
        let left = t.remaining == 1 ? "1 rule left today." : "\(t.remaining) rules left today."
        let ok = await save([.nudge(NudgeFact(id: .newID(), from: meID, to: p.id, kind: .nudge, text: left,
                                             createdAt: now()))])
        if ok {
            Haptics.light()
            toast = "Nudge sent to \(p.name)."
        }
    }

    func sendNote(_ text: String) async {
        guard let p = partner else { return }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.noteMaxLength))
        guard !clean.isEmpty else { return }
        let ok = await save([.nudge(NudgeFact(id: .newID(), from: meID, to: p.id, kind: .note, text: clean,
                                             createdAt: now()))])
        if ok {
            Haptics.success()
            toast = "Note sent to \(p.name)."
        }
    }

    /// The newest note to me from the last 24 hours that I haven't dismissed (shown on Today).
    var unreadNote: NudgeFact? {
        facts.nudges
            .filter { $0.to == meID && $0.kind == .note && now().timeIntervalSince($0.createdAt) < 86_400
                      && !SeenEvents.contains("note-\($0.id)") }
            .max { $0.createdAt < $1.createdAt }
    }

    func dismissNote(_ n: NudgeFact) {
        SeenEvents.insert(["note-\(n.id)"])
        recompute()
    }
}
