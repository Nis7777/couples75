import SwiftUI
import UIKit
import StoreKit

/// 27: "Waiting for {B}": header with a "Not started" pill, A standing next to the dashed outline,
/// Remind button plus an outlined Copy invite code button.
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
            VStack(spacing: 14) {
                CoupleHeader(pill: "Not started")

                if model.isOwner {
                    TitleText(bIsJoining ? "\(model.nameB) is joining" : "Waiting for \(model.nameB)", size: 30)
                        .padding(.top, 14)
                    BodyText(bIsJoining
                             ? "\(model.nameB) is setting up. Day 1 starts the morning after \(model.nameB) joins."
                             : "Day 1 starts the morning after \(model.nameB) joins. Your subscription covers you both.", size: 15)
                } else {
                    TitleText("Almost there", size: 30)
                        .padding(.top, 14)
                    BodyText("Day 1 starts the morning after you've both joined.", size: 15)
                }

                CoupleScene(left: model.sceneA, right: model.sceneB, crop: 0.64, overlap: 0)
                    .frame(height: 340)
                    .padding(.horizontal, -8)

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

                TextLinkButton("Or start a warm-up day. It doesn't count.", color: .textSecondary) { startWarmup() }

                #if DEBUG
                if model.isMock && model.isOwner {
                    TextLinkButton("Mock: simulate \(model.nameB) joining", color: .coral) {
                        Task { await model.debugSimulatePartnerJoin() }
                    }
                }
                #endif
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .manageSubscriptionsSheet(isPresented: $showManage)
    }
}

/// "{A} & {B}" on the left and a soft peach status pill on the right (27, 28).
struct CoupleHeader: View {
    @Environment(AppModel.self) private var model
    var pill: String
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 32, height: 36)
                }
                .accessibilityLabel("Back")
            }
            Text("\(model.nameA) & \(model.nameB)")
                .font(.app(24, .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(pill)
                .font(.app(13, .semibold))
                .foregroundStyle(Color.coral)
                .padding(.horizontal, 20)
                .frame(height: 32)
                .background(Capsule().fill(Color.peach))
        }
        .padding(.top, 12)
    }
}
