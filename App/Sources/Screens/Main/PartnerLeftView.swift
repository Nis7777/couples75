import SwiftUI

/// "{name} left the couple" with an offer to start over with a new partner (6.5).
struct PartnerLeftView: View {
    @Environment(AppModel.self) private var model

    private var leaverName: String {
        if case .partnerLeft(let id) = model.state.phase { return model.name(of: id) }
        return model.facts.members.first { $0.leftAt != nil }?.name ?? "Your partner"
    }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                TitleText("\(leaverName) left the couple")
                BodyText(model.iAmPayer
                         ? "Your run has ended. Your subscription stays active until you cancel it (Settings → your name → Subscriptions), so you can start over with someone new without paying again."
                         : "Your run has ended. \(leaverName) was the one paying, so to start over with someone new you'll need your own subscription.")
                if let me = model.me {
                    CharacterView(avatar: me.avatar, pose: .stand)
                        .frame(maxHeight: 280)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Start over with a new partner") { Task { await model.startOver() } }
        }
    }
}
