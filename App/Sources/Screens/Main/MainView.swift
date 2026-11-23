import SwiftUI

/// The app after onboarding: three tabs in a floating bar, plus the shown-once screens and locked states.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var openedCheckIn: CheckInFact?
    @State private var showPauseAnswer = false
    @State private var showTweakAnswer = false

    /// The couple's subscription lapsed during an active run and I'm the one who paid: renew (4.11).
    private var mustRenew: Bool { model.subscriptionLapsed && model.iAmPayer }
    /// The payer's subscription lapsed: the partner may take it over (the only paywall B ever sees).
    @State private var takeOverDismissed = false
    private var offerTakeOver: Bool { model.subscriptionLapsed && !model.iAmPayer && !takeOverDismissed }

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            Group {
                switch model.tab {
                case .today: TodayTab()
                case .challenges: ChallengesScreen()
                case .proof: ProofScreen()
                case .progress: ProgressScreen()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: FloatingTabBar.height + 22) }

            // Content scrolling under the bar fades out instead of peeking above its edge.
            LinearGradient(colors: [Color.ivory.opacity(0), Color.ivory.opacity(0.96), Color.ivory],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: FloatingTabBar.height + 34)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            FloatingTabBar(selection: $model.tab, proofBadge: model.proofBadge)
                .padding(.bottom, 6)
        }
        .screenBackground()
        .fullScreenCover(item: $model.presentedSave) { event in
            SaveUsedView(event: event) { model.presentedSave = nil }
        }
        .fullScreenCover(item: $model.presentedRoundEnd) { round in
            RoundEndView(round: round) { model.dismissRoundEnd() }
        }
        .sheet(item: $model.presentedRecap) { r in WeeklyRecapView(recap: r) }
        .fullScreenCover(isPresented: Binding(get: { model.presentedMilestone != nil && model.presentedDay75 == nil },
                                              set: { if !$0 { model.presentedMilestone = nil } })) {
            MilestoneView(day: model.presentedMilestone ?? 25)
        }
        .fullScreenCover(item: $model.presentedDay75) { round in
            Day75View(round: round)
        }
        .fullScreenCover(item: $model.presentedRankUp) { rank in
            RankUpView(rank: rank)
        }
        .fullScreenCover(isPresented: $model.presentedPartnerJoined) {
            PartnerJoinedView()
        }
        .fullScreenCover(isPresented: .constant(mustRenew && model.presentedDay75 == nil)) {
            PaywallView(variant: .renew, onClose: nil) { Task { await model.refresh() } }
        }
        .fullScreenCover(isPresented: Binding(get: { offerTakeOver && model.presentedDay75 == nil },
                                              set: { if !$0 { takeOverDismissed = true } })) {
            PaywallView(variant: .takeOver(payer: model.payerName), onClose: { takeOverDismissed = true }) {
                Task { await model.refresh() }
            }
        }
        .sheet(item: $openedCheckIn) { c in
            PartnerCheckInView(checkIn: c)
        }
        .sheet(isPresented: $showPauseAnswer) {
            if let p = model.pauseForMeToAnswer { PauseAnswerView(info: p) }
        }
        .sheet(isPresented: $showTweakAnswer) {
            if let t = model.tweakForMeToAnswer { TweakAnswerView(info: t) }
        }
        .onChange(of: model.deepLink) { _, link in handle(link) }
        .onAppear { handle(model.deepLink) }
    }

    private func handle(_ link: DeepLink?) {
        guard let link else { return }
        model.deepLink = nil
        switch link {
        case .today:
            model.tab = .today
        case .progress:
            model.tab = .progress
        case .proof:
            model.tab = .proof
        case .checkIn(let id):
            // "{name} finished {rule}. React?" opens that exact check-in in Proof.
            if let c = model.facts.checkIns.first(where: { $0.id == id }) {
                if c.memberID == model.meID { openedCheckIn = c } else { model.openInProof(id) }
            }
        case .pause:
            model.tab = .today
            if model.pauseForMeToAnswer != nil { showPauseAnswer = true }
        case .tweak:
            model.tab = .today
            if model.tweakForMeToAnswer != nil { showTweakAnswer = true }
        }
    }
}

/// Today tab: waiting / warm-up / today depending on the phase.
struct TodayTab: View {
    @Environment(AppModel.self) private var model
    @State private var showWarmup = false

    var body: some View {
        switch model.state.phase {
        case .waitingForPartner:
            if showWarmup {
                TodayView(warmup: true, onBack: { showWarmup = false })
            } else {
                WaitingView(startWarmup: { showWarmup = true })
            }
        case .warmup:
            TodayView(warmup: true)
        default:
            TodayView()
        }
    }
}
