import SwiftUI

/// Right after the names: the couple's Pact Card being made. It rises in, both names type themselves on, the
/// date stamps on and the empty streak grid fades in, with a light haptic. Nobody has signed yet (that's the Hold
/// to sign step); a partner who hasn't built their character shows as the outline.
struct CardCreatedView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var play = false

    private enum Beat {
        static let rise: (Double, Double) = (0, 650)
        static let typeA: (Double, Double) = (550, 1150)
        static let typeB: (Double, Double) = (1050, 1650)
        static let stamp: (Double, Double) = (1750, 2050)
        static let grid: (Double, Double) = (2050, 2900)
        static let total: Double = 3000
    }

    private var data: PactCardData {
        var d = model.pactCard
        d.signedA = nil
        d.signedB = nil
        return d
    }

    var body: some View {
        let d = data
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            VStack(spacing: 14) {
                SmallLabel(text: "\(Brand.appName) #\(d.cardNumber)")
                    .padding(.top, 26)
                TitleText("This is your pact.", size: 30)
                OneShotClock(duration: Beat.total, play: play) { t in
                    let rise = seg(t, Beat.rise.0, Beat.rise.1)
                    PactCard(data: d, seal: 0, sheen: 1,
                             typeA: seg(t, Beat.typeA.0, Beat.typeA.1, easeOut: false),
                             typeB: seg(t, Beat.typeB.0, Beat.typeB.1, easeOut: false),
                             stamp: seg(t, Beat.stamp.0, Beat.stamp.1),
                             gridIn: seg(t, Beat.grid.0, Beat.grid.1, easeOut: false))
                        .rotation3DEffect(.degrees(16 * (1 - rise)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                        .scaleEffect(0.94 + 0.06 * rise)
                        .offset(y: 40 * (1 - rise))
                        .opacity(rise)
                }
                .frame(width: PactCardMetrics.width, height: PactCardMetrics.height)
                .padding(.vertical, 10)
                BodyText("Let's fill it in.")
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Let's fill it in") { next() }
        }
        .onAppear {
            // The card number comes from the couple's ID, so make the ID now and keep it.
            if model.draft.coupleID == nil { model.draft.coupleID = .newID() }
            play = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Beat.stamp.1 * 1_000_000))
                Haptics.light()
            }
        }
    }
}
