import SwiftUI

/// "Pick your character" (replaces 02): big preview on top, a 4×3 grid of busts below (women and men mixed).
/// Used by A (step 2) and B (joining step 3).
struct CharacterPickerView: View {
    @Binding var characterID: String
    var name: String
    var step: Int?
    var total: Int = OnboardingDraft.countedSteps.count
    var back: (() -> Void)?
    var next: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 16) {
                TitleText("Pick your character")
                    .padding(.top, 8)
                CharacterImage(characterID: characterID, pose: .stand)
                    .frame(maxHeight: .infinity)
                    .id(characterID)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .accessibilityLabel("Selected character \(characterLabel(characterID))")
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Characters.all, id: \.self) { id in
                        Button {
                            Haptics.tap()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { characterID = id }
                        } label: {
                            CharacterImage(characterID: id, pose: .bust)
                                .padding(6)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(Circle().fill(id == characterID ? Color.peach : Color.white))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(id == characterID ? Color.coral : Color.cardBorder,
                                                         lineWidth: id == characterID ? 2.5 : 1))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(characterLabel(id))
                        .accessibilityAddTraits(id == characterID ? .isSelected : [])
                    }
                }
                .padding(.bottom, 4)
            }
        } actions: {
            PrimaryButton("Looks like me") { next() }
        }
    }

    private func characterLabel(_ id: String) -> String {
        "Character \((Characters.all.firstIndex(of: id) ?? 0) + 1)"
    }
}

struct OnboardingCharacterStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        CharacterPickerView(characterID: $model.draft.characterID, name: model.draft.myName,
                            step: model.draft.stepNumber, back: back, next: next)
    }
}
