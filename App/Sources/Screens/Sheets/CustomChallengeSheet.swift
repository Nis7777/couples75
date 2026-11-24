import SwiftUI

/// Challenges → "Create your own": a name, any length (3–100 days), shared saves and 1–3 rules, the same for both
/// of you. "Continue" hands the challenge to the usual details sheet (optional bet, "Start tomorrow").
struct CustomChallengeSheet: View {
    @Environment(AppModel.self) private var model
    var onContinue: (Challenge) -> Void

    @State private var name = ""
    @State private var days = 30
    @State private var saves = 1
    @State private var ideas: [RuleIdea] = []
    @State private var adding = false
    @State private var who = 0
    @FocusState private var nameFocused: Bool

    private let range = Challenges.customDayRange
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !ideas.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    nameCard
                    lengthCard
                    savesCard
                    rulesCard
                }
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            BottomActions {
                Text(summary)
                    .font(.app(13, .medium))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryButton("Continue", isEnabled: canContinue) {
                    onContinue(Challenges.custom(title: name, days: days, saves: saves, ideas: ideas))
                }
            }
        }
        .background(Color.ivory.ignoresSafeArea())
        .onAppear { nameFocused = name.isEmpty }
        .sheet(isPresented: $adding) {
            RuleChangeSheet(
                title: "Add a rule",
                currentTitle: nil,
                who: $who,
                suggestions: [],
                intensity: .standard,
                note: "Both of you do this every day of the challenge.",
                validate: { idea in
                    if ideas.count >= Challenges.customMaxRules { return "Up to \(Challenges.customMaxRules) rules." }
                    if ideas.contains(where: { $0.title == idea.title }) { return "It's already in the challenge." }
                    return nil
                },
                onPick: { idea in
                    withAnimation(.open(0.25)) { ideas.append(idea) }
                    adding = false
                })
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "star.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.coral)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color.peach))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Create your own")
                    .font(.app(26, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Same rules for both of you, on top of your habits.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 26)
        .padding(.bottom, 4)
    }

    // MARK: Name

    private var nameCard: some View {
        card("Name", icon: "pencil") {
            TextField("e.g. Summer Shred", text: $name)
                .font(.app(18, .semibold))
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ivory))
                .onChange(of: name) { _, new in if new.count > 30 { name = String(new.prefix(30)) } }
        }
    }

    // MARK: Length

    private var lengthCard: some View {
        card("How long", icon: "calendar") {
            HStack(spacing: 0) {
                roundButton("minus", label: "Fewer days", enabled: days > range.lowerBound) { setDays(days - 1) }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(.app(48, .heavy))
                        .foregroundStyle(Color.textPrimary)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    Text(days == 1 ? "day" : "days")
                        .font(.app(15, .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAdjustableAction { dir in
                    switch dir {
                    case .increment: setDays(days + 1)
                    case .decrement: setDays(days - 1)
                    @unknown default: break
                    }
                }
                Spacer(minLength: 0)
                roundButton("plus", label: "More days", enabled: days < range.upperBound) { setDays(days + 1) }
            }
            .padding(.vertical, 4)

            HStack(spacing: 6) {
                ForEach(Challenges.customLengths, id: \.self) { d in
                    let on = d == days
                    Button { setDays(d) } label: {
                        Text("\(d)")
                            .font(.app(14, .semibold))
                            .foregroundStyle(on ? Color.white : Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Capsule().fill(on ? Color.coral : Color.ivory))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(d) days")
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }

            Label(dateRange, systemImage: "flag.checkered")
                .font(.app(13, .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func setDays(_ value: Int) {
        let v = min(max(value, range.lowerBound), range.upperBound)
        guard v != days else { return }
        Haptics.tap()
        withAnimation(.snappy(duration: 0.2)) { days = v }
    }

    /// "Starts tomorrow · ends Tue 24 Dec".
    private var dateRange: String {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        let end = cal.date(byAdding: .day, value: days - 1, to: start) ?? start
        return "Starts tomorrow · ends \(end.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
    }

    // MARK: Saves

    private var savesCard: some View {
        card("Shared saves", icon: "shield.fill") {
            HStack(spacing: 14) {
                Text(saves == 0 ? "No saves: one missed day by either of you ends it."
                     : "\(saves) missed \(saves == 1 ? "day" : "days") either of you can use before it ends.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    roundButton("minus", label: "Fewer saves", enabled: saves > 0, size: 36) { setSaves(saves - 1) }
                    Text("\(saves)")
                        .font(.app(22, .bold))
                        .foregroundStyle(Color.textPrimary)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                        .frame(minWidth: 22)
                    roundButton("plus", label: "More saves", enabled: saves < 3, size: 36) { setSaves(saves + 1) }
                }
            }
        }
    }

    private func setSaves(_ value: Int) {
        let v = min(max(value, 0), 3)
        guard v != saves else { return }
        Haptics.tap()
        withAnimation(.snappy(duration: 0.2)) { saves = v }
    }

    // MARK: Rules

    private var rulesCard: some View {
        card("Every day, for both of you", icon: "checklist") {
            VStack(spacing: 0) {
                ForEach(Array(ideas.enumerated()), id: \.offset) { i, idea in
                    HStack(spacing: 12) {
                        Image(systemName: idea.type == .photo ? "camera.fill" : "hand.raised.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.coral)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.peach))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(idea.title)
                                .font(.app(16, .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text(idea.type == .photo ? "Photo proof" : "Honour tap")
                                .font(.app(12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Button {
                            withAnimation(.open(0.25)) { _ = ideas.remove(at: i) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.textSecondary.opacity(0.5))
                        }
                        .accessibilityLabel("Remove \(idea.title)")
                    }
                    .padding(.vertical, 10)
                    if i < ideas.count - 1 || ideas.count < Challenges.customMaxRules {
                        Divider()
                    }
                }
                if ideas.count < Challenges.customMaxRules {
                    Button {
                        nameFocused = false
                        adding = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.coral))
                            Text(ideas.isEmpty ? "Add a rule" : "Add another rule")
                                .font(.app(16, .semibold))
                                .foregroundStyle(Color.coral)
                            Spacer()
                            Text("\(ideas.count)/\(Challenges.customMaxRules)")
                                .font(.app(13, .medium))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Text("Workout, steps and water follow each of your levels.")
                .font(.app(12))
                .foregroundStyle(Color.textSecondary)
        }
    }

    /// "30 days · 1 save · 2 rules".
    private var summary: String {
        let r = ideas.count
        let rules = r == 0 ? "add at least 1 rule" : "\(r) \(r == 1 ? "rule" : "rules")"
        return "\(days) days · \(saves) \(saves == 1 ? "save" : "saves") · \(rules)"
    }

    // MARK: Pieces

    private func card<Content: View>(_ title: String, icon: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.app(15, .bold))
                .foregroundStyle(Color.textPrimary)
                .labelStyle(.titleAndIcon)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20, shadow: false)
    }

    private func roundButton(_ symbol: String, label: String, enabled: Bool, size: CGFloat = 48,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(enabled ? Color.coral : Color.textSecondary.opacity(0.35))
                .frame(width: size, height: size)
                .background(Circle().fill(enabled ? Color.peach : Color.ivory))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
