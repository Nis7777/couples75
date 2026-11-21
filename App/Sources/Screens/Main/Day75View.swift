import SwiftUI
import UIKit

/// 19: Day 75. Confetti, recap, share card, start round 2.
struct Day75View: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    @State private var shareImage: UIImage?
    @State private var showNextRound = false

    var body: some View {
        ZStack {
            OnboardingPage(step: nil, back: nil) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        HStack {
                            Spacer()
                            CloseButton { model.dismissDay75() }
                        }
                        SmallLabel(text: "Day 75")
                        TitleText("We finished \(Brand.appName)", size: 32)
                        Text("\(model.nameA) & \(model.nameB)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                        TrophyScene(left: model.sceneA, right: model.sceneB)
                            .frame(height: 280)
                        RecapCard(round: round)
                    }
                }
            } actions: {
                if let shareImage {
                    ShareLink(item: Image(uiImage: shareImage),
                              preview: SharePreview("We finished \(Brand.appName)", image: Image(uiImage: shareImage))) {
                        Text("Share our card ›")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Capsule().fill(Color.coral))
                    }
                }
                SecondaryButton("Start round \(round.number + 1)") { showNextRound = true }
            }
            ConfettiView().ignoresSafeArea()
        }
        .screenBackground()
        .onAppear {
            Haptics.success()
            render()
        }
        .sheet(isPresented: $showNextRound) {
            StartNextRoundSheet(round: round)
        }
    }

    private func render() {
        let card = ShareCardView(nameA: model.nameA, nameB: model.nameB, a: model.sceneA, b: model.sceneB,
                                 bestStreak: model.state.bestStreak, savesUsed: round.savesUsed,
                                 owes: round.owes.isEmpty ? nil : round.betText)
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
            row("Saves used", round.mode == .hard ? "Hard mode" : "\(round.savesUsed) of \(round.savesAllowed)")
            Divider()
            row("Final score", "\(model.nameA) \(model.memberA.map { round.misses($0.id) } ?? 0) · \(model.nameB) \(model.memberB.map { round.misses($0.id) } ?? 0)")
            Divider()
            row("Best streak", "\(max(round.bestStreak, model.state.bestStreak)) days")
            Divider()
            row("Most sus moments", "\(round.susCount) 🤨")
            Divider()
            row("The bet", owesText)
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
            Text(label).font(.system(size: 15)).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
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

    var body: some View {
        VStack(spacing: 14) {
            Text("DAY 75")
                .font(.system(size: 16, weight: .heavy))
                .tracking(3)
                .foregroundStyle(Color.coral)
                .padding(.top, 40)
            Text("We finished \(Brand.appName)")
                .font(.rounded(34))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(nameA) & \(nameB)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            TrophyScene(left: a, right: b)
                .frame(height: 300)
            HStack(spacing: 24) {
                stat("\(bestStreak)", "best streak")
                stat("\(savesUsed)", "saves used")
            }
            if let owes {
                Text("🏆 \(owes)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Text(Brand.tagline)
                .font(.system(size: 13, weight: .medium))
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
            Text(label).font(.system(size: 12)).foregroundStyle(Color.textSecondary)
        }
    }
}

/// "Start round 2": reruns the wake-up and level steps, offers Hard mode.
struct StartNextRoundSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var round: RoundState
    @State private var step = 0
    @State private var wake = "07:30"
    @State private var level: Level = .couples75
    @State private var saving = false

    var body: some View {
        Group {
            if step == 0 {
                WakeTimePickerView(wakeTime: $wake, step: 1, total: 2, back: { dismiss() }) { step = 1 }
            } else {
                LevelPickerView(level: $level, step: 2, total: 2, back: { step = 0 },
                                buttonTitle: "Start round \(round.number + 1)") {
                    guard !saving else { return }
                    saving = true
                    Task {
                        await model.startNextRound(after: round, level: level, wakeTime: wake)
                        saving = false
                        dismiss()
                    }
                }
            }
        }
        .screenBackground()
        .onAppear {
            wake = model.me?.wakeTime ?? "07:30"
            level = round.mode == .hard ? .hard : .couples75
        }
    }
}
