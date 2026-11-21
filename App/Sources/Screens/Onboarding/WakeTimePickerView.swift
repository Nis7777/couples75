import SwiftUI

/// "When do you usually wake up?" (A step 9, B joining step 4): a time wheel, default 07:30.
struct WakeTimePickerView: View {
    @Binding var wakeTime: String
    var step: Int?
    var total: Int = OnboardingDraft.countedSteps.count
    var back: (() -> Void)?
    var buttonTitle = "Continue"
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 14) {
                TitleText("When do you usually wake up?")
                    .padding(.top, 24)
                Text("We'll remind you when your day starts.")
                    .font(.app(15))
                    .foregroundStyle(Color.textSecondary)
                DatePicker("Wake-up time",
                           selection: Binding(get: { ClockTime.date(from: wakeTime) },
                                              set: { wakeTime = ClockTime.string(from: $0) }),
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .card()
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
