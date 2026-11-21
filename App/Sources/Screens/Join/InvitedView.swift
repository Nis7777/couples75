import SwiftUI

/// 25: "{A} invited you".
struct InvitedView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    SmallLabel(text: "You're in")
                        .padding(.top, 8)
                    TitleText("\(model.nameA) invited you")
                    CharacterImage(characterID: model.sceneA.characterID, pose: .bust)
                        .padding(10)
                        .frame(width: 110, height: 110)
                        .background(Circle().fill(Color.peach))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.coral, lineWidth: 2))
                        .accessibilityLabel(model.nameA)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(model.nameA) picked this plan for you both")
                            .font(.app(15, .bold))
                            .foregroundStyle(Color.textPrimary)
                        RulesColumnsCard(title: "Daily rules",
                                         leftName: model.nameA,
                                         leftRules: model.memberA.map { model.rules(for: $0.id).map { $0.title } } ?? [],
                                         rightName: model.nameB,
                                         rightRules: model.draftRulesForB.map { $0.title },
                                         rightNote: nil)
                        HStack {
                            Text(model.currentMode == .hard ? "Hard mode · no saves" : "\(Brand.savesPerRound) saves, shared")
                                .font(.app(15, .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if model.currentMode != .hard {
                                SaveSquares(left: Brand.savesPerRound, total: Brand.savesPerRound, size: 14)
                            }
                        }
                        BetBox(bet: model.currentBet)
                    }
                    .padding(16)
                    .card()
                }
                .padding(.bottom, 8)
            }
        } actions: {
            PrimaryButton("See the plan") { next() }
            Text("You can swap one rule and change the bet. \(Brand.appName) is \(model.purchases.monthlyPrice ?? "…") a month each, so you'll subscribe before Day 1.")
                .font(.app(12))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "🏆 The bet" box.
struct BetBox: View {
    var bet: String

    var body: some View {
        HStack(spacing: 10) {
            Text("🏆").font(.app(22))
            VStack(alignment: .leading, spacing: 2) {
                Text("The bet")
                    .font(.app(12, .semibold))
                    .foregroundStyle(Color.textSecondary)
                Text(bet)
                    .font(.app(16, .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.peach))
        .accessibilityElement(children: .combine)
    }
}
