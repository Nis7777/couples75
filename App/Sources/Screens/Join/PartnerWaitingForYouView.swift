import SwiftUI

/// Shown when B closes the paywall: B cannot start without subscribing.
struct PartnerWaitingForYouView: View {
    @Environment(AppModel.self) private var model
    var subscribe: () -> Void

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 16) {
                TitleText("\(model.nameA) is waiting for you")
                    .padding(.top, 24)
                BodyText("Day 1 starts the morning after you subscribe. Each of you has your own subscription.")
                CoupleScene(left: model.sceneA, right: nil)
                    .frame(maxHeight: .infinity)
            }
        } actions: {
            PrimaryButton("Subscribe") { subscribe() }
        }
    }
}
