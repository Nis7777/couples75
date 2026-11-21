import SwiftUI

/// Step 14 (11): "{A} & {B}'s 75-day plan": a peach panel with the gold Day 1 → 75 ring behind the
/// couple, the rules card in two coloured columns, the saves card with three gold squares.
struct PlanRevealView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        let d = model.draft
        OnboardingPage(step: d.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    TitleText("\(d.myName) & \(d.partnerName)'s 75-day plan", size: 28)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    RingHero(left: SceneCharacter(characterID: d.characterID, name: d.myName),
                             right: SceneCharacter(characterID: Characters.partnerPreview(for: d.characterID),
                                                   name: d.partnerName),
                             progress: 0.62, centerTitle: "Day 1", centerSubtitle: "→ 75", panelRadius: 0)
                        .frame(height: 300)
                        .padding(.horizontal, -Metrics.side)
                    RulesColumnsCard(
                        leftName: d.myName, leftRules: PlanGenerator.titles(keys: d.ruleKeys, intensity: d.myIntensity),
                        rightName: d.partnerName,
                        rightRules: PlanGenerator.titles(keys: d.ruleKeys, intensity: d.partnerIntensity),
                        rightNote: "Draft: \(d.partnerName) can adjust when they join")
                    SavesCard(mode: d.level.mode)
                }
                .padding(.bottom, 8)
            }
        } actions: {
            PrimaryButton("See our plan") { next() }
        }
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
