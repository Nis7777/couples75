import SwiftUI

/// Step 7 (06): "What do you want to fix together?" Multi-select, at least 2.
struct GoalsView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 12) {
                TitleText("What do you want to fix together?")
                    .padding(.top, 24)
                Text("Pick two or more")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, 12)
                LazyVGrid(columns: columns, spacing: 12) {
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
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark" : g.icon)
                    .font(.system(size: 15, weight: .bold))
                Text(g.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.white : Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selected ? Color.coral : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? Color.coral : Color.cardBorder, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(g.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
