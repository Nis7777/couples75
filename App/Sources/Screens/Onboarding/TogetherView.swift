import SwiftUI

/// Step 5 (04): "How long have you been together?" Three tall cards that share the free height.
struct TogetherView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    private let options = ["<1 yr", "1–3 yrs", "3+ yrs"]

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 14) {
                TitleText("How long have you been together?", size: 28)
                    .padding(.top, 26)
                    .padding(.bottom, 10)
                ForEach(options, id: \.self) { o in
                    OptionCard(title: o, isSelected: model.draft.together == o, minHeight: 72) {
                        model.draft.together = o
                    }
                    .expanding()
                    .frame(maxHeight: 122)
                }
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Continue", isEnabled: model.draft.together != nil) { next() }
        }
    }
}
