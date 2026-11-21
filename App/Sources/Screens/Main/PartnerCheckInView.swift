import SwiftUI
import UIKit

/// 22: a partner's check-in. React, comment, Sus, Approve, Report. (No "Prove it".)
/// Opening someone else's check-in records "Seen".
struct PartnerCheckInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var checkIn: CheckInFact

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isMine ? "Your check-in" : "\(name) checked in")
                            .font(.rounded(24))
                            .foregroundStyle(Color.textPrimary)
                        Text(rule?.title ?? "")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                    }

                    photoView

                    if let status = model.partnerStatus(of: checkIn), isMine {
                        Pill(text: status, fill: .sage)
                    }

                    if !reactions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(reactions) { r in reactionRow(r) }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 14)
                    }

                    if !isMine { reactSection }

                    Button("Report") { report() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.peach)
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    .font(.system(size: 15, weight: .medium))
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: 10) {
                ForEach(emojis, id: \.self) { e in
                    Button {
                        Haptics.tap()
                        Task { await model.react(to: checkIn, kind: .emoji, emoji: e) }
                    } label: {
                        Text(e)
                            .font(.system(size: 26))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
                    }
                    .accessibilityLabel("React \(e)")
                }
            }
            HStack(spacing: 8) {
                TextField("Add a comment…", text: $comment)
                    .font(.system(size: 15))
                    .submitLabel(.send)
                    .onSubmit { sendComment() }
                    .onChange(of: comment) { _, new in if new.count > 80 { comment = String(new.prefix(80)) } }
                    .accessibilityLabel("Comment, up to 80 characters")
                if !comment.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Send") { sendComment() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.coral)
                }
            }
            .padding(14)
            .card(radius: 14)
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
            .font(.system(size: 14))
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
