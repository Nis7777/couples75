import SwiftUI

/// "Your fitness level" (A step 8, B joining). Same style as 04: tall cards sharing the free height.
struct FitnessPickerView: View {
    @Binding var fitness: FitnessLevel?
    var step: Int?
    var total: Int = OnboardingDraft.countedSteps.count
    var back: (() -> Void)?
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 14) {
                TitleText("Your fitness level", size: 30)
                    .padding(.top, 26)
                    .padding(.bottom, 10)
                ForEach(FitnessLevel.allCases, id: \.self) { f in
                    OptionCard(title: f.title, subtitle: subtitle(f), isSelected: fitness == f, minHeight: 76) {
                        fitness = f
                    }
                    .expanding()
                    .frame(maxHeight: 118)
                }
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Continue", isEnabled: fitness != nil) { next() }
        }
    }

    private func subtitle(_ f: FitnessLevel) -> String {
        guard let workout = RuleLibrary.rule("workout") else { return "" }
        return "e.g. \(workout.title(for: f.intensity))"
    }
}

struct OnboardingFitnessStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        FitnessPickerView(fitness: $model.draft.fitness, step: model.draft.stepNumber, back: back, next: next)
    }
}
