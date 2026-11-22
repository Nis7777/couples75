import SwiftUI
import UIKit
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
    @State private var showRules = false
    @State private var eveningOn = Prefs.eveningWarningOn
    @State private var notificationsDenied = false

    private var round: RoundState? { model.currentRound }
    private var partnerLinked: Bool { model.partner?.joinedAt != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Text("Profile")
                    .font(.app(34, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                    .accessibilityAddTraits(.isHeader)

                if let me = model.me {
                    ZStack(alignment: .bottom) {
                        Ellipse()
                            .fill(Color.peach.opacity(0.8))
                            .frame(width: 230, height: 230)
                            .offset(y: -10)
                        CharacterView(avatar: me.avatar, pose: .stand)
                            .frame(height: 440)
                            .frame(height: 250, alignment: .top)
                            .clipped()
                    }
                    .frame(height: 250)
                    .accessibilityHidden(true)
                    Text(me.name)
                        .font(.app(40, .bold))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.top, 2)
                }
                Text(partnerLinked ? "Partner linked" : "Waiting for \(model.partnerName)")
                    .font(.app(17, .medium))
                    .foregroundStyle(partnerLinked ? Color.white : Color.coral)
                    .padding(.horizontal, 22)
                    .frame(height: 38)
                    .background(Capsule().fill(partnerLinked ? Color.sage : Color.peach))
                    .fixedSize()
                    .padding(.bottom, 6)

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
                            .font(.app(17, .medium))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .tint(.coral)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 58)
                    .card(radius: 16, shadow: false)
                    .onChange(of: eveningOn) { _, on in Task { await model.setEveningWarning(on) } }
                    if notificationsDenied {
                        // The user said no to the iOS prompt: offer a way back in Settings.
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } label: {
                            row("Reminders are off", value: "Turn on in Settings", chevron: true)
                        }
                    }
                    row("Partner", value: model.partnerName)
                    Button { showRules = true } label: {
                        row("Our rules", value: model.myPendingProposals.isEmpty ? nil : "Pending", chevron: true)
                    }
                }

                section {
                    Button { showManage = true } label: {
                        row("Subscription", value: subscriptionText, chevron: true)
                    }
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
                        Text("About").font(.app(17, .medium)).foregroundStyle(Color.textPrimary)
                        Text(Brand.disclaimer).font(.app(13)).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .card(radius: 16, shadow: false)
                    #if DEBUG
                    Button { showDebug = true } label: { row("Debug menu", chevron: true) }
                    #endif
                }

                VStack(spacing: 0) {
                    TextLinkButton("Leave couple", color: .textSecondary) { showLeave = true }
                    TextLinkButton("Delete my data", color: .textSecondary) { confirmDelete = true }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .task { notificationsDenied = await NotificationManager.shared.authorizationStatus() == .denied }
        .sheet(isPresented: $showWake) { WakeReminderSheet().presentationDetents([.medium]) }
        .sheet(isPresented: $showLeave) { LeaveCoupleSheet() }
        .sheet(isPresented: $showRules) { OurRulesSheet() }
        .sheet(isPresented: $showDebug) { DebugMenuView() }
        .confirmationDialog("Delete my data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete my data", role: .destructive) { Task { await model.deleteMyData() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You leave the couple, the run ends, shared photos are deleted for both of you, and everything on this phone is cleared. Your subscription stays active until you cancel it.")
        }
    }

    /// One subscription covers both partners.
    private var subscriptionText: String {
        if let ent = model.purchases.entitlement {
            let date = ent.expirationDate.formatted(date: .abbreviated, time: .omitted)
            let plan = ent.isTrial ? "\(ent.planName) (free trial)" : ent.planName
            return "Active · \(plan), \(ent.willAutoRenew ? "renews" : "ends") \(date) · covers you both"
        }
        if model.coupleActive { return "Covered by \(model.payerName)'s subscription" }
        return "Not active"
    }

    /// Settings rows as separate white cards.
    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
    }

    private func row(_ title: String, value: String? = nil, chevron: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.app(17, .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 58)
        .card(radius: 16, shadow: false)
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
