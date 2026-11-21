import SwiftUI

/// Step 10 (07): "How often do you start something together and quit?"
struct QuitSliderView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    private let labels = ["Rarely", "Sometimes", "Usually", "Always"]

    private var currentLabel: String {
        let i = min(max(Int(model.draft.quitFrequency.rounded()), 0), labels.count - 1)
        return labels[i]
    }

    var body: some View {
        @Bindable var model = model
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 24) {
                TitleText("How often do you start something together and quit?")
                    .padding(.top, 24)
                Spacer(minLength: 0)
                VStack(spacing: 18) {
                    Text(currentLabel)
                        .font(.rounded(22))
                        .foregroundStyle(Color.coral)
                    Slider(value: $model.draft.quitFrequency, in: 0...3, step: 1)
                        .tint(.coral)
                        .accessibilityLabel("How often you quit")
                        .accessibilityValue(currentLabel)
                        .onChange(of: model.draft.quitFrequency) { _, _ in Haptics.tap() }
                    HStack {
                        ForEach(labels, id: \.self) { l in
                            Text(l)
                                .font(.app(12, .medium))
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(20)
                .card()
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
    }
}
