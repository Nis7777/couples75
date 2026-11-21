import SwiftUI

/// "When do you usually wake up?" (A step 9, B joining): a time wheel in a card, default 07:30.
struct WakeTimePickerView: View {
    @Binding var wakeTime: String
    var step: Int?
    var total: Int = OnboardingDraft.countedSteps.count
    var back: (() -> Void)?
    var buttonTitle = "Continue"
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 10) {
                TitleText("When do you usually wake up?", size: 30)
                    .padding(.top, 26)
                Text("We'll remind you when your day starts.")
                    .font(.app(17))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 12)
                VStack(spacing: 0) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.gold)
                        .padding(.top, 18)
                        .accessibilityHidden(true)
                    DatePicker("Wake-up time",
                               selection: Binding(get: { ClockTime.date(from: wakeTime) },
                                                  set: { wakeTime = ClockTime.string(from: $0) }),
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity)
                .card()
                Spacer(minLength: 12)
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton(buttonTitle) { next() }
        }
    }
}

struct OnboardingWakeStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        WakeTimePickerView(wakeTime: $model.draft.wakeTime, step: model.draft.stepNumber, back: back, next: next)
    }
}
