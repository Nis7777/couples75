import SwiftUI

/// Step 11 (08): a full-width peach panel with the couple (arms crossed), cut at the hips; below it, their answers
/// echoed back, the reframe card and three tiny wins for tomorrow (copy in `MirrorCopy`).
struct MirrorView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        let d = model.draft
        OnboardingPage(step: d.stepNumber, back: back) {
            // Same layout (the couple in the peach panel, then the words), now echoing their answers. It scrolls
            // when the text is longer than the screen. Copy: MirrorCopy.
            ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    PeachPanelFill()
                    CoupleScene(left: model.draftScene,
                                right: model.sceneBBuilt,
                                leftPose: .stand, rightPose: .crossed, crop: 0.64, overlap: 0.02)
                        .padding(.top, 28)
                        .padding(.horizontal, 12)
                }
                .frame(height: 250)
                .padding(.horizontal, -Metrics.side)
                .padding(.top, 18)
                VStack(spacing: 10) {
                    Text(MirrorCopy.goalsLine(d.goals, partner: d.partnerName))
                        .font(.app(23, .bold))
                        .foregroundStyle(Color.textPrimary)
                    if let line = MirrorCopy.togetherLine(d.together) {
                        Text(line)
                            .font(.app(17, .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                    if d.longDistance == true {
                        Text(MirrorCopy.longDistanceLine)
                            .font(.app(17, .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.top, 20)
                Text(MirrorCopy.reframe)
                    .font(.app(17, .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .peachBox(radius: 18)
                    .padding(.top, 18)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tiny first wins for tomorrow")
                        .font(.app(17, .bold))
                        .foregroundStyle(Color.textPrimary)
                    ForEach(Array(MirrorCopy.tinyWins(d.goals, longDistance: d.longDistance == true).enumerated()), id: \.offset) { _, win in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.sage)
                            Text(win)
                                .font(.app(16, .medium))
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: 18, shadow: false)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
    }
}
