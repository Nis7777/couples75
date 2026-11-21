import SwiftUI

/// Step 16 (13a): the cheering couple with the trophy, a gold ribbon across and a gold "Day 75" ring badge.
struct OutcomeView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 10) {
                TitleText("In 75 days, you'll be the couple who finished.", size: 30)
                    .padding(.top, 28)
                    .padding(.horizontal, 8)
                TrophyScene(left: SceneCharacter(characterID: model.draft.characterID, name: model.draft.myName),
                            right: SceneCharacter(characterID: Characters.partnerPreview(for: model.draft.characterID),
                                                  name: model.draft.partnerName))
                    .padding(.horizontal, -Metrics.side)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 8)
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
    }
}
