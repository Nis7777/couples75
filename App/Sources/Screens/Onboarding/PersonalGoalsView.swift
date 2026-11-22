import SwiftUI

/// After the goals: "Anything personal you want to work on?" Multi-select chips plus "Something else?"
/// (60 characters). Skippable. Picks become rules in the plan; the free text becomes suggestions
/// (on-device model or keyword match) under "Suggested for you" in the plan's Change sheet.
struct PersonalGoalsView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var thinking = false
    @FocusState private var typing: Bool

    var body: some View {
        @Bindable var model = model
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    TitleText("Anything personal you want to work on?", size: 30)
                        .padding(.top, 26)
                    Text("Pick any. We'll fit them into your plan.")
                        .font(.app(17))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 14)
                    FlowLayout(spacing: 10) {
                        ForEach(PersonalGoal.allCases) { chip($0) }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Something else?")
                            .font(.app(15, .medium))
                            .foregroundStyle(Color.textSecondary)
                        TextField("e.g. Learn to draw", text: $model.draft.personalOther)
                            .font(.app(18, .medium))
                            .foregroundStyle(Color.textPrimary)
                            .focused($typing)
                            .submitLabel(.done)
                            .onChange(of: model.draft.personalOther) { _, new in
                                if new.count > PersonalGoal.otherMaxLength {
                                    model.draft.personalOther = String(new.prefix(PersonalGoal.otherMaxLength))
                                }
                            }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: Metrics.optionRadius)
                    .padding(.top, 18)
                }
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        } actions: {
            VStack(spacing: 4) {
                PrimaryButton(hasAnswer ? "Continue" : "Skip", isLoading: thinking) { finish() }
            }
        }
    }

    private var hasAnswer: Bool {
        !model.draft.personalGoals.isEmpty || !model.draft.personalOther.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func finish() {
        typing = false
        let text = model.draft.personalOther
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            model.draft.personalIdeas = []
            next()
            return
        }
        thinking = true
        Task {
            let ideas = await RuleIdeas.ideas(for: text, intensity: model.draft.myIntensity)
            model.draft.personalIdeas = ideas
            thinking = false
            next()
        }
    }

    private func chip(_ g: PersonalGoal) -> some View {
        let selected = model.draft.personalGoals.contains(g)
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                if selected { model.draft.personalGoals.removeAll { $0 == g } } else { model.draft.personalGoals.append(g) }
                model.draft.ruleChanges = []
            }
        } label: {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                }
                Text(g.title)
                    .font(.app(16, .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.white : Color.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Capsule().fill(selected ? Color.coral : Color.white))
            .overlay(Capsule().stroke(selected ? Color.coral : Color.cardBorder, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(g.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Wraps its children onto as many centred rows as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var r = rows[rows.count - 1]
            r.width += r.indices.isEmpty ? size.width : size.width + spacing
            r.height = max(r.height, size.height)
            r.indices.append(i)
            rows[rows.count - 1] = r
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
