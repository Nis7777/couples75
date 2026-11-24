import SwiftUI

/// Challenges → "Create your own": a name, a length, shared saves and 1–3 rules, the same for both of you.
/// "Continue" hands the challenge to the usual details sheet (optional bet, "Start tomorrow").
struct CustomChallengeSheet: View {
    @Environment(AppModel.self) private var model
    var onContinue: (Challenge) -> Void

    @State private var name = ""
    @State private var lengthIndex = 3          // 30 days
    @State private var saves = 1
    @State private var ideas: [RuleIdea] = []
    @State private var adding = false
    @State private var who = 0
    @FocusState private var nameFocused: Bool

    private var days: Int { Challenges.customLengths[lengthIndex] }
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !ideas.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        SmallLabel(text: "Your own")
                        Text("Create a challenge")
                            .font(.app(26, .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("The same rules for both of you, on top of your daily habits.")
                            .font(.app(15))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 26)

                    section("Name") {
                        TextField("e.g. Summer Shred", text: $name)
                            .font(.app(17, .semibold))
                            .textInputAutocapitalization(.words)
                            .focused($nameFocused)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .card(radius: 14, shadow: false)
                            .onChange(of: name) { _, new in if new.count > 30 { name = String(new.prefix(30)) } }
                    }

                    section("Length") {
                        PillSegmentedControl(options: Challenges.customLengths.map { "\($0)" }, selection: $lengthIndex)
                        Text("\(days) days")
                            .font(.app(13))
                            .foregroundStyle(Color.textSecondary)
                    }

                    section("Shared saves") {
                        PillSegmentedControl(options: ["0", "1", "2", "3"], selection: $saves)
                        Text(saves == 0 ? "No saves: one missed day by either of you ends it."
                             : "Misses either of you can use before it ends: \(saves).")
                            .font(.app(13))
                            .foregroundStyle(Color.textSecondary)
                    }

                    section("Every day, for both of you") {
                        ForEach(Array(ideas.enumerated()), id: \.offset) { i, idea in
                            HStack(spacing: 10) {
                                Image(systemName: idea.type == .photo ? "camera.fill" : "hand.raised.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.coral)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Color.peach))
                                Text(idea.title)
                                    .font(.app(16, .medium))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Button {
                                    withAnimation(.open(0.25)) { _ = ideas.remove(at: i) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.textSecondary.opacity(0.6))
                                }
                                .accessibilityLabel("Remove \(idea.title)")
                            }
                            .padding(.vertical, 2)
                        }
                        if ideas.count < Challenges.customMaxRules {
                            Button {
                                nameFocused = false
                                adding = true
                            } label: {
                                Label(ideas.isEmpty ? "Add a rule" : "Add another rule", systemImage: "plus")
                                    .font(.app(16, .semibold))
                                    .foregroundStyle(Color.coral)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .frame(height: 48)
                                    .card(radius: 14, shadow: false)
                            }
                            .buttonStyle(PressableStyle())
                        }
                        Text("Up to \(Challenges.customMaxRules). Workout, steps and water follow each of your levels.")
                            .font(.app(12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            BottomActions {
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.app(17, .bold))
                .foregroundStyle(Color.textPrimary)
            content()
        }
    }
}
