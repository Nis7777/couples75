import SwiftUI
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
                          Task { await buy(purchases.monthly) }
                      },
                      sevenDayTrial: {
                          showExit = false
                          Task { await buy(purchases.yearly7) }
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
            }
            .padding(.horizontal, 32)
            .padding(.top, 4)
            if let rating = SocialProof.appStoreRating, let count = SocialProof.appStoreRatingCount {
                // Real App Store rating only (see SocialProof).
                Text("\(rating.formatted(.number.precision(.fractionLength(1)))) on the App Store · \(count) ratings")
                    .font(.app(15, .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            Text(SocialProof.line)
                .font(.app(16, .medium))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            TrophyScene(left: model.sceneA, right: model.sceneBBuilt)
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
                    if purchases.yearly == nil && purchases.monthly == nil {
                        loadingState
                    } else {
                        planCard(yearly: true)
                        planCard(yearly: false)
                        VStack(spacing: 4) {
                            if let weekly = purchases.weeklyPrice {
                                Text("\(weekly)/week, less than one date night.")
                                    .font(.app(16, .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Text("One subscription covers you both.")
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
                    Task { await buy(selectedProduct) }
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

    /// 13c plan card. Yearly: peach with a gold "BEST VALUE · x/week" pill. Monthly: white.
    private func planCard(yearly: Bool) -> some View {
        let selected = yearlySelected == yearly
        let trial = purchases.trialDays(purchases.yearly)
        let yearlyLine: String = {
            let price = purchases.yearlyPrice ?? "…"
            if let trial { return "\(price)/year after \(trial) free days" }
            return "\(price)/year"
        }()
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { yearlySelected = yearly }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(yearly ? "Yearly" : "Monthly")
                    .font(.app(26, .bold))
                    .foregroundStyle(Color.textPrimary)
                if yearly {
                    if let weekly = purchases.weeklyPrice {
                        Pill(text: "BEST VALUE · \(weekly)/week", fill: .gold, size: 15)
                            .frame(maxWidth: .infinity)
                    }
                    Text(yearlyLine)
                        .font(.app(17, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("\(purchases.monthlyPrice ?? "…")/month")
                        .font(.app(20, .bold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(selected ? Color.peach.opacity(0.75) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 4))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .stroke(selected ? Color.coral.opacity(0.8) : Color.cardBorder, lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var selectedProduct: Product? { yearlySelected ? purchases.yearly : purchases.monthly }

    private var primaryTitle: String {
        if yearlySelected && hasTrial { return "Start my free trial" }
        return "Subscribe"
    }

    private func buy(_ product: Product?) async {
        if isOnboarding && model.hasActiveSubscription {
            onPurchased()
            return
        }
        guard let product else { return }
        working = true
        defer { working = false }
        do {
            if try await purchases.purchase(product, memberID: model.meID) {
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
struct PaywallAView: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void
    var onDone: () -> Void
    @State private var confirming = false

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
        }
    }

    private func afterPurchase() async {
        withAnimation { confirming = true }
        let started = Date()
        var ok = true
        if model.me == nil {
            ok = await model.createCouple()
        }
        let remaining = 1.4 - Date().timeIntervalSince(started)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        if ok {
            onDone()
        } else {
            withAnimation { confirming = false }
        }
    }
}
