import SwiftUI

/// "Updated 2 min ago" / "Syncing…" / "Offline · 2 waiting to send": sync you can see.
struct SyncStatusLine: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(text(now: context.date))
                    .font(.app(12, .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var color: Color {
        if model.isSyncing { return .gold }
        if model.syncProblem != nil || model.pendingUploads > 0 { return .coral }
        return .sage
    }

    private func text(now: Date) -> String {
        // App Store screenshots from the Simulator: launch with -screenshots to hide the test-mode line.
        #if DEBUG
        if model.isMock {
            return ProcessInfo.processInfo.arguments.contains("-screenshots") ? "Synced just now" : "Mock mode · saved on this phone"
        }
        #endif
        if model.isSyncing { return "Syncing…" }
        let waiting = model.pendingUploads
        switch model.syncProblem {
        case .signedOut: return "Signed out of iCloud · not syncing"
        case .offline: return waiting > 0 ? "Offline · \(waiting) waiting to send" : "Offline · showing saved data"
        case nil: break
        }
        if waiting > 0 { return "\(waiting) waiting to send" }
        guard let last = model.lastSyncedAt else { return "Not synced yet" }
        let secs = now.timeIntervalSince(last)
        if secs < 60 { return "Updated just now" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return "Updated \(f.localizedString(for: last, relativeTo: now))"
    }
}

/// A love note from the partner, shown on Today until dismissed (24 h max).
struct NoteBanner: View {
    @Environment(AppModel.self) private var model
    var note: NudgeFact

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.coral)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.name(of: note.from)) sent you a note")
                    .font(.app(13, .semibold))
                    .foregroundStyle(Color.textSecondary)
                Text(note.text ?? "❤️")
                    .font(.app(17, .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { model.dismissNote(note) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Dismiss note")
        }
        .padding(14)
        .peachBox(radius: 18)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Quick love notes plus one custom line (80 characters).
struct LoveNoteSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("A note for \(model.partnerName)")
                    .font(.app(22, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 22)
                ForEach(AppModel.notePresets, id: \.self) { p in
                    Button {
                        Task { await model.sendNote(p); dismiss() }
                    } label: {
                        Text(p)
                            .font(.app(17, .medium))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .card(radius: 16, shadow: false)
                    }
                    .buttonStyle(PressableStyle())
                }
                HStack(spacing: 10) {
                    TextField("Write your own…", text: $custom)
                        .font(.app(17))
                        .onChange(of: custom) { _, new in
                            if new.count > AppModel.noteMaxLength { custom = String(new.prefix(AppModel.noteMaxLength)) }
                        }
                    Button("Send") { Task { await model.sendNote(custom); dismiss() } }
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.coral)
                        .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .card(radius: 16, shadow: false)
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 20)
        }
        .background(Color.ivory.ignoresSafeArea())
    }
}
