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
        // Swiping back from the left edge is allowed; there is no swipe forward (answers need a tap).
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { g in
                    guard g.startLocation.x < 28, g.translation.width > 80,
                          abs(g.translation.height) < 80 else { return }
                    edgeBack()
                })
    }

    private func edgeBack() {
        switch model.draft.step {
        case .hook, .building, .paywall, .stakes, .invite, .notifications: return
        case .handOff: go(.togetherNow, forward: false)
        case .partnerAvatar: go(.handOff, forward: false)
        case .partnerFitness: go(.partnerAvatar, forward: false)
        case .partnerWake: go(.partnerFitness, forward: false)
        case .partnerGoals: go(.partnerWake, forward: false)
        case .handBack: go(.partnerGoals, forward: false)
        case .planReveal: go(.level, forward: false)
        case .android: go(.partnerIPhone, forward: false)
        default: back()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.draft.step {
        case .hook: HookView(next: { go(.character) })
        case .character: OnboardingCharacterStep(next: { go(.names) }, back: back)
        case .names: NamesView(next: { go(.partnerIPhone) }, back: back)
        case .partnerIPhone: PartnerIPhoneView(next: { onIPhone in go(onIPhone ? .togetherNow : .android) }, back: back)
        case .togetherNow: TogetherNowView(next: { withYou in go(withYou ? .handOff : .together) }, back: back)
        case .handOff: HandOffView(handTo: model.draft.partnerName, from: model.draft.myName,
                                   isHandBack: false, next: { go(.partnerAvatar) }, back: { go(.togetherNow, forward: false) })
        case .partnerAvatar: PartnerAvatarStep(next: { go(.partnerFitness) }, back: { go(.handOff, forward: false) })
        case .partnerFitness: PartnerFitnessStep(next: { go(.partnerWake) }, back: { go(.partnerAvatar, forward: false) })
        case .partnerWake: PartnerWakeStep(next: { go(.partnerGoals) }, back: { go(.partnerFitness, forward: false) })
        case .partnerGoals: PartnerGoalsStep(next: { go(.handBack) }, back: { go(.partnerWake, forward: false) })
        case .handBack: HandOffView(handTo: model.draft.myName, from: model.draft.partnerName,
                                    isHandBack: true, next: { go(.together) }, back: { go(.partnerGoals, forward: false) })
        case .together: TogetherView(next: { go(.longDistance) },
                                     back: { go(model.draft.partnerWithYou == true ? .handBack : .togetherNow, forward: false) })
        case .longDistance: LongDistanceView(next: { go(.goals) }, back: back)
        case .goals: GoalsView(next: { go(.personal) }, back: back)
        case .personal: PersonalGoalsView(next: { go(.fitness) }, back: back)
        case .fitness: OnboardingFitnessStep(next: { go(.wakeUp) }, back: back)
        case .wakeUp: OnboardingWakeStep(next: { go(.quit) }, back: back)
        case .quit: QuitSliderView(next: { go(.mirror) }, back: back)
        case .mirror: MirrorView(next: { go(.level) }, back: back)
        case .level: OnboardingLevelStep(next: { go(.building) }, back: back)
        case .building:
            // The plan is generated ONCE here and stored in the draft (one source of truth).
            BuildingPlanView(next: { go(.planReveal) })
                .onAppear { model.draft.generatePlan() }
        case .planReveal: PlanRevealView(next: { go(.signPact) }, back: { go(.level, forward: false) })
        // Between the plan review and the paywall.
        case .signPact: SignPactView(next: { go(.coupleScore) }, back: back)
        case .coupleScore: CoupleScoreView(next: { go(.ninetyDays) }, back: back)
        case .ninetyDays: NinetyDayPlanView(next: { go(.notifySetup) }, back: back)
        // The reviews screen was removed: old saved progress on it continues at notifications.
        case .socialProof: NotificationSetupView(next: { go(.paywall) }, back: { go(.ninetyDays, forward: false) })
        case .notifySetup: NotificationSetupView(next: { go(.paywall) }, back: back)
        // Old drafts saved on the removed stakes step continue at the sign step.
        case .stakes: SignPactView(next: { go(.coupleScore) }, back: { go(.planReveal, forward: false) })
        // × on any paywall page opens the exit sheet; closing the paywall goes back to the plan, never into the app.
        case .paywall: PaywallAView(onClose: { go(.ninetyDays, forward: false) }, onDone: { go(.invite) })
        // Notifications are asked before the paywall now; the invite is the last step.
        case .invite: InviteView(next: { model.finishOnboarding() })
        case .notifications: InviteView(next: { model.finishOnboarding() })
        case .android: AndroidWaitlistView(done: { go(.hook, forward: false) }, back: { go(.partnerIPhone, forward: false) })
        }
    }

    private func go(_ step: OnboardingDraft.Step, forward: Bool = true) {
        AutoAdvanceGate.cancelPending()
        self.forward = forward
        model.draft.step = step
    }

    private func back() {
        let steps = model.draft.shownSteps
        guard let i = steps.firstIndex(of: model.draft.step), i > 0 else { return }
        var target = steps[i - 1]
        if target == .building { target = .level }
        go(target, forward: false)
    }
}

/// Shared page layout: "Step X of N" header (back chevron on its left), content, bottom actions.
struct OnboardingPage<Content: View, Actions: View>: View {
    var step: Int?
    var total: Int? = nil
    var back: (() -> Void)?
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let step {
                    OnboardingHeader(step: step, total: total ?? model.draft.stepTotal)
                        .padding(.horizontal, Metrics.side + 8)
                } else {
                    Color.clear.frame(height: back == nil ? 8 : 36)
                }
                if let back {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 44, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Back")
                    .padding(.leading, 8)
                    .offset(y: step == nil ? 0 : 9)
                }
            }
            .padding(.top, 10)

            // The content scrolls when it doesn't fit; the actions stay pinned to the bottom safe area.
            // Proposing the visible height as the ideal height keeps Spacers and flexible illustrations
            // filling the page when everything fits.
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    content
                        .padding(.horizontal, Metrics.side)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height, idealHeight: geo.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }

            BottomActions { actions }
        }
    }
}
