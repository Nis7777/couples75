import SwiftUI

/// B's last step: hold to sign, then the couple's Pact Card with B's signature writing itself on next to A's.
/// Day 1 is the next local day (no subscription needed: A's covers both).
struct ImInView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    @State private var saving = false
    @State private var signed = false

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            if signed {
                VStack(spacing: 14) {
                    SmallLabel(text: "It's official")
                        .padding(.top, 30)
                    TitleText("You signed \(model.nameA)'s pact", size: 30)
                    PactCardReveal(data: model.pactCard, signA: false, signB: true)
                        .padding(.vertical, 12)
                    BodyText("Day 1 starts tomorrow. Today is a free warm-up: try a check-in, it doesn't count.")
                        .padding(.horizontal, 12)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                VStack(spacing: 16) {
                    SmallLabel(text: "All set")
                        .padding(.top, 24)
                    TitleText("\(model.nameA) & \(model.nameB)", size: 30)
                    BodyText("Day 1 starts tomorrow. Today is a free warm-up day.")
                    CoupleScene(left: model.sceneA,
                                right: SceneCharacter(avatar: model.joinDraft?.avatar ?? Avatar(characterID: "m1"),
                                                      name: model.nameB),
                                leftPose: .cheer, rightPose: .cheer, crop: 0.72, overlap: -0.05, alive: true)
                        .padding(.horizontal, -8)
                        .frame(maxHeight: .infinity)
                }
            }
        } actions: {
            if signed {
                PrimaryButton("Continue") { next() }
            } else {
                VStack(spacing: 4) {
                    Text("Hold to sign").font(.app(18, .bold)).foregroundStyle(Color.textPrimary)
                    Text("We do this together").font(.app(14)).foregroundStyle(Color.textSecondary)
                    HoldToSignButton(enabled: !saving) {
                        Task {
                            saving = true
                            let ok = await model.finishJoining()
                            saving = false
                            if ok { withAnimation(.open(0.35)) { signed = true } }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}
