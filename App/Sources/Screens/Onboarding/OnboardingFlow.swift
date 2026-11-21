import SwiftUI

/// Person A's onboarding (section 3.1). One screen per step; push-style slide + fade between steps.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var forward = true

    var body: some View {
        ZStack {
            content
                .id(model.draft.step)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
        }
        .animation(.easeInOut(duration: 0.32), value: model.draft.step)
        .screenBackground()
    }

    @ViewBuilder
    private var content: some View {
        switch model.draft.step {
        case .hook: HookView(next: { go(.character) })
        case .character: OnboardingCharacterStep(next: { go(.names) }, back: back)
        case .names: NamesView(next: { go(.partnerIPhone) }, back: back)
        case .partnerIPhone: PartnerIPhoneView(next: { onIPhone in go(onIPhone ? .together : .android) }, back: back)
        case .together: TogetherView(next: { go(.longDistance) }, back: back)
        case .longDistance: LongDistanceView(next: { go(.goals) }, back: back)
        case .goals: GoalsView(next: { go(.fitness) }, back: back)
        case .fitness: OnboardingFitnessStep(next: { go(.wakeUp) }, back: back)
        case .wakeUp: OnboardingWakeStep(next: { go(.quit) }, back: back)
        case .quit: QuitSliderView(next: { go(.mirror) }, back: back)
        case .mirror: MirrorView(next: { go(.level) }, back: back)
        case .level: OnboardingLevelStep(next: { go(.building) }, back: back)
        case .building: BuildingPlanView(next: { go(.planReveal) })
        case .planReveal: PlanRevealView(next: { go(.stakes) }, back: { go(.level, forward: false) })
        case .stakes: StakesView(next: { go(.outcome) }, back: back)
        case .outcome: OutcomeView(next: { go(.paywall) }, back: back)
        case .paywall: PaywallAView(onClose: { go(.planReveal, forward: false) }, onDone: { go(.invite) })
        case .invite: InviteView(next: { go(.notifications) })
        case .notifications: NotificationPrimingView(next: { model.finishOnboarding() })
        case .android: AndroidWaitlistView(done: { go(.hook, forward: false) }, back: { go(.partnerIPhone, forward: false) })
        }
    }

    private func go(_ step: OnboardingDraft.Step, forward: Bool = true) {
        self.forward = forward
        model.draft.step = step
    }

    private func back() {
        let steps = OnboardingDraft.countedSteps
        guard let i = steps.firstIndex(of: model.draft.step), i > 0 else { return }
        var target = steps[i - 1]
        if target == .building { target = .level }
        go(target, forward: false)
    }
}

/// Shared page layout: back chevron + "Step X of N" header, content, bottom actions.
struct OnboardingPage<Content: View, Actions: View>: View {
    var step: Int?
    var total: Int = OnboardingDraft.countedSteps.count
    var back: (() -> Void)?
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let back {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
                if let step {
                    OnboardingHeader(step: step, total: total)
                } else {
                    Spacer()
                }
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            content
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomActions { actions }
        }
    }
}
