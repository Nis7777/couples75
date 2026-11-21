import SwiftUI

/// 28: warm-up day. A peach banner with a coral border at the top, the couple, "Today's practice"
/// in two columns, "Practise check-in". Practice check-ins are stored with isWarmup = true.
struct WarmupView: View {
    @Environment(AppModel.self) private var model
    var onBack: (() -> Void)?
    @State private var cameraRule: RuleFact?
    @State private var honourRule: RuleFact?

    private var partnerJoined: Bool { model.memberB?.joinedAt != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                CoupleHeader(pill: "Warm-up", onBack: onBack)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Warm-up day: this doesn't count")
                        .font(.app(18, .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text(partnerJoined
                         ? "Practise a check-in today. Day 1 starts tomorrow morning."
                         : "Practise a check-in while you wait. Day 1 starts the morning after \(model.nameB) joins.")
                        .font(.app(15))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .peachBox(radius: 18)

                CoupleScene(left: model.sceneA, right: model.sceneBJoined,
                            crop: 0.56, overlap: -0.05)
                    .frame(height: 230)

                Text("Today's practice")
                    .font(.app(21, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 12) {
                    practiceColumn(name: model.nameA, member: model.memberA, rules: rulesA)
                    practiceColumn(name: model.nameB, member: model.memberB, rules: rulesB)
                }

                PrimaryButton("Practise check-in", isEnabled: nextRule != nil) {
                    guard let r = nextRule else { return }
                    open(r)
                }
                if !partnerJoined {
                    Text("Waiting for \(model.nameB)")
                        .font(.app(14, .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $cameraRule) { r in CheckInCameraView(rule: r) }
        .sheet(item: $honourRule) { r in HonourSheet(rule: r).presentationDetents([.height(340)]) }
    }

    private var rulesA: [RuleFact] { model.memberA.map { model.rules(for: $0.id) } ?? [] }
    private var rulesB: [RuleFact] {
        if let b = model.memberB, !model.rules(for: b.id).isEmpty { return model.rules(for: b.id) }
        return model.draftRulesForB
    }

    private var myItems: [ChecklistItem] { model.myToday?.items ?? [] }

    private var nextRule: RuleFact? {
        myItems.first { !$0.isChecked }?.rule ?? myItems.first?.rule
    }

    private func open(_ r: RuleFact) {
        if r.type == .photo { cameraRule = r } else { honourRule = r }
    }

    private func practiceColumn(name: String, member: MemberFact?, rules: [RuleFact]) -> some View {
        let isMe = member?.id == model.meID
        let items = member.flatMap { model.state.today[$0.id]?.items } ?? []
        return VStack(alignment: .leading, spacing: 14) {
            Text(name)
                .font(.app(18, .bold))
                .foregroundStyle(Color.textPrimary)
            ForEach(rules) { r in
                let checked = items.first { $0.rule.id == r.id }?.isChecked ?? false
                Button {
                    if isMe { open(r) }
                } label: {
                    HStack(spacing: 10) {
                        CheckCircle(isOn: checked, color: .coral, size: 22)
                        Text(r.title)
                            .font(.app(15, .medium))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .disabled(!isMe)
                .accessibilityLabel("\(r.title), \(checked ? "practised" : "not practised")")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .card(radius: 18)
    }
}
