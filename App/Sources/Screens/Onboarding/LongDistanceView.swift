import SwiftUI

/// Step 6 (05): the couple's busts, "Long distance?", two tall cards side by side
/// (selected: peach, coral border, check in the top-right corner).
struct LongDistanceView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 18) {
                CoupleBusts(left: model.draftScene,
                            right: nil)
                    .frame(height: 140)
                    .padding(.top, 18)
                TitleText("Long distance?", size: 30)
                HStack(spacing: 14) {
                    choice("Yes", value: true)
                    choice("No", value: false)
                }
                .frame(maxHeight: 260)
                Text("Different time zones are fine. Each of you gets your own local days.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Continue", isEnabled: model.draft.longDistance != nil) { next() }
        }
    }

    private func choice(_ title: String, value: Bool) -> some View {
        let selected = model.draft.longDistance == value
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { model.draft.longDistance = value }
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: Metrics.optionRadius, style: .continuous)
                    .fill(selected ? Color.peach : Color.white)
                Text(title)
                    .font(.app(24, .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if selected {
                    CheckCircle(isOn: true, size: 26)
                        .padding(14)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .overlay(RoundedRectangle(cornerRadius: Metrics.optionRadius, style: .continuous)
                .stroke(selected ? Color.coral : Color.cardBorder, lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.optionRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
