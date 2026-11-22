import SwiftUI

/// B's last step: review and hold to sign. Day 1 is the next local day (no subscription needed: A's covers both).
struct ImInView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    @State private var saving = false

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 16) {
                SmallLabel(text: "All set")
                    .padding(.top, 24)
                TitleText("\(model.nameA) & \(model.nameB)", size: 30)
                BodyText("Day 1 starts tomorrow morning. Today is a free warm-up day.")
                CoupleScene(left: model.sceneA,
                            right: SceneCharacter(avatar: model.joinDraft?.avatar ?? Avatar(characterID: "m1"), name: model.nameB),
                            leftPose: .cheer, rightPose: .cheer, crop: 0.72, overlap: -0.05)
                    .padding(.horizontal, -8)
                    .frame(maxHeight: .infinity)
            }
        } actions: {
            // B signs the plan, like A did on "Set the stakes".
            VStack(spacing: 4) {
                Text("Hold to sign").font(.app(18, .bold)).foregroundStyle(Color.textPrimary)
                Text("We finish this together").font(.app(14)).foregroundStyle(Color.textSecondary)
                HoldToSignButton(enabled: !saving) {
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
                .padding(.top, 8)
            }
        }
    }
}
