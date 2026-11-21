import SwiftUI

/// Step 14 (11): "{A} & {B}'s 75-day plan".
struct PlanRevealView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        let d = model.draft
        OnboardingPage(step: d.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    TitleText("\(d.myName) & \(d.partnerName)'s 75-day plan", size: 26)
                        .padding(.top, 8)
                    RingScene(left: SceneCharacter(characterID: d.characterID, name: d.myName),
                              right: nil, day: nil, caption: "Day 1\n→ 75")
                        .frame(height: 230)
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
                .font(.app(15, .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(alignment: .top, spacing: 14) {
                column(name: leftName, rules: leftRules, color: .coral, note: nil)
                Divider()
                column(name: rightName, rules: rightRules, color: .sage, note: rightNote)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func column(name: String, rules: [String], color: Color, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.app(14, .bold))
                .foregroundStyle(color)
            ForEach(Array(rules.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(color).frame(width: 6, height: 6).padding(.top, 6)
                    Text(r)
                        .font(.app(14))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let note {
                Text(note)
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "3 saves · Shared. Each one covers a missed day." or the Hard mode version.
struct SavesCard: View {
    var mode: RoundMode
    var savesLeft: Int? = nil

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .hard ? "No saves" : "\(Brand.savesPerRound) saves")
                    .font(.app(16, .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(mode == .hard ? "One miss restarts the round" : "Shared. Each one covers a missed day.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if mode != .hard {
                SaveSquares(left: savesLeft ?? Brand.savesPerRound, total: Brand.savesPerRound, size: 16)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.peach))
        .accessibilityElement(children: .combine)
    }
}

/// Small gold squares: filled = saves left.
struct SaveSquares: View {
    var left: Int
    var total: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: size * 0.35) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: size * 0.25)
                    .fill(i < left ? Color.gold : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: size * 0.25).stroke(Color.gold, lineWidth: 1.5))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(left) of \(total) saves left")
    }
}
