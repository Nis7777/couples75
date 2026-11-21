import SwiftUI

/// Step 7 (06): 2-column grid of big rounded cards; selected ones are coral with a white check.
struct GoalsView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 8) {
                TitleText("What do you want to fix together?", size: 30)
                    .padding(.top, 26)
                Text("Pick two or more")
                    .font(.app(17))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, 14)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Goal.allCases) { g in goalChip(g) }
                }
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Continue", isEnabled: model.draft.goals.count >= 2) { next() }
        }
    }

    private func goalChip(_ g: Goal) -> some View {
        let selected = model.draft.goals.contains(g)
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                if selected { model.draft.goals.removeAll { $0 == g } } else { model.draft.goals.append(g) }
            }
        } label: {
            HStack(spacing: 10) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(g.title)
                    .font(.app(19, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.white : Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 86)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(selected ? Color.coral : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(selected ? Color.coral : Color.cardBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(g.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
