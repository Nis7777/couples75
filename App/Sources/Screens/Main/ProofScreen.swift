import SwiftUI
import UIKit

/// Proof tab: how partners verify each other. "From {partner}" is a two-column gallery of their check-ins to
/// review; "Mine" shows what the partner did with yours. Tapping a tile opens the full proof (photo, reactions,
/// Question and Approve).
struct ProofScreen: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var segment = 0
    @State private var pager: PagerStart?
    @State private var suggesting: RuleProposalFact?

    struct PagerStart: Identifiable {
        var ids: [String]
        var start: String
        var id: String { start }
    }

    private let columns = [GridItem(.flexible(), spacing: 12, alignment: .top),
                           GridItem(.flexible(), spacing: 12, alignment: .top)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Proof")
                    .font(.app(34, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 14)
                    .accessibilityAddTraits(.isHeader)
                PillSegmentedControl(options: ["From \(model.partnerName)", "Mine"], selection: $segment)
                PlanChangesSection(suggest: { suggesting = $0 })
                // Cross-fade between the two galleries.
                VStack(alignment: .leading, spacing: 20) {
                    if segment == 0 { fromPartner } else { mine }
                }
                .id(segment)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: segment)
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $pager) { p in
            ProofPager(ids: p.ids, start: p.start)
                .proofZoomDestination(id: p.start, in: zoom)
        }
        .sheet(item: $suggesting) { p in SuggestInsteadSheet(proposal: p) }
        .onAppear { openFocus() }
        .onChange(of: model.proofFocus) { _, _ in openFocus() }
    }

    private func openFocus() {
        guard let id = model.proofFocus else { return }
        model.proofFocus = nil
        segment = 0
        let ids = orderedPartner.map(\.id)
        pager = PagerStart(ids: ids.contains(id) ? ids : [id], start: id)
    }

    private func open(_ c: CheckInFact, in list: [CheckInFact]) {
        Haptics.tap()
        let ids = list.map(\.id)
        pager = PagerStart(ids: ids.contains(c.id) ? ids : [c.id], start: c.id)
    }

    // MARK: Groups

    /// Day groups, newest first; inside each day, check-ins waiting for review first.
    private func groups(_ list: [CheckInFact], pendingFirst: Bool) -> [(label: String, items: [CheckInFact])] {
        var order: [String] = []
        var byLabel: [String: [CheckInFact]] = [:]
        for c in list {
            let label = model.dayLabel(for: c)
            if byLabel[label] == nil { order.append(label) }
            byLabel[label, default: []].append(c)
        }
        return order.map { label in
            let items = byLabel[label] ?? []
            guard pendingFirst else { return (label, items) }
            return (label, items.filter { model.needsMyApproval($0) } + items.filter { !model.needsMyApproval($0) })
        }
    }

    /// The partner's check-ins in the order the gallery shows them (and the pager swipes through).
    private var orderedPartner: [CheckInFact] {
        groups(model.partnerCheckIns, pendingFirst: true).flatMap(\.items)
    }

    private func gallery(_ list: [CheckInFact], pendingFirst: Bool, mine: Bool) -> some View {
        let gs = groups(list, pendingFirst: pendingFirst)
        let ordered = gs.flatMap(\.items)
        return ForEach(gs, id: \.label) { g in
            VStack(alignment: .leading, spacing: 10) {
                Text(g.label)
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(g.items) { c in
                        ProofTile(checkIn: c, status: mine ? model.mineStatus(c) : model.reviewStatus(c)) {
                            open(c, in: ordered)
                        }
                        .proofZoomSource(id: c.id, in: zoom)
                    }
                }
            }
        }
    }

    // MARK: From partner

    @ViewBuilder
    private var fromPartner: some View {
        if model.partner?.joinedAt == nil {
            emptyState("Nothing yet. \(model.partnerName)'s check-ins show up here once they join.")
        } else if model.partnerCheckIns.isEmpty {
            emptyState("All caught up. Nothing to review right now.")
        } else {
            pendingCounter
            gallery(model.partnerCheckIns, pendingFirst: true, mine: false)
        }
    }

    /// "2 to review" (or "All caught up"), quiet, under the segmented control.
    private var pendingCounter: some View {
        let n = model.unreactedPartnerCheckIns.count
        return HStack(spacing: 8) {
            Circle()
                .fill(n > 0 ? Color.highlight : Color.sage)
                .frame(width: 7, height: 7)
            Text(n > 0 ? "\(n) to review" : "All caught up")
                .font(.app(14, .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.peach.opacity(0.7)))
        .accessibilityElement(children: .combine)
    }

    // MARK: Mine

    @ViewBuilder
    private var mine: some View {
        let mineList = model.checkIns(of: model.meID)
        if mineList.isEmpty {
            emptyState("No proof yet. Check in and \(model.partnerName) can react.")
        } else {
            gallery(mineList, pendingFirst: false, mine: true)
        }
    }

    /// The Polaroid illustration, smaller.
    private func emptyState(_ text: String) -> some View {
        EmptyStateCard(text: text, height: 96, art: "empty_proof")
    }
}

