import SwiftUI

/// Step 4 (30): "Is {partner} on iPhone?" Busts on top, two option cards, nothing preselected.
struct PartnerIPhoneView: View {
    @Environment(AppModel.self) private var model
    var next: (Bool) -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 14) {
                CoupleBusts(left: SceneCharacter(characterID: model.draft.characterID, name: model.draft.myName),
                            right: SceneCharacter(characterID: Characters.partnerPreview(for: model.draft.characterID),
                                                  name: model.draft.partnerName))
                    .frame(height: 140)
                    .padding(.top, 18)
                TitleText("Is \(model.draft.partnerName) on iPhone?", size: 30)
                    .padding(.vertical, 6)
                OptionCard(title: "Yes, iPhone", isSelected: model.draft.partnerOnIPhone == true, minHeight: 64) {
                    model.draft.partnerOnIPhone = true
                }
                OptionCard(title: "No, Android", isSelected: model.draft.partnerOnIPhone == false, minHeight: 64) {
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

extension Characters {
    /// A stand-in look for the partner before they pick (the opposite preset of A's, or m1/w1).
    static func partnerPreview(for mine: String) -> String {
        mine.hasPrefix("w") ? "m1" : "w1"
    }
}
