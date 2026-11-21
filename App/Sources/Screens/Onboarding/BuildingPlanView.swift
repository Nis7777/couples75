import SwiftUI

/// Step 13 (10): animated checklist, ~3 seconds, auto-advances.
struct BuildingPlanView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    @State private var done = 0
    private let items = ["Matching rules to your goals…", "Building Day 1", "Setting the finish line"]

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: nil) {
            VStack(spacing: 24) {
                CoupleScene(left: SceneCharacter(characterID: model.draft.characterID, name: model.draft.myName),
                            right: SceneCharacter(characterID: "m1", name: model.draft.partnerName),
                            leftPose: .stretch, rightPose: .stretch)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 12)
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, text in
                        HStack(spacing: 12) {
                            ZStack {
                                if i < done {
                                    CheckCircle(isOn: true, color: .sage)
                                        .transition(.scale.combined(with: .opacity))
                                } else if i == done {
                                    ProgressView().tint(.coral).frame(width: 24, height: 24)
                                } else {
                                    CheckCircle(isOn: false)
                                }
                            }
                            .frame(width: 24, height: 24)
                            Text(text)
                                .font(.system(size: 16, weight: i <= done ? .semibold : .regular))
                                .foregroundStyle(i <= done ? Color.textPrimary : Color.textSecondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Building your plan")
            }
        } actions: {
            Color.clear.frame(height: 58)
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
