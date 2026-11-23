import SwiftUI
import UIKit

/// A challenge finished together (was "Day 75"): confetti, the badge reveal, recap, share card, then back to
/// daily habits or on to the next challenge.
struct Day75View: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    @State private var sharing = false
    @State private var leaving = false

    private var challenge: Challenge? {
        Challenges.challenge(round.challengeID) ?? (round.length == Challenges.the75.days ? Challenges.the75 : nil)
    }
    private var name: String { challenge?.title ?? "the challenge" }

    var body: some View {
        ZStack {
            OnboardingPage(step: nil, back: nil) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        HStack {
                            CloseButton { finish(openChallenges: false) }
                            Spacer()
                        }
                        .padding(.horizontal, -8)
                        Text("Day \(round.length) of \(round.length)")
                            .font(.app(18, .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("We finished \(name)")
                            .font(.app(42, .heavy))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-4)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(model.nameA) & \(model.nameB) · +\(challenge?.xpReward ?? round.length * 20) XP")
                            .font(.app(18, .semibold))
                            .foregroundStyle(Color.coral)
                            .padding(.bottom, 4)
                        BadgeReveal(size: 120) {
                            if let c = challenge {
                                CustomIcon(asset: c.asset, symbol: c.icon, size: 120, circled: true)
                            } else {
                                RankBadge(rank: model.xp.rank, size: 120)
                            }
                        }
                        TrophyScene(left: model.sceneA, right: model.sceneB, ribbon: false, badge: false)
                            .frame(height: 300)
                            .padding(.horizontal, -Metrics.side)
                        RecapCard(round: round)
                            .padding(.top, 8)
                        if round.owes.isEmpty {
                            RewardPickerCard(round: round)
                        }
                    }
                    .padding(.bottom, 8)
                }
            } actions: {
                PrimaryButton("Share our card") { sharing = true }
                SecondaryButton("Pick our next challenge") { finish(openChallenges: true) }
                TextLinkButton("Back to our daily habits", color: .coral) { finish(openChallenges: false) }
            }
            ConfettiView().ignoresSafeArea()
        }
        .screenBackground()
        .onAppear { Haptics.success() }
        .sheet(isPresented: $sharing) {
            MilestoneShareView(milestone: PactMilestone(kind: .challenge(round: round.number, title: name,
                                                                         days: round.length)),
                               celebrate: false)
        }
    }

    private func finish(openChallenges: Bool) {
        guard !leaving else { return }
        leaving = true
        Task {
            await model.returnToHabits(after: round)
            model.dismissDay75()
            if openChallenges { model.tab = .challenges }
        }
    }
}

struct RecapCard: View {
    @Environment(AppModel.self) private var model
    var round: RoundState

    var body: some View {
        VStack(spacing: 10) {
            row("Saves used", round.savesAllowed == 0 ? "No saves" : "\(round.savesUsed) of \(round.savesAllowed)")
            Divider()
            row("Final score", "\(model.nameA) \(model.memberA.map { round.misses($0.id) } ?? 0) · \(model.nameB) \(model.memberB.map { round.misses($0.id) } ?? 0)")
            Divider()
            row("Best streak", "\(max(round.bestStreak, model.state.bestStreak)) days")
            Divider()
            row("Most sus moments", "\(round.susCount) 🤨")
            if !round.betText.isEmpty {
                Divider()
                row("The bet", owesText)
            }
        }
        .padding(16)
        .card()
    }

    private var owesText: String {
        if round.owes.count == 2 { return "You both owe: \(round.betText)" }
        if let id = round.owes.first { return "\(model.name(of: id)) owes: \(round.betText)" }
        return "Nobody owes anything"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.app(15)).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
