import SwiftUI

#if DEBUG
/// Hidden Debug menu (section 7): triple-tap the Today header in DEBUG builds.
struct DebugMenuView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Mode", value: model.isMock ? "Mock" : "CloudKit")
                    LabeledContent("You are", value: model.me.map { "\($0.name) (\($0.role.rawValue))" } ?? "—")
                    LabeledContent("Mock clock", value: model.now().formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Phase", value: phaseText)
                }
                if model.isMock {
                    Section("Who") {
                        action("Act as \(model.nameA)") { model.debugActAs(.a) }
                        action("Act as \(model.nameB)") { model.debugActAs(.b) }
                        if model.memberB?.joinedAt == nil {
                            action("Simulate \(model.nameB) joining") { await model.debugSimulatePartnerJoin() }
                        }
                    }
                    Section("Partner") {
                        action("Simulate partner check-in") { await model.debugPartnerCheckIn() }
                        action("Simulate partner reaction") { await model.debugPartnerReaction() }
                        action("Simulate Sus") { await model.debugPartnerSus() }
                        action("Simulate pause request") { await model.debugPauseRequest() }
                        action("Simulate tweak proposal") { await model.debugTweakProposal() }
                    }
                    Section("Time") {
                        action("Advance to next day") { await model.debugAdvanceDay() }
                        action("Jump to Day 74") { await model.debugJumpToDay74() }
                        action("Simulate miss") { await model.debugSimulateMiss() }
                    }
                    Section("Subscription") {
                        action("Simulate subscription lapse") { await model.debugPartnerLapse() }
                        action("Simulate subscription renewal") { await model.debugPartnerRenew() }
                    }
                    Section {
                        Button("Reset everything", role: .destructive) { confirmReset = true }
                    }
                } else {
                    Section {
                        Text("Debug actions need Mock mode. Run in the Simulator or pass -mock.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Reset everything?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    Task {
                        await model.debugResetEverything()
                        dismiss()
                    }
                }
            }
        }
    }

    private var phaseText: String {
        switch model.state.phase {
        case .noCouple: return "No couple"
        case .waitingForPartner: return "Waiting for partner"
        case .warmup: return "Warm-up"
        case .active: return "Active"
        case .betweenRounds: return "Between rounds"
        case .partnerLeft: return "Partner left"
        }
    }

    private func action(_ title: String, _ run: @escaping () async -> Void) -> some View {
        Button(title) {
            Task {
                await run()
                Haptics.tap()
            }
        }
    }
}
#else
/// Release builds have no Debug menu.
struct DebugMenuView: View {
    var body: some View { EmptyView() }
}
#endif
