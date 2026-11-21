import SwiftUI

/// 24: round end (failed, or completed with someone owing the bet).
struct RoundEndView: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    var onDone: () -> Void
    @State private var paying = false

    private var live: RoundState { model.state.rounds.first { $0.number == round.number } ?? round }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    SmallLabel(text: live.status == .completed ? "Day 75" : "Round over")
                        .padding(.top, 12)
                    TitleText(live.status == .completed ? "You finished the round"
                                                        : "Out of saves on Day \(live.failedOnDay ?? 0)")
                    CoupleScene(left: model.sceneA, right: model.sceneB,
                                leftPose: live.status == .completed ? .cheer : .crossed,
                                rightPose: live.status == .completed ? .cheer : .crossed)
                        .frame(height: 240)
                    BetCard(round: live)
                    if live.status == .failed {
                        Text("Back to Day 1 tomorrow. Best streak: \(model.state.bestStreak) days. Your history is kept.")
                            .font(.app(14))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } actions: {
            if !live.owes.isEmpty && live.paidAt == nil {
                PrimaryButton("Paid", isLoading: paying) {
                    Task {
                        paying = true
                        await model.markPaid(live)
                        paying = false
                        Haptics.success()
                    }
                }
            } else if live.paidAt != nil {
                Label("Bet paid", systemImage: "checkmark.seal.fill")
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.sage)
                    .frame(height: 44)
            }
            TextLinkButton(live.status == .failed ? "Start round \(live.number + 1)" : "Back to today", color: .coral) {
                onDone()
            }
        }
        .screenBackground()
    }
}

/// "🏆 The bet" card with who owes and the final score.
struct BetCard: View {
    @Environment(AppModel.self) private var model
    var round: RoundState

    private var owesLine: String? {
        if round.owes.count == 2 { return "You both owe:" }
        if let id = round.owes.first { return id == model.meID ? "You owe:" : "\(model.name(of: id)) owes:" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🏆 The bet")
                .font(.app(14, .bold))
                .foregroundStyle(Color.textSecondary)
            if let owesLine {
                Text(owesLine)
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(round.betText)
                    .font(.app(26, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(round.rewardUnlocked ? "Nobody owes anything. Your reward is unlocked: \(round.rewardText ?? "")"
                                          : "Nobody owes anything")
                    .font(.app(20, .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            Text("Final score: \(scoreText)")
                .font(.app(14))
                .foregroundStyle(Color.textSecondary)
            if let paid = round.paidAt {
                Text("Paid \(paid.formatted(date: .abbreviated, time: .omitted))")
                    .font(.app(13, .semibold))
                    .foregroundStyle(Color.sage)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.peach))
        .accessibilityElement(children: .combine)
    }

    private var scoreText: String {
        let a = model.memberA.map { round.misses($0.id) } ?? 0
        let b = model.memberB.map { round.misses($0.id) } ?? 0
        return "\(model.nameA) \(a) · \(model.nameB) \(b)"
    }
}
