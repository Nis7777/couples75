import Foundation

/// The Proof tab (how partners verify each other's check-ins).
extension AppModel {
    /// Did I react (approve, emoji, Sus or comment) to this check-in? "Seen" doesn't count.
    func hasReacted(to checkIn: CheckInFact) -> Bool {
        facts.reactions.contains { $0.checkInID == checkIn.id && $0.memberID == meID && $0.kind != .seen }
    }

    /// The partner's check-ins, newest first.
    var partnerCheckIns: [CheckInFact] {
        guard let p = partner else { return [] }
        return checkIns(of: p.id)
    }

    /// Only photo proof asks to be approved: a tap (or an Apple Health check) has nothing to look at.
    /// Approving never decides whether a day counts; it's how partners keep each other honest on photos.
    func needsMyApproval(_ checkIn: CheckInFact) -> Bool {
        checkIn.memberID != meID && checkIn.hasPhoto && !hasReacted(to: checkIn)
    }

    /// My partner's photo check-ins I haven't approved or reacted to yet, newest first.
    var unreactedPartnerCheckIns: [CheckInFact] {
        partnerCheckIns.filter(needsMyApproval)
    }

    /// The coral number on the Proof tab.
    /// Photos to approve plus rule changes to approve.
    var proofBadge: Int { unreactedPartnerCheckIns.count + proposalsForMeToAnswer.count }

    /// "Today", "Yesterday", "Day 21" (or a date) for a check-in, in its member's own local days.
    func dayLabel(for checkIn: CheckInFact) -> String {
        let tz = facts.member(checkIn.memberID)?.tz ?? .current
        let today = LocalDate(now(), in: tz)
        if checkIn.localDate == today.string { return "Today" }
        if checkIn.localDate == today.adding(-1).string { return "Yesterday" }
        if checkIn.isWarmup { return "Warm-up" }
        if let n = dayNumber(of: checkIn) { return "Day \(n)" }
        guard let d = LocalDate(string: checkIn.localDate) else { return checkIn.localDate }
        return d.startInstant(in: tz).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// What my partner did with one of my check-ins, for the "Mine" list.
    func partnerResponse(to checkIn: CheckInFact) -> [String] {
        let theirs = reactions(for: checkIn.id).filter { $0.memberID != checkIn.memberID }
        var out: [String] = []
        if theirs.contains(where: { $0.kind == .approve }) { out.append("Approved ❤️") }
        for r in theirs where r.kind == .emoji { if let e = r.emoji { out.append(e) } }
        if theirs.contains(where: { $0.kind == .sus }) { out.append("Questioned 🤨") }
        for r in theirs where r.kind == .comment { if let c = r.comment { out.append("\u{201C}\(c)\u{201D}") } }
        if out.isEmpty {
            // A tap has nothing to approve.
            out.append(!checkIn.hasPhoto ? "Done ✓" : theirs.contains { $0.kind == .seen } ? "Seen" : "Not seen yet")
        }
        return out
    }

    func ruleTitle(for checkIn: CheckInFact) -> String {
        facts.rules.first { $0.id == checkIn.ruleID }?.title ?? "A rule"
    }

    /// Open a check-in in the Proof tab.
    func openInProof(_ checkInID: String) {
        tab = .proof
        proofFocus = checkInID
    }
}
