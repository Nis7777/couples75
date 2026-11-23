#if DEBUG
import SwiftUI

// Every screen at iPhone SE (375×667) and iPhone Pro Max (430×932), side by side.
// Open this file in Xcode and use the canvas to check: nothing cropped, nothing behind the buttons
// or the tab bar, no text cut off.

/// Seeded Mock-mode data: Maya (A, the viewer) and Joao (B), Day 14, some check-ins, a partner photo.
enum PreviewData {
    static let a = "preview-a"
    static let b = "preview-b"

    static func facts(dayOffset: Int = 13, joinedB: Bool = true, partnerPhoto: Bool = true) -> Facts {
        let tz = TimeZone.current
        let now = Date()
        let today = LocalDate(now, in: tz)
        let day1 = today.adding(-dayOffset)
        let joined = day1.adding(-1).startInstant(in: tz).addingTimeInterval(10 * 3600)
        let periods = [SubscriptionPeriod(start: joined.addingTimeInterval(-86_400), end: now.addingTimeInterval(86_400 * 300))]
        var f = Facts()
        f.couple = CoupleFact(id: "preview-couple", createdAt: joined, ownerMemberID: a, title: "Maya's Pact",
                              invitedName: "Joao")
        var ma = MemberFact(id: a, role: .a, name: "Maya", characterID: "w1", timeZone: tz.identifier, wakeTime: "07:30",
                            fitnessLevel: .somewhatActive, joinedAt: joined.addingTimeInterval(-3600),
                            subscribedUntil: periods[0].end, subscriptionProduct: Brand.iapMonthly,
                            subscriptionPeriods: periods, leftAt: nil)
        ma.jacketColor = nil
        f.members = [ma]
        if joinedB {
            f.members.append(MemberFact(id: b, role: .b, name: "Joao", characterID: "m1", timeZone: tz.identifier,
                                        wakeTime: "07:00", fitnessLevel: .justStarting, joinedAt: joined,
                                        subscribedUntil: periods[0].end, subscriptionProduct: Brand.iapMonthly,
                                        subscriptionPeriods: periods, leftAt: nil))
        }
        f.roundConfigs = [RoundConfigFact(id: "cfg", fromRound: 1, mode: .maintenance, betText: "",
                                          rewardText: nil, createdBy: a, createdAt: joined)]
        let keys = PlanGenerator.ruleKeys(goals: [.fitness, .discipline])
        f.rules = PlanGenerator.rules(keys: keys, memberID: a, intensity: .standard, round: 1, now: joined)
            + PlanGenerator.rules(keys: keys, memberID: joinedB ? b : PendingPartner.id, intensity: .gentle, round: 1, now: joined)
        guard joinedB else { return f }
        // Days before today: both complete.
        for n in 0..<dayOffset {
            let d = day1.adding(n)
            let t = d.startInstant(in: tz).addingTimeInterval(12 * 3600)
            for r in f.rules {
                f.checkIns.append(CheckInFact(id: "c-\(r.id)-\(n)", memberID: r.memberID, ruleID: r.id, capturedAt: t,
                                              localDate: d.string, stampText: "DAY \(n + 1)", hasPhoto: false,
                                              isWarmup: false, uploadedAt: t.addingTimeInterval(30)))
            }
        }
        // Today: Maya 4/4, Joao 2/4 (one photo to react to).
        let t = now.addingTimeInterval(-3600)
        for r in f.rules where r.memberID == a {
            f.checkIns.append(CheckInFact(id: "today-\(r.id)", memberID: a, ruleID: r.id, capturedAt: t,
                                          localDate: today.string, stampText: "DAY \(dayOffset + 1)", hasPhoto: false,
                                          isWarmup: false, uploadedAt: t))
        }
        for r in f.rules.filter({ $0.memberID == b }).prefix(2) {
            f.checkIns.append(CheckInFact(id: "today-\(r.id)", memberID: b, ruleID: r.id, capturedAt: t,
                                          localDate: today.string, stampText: "DAY \(dayOffset + 1)",
                                          hasPhoto: partnerPhoto && r.type == .photo, isWarmup: false, uploadedAt: t))
        }
        return f
    }

