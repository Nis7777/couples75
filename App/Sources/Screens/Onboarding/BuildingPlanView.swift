import SwiftUI

/// Step 13 (10): a big stretching couple, then a checklist card with green checks and a spinner on the active line.
/// ~3 seconds, auto-advances.
struct BuildingPlanView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    @State private var done = 0
    private let items = ["Matching habits to your goals…", "Sizing them for each of you", "Lighting your streak"]

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: nil) {
            VStack(spacing: 24) {
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.peachDeep.opacity(0.6))
                        .frame(height: 22)
                        .padding(.horizontal, 24)
                    CoupleScene(left: model.draftScene,
                                right: nil,
                                leftPose: .stretch, rightPose: .stretch, crop: 1, overlap: 0.08)
                        .padding(.bottom, 8)
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, text in
                        HStack(spacing: 14) {
                            ZStack {
                                if i < done {
                                    CheckCircle(isOn: true, color: .sage, size: 28)
                                        .transition(.scale.combined(with: .opacity))
                                } else if i == done {
                                    ProgressView().tint(.gold).scaleEffect(1.1)
                                } else {
                                    Circle().stroke(Color.radio, lineWidth: 1.8)
                                }
                            }
                            .frame(width: 28, height: 28)
                            Text(text)
                                .font(.app(18, i < done ? .semibold : .medium))
                                .foregroundStyle(i < done ? Color.textPrimary : Color.textSecondary.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .padding(.horizontal, 10)
                .padding(.bottom, 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Building your plan")
            }
        } actions: {
            Color.clear.frame(height: 30)
        }
        .task {
            for i in 1...items.count {
                try? await Task.sleep(nanoseconds: 950_000_000)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { done = i }
                Haptics.tap()
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            next()
        }
    }
}
