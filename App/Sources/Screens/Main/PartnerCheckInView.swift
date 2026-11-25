import SwiftUI
import UIKit

/// 22: one check-in, full screen. The whole photo, the habit, when it was taken, the reactions, and (on a
/// partner's check-in) the emoji row, a comment, Question and Approve pinned at the bottom. Report sits under the
/// reactions. Opening someone else's check-in records "Seen".
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
    @FocusState private var commentFocused: Bool

    private let emojis = ["❤️", "🔥", "💪", "👀", "😂"]
    private var isMine: Bool { checkIn.memberID == model.meID }
    private var name: String { model.name(of: checkIn.memberID) }
    private var rule: RuleFact? { model.facts.rules.first { $0.id == checkIn.ruleID } }
    private var reactions: [ReactionFact] { model.reactions(for: checkIn.id).filter { $0.kind != .seen } }
    private var myReactions: [ReactionFact] { model.reactions(for: checkIn.id).filter { $0.memberID == model.meID } }
    private var iApproved: Bool { myReactions.contains { $0.kind == .approve } }
    private var iQuestioned: Bool { myReactions.contains { $0.kind == .sus } }
    private var status: ProofStatus { isMine ? model.mineStatus(checkIn) : model.reviewStatus(checkIn) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    photoView
                    titleBlock
                    if !reactions.isEmpty { reactionsList }
                    if !isMine {
                        emojiRow
                        commentField
                    }
                    Button("Report") { report() }
                        .font(.app(13, .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.side)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            // The photo and reactions scroll under the actions, which sit on a soft fade (no hard edge).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isMine { actionBar }
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

    // MARK: Top

    private var topBar: some View {
        ZStack {
            Text(isMine ? "Your proof" : "\(name)'s proof")
                .font(.app(16, .semibold))
                .foregroundStyle(Color.textPrimary)
            HStack {
                CloseButton { if let onClose { onClose() } else { dismiss() } }
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: Photo

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
                        .accessibilityLabel("Photo for \(rule?.title ?? "the habit"), \(checkIn.stampText)")
                } else if loadingPhoto {
                    ProgressView().tint(.coral)
                } else {
                    Text("Photo unavailable")
                        .font(.app(15))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: photo == nil ? 320 : nil)
        } else {
            VStack(spacing: 10) {
                Image(systemName: checkIn.healthProof != nil ? "heart.text.square" : "hand.raised.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.sage)
                Text(honourText)
                    .font(.app(16, .medium))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.peach))
        }
    }

    private var honourText: String {
        if checkIn.healthProof != nil { return HealthMetric.proofLine }
        return checkIn.honourFallback ? "Honour tap (iCloud was full)" : "Honour tap: \u{201C}I stuck to it today\u{201D}"
    }

    // MARK: Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rule?.title ?? model.ruleTitle(for: checkIn))
                .font(.app(26, .bold))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // Date and status side by side when they fit; otherwise the status goes under the date. Never cut off.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    subtitleText
                    Spacer(minLength: 8)
                    statusPill
                }
                VStack(alignment: .leading, spacing: 8) {
                    subtitleText
                    statusPill
                }
            }
        }
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.app(14, .medium))
            .foregroundStyle(Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle().fill(status.color).frame(width: 7, height: 7)
            Text(status.text)
                .font(.app(13, .semibold))
                .foregroundStyle(Color.textSecondary)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.peach.opacity(0.7)))
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let day = model.dayLabel(for: checkIn)
        let time = checkIn.capturedAt.formatted(date: .omitted, time: .shortened)
        if let n = model.dayNumber(of: checkIn), !day.hasPrefix("Day") { return "\(day) · Day \(n) · \(time)" }
        return "\(day) · \(time)"
    }

    // MARK: Reactions

    private var reactionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reactions")
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textPrimary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(reactions) { r in reactionRow(r) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.7)))
    }

    private func reactionRow(_ r: ReactionFact) -> some View {
        let who = r.memberID == model.meID ? "You" : model.name(of: r.memberID)
        let text: String
        switch r.kind {
        case .approve: text = "\(who) approved ❤️"
        case .emoji: text = "\(who) reacted \(r.emoji ?? "")"
        case .comment: text = "\(who): \(r.comment ?? "")"
        case .sus: text = "\(who) asked a question about it 🤨"
        case .seen: text = "\(who) saw it"
        }
        return Text(text)
            .font(.app(14))
            .foregroundStyle(Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emojiRow: some View {
        HStack(spacing: 10) {
            ForEach(emojis, id: \.self) { e in
                let used = myReactions.contains { $0.kind == .emoji && $0.emoji == e }
                Button {
                    Haptics.tap()
                    Task { await model.react(to: checkIn, kind: .emoji, emoji: e) }
                } label: {
                    Text(e)
                        .font(.system(size: 24))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(used ? Color.sage.opacity(0.22) : Color.white.opacity(0.75)))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("React \(e)")
                .accessibilityAddTraits(used ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private var commentField: some View {
        HStack(spacing: 8) {
            TextField("Add a comment…", text: $comment)
                .font(.app(15))
                .submitLabel(.send)
                .focused($commentFocused)
                .onSubmit { sendComment() }
                .onChange(of: comment) { _, new in if new.count > 80 { comment = String(new.prefix(80)) } }
                .accessibilityLabel("Comment, up to 80 characters")
            if !comment.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Send") { sendComment() }
                    .font(.app(15, .bold))
                    .foregroundStyle(Color.coral)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.75)))
    }

    // MARK: Actions

    /// Question and Approve, pinned to the bottom.
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                guard !iQuestioned else { return }
                Haptics.tap()
                Task { await model.react(to: checkIn, kind: .sus) }
            } label: {
                Label(iQuestioned ? "Questioned" : "Question", systemImage: "questionmark.circle")
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Color.buttonBorder, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Lets \(name) know you're not sure about this one")
            Button {
                guard !iApproved else { return }
                Haptics.success()
                Task { await model.react(to: checkIn, kind: .approve) }
            } label: {
                Label(iApproved ? "Approved" : "Approve", systemImage: iApproved ? "checkmark.circle.fill" : "checkmark")
                    .font(.app(16, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(iApproved ? Color.sage : Color.coral))
            }
            .buttonStyle(PressableStyle())
            .animation(.easeInOut(duration: 0.2), value: iApproved)
        }
        .padding(.horizontal, Metrics.side)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .background {
            LinearGradient(colors: [Color.ivory.opacity(0), Color.ivory.opacity(0.94), Color.ivory],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func sendComment() {
        let text = comment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        comment = ""
        commentFocused = false
        Task { await model.react(to: checkIn, kind: .comment, comment: text) }
    }

    private func report() {
        let subject = "Report check-in \(checkIn.id)"
        let body = "Check-in id: \(checkIn.id)\nWhat's wrong:\n"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = Brand.supportEmail
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        if let url = c.url {
            openURL(url) { accepted in
                // No Mail account on this device: copy the address instead, so the button never does nothing.
                if !accepted {
                    UIPasteboard.general.string = Brand.supportEmail
                    model.toast = "No Mail account set up. \(Brand.supportEmail) copied: paste it into any email app."
                }
            }
        }
    }
}
