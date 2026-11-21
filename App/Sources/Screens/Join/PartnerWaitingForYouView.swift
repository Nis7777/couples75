import SwiftUI

/// Shown when B closes the paywall: B cannot start without subscribing.
struct PartnerWaitingForYouView: View {
    @Environment(AppModel.self) private var model
    var subscribe: () -> Void

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 16) {
                TitleText("\(model.nameA) is waiting for you", size: 30)
                    .padding(.top, 24)
                BodyText("Day 1 starts the morning after you subscribe. Each of you has your own subscription.")
                CoupleScene(left: model.sceneA, right: nil, crop: 0.6, overlap: 0, alignment: .top, fillHeight: true)
                    .padding(.horizontal, -8)
                    .frame(maxHeight: .infinity)
            }
        } actions: {
            PrimaryButton("Subscribe") { subscribe() }
        }
    }
}
