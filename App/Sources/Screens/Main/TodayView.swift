import SwiftUI
import UIKit

/// 15: Today does one job: where the two of you stand today, and checking in. Top to bottom: the compact Pact Card
/// (names, rank, streak, both busts around today's ring, one status line; tap = the full card), the week strip,
/// "Today" with both habit cards side by side (equal height; yours is tappable, your partner's shows done / pending
/// / waiting for your approval), the one primary button, then "More today" (progress pic, challenges).
/// The warm-up (28) is the same screen: the status line says it, and the button is "Practise check-in ›".
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
    @State private var showPactCard = false
    @State private var showNote = false
    /// Habit cards opened past 5 rows ("+N more"), by member (or name, before the partner joins).
    @State private var expanded: Set<String> = []
    @State private var bannerDetail: TodayBanner?

    /// Habit rows per card before "+N more", so 5 + 5 and the button fit an iPhone 16 Pro without scrolling.
    private static let maxRows = 5

    private var round: RoundState? { model.currentRound }
    private var hour: Int {
        _ = model.clockTick
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = model.me?.tz ?? .current
        return cal.component(.hour, from: model.now())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let onBack {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .font(.app(16, .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                header
                WeekDotsView(days: weekDays)
                rulesSection
                checkInSection
                moreToday
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            // Clears the floating tab bar (on top of the bar's own inset from MainView).
            .padding(.bottom, 32)
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
        .sheet(isPresented: $showPactCard) { PactCardSheet().presentationDragIndicator(.visible) }
        .sheet(item: $bannerDetail) { b in
            TodayBannerSheet(banner: b, sendNote: { showNote = true })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNote) {
            LoveNoteSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header

    /// The compact Pact Card. Tap anywhere but the "…" menu to open the full card.
    private var header: some View {
        let ring = checkedToday
        let banner = topBanner
        return PactCardCompact(data: model.pactCard, done: ring.done, total: ring.total, status: statusLine,
                               shields: model.state.streakShields, bannerIcon: banner?.icon,
                               bannerText: banner?.text, onBanner: { if let banner { openBanner(banner) } }) {
            if !warmup { menu }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            Haptics.tap()
            showPactCard = true
        }
        .accessibilityAction(named: "Open our card") { showPactCard = true }
    }

    /// The one line under the ring.
    private var statusLine: String {
        let t = model.myToday
        if warmup {
            return model.memberB?.joinedAt != nil
                ? "Warm-up · Day 1 starts tomorrow"
                : "Warm-up · Day 1 starts the day after \(model.partnerName) joins"
        }
        if t?.isPaused == true || model.state.isFrozen { return "Paused today · nothing counts" }
        if let c = model.upcomingChallenge { return "\(c.title) starts tomorrow · today still counts" }
        if t?.beforeStart == true || model.state.phase == .betweenRounds { return "Day 1 starts tomorrow" }
        guard let r = round else { return "Day 1 starts tomorrow" }
        if t?.finishedRound == true { return "Done · \(r.length) of \(r.length)" }
        let day = t?.dayNumber ?? 0
        if r.mode.isMaintenance { return "Day \(day)" }
        var line = "Day \(day) of \(r.length)"
        if r.savesAllowed > 0 { line += " · \(r.savesLeft) \(r.savesLeft == 1 ? "save" : "saves") left" }
        return line
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .contentShape(Circle())
            }
            .accessibilityLabel("More")
    }

    // MARK: Banner

    /// At most one banner, highest priority first; it sits in the header card's status line (one line, never
    /// pushes the screen down) and opens the details. "Starts tomorrow" and "Paused today" aren't banners: the
    /// status line already says them.
    private var topBanner: TodayBanner? {
        if let p = model.pauseForMeToAnswer {
            let who = model.name(of: p.request.requestedBy)
            return TodayBanner(id: "pause-\(p.request.id)", icon: "pause.circle.fill", text: "\(who) asked to pause · Answer",
                               title: "\(who) asked to pause", detail: "", kind: .pauseAnswer)
        }
        if let t = model.tweakForMeToAnswer {
            let who = model.name(of: t.tweak.proposedBy)
            return TodayBanner(id: "tweak-\(t.tweak.id)", icon: "slider.horizontal.3", text: "\(who) suggested a change · Review",
                               title: "\(who) suggested a change", detail: "", kind: .tweakAnswer)
        }
        if model.subscriptionLapsed {
            return TodayBanner(id: "lapsed", icon: "pause.circle.fill", text: "Run paused · subscription ended",
                               title: "Your run is paused",
                               detail: model.iAmPayer
                                ? "Your subscription ended. Your days stop counting until it's renewed. One subscription covers you both."
                                : "\(model.payerName)'s subscription ended. Your days stop counting until it's renewed. Either of you can subscribe.",
                               kind: .info)
        }
        if model.deviceStorageLow {
            return TodayBanner(id: "devicefull", icon: "externaldrive.badge.exclamationmark",
                               text: "Your iPhone is almost full · photos may not save",
                               title: "Your iPhone is almost full",
                               detail: "\(Brand.appName) keeps your check-in photos on your iPhone. With so little space left, a photo might not save. Free up some space in Settings → General → iPhone Storage.",
                               kind: .info)
        }
        if model.myToday?.items.contains(where: { $0.state == .notSent }) == true {
            return TodayBanner(id: "notsent", icon: "icloud.and.arrow.up", text: "Not sent yet · connect to the internet",
                               title: "Not sent yet",
                               detail: "Some of your check-ins are saved on this phone but haven't reached \(model.partnerName) yet. Connect to the internet so they count; they're sent automatically.",
                               kind: .info)
        }
        if let note = model.unreadNote {
            let from = model.name(of: note.from)
            return TodayBanner(id: "note-\(note.id)", icon: "heart.fill", text: "\(from): \(note.text ?? "❤️")",
                               title: "\(from) sent you a note", detail: note.text ?? "❤️", kind: .note(note))
        }
        if hour >= 21, let t = model.myToday, t.dayNumber != nil, t.remaining > 0 {
            let hours = max(1, 24 - hour)
            let left = "\(t.remaining) \(t.remaining == 1 ? "habit" : "habits") left"
            return TodayBanner(id: "evening", icon: "moon.stars.fill",
                               text: "\(left) · \(hours) \(hours == 1 ? "hour" : "hours") to go",
                               title: "\(left) today",
                               detail: "Your day closes at midnight. Check in on what's left before then so it counts.",
                               kind: .info)
        }
        if let p = model.state.pendingPause, p.request.requestedBy == model.meID {
            return TodayBanner(id: "pausesent", icon: "hourglass", text: "Pause request sent · waiting for \(model.partnerName)",
                               title: "Pause request sent",
                               detail: "\(model.partnerName) can accept or decline it. If they don't answer, it's accepted automatically.",
                               kind: .info)
        }
        return nil
    }

    private func openBanner(_ b: TodayBanner) {
        switch b.kind {
        case .pauseAnswer: showPauseAnswer = true
        case .tweakAnswer: showTweakAnswer = true
        case .note, .info: bannerDetail = b
        }
    }

    // MARK: Ring

    /// Today's check-ins for both of us (the header ring): every habit either of you has checked today, out of all
    /// of both your habits today. Straight from the engine's `MemberToday` items; before the partner joins, just yours.
    private var checkedToday: (done: Int, total: Int) {
        let items = [model.todayA, model.todayB].compactMap { $0 }.flatMap(\.items)
        return (items.filter(\.isChecked).count, items.count)
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

    // MARK: Today's habits

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.app(21, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                SyncStatusLine()
            }
            // Equal height: both cards stretch to the taller one.
            HStack(alignment: .top, spacing: 12) {
                rulesCard(member: model.memberA, today: model.todayA, name: model.nameA, color: .coral)
                rulesCard(member: model.memberB, today: model.todayB, name: model.nameB, color: .sage,
                          fallback: model.memberB == nil ? model.draftRulesForB : [])
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One person's habits. Mine: tap to check in. My partner's: full contrast but read-only, each habit done ✓,
    /// pending ○, or done and waiting for my approval (coral dot; tap opens it in Proof to approve).
    private func rulesCard(member: MemberFact?, today: MemberToday?, name: String, color: Color,
                           fallback: [RuleFact] = []) -> some View {
        let isMe = member?.id == model.meID
        let items = today?.items ?? fallback.map { ChecklistItem(rule: $0, checkIn: nil, state: .open) }
        let done = items.filter(\.isChecked).count
        let key = member?.id ?? name
        let isOpen = expanded.contains(key)
        // More than 5: unfinished first, then the first 5 and "+N more" (opens the card in place).
        let ordered = items.count > Self.maxRows ? items.filter { !$0.isChecked } + items.filter(\.isChecked) : items
        let shown = isOpen ? ordered : Array(ordered.prefix(Self.maxRows))
        let hidden = ordered.count - shown.count
        let partnerJoined = !isMe && member?.joinedAt != nil
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.app(17, .bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !items.isEmpty {
                    Text("\(done)/\(items.count)")
                        .font(.app(13, .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 2)
                if partnerJoined {
                    if model.canNudgePartner {
                        iconButton("hand.point.right.fill", label: "Nudge \(name)") {
                            Task { await model.sendNudge() }
                        }
                    }
                    iconButton("heart.fill", label: "Send \(name) a note") { showNote = true }
                }
            }
            if member == nil && fallback.isEmpty {
                Text("Picks their own habits when joining")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(shown) { item in
                    Button {
                        tap(item, isMe: isMe, today: today)
                    } label: {
                        ruleRow(item, isMe: isMe)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(a11yText(item, isMe: isMe, name: name))
                    .accessibilityHint(isMe && !item.isChecked ? "Check in" : (item.checkIn != nil ? "Open check-in" : ""))
                }
                if hidden > 0 || (isOpen && items.count > Self.maxRows) {
                    Button {
                        Haptics.tap()
                        withAnimation(.open(0.3)) {
                            if isOpen { expanded.remove(key) } else { expanded.insert(key) }
                        }
                    } label: {
                        HStack {
                            Text(isOpen ? "Show less" : "+\(hidden) more")
                                .font(.app(14, .semibold))
                                .foregroundStyle(Color.coral)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isOpen ? "Show fewer of \(name)'s habits" : "Show \(hidden) more of \(name)'s habits")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(radius: 18)
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.coral)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.peach))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    /// Waiting for MY approval: my partner checked it in with a photo and I haven't reacted yet (taps need none).
    private func awaitsMyApproval(_ item: ChecklistItem, isMe: Bool) -> Bool {
        guard !isMe, let c = item.checkIn else { return false }
        return model.needsMyApproval(c)
    }

    private func ruleRow(_ item: ChecklistItem, isMe: Bool) -> some View {
        let waiting = awaitsMyApproval(item, isMe: isMe)
        return HStack(alignment: .center, spacing: 8) {
            Group {
                if !isMe, let c = item.checkIn, c.hasPhoto {
                    CheckInThumb(checkIn: c, size: 24, radius: 7)
                } else {
                    CheckCircle(isOn: item.isChecked, color: isMe ? .coral : .sage, size: 22)
                }
            }
            .overlay(alignment: .topTrailing) {
                if waiting {
                    Circle().fill(Color.highlight).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                // One line; the full name shows on tap and to VoiceOver.
                Text(RuleTitle.short(item.rule.title))
                    .font(.app(15, .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let sub = subline(item, isMe: isMe, waiting: waiting) {
                    Text(sub.text)
                        .font(.app(11, .semibold))
                        .foregroundStyle(sub.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    private func subline(_ item: ChecklistItem, isMe: Bool, waiting: Bool) -> (text: String, color: Color)? {
        if waiting { return ("Tap to approve", .highlight) }
        guard isMe else { return nil }
        if !item.isChecked, let health = model.healthProgressText(for: item.rule) {
            return (health, Color.textSecondary)
        }
        if item.checkIn?.healthProof != nil, item.isChecked {
            // Today's Health reading is only on this iPhone; the synced check-in has no number.
            if let metric = HealthMetric.metric(for: item.rule), let v = model.healthReadings[item.rule.id] {
                return (metric.progressText(v), .sage)
            }
            return ("Auto-checked", .sage)
        }
        if !warmup, !item.isChecked, item.rule.type == .honour, hour < 18 { return ("Tap tonight", Color.textSecondary) }
        if item.state == .notSent { return ("Not sent yet", .coral) }
        if let c = item.checkIn, let status = model.partnerStatus(of: c) { return (status, .sage) }
        if item.isChecked, item.checkIn?.hasPhoto == true, !warmup, model.partner?.joinedAt != nil {
            return ("Waiting for \(model.partnerName)", Color.textSecondary)
        }
        return nil
    }

    private func a11yText(_ item: ChecklistItem, isMe: Bool, name: String) -> String {
        let state: String
        if awaitsMyApproval(item, isMe: isMe) { state = "done, waiting for your approval" }
        else { state = item.isChecked ? "done" : "not done yet" }
        return isMe ? "\(item.rule.title), \(state)" : "\(name): \(item.rule.title), \(state)"
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
        guard isMe, canCheckIn(today) else {
            // Nothing to do here (a pending habit of my partner's, or a paused day): show the full name.
            model.toast = item.rule.title
            return
        }
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

    /// The only full-width primary button. Done: "Done for today ✓" (secondary), and who we're waiting on.
    @ViewBuilder
    private var checkInSection: some View {
        if model.myToday?.isComplete == true {
            VStack(spacing: 8) {
                SecondaryButtonLabel(title: warmup ? "Practice done ✓" : "Done for today ✓")
                    .accessibilityElement(children: .combine)
                if let p = model.partnerToday, warmup || p.dayNumber != nil, !p.isComplete, model.partner?.joinedAt != nil {
                    Text("Waiting on \(model.partnerName)")
                        .font(.app(14, .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        } else {
            // Never opens the camera directly: "Which rule?" first.
            PrimaryButton(warmup ? "Practise check-in ›" : "Check in ›", isEnabled: !uncheckedRules.isEmpty) {
                showWhichRule = true
            }
        }
    }

    // MARK: More today

    /// Quiet compact rows below the fold.
    private var moreToday: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("More today")
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textSecondary)
            VStack(spacing: 0) {
                if let latest = model.unreactedPartnerCheckIns.first {
                    moreRow(icon: "hand.thumbsup.fill",
                            title: "New from \(model.partnerName) · \(RuleTitle.short(model.ruleTitle(for: latest)))",
                            detail: "React") {
                        model.openInProof(latest.id)
                    }
                    Divider().padding(.leading, 46)
                }
                moreRow(icon: model.myProgressToday == nil ? "camera.fill" : "checkmark.circle.fill",
                        title: model.myProgressToday == nil
                            ? (model.shareProgressPhotos ? "Progress pic · optional" : "Progress pic · optional, only you see it")
                            : "Progress pic done",
                        detail: model.myProgressToday == nil ? nil : "Retake") {
                    showProgressCamera = true
                }
                Divider().padding(.leading, 46)
                if let c = model.activeChallenge {
                    let bet = round?.betText ?? ""
                    moreRow(icon: "trophy.fill", title: bet.isEmpty ? "\(c.title) · no bet" : "Stakes: \(bet)",
                            detail: nil, chevron: false, action: nil)
                } else {
                    moreRow(icon: "trophy.fill",
                            title: model.upcomingChallenge.map { "\($0.title) starts tomorrow" } ?? "Want a push? Start a challenge",
                            detail: nil) {
                        model.tab = .challenges
                    }
                }
            }
            .card(radius: 16, shadow: false)
        }
    }

    private func moreRow(icon: String, title: String, detail: String?, chevron: Bool = true,
                         action: (() -> Void)?) -> some View {
        let row = HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.gold)
                .frame(width: 22)
            Text(title)
                .font(.app(15, .medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            if let detail {
                Text(detail).font(.app(14, .semibold)).foregroundStyle(Color.coral)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .contentShape(Rectangle())
        return Group {
            if let action {
                Button {
                    Haptics.tap()
                    action()
                } label: { row }
                .buttonStyle(PressableStyle())
            } else {
                row.accessibilityElement(children: .combine)
            }
        }
    }
}

/// Challenges tab: "Day X of 75", a coral bar and the percentage. The bar animates from the last day this phone
/// showed when the day goes up.
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
                            Text(r.type == .photo ? "Photo (recommended)" : "Honour tap")
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

struct WeekDot: Identifiable {
    enum Kind { case complete, save, miss, paused, today, future, empty }
    var date: LocalDate
    var kind: Kind
    var isToday: Bool
    var id: Int { date.ordinal }
}

/// S M T W T F S for the current week: ticked caramel circles for completed days, today ringed and labelled,
/// future days empty. (The streak lives in the header card.)
struct WeekDotsView: View {
    var days: [WeekDot]
    private var letters: [String] { ["S", "M", "T", "W", "T", "F", "S"] }

    var body: some View {
        HStack {
            ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                VStack(spacing: 5) {
                    dot(d)
                    Text(d.isToday ? "Today" : letters[i % 7])
                        .font(.app(d.isToday ? 12 : 13, d.isToday ? .bold : .medium))
                        .foregroundStyle(d.isToday ? Color.coral : Color.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(d.isToday ? "Today" : letters[i % 7]): \(label(d))")
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func dot(_ d: WeekDot) -> some View {
        let size: CGFloat = 30
        switch d.kind {
        case .complete:
            Circle().fill(Color.gold).frame(width: size, height: size)
                .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white))
                .overlay(Circle().stroke(Color.coral, lineWidth: d.isToday ? 2.5 : 0).padding(-3))
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

/// The one banner Today shows (see `TodayView.topBanner`).
struct TodayBanner: Identifiable {
    enum Kind {
        case pauseAnswer, tweakAnswer
        case note(NudgeFact)
        case info
    }
    var id: String
    var icon: String
    /// One line, in the header card.
    var text: String
    var title: String
    var detail: String
    var kind: Kind
}

/// A banner's full detail. A love note can be cleared or answered from here.
struct TodayBannerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var banner: TodayBanner
    var sendNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: banner.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.coral)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.peach))
                .padding(.top, 26)
            Text(banner.title)
                .font(.app(22, .bold))
                .foregroundStyle(Color.textPrimary)
            Text(banner.detail)
                .font(.app(17, isNote ? .semibold : .regular))
                .foregroundStyle(isNote ? Color.textPrimary : Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if case .note(let n) = banner.kind {
                PrimaryButton("Send one back") {
                    model.dismissNote(n)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { sendNote() }
                }
                TextLinkButton("Clear note", color: .coral) {
                    model.dismissNote(n)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            } else {
                PrimaryButton("OK") { dismiss() }
            }
        }
        .padding(.horizontal, Metrics.side)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ivory.ignoresSafeArea())
    }

    private var isNote: Bool {
        if case .note = banner.kind { return true }
        return false
    }
}
