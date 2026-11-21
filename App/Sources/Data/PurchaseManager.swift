import Foundation
import StoreKit

/// The member's own current subscription.
struct Entitlement: Equatable {
    var productID: String
    var purchaseDate: Date
    var expirationDate: Date
    var willAutoRenew: Bool

    var isYearly: Bool { productID == Brand.iapYearly }
    var planName: String { isYearly ? "Yearly" : "Monthly" }
}

/// StoreKit 2, one subscription per person (section 2.6). Prices always come from StoreKit.
@MainActor
@Observable
final class PurchaseManager {
    private(set) var monthly: Product?
    private(set) var yearly: Product?
    private(set) var entitlement: Entitlement?
    private(set) var isLoadingProducts = false
    private(set) var productsFailed = false
    private(set) var isPurchasing = false

    @ObservationIgnored var onEntitlementChange: ((Entitlement?) -> Void)?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    var monthlyPrice: String? { monthly?.displayPrice }
    var yearlyPrice: String? { yearly?.displayPrice }

    /// Yearly price ÷ 12, localized.
    var yearlyMonthlyEquivalent: String? {
        guard let y = yearly else { return nil }
        return (y.price / 12).formatted(y.priceFormatStyle)
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
            let products = try await Product.products(for: [Brand.iapMonthly, Brand.iapYearly])
            monthly = products.first { $0.id == Brand.iapMonthly }
            yearly = products.first { $0.id == Brand.iapYearly }
            productsFailed = monthly == nil && yearly == nil
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
                                  expirationDate: exp, willAutoRenew: true)
            if best == nil || exp > best!.expirationDate { best = ent }
        }
        if var b = best, let product = b.isYearly ? yearly : monthly,
           let status = try? await product.subscription?.status.first {
            if case .verified(let info) = status.renewalInfo { b.willAutoRenew = info.willAutoRenew }
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
        var options: Set<Product.PurchaseOption> = []
        if let token = UUID(uuidString: memberID) { options.insert(.appAccountToken(token)) }
        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            guard case .verified(let t) = verification else { return false }
            await t.finish()
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
