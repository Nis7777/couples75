import SwiftUI
import UIKit

/// Challenges tab: your rank, the running challenge (or the one starting tomorrow), The 75 as the signature
/// card, then short challenges for Body, Looks and Mind & money. Tap one for its details and to start it.
struct ChallengesScreen: View {
    @Environment(AppModel.self) private var model
    @State private var opened: Challenge?
    @State private var confirmGiveUp = false
    @State private var creating = false
    @State private var showingCurrent = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Challenges")
                    .font(.app(30, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 10)
                XPCard(xp: model.xp)
                current
                createOwnCard
                Text("Signature")
                    .font(.app(19, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 4)
                SignatureCard(challenge: Challenges.the75) { opened = Challenges.the75 }
                ForEach(Area.allCases) { area in
                    section(area)
                }
                Text("Challenges start the next morning. Your daily habits keep counting today, and come back when the challenge ends.")
                    .font(.app(13))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $creating) {
            CustomChallengeSheet { c in
                creating = false
                // Then the usual details (bet, Start tomorrow), once this sheet has gone.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { opened = c }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingCurrent) {
            CurrentChallengeSheet(onGiveUp: { confirmGiveUp = true })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $opened) { c in
            ChallengeDetailSheet(challenge: c)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .confirmationDialog(giveUpTitle, isPresented: $confirmGiveUp, titleVisibility: .visible) {
            Button(giveUpButton, role: .destructive) { Task { await model.giveUpChallenge() } }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text(giveUpMessage)
        }
    }

    // MARK: Create your own

    private var createOwnCard: some View {
        Button {
            // Never a dead button: if a challenge can't start yet, say why.
            if let reason = model.challengeBlockedReason {
                Haptics.warning()
                model.toast = reason
                return
            }
            Haptics.tap()
            creating = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.gold)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.peach))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create your own")
                        .font(.app(17, .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Your name, your length, your rules")
                        .font(.app(13))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(14)
            .card(radius: 18, shadow: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .opacity(model.canStartChallenge ? 1 : 0.5)
        .accessibilityHint("Make a challenge with your own name, length and rules")
    }

    // MARK: Current

    @ViewBuilder
    private var current: some View {
        if let c = model.activeChallenge, let r = model.currentRound {
            let day = model.myToday?.dayNumber ?? 0
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    CustomIcon(asset: c.asset, symbol: c.icon, size: 46, circled: true)
                    VStack(alignment: .leading, spacing: 2) {
                        SmallLabel(text: "In progress")
                        Text(c.title).font(.app(20, .bold)).foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                DayProgressBar(day: day, total: r.length)
                HStack(spacing: 8) {
                    Pill(text: r.savesAllowed == 0 ? "No saves" : "\(r.savesLeft) of \(r.savesAllowed) saves left",
                         fill: .peach, foreground: .coral)
                    if !r.betText.isEmpty { Pill(text: "Bet: \(r.betText)", fill: .gold.opacity(0.35), foreground: .textPrimary) }
                    Spacer(minLength: 0)
                }
                TextLinkButton("Give up", color: .textSecondary) { confirmGiveUp = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .card(radius: 20)
            .contentShape(Rectangle())
            .onTapGesture { openCurrent() }
            .accessibilityAction(named: "Details") { openCurrent() }
        } else if let c = model.upcomingChallenge {
            HStack(spacing: 12) {
                CustomIcon(asset: c.asset, symbol: c.icon, size: 46, circled: true)
                VStack(alignment: .leading, spacing: 2) {
                    SmallLabel(text: "Starts tomorrow")
                    Text(c.title).font(.app(18, .bold)).foregroundStyle(Color.textPrimary)
                }
                Spacer()
                Button("Cancel") { confirmGiveUp = true }
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.coral)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(16)
            .peachBox(radius: 20)
            .contentShape(Rectangle())
            .onTapGesture { openCurrent() }
            .accessibilityAction(named: "Details") { openCurrent() }
        } else {
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill").foregroundStyle(Color.sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text("On daily habits").font(.app(16, .semibold)).foregroundStyle(Color.textPrimary)
                    Text("No stakes. Pick a challenge when you want a push.")
                        .font(.app(13)).foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .card(radius: 18, shadow: false)
        }
    }

    private func openCurrent() {
        Haptics.tap()
        showingCurrent = true
    }

    private var isUpcoming: Bool { model.activeChallenge == nil && model.upcomingChallenge != nil }
    private var giveUpTitle: String { isUpcoming ? "Cancel this challenge?" : "Give up the challenge?" }
    private var giveUpButton: String { isUpcoming ? "Cancel challenge" : "Give up" }
    private var giveUpMessage: String {
        if isUpcoming { return "It hasn't started yet, so nothing is lost." }
        let bet = model.currentRound?.betText ?? ""
        return bet.isEmpty ? "You'll both go back to your daily habits tomorrow. Your streak and XP are kept."
                           : "Giving up loses the bet: you'll owe “\(bet)”. Back to your daily habits tomorrow."
    }

    // MARK: Sections

    private func section(_ area: Area) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CustomIcon(asset: area.asset, symbol: area.icon, size: 26)
                Text(area.title).font(.app(19, .bold)).foregroundStyle(Color.textPrimary)
                Text(area.subtitle).font(.app(13)).foregroundStyle(Color.textSecondary)
            }
            .padding(.top, 6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Challenges.inArea(area)) { c in
                        ChallengeTile(challenge: c, done: model.timesCompleted(c)) { opened = c }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, Metrics.side)
            }
            .padding(.horizontal, -Metrics.side)
        }
    }
}

/// The 75: a big peach card with the flame.
struct SignatureCard: View {
    var challenge: Challenge
    var open: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            open()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.title)
                        .font(.app(28, .heavy))
                        .foregroundStyle(Color.textPrimary)
                    Text(challenge.tagline)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Pill(text: "75 days", fill: .coral)
                        Pill(text: "Photo proof", fill: .white, foreground: .coral)
                        Pill(text: "Bet", fill: .white, foreground: .coral)
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
                if UIImage(named: challenge.asset) != nil {
                    Image(challenge.asset).resizable().scaledToFit().frame(width: 84, height: 84)
                } else {
                    LivingFlame(size: 70)
                }
            }
            .padding(18)
            .peachBox(radius: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(challenge.title). \(challenge.tagline). 75 days, photo proof and a bet.")
    }
}

