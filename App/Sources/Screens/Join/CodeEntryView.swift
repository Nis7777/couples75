import SwiftUI

/// 26: "Did your partner invite you?" First screen when the app opens without a link.
/// Six square code boxes (the active one coral), the button and "I don't have a code" right under them.
struct CodeEntryView: View {
    @Environment(AppModel.self) private var model
    @State private var code = ""
    @State private var lookup: InviteLookup?
    @State private var resolving = false
    @State private var joining = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                TitleText("Did your partner invite you?", size: 28)
                    .padding(.top, 90)
                BodyText("Tap the link in their message again, or enter their 6-letter code.", size: 16)
                    .padding(.top, 20)
                    .padding(.horizontal, 6)
                codeBoxes
                    .padding(.top, 48)
                Group {
                    if resolving {
                        ProgressView().tint(.coral)
                    } else if let lookup {
                        Label("\(lookup.inviterName) invited you", systemImage: "checkmark.circle.fill")
                            .font(.app(15, .semibold))
                            .foregroundStyle(Color.sage)
                    } else {
                        Text("Enter their 6-letter code")
                            .font(.app(14, .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(height: 30)
                .padding(.top, 14)
                PrimaryButton(lookup.map { "Join \($0.inviterName)" } ?? "Join", isEnabled: lookup != nil,
                              isLoading: joining) {
                    guard let lookup else { return }
                    Task {
                        joining = true
                        _ = await model.join(lookup)
                        joining = false
                    }
                }
                .padding(.top, 36)
                TextLinkButton("I don't have a code", color: .textPrimary) {
                    model.seenCodeEntry = true
                }
                .padding(.top, 8)
                Text("Just installed? If you tapped their link before \(Brand.appName) was installed, tap it again now or type the code.")
                    .font(.app(13))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 28)
            }
            .padding(.horizontal, Metrics.side)
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
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    let chars = Array(code)
                    let ch = i < chars.count ? String(chars[i]) : ""
                    let active = focused && (i == chars.count || (chars.count == 6 && i == 5))
                    Text(ch)
                        .font(.app(28, .bold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: 56)
                        .frame(height: 64)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(active ? Color.coral : Color.cardBorder, lineWidth: active ? 1.8 : 1))
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
