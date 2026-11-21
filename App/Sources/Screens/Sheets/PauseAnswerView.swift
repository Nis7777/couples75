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
                VStack(spacing: 10) {
                    HStack {
                        CloseButton { dismiss() }
                        Spacer()
                    }
                    .padding(.horizontal, -12)
                    SmallLabel(text: "Pause request")
                    TitleText("\(requester) asked to pause", size: 28)
                    CoupleScene(left: model.sceneA, right: model.sceneB, crop: 0.52, overlap: -0.04)
                        .frame(height: 230)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Life happens")
                            .font(.app(19, .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(info.request.reason). Pause \(info.dates.count) day\(info.dates.count == 1 ? "" : "s") from \(startText)? Paused days don't count for either of you and don't use a save. If you don't answer in \(Int(Brand.pauseAutoAcceptHours)) hours, it's accepted.")
                            .font(.app(16))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                    .padding(.top, 4)
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
