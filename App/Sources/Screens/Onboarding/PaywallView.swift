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
                        // Onboarding: the one-time offer the first time, then back to the plan. (Test builds: every
                        // time, so it can be checked.)
                        if isOnboarding && (!Prefs.exitOfferShown || AppEnvironment.isDebug) {
                            Prefs.exitOfferShown = true
                            showExit = true
                        } else {
                            onClose?()
                        }
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
        .fullScreenCover(isPresented: $showExit) {
            ExitOfferView(claim: {
                await buy(.offer)
                // Paid: close the offer so "You're in" (or Try again) shows.
                if model.hasActiveSubscription { showExit = false }
            }, close: {
                showExit = false
                onClose?()
            })
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
                let days = purchases.trialDays(purchases.yearly) ?? 7
                timelineRow(day: "Today", text: "Full access for both of you", last: false)
                timelineRow(day: "Day \(max(2, days - 1))", text: "We remind you", last: false)
                timelineRow(day: "Day \(days)", text: "Trial ends, billing starts", last: true)
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

    /// Which plan a button buys: the selected one, or the exit offer's discount / 7-day free trial.
    private enum Plan { case selected, offer }

    private func product(for plan: Plan) -> Product? {
        switch plan {
        case .selected: return selectedProduct
        case .offer: return purchases.yearlyOffer
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

/// 13d, × on the paywall (once per install): the one-time offer. 38% off yearly ($24.99 instead of $39.99, about $1
/// per person a month, no trial), on sun rays behind the two of you cheering. Prices are the real App Store ones
/// (the struck-through price is the regular yearly plan). × closes it for good.
struct ExitOfferView: View {
    @Environment(AppModel.self) private var model
    var claim: () async -> Void
    var close: () -> Void
    @State private var appeared = false
    @State private var claiming = false
    @State private var visible = false

    private var purchases: PurchaseManager { model.purchases }
    private var offer: Product? { purchases.yearlyOffer }
    private var offerPrice: String { offer?.displayPrice ?? "" }
    private var regularPrice: String { purchases.yearly?.displayPrice ?? "" }
    /// The offer's free trial (7 days), if this Apple ID can still get one.
    private var trialDays: Int? { purchases.trialDays(offer) }

    /// "38%", from the real prices.
    private var percentOff: String {
        guard let o = offer?.price, let y = purchases.yearly?.price, y > 0 else { return "38%" }
        let ratio = NSDecimalNumber(decimal: o / y).doubleValue
        return "\(Int(((1 - ratio) * 100).rounded()))%"
    }

    var body: some View {
        ZStack {
            rays
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.peachDeep.opacity(0.8)))
                    }
                    .accessibilityLabel("No thanks")
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        CoupleScene(left: model.draftScene, right: model.sceneBBuilt, leftPose: .cheer, rightPose: .cheer,
                                    crop: 0.55, alive: true)
                            .frame(height: 200)
                            .scaleEffect(appeared ? 1 : 0.9)
                            .opacity(appeared ? 1 : 0)
                            .accessibilityHidden(true)
                        Text("\(percentOff) off \(Brand.appName)")
                            .font(.app(38, .heavy))
                            .foregroundStyle(Color.highlight)
                            .multilineTextAlignment(.center)
                            .scaleEffect(appeared ? 1 : 0.8)
                            .accessibilityAddTraits(.isHeader)
                        Text("This offer is only shown once.")
                            .font(.app(16, .medium))
                            .foregroundStyle(Color.textSecondary)
                        priceCard
                            .padding(.top, 6)
                        Text(trialDays.map { "Free for \($0) days, then \(offerPrice)/year. Cancel before day \($0) and you pay nothing." }
                             ?? "Billed \(offerPrice) today, then \(offerPrice)/year.")
                            .font(.app(14))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.horizontal, Metrics.side)
                    .padding(.bottom, 12)
                }

                VStack(spacing: 8) {
                    claimButton
                    Text(trialDays.map { "\($0) days free, then \(offerPrice)/year" } ?? "\(offerPrice)/year")
                        .font(.app(17, .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Auto-renews. Cancel anytime in Settings. One subscription covers you both.")
                        .font(.app(12))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    links
                        .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, 10)
            }
        }
        .background(Color.ivory.ignoresSafeArea())
        .tracksVisibility($visible)
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appeared = true }
        }
        .task { if purchases.yearlyOffer == nil { await purchases.loadProducts() } }
    }

    /// Sun rays turning slowly behind everything (paused off screen; still with Reduce Motion).
    private var rays: some View {
        LoopClock(period: 90_000, paused: !visible) { t in
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.26)
                let r = max(size.width, size.height) * 1.2
                let count = 18
                let turn = t / 90_000 * 2 * .pi
                for i in 0..<count {
                    let a0 = turn + Double(i) * 2 * .pi / Double(count)
                    let a1 = a0 + .pi / Double(count)
                    var p = Path()
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + cos(a0) * r, y: c.y + sin(a0) * r))
                    p.addLine(to: CGPoint(x: c.x + cos(a1) * r, y: c.y + sin(a1) * r))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(Color.peach.opacity(0.9)))
                }
            }
        }
        .overlay(RadialGradient(colors: [Color.ivory.opacity(0), Color.ivory.opacity(0.85)],
                                center: UnitPoint(x: 0.5, y: 0.26), startRadius: 120, endRadius: 520))
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var priceCard: some View {
        VStack(spacing: 6) {
            if !regularPrice.isEmpty {
                Text("\(regularPrice)/year")
                    .font(.app(18, .medium))
                    .strikethrough(true, color: Color.textSecondary)
                    .foregroundStyle(Color.textSecondary)
            }
            Text("\(offerPrice)/year")
                .font(.app(42, .heavy))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(trialDays.map { "\(Brand.appName) · Yearly · \($0) days free first" } ?? "\(Brand.appName) · Yearly for both of you")
                .font(.app(15, .semibold))
                .foregroundStyle(Color.textSecondary)
            if let each = purchases.perPersonPerMonth(offer) {
                Text("That's \(each) per person a month")
                    .font(.app(13, .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Color.sage))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.highlight.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [7, 6])))
        .accessibilityElement(children: .combine)
    }

    /// A chunky button with a darker bottom edge that presses down.
    private var claimButton: some View {
        Button {
            guard !claiming else { return }
            Haptics.tap()
            Task {
                claiming = true
                await claim()
                claiming = false
            }
        } label: {
            ZStack {
                if claiming {
                    ProgressView().tint(.white)
                } else {
                    Text(trialDays.map { "Start my \($0)-day free trial" } ?? "Claim my discount")
                        .font(.app(20, .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(ChunkyButtonStyle(color: Color.highlight, edge: Color(hex: 0xB9532F)))
        .disabled(offer == nil)
    }

    private var links: some View {
        HStack(spacing: 18) {
            Button("Restore Purchases") {
                Task {
                    await purchases.restore()
                    model.toast = purchases.entitlement != nil ? "Purchases restored." : "No active subscription found."
                }
            }
            Link("Terms of Use", destination: Brand.termsURL)
            Link("Privacy Policy", destination: Brand.privacyURL)
        }
        .font(.app(13, .semibold))
        .foregroundStyle(Color.highlight)
        .tint(Color.highlight)
    }
}

/// A raised capsule: the face sits on a darker edge and moves down onto it when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color
    var edge: Color

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .background(Capsule().fill(color))
            .offset(y: pressed ? 4 : 0)
            .background(Capsule().fill(edge).offset(y: 4))
            .animation(.easeOut(duration: 0.08), value: pressed)
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
