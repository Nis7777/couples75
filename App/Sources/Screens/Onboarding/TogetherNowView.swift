import SwiftUI

/// "Is {B} with you right now?" (after Names and the iPhone check). If yes, A hands the phone to B, who builds
/// an avatar and answers fitness and wake-up; B's answers go into the plan.
struct TogetherNowView: View {
    @Environment(AppModel.self) private var model
    var next: (Bool) -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 14) {
                CoupleBusts(left: model.draftScene, right: model.sceneBBuilt)
                    .frame(height: 140)
                    .padding(.top, 18)
                TitleText("Is \(model.draft.partnerName) with you right now?", size: 30)
                    .padding(.vertical, 6)
                OptionCard(title: "Yes, we're together", isSelected: model.draft.partnerWithYou == true, minHeight: 64) {
                    model.draft.partnerWithYou = true
                    autoAdvance { next(true) }
                }
                OptionCard(title: "No, I'll invite them", isSelected: model.draft.partnerWithYou == false, minHeight: 64) {
                    model.draft.partnerWithYou = false
                    autoAdvance { next(false) }
                }
                Spacer(minLength: 0)
            }
        } actions: {
            EmptyView()
        }
    }
}

/// "Hand the phone to {B}" / "Hand it back to {A}".
struct HandOffView: View {
    @Environment(AppModel.self) private var model
    var handTo: String
    var from: String
    var isHandBack: Bool
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: nil, back: back) {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                IconBadge(systemName: "iphone.and.arrow.forward", color: .coral)
                TitleText(isHandBack ? "Hand it back to \(handTo)" : "Hand the phone to \(handTo)", size: 30)
                BodyText(isHandBack
                         ? "Thanks, \(from)! \(handTo) finishes setting up your plan."
                         : "\(handTo), build your avatar and pick your own goals. It takes a minute.")
                CoupleScene(left: model.draftScene, right: model.sceneBBuilt, crop: 0.56, overlap: -0.05)
                    .frame(height: 200)
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("I'm \(handTo)") { next() }
        }
    }
}

struct PartnerAvatarStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        AvatarBuilderView(avatar: Binding(get: { model.draft.partnerAvatar ?? Avatar(characterID: "m1") },
                                          set: { model.draft.partnerAvatar = $0 }),
                          step: model.draft.stepNumber, back: back,
                          title: "\(model.draft.partnerName), build your avatar", next: {
                              if model.draft.partnerAvatar == nil { model.draft.partnerAvatar = Avatar(characterID: "m1") }
                              next()
                          })
    }
}

struct PartnerFitnessStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        FitnessPickerView(fitness: Binding(get: { model.draft.partnerFitness }, set: { model.draft.partnerFitness = $0 }),
                          step: model.draft.stepNumber, back: back, next: next)
    }
}

struct PartnerWakeStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        WakeTimePickerView(wakeTime: Binding(get: { model.draft.partnerWakeTime ?? "07:30" },
                                             set: { model.draft.partnerWakeTime = $0 }),
                           step: model.draft.stepNumber, back: back, next: {
                               if model.draft.partnerWakeTime == nil { model.draft.partnerWakeTime = "07:30" }
                               next()
                           })
    }
}

/// On A's phone, B picks B's own goals: B's habits come from B's answers, never from A's.
struct PartnerGoalsStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        GoalsPicker(goals: Binding(get: { model.draft.partnerGoals ?? [] }, set: { model.draft.partnerGoals = $0 }),
                    step: nil, total: nil,
                    title: "\(model.draft.partnerName), what do you want to level up?",
                    subtitle: "Pick two or more. These become your own daily habits.",
                    next: {
                        model.draft.generatePartnerPlan()
                        next()
                    }, back: back)
    }
}
