import SwiftUI
import StoreKit

/// "Help us help more couples": a short line, the testimonial cards (`Testimonials`: placeholders show in DEBUG
/// builds only, so nothing fake ships) and Apple's rating prompt, asked once when the screen appears. Apple decides
/// whether it actually shows (at most 3 times a year per person).
struct SocialProofView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.requestReview) private var requestReview
    var next: () -> Void
    var back: () -> Void

    private static let askedKey = "onboardingRatingAsked"

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    CustomIcon(asset: "icon_challenge", symbol: "heart.circle.fill", size: 72, color: .coral)
                        .padding(.top, 18)
                    TitleText("Help us help more couples", size: 30)
                    BodyText("\(Brand.appName) is made by a tiny team. A rating helps other couples find it, and takes five seconds.")
                    ForEach(Testimonials.shown) { t in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.gold)
                                }
                                if t.isPlaceholder {
                                    Spacer()
                                    Pill(text: "PLACEHOLDER", fill: .coral, size: 11)
                                }
                            }
                            Text("“\(t.quote)”")
                                .font(.app(16, .medium))
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(t.name)
                                .font(.app(13, .semibold))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 18, shadow: false)
                    }
                }
                .padding(.bottom, 16)
            }
        } actions: {
            PrimaryButton("Continue") { next() }
        }
        .task {
            guard !UserDefaults.standard.bool(forKey: Self.askedKey) else { return }
            UserDefaults.standard.set(true, forKey: Self.askedKey)
            // Let the screen settle first, so the prompt doesn't cover the transition.
            try? await Task.sleep(nanoseconds: 700_000_000)
            requestReview()
        }
    }
}
