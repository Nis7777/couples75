import SwiftUI
import UIKit

/// 19: Day 75. Confetti, recap, share card, start round 2.
struct Day75View: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    @State private var shareImage: UIImage?
    @State private var showNextRound = false
    @State private var showMaintenance = false

    var body: some View {
        ZStack {
            OnboardingPage(step: nil, back: nil) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        HStack {
                            CloseButton { model.dismissDay75() }
                            Spacer()
                        }
                        .padding(.horizontal, -8)
                        Text("Day 75")
                            .font(.app(18, .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("We finished \(Brand.appName)")
                            .font(.app(46, .heavy))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-4)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(model.nameA) & \(model.nameB)")
                            .font(.app(20, .medium))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.bottom, 4)
                        TrophyScene(left: model.sceneA, right: model.sceneB, ribbon: false, badge: false)
                            .frame(height: 380)
                            .padding(.horizontal, -Metrics.side)
                        RecapCard(round: round)
                            .padding(.top, 8)
                    }
                    .padding(.bottom, 8)
                }
            } actions: {
                if let shareImage {
                    ShareLink(item: Image(uiImage: shareImage),
                              preview: SharePreview("We finished \(Brand.appName)", image: Image(uiImage: shareImage))) {
                        PrimaryButtonLabel(title: "Share our card")
                    }
                }
                SecondaryButton("Start round \(round.number + 1)") { showNextRound = true }
                TextLinkButton("Keep it up with maintenance mode", color: .coral) { showMaintenance = true }
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
        .sheet(isPresented: $showMaintenance) {
            MaintenanceSheet(round: round)
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

    var body: some View {
        VStack(spacing: 14) {
            Text("DAY 75")
                .font(.app(16, .heavy))
                .tracking(3)
                .foregroundStyle(Color.coral)
                .padding(.top, 40)
            Text("We finished \(Brand.appName)")
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
                LevelPickerView(level: $level, left: model.sceneA, right: model.sceneB, step: 2, total: 2,
                                back: { step = 0 },
                                buttonTitle: "Start round \(round.number + 1)", autoAdvances: false) {
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

/// After Day 75: pick the rules to keep. No saves, no bet, no end date.
struct MaintenanceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var round: RoundState
    @State private var keep: Set<String> = []
    @State private var saving = false

    var body: some View {
        let rules = model.rules(for: model.meID)
        VStack(alignment: .leading, spacing: 14) {
            TitleText("Maintenance mode", size: 28)
                .padding(.top, 26)
            BodyText("Keep the habits that stuck. No saves, no bet, no end date. Start a new 75 whenever you like.",
                     alignment: .leading)
            Text("Rules to keep").font(.app(17, .bold)).foregroundStyle(Color.textPrimary)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(rules) { r in
                        Button {
                            if keep.contains(r.id) { keep.remove(r.id) } else { keep.insert(r.id) }
                        } label: {
                            HStack(spacing: 12) {
                                CheckCircle(isOn: keep.contains(r.id), size: 24)
                                Text(r.title).font(.app(16, .medium)).foregroundStyle(Color.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .card(radius: 16, shadow: false)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            PrimaryButton("Start maintenance", isEnabled: !keep.isEmpty, isLoading: saving) {
                Task {
                    saving = true
                    await model.startMaintenance(after: round, keepRuleIDs: keep)
                    saving = false
                    dismiss()
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, Metrics.side)
        .background(Color.ivory.ignoresSafeArea())
        .onAppear { keep = Set(rules.map(\.id)) }
    }
}
