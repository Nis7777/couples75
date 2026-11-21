import SwiftUI

/// Step 16 (13a): the cheer + trophy scene.
struct OutcomeView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 18) {
                TitleText("In 75 days, you'll be the couple who finished.", size: 28)
                    .padding(.top, 12)
                TrophyScene(left: SceneCharacter(characterID: model.draft.characterID, name: model.draft.myName),
                            right: SceneCharacter(characterID: "m1", name: model.draft.partnerName))
                    .frame(maxHeight: .infinity)
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
    }
}

/// Both characters cheering with the trophy in front (separate layers).
struct TrophyScene: View {
    var left: SceneCharacter
    var right: SceneCharacter?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                CoupleScene(left: left, right: right, leftPose: .cheer, rightPose: .cheer)
                TrophyImage()
                    .frame(width: geo.size.width * 0.26, height: geo.size.height * 0.3)
                    .padding(.bottom, 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You both cheering with a trophy")
    }
}
