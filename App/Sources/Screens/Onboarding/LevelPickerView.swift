import SwiftUI

/// Step 12 (09): "How hard should it be?" with both characters stretching above the title,
/// then Gentle / Couples 75 (Most popular, preselected) / Hard mode. Also used by "Start round 2".
struct LevelPickerView: View {
    @Binding var level: Level
    var left: SceneCharacter
    /// nil: the partner hasn't built an avatar yet (dashed outline).
    var right: SceneCharacter?
    var step: Int?
    var total: Int? = nil
    var back: (() -> Void)?
    var buttonTitle = "Continue"
    /// Onboarding moves on by itself after a tap; "Start round 2" keeps its button.
    var autoAdvances = true
    var next: () -> Void

    private func pick(_ l: Level) {
        level = l
        if autoAdvances { autoAdvance(next) }
    }

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 12) {
                    CoupleScene(left: left, right: right, leftPose: .stretch, rightPose: .stretch,
                                crop: 1, overlap: 0.04)
                        .frame(height: 190)
                        .padding(.top, 14)
                    TitleText("How hard should it be?", size: 30)
                        .padding(.vertical, 6)
                    OptionCard(title: Level.gentle.title, subtitle: "Lighter daily rules · 3 saves",
                               isSelected: level == .gentle, minHeight: 72) {
                        pick(.gentle)
                    }
                    OptionCard(title: Level.couples75.title, subtitle: "The full plan · 3 shared saves",
                               isSelected: level == .couples75, minHeight: 72) {
                        pick(.couples75)
                    } trailing: {
                        Pill(text: "Most popular", fill: .gold, size: 13)
                    }
                    OptionCard(title: Level.hard.title, subtitle: "The full plan · no saves, one miss restarts",
                               isSelected: level == .hard, minHeight: 72) {
                        pick(.hard)
                    }
            }
            .padding(.bottom, 16)
        } actions: {
            if !autoAdvances { PrimaryButton(buttonTitle) { next() } }
        }
    }
}

struct OnboardingLevelStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        // Couples 75 is preselected, so this step keeps a pinned Continue button instead of auto-advancing.
        LevelPickerView(level: $model.draft.level, left: model.draftScene, right: model.sceneBBuilt,
                        step: model.draft.stepNumber, back: back, autoAdvances: false, next: next)
    }
}
