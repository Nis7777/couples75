import SwiftUI

/// B step 7: "I'm in" → Day 1 is the next local day.
struct ImInView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    @State private var saving = false

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 16) {
                SmallLabel(text: "All set")
                    .padding(.top, 24)
                TitleText("\(model.nameA) & \(model.nameB)")
                BodyText("Day 1 starts tomorrow morning. Today is a free warm-up day.")
                CoupleScene(left: model.sceneA,
                            right: SceneCharacter(characterID: model.joinDraft?.characterID ?? "m1", name: model.nameB),
                            leftPose: .cheer, rightPose: .cheer)
                    .frame(maxHeight: .infinity)
            }
        } actions: {
            PrimaryButton("I'm in", isLoading: saving) {
                Task {
                    saving = true
                    let ok = await model.finishJoining()
                    saving = false
                    if ok {
                        Haptics.success()
                        next()
                    }
                }
            }
        }
    }
}
