import SwiftUI

/// 28: "Warm-up day: this doesn't count". Practice check-ins are stored with isWarmup = true.
struct WarmupView: View {
    @Environment(AppModel.self) private var model
    var onBack: (() -> Void)?
    @State private var cameraRule: RuleFact?
    @State private var honourRule: RuleFact?

    private var partnerJoined: Bool { model.memberB?.joinedAt != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel("Back")
                    }
                    Text("\(model.nameA) & \(model.nameB)")
                        .font(.rounded(20))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Pill(text: "Warm-up", fill: .peach, foreground: .coral)
                }
                .padding(.top, 8)

                Banner(text: "Warm-up day: this doesn't count", fill: .peach, foreground: .coral, icon: "sun.haze")

                BodyText(partnerJoined
                         ? "Practise a check-in today. Day 1 starts tomorrow morning."
                         : "Practise a check-in while you wait. Day 1 starts the morning after \(model.nameB) joins.")

                CoupleScene(left: model.sceneA, right: model.sceneBJoined, leftPose: .stretch, rightPose: .stretch)
                    .frame(height: 240)

                Text("Today's practice")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 12) {
                    practiceColumn(name: model.nameA, member: model.memberA, rules: rulesA, color: .coral)
                    practiceColumn(name: model.nameB, member: model.memberB, rules: rulesB, color: .sage)
                }

                PrimaryButton("Practise check-in", isEnabled: nextRule != nil) {
                    guard let r = nextRule else { return }
                    open(r)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $cameraRule) { r in CheckInCameraView(rule: r) }
        .sheet(item: $honourRule) { r in HonourSheet(rule: r).presentationDetents([.height(320)]) }
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

    private func practiceColumn(name: String, member: MemberFact?, rules: [RuleFact], color: Color) -> some View {
        let isMe = member?.id == model.meID
        let items = member.flatMap { model.state.today[$0.id]?.items } ?? []
        return VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            ForEach(rules) { r in
                let checked = items.first { $0.rule.id == r.id }?.isChecked ?? false
                Button {
                    if isMe { open(r) }
                } label: {
                    HStack(spacing: 8) {
                        CheckCircle(isOn: checked, color: color, size: 20)
                        Text(r.title)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .disabled(!isMe)
                .accessibilityLabel("\(r.title), \(checked ? "practised" : "not practised")")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