    /// Day 14 facts plus a rule change from Joao waiting for Maya, and one of Maya's waiting for Joao.
    static func factsWithProposals() -> Facts {
        var f = facts()
        let now = Date()
        let joaoRule = RuleFact(id: "p-joao", memberID: b, fromRound: 1, position: 4, libraryKey: RuleFact.customKey,
                                title: "15 min guitar", type: .photo, createdAt: now, photoHint: "Photo of your guitar")
        let mayaRule = RuleFact(id: "p-maya", memberID: a, fromRound: 1, position: 3, libraryKey: "language",
                                title: "15 min language practice", type: .photo, createdAt: now)
        f.ruleProposals = [
            RuleProposalFact(id: "prop-joao", proposedBy: b, forMember: b, ruleJSON: joaoRule,
                             effectiveFrom: LocalDate(now, in: .current).adding(1).string, createdAt: now),
            RuleProposalFact(id: "prop-maya", proposedBy: a, forMember: a, ruleJSON: mayaRule,
                             effectiveFrom: nil, createdAt: now),
        ]
        return f
    }

    @MainActor
    static func model(_ facts: Facts = facts(), onboardingDone: Bool = true, tab: MainTab = .today) -> AppModel {
        let m = AppModel()
        m.draft = OnboardingDraft(step: .planReveal, myName: "Maya", partnerName: "Joao",
                                  avatar: Avatar(characterID: "w1"), goals: [.fitness, .discipline],
                                  fitness: .somewhatActive)
        m.draft.generatePlan()
        m.loadPreview(facts: facts, me: a, onboardingDone: onboardingDone)
        m.tab = tab
        return m
    }
}

/// Shows `content` at iPhone SE and iPhone Pro Max sizes.
struct DeviceSizes<Content: View>: View {
    var model: AppModel
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            device("iPhone SE", width: 375, height: 667)
            device("iPhone Pro Max", width: 430, height: 932)
        }
        .padding(24)
        .background(Color.gray.opacity(0.15))
    }

    private func device(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(name).font(.caption)
            ZStack {
                AppBackground()
                content()
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .environment(model)
            .font(.app(16))
            .tint(.coral)
        }
    }
}

@MainActor
private func screen<V: View>(_ model: AppModel, @ViewBuilder _ v: @escaping () -> V) -> some View {
    DeviceSizes(model: model, content: v)
}

@MainActor
private func screen<V: View>(@ViewBuilder _ v: @escaping () -> V) -> some View {
    DeviceSizes(model: PreviewData.model(), content: v)
}

private let noop: () -> Void = {}

// MARK: Onboarding (A)

