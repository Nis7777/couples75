import SwiftUI
import UIKit
import StoreKit

/// Social proof shown on the outcome page. NEVER invent ratings, review counts, quotes or user numbers.
enum SocialProof {
    static let line = "Built for couples who want to finish what they start."

    // MARK: Real App Store ratings go here later
    // When the app has real ratings, set these from App Store Connect (e.g. 4.8 and 1200).
    // Leave them nil until then: nothing is shown.
    static let appStoreRating: Double? = nil
    static let appStoreRatingCount: Int? = nil
}

/// The paywall. Only the person who sets up the couple (A) sees it during onboarding: 4 pages after "Hold to sign"
/// (outcome → trial timeline → plans, and the exit sheet on ×). ONE subscription covers both partners.
/// The same plans page is used to renew (the payer) or to take over the subscription (the partner, only when the
/// payer's lapsed). Prices always come from StoreKit.
struct PaywallView: View {
    enum Variant: Equatable {
        /// A, during onboarding: outcome, trial, plans.
        case onboarding(partner: String)
        /// The payer's subscription lapsed.
        case renew
        /// The payer's subscription lapsed; the partner can take it over.
        case takeOver(payer: String)
    }

    enum Page: Hashable { case outcome, trial, plans }

    @Environment(AppModel.self) private var model
    var variant: Variant
    /// Closing the paywall entirely (onboarding: back to the plan; take over: back to the app). nil hides the ×.
    var onClose: (() -> Void)?
    var onPurchased: () -> Void

    @State private var page: Page = .outcome
    @State private var yearlySelected = true
    @State private var showExit = false
    @State private var showAllPlans = false
    @State private var working = false

