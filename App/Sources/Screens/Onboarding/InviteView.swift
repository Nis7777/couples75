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
                // A and the partner (dashed outline until built), starting right under the title.
                CoupleScene(left: model.sceneA, right: model.sceneBBuilt, crop: 0.6, overlap: 0.0,
                            alignment: .top, fillHeight: true)
                    .padding(.horizontal, -8)
                    .frame(maxHeight: .infinity)
                Text("Free for \(model.nameB): your subscription covers you both.")
                    .font(.app(15, .medium))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        } actions: {
            InviteShareButton(title: "Send invite")
            InviteCodeLine()
            TextLinkButton("Done for now") { next() }
        }
    }
}

/// "Or share code K7M2QP" in smaller text under the button (tap to copy).
struct InviteCodeLine: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let code = model.invite?.code {
            Button {
                UIPasteboard.general.string = code
                Haptics.success()
                model.toast = "Code copied."
            } label: {
                HStack(spacing: 6) {
                    Text("Or share code")
                        .foregroundStyle(Color.textSecondary)
                    Text(code)
                        .font(.app(16, .bold))
                        .tracking(2)
                        .foregroundStyle(Color.textPrimary)
                    Image(systemName: "doc.on.doc").font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
                .font(.app(15, .medium))
            }
            .accessibilityLabel("Or share code \(code.map(String.init).joined(separator: " ")). Double tap to copy.")
        } else {
            Button("Get a code") { Task { await model.regenerateInvite() } }
                .font(.app(15, .semibold))
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
        let aRules = model.memberA.map { model.rules(for: $0.id) } ?? []
        let bRules = model.memberB.map { model.rules(for: $0.id) } ?? model.draftRulesForB
        let view = InviteCardView(inviter: model.sceneA, partner: model.sceneBBuilt, partnerName: model.nameB,
                                  inviterRules: aRules.map { $0.title }, partnerRules: bRules.map { $0.title },
                                  bet: model.currentBet)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        card = renderer.uiImage
    }
}

/// The shareable invite card image (360×560 pt rendered at 3×): both avatars (the partner as the dashed outline
/// until built), "{A} invited you to Couples 75", each partner's 4 rules, the bet and "Free for you".
struct InviteCardView: View {
    var inviter: SceneCharacter
    var partner: SceneCharacter?
    var partnerName: String
    var inviterRules: [String]
    var partnerRules: [String]
    var bet: String

    var body: some View {
        VStack(spacing: 12) {
            Text(Brand.appName.uppercased())
                .font(.app(12, .heavy))
                .tracking(2)
                .foregroundStyle(Color.coral)
            Text("\(inviter.name) invited you to \(Brand.appName)")
                .font(.app(22, .bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            CoupleScene(left: inviter, right: partner, crop: 0.6, overlap: 0)
                .frame(height: 150)
                .background(PeachPanelFill(radius: 18))
            HStack(alignment: .top, spacing: 12) {
                column(inviter.name, inviterRules, .coral)
                column(partnerName, partnerRules, .sage)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(Color.gold)
                Text(bet).font(.app(14, .bold)).foregroundStyle(Color.textPrimary)
            }
            Text("Free for you: \(inviter.name)'s subscription covers you both.")
                .font(.app(13, .semibold))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(width: 360, height: 560)
        .background(Color.ivory)
    }

    private func column(_ name: String, _ rules: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.app(13, .bold)).foregroundStyle(color)
            ForEach(Array(rules.prefix(4).enumerated()), id: \.offset) { _, r in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text(r).font(.app(12)).foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
