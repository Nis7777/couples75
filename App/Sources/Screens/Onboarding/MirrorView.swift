import SwiftUI

/// Step 11 (08). Copy kept exactly.
struct MirrorView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 20) {
                CoupleScene(left: SceneCharacter(characterID: model.draft.characterID, name: model.draft.myName),
                            right: SceneCharacter(characterID: "m1", name: model.draft.partnerName),
                            leftPose: .crossed, rightPose: .crossed)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 12)
                Text("Most couples quit before it gets hard. Not because they're weak. Because no one's watching.")
                    .font(.rounded(22))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
    }
}