    private var purchases: PurchaseManager { model.purchases }
    private var isOnboarding: Bool {
        if case .onboarding = variant { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if onClose != nil {
                    // In onboarding the × always opens the exit sheet; it never drops the user into the app.
                    CloseButton {
                        if isOnboarding { showExit = true } else { onClose?() }
                    }
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
                if isOnboarding { pageDots }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            Group {
                switch page {
                case .outcome: outcomePage
                case .trial: trialPage
                case .plans: plansPage
                }
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .animation(.easeInOut(duration: 0.3), value: page)
        .screenBackground()
        .onAppear { if !isOnboarding { page = .plans } }
        .sheet(isPresented: $showExit) {
            ExitSheet(monthlyPrice: purchases.monthlyPrice ?? "…",
                      tryMonthly: {
                          showExit = false
                          Task { await buy(.monthly) }
                      },
                      sevenDayTrial: {
                          showExit = false
                          Task { await buy(.yearly7) }
                      },
                      keepYearly: {
                          showExit = false
                          yearlySelected = true
                      },
                      backToPlan: {
                          showExit = false
                          onClose?()
                      })
                .presentationDetents([.height(430)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllPlans) { AllPlansSheet() }
        .task {
            if purchases.yearly == nil { await purchases.loadProducts() }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach([Page.outcome, Page.trial, Page.plans], id: \.self) { p in
                Capsule()
                    .fill(p == page ? Color.gold : Color.track)
                    .frame(width: p == page ? 22 : 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private var hasTrial: Bool { purchases.trialDays(purchases.yearly) != nil }

    // MARK: 1. Outcome (13a)

    private var outcomePage: some View {
        VStack(spacing: 10) {
            TitleText("Become the best version of you. Together.", size: 30)
                .padding(.horizontal, 28)
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                valueRow("checklist", "Daily habits for body, looks, mind and money")
                valueRow("flame.fill", "Challenges with real stakes, like The 75")
                valueRow("crown.fill", "One streak, one rank, both of you")
                valueRow("person.2.fill", partnerName.isEmpty ? "One subscription covers you both"
                                                                : "One subscription covers you both: \(partnerName) joins free")
            }
            .padding(.horizontal, 32)
            .padding(.top, 4)
            if let rating = SocialProof.appStoreRating, let count = SocialProof.appStoreRatingCount {
                // Real App Store rating only (see SocialProof).
                Text("\(rating.formatted(.number.precision(.fractionLength(1)))) on the App Store · \(count) ratings")
                    .font(.app(15, .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            // A closing line, not a fifth bullet: set apart from the list and in italic.
            Text(SocialProof.line)
                .font(.app(15, .medium))
                .italic()
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 14)
            // No "Day 75" badge: it covered the partner, and The 75 is one challenge, not the app.
            TrophyScene(left: model.sceneA, right: model.sceneBBuilt, badge: false)
                .frame(maxHeight: .infinity)
            BottomActions {
                PrimaryButton("Continue") { page = hasTrial ? .trial : .plans }
            }
        }
    }

    private func valueRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.coral)
                .frame(width: 22)
            Text(text).font(.app(16, .medium)).foregroundStyle(Color.textPrimary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 2. Trial timeline (13b)

    private var trialPage: some View {
        VStack(spacing: 0) {
            TitleText("How your free trial works", size: 30)
                .padding(.horizontal, 28)
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: 0) {
                timelineRow(day: "Today", text: "Full access for both of you", last: false)
                timelineRow(day: "Day 2", text: "We remind you", last: false)
                timelineRow(day: "Day 3", text: "Trial ends, billing starts", last: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(.horizontal, Metrics.side)
            .padding(.top, 28)
            Spacer(minLength: 12)
            Text("No commitment. Cancel anytime.")
                .font(.app(15, .medium))
                .foregroundStyle(Color.textSecondary)
            BottomActions {
                PrimaryButton("Continue") { page = .plans }
            }
        }
    }

    /// 13b: plain gold dots on a gold line; the last dot (trial ends) is coral.
    private func timelineRow(day: String, text: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 0) {
                Circle()
                    .fill(last ? Color.coral.opacity(0.8) : Color.gold)
                    .frame(width: 20, height: 20)
                    .padding(.top, 4)
                if !last {
                    Rectangle().fill(Color.gold).frame(width: 2.5).frame(minHeight: 64, maxHeight: 96)
                }
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(day).font(.app(21, .bold)).foregroundStyle(Color.textPrimary)
                Text(text).font(.app(17)).foregroundStyle(Color.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 3. Plans (13c)

    private var plansPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    plansHeader
                    if case .onboarding = variant { coversBoth }
                    if purchases.yearly == nil && purchases.monthly == nil {
                        loadingState
                    } else {
                        // Monthly first, then Yearly (preselected): the yearly saving reads against the monthly price.
                        planCard(yearly: false)
                        planCard(yearly: true)
                            .padding(.bottom, 10)
                        VStack(spacing: 4) {
                            Text("No second payment for \(partnerName.isEmpty ? "your partner" : partnerName).")
                                .font(.app(15))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, 16)
            }
            BottomActions {
                PrimaryButton(primaryTitle, isEnabled: selectedProduct != nil,
                              isLoading: working || purchases.isPurchasing) {
                    Task { await buy(.selected) }
                }
                if case .onboarding = variant {
                    // An invited partner who started here by mistake: join free with the code instead of paying.
                    Button("Already invited? Join with your partner's code") {
                        model.seenCodeEntry = false
                        model.draft = OnboardingDraft()
                    }
                    .font(.app(13, .semibold))
                    .foregroundStyle(Color.coral)
                }
                HStack(spacing: 6) {
                    Button("View all plans") { showAllPlans = true }
                    Text("·")
                    FooterLinks()
                }
                .font(.app(13, .medium))
                .foregroundStyle(Color.textSecondary)
                .tint(Color.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var plansHeader: some View {
        switch variant {
        case .onboarding:
            header(title: "Start leveling up together", subtitle: "No commitment. Cancel anytime.")
        case .renew:
            header(title: "Renew to keep your run",
                   subtitle: "Your subscription ended, so your run is paused. Renew within \(Brand.lapseGraceDays) days or a running challenge ends with no bet.")
        case .takeOver(let payer):
            header(title: "Keep your run going: take over the subscription",
                   subtitle: "\(payer)'s subscription ended, so your run is paused. Subscribe and it continues for you both.")
        }
    }

    private var partnerName: String {
        if case .onboarding(let p) = variant { return p }
        return model.partnerName
    }

    /// Plans page: both of you, one price. Hard to miss.
    private var coversBoth: some View {
        HStack(spacing: 12) {
            CoupleBusts(left: model.sceneA, right: model.sceneBBuilt)
                .frame(width: 96, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text("One subscription, both of you")
                    .font(.app(17, .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(partnerName.isEmpty ? "Your partner joins free with your invite."
                                         : "\(partnerName) joins free with your invite.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .peachBox(radius: 18)
        .accessibilityElement(children: .combine)
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            TitleText(title, size: 28)
            Text(subtitle)
                .font(.app(15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            if purchases.productsFailed {
                Text("Couldn't load prices from the App Store.")
                    .font(.app(15))
                    .foregroundStyle(Color.textSecondary)
                SecondaryButton("Try again") { Task { await purchases.loadProducts() } }
            } else {
                ProgressView().tint(.coral)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    /// Plan card: name (caramel), "$12.99 / month for 2 people", "$6.50 / person / month"; the selected one has an
    /// espresso border and a check; Yearly carries the "SAVE x%" pill on its bottom edge.
    private func planCard(yearly: Bool) -> some View {
        let selected = yearlySelected == yearly
        let product = yearly ? purchases.yearly : purchases.monthly
        let price = (yearly ? purchases.yearlyPrice : purchases.monthlyPrice) ?? "…"
        let trial = yearly ? purchases.trialDays(purchases.yearly) : nil
        return Button {
            Haptics.tap()
            withAnimation(.open(0.25)) { yearlySelected = yearly }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(yearly ? "Yearly" : "Monthly")
                        .font(.app(19, .semibold))
                        .foregroundStyle(Color.gold)
                    (Text("\(price) / \(yearly ? "year" : "month")").font(.app(18, .bold))
                        + Text(" for 2 people").font(.app(17)))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let per = purchases.perPersonPerMonth(product) {
                        Text("\(per) / person / month")
                            .font(.app(14))
                            .foregroundStyle(Color.textSecondary)
                    }
                    if let trial {
                        Text("\(trial)-day free trial first")
                            .font(.app(13, .semibold))
                            .foregroundStyle(Color.sage)
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(selected ? Color.coral : Color.clear)
                        .overlay(Circle().stroke(selected ? Color.coral : Color.radio, lineWidth: 1.5))
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(selected ? Color.peach.opacity(0.75) : Color.white))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .stroke(selected ? Color.coral.opacity(0.85) : Color.cardBorder, lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .bottomTrailing) {
                if yearly, let save = purchases.yearlySavingsPercent {
                    // Coral = something special (docs/BRAND.md).
                    Pill(text: "SAVE \(save)%", fill: .highlight, size: 14)
                        .offset(x: -18, y: 14)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var selectedProduct: Product? { yearlySelected ? purchases.yearly : purchases.monthly }

    /// Which plan a button buys: the selected one, or the exit sheet's monthly / 7-day trial.
    private enum Plan { case selected, monthly, yearly7 }

    private func product(for plan: Plan) -> Product? {
        switch plan {
        case .selected: return selectedProduct
        case .monthly: return purchases.monthly
        case .yearly7: return purchases.yearly7
        }
    }

    private var primaryTitle: String {
        if yearlySelected && hasTrial { return "Start my free trial" }
        return "Subscribe"
    }

    private func buy(_ plan: Plan) async {
        if isOnboarding && model.hasActiveSubscription {
            onPurchased()
            return
        }
        working = true
        defer { working = false }
        var item = product(for: plan)
        if item == nil {
            // Prices hadn't loaded (bad connection): try once more, then say what's wrong.
            await purchases.loadProducts()
            item = product(for: plan)
        }
        guard let item else {
            model.errorMessage = "Couldn't reach the App Store. Check your internet connection and try again."
            return
        }
        do {
            if try await purchases.purchase(item, memberID: model.meID) {
                Haptics.success()
                onPurchased()
            }
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

/// "Terms · Privacy · Restore".
struct FooterLinks: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            Link("Terms", destination: Brand.termsURL)
            Text("·")
            Link("Privacy", destination: Brand.privacyURL)
            Text("·")
            Button("Restore") {
                Task {
                    await model.purchases.restore()
                    model.toast = model.purchases.entitlement != nil ? "Purchases restored." : "No active subscription found."
                }
            }
        }
        .font(.app(13, .medium))
        .foregroundStyle(Color.textSecondary)
        .tint(Color.textSecondary)
    }
}

/// 13d exit sheet: "Not ready for a year?"
struct ExitSheet: View {
    var monthlyPrice: String
    var tryMonthly: () -> Void
    var sevenDayTrial: () -> Void
    var keepYearly: () -> Void
    var backToPlan: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TitleText("Not ready for a year?", size: 26)
                .padding(.top, 30)
                .padding(.bottom, 6)
            sheetButton("Try monthly \(monthlyPrice)", fill: .peach, border: .coral, action: tryMonthly)
            sheetButton("Get a 7-day free trial instead", fill: .white, border: .cardBorder, action: sevenDayTrial)
            Button(action: keepYearly) {
                Text("Keep yearly")
                    .font(.app(16, .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 26)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.cardBorder, lineWidth: 1))
            }
            .padding(.top, 4)
            TextLinkButton("Back to our plan") { backToPlan() }
        }
        .padding(.horizontal, Metrics.side)
        .padding(.bottom, 8)
        .screenBackground()
    }

    private func sheetButton(_ title: String, fill: Color, border: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.app(18, .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border, lineWidth: 1.2))
        }
        .buttonStyle(PressableStyle())
    }
}

/// "View all plans": both plans with their full terms.
struct AllPlansSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    plan(title: "Yearly", price: model.purchases.yearlyPrice, period: "year",
                         trial: model.purchases.trialDays(model.purchases.yearly))
                    plan(title: "Monthly", price: model.purchases.monthlyPrice, period: "month", trial: nil)
                    Text("One subscription covers you both: your partner joins free. Payment is charged to your Apple ID when you confirm, or when the free trial ends. It renews automatically unless you turn it off at least 24 hours before the end of the current period, in Settings → [your name] → Subscriptions. Cancel anytime.")
                        .font(.app(14))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    FooterLinks()
                }
                .padding(Metrics.side)
            }
            .screenBackground()
            .navigationTitle("All plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func plan(title: String, price: String?, period: String, trial: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.app(20, .bold)).foregroundStyle(Color.textPrimary)
            Text("\(price ?? "…") per \(period), auto-renewing, for both of you.")
                .font(.app(16)).foregroundStyle(Color.textPrimary)
            if let trial {
                Text("Starts with a \(trial)-day free trial. You won't be charged if you cancel before it ends.")
                    .font(.app(14)).foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 16)
    }
}

/// A's paywall: purchase → "You're in. Now invite {B}." → create the couple → invite.
/// If setting up the couple fails after paying (iCloud full, offline), it never goes back to the paywall:
/// it shows why, with Try again (the subscription is already active, so there's nothing to pay twice).
struct PaywallAView: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void
    var onDone: () -> Void
    @State private var confirming = false
    @State private var failed = false
    @State private var retrying = false

    var body: some View {
        ZStack {
            PaywallView(variant: .onboarding(partner: model.draft.partnerName), onClose: onClose) {
                Task { await afterPurchase() }
            }
            if confirming {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.sage)
                    TitleText("You're in. Now invite \(model.draft.partnerName).", size: 24)
                    ProgressView().tint(.coral)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ivory.ignoresSafeArea())
                .transition(.opacity)
            }
            if failed {
                setupFailed
                    .transition(.opacity)
            }
        }
    }

    /// Not signed in to iCloud: Settings is where to fix it.
    private var needsSettings: Bool {
        if case .notAuthenticated = model.lastSetupError { return true }
        return false
    }

    /// Paid, but the couple isn't in iCloud yet: why, and Try again.
    private var setupFailed: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(Color.coral)
            TitleText("Your pact isn't set up yet", size: 26)
            BodyText(model.setupErrorText)
            Text("Your subscription is active. You won't be charged again.")
                .font(.app(14, .semibold))
                .foregroundStyle(Color.sage)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            PrimaryButton("Try again", isLoading: retrying) { Task { await retry() } }
            if needsSettings {
                SecondaryButton("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
        }
        .padding(.horizontal, Metrics.side)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ivory.ignoresSafeArea())
    }

    private func afterPurchase() async {
        withAnimation { confirming = true }
        let started = Date()
        // Also when a previous attempt stopped half-way (the couple exists but has no invite yet).
        let ok = model.me == nil || model.invite == nil ? await model.createCouple() : true
        let remaining = 1.4 - Date().timeIntervalSince(started)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        if ok {
            onDone()
        } else {
            withAnimation {
                confirming = false
                failed = true
            }
        }
    }

    private func retry() async {
        retrying = true
        let ok = await model.createCouple()
        retrying = false
        if ok {
            failed = false
            onDone()
        } else {
            Haptics.warning()
        }
    }
}
