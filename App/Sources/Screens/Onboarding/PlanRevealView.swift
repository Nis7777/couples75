import SwiftUI

/// Step 14 (11): "{A} & {B}'s 75-day plan": a peach panel with the gold Day 1 → 75 ring behind the
/// couple, the rules card in two coloured columns, the saves card with three gold squares.
struct PlanRevealView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    /// "Change" on each rule (Part 8). Changed rules wait for the partner's approval.
    var editable = true
    @State private var changing: ChangingRow?

    private struct ChangingRow: Identifiable {
        var index: Int
        /// Trimming to 6: "Swap" replaces the row for both partners directly.
        var swap = false
        var id: String { "\(index)-\(swap)" }
    }

    var body: some View {
        let d = model.draft
        OnboardingPage(step: d.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    TitleText("\(d.myName) & \(d.partnerName)'s 75-day plan", size: 28)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    RingHero(left: SceneCharacter(avatar: d.avatar, name: d.myName), right: model.sceneBBuilt,
                             progress: 0.62, centerTitle: "Day 1", centerSubtitle: "→ 75", panelRadius: 0, inset: 20)
                        .frame(height: 310)
                        .padding(.horizontal, -Metrics.side)
                    if d.tooManyRules > 0 {
                        Text("Up to \(Brand.maxRules) rules each. Swap or remove \(d.tooManyRules) more to continue.")
                            .font(.app(15, .semibold))
                            .foregroundStyle(Color.coral)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .peachBox(radius: 14)
                    }
                    PlanRulesCard(rows: d.planRows,
                                  leftName: d.myName, rightName: d.partnerName,
                                  rightNote: d.partnerFitness == nil ? "Draft: \(d.partnerName) can adjust when they join" : nil,
                                  onChange: editable && d.tooManyRules == 0 ? { changing = ChangingRow(index: $0) } : nil,
                                  onSwap: editable && d.tooManyRules > 0 ? { changing = ChangingRow(index: $0, swap: true) } : nil,
                                  onRemove: editable && d.tooManyRules > 0 ? { i in
                                      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { model.draft.removeRow(i) }
                                  } : nil,
                                  canRemove: { d.canRemove($0) })
                    if d.planRows.contains(where: \.pending) {
                        Text("Changed rules are pending until \(d.partnerName) approves. The original rule stays until then.")
                            .font(.app(13))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    SavesCard(mode: d.level.mode)
                }
                .padding(.bottom, 28)
            }
        } actions: {
            PrimaryButton("Set the stakes", isEnabled: d.tooManyRules == 0 && !d.planRules.isEmpty) { next() }
        }
        .onAppear { if model.draft.planRules.isEmpty { model.draft.generatePlan() } }
        .sheet(item: $changing) { row in
            if row.swap {
                DraftRuleSwapSheet(index: row.index)
            } else {
                DraftRuleChangeSheet(index: row.index)
            }
        }
    }
}

/// Trimming to 6 rules: replace a row for both partners (no approval needed: nothing is agreed yet).
struct DraftRuleSwapSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var index: Int
    @State private var who = 0

    var body: some View {
        let d = model.draft
        let row = d.planRows.first { $0.index == index }
        RuleChangeSheet(
            title: "Swap a rule",
            currentTitle: row?.left,
            who: $who,
            suggestions: d.suggestions(intensity: d.myIntensity, extra: d.personalIdeas),
            intensity: d.myIntensity,
            note: "Swaps this rule for both of you.",
            validate: { idea in
                let ok = d.photoCount(forPartner: false, replacing: index, with: idea) >= Brand.minPhotoRules
                    && d.photoCount(forPartner: true, replacing: index, with: idea) >= Brand.minPhotoRules
                return ok ? nil : "Keep at least \(Brand.minPhotoRules) photo rules each."
            },
            onPick: { idea in
                model.draft.swapRow(index, idea: idea)
                dismiss()
            })
    }
}

/// The plan reveal's Change sheet for one row: pick who it's for, then a rule.
struct DraftRuleChangeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var index: Int
    @State private var forPartner = false

    var body: some View {
        let d = model.draft
        let intensity = forPartner ? d.partnerIntensity : d.myIntensity
        let row = d.planRows.first { $0.index == index }
        RuleChangeSheet(
            title: "Change a rule",
            currentTitle: forPartner ? row?.right : row?.left,
            whoOptions: [d.myName, d.partnerName],
            who: Binding(get: { forPartner ? 1 : 0 }, set: { forPartner = $0 == 1 }),
            suggestions: d.suggestions(intensity: intensity, extra: d.personalIdeas),
            intensity: intensity,
            note: "\(d.partnerName) approves changes when they join. Until then the original rule stays.",
            validate: { idea in
                d.photoCount(forPartner: forPartner, replacing: index, with: idea) >= Brand.minPhotoRules
                    ? nil : "Keep at least \(Brand.minPhotoRules) photo rules each."
            },
            canReset: d.change(at: index, forPartner: forPartner) != nil,
            onReset: {
                model.draft.setChange(index: index, forPartner: forPartner, idea: nil)
                dismiss()
            },
            onPick: { idea in
                model.draft.setChange(index: index, forPartner: forPartner, idea: idea)
                dismiss()
            })
    }
}

