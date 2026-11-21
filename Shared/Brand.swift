import Foundation

/// Every product-level constant lives here. Use these everywhere instead of literals.
enum Brand {
    static let appName = "Couples 75"
    static let tagline = "75 days. Same rules. One bet."
    static let bundleID = "com.dinismagina.couples75"
    static let appGroup = "group.com.dinismagina.couples75"
    static let urlScheme = "couples75"
    static let supportEmail = "nismagina@gmail.com"
    static let termsURL = URL(string: "https://example.com/terms")!
    static let privacyURL = URL(string: "https://example.com/privacy")!
    static let cloudKitContainer = "iCloud.com.dinismagina.couples75"
    /// A check-in must reach iCloud within this many hours of being taken.
    static let checkInUploadWindowHours: Double = 6
    static let iapMonthly = "com.dinismagina.couples75.monthly"
    static let iapYearly = "com.dinismagina.couples75.yearly"
    static let savesPerRound = 3
    static let roundLengthDays = 75
    static let maxPauseDays = 3
    static let pauseAutoAcceptHours: Double = 12
    static let tweakAutoAcceptHours: Double = 24
    static let eveningWarning = "21:00"
    static let lapseGraceDays = 7
    static let minIOS = "17.0"

    static let backgroundRefreshID = "com.dinismagina.couples75.refresh"
    static let disclaimer = "Couples 75 is not affiliated with 44Seven Media or the 75 HARD program."
}
