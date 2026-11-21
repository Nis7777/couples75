import SwiftUI

/// 26: "Did your partner invite you?" First screen when the app opens without a link.
struct CodeEntryView: View {
    @Environment(AppModel.self) private var model
    @State private var code = ""
    @State private var lookup: InviteLookup?
    @State private var resolving = false
    @State private var joining = false
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    TitleText("Did your partner invite you?")
                        .padding(.top, 32)
                    BodyText("Tap the link in their message again, or enter their 6-letter code.")
                    BodyText("Just installed? If you tapped the link before \(Brand.appName) was installed, tap it again now or type the code.")
                        .font(.system(size: 13))
                    codeBoxes
                        .padding(.top, 8)
                    if resolving {
                        ProgressView().tint(.coral)
                    } else if let lookup {
                        Label("\(lookup.inviterName) invited you", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.sage)
                    }
                }
            }
        } actions: {
            PrimaryButton(lookup.map { "Join \($0.inviterName)" } ?? "Join", isEnabled: lookup != nil,
                          isLoading: joining) {
                guard let lookup else { return }
                Task {
                    joining = true
                    _ = await model.join(lookup)
                    joining = false
                }
            }
            TextLinkButton("I don't have a code") {
                model.seenCodeEntry = true
            }
        }
        .onAppear { focused = true }
    }

    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .accessibilityLabel("Invite code, 6 characters")
                .onChange(of: code) { _, new in
                    let clean = InviteCodes.normalize(new)
                    if clean != new { code = clean }
                    lookup = nil
                    if clean.count == 6 { resolve(clean) }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let chars = Array(code)
                    let ch = i < chars.count ? String(chars[i]) : ""
                    Text(ch)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: 52)
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(i == chars.count && focused ? Color.coral : Color.cardBorder,
                                    lineWidth: i == chars.count && focused ? 1.5 : 1))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func resolve(_ clean: String) {
        resolving = true
        Task {
            let result = await model.lookupCode(clean)
            resolving = false
            if code == clean { lookup = result }
        }
    }
}