struct ChallengeTile: View {
    var challenge: Challenge
    var done: Int
    var open: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            open()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CustomIcon(asset: challenge.asset, symbol: challenge.icon, size: 40, circled: true)
                    Spacer()
                    if done > 0 {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.sage)
                            .accessibilityLabel("Done \(done) time\(done == 1 ? "" : "s")")
                    }
                }
                Text(challenge.title)
                    .font(.app(16, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(challenge.tagline)
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\(challenge.lengthText) · +\(challenge.xpReward) XP")
                    .font(.app(12, .semibold))
                    .foregroundStyle(Color.coral)
            }
            .padding(14)
            .frame(width: 168, height: 186, alignment: .topLeading)
            .card(radius: 20, shadow: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Details and start: rules, length, saves, proof, and the stakes (optional, required for The 75).
struct ChallengeDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var challenge: Challenge
    @State private var withBet = false
    @State private var bet: BetOption = .date
    @State private var customBet = ""
    @State private var reward = ""
    @State private var saving = false

    private var betText: String {
        guard withBet || challenge.stakesRequired else { return "" }
        return bet == .custom ? customBet : bet.title
    }

    private var canStart: Bool {
        model.canStartChallenge && (!challenge.stakesRequired || !betText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 14) {
                        CustomIcon(asset: challenge.asset, symbol: challenge.icon, size: 64, circled: true)
                        VStack(alignment: .leading, spacing: 3) {
                            if let area = challenge.area { SmallLabel(text: area.title) }
                            else { SmallLabel(text: challenge.isCustom ? "Your own" : "Signature") }
                            Text(challenge.title).font(.app(26, .bold)).foregroundStyle(Color.textPrimary)
                        }
                    }
                    .padding(.top, 26)
                    .padding(.trailing, 36)   // room for the ×
                    Text(challenge.tagline).font(.app(16)).foregroundStyle(Color.textSecondary)
                    HStack(spacing: 10) {
                        stat(challenge.lengthText, "length")
                        stat(challenge.saves == 0 ? "0" : "\(challenge.saves)", "shared saves")
                        stat("+\(challenge.xpReward)", "XP")
                    }
                    rules
                    proofRow
                    safetyRow
                    stakes
                    if !model.canStartChallenge { blockedNote }
                }
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, 16)
            }
            BottomActions {
                PrimaryButton("Start tomorrow", isEnabled: canStart, isLoading: saving) {
                    Task {
                        saving = true
                        await model.startChallenge(challenge, bet: betText, reward: reward.isEmpty ? nil : reward)
                        saving = false
                        dismiss()
                    }
                }
            }
        }
        .background(Color.ivory.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            // A visible way out (the sheet also closes with a swipe down).
            CloseButton { dismiss() }
                .padding(.top, 6)
                .padding(.trailing, 8)
        }
        .onAppear { withBet = challenge.stakesRequired }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.app(20, .bold)).foregroundStyle(Color.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.app(12)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(radius: 16, shadow: false)
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(challenge.replacesHabits ? "Every day, instead of your habits" : "Every day, on top of your habits")
                .font(.app(17, .bold))
                .foregroundStyle(Color.textPrimary)
            ForEach(challenge.ruleIdeas()) { idea in
                HStack(spacing: 10) {
                    Image(systemName: idea.type == .photo ? "camera.fill" : "hand.raised.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.coral)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.peach))
                    Text(idea.title).font(.app(16, .medium)).foregroundStyle(Color.textPrimary)
                    Spacer()
                }
            }
            if !challenge.replacesHabits {
                Text("Workout, steps and water follow each of your levels.")
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .card(radius: 18, shadow: false)
    }

    private var proofRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: challenge.proofRequired ? "camera.badge.ellipsis" : "camera")
                .foregroundStyle(Color.coral)
            Text(challenge.proofRequired
                 ? "Photo proof is required. Every photo rule needs a photo taken in the app, no honour taps."
                 : "Photo proof is optional but recommended. Your partner sees it and can cheer.")
                .font(.app(14))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Guideline 1.4.1: demanding challenges (two workouts, 4 L of water) carry a short safety note.
    private var safetyRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square")
                .foregroundStyle(Color.coral)
            Text("Not medical advice. Check with a doctor before a demanding challenge, especially with a health condition or during pregnancy. Spread water over the day, and stop if you feel pain or unwell: pausing is always fine.")
                .font(.app(14))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var stakes: some View {
        VStack(alignment: .leading, spacing: 10) {
            if challenge.stakesRequired {
                Text("The bet").font(.app(17, .bold)).foregroundStyle(Color.textPrimary)
                Text("Part of The 75. Whoever misses more owes it. Giving up loses it.")
                    .font(.app(13)).foregroundStyle(Color.textSecondary)
            } else {
                Toggle(isOn: $withBet.animation(.open(0.25))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a bet").font(.app(17, .bold)).foregroundStyle(Color.textPrimary)
                        Text("Optional. Whoever misses more owes it.").font(.app(13)).foregroundStyle(Color.textSecondary)
                    }
                }
                .tint(Color.coral)
            }
            if withBet || challenge.stakesRequired {
                ForEach(BetOption.allCases) { o in
                    Button {
                        Haptics.tap()
                        bet = o
                    } label: {
                        HStack(spacing: 10) {
                            CheckCircle(isOn: bet == o, size: 22)
                            Text(o.title).font(.app(15, .medium)).foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .card(radius: 14, shadow: false)
                    }
                    .buttonStyle(PressableStyle())
                }
                if bet == .custom {
                    TextField("Loser…", text: $customBet)
                        .font(.app(16))
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .card(radius: 14, shadow: false)
                        .onChange(of: customBet) { _, v in
                            if v.count > BetOption.customMaxLength { customBet = String(v.prefix(BetOption.customMaxLength)) }
                        }
                }
            }
            TextField("Reward if you both nail it (optional)", text: $reward)
                .font(.app(15))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .card(radius: 14, shadow: false)
        }
        .padding(16)
        .card(radius: 18, shadow: false)
    }

    private var blockedNote: some View {
        Text(blockedReason)
            .font(.app(13, .semibold))
            .foregroundStyle(Color.coral)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var blockedReason: String { model.challengeBlockedReason ?? "" }
}
