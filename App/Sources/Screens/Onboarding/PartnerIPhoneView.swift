import SwiftUI

/// Step 4 (30): "Is {partner} on iPhone?" Nothing preselected; Continue disabled until one is picked.
struct PartnerIPhoneView: View {
    @Environment(AppModel.self) private var model
    var next: (Bool) -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 14) {
                CoupleScene(left: SceneCharacter(characterID: model.draft.characterID, name: model.draft.myName),
                            right: nil)
                    .frame(maxHeight: 220)
                    .padding(.top, 8)
                TitleText("Is \(model.draft.partnerName) on iPhone?")
                    .padding(.bottom, 8)
                OptionCard(title: "Yes, iPhone", isSelected: model.draft.partnerOnIPhone == true) {
                    model.draft.partnerOnIPhone = true
                }
                OptionCard(title: "No, Android", isSelected: model.draft.partnerOnIPhone == false) {
                    model.draft.partnerOnIPhone = false
                }
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Continue", isEnabled: model.draft.partnerOnIPhone != nil) {
                next(model.draft.partnerOnIPhone ?? true)
            }
        }
    }
}
