import SwiftUI
import UIKit

/// A challenge finished together (was "Day 75"): confetti, the badge reveal, recap, share card, then back to
/// daily habits or on to the next challenge.
struct Day75View: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    @State private var shareImage: UIImage?
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
                                CustomIcon(asset: c.asset, symbol: c.icon, size: 120)
                                    .background(Circle().fill(Color.peach))
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
                if let shareImage {
                    ShareLink(item: Image(uiImage: shareImage),
                              preview: SharePreview("We finished \(name)", image: Image(uiImage: shareImage))) {
                        PrimaryButtonLabel(title: "Share our card")
                    }
                }
                SecondaryButton("Pick our next challenge") { finish(openChallenges: true) }
                TextLinkButton("Back to our daily habits", color: .coral) { finish(openChallenges: false) }
            }
            ConfettiView().ignoresSafeArea()
        }
        .screenBackground()
        .onAppear {
            Haptics.success()
            render()
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

    private func render() {
        let card = ShareCardView(nameA: model.nameA, nameB: model.nameB, a: model.sceneA, b: model.sceneB,
                                 bestStreak: model.state.bestStreak, savesUsed: round.savesUsed,
                                 owes: round.owes.isEmpty ? nil : round.betText,
                                 headline: "DAY \(round.length)", title: "We finished \(name)")
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        shareImage = renderer.uiImage
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

/// 1080×1920 share card (rendered at 3× from 360×640). Never contains photos.
struct ShareCardView: View {
    var nameA: String
    var nameB: String
    var a: SceneCharacter
    var b: SceneCharacter?
    var bestStreak: Int
    var savesUsed: Int
    var owes: String?
    var headline = "DAY 75"
    var title = "We finished The 75"

    var body: some View {
        VStack(spacing: 14) {
            Text(headline)
                .font(.app(16, .heavy))
                .tracking(3)
                .foregroundStyle(Color.coral)
                .padding(.top, 40)
            Text(title)
                .font(.app(36, .heavy))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(nameA) & \(nameB)")
                .font(.app(18, .semibold))
                .foregroundStyle(Color.textSecondary)
            TrophyScene(left: a, right: b, ribbon: false, badge: false)
                .frame(height: 320)
            HStack(spacing: 24) {
                stat("\(bestStreak)", "best streak")
                stat("\(savesUsed)", "saves used")
            }
            if let owes {
                Text("🏆 \(owes)")
                    .font(.app(15, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Text(Brand.tagline)
                .font(.app(13, .medium))
                .foregroundStyle(Color.textSecondary)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .frame(width: 360, height: 640)
        .background(Color.ivory)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.rounded(28)).foregroundStyle(Color.gold)
            Text(label).font(.app(12)).foregroundStyle(Color.textSecondary)
        }
    }
}
