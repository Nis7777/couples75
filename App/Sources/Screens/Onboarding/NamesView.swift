import SwiftUI
import UIKit

/// Step 3 (03_names): "Who's in this with you?"
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
            ScrollView {
                VStack(spacing: 16) {
                    TitleText("Who's in this with you?")
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    nameCard(label: "You", text: $model.draft.myName, field: .me, hint: nil) {
                        CharacterImage(characterID: model.draft.characterID, pose: .bust,
                                       initial: model.draft.myName.isEmpty ? "Y" : model.draft.myName)
                    }
                    nameCard(label: "Partner", text: $model.draft.partnerName, field: .partner,
                             hint: "Picks their character later") {
                        PartnerOutlineImage()
                    }
                }
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
        HStack(spacing: 16) {
            avatar()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                TextField(field == .me ? "Your name" : "Their name", text: text)
                    .font(.system(size: 20, weight: .semibold))
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
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .card()
    }
}
