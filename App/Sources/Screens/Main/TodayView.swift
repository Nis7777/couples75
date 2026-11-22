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
    @State private var showWhichRule = false
    @State private var showProgressCamera = false

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
                SyncStatusLine()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, -8)
                if let note = model.unreadNote { NoteBanner(note: note) }
                banners
                hero
                WeekDotsView(days: weekDays, streak: model.state.streak)
                if round?.mode.isMaintenance != true {
                    DayProgressBar(day: warmup ? 0 : (model.myToday?.dayNumber ?? 0))
                }
                savesRow
                newFromPartnerRow
                rulesSection
                checkInButton
                PartnerActionsRow()
                ProgressPhotoCard { showProgressCamera = true }
                if round?.mode.isMaintenance == true { MaintenanceRow() } else { stakesRow }
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $cameraRule) { r in CheckInCameraView(rule: r) }
        .fullScreenCover(isPresented: $showProgressCamera) { ProgressCameraView() }
        .onChange(of: model.openRuleID) { _, id in openFromWidget(id) }
        .onAppear { openFromWidget(model.openRuleID) }
        .sheet(item: $honourRule) { r in HonourSheet(rule: r).presentationDetents([.height(430)]) }
        .sheet(item: $openedCheckIn) { c in PartnerCheckInView(checkIn: c) }
        .sheet(isPresented: $showPauseRequest) { PauseRequestView() }
        .sheet(isPresented: $showPauseAnswer) {
            if let p = model.pauseForMeToAnswer { PauseAnswerView(info: p) }
        }
        .sheet(isPresented: $showTweakAnswer) {
            if let t = model.tweakForMeToAnswer { TweakAnswerView(info: t) }
        }
        .sheet(isPresented: $showWhichRule) {
            WhichRuleSheet(rules: uncheckedRules) { r in
                showWhichRule = false
                // Let the sheet go away before the camera cover comes up.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { open(r) }
            }
            // Native sheet: medium/large detents with spring snapping and a grabber.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
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
                    #if DEBUG
                    showDebug = true
                    #endif
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
                #if DEBUG
                Button {
                    showDebug = true
                } label: {
                    Label("Debug menu", systemImage: "ladybug")
                }
                #endif
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
            title = "Day 1"; subtitle = model.memberB?.joinedAt != nil ? "tomorrow" : "soon"
        } else if model.myToday?.isPaused == true || model.state.isFrozen {
            title = "Paused"; subtitle = nil
        } else if model.myToday?.beforeStart == true {
            title = "Day 1"; subtitle = "tomorrow"
        } else if model.myToday?.finishedRound == true {
            title = "Done"; subtitle = "75 / 75"
        } else if round?.mode.isMaintenance == true {
            title = "DAY \(day ?? 0)"; subtitle = "Keep it up"
        } else {
            title = "DAY \(day ?? 0)"; subtitle = "/ \(Brand.roundLengthDays)"
        }
        let bubble = speechBubble(ta: ta, tb: tb)
        return RingHero(left: model.sceneA, right: model.sceneBJoined ?? (warmup ? nil : model.sceneB),
                        progress: round?.mode.isMaintenance == true ? 1 : Double(day ?? 0) / Double(Brand.roundLengthDays),
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
            if (round?.mode ?? model.currentMode) == .maintenance {
                Text("Maintenance · no stakes")
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.textPrimary)
            } else if (round?.mode ?? model.currentMode) == .hard {
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
                            // Wraps to 2 lines instead of cutting off ("Instrument: 30 min").
                            Text(item.rule.title)
                                .font(.app(15, .medium))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                            if isMe, !item.isChecked, let health = model.healthProgressText(for: item.rule) {
                                Text(health)
                                    .font(.app(12, .medium))
                                    .foregroundStyle(Color.textSecondary.opacity(0.85))
                            } else if let proof = item.checkIn?.healthProof, item.isChecked {
                                Text(proof.replacingOccurrences(of: "Apple Health · ", with: " "))
                                    .font(.app(12, .semibold))
                                    .foregroundStyle(Color.sage)
                            } else if isMe, !warmup, !item.isChecked, item.rule.type == .honour, hour < 18 {
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

    /// A widget tap on a photo rule: open its camera (or the honour sheet).
    private func openFromWidget(_ id: String?) {
        guard let id else { return }
        model.openRuleID = nil
        guard let item = model.myToday?.items.first(where: { $0.rule.id == id }), !item.isChecked,
              canCheckIn(model.myToday) else { return }
        open(item.rule)
    }

    private func open(_ rule: RuleFact) {
        if rule.type == .photo {
            cameraRule = rule
        } else {
            honourRule = rule
        }
    }

    // MARK: Check in

    /// My rules not checked in yet today, photo rules first.
    private var uncheckedRules: [RuleFact] {
        guard canCheckIn(model.myToday) else { return [] }
        let open = (model.myToday?.items ?? []).filter { !$0.isChecked }.map(\.rule)
        return open.filter { $0.type == .photo } + open.filter { $0.type == .honour }
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
            // Never opens the camera directly: "Which rule?" first.
            PrimaryButton(warmup ? "Practise check-in" : "Check in", isEnabled: !uncheckedRules.isEmpty) {
                showWhichRule = true
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

/// Today, under the streak row: "Day X of 75", a coral bar and the percentage. The bar animates from the
/// last day this phone showed when the day goes up.
struct DayProgressBar: View {
    var day: Int
    var total = Brand.roundLengthDays
    @State private var shown: Int = UserDefaults.standard.integer(forKey: "progressBarDay")

    private var fraction: Double { Double(min(max(shown, 0), total)) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Day \(shown) of \(total)")
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .contentTransition(.numericText())
                Spacer()
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.app(15, .bold))
                    .foregroundStyle(Color.coral)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track)
                    Capsule().fill(Color.coral)
                        .frame(width: max(fraction > 0 ? 10 : 0, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .card(radius: 16, shadow: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(day) of \(total), \(Int((Double(day) / Double(total) * 100).rounded())) percent")
        .onAppear { animate(to: day) }
        .onChange(of: day) { _, new in animate(to: new) }
    }

    private func animate(to new: Int) {
        guard new != shown else { return }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.25)) { shown = new }
        UserDefaults.standard.set(new, forKey: "progressBarDay")
    }
}

/// The optional daily progress photo (separate from rule proof): "Take today's progress pic".
struct ProgressPhotoCard: View {
    @Environment(AppModel.self) private var model
    var open: () -> Void

    var body: some View {
        let today = model.myProgressToday
        Button(action: open) {
            HStack(spacing: 14) {
                Group {
                    if let today, let img = model.progress.image(for: today) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.coral)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.peach)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(today == nil ? "Take today's progress pic" : "Progress pic done")
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(model.shareProgressPhotos ? "Shared with \(model.partnerName)" : "Optional · private, only you see it")
                        .font(.app(13))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 4)
                Text(today == nil ? "Open ›" : "Retake")
                    .font(.app(14, .semibold))
                    .foregroundStyle(Color.coral)
            }
            .padding(12)
            .card(radius: 18, shadow: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(today == nil ? "Take today's progress pic" : "Progress pic done. Retake")
    }
}

/// "Which rule?": the small sheet behind the main Check in button, listing my unchecked rules.
struct WhichRuleSheet: View {
    var rules: [RuleFact]
    var pick: (RuleFact) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which rule?")
                .font(.app(22, .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 22)
            ForEach(rules) { r in
                Button { pick(r) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: r.type == .photo ? "camera.fill" : "hand.raised.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.coral)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.peach))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title)
                                .font(.app(16, .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(2)
                            Text(r.type == .photo ? "Photo" : "Honour tap")
                                .font(.app(12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.card))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.side)
        .padding(.bottom, 20)
        }
        .background(Color.ivory.ignoresSafeArea())
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

/// In maintenance: no stakes, and a way back into a full 75-day round.
struct MaintenanceRow: View {
    @Environment(AppModel.self) private var model
    @State private var startNew = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill").foregroundStyle(Color.sage)
            VStack(alignment: .leading, spacing: 2) {
                Text("Maintenance mode").font(.app(16, .semibold)).foregroundStyle(Color.textPrimary)
                Text("No saves, no bet. Just keep it up.").font(.app(13)).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button("New 75 ›") { startNew = true }
                .font(.app(15, .bold))
                .foregroundStyle(Color.coral)
        }
        .padding(16)
        .card(radius: 16)
        .sheet(isPresented: $startNew) {
            if let r = model.currentRound { StartNextRoundSheet(round: r) }
        }
    }
}