#Preview("01 Hook", traits: .sizeThatFitsLayout) { screen { HookView(next: noop) } }
#Preview("02 Avatar builder", traits: .sizeThatFitsLayout) {
    screen { AvatarBuilderView(avatar: .constant(Avatar(characterID: "w1")), step: 2, back: noop, next: noop) }
}
#Preview("03 Names", traits: .sizeThatFitsLayout) { screen { NamesView(next: noop, back: noop) } }
#Preview("30 Partner iPhone", traits: .sizeThatFitsLayout) { screen { PartnerIPhoneView(next: { _ in }, back: noop) } }
#Preview("04 Together", traits: .sizeThatFitsLayout) { screen { TogetherView(next: noop, back: noop) } }
#Preview("05 Long distance", traits: .sizeThatFitsLayout) { screen { LongDistanceView(next: noop, back: noop) } }
#Preview("06 Goals", traits: .sizeThatFitsLayout) { screen { GoalsView(next: noop, back: noop) } }
#Preview("Personal goals", traits: .sizeThatFitsLayout) { screen { PersonalGoalsView(next: noop, back: noop) } }
#Preview("Is Joao with you?", traits: .sizeThatFitsLayout) { screen { TogetherNowView(next: { _ in }, back: noop) } }
#Preview("Hand the phone", traits: .sizeThatFitsLayout) {
    screen { HandOffView(handTo: "Joao", from: "Maya", isHandBack: false, next: noop, back: noop) }
}
#Preview("Partner avatar", traits: .sizeThatFitsLayout) { screen { PartnerAvatarStep(next: noop, back: noop) } }
#Preview("Partner fitness", traits: .sizeThatFitsLayout) { screen { PartnerFitnessStep(next: noop, back: noop) } }
#Preview("Partner wake-up", traits: .sizeThatFitsLayout) { screen { PartnerWakeStep(next: noop, back: noop) } }
#Preview("Fitness", traits: .sizeThatFitsLayout) {
    screen { FitnessPickerView(fitness: .constant(.somewhatActive), step: 8, back: noop, next: noop) }
}
#Preview("Wake-up", traits: .sizeThatFitsLayout) {
    screen { WakeTimePickerView(wakeTime: .constant("07:30"), step: 9, back: noop, next: noop) }
}
#Preview("07 Quit slider", traits: .sizeThatFitsLayout) { screen { QuitSliderView(next: noop, back: noop) } }
#Preview("08 Mirror", traits: .sizeThatFitsLayout) { screen { MirrorView(next: noop, back: noop) } }
#Preview("09 Level", traits: .sizeThatFitsLayout) {
    screen {
        LevelPickerView(level: .constant(.steady), left: SceneCharacter(characterID: "w1", name: "Maya"), right: nil,
                        step: 12, back: noop, next: noop)
    }
}
#Preview("10 Building plan", traits: .sizeThatFitsLayout) { screen { BuildingPlanView(next: noop) } }
#Preview("11 Plan reveal", traits: .sizeThatFitsLayout) { screen { PlanRevealView(next: noop, back: noop) } }
#Preview("11 Plan reveal, changed rule", traits: .sizeThatFitsLayout) {
    let m = PreviewData.model()
    m.draft.setChange(index: 1, forPartner: false,
                      idea: RuleIdea(title: "15 min guitar", type: .photo, libraryKey: nil, photoHint: nil))
    return screen(m) { PlanRevealView(next: noop, back: noop) }
}
#Preview("Change a rule", traits: .sizeThatFitsLayout) { screen { DraftRuleChangeSheet(index: 1) } }
#Preview("12 Stakes", traits: .sizeThatFitsLayout) { screen { StakesView(next: noop, back: noop) } }
#Preview("13a–13c Paywall", traits: .sizeThatFitsLayout) {
    screen { PaywallView(variant: .onboarding(partner: "Joao"), onClose: noop, onPurchased: noop) }
}
#Preview("13d Exit sheet", traits: .sizeThatFitsLayout) {
    screen { ExitSheet(monthlyPrice: "$12.99", tryMonthly: noop, sevenDayTrial: noop, keepYearly: noop, backToPlan: noop) }
}
#Preview("14 Invite", traits: .sizeThatFitsLayout) { screen { InviteView(next: noop) } }
#Preview("Notifications", traits: .sizeThatFitsLayout) { screen { NotificationPrimingView(next: noop) } }
#Preview("Android waitlist", traits: .sizeThatFitsLayout) { screen { AndroidWaitlistView(done: noop, back: noop) } }
#Preview("iCloud required", traits: .sizeThatFitsLayout) { screen { ICloudRequiredView() } }

// MARK: Joining (B)

#Preview("26 Code entry", traits: .sizeThatFitsLayout) { screen { CodeEntryView() } }
#Preview("25 Invited", traits: .sizeThatFitsLayout) { screen { InvitedView(next: noop) } }
#Preview("Accept or tweak", traits: .sizeThatFitsLayout) { screen { AcceptTweakView(next: noop, back: noop) } }
#Preview("Take over subscription", traits: .sizeThatFitsLayout) {
    screen { PaywallView(variant: .takeOver(payer: "Maya"), onClose: noop, onPurchased: noop) }
}
#Preview("I'm in", traits: .sizeThatFitsLayout) { screen { ImInView(next: noop) } }

// MARK: Main app

