import SwiftUI

/// 3.4: "Pact is iPhone-only for now". No paywall ever. (Never name another phone platform here: guideline 2.3.10.)
struct AndroidWaitlistView: View {
    @Environment(AppModel.self) private var model
    var done: () -> Void
    var back: () -> Void
    @State private var email = ""
    @State private var sent = false
    @State private var sending = false

    private var valid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 5
    }

    var body: some View {
        OnboardingPage(step: nil, back: sent ? nil : back) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                IconBadge(systemName: sent ? "checkmark.circle.fill" : "iphone", color: sent ? Color.sage : Color.coral)
                if sent {
                    TitleText("Thanks! We'll be in touch.")
                } else {
                    TitleText("\(Brand.appName) is iPhone-only for now")
                    BodyText("Leave your email and we'll tell you when \(model.draft.partnerName.isEmpty ? "your partner" : model.draft.partnerName) can join.")
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.app(17))
                        .padding(16)
                        .card(radius: 14)
                        .accessibilityLabel("Email")
                    // Said where the email is collected (GDPR, Guideline 5.1.1).
                    VStack(spacing: 2) {
                        Text("We only use it to tell you, and you can ask us to delete it.")
                        Link("Privacy Policy", destination: Brand.privacyURL)
                            .underline()
                    }
                    .font(.app(13))
                    .foregroundStyle(Color.textSecondary)
                    .tint(Color.textSecondary)
                    .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
        } actions: {
            if sent {
                PrimaryButton("Done") {
                    model.draft = OnboardingDraft()
                    done()
                }
            } else {
                PrimaryButton("Notify me", isEnabled: valid, isLoading: sending) {
                    Task {
                        sending = true
                        let ok = await model.joinWaitlist(email: email.trimmingCharacters(in: .whitespaces))
                        sending = false
                        if ok { withAnimation { sent = true } }
                    }
                }
            }
        }
    }
}
