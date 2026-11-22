import SwiftUI

/// Person B joining (section 3.5). B never sees A's couple quiz.
struct JoinFlow: View {
    @Environment(AppModel.self) private var model
    @State private var forward = true

    private var step: JoinDraft.Step { model.joinDraft?.step ?? .invited }

    var body: some View {
        ZStack {
            content
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
        }
        .animation(.easeInOut(duration: 0.32), value: step)
        .screenBackground()
        .onAppear {
            if model.joinDraft == nil { model.joinDraft = JoinDraft() }
            // Resume after relaunch: a member who already subscribed and joined goes to notifications.
            if let me = model.me, me.joinedAt != nil, step != .notifications { go(.notifications) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .invited:
            // If B built the avatar on A's phone, it's already made: go straight to the plan.
            InvitedView(next: { go(model.joinDraft?.prebuilt == true ? .tweak : .character) })
        case .character:
            JoinCharacterStep(next: { go(.fitness) }, back: { go(.invited, forward: false) })
        case .fitness:
            JoinFitnessStep(next: { go(.wakeUp) }, back: { go(.character, forward: false) })
        case .wakeUp:
            JoinWakeStep(next: { go(.tweak) }, back: { go(.fitness, forward: false) })
        case .tweak:
            // One subscription covers both: B never sees a paywall.
            AcceptTweakView(next: { go(.imIn) }, back: { go(.wakeUp, forward: false) })
        case .imIn:
            ImInView(next: { go(.notifications) })
        case .notifications:
            NotificationPrimingView(next: { model.finishOnboarding() })
        }
    }

    private func go(_ s: JoinDraft.Step, forward: Bool = true) {
        AutoAdvanceGate.cancelPending()
        self.forward = forward
        model.joinDraft?.step = s
    }
}

/// B's step numbers (character, fitness, wake-up, plan).
enum JoinSteps {
    static let total = 4
}

struct JoinCharacterStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        AvatarBuilderView(avatar: Binding(get: { model.joinDraft?.avatar ?? Avatar(characterID: "m1") },
                                          set: { model.joinDraft?.avatar = $0 }),
                          step: 1, total: JoinSteps.total, back: back, next: next)
    }
}

struct JoinFitnessStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        FitnessPickerView(fitness: Binding(get: { model.joinDraft?.fitness }, set: { model.joinDraft?.fitness = $0 }),
                          step: 2, total: JoinSteps.total, back: back, next: next)
    }
}

struct JoinWakeStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        WakeTimePickerView(wakeTime: Binding(get: { model.joinDraft?.wakeTime ?? "07:30" },
                                             set: { model.joinDraft?.wakeTime = $0 }),
                           step: 3, total: JoinSteps.total, back: back, next: next)
    }
}
