import Foundation
import StoreKit

/// The member's own current subscription.
struct Entitlement: Equatable {
    var productID: String
    var purchaseDate: Date
    var expirationDate: Date
    var willAutoRenew: Bool
    /// In the free-trial period right now.
    var isTrial: Bool = false

    var isYearly: Bool { productID != Brand.iapMonthly }
    var planName: String { isYearly ? "Yearly" : "Monthly" }
}

/// StoreKit 2. ONE subscription covers both partners; only the person who sets up the couple pays.
/// Prices always come from StoreKit, never hard-coded.
@MainActor
@Observable
final class PurchaseManager {
    private(set) var yearly: Product?
    private(set) var yearly7: Product?
    private(set) var monthly: Product?
    /// The one-time exit offer (40% off yearly).
    private(set) var yearlyOffer: Product?
    private(set) var entitlement: Entitlement?
    private(set) var isLoadingProducts = false
    private(set) var productsFailed = false
    private(set) var isPurchasing = false
    /// Whether this Apple ID can still get the free trial (one introductory offer per subscription group).
    private(set) var trialEligible = true

    @ObservationIgnored var onEntitlementChange: ((Entitlement?) -> Void)?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    var yearlyPrice: String? { yearly?.displayPrice }
    var monthlyPrice: String? { monthly?.displayPrice }

    /// Yearly price ÷ 52, localized ("$0.77").
    /// The yearly price as a per-month price ("$3.33"), for "$3.33/mo, billed $39.99 yearly".
    var yearlyPerMonth: String? {
        guard let y = yearly else { return nil }
        return (y.price / 12).formatted(y.priceFormatStyle)
    }

    /// Price per person per month ("$6.50" for $12.99 a month, "$1.67" for $39.99 a year): one subscription covers 2.
    func perPersonPerMonth(_ product: Product?) -> String? {
        guard let p = product, let unit = p.subscription?.subscriptionPeriod.unit else { return nil }
        let value = p.subscription?.subscriptionPeriod.value ?? 1
        let months: Decimal
        switch unit {
        case .year: months = Decimal(12 * value)
        case .month: months = Decimal(value)
        case .week: months = Decimal(value) / 4
        default: months = Decimal(value) / 30
        }
        return (p.price / months / 2).formatted(p.priceFormatStyle)
    }

    /// How much cheaper yearly is than 12 months of monthly, in whole percent (58 for 39.99 vs 7.99).
    var yearlySavingsPercent: Int? {
        guard let y = yearly, let m = monthly, m.price > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: y.price / (m.price * 12)).doubleValue
        let pct = Int(((1 - ratio) * 100).rounded(.down))
        return pct > 0 ? pct : nil
    }

    var weeklyPrice: String? {
        guard let y = yearly else { return nil }
        return (y.price / 52).formatted(y.priceFormatStyle)
    }

    /// Free-trial length in days for a product (3 for yearly, 7 for yearly7), nil when none or not eligible.
    func trialDays(_ product: Product?) -> Int? {
        guard trialEligible, let offer = product?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else {
            return nil
        }
        let p = offer.period
        if p.unit == .day { return p.value }
        if p.unit == .week { return p.value * 7 }
        if p.unit == .month { return p.value * 30 }
        if p.unit == .year { return p.value * 365 }
        return nil
    }

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        productsFailed = false
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: Brand.allProducts)
            yearly = products.first { $0.id == Brand.iapYearly }
            yearly7 = products.first { $0.id == Brand.iapYearly7 }
            monthly = products.first { $0.id == Brand.iapMonthly }
            yearlyOffer = products.first { $0.id == Brand.iapYearlyOffer }
            productsFailed = yearly == nil && monthly == nil
            if let sub = yearly?.subscription {
                trialEligible = await sub.isEligibleForIntroOffer
            }
        } catch {
            productsFailed = true
        }
    }

    func refreshEntitlements() async {
        var best: Entitlement?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  t.productType == .autoRenewable,
                  t.revocationDate == nil,
                  let exp = t.expirationDate else { continue }
            let ent = Entitlement(productID: t.productID, purchaseDate: t.originalPurchaseDate,
                                  expirationDate: exp, willAutoRenew: true,
                                  isTrial: t.offerType == .introductory)
            if best == nil || exp > (best?.expirationDate ?? .distantPast) { best = ent }
        }
        if var b = best {
            let product: Product?
            switch b.productID {
            case Brand.iapMonthly: product = monthly
            case Brand.iapYearly7: product = yearly7
            case Brand.iapYearlyOffer: product = yearlyOffer
            default: product = yearly
            }
            if let status = try? await product?.subscription?.status.first,
               case .verified(let info) = status.renewalInfo {
                b.willAutoRenew = info.willAutoRenew
            }
            best = b
        }
        let changed = best != entitlement
        entitlement = best
        if changed { onEntitlementChange?(best) }
    }

    /// Buys `product` for this member. Returns true when the subscription is active.
    func purchase(_ product: Product, memberID: MemberID) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        let trial = trialDays(product)
        var options: Set<Product.PurchaseOption> = []
        if let token = UUID(uuidString: memberID) { options.insert(.appAccountToken(token)) }
        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            guard case .verified(let t) = verification else { return false }
            await t.finish()
            if let trial {
                // "Day 2: we remind you": a real local reminder the day before the trial ends.
                let end = t.purchaseDate.addingTimeInterval(TimeInterval(trial) * 86_400)
                NotificationManager.shared.scheduleTrialReminder(trialEnd: end)
            }
            trialEligible = false
            await refreshEntitlements()
            return entitlement != nil
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
