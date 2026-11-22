import SwiftUI
import StoreKit

/// "Our week": both partners' last 7 days, with a shareable card. A good week may end with the
/// App Store rating prompt (at most every 120 days).
struct WeeklyRecapView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    var recap: WeeklyRecap
    @State private var shareImage: Image?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SmallLabel(text: "Our week")
                    .padding(.top, 28)
                TitleText(recap.headline, size: 30)
                WeekRecapCard(recap: recap, left: model.sceneA, right: model.sceneBBuilt)
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview("Our week on Couples 75", image: shareImage)) {
                        PrimaryButtonLabel(title: "Share our week")
                    }
                }
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                SecondaryButton("Done") { finish() }
            }
            .background(Color.ivory.opacity(0.95))
        }
        .background(AppBackground())
        .task { render() }
    }

    @MainActor
    private func render() {
        let card = WeekRecapCard(recap: recap, left: model.sceneA, right: model.sceneBBuilt)
            .frame(width: 390)
            .padding(20)
            .background(Color.ivory)
            .environment(model)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }

    private func finish() {
        if recap.me.completeDays >= 5, ReviewPrompt.canAsk {
            ReviewPrompt.markAsked()
            requestReview()
        }
        dismiss()
    }
}

/// The recap card (also rendered as the share image; never contains photos).
struct WeekRecapCard: View {
    var recap: WeeklyRecap
    var left: SceneCharacter
    var right: SceneCharacter?

    var body: some View {
        VStack(spacing: 14) {
            CoupleScene(left: left, right: right, leftPose: .cheer, rightPose: .cheer, crop: 0.56, overlap: -0.04)
                .frame(height: 170)
            if recap.partner != nil {
                Text("\(recap.bothCompleteDays) of 7 days together")
                    .font(.app(22, .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            HStack(spacing: 12) {
                person(recap.me, color: .coral)
                if let p = recap.partner { person(p, color: .sage) }
            }
            HStack(spacing: 12) {
                stat("\(recap.streak)", "Streak")
                stat("\(recap.savesUsed)", "Saves used")
                stat("\(recap.me.photos + (recap.partner?.photos ?? 0))", "Photos")
            }
            Text(Brand.appName)
                .font(.app(12, .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(18)
        .card()
    }

    private func person(_ p: WeeklyRecap.Person, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.name).font(.app(16, .bold)).foregroundStyle(color)
            Text("\(p.completeDays)/\(max(p.countedDays, 1)) days")
                .font(.app(22, .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Circle()
                        .fill(i < p.completeDays ? color : color.opacity(0.18))
                        .frame(width: 9, height: 9)
                }
            }
            Text("\(p.reactionsReceived) reactions")
                .font(.app(12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.peach.opacity(0.6)))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.app(20, .bold)).foregroundStyle(Color.textPrimary)
            Text(label).font(.app(12, .medium)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
