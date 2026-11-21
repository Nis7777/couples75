import SwiftUI

/// Priming screen before the system prompt (section 5).
struct NotificationPrimingView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.coral, Color.gold)
                    .accessibilityHidden(true)
                TitleText("Turn on reminders so neither of you misses a day")
                BodyText("A wake-up nudge, a 21:00 warning if rules are left, and a heads-up when \(model.partnerName) checks in.")
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Turn on reminders") {
                Task {
                    await NotificationManager.shared.requestPermission()
                    await NotificationManager.shared.reschedule(model: model)
                    next()
                }
            }
            TextLinkButton("Not now") { next() }
        }
    }
}
