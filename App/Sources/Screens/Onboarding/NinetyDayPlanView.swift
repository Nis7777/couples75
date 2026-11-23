import SwiftUI

/// "Your next 90 days": the real next 7 dates (week 1), the habits for week 1 straight from the stored plan
/// (`draft.planRules`, the same rows the plan review shows and that become the real rules), with edit, delete and
/// "+ Add a habit", then the FAQ. Continue stays pinned at the bottom.
struct NinetyDayPlanView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var editing: EditRow?
    @State private var adding = false
    @State private var problem: String?
    @State private var openFAQ: String?

    private struct EditRow: Identifiable {
        var index: Int
        var id: Int { index }
    }

    var body: some View {
        let d = model.draft
        OnboardingPage(step: d.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your next 90 days")
                            .font(.app(30, .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Built from your answers. Tap any habit to edit.")
                            .font(.app(16))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 16)
                    WeekStrip()
                    habits(d)
                    PartnerHabitsCard(name: d.partnerName, habits: d.partnerPlan?.map(\.title))
                    faq
                }
                .padding(.bottom, 16)
            }
        } actions: {
            PrimaryButton("Continue", isEnabled: d.tooManyRules == 0 && !d.planRules.isEmpty) { next() }
        }
        .onAppear { if model.draft.planRules.isEmpty { model.draft.generatePlan() } }
        .sheet(item: $editing) { row in DraftRuleSwapSheet(index: row.index, title: "Edit habit") }
        .sheet(isPresented: $adding) { AddHabitSheet() }
        .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: Habits

    private func habits(_ d: OnboardingDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your habits for week 1")
                    .font(.app(19, .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(d.planRules.count) of \(Brand.maxRules)")
                    .font(.app(13, .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            ForEach(d.planRows) { row in
                habitRow(row, rule: d.planRules[row.index], partner: d.partnerName)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            if d.canAddRow {
                Button {
                    Haptics.tap()
                    adding = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.peach))
                        Text("Add a habit").font(.app(16, .semibold))
                        Spacer()
                    }
                    .foregroundStyle(Color.coral)
                    .padding(.horizontal, 12)
                    .frame(height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.coral.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .animation(.open(0.25), value: d.planRules.map(\.id))
    }

    private func habitRow(_ row: PlanRow, rule: PlanRuleRow, partner: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: RuleLibrary.icon(for: rule.a.libraryKey, type: rule.a.type))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.coral)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.peach))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.left)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                Text(rule.a.type == .photo ? "every day · photo proof" : "every day · honour tap")
                    .font(.app(12, .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button {
                Haptics.tap()
                editing = EditRow(index: row.index)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Edit \(row.left)")
            Button {
                if let why = model.draft.removeProblem(row.index) {
                    Haptics.warning()
                    problem = why
                } else {
                    Haptics.tap()
                    withAnimation(.open(0.25)) { model.draft.removeRow(row.index) }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.coral)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Delete \(row.left)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .card(radius: 16, shadow: false)
        .contentShape(Rectangle())
        .onTapGesture { editing = EditRow(index: row.index) }
    }

    // MARK: FAQ

    private var faq: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Questions")
                .font(.app(19, .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 6)
            ForEach(OnboardingFAQ.items) { item in
                let open = openFAQ == item.id
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Haptics.tap()
                        withAnimation(.open(0.25)) { openFAQ = open ? nil : item.id }
                    } label: {
                        HStack(alignment: .top) {
                            Text(item.question)
                                .font(.app(16, .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.textSecondary)
                                .rotationEffect(.degrees(open ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(open ? .isSelected : [])
                    if open {
                        Text(item.answer)
                            .font(.app(15))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                .padding(14)
                .card(radius: 16, shadow: false)
            }
        }
    }
}

/// The real next 7 dates, starting today, as week 1 (highlighted), with "Week 1 of 13".
struct WeekStrip: View {
    private var days: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        let cal = Calendar.current
        let letters = cal.veryShortStandaloneWeekdaySymbols
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week 1")
                    .font(.app(15, .bold))
                    .foregroundStyle(Color.coral)
                Spacer()
                Text("of 13")
                    .font(.app(13, .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    VStack(spacing: 4) {
                        Text(letters[cal.component(.weekday, from: day) - 1])
                            .font(.app(12, .semibold))
                            .foregroundStyle(i == 0 ? Color.white : Color.textSecondary)
                        Text("\(cal.component(.day, from: day))")
                            .font(.app(17, .bold))
                            .foregroundStyle(i == 0 ? Color.white : Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(i == 0 ? Color.coral : Color.white.opacity(0.8)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)) + (i == 0 ? ", today" : ""))
                }
            }
        }
        .padding(12)
        .peachBox(radius: 18)
    }
}

/// "+ Add a habit": the same picker as Change, adding a row for both of you (each at your own level).
struct AddHabitSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var who = 0

    var body: some View {
        let d = model.draft
        RuleChangeSheet(
            title: "Add a habit",
            currentTitle: nil,
            who: $who,
            suggestions: d.suggestions(intensity: d.myIntensity, extra: d.personalIdeas),
            intensity: d.myIntensity,
            note: "Added to your habits. \(d.partnerName) picks their own.",
            validate: { idea in
                if !d.canAddRow { return "Up to \(Brand.maxRules) habits each." }
                if d.planRows.contains(where: { $0.left == idea.title }) { return "You already have this one." }
                return nil
            },
            onPick: { idea in
                withAnimation(.open(0.25)) { model.draft.addRow(idea) }
                dismiss()
            })
    }
}
