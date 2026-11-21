import SwiftUI

// Design tokens (section 1.1). Shared by the app and the widget extension.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Every screen background.
    static let ivory = Color(hex: 0xFFF6F0)
    /// Selected cards, banners, soft fills.
    static let peach = Color(hex: 0xFDE4D8)
    /// Cards.
    static let card = Color.white
    static let cardBorder = Color(hex: 0xF1DDD2)
    static let buttonBorder = Color(hex: 0xEAD5CA)
    static let textPrimary = Color(hex: 0x2A1814)
    static let textSecondary = Color(hex: 0x4A322B)
    /// Primary buttons, selected radios and checks, accents, partner A.
    static let coral = Color(hex: 0xC9452A)
    /// Progress, ring, streak, "Best value".
    static let gold = Color(hex: 0xE8A54B)
    /// "Done", "Partner linked", partner B.
    static let sage = Color(hex: 0x3F8F6B)
    static let brownChip = Color(hex: 0x8A5A44)
    static let faint = Color(hex: 0xEADBD2)
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Characters (section 1.3)

enum CharacterPose: String, CaseIterable {
    case stand, crossed, cheer, stretch, bust
}

enum Characters {
    /// 12 presets: 6 women w1–w6 and 6 men m1–m6, shown mixed. w1 is Maya's look, m1 is Joao's.
    static let all = ["w1", "m1", "w2", "m2", "w3", "m3", "w4", "m4", "w5", "m5", "w6", "m6"]

    static func assetName(_ id: String, _ pose: CharacterPose) -> String { "char_\(id)_\(pose.rawValue)" }
}

/// A single character image from the asset catalog (transparent PNG).
struct CharacterImage: View {
    var characterID: String
    var pose: CharacterPose

    var body: some View {
        Image(Characters.assetName(characterID, pose))
            .resizable()
            .scaledToFit()
    }
}

/// The dashed "not joined yet" partner.
struct PartnerOutlineImage: View {
    var body: some View {
        Image("partner_outline")
            .resizable()
            .scaledToFit()
    }
}

struct TrophyImage: View {
    var body: some View {
        Image("trophy")
            .resizable()
            .scaledToFit()
    }
}
