import SwiftUI

/// "Pick your character" (replaces 02): big preview on a gold pedestal, then a white card holding
/// a 4×3 grid of busts (women and men mixed) and the button.
/// Used by A (step 2) and B (joining).
struct CharacterPickerView: View {
    @Binding var characterID: String
    var name: String
    var step: Int?
    var total: Int = OnboardingDraft.countedSteps.count
    var back: (() -> Void)?
    var next: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 10) {
                TitleText("Pick your character", size: 28)
                    .padding(.top, 14)
                ZStack(alignment: .bottom) {
                    Pedestal()
                        .frame(width: 170, height: 34)
                    CharacterImage(characterID: characterID, pose: .stand)
                        .padding(.bottom, 16)
                        .id(characterID)
                        .transition(.scale(scale: 0.94, anchor: .bottom).combined(with: .opacity))
                        .accessibilityLabel("Selected character \(characterLabel(characterID))")
                }
                .frame(maxHeight: .infinity)
                .padding(.bottom, 4)
            }
        } actions: {
            VStack(spacing: 14) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Characters.all, id: \.self) { id in
                        tile(id)
                    }
                }
                PrimaryButton("Looks like me") { next() }
            }
            .padding(14)
            .card(radius: 24)
        }
    }

    private func tile(_ id: String) -> some View {
        let selected = id == characterID
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { characterID = id }
        } label: {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.peach : Color.ivory)
                Image(Characters.assetName(id, .bust))
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? Color.gold : Color.cardBorder, lineWidth: selected ? 2.5 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(characterLabel(id))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func characterLabel(_ id: String) -> String {
        "Character \((Characters.all.firstIndex(of: id) ?? 0) + 1)"
    }
}

/// The gold disc the preview stands on.
struct Pedestal: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0xC98B33))
                .offset(y: 6)
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0xF0C178), Color.gold], startPoint: .top, endPoint: .bottom))
        }
        .accessibilityHidden(true)
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
