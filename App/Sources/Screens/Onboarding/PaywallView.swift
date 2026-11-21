import SwiftUI
import StoreKit

/// 13c paywall. Variants: A during onboarding, B while joining, and "Renew to keep your run".
/// Prices always come from StoreKit.
struct PaywallView: View {
    enum Variant: Equatable {
        case personA(partner: String)
        case personB(inviter: String)
        case renew
    }

    @Environment(AppModel.self) private var model
    var variant: Variant
    /// × tapped (A: opens the exit sheet first). nil hides the ×.
    var onClose: (() -> Void)?
    var onPurchased: () -> Void

    @State private var yearlySelected = false
    @State private var showExit = false
    @State private var working = false

    private var purchases: PurchaseManager { model.purchases }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if onClose != nil {
                    CloseButton {
                        if case .personA = variant { showExit = true } else { onClose?() }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(height: 52)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    if purchases.monthly == nil && purchases.yearly == nil {
                        loadingState
                    } else {
                        planCard(yearly: false)
                        planCard(yearly: true)
                    }
                    if case .personA(let partner) = variant {
                        StepsStrip(partner: partner)
                            .padding(.top, 4)
                    }
                    Text("Cancel anytime.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            BottomActions {
                PrimaryButton(primaryTitle, isEnabled: selectedProduct != nil || model.hasActiveSubscription,
                              isLoading: working || purchases.isPurchasing) {
                    Task { await buy(selectedProduct) }
                }
                FooterLinks()
            }
        }
        .screenBackground()
        .sheet(isPresented: $showExit) {
            ExitSheet(monthlyPrice: purchases.monthlyPrice ?? "",
                      startMonthly: {
                          showExit = false
                          Task { await buy(purchases.monthly) }
                      },
                      backToPlans: { showExit = false },
                      reviewPlan: {
                          showExit = false
                          onClose?()
                      })
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
        .task {
            if purchases.monthly == nil { await purchases.loadProducts() }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var header: some View {
        let monthly = purchases.monthlyPrice ?? "…"
        switch variant {
        case .personA(let partner):
            headerText(title: "\(monthly) a month each",
                       subtitle: "You subscribe now, then invite \(partner). \(partner) joins with their own subscription.")
        case .personB(let inviter):
            headerText(title: "Join \(inviter): \(monthly) a month",
                       subtitle: "\(inviter) already subscribed. Subscribe to start Day 1 together.")
        case .renew:
            VStack(spacing: 8) {
                TitleText("Renew to keep your run", size: 26)
                headerText(title: nil,
                           subtitle: "Your subscription ended, so your run is paused. Renew within \(Brand.lapseGraceDays) days or the round ends with no bet.")
            }
        }
    }

    private func headerText(title: String?, subtitle: String) -> some View {
        VStack(spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            if purchases.productsFailed {
                Text("Couldn't load prices from the App Store.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                SecondaryButton("Try again") { Task { await purchases.loadProducts() } }
            } else {
                ProgressView().tint(.coral)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func planCard(yearly: Bool) -> some View {
        let selected = yearlySelected == yearly
        let price = (yearly ? purchases.yearlyPrice : purchases.monthlyPrice) ?? "…"
        return OptionCard(title: yearly ? "Yearly" : "Monthly",
                          subtitle: yearly ? "\(price)/year per person" : "\(price)/month per person",
                          isSelected: selected) {
            yearlySelected = yearly
        } trailing: {
            if yearly, let eq = purchases.yearlyMonthlyEquivalent {
                Pill(text: "BEST VALUE · \(eq)/month", fill: .gold)
            }
        }
    }

    private var selectedProduct: Product? { yearlySelected ? purchases.yearly : purchases.monthly }

    private var primaryTitle: String {
        switch variant {
        case .personA: return "Start our challenge"
        case .personB(let inviter): return "Join \(inviter)"
        case .renew: return "Renew"
        }
    }

    private func buy(_ product: Product?) async {
        if model.hasActiveSubscription && variant != .renew {
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

/// "1. You subscribe" → "2. Invite {B}" → "3. {B} subscribes and Day 1 starts".
struct StepsStrip: View {
    var partner: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            item(1, "You subscribe")
            arrow
            item(2, "Invite \(partner)")
            arrow
            item(3, "\(partner) subscribes and Day 1 starts")
        }
        .padding(12)
        .card(fill: .white, radius: 16)
        .accessibilityElement(children: .combine)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.gold)
            .padding(.top, 6)
    }

    private func item(_ n: Int, _ text: String) -> some View {
        VStack(spacing: 4) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.coral))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
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
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.textSecondary)
        .tint(Color.textSecondary)
    }
}

/// 13d exit sheet.
struct ExitSheet: View {
    var monthlyPrice: String
    var startMonthly: () -> Void
    var backToPlans: () -> Void
    var reviewPlan: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            TitleText("Not ready to start?", size: 24)
                .padding(.top, 28)
            BodyText("It's \(monthlyPrice) a month each. Cancel anytime.")
            Spacer(minLength: 0)
            PrimaryButton("Start monthly") { startMonthly() }
            SecondaryButton("Back to plans") { backToPlans() }
            TextLinkButton("Review the plan again") { reviewPlan() }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .screenBackground()
    }
}

/// A's paywall step: purchase → "You're in. Now invite {B}." → create the couple → invite.
struct PaywallAView: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void
    var onDone: () -> Void
    @State private var confirming = false

    var body: some View {
        ZStack {
            PaywallView(variant: .personA(partner: model.draft.partnerName), onClose: onClose) {
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
