import SwiftUI

/// "Know when your partner checks in": three toggles, all on. Continue saves them (Prefs, also in Profile) and asks
/// iOS for permission only if at least one is on. This replaces the old ask after the invite, so nobody is asked twice.
struct NotificationSetupView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        NotificationChoices(partnerName: model.draft.partnerName,
                            wakeTime: Binding(get: { model.draft.wakeTime }, set: { model.draft.wakeTime = $0 }),
                            step: model.draft.stepNumber, back: back, next: next)
    }
}

/// The partner joining: the same three switches. Their reminder time is their wake-up time.
struct JoinNotificationStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    var body: some View {
        NotificationChoices(partnerName: model.nameA,
                            wakeTime: Binding(get: { model.me?.wakeTime ?? model.joinDraft?.wakeTime ?? "07:30" },
                                              set: { t in Task { await model.setWakeTime(t) } }),
                            step: nil, back: nil, next: next)
    }
}

/// "Know when your partner checks in": the three switches and Continue (asks iOS only if one is on).
struct NotificationChoices: View {
    @Environment(AppModel.self) private var model
    var partnerName: String
    @Binding var wakeTime: String
    var step: Int?
    var back: (() -> Void)?
    var next: () -> Void
    @State private var partner = Prefs.partnerCheckInNotifsOn
    @State private var daily = Prefs.dailyReminderOn
    @State private var recap = Prefs.weeklyRecapOn
    @State private var working = false

    var body: some View {
        OnboardingPage(step: step, back: back) {
            VStack(spacing: 14) {
                IconBadge(systemName: "bell.badge.fill", color: .coral, size: 110)
                    .padding(.top, 18)
                TitleText("Which notifications do you want?", size: 30)
                Text("Turn off anything you don't want. You can change these any time in Profile.")
                    .font(.app(15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                VStack(spacing: 10) {
                    toggle("When \(partnerLabel(partnerName)) checks in",
                           "A ping each time \(partnerLabel(partnerName)) finishes a habit, so you can cheer them on",
                           icon: "person.2.fill", isOn: $partner)
                    VStack(spacing: 0) {
                        toggle("Morning reminder", "Today's habits, at the time below", icon: "sun.max.fill",
                               isOn: $daily, carded: false)
                        if daily {
                            HStack {
                                Text("Remind me at")
                                    .font(.app(15, .medium))
                                    .foregroundStyle(Color.textSecondary)
                                Spacer()
                                DatePicker("Daily reminder time",
                                           selection: Binding(get: { ClockTime.date(from: wakeTime) },
                                                              set: { wakeTime = ClockTime.string(from: $0) }),
                                           displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(.coral)
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                            .transition(.opacity)
                        }
                    }
                    .card(radius: 18, shadow: false)
                    toggle("Weekly recap", "Every Monday: how your week went, together", icon: "calendar", isOn: $recap)
                }
                .animation(.open(0.25), value: daily)
                Spacer(minLength: 0)
            }
        } actions: {
            if partner || daily || recap {
                Text("Next, your iPhone asks whether \(Brand.appName) can send you notifications.")
                    .font(.app(13))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            PrimaryButton("Continue", isLoading: working) {
                Task {
                    working = true
                    Prefs.partnerCheckInNotifsOn = partner
                    Prefs.dailyReminderOn = daily
                    Prefs.weeklyRecapOn = recap
                    if partner || daily || recap {
                        _ = await NotificationManager.shared.requestPermission()
                        // Schedules right away when there's already a couple (the partner joining).
                        await NotificationManager.shared.reschedule(model: model)
                    }
                    working = false
                    next()
                }
            }
        }
    }

    private func partnerLabel(_ name: String) -> String { name.isEmpty ? "your partner" : name }

    private func toggle(_ title: String, _ detail: String, icon: String, isOn: Binding<Bool>,
                        carded: Bool = true) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.coral)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.peach))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.app(16, .semibold)).foregroundStyle(Color.textPrimary)
                    Text(detail).font(.app(13)).foregroundStyle(Color.textSecondary)
                }
            }
        }
        .tint(.coral)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(carded ? AnyView(Color.clear.card(radius: 18, shadow: false)) : AnyView(Color.clear))
        .onChange(of: isOn.wrappedValue) { _, _ in Haptics.tap() }
    }
}
