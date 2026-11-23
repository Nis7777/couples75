import SwiftUI
import UIKit

/// Step 3 (03_names): "Who's in this with you?" Two big cards with a circle avatar on the left,
/// a small "You"/"Partner" label above the name.
struct NamesView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    @FocusState private var focus: Field?

    private enum Field { case me, partner }

    private var valid: Bool {
        !model.draft.myName.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.draft.partnerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        @Bindable var model = model
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    TitleText("Who's in this with you?", size: 30)
                        .padding(.top, 28)
                        .padding(.bottom, 6)
                    nameCard(label: "You", text: $model.draft.myName, field: .me, hint: nil) {
                        BustCircle(avatar: model.draft.avatar, size: 96)
                    }
                    nameCard(label: "Partner", text: $model.draft.partnerName, field: .partner,
                             hint: "Picks their character later") {
                        BustCircle(avatar: nil, size: 96, fill: Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.textSecondary.opacity(0.55),
                                                 style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        } actions: {
            PrimaryButton("Continue", isEnabled: valid) {
                focus = nil
                model.draft.myName = model.draft.myName.trimmingCharacters(in: .whitespaces)
                model.draft.partnerName = model.draft.partnerName.trimmingCharacters(in: .whitespaces)
                next()
            }
        }
        .onAppear { if model.draft.myName.isEmpty { focus = .me } }
    }

    private func nameCard<Avatar: View>(label: String, text: Binding<String>, field: Field, hint: String?,
                                        @ViewBuilder avatar: () -> Avatar) -> some View {
        HStack(spacing: 20) {
            avatar()
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.app(16, .medium))
                    .foregroundStyle(Color.textSecondary)
                TextField(field == .me ? "Your name" : "Their name", text: text)
                    .font(.app(28, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .textContentType(field == .me ? UITextContentType.givenName : nil)
                    .autocorrectionDisabled()
                    .submitLabel(field == .me ? .next : .done)
                    .focused($focus, equals: field)
                    .onSubmit { focus = field == .me ? .partner : nil }
                    .onChange(of: text.wrappedValue) { _, new in
                        if new.count > 24 { text.wrappedValue = String(new.prefix(24)) }
                    }
                    .accessibilityLabel(field == .me ? "Your name" : "Your partner's name")
                if let hint {
                    Text(hint)
                        .font(.app(15))
                        .foregroundStyle(Color.textSecondary.opacity(0.85))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(minHeight: 136)
        .card()
        .contentShape(Rectangle())
        .onTapGesture { focus = field }
    }
}
