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
/// (outcome → plans; × closes). ONE subscription covers both partners.
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

    enum Page: Hashable { case outcome, plans }

    @Environment(AppModel.self) private var model
    var variant: Variant
    /// Closing the paywall entirely (onboarding: back to the plan; take over: back to the app). nil hides the ×.
    var onClose: (() -> Void)?
    var onPurchased: () -> Void

    @State private var page: Page = .outcome
    /// Which plan is selected. `.offer` only exists once the paywall was closed once (see `showsOffer`).
    enum Choice { case monthly, yearly, offer }
    @State private var choice: Choice = .yearly
    private var yearlySelected: Bool { choice == .yearly }
    @State private var showAllPlans = false
    @State private var working = false
    /// The trial reminder is a local notification: only promise it when notifications are allowed.
    @State private var canRemind = false

    private var purchases: PurchaseManager { model.purchases }
    private var isOnboarding: Bool {
        if case .onboarding = variant { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if onClose != nil {
                    // × always just closes: nothing pops up (Guideline 5.6). In onboarding, the next visit to the
                    // paywall shows the welcome offer as one more plan card.
                    CloseButton {
                        if isOnboarding { Prefs.exitOfferShown = true }
                        onClose?()
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
        .sheet(isPresented: $showAllPlans) { AllPlansSheet() }
        .task {
            canRemind = await NotificationManager.shared.authorizationStatus() == .authorized
            if purchases.yearly == nil || purchases.yearlyOffer == nil { await purchases.loadProducts() }
            if showsOffer { choice = .offer }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach([Page.outcome, Page.plans], id: \.self) { p in
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
                valueRow("flame.fill", "Challenges with stakes you set, like The 75")
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
                PrimaryButton("Continue") { page = .plans }
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
                        if showsOffer { offerCard }
                        // Monthly first, then Yearly (preselected): the yearly saving reads against the monthly price.
                        planCard(yearly: false)
                        planCard(yearly: true)
                            .padding(.bottom, 10)
                        if yearlySelected, let days = purchases.trialDays(purchases.yearly) {
                            // The trial, in one line (no separate page): free now, a reminder the day before it ends.
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.sage)
                                    .padding(.top, 2)
                                Text(trialLine(days: days))
                                    .font(.app(14, .medium))
                                    .foregroundStyle(Color.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.sage.opacity(0.12)))
                            .transition(.opacity)
                        }
                        #if DEBUG
                        if purchases.trialUsedUp {
                            // Test builds only: why there's no free trial on this device.
                            Text("Test build: no free trial because this account already used one. In Xcode: Debug → StoreKit → Manage Transactions → delete them all, then run again.")
                                .font(.app(12, .semibold))
                                .foregroundStyle(Color.highlight)
                                .multilineTextAlignment(.center)
                        }
                        #endif
                        VStack(spacing: 4) {
                            Text("No second payment for \(partnerName.isEmpty ? "your partner" : partnerName).")
                                .font(.app(15))
                                .foregroundStyle(Color.textSecondary)
                            // The renewal terms on the plans page itself (Guideline 3.1.2), not only in "View all plans".
                            Text(renewalLine)
                                .font(.app(12))
                                .foregroundStyle(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
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
                    Task { await buy() }
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
            header(title: "Start leveling up together", subtitle: "Cancel anytime in Settings.")
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
        let selected = choice == (yearly ? .yearly : .monthly)
        let product = yearly ? purchases.yearly : purchases.monthly
        let price = (yearly ? purchases.yearlyPrice : purchases.monthlyPrice) ?? "…"
        let trial = yearly ? purchases.trialDays(purchases.yearly) : nil
        return Button {
            Haptics.tap()
            withAnimation(.open(0.25)) { choice = yearly ? .yearly : .monthly }
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

    private var selectedProduct: Product? {
        switch choice {
        case .monthly: return purchases.monthly
        case .yearly: return purchases.yearly
        case .offer: return purchases.yearlyOffer
        }
    }

    /// The welcome offer shows (as a plan card, never a pop-up) in onboarding once the paywall was closed once.
    private var showsOffer: Bool { isOnboarding && Prefs.exitOfferShown && purchases.yearlyOffer != nil }

    /// "38%": how much less than the regular yearly price.
    private var offerPercent: Int? {
        guard let o = purchases.yearlyOffer?.price, let y = purchases.yearly?.price, y > 0 else { return nil }
        let pct = Int(((1 - NSDecimalNumber(decimal: o / y).doubleValue) * 100).rounded())
        return pct > 0 ? pct : nil
    }

    /// The welcome offer: a normal plan card with honest terms (the same yearly plan for less, no free trial).
    private var offerCard: some View {
        let selected = choice == .offer
        let price = purchases.yearlyOffer?.displayPrice ?? "…"
        return VStack(alignment: .leading, spacing: 8) {
            Text("Still deciding? Here's the yearly plan for less.")
                .font(.app(14, .medium))
                .foregroundStyle(Color.textSecondary)
            Button {
                Haptics.tap()
                withAnimation(.open(0.25)) { choice = .offer }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome offer")
                            .font(.app(19, .semibold))
                            .foregroundStyle(Color.gold)
                        (Text("\(price) / year").font(.app(18, .bold)) + Text(" for 2 people").font(.app(17)))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let regular = purchases.yearlyPrice {
                            Text("Instead of \(regular) / year · no free trial")
                                .font(.app(14))
                                .foregroundStyle(Color.textSecondary)
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
                    if let pct = offerPercent {
                        Pill(text: "\(pct)% LESS", fill: .highlight, size: 14)
                            .offset(x: -18, y: 14)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }
        .padding(.bottom, 12)
    }

    /// "Free for 7 days, then $39.99/year." plus the reminder only when it can really be sent.
    private func trialLine(days: Int) -> String {
        let price = purchases.yearlyPrice.map { ", then \($0)/year" } ?? ""
        let base = "Free for \(days) days\(price). Cancel anytime before the trial ends and you won't be charged."
        return canRemind ? base + " We'll remind you 1 day before it ends." : base
    }

    /// "Auto-renews at $39.99/year until you cancel…" for the selected plan.
    private var renewalLine: String {
        let price = selectedProduct?.displayPrice ?? ""
        let period = choice == .monthly ? "month" : "year"
        let charge = yearlySelected && hasTrial ? "Charged to your Apple ID when the free trial ends." : "Charged to your Apple ID when you confirm."
        return "\(charge) Auto-renews at \(price)/\(period) until you cancel, at least 24 hours before the end of the period, in Settings → [your name] → Subscriptions."
    }


    private var primaryTitle: String {
        if yearlySelected && hasTrial { return "Start my free trial" }
        return "Subscribe"
    }

    private func buy() async {
        if isOnboarding && model.hasActiveSubscription {
            onPurchased()
            return
        }
        working = true
        defer { working = false }
        var item = selectedProduct
        if item == nil {
            // Prices hadn't loaded (bad connection): try once more, then say what's wrong.
            await purchases.loadProducts()
            item = selectedProduct
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
