import SwiftUI

/// Step 12 (09): "Pick your level". Also used by "Start round 2".
struct LevelPickerView: View {
    @Binding var level: Level
    var step: Int?
    var total: Int = OnboardingDraft.countedSteps.count
    var back: (() -> Void)?
    var buttonTitle = "Continue"
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 14) {
                TitleText("Pick your level")
                    .padding(.vertical, 24)
                OptionCard(title: Level.easy.title, subtitle: "Lighter rules, same 3 saves.", isSelected: level == .easy) {
                    level = .easy
                }
                OptionCard(title: Level.couples75.title, subtitle: "3 shared saves.", isSelected: level == .couples75) {
                    level = .couples75
                } trailing: {
                    Pill(text: "Most popular", fill: .gold)
                }
                OptionCard(title: Level.hard.title, subtitle: "No saves. One miss restarts the round.",
                           isSelected: level == .hard) {
                    level = .hard
                }
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton(buttonTitle) { next() }
        }
    }
}

struct OnboardingLevelStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        LevelPickerView(level: $model.draft.level, step: model.draft.stepNumber, back: back, next: next)
    }
}