// MARK: - Status

/// The small status under a tile.
struct ProofStatus: Equatable {
    enum Tone { case pending, approved, questioned, neutral }
    var text: String
    var tone: Tone

    var color: Color {
        switch self.tone {
        case .pending: return .highlight
        case .approved: return .sage
        case .questioned: return .gold
        case .neutral: return .textSecondary.opacity(0.5)
        }
    }
}

extension AppModel {
    /// From the partner: what I did with their check-in.
    func reviewStatus(_ c: CheckInFact) -> ProofStatus {
        let mine = reactions(for: c.id).filter { $0.memberID == meID }
        if mine.contains(where: { $0.kind == .approve }) { return ProofStatus(text: "Approved", tone: .approved) }
        if mine.contains(where: { $0.kind == .sus }) { return ProofStatus(text: "Questioned", tone: .questioned) }
        if needsMyApproval(c) { return ProofStatus(text: "To review", tone: .pending) }
        if !c.hasPhoto { return ProofStatus(text: c.healthProof != nil ? "Auto-checked" : "Honour tap", tone: .neutral) }
        return ProofStatus(text: "Reacted", tone: .neutral)
    }

    /// Mine: what the partner did with my check-in.
    func mineStatus(_ c: CheckInFact) -> ProofStatus {
        let theirs = reactions(for: c.id).filter { $0.memberID != c.memberID }
        if theirs.contains(where: { $0.kind == .approve }) { return ProofStatus(text: "Approved", tone: .approved) }
        if theirs.contains(where: { $0.kind == .sus }) { return ProofStatus(text: "Questioned", tone: .questioned) }
        if theirs.contains(where: { $0.kind == .emoji || $0.kind == .comment }) {
            return ProofStatus(text: "Reacted", tone: .neutral)
        }
        if !c.hasPhoto { return ProofStatus(text: "Done", tone: .neutral) }
        if theirs.contains(where: { $0.kind == .seen }) { return ProofStatus(text: "Seen", tone: .neutral) }
        return ProofStatus(text: "Not seen yet", tone: .pending)
    }
}

// MARK: - Tile

/// One gallery tile: a 4:5 thumbnail (or a quiet honour tile), the habit, the time and the status.
struct ProofTile: View {
    @Environment(AppModel.self) private var model
    var checkIn: CheckInFact
    var status: ProofStatus
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .overlay {
                        if checkIn.hasPhoto {
                            CheckInPhoto(checkIn: checkIn)
                        } else {
                            honourFace
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if status.tone == .pending, checkIn.memberID != model.meID {
                            Circle()
                                .fill(Color.highlight)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .padding(10)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.ruleTitle(for: checkIn))
                        .font(.app(15, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(checkIn.capturedAt.formatted(date: .omitted, time: .shortened))
                            .font(.app(12, .medium))
                            .foregroundStyle(Color.textSecondary)
                        Spacer(minLength: 4)
                        HStack(spacing: 4) {
                            Circle().fill(status.color).frame(width: 6, height: 6)
                            Text(status.text)
                                .font(.app(12, .medium))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.ruleTitle(for: checkIn)), \(checkIn.capturedAt.formatted(date: .omitted, time: .shortened)), \(status.text)")
        .accessibilityHint("Opens the proof")
    }

    private var honourFace: some View {
        ZStack {
            Rectangle().fill(Color.peach)
            VStack(spacing: 8) {
                Image(systemName: checkIn.healthProof != nil ? "heart.text.square" : "hand.raised.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.sage)
                Text(checkIn.healthProof != nil ? HealthMetric.proofLine : "Honour tap")
                    .font(.app(13, .medium))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
        }
    }
}

// MARK: - Zoom transition (iOS 18; the standard cover elsewhere)

extension View {
    @ViewBuilder
    func proofZoomSource(id: String, in ns: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: ns) { $0.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) }
        } else {
            self
        }
    }

    @ViewBuilder
    func proofZoomDestination(id: String, in ns: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: ns))
        } else {
            self
        }
    }
}

