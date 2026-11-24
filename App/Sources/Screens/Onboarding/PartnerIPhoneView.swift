import SwiftUI

/// Step 4 (30): "Is {partner} on iPhone?" Busts on top, two option cards, nothing preselected.
struct PartnerIPhoneView: View {
    @Environment(AppModel.self) private var model
    var next: (Bool) -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 14) {
                CoupleBusts(left: model.draftScene,
                            right: model.sceneBBuilt)
                    .frame(height: 140)
                    .padding(.top, 18)
                TitleText("Is \(model.draft.partnerName) on iPhone?", size: 30)
                    .padding(.vertical, 6)
                OptionCard(title: "Yes, iPhone", isSelected: model.draft.partnerOnIPhone == true, minHeight: 64) {
                    model.draft.partnerOnIPhone = true
                    autoAdvance { next(true) }
                }
                OptionCard(title: "No, they don't have an iPhone", isSelected: model.draft.partnerOnIPhone == false, minHeight: 64) {
                    model.draft.partnerOnIPhone = false
                    autoAdvance { next(false) }
                }
                Spacer(minLength: 0)
            }
        } actions: {
            EmptyView()
        }
    }
}
