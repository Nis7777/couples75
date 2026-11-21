import SwiftUI

/// Shown before step 1 when there's no iCloud account (there is no separate sign-up).
struct ICloudRequiredView: View {
    @Environment(AppModel.self) private var model
    @State private var checking = false

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Image(systemName: "icloud.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.coral)
                    .accessibilityHidden(true)
                TitleText("Turn on iCloud to use \(Brand.appName)")
                BodyText("Your iCloud account is your \(Brand.appName) account. Open Settings → [your name] → iCloud and sign in, then come back.")
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Check again", isLoading: checking) {
                Task {
                    checking = true
                    await model.recheckICloud()
                    checking = false
                }
            }
        }
    }
}
