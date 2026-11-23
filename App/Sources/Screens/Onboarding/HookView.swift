import SwiftUI

/// Step 1 (01_hook): two-line headline at the top, the couple large in the bottom half on a peach blob.
struct HookView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: 1, back: nil) {
            VStack(spacing: 0) {
                TitleText(Brand.tagline, size: 32)
                    .padding(.horizontal, 12)
                    .padding(.top, 36)
                BodyText(Brand.pitch, size: 17)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        PeachBlob()
                            .fill(Color.peach.opacity(0.85))
                            .frame(width: geo.size.width * 0.98, height: geo.size.height * 0.92)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, geo.size.height * 0.02)
                        CoupleScene(left: SceneCharacter(characterID: "w1", name: "Maya"),
                                    right: SceneCharacter(characterID: "m1", name: "Joao"),
                                    crop: 0.6, overlap: 0.04, alive: true)
                            .frame(width: geo.size.width + Metrics.side * 2)
                            .accessibilityLabel("A couple standing together")
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
        } actions: {
            PrimaryButton("Let's start") { next() }
            // An invited partner joins free with the code: they must never start (and pay for) a second couple.
            SecondaryButton("My partner invited me") {
                model.seenCodeEntry = false
                model.draft = OnboardingDraft()
            }
        }
    }
}
