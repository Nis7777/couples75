import SwiftUI
import UIKit

/// Proof tab: how partners verify each other. "From {partner}" lists their check-ins to react to;
/// "Mine" shows what the partner did with yours.
struct ProofScreen: View {
    @Environment(AppModel.self) private var model
    @State private var segment = 0
    @State private var pager: PagerStart?
    @State private var suggesting: RuleProposalFact?

    struct PagerStart: Identifiable {
        var ids: [String]
        var start: String
        var id: String { start }
    }

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
                // Cross-fade between the two lists.
                VStack(alignment: .leading, spacing: 16) {
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
        }
        .sheet(item: $suggesting) { p in SuggestInsteadSheet(proposal: p) }
        .onAppear { openFocus() }
        .onChange(of: model.proofFocus) { _, _ in openFocus() }
    }

    private func openFocus() {
        guard let id = model.proofFocus else { return }
        model.proofFocus = nil
        segment = 0
        let unreacted = model.unreactedPartnerCheckIns.map { $0.id }
        let ids = unreacted.contains(id) ? unreacted : [id]
        pager = PagerStart(ids: ids, start: id)
    }

    // MARK: From partner

    /// Day groups, newest first; inside each day, unreacted check-ins first.
    private var groups: [(label: String, items: [CheckInFact])] {
        var order: [String] = []
        var byLabel: [String: [CheckInFact]] = [:]
        for c in model.partnerCheckIns {
            let label = model.dayLabel(for: c)
            if byLabel[label] == nil { order.append(label) }
            byLabel[label, default: []].append(c)
        }
        return order.map { label in
            let items = byLabel[label] ?? []
            return (label, items.filter { !model.hasReacted(to: $0) } + items.filter { model.hasReacted(to: $0) })
        }
    }

    @ViewBuilder
    private var fromPartner: some View {
        if model.partnerCheckIns.isEmpty || model.partner?.joinedAt == nil {
            emptyState(text: model.partner?.joinedAt == nil
                       ? "Nothing yet. \(model.partnerName)'s check-ins show up here once they join."
                       : "No proof yet today.")
        } else {
            if model.unreactedPartnerCheckIns.isEmpty {
                emptyState(text: "All caught up. Nothing to check right now.")
                    .padding(.bottom, 6)
            }
            ForEach(groups, id: \.label) { g in
                VStack(alignment: .leading, spacing: 12) {
                    Text(g.label)
                        .font(.app(20, .bold))
                        .foregroundStyle(Color.textPrimary)
                    ForEach(g.items) { c in
                        if c.hasPhoto {
                            PhotoProofCard(checkIn: c) {
                                let ids = model.unreactedPartnerCheckIns.map { $0.id }
                                pager = PagerStart(ids: ids.contains(c.id) ? ids : [c.id], start: c.id)
                            }
                        } else {
                            HonourProofCard(checkIn: c)
                        }
                    }
                }
            }
        }
    }

    private func emptyState(text: String) -> some View {
        EmptyStateCard(text: text, height: 180)
    }

    // MARK: Mine

    @ViewBuilder
    private var mine: some View {
        let mineList = model.checkIns(of: model.meID)
        if mineList.isEmpty {
            emptyState(text: "No proof yet today. Check in and \(model.partnerName) can react.")
        } else {
            ForEach(mineList) { c in
                HStack(alignment: .top, spacing: 14) {
                    if c.hasPhoto {
                        CheckInThumb(checkIn: c, size: 64)
                    } else {
                        IconBadge(systemName: "hand.raised.fill", color: .sage, size: 64)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.ruleTitle(for: c))
                            .font(.app(17, .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(model.dayLabel(for: c)) · \(c.capturedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.app(13))
                            .foregroundStyle(Color.textSecondary)
                        FlowChips(items: model.partnerResponse(to: c))
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .card(radius: 18)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Wrapping row of small chips ("Approved ❤️", "🔥", "Sus 🤨", "“Nice”", "Not seen yet").
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

struct FlowChips: View {
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, t in
                Text(t)
                    .font(.app(14, .medium))
                    .foregroundStyle(t == "Not seen yet" ? Color.textSecondary : Color.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(t.hasPrefix("Approved") ? Color.sage.opacity(0.18) : Color.peach))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Photo check-in card: big 4:5 photo with its stamp, rule and time, reactions, Sus and Approve.
struct PhotoProofCard: View {
    @Environment(AppModel.self) private var model
    var checkIn: CheckInFact
    var open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) {
                CheckInPhoto(checkIn: checkIn)
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topTrailing) { UnreactedDot(checkIn: checkIn).padding(12) }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Open \(model.ruleTitle(for: checkIn)) photo")
            HStack {
                Text(model.ruleTitle(for: checkIn))
                    .font(.app(18, .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(checkIn.capturedAt.formatted(date: .omitted, time: .shortened))
                    .font(.app(14, .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            ReactionBar(checkIn: checkIn)
        }
        .padding(14)
        .card()
    }
}

/// Compact honour card: "{partner} stuck to No sugar" with the same actions.
struct HonourProofCard: View {
    @Environment(AppModel.self) private var model
    var checkIn: CheckInFact

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(systemName: "hand.raised.fill", color: .sage, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.name(of: checkIn.memberID)) stuck to \(model.ruleTitle(for: checkIn))")
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(checkIn.healthProof.map { "\($0) · \(checkIn.capturedAt.formatted(date: .omitted, time: .shortened))" }
                         ?? checkIn.capturedAt.formatted(date: .omitted, time: .shortened))
                        .font(.app(13))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 0)
                UnreactedDot(checkIn: checkIn)
            }
            ReactionBar(checkIn: checkIn)
        }
        .padding(14)
        .card()
    }
}

/// Coral dot on check-ins I haven't reacted to.
struct UnreactedDot: View {
    @Environment(AppModel.self) private var model
    var checkIn: CheckInFact

    var body: some View {
        if checkIn.memberID != model.meID && !model.hasReacted(to: checkIn) {
            Circle()
                .fill(Color.coral)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .accessibilityLabel("Not reacted yet")
        }
    }
}

/// ❤️ 🔥 💪 👀 😂, then Sus 🤨 and Approve ›.
struct ReactionBar: View {
    @Environment(AppModel.self) private var model
    var checkIn: CheckInFact
    private let emojis = ["❤️", "🔥", "💪", "👀", "😂"]

    private var mine: [ReactionFact] {
        model.reactions(for: checkIn.id).filter { $0.memberID == model.meID }
    }
    private var approved: Bool { mine.contains { $0.kind == .approve } }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(emojis, id: \.self) { e in
                    let used = mine.contains { $0.kind == .emoji && $0.emoji == e }
                    Button {
                        Haptics.tap()
                        Task { await model.react(to: checkIn, kind: .emoji, emoji: e) }
                    } label: {
                        Text(e)
                            .font(.system(size: 22))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(used ? Color.peach : Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(used ? Color.coral : Color.cardBorder, lineWidth: used ? 1.5 : 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("React \(e)")
                }
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    Task { await model.react(to: checkIn, kind: .sus) }
                } label: {
                    Text("Sus 🤨")
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Color.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                Button {
                    guard !approved else { return }
                    Haptics.success()
                    Task { await model.react(to: checkIn, kind: .approve) }
                } label: {
                    Text(approved ? "Approved ❤️" : "Approve ›")
                        .font(.app(16, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(approved ? Color.sage : Color.coral))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(approved ? "Approved" : "Approve")
            }
        }
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

/// Full-screen partner check-ins (22): swipe to the next unreacted one.
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
        .tabViewStyle(.page(indexDisplayMode: ids.count > 1 ? .automatic : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(AppBackground())
        .onAppear { current = start }
    }
}
