import SwiftUI

/// Step 1 (01_hook).
struct HookView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: 1, back: nil) {
            VStack(spacing: 20) {
                TitleText(Brand.tagline, size: 32)
                    .padding(.top, 16)
                CoupleScene(left: SceneCharacter(characterID: "w1", name: "Maya"),
                            right: SceneCharacter(characterID: "m1", name: "Joao"))
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel("A couple standing together")
            }
        } actions: {
            PrimaryButton("Let's start") { next() }
            TextLinkButton("Did your partner invite you?") {
                model.seenCodeEntry = false
                model.draft = OnboardingDraft()
            }
        }
    }
}
