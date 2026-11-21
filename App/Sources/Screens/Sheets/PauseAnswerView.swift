import SwiftUI

/// 29: receiver side of a pause request.
struct PauseAnswerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var info: PauseInfo
    @State private var saving = false

    private var requester: String { model.name(of: info.request.requestedBy) }
    private var startText: String {
        guard let first = info.dates.first else { return "" }
        let date = first.startInstant(in: model.me?.tz ?? .current)
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        CloseButton { dismiss() }
                        Spacer()
                    }
                    SmallLabel(text: "Pause request")
                    TitleText("\(requester) asked to pause")
                    CoupleScene(left: model.sceneA, right: model.sceneB)
                        .frame(height: 220)
                    BodyText("\(info.request.reason). Pause \(info.dates.count) day\(info.dates.count == 1 ? "" : "s") from \(startText)? Paused days don't count for either of you and don't use a save. If you don't answer in \(Int(Brand.pauseAutoAcceptHours)) hours, it's accepted.")
                        .padding(16)
                        .card()
                }
            }
        } actions: {
            PrimaryButton("Agree", isLoading: saving) {
                Task {
                    saving = true
                    await model.answerPause(info, accepted: true)
                    saving = false
                    dismiss()
                }
            }
            SecondaryButton("Not now") {
                Task {
                    await model.answerPause(info, accepted: false)
                    dismiss()
                }
            }
        }
        .screenBackground()
    }
}
