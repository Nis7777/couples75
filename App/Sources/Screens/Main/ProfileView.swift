import SwiftUI
import StoreKit

/// 18: Profile.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showManage = false
    @State private var showWake = false
    @State private var showLeave = false
    @State private var confirmDelete = false
    @State private var showDebug = false
    @State private var eveningOn = Prefs.eveningWarningOn

    private var round: RoundState? { model.currentRound }
    private var partnerLinked: Bool { model.partner?.joinedAt != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Text("Profile")
                    .font(.rounded(30))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                if let me = model.me {
                    CharacterImage(characterID: me.characterID, pose: .stand)
                        .frame(height: 220)
                        .accessibilityHidden(true)
                    Text(me.name)
                        .font(.rounded(26))
                        .foregroundStyle(Color.textPrimary)
                }
                Pill(text: partnerLinked ? "Partner linked" : "Waiting for \(model.partnerName)",
                     fill: partnerLinked ? .sage : .peach, foreground: partnerLinked ? .white : .coral)

                section {
                    row("Mode", value: (round?.mode ?? model.currentMode) == .hard
                        ? "Hard mode" : "Couples 75 · \(Brand.savesPerRound) saves")
                    if (round?.mode ?? model.currentMode) != .hard {
                        row("Saves left", value: "\(round?.savesLeft ?? Brand.savesPerRound) of \(Brand.savesPerRound)")
                    }
                    Button { showWake = true } label: {
                        row("Wake-up reminder", value: ClockTime.display(model.me?.wakeTime ?? "07:30"), chevron: true)
                    }
                    Toggle(isOn: $eveningOn) {
                        Text("Evening warning (\(Brand.eveningWarning))")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .tint(.coral)
                    .padding(.vertical, 4)
                    .onChange(of: eveningOn) { _, on in Task { await model.setEveningWarning(on) } }
                    row("Partner", value: model.partnerName)
                }

                section {
                    Button { showManage = true } label: {
                        row("Subscription", value: subscriptionText, chevron: true)
                    }
                    row("Partner's subscription", value: partnerSubscriptionText)
                    Button {
                        Task {
                            await model.purchases.restore()
                            model.toast = model.purchases.entitlement != nil ? "Purchases restored." : "No active subscription found."
                        }
                    } label: { row("Restore purchases", chevron: true) }
                }

                section {
                    Button { openURL(Brand.termsURL) } label: { row("Terms", chevron: true) }
                    Button { openURL(Brand.privacyURL) } label: { row("Privacy", chevron: true) }
                    Button { contactSupport() } label: { row("Contact support", chevron: true) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About").font(.system(size: 16)).foregroundStyle(Color.textPrimary)
                        Text(Brand.disclaimer).font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    if AppEnvironment.isDebug {
                        Button { showDebug = true } label: { row("Debug menu", chevron: true) }
                    }
                }

                VStack(spacing: 4) {
                    TextLinkButton("Leave couple", color: .red) { showLeave = true }
                    TextLinkButton("Delete my data", color: .red) { confirmDelete = true }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .sheet(isPresented: $showWake) { WakeReminderSheet().presentationDetents([.medium]) }
        .sheet(isPresented: $showLeave) { LeaveCoupleSheet() }
        .sheet(isPresented: $showDebug) { DebugMenuView() }
        .confirmationDialog("Delete my data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete my data", role: .destructive) { Task { await model.deleteMyData() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You leave the couple, the run ends, shared photos are deleted for both of you, and everything on this phone is cleared. Your subscription stays active until you cancel it.")
        }
    }

    private var subscriptionText: String {
        guard let ent = model.purchases.entitlement else { return "Not active" }
        let date = ent.expirationDate.formatted(date: .abbreviated, time: .omitted)
        return "Active · \(ent.planName), \(ent.willAutoRenew ? "renews" : "ends") \(date)"
    }

    private var partnerSubscriptionText: String {
        guard let p = model.partner, p.joinedAt != nil else { return "Not joined yet" }
        return p.isSubscribed(at: model.now()) ? "Active" : "Ended"
    }

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .card()
    }

    private func row(_ title: String, value: String? = nil, chevron: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func contactSupport() {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = Brand.supportEmail
        c.queryItems = [URLQueryItem(name: "subject", value: "\(Brand.appName) support")]
        if let url = c.url { openURL(url) }
    }
}

struct WakeReminderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var time = "07:30"

    var body: some View {
        NavigationStack {
            DatePicker("Wake-up time",
                       selection: Binding(get: { ClockTime.date(from: time) }, set: { time = ClockTime.string(from: $0) }),
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("Wake-up reminder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await model.setWakeTime(time)
                                dismiss()
                            }
                        }
                    }
                }
        }
        .onAppear { time = model.me?.wakeTime ?? "07:30" }
    }
}
