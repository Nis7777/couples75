import SwiftUI

/// After the plan review: "Sign your pact". A commitment to the daily habits, no bet (bets come with challenges).
/// Hold the fingerprint, then your Pact Card appears, your signature writes itself on (your partner's line
/// waits for them), the seal stamps and it ends on a "SIGNED" stamp.
struct SignPactView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var signed = false

    private var promises: [String] {
        let b = model.draft.partnerName
        return ["We do our daily habits, every day", "We check in for each other, with proof",
                b.isEmpty ? "We don't let each other slide" : "I don't let \(b) slide, and \(b) doesn't let me"]
    }

    var body: some View {
        let d = model.draft
        OnboardingPage(step: d.stepNumber, back: signed ? nil : back) {
            if signed {
                VStack(spacing: 14) {
                    SmallLabel(text: "Signed")
                        .padding(.top, 26)
                    TitleText("Your \(Brand.appName) card", size: 30)
                    PactCardReveal(data: model.pactCard, signA: true, signB: false, stampSigned: true)
                        .padding(.vertical, 10)
                    BodyText("\(d.partnerName.isEmpty ? "Your partner" : d.partnerName) signs it when they join. Day 1 starts the day after.")
                        .padding(.horizontal, 12)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                VStack(spacing: 14) {
                    CoupleBusts(left: model.draftScene, right: model.sceneBBuilt)
                        .frame(height: 130)
                        .padding(.top, 14)
                    TitleText("Sign your pact", size: 30)
                    Text("\(d.myName) & \(d.partnerName), from the day after \(d.partnerName) joins:")
                        .multilineTextAlignment(.center)
                        .font(.app(16, .medium))
                        .foregroundStyle(Color.textSecondary)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(promises, id: \.self) { p in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.coral)
                                Text(p)
                                    .font(.app(17, .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 20, shadow: false)
                    Spacer(minLength: 0)
                    VStack(spacing: 4) {
                        Text("Hold to sign")
                            .font(.app(19, .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("We do this together")
                            .font(.app(14))
                            .foregroundStyle(Color.textSecondary)
                        HoldToSignButton(enabled: true) {
                            withAnimation(.open(0.35)) { signed = true }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 12)
                }
            }
        } actions: {
            if signed {
                PrimaryButton("Continue") { next() }
            }
        }
    }
}
