import SwiftUI

/// 24: round end (failed, or completed with someone owing the bet).
struct RoundEndView: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    var onDone: () -> Void
    @State private var paying = false

    private var live: RoundState { model.state.rounds.first { $0.number == round.number } ?? round }
    private var name: String { Challenges.challenge(live.challengeID)?.title ?? "The challenge" }
    /// Someone gave up (the habits config after it says who).
    private var quitter: MemberID? {
        model.facts.roundConfigs.first { $0.fromRound == live.number + 1 && $0.quitBy != nil && $0.createdAt == live.endedAt }?.quitBy
    }
    private var headline: String {
        if live.status == .completed { return "You finished \(name)" }
        if let q = quitter { return q == model.meID ? "You gave up on Day \(live.failedOnDay ?? 0)" : "\(model.name(of: q)) gave up on Day \(live.failedOnDay ?? 0)" }
        return "Out of saves on Day \(live.failedOnDay ?? 0)"
    }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    CoupleScene(left: model.sceneA, right: model.sceneB,
                                leftPose: live.status == .completed ? .cheer : .stand,
                                rightPose: live.status == .completed ? .cheer : .crossed,
                                crop: 0.56, overlap: 0.02)
                        .frame(height: 270)
                        .padding(.horizontal, -8)
                        .padding(.top, 20)
                    SmallLabel(text: live.status == .completed ? "Day \(live.length)" : "\(name) is over")
                    TitleText(headline, size: 28)
                    if live.betText.isEmpty {
                        BodyText("Back to your daily habits tomorrow. Best streak: \(model.state.bestStreak) days. Your XP and history are kept. Try it again whenever you're ready.")
                            .padding(.top, 10)
                    } else {
                        BetCard(round: live, footer: live.status == .failed
                                ? "Back to your daily habits tomorrow. Best streak: \(model.state.bestStreak) days. Your XP is kept."
                                : nil)
                            .padding(.top, 14)
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
            TextLinkButton("Back to today", color: .coral) {
                Task {
                    await model.returnToHabits(after: live)
                    onDone()
                }
            }
        }
        .screenBackground()
    }
}

/// "🏆 The bet" card with who owes and the final score.
struct BetCard: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    var footer: String? = nil

    private var owesLine: String? {
        if round.owes.count == 2 { return "You both owe:" }
        if let id = round.owes.first { return id == model.meID ? "You owe:" : "\(model.name(of: id)) owes:" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.gold)
                Text("The bet")
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            if let owesLine {
                Text(owesLine)
                    .font(.app(17, .medium))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 4)
                Text(round.betText)
                    .font(.app(26, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(round.rewardUnlocked ? "Nobody owes anything. Your reward is unlocked: \(round.rewardText ?? "")"
                                          : "Nobody owes anything")
                    .font(.app(22, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 4)
            }
            Text("Final score: \(scoreText)")
                .font(.app(15))
                .foregroundStyle(Color.textSecondary)
            if let footer {
                Text(footer)
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let paid = round.paidAt {
                Text("Paid \(paid.formatted(date: .abbreviated, time: .omitted))")
                    .font(.app(14, .semibold))
                    .foregroundStyle(Color.sage)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }

    private var scoreText: String {
        let a = model.memberA.map { round.misses($0.id) } ?? 0
        let b = model.memberB.map { round.misses($0.id) } ?? 0
        return "\(model.nameA) \(a) · \(model.nameB) \(b)"
    }
}
