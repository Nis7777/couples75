import SwiftUI

/// B's "Your daily habits": made from B's own goals (or what B chose on A's phone). B edits, removes and adds
/// freely: they're B's habits, so A doesn't approve them. 4–6 habits, at least 2 with photo proof.
struct JoinHabitsView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var saving = false
    @State private var editing: EditIndex?
    @State private var adding = false
    @State private var problem: String?

    private struct EditIndex: Identifiable {
        var index: Int
        var id: Int { index }
    }

    private var plan: [RuleIdea] { model.joinDraft?.plan ?? [] }

    var body: some View {
        OnboardingPage(step: 5, total: JoinSteps.total, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    BustCircle(avatar: model.joinDraft?.avatar, size: 96, ring: Color.peachDeep, ringWidth: 4,
                               fill: Color.peach.opacity(0.6))
                        .padding(.top, 10)
                        .accessibilityHidden(true)
                    TitleText("Your daily habits", size: 30)
                    BodyText("From your goals, at your level. They're yours: change anything. \(model.nameA) has their own.",
                             size: 15)
                    VStack(spacing: 10) {
                        ForEach(Array(plan.enumerated()), id: \.offset) { i, idea in row(i, idea) }
                        if plan.count < Brand.maxRules {
                            Button {
                                Haptics.tap()
                                adding = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .bold))
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Color.sage.opacity(0.12)))
                                    Text("Add a habit").font(.app(16, .semibold))
                                    Spacer()
                                }
                                .foregroundStyle(Color.sage)
                                .padding(.horizontal, 12)
                                .frame(height: 56)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.sage.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .animation(.open(0.25), value: plan)
                }
                .padding(.bottom, 20)
            }
        } actions: {
            PrimaryButton("Looks good", isEnabled: plan.count >= Brand.minRules, isLoading: saving) {
                Task {
                    saving = true
                    let ok = await model.submitJoinPlan()
                    saving = false
                    if ok { next() }
                }
            }
        }
        .onAppear {
            // Habits chosen on A's phone start the list; otherwise they come from B's goals.
            guard model.joinDraft?.plan == nil else { return }
            let pending = model.pendingIdeasForB
            if !pending.isEmpty { model.joinDraft?.plan = pending } else { model.joinDraft?.generatePlan() }
        }
        .sheet(item: $editing) { e in habitSheet(replacing: e.index) }
        .sheet(isPresented: $adding) { habitSheet(replacing: nil) }
        .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func row(_ i: Int, _ idea: RuleIdea) -> some View {
        HStack(spacing: 12) {
            Image(systemName: RuleLibrary.icon(for: idea.libraryKey, type: idea.type))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.sage)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.sage.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.title).font(.app(16, .semibold)).foregroundStyle(Color.textPrimary).lineLimit(2)
                Text(idea.type == .photo ? "every day · photo proof" : "every day · honour tap")
                    .font(.app(12, .medium)).foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 4)
            Button {
                editing = EditIndex(index: i)
            } label: {
                Image(systemName: "pencil").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary).frame(width: 36, height: 36)
            }
            .accessibilityLabel("Edit \(idea.title)")
            Button {
                if let why = model.joinDraft?.removeProblem(i) {
                    Haptics.warning()
                    problem = why
                } else {
                    Haptics.tap()
                    withAnimation(.open(0.25)) { _ = model.joinDraft?.plan?.remove(at: i) }
                }
            } label: {
                Image(systemName: "trash").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.coral).frame(width: 36, height: 36)
            }
            .accessibilityLabel("Delete \(idea.title)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .card(radius: 16, shadow: false)
        .contentShape(Rectangle())
        .onTapGesture { editing = EditIndex(index: i) }
    }

    /// Edit (replace) or add, with the library picker. Keeps at least 2 photo habits and no duplicates.
    private func habitSheet(replacing index: Int?) -> some View {
        let intensity = model.joinDraft?.myIntensity ?? .standard
        let goalKeys = (model.joinDraft?.goals ?? []).flatMap(\.ruleKeys)
        let suggestions = goalKeys.compactMap { RuleIdea.library($0, intensity: intensity) }
            .filter { s in !plan.contains { $0.libraryKey == s.libraryKey } }
        return RuleChangeSheet(
            title: index == nil ? "Add a habit" : "Edit habit",
            currentTitle: index.flatMap { plan.indices.contains($0) ? plan[$0].title : nil },
            who: .constant(0),
            suggestions: Array(suggestions.prefix(6)),
            intensity: intensity,
            note: nil,
            validate: { idea in
                if plan.contains(where: { $0.title == idea.title }) { return "You already have this one." }
                var probe = plan
                if let index, probe.indices.contains(index) { probe[index] = idea } else { probe.append(idea) }
                if probe.count > Brand.maxRules { return "Up to \(Brand.maxRules) habits." }
                if probe.filter({ $0.type == .photo }).count < Brand.minPhotoRules {
                    return "Keep at least \(Brand.minPhotoRules) photo habits."
                }
                return nil
            },
            onPick: { idea in
                withAnimation(.open(0.25)) {
                    if let index, model.joinDraft?.plan?.indices.contains(index) == true {
                        model.joinDraft?.plan?[index] = idea
                    } else {
                        model.joinDraft?.plan = plan + [idea]
                    }
                }
                editing = nil
                adding = false
            })
    }
}

/// B picks B's own goals while joining.
struct JoinGoalsStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        GoalsPicker(goals: Binding(get: { model.joinDraft?.goals ?? [] }, set: { model.joinDraft?.goals = $0 }),
                    step: 4, total: JoinSteps.total,
                    title: "What do you want to level up?",
                    subtitle: "Pick two or more. These become your own daily habits.",
                    next: {
                        model.joinDraft?.generatePlan()
                        next()
                    }, back: back)
    }
}
