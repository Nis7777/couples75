import SwiftUI

/// 23: shown to both members the next time they open the app after a miss.
struct SaveUsedView: View {
    @Environment(AppModel.self) private var model
    var event: SaveEvent
    var onDone: () -> Void

    private var round: RoundState? { model.state.rounds.first { $0.number == event.roundNumber } }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 16) {
                CoupleScene(left: model.sceneA, right: model.sceneB, leftPose: .crossed, rightPose: .crossed)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 12)
                TitleText("Save used")
                BodyText("\(model.name(of: event.memberID)) missed a rule on Day \(event.dayNumber). One save covered it, so the run continues.")
                VStack(spacing: 10) {
                    row("Saves left", "\(round?.savesLeft ?? 0) of \(Brand.savesPerRound)")
                    Divider()
                    row("Score", scoreText)
                    Divider()
                    Text("Whoever has more misses at Day 75 owes the bet.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .card()
            }
        } actions: {
            PrimaryButton("Back to today") { onDone() }
        }
        .screenBackground()
    }

    private var scoreText: String {
        let a = model.memberA.map { round?.misses($0.id) ?? 0 } ?? 0
        let b = model.memberB.map { round?.misses($0.id) ?? 0 } ?? 0
        return "\(model.nameA) \(a) · \(model.nameB) \(b)"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}
