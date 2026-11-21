import SwiftUI

/// 3.4: "Couples 75 is iPhone-only for now". No paywall ever.
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
                Image(systemName: sent ? "checkmark.circle.fill" : "iphone")
                    .font(.system(size: 60))
                    .foregroundStyle(sent ? Color.sage : Color.coral)
                    .accessibilityHidden(true)
                if sent {
                    TitleText("Thanks! We'll be in touch.")
                } else {
                    TitleText("\(Brand.appName) is iPhone-only for now")
                    BodyText("Leave your email and we'll tell you when Android is ready.")
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 17))
                        .padding(16)
                        .card(radius: 14)
                        .accessibilityLabel("Email")
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
