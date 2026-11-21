import SwiftUI
import UIKit

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
    /// Selected cards, banners, soft fills, illustration panels.
    static let peach = Color(hex: 0xFDE4D8)
    /// A deeper peach for the edge of glows and blobs.
    static let peachDeep = Color(hex: 0xFAD9C8)
    /// Light peach track behind progress bars and rings.
    static let track = Color(hex: 0xF5E6DB)
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
    /// "Pending" / "x left" chips.
    static let brownChip = Color(hex: 0x8C5A47)
    static let faint = Color(hex: 0xEFE2D9)
    /// Unselected radio rings.
    static let radio = Color(hex: 0xE8CDBD)
}

// MARK: - Typography: Outfit (bundled, OFL), falling back to SF Pro Rounded.

enum AppFont {
    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light, .regular: return "Outfit-Regular"
        case .medium: return "Outfit-Medium"
        case .semibold: return "Outfit-SemiBold"
        case .bold: return "Outfit-Bold"
        case .heavy, .black: return "Outfit-ExtraBold"
        default: return "Outfit-Regular"
        }
    }

    static var isAvailable: Bool { UIFont(name: "Outfit-Regular", size: 12) != nil }

    static func uiFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let n: String
        switch weight {
        case .medium: n = "Outfit-Medium"
        case .semibold: n = "Outfit-SemiBold"
        case .bold: n = "Outfit-Bold"
        case .heavy, .black: n = "Outfit-ExtraBold"
        default: n = "Outfit-Regular"
        }
        return UIFont(name: n, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

extension Font {
    /// The app font at `size` points (scales with Dynamic Type).
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if AppFont.isAvailable {
            return .custom(AppFont.name(for: weight), size: size, relativeTo: size >= 22 ? .title2 : .body)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    /// Titles.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { app(size, weight) }
}

// MARK: - Characters (section 1.3)

enum CharacterPose: String, CaseIterable {
    case stand, crossed, cheer, stretch, bust
}

enum Characters {
    /// 12 presets: 6 women w1–w6 and 6 men m1–m6, shown mixed. w1 is Maya's look, m1 is Joao's.
    static let all = ["w1", "m1", "w2", "m2", "w3", "m3", "w4", "m4", "w5", "m5", "w6", "m6"]

    static func assetName(_ id: String, _ pose: CharacterPose) -> String { "char_\(id)_\(pose.rawValue)" }

    private static var aspectCache: [String: CGFloat] = [:]

    /// Width ÷ height of an image asset (used to lay figures out without cropping heads).
    static func aspect(of assetName: String, fallback: CGFloat = 0.37) -> CGFloat {
        if let a = aspectCache[assetName] { return a }
        guard let img = UIImage(named: assetName), img.size.height > 0 else { return fallback }
        let a = img.size.width / img.size.height
        aspectCache[assetName] = a
        return a
    }
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

/// A bust in a circle (03, 14, 25, widgets).
struct BustCircle: View {
    var characterID: String?
    var size: CGFloat
    var ring: Color = .peach
    var ringWidth: CGFloat = 0
    var fill: Color = .peach

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let characterID {
                // Top of the head stays inside the circle; shoulders run off the bottom.
                Image(Characters.assetName(characterID, .bust))
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.86)
                    .offset(y: size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring, lineWidth: ringWidth))
    }
}
