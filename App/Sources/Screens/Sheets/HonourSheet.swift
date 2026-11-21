import SwiftUI

/// "Did you stick to {rule} today?" — "Yes, I did ›" is only enabled after 18:00 local.
/// `fallback`: a photo rule submitted as an honour tap because iCloud is full (that day only).
struct HonourSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var rule: RuleFact
    var fallback = false
    @State private var saving = false

    private var isEvening: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = model.me?.tz ?? .current
        return cal.component(.hour, from: model.now()) >= 18
    }

    private var enabled: Bool { fallback || model.isWarmup || isEvening }

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.cardBorder).frame(width: 40, height: 5).padding(.top, 10)
            IconBadge(systemName: fallback ? "icloud.slash" : "hand.raised.fill",
                      color: fallback ? .coral : .sage, size: 70)
                .padding(.top, 4)
            TitleText("Did you stick to \(rule.title.lowercasedFirst) today?", size: 24)
            if !enabled {
                BodyText("Come back after 18:00 to confirm. Tap tonight.")
            } else if fallback {
                BodyText("iCloud is full, so this counts as an honour tap for today only.")
            } else {
                BodyText("Be honest. \(model.partnerName) can react, but can't fail your day.")
            }
            Spacer(minLength: 0)
            PrimaryButton("Yes, I did", isEnabled: enabled, isLoading: saving) {
                Task {
                    saving = true
                    let ok = await model.checkIn(rule: rule, photo: nil, honourFallback: fallback)
                    saving = false
                    if ok { dismiss() }
                }
            }
            TextLinkButton("Not yet") { dismiss() }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .screenBackground()
    }
}

extension String {
    /// "No sugar" → "no sugar", keeps "In bed by 23:30" readable.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + String(dropFirst())
    }
}
