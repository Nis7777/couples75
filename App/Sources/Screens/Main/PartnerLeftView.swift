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
                BodyText("The run has ended and the shared photos are gone. Your own subscription stays yours.")
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
