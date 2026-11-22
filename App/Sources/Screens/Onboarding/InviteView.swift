import SwiftUI
import UIKit

/// 14: "Send {B} their invite" with the code and a share sheet carrying a rendered invite card.
struct InviteView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 16) {
                TitleText("Send \(model.nameB) their invite", size: 30)
                    .padding(.top, 22)
                // A and the dashed outline at the same height, starting right under the title.
                CoupleScene(left: model.sceneA, right: nil, crop: 0.6, overlap: 0.0, alignment: .top, fillHeight: true)
                    .padding(.horizontal, -8)
                    .frame(maxHeight: .infinity)
                InviteCodeCard()
            }
        } actions: {
            InviteShareButton(title: "Send invite")
            TextLinkButton("Done for now") { next() }
        }
    }
}

/// The code in large letters with a copy button.
struct InviteCodeCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 6) {
            Text("Invite code")
                .font(.app(14, .medium))
                .foregroundStyle(Color.textSecondary)
            if let code = model.invite?.code {
                HStack(spacing: 12) {
                    Text(code)
                        .font(.app(34, .bold))
                        .tracking(7)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityLabel("Code \(code.map(String.init).joined(separator: " "))")
                    Button {
                        UIPasteboard.general.string = code
                        Haptics.success()
                        model.toast = "Code copied."
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Copy code")
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView().tint(.coral)
                    Button("Get a code") { Task { await model.regenerateInvite() } }
                        .font(.app(15, .semibold))
                }
                .frame(height: 44)
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .card()
    }
}

/// Renders the invite card and opens the share sheet with the card and the invite text.
struct InviteShareButton: View {
    @Environment(AppModel.self) private var model
    var title: String
    var secondary = false
    @State private var card: UIImage?

    var body: some View {
        Group {
            if let card {
                ShareLink(item: Image(uiImage: card),
                          subject: Text("\(model.nameA) invited you to \(Brand.appName)"),
                          message: Text(model.inviteMessage()),
                          preview: SharePreview("\(model.nameA) invited you to \(Brand.appName)",
                                                image: Image(uiImage: card))) {
                    label
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            } else {
                label.opacity(0.5)
            }
        }
        .task(id: model.invite?.code) { render() }
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var label: some View {
        if secondary {
            SecondaryButtonLabel(title: title)
        } else {
            PrimaryButtonLabel(title: title)
        }
    }

    private func render() {
        let rules = model.memberB.map { model.rules(for: $0.id) } ?? model.draftRulesForB
        let view = InviteCardView(inviter: model.sceneA, rules: rules.map { $0.title }, bet: model.currentBet,
                                  code: model.invite?.code ?? "", monthlyPrice: model.purchases.monthlyPrice)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        card = renderer.uiImage
    }
}

/// The shareable invite card image (360×480 pt rendered at 3×).
struct InviteCardView: View {
    var inviter: SceneCharacter
    var rules: [String]
    var bet: String
    var code: String
    var monthlyPrice: String?

    var body: some View {
        VStack(spacing: 12) {
            Text(Brand.appName.uppercased())
                .font(.app(12, .heavy))
                .tracking(2)
                .foregroundStyle(Color.coral)
            Text("\(inviter.name) invited you to \(Brand.appName)")
                .font(.rounded(22))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            CoupleScene(left: inviter, right: nil)
                .frame(height: 140)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(rules.enumerated()), id: \.offset) { _, r in
                    HStack(spacing: 6) {
                        Circle().fill(Color.sage).frame(width: 6, height: 6)
                        Text(r).font(.app(13)).foregroundStyle(Color.textPrimary)
                    }
                }
                HStack(spacing: 6) {
                    Text("🏆")
                    Text(bet).font(.app(13, .bold)).foregroundStyle(Color.textPrimary)
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            Text(code)
                .font(.app(28, .heavy))
                .tracking(5)
                .foregroundStyle(Color.textPrimary)
            Text("Free for you: \(inviter.name)'s subscription covers you both.")
                .font(.app(12, .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(20)
        .frame(width: 360, height: 480)
        .background(Color.ivory)
    }
}
