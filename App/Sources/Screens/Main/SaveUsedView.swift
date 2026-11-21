import SwiftUI

/// 23: shown to both members the next time they open the app after a miss.
struct SaveUsedView: View {
    @Environment(AppModel.self) private var model
    var event: SaveEvent
    var onDone: () -> Void

    private var round: RoundState? { model.state.rounds.first { $0.number == event.roundNumber } }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 12) {
                HStack {
                    CloseButton { onDone() }
                    Spacer()
                }
                .padding(.horizontal, -12)
                CoupleScene(left: model.sceneA, right: model.sceneB, leftPose: .stand, rightPose: .crossed,
                            crop: 0.56, overlap: 0.02)
                    .frame(maxHeight: 300)
                    .padding(.horizontal, -8)
                TitleText("Save used", size: 30)
                    .padding(.top, 4)
                BodyText("\(model.name(of: event.memberID)) missed a rule on Day \(event.dayNumber). One save covered it, so the run continues.", size: 16)
                    .padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 12) {
                    infoRow("Saves left", "\(round?.savesLeft ?? 0) of \(Brand.savesPerRound)")
                    infoRow("Score", scoreText)
                    Text("Whoever has more misses at Day 75 owes the bet.")
                        .font(.app(14))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .padding(.top, 10)
                Spacer(minLength: 0)
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

    /// Label above value, like 23's info card.
    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.app(14)).foregroundStyle(Color.textSecondary)
            Text(value).font(.app(18, .bold)).foregroundStyle(Color.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}
