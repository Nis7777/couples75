import Foundation

/// Every product-level constant lives here. Use these everywhere instead of literals.
enum Brand {
    /// The app's name everywhere users see it (plus CFBundleDisplayName in Config and the Watch, see README).
    static let appName = "Pact"
    static let tagline = "Level up as a couple."
    /// One line on what the app is, for the paywall, share cards and the App Store.
    static let pitch = "Daily habits and challenges you do together. Body, looks, mind and money."
    static let bundleID = "com.tomasbeja.pact"
    static let appGroup = "group.com.tomasbeja.pact"
    static let urlScheme = "pactapp"
    static let supportEmail = "pactapp.support@gmail.com"
    /// Hosted with GitHub Pages from `docs/` (repo Nis7777/pact). See docs/APPLE_SETUP.md, step 0.
    static let websiteURL = URL(string: "https://nis7777.github.io/pact/")!
    static let termsURL = URL(string: "https://nis7777.github.io/pact/terms.html")!
    static let privacyURL = URL(string: "https://nis7777.github.io/pact/privacy.html")!
    static let supportURL = URL(string: "https://nis7777.github.io/pact/support.html")!
    static let cloudKitContainer = "iCloud.com.tomasbeja.pact"
    /// A check-in must reach iCloud within this many hours of being taken.
    static let checkInUploadWindowHours: Double = 6
    /// One subscription covers both partners. Prices always come from StoreKit.
    static let iapYearly = "com.tomasbeja.pact.yearly"      // 39,99 € / $39.99 a year, 3-day free trial
    static let iapYearly7 = "com.tomasbeja.pact.yearly7"    // same price, 7-day free trial (exit sheet only)
    static let iapMonthly = "com.tomasbeja.pact.monthly"    // 7,99 € / $7.99 a month, no trial
    static let allProducts = [iapYearly, iapYearly7, iapMonthly]
    static let savesPerRound = 3
    /// 4 to 6 rules per person, at least 2 of them photo rules.
    static let minRules = 4
    static let maxRules = 6
    static let minPhotoRules = 2
    /// The 75 (the signature challenge) and rounds from before challenges existed.
    static let roundLengthDays = 75
    static let maxPauseDays = 3
    static let pauseAutoAcceptHours: Double = 12
    static let tweakAutoAcceptHours: Double = 24
    static let eveningWarning = "21:00"
    static let lapseGraceDays = 7
    static let minIOS = "17.0"

    static let backgroundRefreshID = "com.tomasbeja.pact.refresh"
    static let disclaimer = "\(appName)'s The 75 challenge is not affiliated with 44Seven Media or the 75 HARD program."
}