/// Proof → "Plan changes": rules waiting for approval (Part 8). Nothing shows when there are none.
struct PlanChangesSection: View {
    @Environment(AppModel.self) private var model
    var suggest: (RuleProposalFact) -> Void

    var body: some View {
        let toAnswer = model.proposalsForMeToAnswer
        let mine = model.myPendingProposals
        if !toAnswer.isEmpty || !mine.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Plan changes")
                    .font(.app(20, .bold))
                    .foregroundStyle(Color.textPrimary)
                ForEach(toAnswer) { p in answerCard(p) }
                ForEach(mine) { p in waitingRow(p) }
            }
        }
    }

    private func ruleLine(_ p: RuleProposalFact) -> String {
        let forOther = RulesEngine.resolvedMember(p.forMember, facts: model.facts) != p.proposedBy
        let base = forOther ? "\(p.rule.title) for \(model.forMemberName(p))" : p.rule.title
        return base
    }

    private func answerCard(_ p: RuleProposalFact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Pill(text: "Pending", fill: .brownChip, size: 11)
                Text(p.rule.type == .photo ? "Photo rule" : "Honour rule")
                    .font(.app(12, .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            Text("\(model.name(of: p.proposedBy)) wants to add: \(ruleLine(p))")
                .font(.app(17, .semibold))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let old = model.replacedRule(p) {
                Text("Instead of \(old.title)")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.success()
                    Task { await model.answerProposal(p, accepted: true) }
                } label: {
                    Text("Approve ›")
                        .font(.app(16, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.coral))
                }
                .buttonStyle(PressableStyle())
                Button { suggest(p) } label: {
                    Text("Suggest a change")
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Color.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .peachBox(radius: 18)
    }

    private func waitingRow(_ p: RuleProposalFact) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .foregroundStyle(Color.brownChip)
            VStack(alignment: .leading, spacing: 1) {
                Text(ruleLine(p))
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Waiting for \(model.partnerName) to approve")
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .card(radius: 16, shadow: false)
        .accessibilityElement(children: .combine)
    }
}

/// "Suggest a change": pick another rule for the partner; their proposal is declined and this one sent.
struct SuggestInsteadSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var proposal: RuleProposalFact
    @State private var who = 0

    var body: some View {
        let member = RulesEngine.resolvedMember(proposal.forMember, facts: model.facts)
        let intensity = model.facts.member(member).map { $0.fitnessLevel.intensity } ?? .standard
        let rules = model.rules(for: member)
        RuleChangeSheet(
            title: "Suggest a change",
            currentTitle: proposal.rule.title,
            who: $who,
            suggestions: [],
            intensity: intensity,
            note: "\(model.forMemberName(proposal)) gets your suggestion to approve.",
            validate: { idea in
                let photos = rules.filter { $0.position != proposal.rule.position && $0.type == .photo }.count
                    + (idea.type == .photo ? 1 : 0)
                return photos >= Brand.minPhotoRules ? nil : "Keep at least \(Brand.minPhotoRules) photo rules each."
            },
            onPick: { idea in
                Task { await model.suggestInstead(of: proposal, idea: idea) }
                dismiss()
            })
    }
}

/// The check-in photo (stamp is burned in), loaded from the cache or iCloud.
struct CheckInPhoto: View {
    @Environment(AppModel.self) private var model
    var checkIn: CheckInFact
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.peach)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().tint(.coral)
            }
        }
        .clipped()
        .task(id: checkIn.id) {
            if let d = model.cachedPhoto(checkIn.id) { image = UIImage(data: d); return }
            if let d = await model.photoData(for: checkIn) { image = UIImage(data: d) }
        }
    }
}

/// Small rounded thumbnail (Today's partner card, the "New from" row, Mine).
struct CheckInThumb: View {
    var checkIn: CheckInFact
    var size: CGFloat
    var radius: CGFloat? = nil

    var body: some View {
        CheckInPhoto(checkIn: checkIn)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius ?? size * 0.22, style: .continuous))
    }
}

/// Full-screen proofs (22): swipe through the gallery in the order it shows them.
struct ProofPager: View {
    @Environment(\.dismiss) private var dismiss
    var ids: [String]
    var start: String
    @State private var current: String = ""
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView(selection: $current) {
            ForEach(ids, id: \.self) { id in
                if let c = model.facts.checkIns.first(where: { $0.id == id }) {
                    PartnerCheckInView(checkIn: c, onClose: { dismiss() })
                        .tag(id)
                }
            }
        }
        // Swipe between proofs; no page dots (they'd sit on the Question / Approve bar).
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(AppBackground())
        .onAppear { current = start }
    }
}