/// One row of the plan: why it's there, A's version and B's version.
struct PlanRow: Identifiable, Equatable {
    var index: Int
    var reason: String
    var left: String
    var right: String
    /// Waiting for the partner's approval (Part 8).
    var pending: Bool = false
    var id: Int { index }
}

/// The plan reveal's rules: a row per rule with A (coral) and B (sage) side by side,
/// "Because you picked {goal}" under it, and an optional "Change" button.
struct PlanRulesCard: View {
    var rows: [PlanRow]
    var leftName: String
    var rightName: String
    var rightNote: String?
    var onChange: ((Int) -> Void)?
    /// More than 6 rules: "Swap" and "Remove" on each row.
    var onSwap: ((Int) -> Void)? = nil
    var onRemove: ((Int) -> Void)? = nil
    var canRemove: (Int) -> Bool = { _ in true }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily rules")
                .font(.app(20, .bold))
                .foregroundStyle(Color.textPrimary)
            HStack {
                Text(leftName).font(.app(16, .bold)).foregroundStyle(Color.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(rightName).font(.app(16, .bold)).foregroundStyle(Color.sage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(rows) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        ruleText(r.left, color: .coral)
                        ruleText(r.right, color: .sage)
                    }
                    HStack(spacing: 8) {
                        Text(r.reason)
                            .font(.app(12))
                            .foregroundStyle(Color.textSecondary)
                        if r.pending {
                            Pill(text: "Pending", fill: .brownChip, size: 11)
                        }
                        Spacer(minLength: 4)
                        if let onChange {
                            Button("Change") { onChange(r.index) }
                                .font(.app(13, .semibold))
                                .foregroundStyle(Color.coral)
                                .accessibilityLabel("Change \(r.left)")
                        }
                        if let onSwap {
                            Button("Swap") { onSwap(r.index) }
                                .font(.app(13, .semibold))
                                .foregroundStyle(Color.coral)
                                .accessibilityLabel("Swap \(r.left)")
                        }
                        if let onRemove {
                            Button("Remove") { onRemove(r.index) }
                                .font(.app(13, .semibold))
                                .foregroundStyle(canRemove(r.index) ? Color.coral : Color.textSecondary.opacity(0.4))
                                .disabled(!canRemove(r.index))
                                .accessibilityLabel("Remove \(r.left)")
                        }
                    }
                }
                .padding(.vertical, 4)
                if r.index != rows.last?.index { Divider() }
            }
            if let rightNote {
                Text(rightNote)
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func ruleText(_ t: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(t)
                .font(.app(15, .medium))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "Daily rules" card with two columns: A in coral, B in sage.
struct RulesColumnsCard: View {
    var title = "Daily rules"
    var leftName: String
    var leftRules: [String]
    var rightName: String
    var rightRules: [String]
    var rightNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.app(20, .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(alignment: .top, spacing: 16) {
                column(name: leftName, rules: leftRules, color: .coral, note: nil)
                column(name: rightName, rules: rightRules, color: .sage, note: rightNote)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func column(name: String, rules: [String], color: Color, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(name)
                .font(.app(16, .bold))
                .foregroundStyle(color)
            ForEach(Array(rules.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(r)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let note {
                Text(note)
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "3 saves · Shared. Each one covers a missed day." (peach, thin coral border, gold squares on the right),
/// or the Hard mode version.
struct SavesCard: View {
    var mode: RoundMode
    var savesLeft: Int? = nil

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(mode == .hard ? "No saves" : "\(Brand.savesPerRound) saves")
                    .font(.app(18, .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(mode == .hard ? "One miss restarts the round" : "Shared. Each one covers a missed day.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if mode != .hard {
                SaveSquares(left: savesLeft ?? Brand.savesPerRound, total: Brand.savesPerRound, size: 22)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .peachBox(radius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// Small gold squares: filled = saves left.
struct SaveSquares: View {
    var left: Int
    var total: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: size * 0.3) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(i < left ? Color.gold : Color.gold.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.gold, lineWidth: i < left ? 0 : 1.2))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(left) of \(total) saves left")
    }
}
