import SwiftUI

/// Change one rule (Part 8): "Suggested for you", "From the list", "Write your own".
/// Used on the plan reveal (before the couple exists) and from Profile → Our rules → Request a change.
struct RuleChangeSheet: View {
    var title: String
    var currentTitle: String?
    /// Who the change is for ([] hides the picker).
    var whoOptions: [String] = []
    @Binding var who: Int
    var suggestions: [RuleIdea]
    var intensity: Intensity
    var note: String?
    /// nil = allowed; otherwise why not (e.g. "Keep at least 2 photo rules each.").
    var validate: (RuleIdea) -> String?
    var canReset = false
    var onReset: () -> Void = {}
    var onPick: (RuleIdea) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customTitle = ""
    @State private var customType: RuleType = .photo
    @State private var customHint = ""
    @State private var problem: String?

    private var library: [RuleIdea] {
        RuleLibrary.all.compactMap { RuleIdea.library($0.key, intensity: intensity) }
            .filter { $0.title != currentTitle && !suggestions.contains($0) }
    }

    private var customIdea: RuleIdea {
        RuleIdea(title: customTitle.trimmingCharacters(in: .whitespaces), type: customType, libraryKey: nil,
                 photoHint: customType == .photo ? customHint.trimmingCharacters(in: .whitespaces) : nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if whoOptions.count > 1 {
                        Picker("For", selection: $who) {
                            ForEach(Array(whoOptions.enumerated()), id: \.offset) { i, name in Text(name).tag(i) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if let currentTitle {
                        HStack(spacing: 6) {
                            Text("Now:").font(.app(14)).foregroundStyle(Color.textSecondary)
                            Text(currentTitle).font(.app(14, .semibold)).foregroundStyle(Color.textPrimary)
                        }
                    }
                    if let problem {
                        Text(problem)
                            .font(.app(14, .semibold))
                            .foregroundStyle(Color.coral)
                    }
                    if !suggestions.isEmpty {
                        section("Suggested for you") {
                            ForEach(suggestions) { ideaRow($0) }
                        }
                    }
                    section("From the list") {
                        ForEach(library) { ideaRow($0) }
                    }
                    section("Write your own") { customForm }
                    if let note {
                        Text(note)
                            .font(.app(13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if canReset {
                        TextLinkButton("Keep the original rule") { onReset() }
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Metrics.side)
                .padding(.vertical, 12)
            }
            .background(Color.ivory.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.coral)
                }
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.app(18, .bold))
                .foregroundStyle(Color.textPrimary)
            content()
        }
    }

    private func pick(_ idea: RuleIdea) {
        if let why = validate(idea) {
            Haptics.warning()
            withAnimation { problem = why }
            return
        }
        Haptics.tap()
        onPick(idea)
    }

    private func ideaRow(_ idea: RuleIdea) -> some View {
        Button { pick(idea) } label: {
            HStack(spacing: 12) {
                Image(systemName: idea.type == .photo ? "camera.fill" : "hand.raised.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.coral)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.peach))
                Text(idea.title)
                    .font(.app(16, .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(idea.type == .photo ? "Photo" : "Honour")
                    .font(.app(12, .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .card(radius: 16, shadow: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(idea.title), \(idea.type == .photo ? "photo rule" : "honour rule")")
    }

    private var customForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Your rule, e.g. 15 min guitar", text: $customTitle)
                .font(.app(17, .medium))
                .onChange(of: customTitle) { _, new in
                    if new.count > RuleLibrary.customTitleMaxLength {
                        customTitle = String(new.prefix(RuleLibrary.customTitleMaxLength))
                    }
                }
            Divider()
            Picker("Proof", selection: $customType) {
                Text("Photo").tag(RuleType.photo)
                Text("Honour").tag(RuleType.honour)
            }
            .pickerStyle(.segmented)
            if customType == .photo {
                TextField("What to photograph (optional)", text: $customHint)
                    .font(.app(15))
                    .onChange(of: customHint) { _, new in
                        if new.count > 80 { customHint = String(new.prefix(80)) }
                    }
            }
            HStack {
                Text("\(customTitle.count)/\(RuleLibrary.customTitleMaxLength)")
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Button("Use this rule ›") { pick(customIdea) }
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.coral)
                    .disabled(customIdea.title.isEmpty)
                    .opacity(customIdea.title.isEmpty ? 0.45 : 1)
            }
        }
        .padding(16)
        .card(radius: 16, shadow: false)
    }
}
