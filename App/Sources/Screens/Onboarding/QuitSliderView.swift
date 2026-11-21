import SwiftUI

/// Step 10 (07): a slider inside a card: coral thumb, the chosen label in coral above it, the 4 labels under it.
struct QuitSliderView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 0) {
                TitleText("How often do you start something together and quit?", size: 28)
                    .padding(.top, 40)
                    .padding(.horizontal, 6)
                Spacer(minLength: 24)
                StepSlider(value: Binding(get: { Int(model.draft.quitFrequency.rounded()) },
                                          set: { model.draft.quitFrequency = Double($0) }),
                           labels: ["Rarely", "Sometimes", "Usually", "Always"])
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 22)
                    .card()
                Spacer(minLength: 24)
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
    }
}

/// Discrete slider: thin beige track with ticks, a coral thumb, the current label above it.
struct StepSlider: View {
    @Binding var value: Int
    var labels: [String]
    private let thumb: CGFloat = 30

    private var currentLabel: String { labels[min(max(value, 0), labels.count - 1)] }

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 26
            let width = geo.size.width - inset * 2
            let steps = max(labels.count - 1, 1)
            let x = inset + width * CGFloat(value) / CGFloat(steps)
            ZStack(alignment: .topLeading) {
                Text(currentLabel)
                    .font(.app(20, .semibold))
                    .foregroundStyle(Color.coral)
                    .fixedSize()
                    .position(x: x, y: 12)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
                Capsule()
                    .fill(Color.track)
                    .frame(width: width, height: 6)
                    .position(x: inset + width / 2, y: 52)
                ForEach(0...steps, id: \.self) { i in
                    Capsule()
                        .fill(Color.track)
                        .frame(width: 3, height: 12)
                        .position(x: inset + width * CGFloat(i) / CGFloat(steps), y: 58)
                }
                Circle()
                    .fill(Color.coral)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: Color.coral.opacity(0.3), radius: 6, y: 2)
                    .position(x: x, y: 52)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: value)
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    Text(l)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize()
                        .position(x: inset + width * CGFloat(i) / CGFloat(steps), y: 92)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let raw = (g.location.x - inset) / max(width, 1) * CGFloat(steps)
                set(Int(raw.rounded()))
            })
        }
        .frame(height: 106)
        .accessibilityElement()
        .accessibilityLabel("How often you quit")
        .accessibilityValue(currentLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(value + 1)
            case .decrement: set(value - 1)
            @unknown default: break
            }
        }
    }

    private func set(_ v: Int) {
        let clamped = min(max(v, 0), labels.count - 1)
        guard clamped != value else { return }
        Haptics.tap()
        value = clamped
    }
}
