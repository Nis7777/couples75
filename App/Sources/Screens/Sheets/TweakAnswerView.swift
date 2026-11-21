import SwiftUI

/// A answers B's "Accept or tweak" proposal (no answer in 24 h = accepted).
struct TweakAnswerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var info: TweakInfo
    @State private var saving = false

    private var proposer: String { model.name(of: info.tweak.proposedBy) }

    private var oldRuleTitle: String? {
        guard let pos = info.tweak.payload.swappedPosition else { return nil }
        let base = model.facts.rules
            .filter { $0.memberID == info.tweak.proposedBy && $0.position == pos }
            .max { $0.createdAt < $1.createdAt }
        return base?.title
    }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 14) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                }
                SmallLabel(text: "Plan change")
                TitleText("\(proposer) suggested a change")
                VStack(alignment: .leading, spacing: 12) {
                    if let newRule = info.tweak.payload.newRule {
                        changeRow(title: "\(proposer)'s rule", from: oldRuleTitle ?? "", to: newRule.title)
                    }
                    if let bet = info.tweak.payload.newBet {
                        changeRow(title: "The bet", from: RulesEngine.config(for: 1, facts: model.facts)?.betText ?? "", to: bet)
                    }
                    Text("If you don't answer by \(info.autoAcceptAt.formatted(date: .omitted, time: .shortened)), \(proposer)'s version is used.")
                        .font(.app(13))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Accept", isLoading: saving) {
                Task {
                    saving = true
                    await model.answerTweak(info, accepted: true)
                    saving = false
                    dismiss()
                }
            }
            SecondaryButton("Keep the original") {
                Task {
                    await model.answerTweak(info, accepted: false)
                    dismiss()
                }
            }
        }
        .screenBackground()
    }

    private func changeRow(title: String, from: String, to: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.app(13, .semibold)).foregroundStyle(Color.textSecondary)
            HStack(spacing: 6) {
                Text(from).strikethrough().foregroundStyle(Color.textSecondary)
                Image(systemName: "arrow.right").foregroundStyle(Color.coral)
                Text(to).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
            }
            .font(.app(15))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(from) changes to \(to)")
    }
}
