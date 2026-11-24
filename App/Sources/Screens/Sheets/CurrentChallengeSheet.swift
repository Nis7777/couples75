import SwiftUI

/// Challenges → tap the running (or starting-tomorrow) challenge: what it is, where you are, both of your daily
/// rules, misses, saves, the bet and the reward.
struct CurrentChallengeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onGiveUp: () -> Void

    private var active: Challenge? { model.activeChallenge }
    private var challenge: Challenge? { active ?? model.upcomingChallenge }
    private var isUpcoming: Bool { active == nil }

    /// The round the challenge is played in: the current one, or the next one when it starts tomorrow.
    private var roundNumber: Int {
        guard let r = model.currentRound else { return 1 }
        if isUpcoming, r.mode.isMaintenance { return r.number + 1 }
        return r.number
    }
    private var config: RoundConfigFact? { RulesEngine.config(for: roundNumber, facts: model.facts) }
    private var round: RoundState? { isUpcoming ? nil : model.currentRound }

    private var length: Int { round?.length ?? config?.length ?? challenge?.days ?? 0 }
    private var savesAllowed: Int { round?.savesAllowed ?? config?.saves ?? challenge?.saves ?? 0 }
    private var bet: String { round?.betText ?? config?.betText ?? "" }
    private var reward: String? { (round?.rewardText ?? config?.rewardText).flatMap { $0.isEmpty ? nil : $0 } }
    private var proofRequired: Bool { round?.proofRequired ?? config?.proofRequired ?? challenge?.proofRequired ?? false }
    private var day: Int { model.myToday?.dayNumber ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let c = challenge {
                    VStack(alignment: .leading, spacing: 16) {
                        header(c)
                        statsRow
                        if !isUpcoming {
                            DayProgressBar(day: day, total: length)
                                .padding(16)
                                .card(radius: 20, shadow: false)
                        }
                        if !isUpcoming, let r = round { missesCard(r) }
                        rulesCard
                        termsCard
                        Button(role: .destructive) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onGiveUp() }
                        } label: {
                            Text(isUpcoming ? "Cancel this challenge" : "Give up")
                                .font(.app(15, .semibold))
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                    }
                    .padding(.horizontal, Metrics.side)
                    .padding(.bottom, 24)
                } else {
                    Text("No challenge right now.")
                        .font(.app(16))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.top, 60)
                }
            }
            .background(Color.ivory.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    // MARK: Header

    private func header(_ c: Challenge) -> some View {
        HStack(alignment: .center, spacing: 14) {
            CustomIcon(asset: c.asset, symbol: c.icon, size: 56, circled: true)
            VStack(alignment: .leading, spacing: 3) {
                SmallLabel(text: isUpcoming ? "Starts tomorrow" : "In progress")
                Text(c.title)
                    .font(.app(26, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(c.tagline)
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat(isUpcoming ? "\(length)" : "\(day)/\(length)", isUpcoming ? "days" : "day")
            stat(savesAllowed == 0 ? "0" : isUpcoming ? "\(savesAllowed)" : "\(round?.savesLeft ?? 0)/\(savesAllowed)",
                 isUpcoming ? "saves" : "saves left")
            stat(endDate, "ends")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.app(19, .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.app(12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(radius: 16, shadow: false)
        .accessibilityElement(children: .combine)
    }

    /// The last day (pauses can push it later).
    private var endDate: String {
        let tz = model.me?.tz ?? .current
        let start: LocalDate
        if let s = round?.member(model.meID)?.startDate {
            start = s
        } else {
            start = LocalDate(Date(), in: tz).adding(1)
        }
        let end = start.adding(max(length - 1, 0)).startInstant(in: tz)
        return end.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: Misses

    private func missesCard(_ r: RoundState) -> some View {
        card("Misses so far", icon: "xmark.circle") {
            HStack(spacing: 10) {
                missChip(name: "You", misses: r.misses(model.meID))
                if let p = model.partner { missChip(name: p.name, misses: r.misses(p.id)) }
            }
            if !bet.isEmpty {
                Text("Whoever misses more at the end owes the bet.")
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func missChip(name: String, misses: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(misses)")
                .font(.app(22, .bold))
                .foregroundStyle(misses == 0 ? Color.sage : Color.coral)
            Text(name)
                .font(.app(13, .medium))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.ivory))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(misses) \(misses == 1 ? "miss" : "misses")")
    }

    // MARK: Rules

    private var rulesCard: some View {
        card("Every day", icon: "checklist") {
            memberRules(title: "You", id: model.meID)
            if let p = model.partner {
                Divider()
                memberRules(title: p.name, id: p.id)
            }
        }
    }

    @ViewBuilder
    private func memberRules(title: String, id: MemberID) -> some View {
        let rules = RulesEngine.effectiveRules(for: id, round: roundNumber, facts: model.facts, at: model.now())
            .sorted { $0.position < $1.position }
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.app(13, .semibold))
                .foregroundStyle(Color.textSecondary)
            if rules.isEmpty {
                Text("Set when the challenge starts.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
            }
            ForEach(rules) { rule in
                HStack(spacing: 10) {
                    Image(systemName: rule.type == .photo ? "camera.fill" : "hand.raised.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.coral)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.peach))
                    Text(rule.title)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color.textPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Terms

    private var termsCard: some View {
        card("The deal", icon: "doc.text") {
            row("camera", proofRequired ? "Photo proof required, no honour taps" : "Photo proof optional, but recommended")
            row("shield", savesAllowed == 0 ? "No saves: one miss ends it"
                : "\(savesAllowed) shared \(savesAllowed == 1 ? "save" : "saves") for missed days")
            row("trophy", bet.isEmpty ? "No bet" : "Bet: \(bet)")
            if let reward { row("gift", "Reward: \(reward)") }
        }
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.coral)
                .frame(width: 20)
            Text(text)
                .font(.app(15))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func card<Content: View>(_ title: String, icon: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.app(15, .bold))
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20, shadow: false)
    }
}
