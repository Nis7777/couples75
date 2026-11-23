import SwiftUI

/// "Your couple score today", then (tap) "Your couple score in 90 days": the level and rank count up over 1.5 s with
/// light haptic ticks, and the couple map (six axes per partner, from each partner's own habits, see
/// `CoupleMapScoring`) grows from today's shape to the 90-day one. The 90-day rank is what 90 perfect days really
/// earn with the app's XP rules. Labelled as a projection. A partner who hasn't answered shows as a dashed outline.
struct CoupleScoreView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var projected = false
    @State private var finished = false
    @State private var tickTask: Task<Void, Never>?
    @State private var appeared = false
    @State private var showValues = false

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
            mapCard(p: p)
            Text("Projected if you both check in daily.")
                .font(.app(13))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func mapCard(p: Double) -> some View {
        let d = model.draft
        let map = model.coupleMap
        let today = map.series(.dayOne)
        let later = map.projectedSeries(keysA: d.planRules.map { $0.a.libraryKey ?? "custom" },
                                        keysB: d.partnerPlan?.map { $0.libraryKey ?? "custom" })
        return VStack(spacing: 10) {
            Text("Your couple map")
                .font(.app(17, .bold))
                .foregroundStyle(Color.textPrimary)
            OneShotClock(duration: 900, play: appeared) { t in
                CoupleMapChart(series: blendMap(today, later, p), size: 280, draw: seg(t, 0, 900), showValues: showValues)
            }
            .frame(width: 280, height: 280)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                withAnimation(.open(0.25)) { showValues.toggle() }
            }
            .accessibilityAddTraits(.isButton)
            CoupleMapLegend(series: today)
            Text(showValues ? "Based on your answers · tap to hide the numbers" : "Based on your answers · tap for the numbers")
                .font(.app(12))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .card(radius: 20, shadow: false)
        .onAppear { appeared = true }
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
