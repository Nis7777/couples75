import SwiftUI
import UIKit

/// 22: a partner's check-in. React, comment, Sus, Approve, Report. (No "Prove it".)
/// Opening someone else's check-in records "Seen".
struct PartnerCheckInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var checkIn: CheckInFact
    /// Used when shown inside the Proof pager.
    var onClose: (() -> Void)? = nil

    @State private var photo: UIImage?
    @State private var comment = ""
    @State private var loadingPhoto = true

    private let emojis = ["❤️", "🔥", "💪", "👀", "😂"]
    private var isMine: Bool { checkIn.memberID == model.meID }
    private var name: String { model.name(of: checkIn.memberID) }
    private var rule: RuleFact? { model.facts.rules.first { $0.id == checkIn.ruleID } }
    private var reactions: [ReactionFact] { model.reactions(for: checkIn.id).filter { $0.kind != .seen } }
    private var iApproved: Bool {
        model.reactions(for: checkIn.id).contains { $0.memberID == model.meID && $0.kind == .approve }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(isMine ? "Your check-in" : "\(name) checked in")
                    .font(.app(17, .semibold))
                    .foregroundStyle(Color.textPrimary)
                HStack {
                    CloseButton { if let onClose { onClose() } else { dismiss() } }
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule?.title ?? "")
                            .font(.app(28, .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(subtitle)
                            .font(.app(15, .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 6)

                    photoView

                    if let status = model.partnerStatus(of: checkIn), isMine {
                        Pill(text: status, fill: .sage)
                    }

                    if !reactions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(reactions) { r in reactionRow(r) }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 16, shadow: false)
                    }

                    if !isMine { reactSection }

                    Button("Report") { report() }
                        .font(.app(14, .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, 20)
            }
        }
        .screenBackground()
        .task {
            if let data = model.cachedPhoto(checkIn.id) { photo = UIImage(data: data) }
            if photo == nil, checkIn.hasPhoto, let data = await model.photoData(for: checkIn) {
                photo = UIImage(data: data)
            }
            loadingPhoto = false
            await model.markSeen(checkIn)
        }
    }

    private var subtitle: String {
        let time = checkIn.capturedAt.formatted(date: .omitted, time: .shortened)
        if let n = model.dayNumber(of: checkIn) { return "Day \(n) · \(time)" }
        return checkIn.isWarmup ? "Warm-up · \(time)" : time
    }

    @ViewBuilder
    private var photoView: some View {
        if checkIn.hasPhoto {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.peach)
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityLabel("Photo for \(rule?.title ?? "the rule"), \(checkIn.stampText)")
                } else if loadingPhoto {
                    ProgressView().tint(.coral)
                } else {
                    Text("Photo unavailable").foregroundStyle(Color.textSecondary)
                }
            }
            .frame(minHeight: 280)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill").foregroundStyle(Color.sage)
                Text(checkIn.honourFallback ? "Honour tap (iCloud was full)" : "Honour tap: \"I stuck to it today\"")
                    .font(.app(15, .medium))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: 14)
        }
    }

    private var reactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("React")
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: 10) {
                ForEach(emojis, id: \.self) { e in
                    Button {
                        Haptics.tap()
                        Task { await model.react(to: checkIn, kind: .emoji, emoji: e) }
                    } label: {
                        Text(e)
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: 64)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.cardBorder, lineWidth: 1))
                    }
                    .accessibilityLabel("React \(e)")
                }
            }
            HStack(spacing: 8) {
                TextField("Add a comment…", text: $comment)
                    .font(.app(15))
                    .submitLabel(.send)
                    .onSubmit { sendComment() }
                    .onChange(of: comment) { _, new in if new.count > 80 { comment = String(new.prefix(80)) } }
                    .accessibilityLabel("Comment, up to 80 characters")
                if !comment.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Send") { sendComment() }
                        .font(.app(15, .bold))
                        .foregroundStyle(Color.coral)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .card(radius: 18, shadow: false)
            HStack(spacing: 12) {
                SecondaryButton("Sus 🤨") {
                    Task { await model.react(to: checkIn, kind: .sus) }
                }
                PrimaryButton(iApproved ? "Approved" : "Approve", isEnabled: !iApproved) {
                    Task {
                        await model.react(to: checkIn, kind: .approve)
                        Haptics.success()
                    }
                }
            }
        }
    }

    private func reactionRow(_ r: ReactionFact) -> some View {
        let who = r.memberID == model.meID ? "You" : model.name(of: r.memberID)
        let text: String
        switch r.kind {
        case .approve: text = "\(who) approved ❤️"
        case .emoji: text = "\(who) reacted \(r.emoji ?? "")"
        case .comment: text = "\(who): \(r.comment ?? "")"
        case .sus: text = "\(who) thinks that's sus 🤨"
        case .seen: text = "\(who) saw it"
        }
        return Text(text)
            .font(.app(14))
            .foregroundStyle(Color.textPrimary)
    }

    private func sendComment() {
        let text = comment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        comment = ""
        Task { await model.react(to: checkIn, kind: .comment, comment: text) }
    }

    private func report() {
        let subject = "Report check-in \(checkIn.id)"
        let body = "Check-in id: \(checkIn.id)\nWhat's wrong:\n"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = Brand.supportEmail
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        if let url = c.url { openURL(url) }
    }
}
