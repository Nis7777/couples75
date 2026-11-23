import SwiftUI

/// 25: "{A} invited you": A's bust in a big circle with a soft peach ring, the plan card with the bet box inside.
struct InvitedView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    private var aRules: [String] { model.memberA.map { model.rules(for: $0.id).map { $0.title } } ?? [] }
    private var bRules: [String] { model.draftRulesForB.map { $0.title } }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    SmallLabel(text: "You're in")
                        .padding(.top, 18)
                    TitleText("\(model.nameA) invited you", size: 30)
                    BustCircle(avatar: model.sceneA.avatar, size: 150, ring: Color.peachDeep,
                               ringWidth: 6, fill: Color.peach.opacity(0.6))
                        .padding(.vertical, 8)
                        .accessibilityLabel(model.nameA)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(model.nameA) picked these daily habits for you both")
                            .font(.app(15, .medium))
                            .foregroundStyle(Color.textSecondary)
                        HStack(alignment: .top, spacing: 14) {
                            ruleColumn(model.nameA, aRules, .coral)
                            ruleColumn(model.nameB, bRules, .sage)
                        }
                        HStack(spacing: 10) {
                            Circle().fill(Color.gold).frame(width: 8, height: 8)
                            Text("No stakes on habits. Challenges and bets come when you want them.")
                                .font(.app(15, .medium))
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        if !model.currentBet.isEmpty { BetBox(bet: model.currentBet) }
                    }
                    .padding(18)
                    .card()
                }
                .padding(.bottom, 8)
            }
        } actions: {
            PrimaryButton("See the plan") { next() }
            Text("You can swap one habit. Free for you: \(model.nameA)'s subscription covers you both.")
                .font(.app(13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
        }
    }

    private func ruleColumn(_ name: String, _ rules: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(name).font(.app(15, .bold)).foregroundStyle(color)
            ForEach(Array(rules.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Color.gold).frame(width: 7, height: 7)
                    Text(r)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The bet box: peach, thin coral border, gold trophy icon.
struct BetBox: View {
    var bet: String
    var title = "The bet"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.gold)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.app(14, .medium))
                    .foregroundStyle(Color.textSecondary)
                Text(bet)
                    .font(.app(19, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .peachBox(radius: 16)
        .accessibilityElement(children: .combine)
    }
}
