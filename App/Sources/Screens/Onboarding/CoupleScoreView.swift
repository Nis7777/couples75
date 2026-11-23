import SwiftUI

/// "Your couple score today", then (tap) "Your couple score in 90 days": the level, rank and five stats count up
/// over 1.5 s with light haptic ticks. Numbers come from `CoupleScore` (their answers, deterministic); the 90-day
/// rank is what 90 perfect days really earn with the app's XP rules. Labelled as a projection.
struct CoupleScoreView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var projected = false
    @State private var finished = false
    @State private var tickTask: Task<Void, Never>?

    private static let duration: Double = 1500

    private var score: CoupleScore {
        let d = model.draft
        return CoupleScore.make(goals: d.goals + (d.partnerGoals ?? []).filter { !d.goals.contains($0) },
                                quitFrequency: d.quitFrequency, names: d.myName + d.partnerName,
                                rulesPerPerson: max(d.planRules.count, Brand.minRules))
    }

    var body: some View {
        let s = score
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                OneShotClock(duration: Self.duration, play: projected) { t in
                    let p = seg(t, 0, Self.duration)
                    content(s, p: p)
                }
                .padding(.bottom, 12)
            }
        } actions: {
            PrimaryButton(finished ? "Continue" : "See your score in 90 days", isEnabled: !projected || finished) {
                if finished { next() } else { project() }
            }
        }
        .onDisappear { tickTask?.cancel() }
    }

    private func content(_ s: CoupleScore, p: Double) -> some View {
        let level = 1 + Int((Double(s.laterRank.level - 1) * p).rounded())
        let rank = Ranks.all[min(max(level - 1, 0), Ranks.all.count - 1)]
        return VStack(spacing: 14) {
            Text(projected ? "Your couple score in 90 days" : "Your couple score today")
                .font(.app(28, .bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.open(0.3), value: projected)
                .padding(.top, 16)
            CoupleBusts(left: model.draftScene, right: model.sceneBBuilt)
                .frame(height: 120)
            HStack(spacing: 14) {
                RankBadge(rank: rank, size: 64)
                    .id(rank.id)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .animation(.open(0.25), value: rank.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(level)")
                        .font(.app(34, .heavy))
                        .foregroundStyle(Color.textPrimary)
                        .monospacedDigit()
                    Text(rank.title)
                        .font(.app(18, .semibold))
                        .foregroundStyle(Color.coral)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .peachBox(radius: 20)
            VStack(spacing: 12) {
                ForEach(CoupleStat.allCases) { stat in
                    let from = Double(s.today[stat] ?? 0)
                    let to = Double(s.later[stat] ?? 0)
                    statRow(stat, value: from + (to - from) * p)
                }
            }
            .padding(16)
            .card(radius: 20, shadow: false)
            Text("Projected if you both check in daily.")
                .font(.app(13))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func statRow(_ stat: CoupleStat, value: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: stat.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.coral)
                .frame(width: 22)
            Text(stat.title)
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 104, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: 0xE6D7B8), Color.gold], startPoint: .leading,
                                             endPoint: .trailing))
                        .frame(width: geo.size.width * value / 100)
                }
            }
            .frame(height: 8)
            Text("\(Int(value.rounded()))")
                .font(.app(15, .bold))
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title) \(Int(value.rounded())) out of 100")
    }

    private func project() {
        guard !projected else { return }
        projected = true
        // Haptic ticks while the numbers count up, then a success tap; the button turns into Continue.
        tickTask = Task { @MainActor in
            for _ in 0..<7 {
                Haptics.light()
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return }
            }
            Haptics.success()
            withAnimation(.open(0.25)) { finished = true }
        }
    }
}
