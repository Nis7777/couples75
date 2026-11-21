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
    /// 4 women w1–w4 and 4 men m1–m4. w1 is Maya's look, m1 is Joao's.
    static let all = ["w1", "w2", "w3", "w4", "m1", "m2", "m3", "m4"]

    static func assetName(_ id: String, _ pose: CharacterPose) -> String { "char_\(id)_\(pose.rawValue)" }
}

/// A single character image. Falls back to a peach rounded rectangle with an initial if the PNG is missing.
struct CharacterImage: View {
    var characterID: String
    var pose: CharacterPose
    var initial: String

    var body: some View {
        if let ui = UIImage(named: Characters.assetName(characterID, pose)) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
        } else {
            PlaceholderFigure(initial: initial, isBust: pose == .bust)
        }
    }
}

/// The dashed "not joined yet" partner.
struct PartnerOutlineImage: View {
    var body: some View {
        if let ui = UIImage(named: "partner_outline") {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            GeometryReader { geo in
                let w = min(geo.size.width, geo.size.height * 0.42)
                VStack(spacing: w * 0.06) {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .frame(width: w * 0.5, height: w * 0.5)
                    RoundedRectangle(cornerRadius: w * 0.25)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .frame(width: w, height: geo.size.height - w * 0.56)
                }
                .foregroundStyle(Color.textSecondary.opacity(0.6))
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(0.42, contentMode: .fit)
        }
    }
}

struct TrophyImage: View {
    var body: some View {
        if let ui = UIImage(named: "trophy") {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            Image(systemName: "trophy.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.gold)
        }
    }
}

struct PlaceholderFigure: View {
    var initial: String
    var isBust: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.peach)
            .overlay(
                Text(initial.prefix(1).uppercased())
                    .font(.rounded(40))
                    .foregroundStyle(Color.coral)
                    .minimumScaleFactor(0.3)
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
            .aspectRatio(isBust ? 1 : 0.42, contentMode: .fit)
    }
}
