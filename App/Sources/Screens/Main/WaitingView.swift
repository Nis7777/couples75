import SwiftUI
import UIKit
import StoreKit

/// 27: "Waiting for {B}".
struct WaitingView: View {
    @Environment(AppModel.self) private var model
    var startWarmup: () -> Void
    @State private var showManage = false
    @State private var regenerating = false

    /// Days since A paid (day 7 adds "Invite someone else" and "Manage subscription").
    private var daysSincePaid: Int {
        guard let paid = UserDefaults.standard.object(forKey: Prefs.invitePaidAtKey) as? Date
                ?? model.memberA?.joinedAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: paid, to: model.now()).day ?? 0
    }

    private var bIsJoining: Bool { model.memberB != nil && model.memberB?.joinedAt == nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    Text("\(model.nameA) & \(model.nameB)")
                        .font(.rounded(20))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Pill(text: "Not started", fill: .peach, foreground: .coral)
                }
                .padding(.top, 8)

                if model.isOwner {
                    TitleText(bIsJoining ? "\(model.nameB) is joining" : "Waiting for \(model.nameB)")
                        .padding(.top, 8)
                    BodyText(bIsJoining
                             ? "\(model.nameB) is setting up. Day 1 starts the morning after \(model.nameB) subscribes."
                             : "Day 1 starts the morning after \(model.nameB) joins and subscribes.")
                } else {
                    TitleText("Almost there")
                        .padding(.top, 8)
                    BodyText("Day 1 starts the morning after you've both subscribed.")
                }

                CoupleScene(left: model.sceneA, right: model.sceneB)
                    .frame(height: 300)

                if model.isOwner {
                    if !bIsJoining {
                        InviteShareButton(title: "Remind \(model.nameB)")
                        SecondaryButton("Copy invite code") {
                            var text = model.invite?.code ?? ""
                            if let link = model.invite?.shareURL?.absoluteString { text += " \(link)" }
                            UIPasteboard.general.string = text
                            Haptics.success()
                            model.toast = "Invite code and link copied."
                        }
                    }
                    if daysSincePaid >= 7 {
                        SecondaryButton(regenerating ? "Creating a new invite…" : "Invite someone else") {
                            Task {
                                regenerating = true
                                await model.regenerateInvite()
                                regenerating = false
                            }
                        }
                        SecondaryButton("Manage subscription") { showManage = true }
                    }
                }

                TextLinkButton("Or start a warm-up day. It doesn't count.", color: .coral) { startWarmup() }

                if model.isMock && model.isOwner {
                    TextLinkButton("Mock: simulate \(model.nameB) joining") {
                        Task { await model.debugSimulatePartnerJoin() }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .manageSubscriptionsSheet(isPresented: $showManage)
    }
}
