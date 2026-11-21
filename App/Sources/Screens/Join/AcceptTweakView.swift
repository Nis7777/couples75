import SwiftUI

/// B step 5 "Accept or tweak": B's 4 rules (from B's fitness level), swap one rule, change the bet.
struct AcceptTweakView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @State private var showSwap = false
    @State private var showBet = false
    @State private var saving = false

    private var jd: JoinDraft { model.joinDraft ?? JoinDraft() }
    private var rules: [RuleFact] { model.proposedRulesForMe(jd) }
    private var changed: Bool { jd.swappedPosition != nil || (jd.changeBet && jd.betText != model.currentBet) }

    var body: some View {
        OnboardingPage(step: 4, total: JoinSteps.total, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    TitleText("Your plan")
                        .padding(.top, 8)
                    BodyText("Set from your fitness level. You can swap one rule and change the bet.")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your daily rules")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.sage)
                        ForEach(rules) { r in
                            HStack(spacing: 10) {
                                Image(systemName: r.type == .photo ? "camera.fill" : "hand.raised.fill")
                                    .foregroundStyle(Color.sage)
                                    .frame(width: 22)
                                Text(r.title)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                if r.position == jd.swappedPosition {
                                    Pill(text: "Swapped", fill: .peach, foreground: .coral)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                    BetBox(bet: jd.changeBet && !jd.betText.isEmpty ? jd.betText : model.currentBet)
                    HStack(spacing: 10) {
                        SecondaryButton(jd.swappedPosition == nil ? "Swap a rule" : "Change swap") { showSwap = true }
                        SecondaryButton("Change the bet") { showBet = true }
                    }
                    if changed {
                        Text("\(model.nameA) gets \(Int(Brand.tweakAutoAcceptHours)) hours to accept your changes. No answer means your version is used.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, 8)
            }
        } actions: {
            PrimaryButton("Looks good", isLoading: saving) {
                Task {
                    saving = true
                    let ok = await model.submitJoinPlan()
                    saving = false
                    if ok { next() }
                }
            }
        }
        .sheet(isPresented: $showSwap) {
            SwapRuleSheet().presentationDetents([.large])
        }
        .sheet(isPresented: $showBet) {
            ChangeBetSheet().presentationDetents([.large])
        }
    }
}

/// Pick one rule to replace, then pick its replacement from the library.
struct SwapRuleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var position: Int?

    var body: some View {
        let jd = model.joinDraft ?? JoinDraft()
        var base = jd
        base.swappedPosition = nil
        base.swapKey = nil
        let rules = model.proposedRulesForMe(base)
        let usedKeys = Set(rules.map { $0.libraryKey })
        return NavigationStack {
            List {
                Section("Replace") {
                    ForEach(rules) { r in
                        Button {
                            position = r.position
                        } label: {
                            HStack {
                                Text(r.title).foregroundStyle(Color.textPrimary)
                                Spacer()
                                if position == r.position { Image(systemName: "checkmark").foregroundStyle(Color.coral) }
                            }
                        }
                    }
                }
                if let position {
                    Section("With") {
                        ForEach(RuleLibrary.all.filter { !usedKeys.contains($0.key) }) { lib in
                            let allowed = model.swapAllowed(base, position: position, key: lib.key)
                            Button {
                                model.joinDraft?.swappedPosition = position
                                model.joinDraft?.swapKey = lib.key
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: lib.type == .photo ? "camera.fill" : "hand.raised.fill")
                                        .foregroundStyle(Color.sage)
                                    Text(lib.title(for: model.level(for: jd)))
                                        .foregroundStyle(allowed ? Color.textPrimary : Color.textSecondary)
                                    Spacer()
                                    if !allowed {
                                        Text("Keep 2 photo rules").font(.caption).foregroundStyle(Color.textSecondary)
                                    }
                                }
                            }
                            .disabled(!allowed)
                        }
                    }
                }
                if jd.swappedPosition != nil {
                    Section {
                        Button("Undo swap", role: .destructive) {
                            model.joinDraft?.swappedPosition = nil
                            model.joinDraft?.swapKey = nil
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Swap a rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct ChangeBetSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var bet: BetOption = .date
    @State private var custom = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    BetPicker(bet: $bet, customBet: $custom)
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("Change the bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.joinDraft?.bet = bet
                        model.joinDraft?.customBet = custom
                        model.joinDraft?.changeBet = true
                        dismiss()
                    }
                    .disabled(bet == .custom && custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            let (o, c) = BetOption.from(text: model.currentBet)
            bet = model.joinDraft?.changeBet == true ? (model.joinDraft?.bet ?? o) : o
            custom = model.joinDraft?.changeBet == true ? (model.joinDraft?.customBet ?? c) : c
        }
    }
}

extension AppModel {
    /// The intensity B's rules use (fitness level + round mode).
    func level(for jd: JoinDraft) -> Intensity {
        let level = Level(mode: RulesEngine.config(for: 1, facts: facts)?.mode ?? .standard)
        return level.adjust((jd.fitness ?? .somewhatActive).intensity)
    }
}
