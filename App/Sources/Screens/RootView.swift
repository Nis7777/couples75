import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AppBackground()
            switch model.route {
            case .loading:
                ProgressView().tint(.coral)
            case .iCloudRequired:
                ICloudRequiredView()
            case .codeEntry:
                CodeEntryView()
            case .onboardingA:
                OnboardingFlow()
            case .joinB:
                JoinFlow()
            case .partnerLeft:
                PartnerLeftView()
            case .main:
                MainView()
            }
            if let toast = model.toast {
                ToastView(text: toast)
                    .task {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        model.toast = nil
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.route)
        .font(.app(16))
        .foregroundStyle(Color.textPrimary)
        .tint(.coral)
        .preferredColorScheme(.light)
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct ToastView: View {
    var text: String

    var body: some View {
        VStack {
            Text(text)
                .font(.app(15, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.textPrimary.opacity(0.92)))
                .padding(.top, 12)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityAddTraits(.isStaticText)
    }
}
