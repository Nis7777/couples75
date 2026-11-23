import SwiftUI

/// Profile → "Our rules": both partners' current rules and "Request a change" (Part 8).
/// Rules lock on Day 1: each person gets one swap per round (it needs approval and starts the next local
/// day); anything else applies from the next round.
struct OurRulesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var changing: RuleFact?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    rulesCard(name: model.me?.name ?? model.nameA, rules: model.rules(for: model.meID), color: model.isOwner ? .coral : .sage)
                    if let p = model.partner {
                        rulesCard(name: p.name, rules: model.rules(for: p.id), color: model.isOwner ? .sage : .coral)
                    }
                    if !model.myPendingProposals.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Waiting for \(model.partnerName)")
                                .font(.app(16, .bold))
                                .foregroundStyle(Color.textPrimary)
                            ForEach(model.myPendingProposals) { p in
                                HStack(spacing: 8) {
                                    Pill(text: "Pending", fill: .brownChip, size: 11)
                                    Text(p.rule.title).font(.app(15, .medium)).foregroundStyle(Color.textPrimary)
                                }
                            }
                        }
                    }
                    RuleRemindersCard()
                    Text(model.ruleChangeTiming.note)
                        .font(.app(14))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton("Request a change", isEnabled: model.partner?.joinedAt != nil) { picking = true }
                    if model.partner?.joinedAt == nil {
                        Text("You can ask for changes once \(model.partnerName) has joined.")
                            .font(.app(13))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.horizontal, Metrics.side)
                .padding(.vertical, 12)
            }
            .background(Color.ivory.ignoresSafeArea())
            .navigationTitle("Our habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Our rules").font(.app(17, .bold)).foregroundStyle(Color.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.coral)
                }
            }
            .confirmationDialog("Which rule?", isPresented: $picking, titleVisibility: .visible) {
                ForEach(model.rules(for: model.meID)) { r in
                    Button(r.title) { changing = r }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $changing) { r in RequestChangeSheet(rule: r) }
        }
    }

    private func rulesCard(name: String, rules: [RuleFact], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name).font(.app(18, .bold)).foregroundStyle(color)
            ForEach(rules) { r in
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(r.title).font(.app(15, .medium)).foregroundStyle(Color.textPrimary)
                    Spacer(minLength: 4)
                    Image(systemName: r.type == .photo ? "camera" : "hand.raised")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// The Change sheet for one of my rules, sent to the partner to approve.
struct RequestChangeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var rule: RuleFact
    @State private var who = 0

    var body: some View {
        let intensity = model.me.map { $0.fitnessLevel.intensity } ?? .standard
        let rules = model.rules(for: model.meID)
        let current = Set(rules.map(\.libraryKey))
        let personal = PersonalGoal.allCases.map(\.ruleKey).filter { !current.contains($0) }
        RuleChangeSheet(
            title: "Request a change",
            currentTitle: rule.title,
            who: $who,
            suggestions: Array(personal.compactMap { RuleIdea.library($0, intensity: intensity) }.prefix(3)),
            intensity: intensity,
            note: model.ruleChangeTiming.note,
            validate: { idea in
                let photos = rules.filter { $0.position != rule.position && $0.type == .photo }.count
                    + (idea.type == .photo ? 1 : 0)
                return photos >= Brand.minPhotoRules ? nil : "Keep at least \(Brand.minPhotoRules) photo rules."
            },
            onPick: { idea in
                Task {
                    if await model.requestRuleChange(position: rule.position, idea: idea) { dismiss() }
                }
            })
    }
}

/// Per-rule reminder times ("Meditate at 07:00"). Local notifications on this phone.
struct RuleRemindersCard: View {
    @Environment(AppModel.self) private var model
    @State private var times: [String: String] = RuleReminders.all

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reminders").font(.app(18, .bold)).foregroundStyle(Color.textPrimary)
            Text("Get a nudge at a set time for any rule. Skipped once it's done.")
                .font(.app(13))
                .foregroundStyle(Color.textSecondary)
            ForEach(model.rules(for: model.meID)) { r in
                let key = RuleReminders.key(for: r)
                HStack(spacing: 10) {
                    Text(r.title)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    if let t = times[key] {
                        DatePicker("Time", selection: Binding(
                            get: { ClockTime.date(from: t) },
                            set: { set(ClockTime.string(from: $0), r) }), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Button { set(nil, r) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textSecondary)
                        }
                        .accessibilityLabel("Remove reminder for \(r.title)")
                    } else {
                        Button("Add time") { set(r.type == .honour ? "20:00" : "09:00", r) }
                            .font(.app(14, .semibold))
                            .foregroundStyle(Color.coral)
                    }
                }
                .frame(minHeight: 40)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18)
    }

    private func set(_ time: String?, _ rule: RuleFact) {
        RuleReminders.set(time, for: rule)
        times = RuleReminders.all
        Task { await NotificationManager.shared.reschedule(model: model) }
    }
}
