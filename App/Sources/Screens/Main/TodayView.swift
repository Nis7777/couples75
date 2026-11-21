import SwiftUI

/// 15: Today.
struct TodayView: View {
    @Environment(AppModel.self) private var model
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
        let tz = model.me?.tz ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.component(.hour, from: model.now())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                banners
                ringScene
                WeekDotsView(days: weekDays)
                savesRow
                rulesSection
                checkInButton
                stakesRow
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $cameraRule) { r in CheckInCameraView(rule: r) }
        .sheet(item: $honourRule) { r in HonourSheet(rule: r).presentationDetents([.height(320)]) }
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
            Text("\(model.nameA) & \(model.nameB)")
                .font(.rounded(22))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
                .onTapGesture(count: 3) {
                    if AppEnvironment.isDebug { showDebug = true }
                }
            Spacer()
            Pill(text: "🔥 \(model.state.streak)", fill: .gold)
                .accessibilityLabel("Streak \(model.state.streak) days")
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
            }
            .accessibilityLabel("More")
        }
        .padding(.top, 8)
    }

    // MARK: Banners

    @ViewBuilder
    private var banners: some View {
        if let partner = model.partner, model.state.lapsedMembers.contains(partner.id), round?.status == .active {
            Banner(text: "\(partner.name)'s subscription ended. Your run is paused until they renew.", icon: "pause.circle.fill")
        } else if model.state.isFrozen {
            Banner(text: "Your run is paused until the subscription is renewed.", icon: "pause.circle.fill")
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
        if r.status == .abandoned { return "This round ended because a subscription lapsed. It restarts when you're both subscribed." }
        if r.status == .completed { return "You finished! Start round \(r.number + 1) from the Day 75 screen." }
        return "Back to Day 1 tomorrow."
    }

    private func actionCard(title: String, button: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button(button, action: action)
                .font(.app(15, .bold))
                .foregroundStyle(Color.coral)
        }
        .padding(14)
        .card(radius: 14)
    }

    // MARK: Ring scene

    private var ringScene: some View {
        let ta = model.todayA, tb = model.todayB
        let day = model.myToday?.dayNumber
        let caption: String? = {
            if model.myToday?.isPaused == true || model.state.isFrozen { return "Paused" }
            if model.myToday?.beforeStart == true { return "Starts\ntomorrow" }
            if model.myToday?.finishedRound == true { return "Done" }
            return nil
        }()
        return VStack(spacing: 8) {
            ZStack(alignment: .top) {
                RingScene(left: model.sceneA, right: model.sceneB, day: day, caption: caption)
                    .frame(height: 290)
                if let bubble = speechBubble(ta: ta, tb: tb) {
                    SpeechBubble(text: bubble.text)
                        .frame(maxWidth: .infinity, alignment: bubble.fromA ? .leading : .trailing)
                        .padding(.top, 4)
                }
            }
            HStack {
                statusChip(ta).frame(maxWidth: .infinity)
                statusChip(tb).frame(maxWidth: .infinity)
            }
        }
    }

    private func speechBubble(ta: MemberToday?, tb: MemberToday?) -> (text: String, fromA: Bool)? {
        guard let ta, let tb, ta.dayNumber != nil, tb.dayNumber != nil else { return nil }
        if ta.isComplete && !tb.isComplete { return ("\(model.nameA)'s done. Your turn.", true) }
        if tb.isComplete && !ta.isComplete { return ("\(model.nameB)'s done. Your turn.", false) }
        return nil
    }

    @ViewBuilder
    private func statusChip(_ t: MemberToday?) -> some View {
        if let t, t.dayNumber != nil {
            if t.isComplete {
                Pill(text: "Done", fill: .sage)
            } else {
                Pill(text: "\(t.remaining) left", fill: .brownChip)
            }
        } else {
            Color.clear.frame(height: 24)
        }
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
                kind = paused.contains(d) ? .paused : .today
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
                    .font(.app(14, .semibold))
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text("Saves")
                    .font(.app(14, .semibold))
                    .foregroundStyle(Color.textPrimary)
                SaveSquares(left: round?.savesLeft ?? Brand.savesPerRound, total: Brand.savesPerRound)
            }
            Spacer()
            Text(scoreText)
                .font(.app(13, .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(14)
        .card(radius: 14)
        .accessibilityElement(children: .combine)
    }

    private var scoreText: String {
        let a = model.memberA.map { round?.misses($0.id) ?? 0 } ?? 0
        let b = model.memberB.map { round?.misses($0.id) ?? 0 } ?? 0
        return "Score: \(model.nameA) \(a) · \(model.nameB) \(b)"
    }

    // MARK: Rules

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's rules")
                .font(.app(17, .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(alignment: .top, spacing: 12) {
                rulesCard(member: model.memberA, today: model.todayA, color: .coral)
                rulesCard(member: model.memberB, today: model.todayB, color: .sage)
            }
        }
    }

    private func rulesCard(member: MemberFact?, today: MemberToday?, color: Color) -> some View {
        let isMe = member?.id == model.meID
        return VStack(alignment: .leading, spacing: 10) {
            Text(member?.name ?? "")
                .font(.app(15, .bold))
                .foregroundStyle(color)
            ForEach(today?.items ?? []) { item in
                Button {
                    tap(item, isMe: isMe, today: today)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        CheckCircle(isOn: item.isChecked, color: color, size: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.rule.title)
                                .font(.app(14, .medium))
                                .foregroundStyle(Color.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            if isMe, !item.isChecked, item.rule.type == .honour, hour < 18 {
                                Text("Tap tonight")
                                    .font(.app(12))
                                    .foregroundStyle(Color.textSecondary)
                            } else if item.state == .notSent {
                                Text("Not sent yet")
                                    .font(.app(12))
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func tap(_ item: ChecklistItem, isMe: Bool, today: MemberToday?) {
        if let c = item.checkIn, (!isMe || item.isChecked) {
            openedCheckIn = c
            return
        }
        guard isMe, canCheckIn(today) else { return }
        open(item.rule)
    }

    private func canCheckIn(_ today: MemberToday?) -> Bool {
        guard let today else { return false }
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
        if hour >= 18 { return open.first?.rule }
        return nil
    }

    @ViewBuilder
    private var checkInButton: some View {
        if model.myToday?.isComplete == true {
            Label("All done today", systemImage: "checkmark.seal.fill")
                .font(.app(16, .semibold))
                .foregroundStyle(Color.sage)
                .frame(height: 58)
        } else {
            PrimaryButton("Check in", isEnabled: nextRule != nil) {
                if let r = nextRule { open(r) }
            }
        }
    }

    private var stakesRow: some View {
        HStack(spacing: 8) {
            Text("🏆")
            Text("Stakes: \(round?.betText ?? model.currentBet)")
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.peach))
        .accessibilityElement(children: .combine)
    }
}

struct SpeechBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.app(13, .semibold))
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
    }
}

struct WeekDot: Identifiable {
    enum Kind { case complete, save, miss, paused, today, future, empty }
    var date: LocalDate
    var kind: Kind
    var isToday: Bool
    var id: Int { date.ordinal }
}

/// S M T W T F S for the current week.
struct WeekDotsView: View {
    var days: [WeekDot]
    private let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack {
            ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                VStack(spacing: 6) {
                    Text(letters[i % 7])
                        .font(.app(12, .semibold))
                        .foregroundStyle(Color.textSecondary)
                    dot(d)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(letters[i % 7]): \(label(d))")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .card(radius: 14)
    }

    @ViewBuilder
    private func dot(_ d: WeekDot) -> some View {
        let size: CGFloat = 22
        switch d.kind {
        case .complete:
            Circle().fill(Color.gold).frame(width: size, height: size)
        case .save:
            Circle().fill(Color.coral).frame(width: size, height: size)
                .overlay(Text("S").font(.app(11, .bold)).foregroundStyle(.white))
        case .miss:
            Circle().stroke(Color.coral, lineWidth: 2).frame(width: size, height: size)
                .overlay(Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.coral))
        case .paused:
            Circle().fill(Color.gray.opacity(0.35)).frame(width: size, height: size)
        case .today:
            Circle().stroke(Color.coral, lineWidth: 2.5).frame(width: size, height: size)
        case .future, .empty:
            Circle().fill(Color.faint).frame(width: size, height: size)
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
