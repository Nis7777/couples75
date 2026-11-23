import SwiftUI

/// Step 11 (08): a full-width peach panel with the couple (arms crossed), cut at the hips; the line below. Copy kept exactly.
struct MirrorView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    PeachPanelFill()
                    CoupleScene(left: model.draftScene,
                                right: nil,
                                leftPose: .stand, rightPose: .crossed, crop: 0.64, overlap: 0.02)
                        .padding(.top, 28)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, -Metrics.side)
                .padding(.top, 18)
                .frame(maxHeight: .infinity)
                Text("Most people quit their habits alone. Not because they're weak. Because no one's watching. Do it as a team.")
                    .font(.app(23, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
    }
}