#Preview("15 Today", traits: .sizeThatFitsLayout) { screen { MainView() } }
#Preview("28 Warm-up", traits: .sizeThatFitsLayout) {
    screen(PreviewData.model(PreviewData.facts(joinedB: false))) { TodayView(warmup: true, onBack: noop) }
}
#Preview("27 Waiting", traits: .sizeThatFitsLayout) {
    screen(PreviewData.model(PreviewData.facts(joinedB: false))) { WaitingView(startWarmup: noop) }
}
#Preview("Proof", traits: .sizeThatFitsLayout) { screen(PreviewData.model(tab: .proof)) { MainView() } }
#Preview("Proof, plan changes", traits: .sizeThatFitsLayout) {
    screen(PreviewData.model(PreviewData.factsWithProposals(), tab: .proof)) { MainView() }
}
#Preview("Progress camera", traits: .sizeThatFitsLayout) { screen { ProgressCameraView() } }
#Preview("Milestone Day 25", traits: .sizeThatFitsLayout) { screen { MilestoneView(day: 25) } }
#Preview("Transformation (empty)", traits: .sizeThatFitsLayout) {
    screen { ScrollView { TransformationSection(takePhoto: {}).padding(20) } }
}
#Preview("Before / after", traits: .sizeThatFitsLayout) {
    let a = UIImage(systemName: "figure.stand") ?? UIImage()
    let b = UIImage(systemName: "figure.run") ?? UIImage()
    return screen { BeforeAfterSlider(before: a, after: b).frame(height: 360).padding(20) }
}
#Preview("Opening animation", traits: .sizeThatFitsLayout) { screen { SplashView(onDone: {}) } }
#Preview("Which rule?", traits: .sizeThatFitsLayout) {
    let rules = PlanGenerator.rules(keys: ["workout", "reading", "noSugar"], memberID: PreviewData.a,
                                    intensity: .standard, round: 1, now: Date())
    return screen { WhichRuleSheet(rules: rules, pick: { _ in }) }
}
#Preview("Our rules", traits: .sizeThatFitsLayout) {
    screen(PreviewData.model(PreviewData.factsWithProposals(), tab: .profile)) { OurRulesSheet() }
}
#Preview("Request a change", traits: .sizeThatFitsLayout) {
    let rule = PlanGenerator.rules(keys: ["water"], memberID: PreviewData.a, intensity: .standard, round: 1, now: Date())[0]
    return screen { RequestChangeSheet(rule: rule) }
}
#Preview("16 Progress", traits: .sizeThatFitsLayout) { screen(PreviewData.model(tab: .progress)) { MainView() } }
#Preview("18 Profile", traits: .sizeThatFitsLayout) { screen(PreviewData.model(tab: .profile)) { MainView() } }
#Preview("21 Camera", traits: .sizeThatFitsLayout) {
    screen {
        CheckInCameraView(rule: RuleFact(id: "r", memberID: PreviewData.a, fromRound: 1, position: 1,
                                         libraryKey: "workout", title: "45 min workout", type: .photo, createdAt: Date()))
    }
}
#Preview("22 Partner check-in", traits: .sizeThatFitsLayout) {
    let m = PreviewData.model()
    return screen(m) {
        if let c = m.facts.checkIns.first(where: { $0.memberID == PreviewData.b && $0.hasPhoto }) {
            PartnerCheckInView(checkIn: c)
        }
    }
}
#Preview("23 Save used", traits: .sizeThatFitsLayout) {
    screen {
        SaveUsedView(event: SaveEvent(id: "s", roundNumber: 1, memberID: PreviewData.b, dayNumber: 14,
                                      date: LocalDate(Date(), in: .current)), onDone: noop)
    }
}
#Preview("24 Round end", traits: .sizeThatFitsLayout) {
    let m = PreviewData.model()
    let failed: RoundState? = {
        guard var r = m.currentRound else { return nil }
        r.status = .failed
        r.failedOnDay = 23
        r.owes = [PreviewData.b]
        return r
    }()
    return screen(m) {
        if let failed { RoundEndView(round: failed, onDone: noop) }
    }
}
#Preview("19 Day 75", traits: .sizeThatFitsLayout) {
    let m = PreviewData.model()
    return screen(m) { if let r = m.currentRound { Day75View(round: r) } }
}
#Preview("29 Pause request", traits: .sizeThatFitsLayout) {
    let req = PauseRequestFact(id: "p", requestedBy: PreviewData.b, startDate: LocalDate(Date(), in: .current).string,
                               days: 2, reason: "Travelling", createdAt: Date())
    return screen {
        PauseAnswerView(info: PauseInfo(request: req, status: .pending,
                                        dates: [LocalDate(Date(), in: .current)], autoAcceptAt: Date()))
    }
}
#Preview("Pause (requester)", traits: .sizeThatFitsLayout) { screen { PauseRequestView() } }
#Preview("Honour sheet", traits: .sizeThatFitsLayout) {
    screen {
        HonourSheet(rule: RuleFact(id: "h", memberID: PreviewData.a, fromRound: 1, position: 3, libraryKey: "noSugar",
                                   title: "No sugar", type: .honour, createdAt: Date()))
    }
}
#Preview("Leave couple", traits: .sizeThatFitsLayout) { screen { LeaveCoupleSheet() } }
#Preview("Partner left", traits: .sizeThatFitsLayout) { screen { PartnerLeftView() } }
#Preview("Debug menu", traits: .sizeThatFitsLayout) { screen { DebugMenuView() } }
#endif
