import SwiftUI

/// 15: Today. Name + gold streak pill; peach hero with the gold ring, both characters, the speech bubble and
/// the Done / x left chips; week dots; saves row; two rule cards side by side; Check in; stakes row.
/// The warm-up (28) uses the same layout with the warm-up banner, a "Warm-up" pill and "Practise check-in ›".
struct TodayView: View {
    @Environment(AppModel.self) private var model
    var warmup = false
    /// Back to the Waiting screen (warm-up started from there).
    var onBack: (() -> Void)? = nil
    @State private var cameraRule: RuleFact?
    @State private var honourRule: RuleFact?
    @State private var openedCheckIn: CheckInFact?
    @State private var showPauseRequest = false
    @State private var showPauseAnswer = false
    @State private var showTweakAnswer = false
    @State private var showDebug = false

    private var round: RoundState? { model.currentRound }
    private var hour: Int {
        _ = model.clockTick
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = model.me?.tz ?? .current
        return cal.component(.hour, from: model.now())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header
                banners
                hero
                WeekDotsView(days: weekDays, streak: model.state.streak)
                savesRow
                newFromPartnerRow
                rulesSection
                checkInButton
                stakesRow
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $cameraRule) { r in CheckInCameraView(rule: r) }
        .sheet(item: $honourRule) { r in HonourSheet(rule: r).presentationDetents([.height(430)]) }
        .sheet(item: $openedCheckIn) { c in PartnerCheckInView(checkIn: c) }
        .sheet(isPresented: $showPauseRequest) { PauseRequestView() }
        .sheet(isPresented: $showPauseAnswer) {
            if let p = model.pauseForMeToAnswer { PauseAnswerView(info: p) }
        }
        .sheet(isPresented: $showTweakAnswer) {
            if let t = model.tweakForMeToAnswer { TweakAnswerView(info: t) }
        }
        .sheet(isPresented: $showDebug) { DebugMenuView() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 28, height: 38)
                }
                .accessibilityLabel("Back")
            }
            Text("\(model.nameA) & \(model.nameB)")
                .font(.app(30, .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .onTapGesture(count: 3) {
                    if AppEnvironment.isDebug { showDebug = true }
                }
            Spacer()
            if warmup {
                Text("Warm-up")
                    .font(.app(14, .semibold))
                    .foregroundStyle(Color.coral)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(Capsule().fill(Color.peach))
            } else {
                StreakPill(streak: model.state.streak)
            }
            if !warmup { menu }
        }
        .padding(.top, 10)
    }

    private var menu: some View {
            Menu {
                Button {
                    showPauseRequest = true
                } label: {
                    Label("Life happens", systemImage: "pause.circle")
                }
                if AppEnvironment.isDebug {
                    Button {
                        showDebug = true
                    } label: {
                        Label("Debug menu", systemImage: "ladybug")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
            }
            .accessibilityLabel("More")
    }

    // MARK: Banners

    @ViewBuilder
    private var banners: some View {
        if warmup {
            VStack(alignment: .leading, spacing: 6) {
                Text("Warm-up day: this doesn't count")
                    .font(.app(18, .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(model.memberB?.joinedAt != nil
                     ? "Practise a check-in today. Day 1 starts tomorrow morning."
                     : "Practise a check-in while you wait for \(model.partnerName). Day 1 starts the morning after \(model.partnerName) joins.")
                    .font(.app(15))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .peachBox(radius: 18)
        }
        if model.subscriptionLapsed {
            Banner(text: model.iAmPayer
                   ? "Your subscription ended. Your run is paused until it's renewed."
                   : "\(model.payerName)'s subscription ended. Your run is paused until it's renewed.",
                   icon: "pause.circle.fill")
        }
        if let t = model.tweakForMeToAnswer {
            actionCard(title: "\(model.name(of: t.tweak.proposedBy)) suggested a change", button: "Review") {
                showTweakAnswer = true
            }
        }
        if let p = model.pauseForMeToAnswer {
            actionCard(title: "\(model.name(of: p.request.requestedBy)) asked to pause", button: "Answer") {
                showPauseAnswer = true
            }
        } else if let p = model.state.pendingPause, p.request.requestedBy == model.meID {
            Banner(text: "Pause request sent. Waiting for \(model.partnerName).", fill: .peach, foreground: .coral,
                   icon: "hourglass")
        }
        if model.myToday?.isPaused == true {
            Banner(text: "Paused today. Nothing counts for either of you.", fill: .peach, foreground: .coral,
                   icon: "pause.circle")
        }
        if model.state.phase == .betweenRounds {
            Banner(text: betweenRoundsText, fill: .peach, foreground: .coral, icon: "arrow.clockwise")
        }
        if model.myToday?.items.contains(where: { $0.state == .notSent }) == true {
            Banner(text: "Not sent yet. Connect to the internet so it counts.", fill: .peach, foreground: .coral,
                   icon: "icloud.and.arrow.up")
        }
        if hour >= 21, let t = model.myToday, t.dayNumber != nil, t.remaining > 0 {
            Banner(text: "\(t.remaining) \(t.remaining == 1 ? "rule" : "rules") left. \(max(1, 24 - hour)) \(24 - hour == 1 ? "hour" : "hours") to go.",
                   icon: "moon.stars.fill")
        }
    }

    private var betweenRoundsText: String {
        guard let r = round else { return "Your next round starts soon." }
        if r.status == .waiting { return "Round \(r.number) starts tomorrow. Back to Day 1." }
        if r.status == .abandoned { return "This round ended because a subscription lapsed. It restarts once the subscription is renewed." }
        if r.status == .completed { return "You finished! Start round \(r.number + 1) from the Day 75 screen." }
        return "Back to Day 1 tomorrow."
    }

    private func actionCard(title: String, button: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.app(16, .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button(button, action: action)
                .font(.app(16, .bold))
                .foregroundStyle(Color.coral)
        }
        .padding(16)
        .card(radius: 16)
    }

    // MARK: Hero

    private var hero: some View {
        let ta = model.todayA, tb = model.todayB
        let day = model.myToday?.dayNumber
        let title: String
        let subtitle: String?
        if warmup {
            title = "Warm-up"; subtitle = model.memberB?.joinedAt != nil ? "Day 1 tomorrow" : "Day 1 soon"
        } else if model.myToday?.isPaused == true || model.state.isFrozen {
            title = "Paused"; subtitle = nil
        } else if model.myToday?.beforeStart == true {
            title = "Day 1"; subtitle = "tomorrow"
        } else if model.myToday?.finishedRound == true {
            title = "Done"; subtitle = "75 / 75"
        } else {
            title = "DAY \(day ?? 0)"; subtitle = "/ \(Brand.roundLengthDays)"
        }
        let bubble = speechBubble(ta: ta, tb: tb)
        return RingHero(left: model.sceneA, right: model.sceneBJoined ?? (warmup ? nil : model.sceneB),
                        progress: Double(day ?? 0) / Double(Brand.roundLengthDays),
                        centerTitle: title, centerSubtitle: subtitle, topLabel: Brand.appName,
                        leftChip: chip(ta), rightChip: chip(tb),
                        bubble: bubble?.text, bubbleFromLeft: bubble?.fromA ?? true, panelRadius: 22)
            .frame(height: 340)
    }

    private func speechBubble(ta: MemberToday?, tb: MemberToday?) -> (text: String, fromA: Bool)? {
        guard let ta, let tb, warmup || (ta.dayNumber != nil && tb.dayNumber != nil) else { return nil }
        if ta.isComplete && !tb.isComplete { return ("\(model.nameA)'s done. Your turn.", true) }
        if tb.isComplete && !ta.isComplete { return ("\(model.nameB)'s done. Your turn.", false) }
        return nil
    }

    private func chip(_ t: MemberToday?) -> StatusChip? {
        guard let t, warmup || t.dayNumber != nil else { return nil }
        return t.isComplete ? StatusChip(text: "Done", color: .sage) : StatusChip(text: "\(t.remaining) left", color: .brownChip)
    }

    // MARK: Week dots

    private var weekDays: [WeekDot] {
        guard let me = model.me else { return [] }
        let today = LocalDate(model.now(), in: me.tz)
        let start = today.adding(-(today.weekday - 1))
        let settled = Dictionary(
            (round?.member(me.id)?.days ?? []).map { ($0.date, $0) },
            uniquingKeysWith: { a, _ in a })
        let paused = Set(round?.pause?.status == .accepted ? (round?.pause?.dates ?? []) : [])
        return (0..<7).map { i in
            let d = start.adding(i)
            var kind: WeekDot.Kind = .empty
            if let s = settled[d] {
                switch s.outcome {
                case .complete: kind = .complete
                case .miss: kind = s.coveredBySave ? .save : .miss
                case .paused, .frozen: kind = .paused
                }
            } else if d == today {
                kind = paused.contains(d) ? .paused : (model.myToday?.isComplete == true ? .complete : .today)
            } else if d > today {
                kind = paused.contains(d) ? .paused : .future
            }
            return WeekDot(date: d, kind: kind, isToday: d == today)
        }
    }

    // MARK: Saves

    private var savesRow: some View {
        HStack(spacing: 10) {
            if (round?.mode ?? model.currentMode) == .hard {
                Text("Hard mode · no saves")
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text("Saves")
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.textPrimary)
                SaveSquares(left: round?.savesLeft ?? Brand.savesPerRound, total: Brand.savesPerRound, size: 16)
            }
            Spacer()
            Text(scoreText)
                .font(.app(14, .medium))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .card(radius: 16)
        .accessibilityElement(children: .combine)
    }

    private var scoreText: String {
        let a = model.memberA.map { round?.misses($0.id) ?? 0 } ?? 0
        let b = model.memberB.map { round?.misses($0.id) ?? 0 } ?? 0
        return "Score: \(model.nameA) \(a) · \(model.nameB) \(b)"
    }

    // MARK: New from partner

    @ViewBuilder
    private var newFromPartnerRow: some View {
        if let latest = model.unreactedPartnerCheckIns.first {
            Button {
                Haptics.tap()
                model.openInProof(latest.id)
            } label: {
                HStack(spacing: 12) {
                    if latest.hasPhoto {
                        CheckInThumb(checkIn: latest, size: 46, radius: 12)
                    } else {
                        IconBadge(systemName: "hand.raised.fill", color: .sage, size: 46)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New from \(model.partnerName)")
                            .font(.app(16, .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(model.ruleTitle(for: latest))
                            .font(.app(14))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer(minLength: 6)
                    Text("Tap to react ›")
                        .font(.app(15, .semibold))
                        .foregroundStyle(Color.coral)
                }
                .padding(12)
                .peachBox(radius: 18)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("New from \(model.partnerName): \(model.ruleTitle(for: latest)). Tap to react")
        }
    }

    // MARK: Rules

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(warmup ? "Today's practice" : "Today's rules")
                .font(.app(21, .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(alignment: .top, spacing: 12) {
                rulesCard(member: model.memberA, today: model.todayA, color: .coral)
                rulesCard(member: model.memberB, today: model.todayB, color: .sage,
                          name: model.nameB, fallback: model.memberB == nil ? model.draftRulesForB : [])
            }
        }
        .padding(.top, 4)
    }

    private func rulesCard(member: MemberFact?, today: MemberToday?, color: Color,
                           name: String? = nil, fallback: [RuleFact] = []) -> some View {
        let isMe = member?.id == model.meID
        let toReact = isMe ? 0 : (today?.items ?? []).filter { $0.checkIn.map { !model.hasReacted(to: $0) } ?? false }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(member?.name ?? name ?? "")
                    .font(.app(18, .bold))
                    .foregroundStyle(color)
                Spacer(minLength: 4)
                if toReact > 0 {
                    Text("\(toReact) to react")
                        .font(.app(12, .semibold))
                        .foregroundStyle(Color.coral)
                        .lineLimit(1)
                }
            }
            ForEach(today?.items ?? fallback.map { ChecklistItem(rule: $0, checkIn: nil, state: .open) }) { item in
                Button {
                    tap(item, isMe: isMe, today: today)
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        if !isMe, let c = item.checkIn, c.hasPhoto {
                            CheckInThumb(checkIn: c, size: 26, radius: 7)
                                .overlay(alignment: .topTrailing) {
                                    if !model.hasReacted(to: c) {
                                        Circle().fill(Color.coral).frame(width: 9, height: 9)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                            .offset(x: 3, y: -3)
                                    }
                                }
                        } else {
                            CheckCircle(isOn: item.isChecked, color: .coral, size: 22)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.rule.title)
                                .font(.app(15, .medium))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if isMe, !warmup, !item.isChecked, item.rule.type == .honour, hour < 18 {
                                Text("Tap tonight")
                                    .font(.app(12, .medium))
                                    .foregroundStyle(Color.textSecondary.opacity(0.85))
                            } else if item.state == .notSent {
                                Text("Not sent yet")
                                    .font(.app(12, .semibold))
                                    .foregroundStyle(Color.coral)
                            } else if let c = item.checkIn, let status = model.partnerStatus(of: c), isMe {
                                Text(status)
                                    .font(.app(12, .semibold))
                                    .foregroundStyle(Color.sage)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isMe && item.checkIn == nil)
                .accessibilityLabel("\(item.rule.title), \(item.isChecked ? "done" : "not done")")
                .accessibilityHint(isMe && !item.isChecked ? "Check in" : (item.checkIn != nil ? "Open check-in" : ""))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18)
    }

    private func tap(_ item: ChecklistItem, isMe: Bool, today: MemberToday?) {
        if let c = item.checkIn, !isMe {
            model.openInProof(c.id)
            return
        }
        if let c = item.checkIn, item.isChecked {
            openedCheckIn = c
            return
        }
        guard isMe, canCheckIn(today) else { return }
        open(item.rule)
    }

    private func canCheckIn(_ today: MemberToday?) -> Bool {
        guard let today else { return false }
        if warmup { return true }
        if model.state.isFrozen || today.isPaused || today.finishedRound { return false }
        return today.dayNumber != nil || model.isWarmup
    }

    private func open(_ rule: RuleFact) {
        if rule.type == .photo {
            cameraRule = rule
        } else {
            honourRule = rule
        }
    }

    // MARK: Check in

    private var nextRule: RuleFact? {
        guard canCheckIn(model.myToday) else { return nil }
        let open = (model.myToday?.items ?? []).filter { !$0.isChecked }
        if let photo = open.first(where: { $0.rule.type == .photo }) { return photo.rule }
        if warmup || hour >= 18 { return open.first?.rule }
        return nil
    }

    @ViewBuilder
    private var checkInButton: some View {
        if model.myToday?.isComplete == true {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text(warmup ? "Practice done" : "All done today").font(.app(18, .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.buttonHeight)
            .background(Capsule().fill(Color.sage))
            .accessibilityElement(children: .combine)
        } else {
            PrimaryButton(warmup ? "Practise check-in" : "Check in", isEnabled: nextRule != nil) {
                if let r = nextRule { open(r) }
            }
        }
    }

    private var stakesRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.gold)
            Text("Stakes: \(round?.betText ?? model.currentBet)")
                .font(.app(16, .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .card(radius: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Gold "🔥 14" pill.
struct StreakPill: View {
    var streak: Int

    var body: some View {
        HStack(spacing: 5) {
            Text("🔥").font(.system(size: 16))
            Text("\(streak)").font(.app(18, .semibold))
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Capsule().fill(Color.gold.opacity(0.55)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak \(streak) days")
    }
}

struct WeekDot: Identifiable {
    enum Kind { case complete, save, miss, paused, today, future, empty }
    var date: LocalDate
    var kind: Kind
    var isToday: Bool
    var id: Int { date.ordinal }
}

/// S M T W T F S for the current week: big dots, letters below, "{n}-day streak" under the row.
struct WeekDotsView: View {
    var days: [WeekDot]
    var streak: Int
    private let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                    VStack(spacing: 6) {
                        dot(d)
                        Text(letters[i % 7])
                            .font(.app(14, .medium))
                            .foregroundStyle(d.isToday ? Color.coral : Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(letters[i % 7]): \(label(d))")
                }
            }
            Text("\(streak)-day streak")
                .font(.app(16, .semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func dot(_ d: WeekDot) -> some View {
        let size: CGFloat = 32
        switch d.kind {
        case .complete:
            Circle().fill(Color.gold).frame(width: size, height: size)
        case .save:
            Circle().fill(Color.gold.opacity(0.35)).frame(width: size, height: size)
                .overlay(Circle().fill(Color.coral).frame(width: 16, height: 16)
                    .overlay(Text("S").font(.app(10, .bold)).foregroundStyle(.white)))
        case .miss:
            Circle().stroke(Color.coral.opacity(0.7), lineWidth: 2).frame(width: size, height: size)
                .overlay(Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.coral))
        case .paused:
            Circle().fill(Color.gray.opacity(0.3)).frame(width: size, height: size)
        case .today:
            Circle().fill(Color.white).frame(width: size, height: size)
                .overlay(Circle().stroke(Color.coral, lineWidth: 2.5))
        case .future, .empty:
            Circle().fill(Color.white.opacity(0.7)).frame(width: size, height: size)
                .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1.5))
        }
    }

    private func label(_ d: WeekDot) -> String {
        switch d.kind {
        case .complete: return "complete"
        case .save: return "covered by a save"
        case .miss: return "missed"
        case .paused: return "paused"
        case .today: return "today"
        case .future, .empty: return "upcoming"
        }
    }
}
