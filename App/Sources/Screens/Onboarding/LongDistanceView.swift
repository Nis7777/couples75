import SwiftUI

/// Step 6 (05): "Long distance?"
struct LongDistanceView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 14) {
                CoupleScene(left: SceneCharacter(characterID: model.draft.characterID, name: model.draft.myName),
                            right: nil)
                    .frame(maxHeight: 200)
                    .padding(.top, 8)
                TitleText("Long distance?")
                    .padding(.bottom, 8)
                HStack(spacing: 12) {
                    choice("Yes", value: true)
                    choice("No", value: false)
                }
                Text("Different time zones are fine. Each of you gets your own local days.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
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
            VStack(spacing: 12) {
                CheckCircle(isOn: selected)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selected ? Color.peach : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? Color.coral : Color.cardBorder, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
