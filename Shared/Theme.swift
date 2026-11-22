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

// MARK: - Characters and avatars (section 1.3)

enum CharacterPose: String, CaseIterable {
    case stand, crossed, cheer, stretch, bust
}

/// A member's avatar: one of the 12 base characters (the "hairstyle") plus optional colour overrides.
/// nil colours mean the character's original colours.
struct Avatar: Codable, Equatable, Hashable {
    var characterID: String
    var skin: String?
    var hair: String?
    var jacket: String?

    init(characterID: String, skin: String? = nil, hair: String? = nil, jacket: String? = nil) {
        self.characterID = characterID
        self.skin = skin
        self.hair = hair
        self.jacket = jacket
    }

    /// w5 wears a hijab: the hair colour tab recolours the hijab instead.
    var hasHijab: Bool { characterID == "w5" }
}

/// Who appears in a scene.
struct SceneCharacter: Equatable {
    var avatar: Avatar
    var name: String

    var characterID: String { avatar.characterID }

    init(avatar: Avatar, name: String) {
        self.avatar = avatar
        self.name = name
    }

    init(characterID: String, name: String) {
        self.init(avatar: Avatar(characterID: characterID), name: name)
    }
}

enum Characters {
    /// 12 presets ("hairstyles"): 6 women w1–w6 and 6 men m1–m6, shown mixed. w1 is Maya's look, m1 is Joao's.
    static let all = ["w1", "m1", "w2", "m2", "w3", "m3", "w4", "m4", "w5", "m5", "w6", "m6"]

    static func assetName(_ id: String, _ pose: CharacterPose) -> String { "char_\(id)_\(pose.rawValue)" }

    static func maskName(_ id: String, _ pose: CharacterPose, _ part: String) -> String {
        "mask_\(id)_\(pose.rawValue)_\(part)"
    }

    private static var aspectCache: [String: CGFloat] = [:]

    /// Width ÷ height of an image asset (used to lay figures out without cropping heads).
    static func aspect(of assetName: String, fallback: CGFloat = 0.37) -> CGFloat {
        if let a = aspectCache[assetName] { return a }
        guard let img = UIImage(named: assetName), img.size.height > 0 else { return fallback }
        let a = img.size.width / img.size.height
        aspectCache[assetName] = a
        return a
    }

    /// Each character's original colours (skin, hair or hijab, jacket), shown as the first swatch.
    static let originals: [String: (skin: String, hair: String, jacket: String)] = [
        "w1": ("#ED9057", "#3C291F", "#F67C66"), "w2": ("#9C582E", "#2C2119", "#E29637"),
        "w3": ("#FBBA8A", "#322924", "#C0A7CE"), "w4": ("#DF8B55", "#33241C", "#2F6E6E"),
        "w5": ("#FAAD77", "#E28A76", "#75816C"), "w6": ("#FCB580", "#924C22", "#303B57"),
        "m1": ("#FDBB8A", "#39281E", "#728068"), "m2": ("#985730", "#272421", "#28324B"),
        "m3": ("#FDBD8B", "#302923", "#D46D4E"), "m4": ("#E29254", "#2B241E", "#E79D39"),
        "m5": ("#FBAF78", "#38281E", "#F37B66"), "m6": ("#FDBF8F", "#E5A86B", "#BDA5CA"),
    ]
}

/// The avatar builder's colour choices (section 1.3).
enum AvatarPalette {
    struct Swatch: Identifiable, Hashable {
        var name: String
        var hex: String
        var id: String { hex + name }
    }

    static let skin: [Swatch] = [
        .init(name: "Porcelain", hex: "#F6D7C3"), .init(name: "Light", hex: "#EBC1A0"),
        .init(name: "Light medium", hex: "#D9A27C"), .init(name: "Medium", hex: "#C68B5F"),
        .init(name: "Tan", hex: "#A86B45"), .init(name: "Brown", hex: "#8A5233"),
        .init(name: "Dark brown", hex: "#6B3D25"), .init(name: "Deep", hex: "#4A2A1A"),
    ]
    static let hair: [Swatch] = [
        .init(name: "Black", hex: "#1E1A18"), .init(name: "Dark brown", hex: "#3B2A20"),
        .init(name: "Brown", hex: "#6B4630"), .init(name: "Auburn", hex: "#8C3F24"),
        .init(name: "Ginger", hex: "#C8642E"), .init(name: "Blonde", hex: "#E2B96A"),
        .init(name: "Platinum", hex: "#EFE3C8"), .init(name: "Grey", hex: "#A8A29E"),
    ]
    static let hijab: [Swatch] = [
        .init(name: "Dusty rose", hex: "#D99A9A"), .init(name: "Sage", hex: "#7FA38A"),
        .init(name: "Navy", hex: "#2E3F66"), .init(name: "Beige", hex: "#D8C3A5"),
        .init(name: "Black", hex: "#1E1A18"), .init(name: "Lavender", hex: "#B9A3D9"),
        .init(name: "Teal", hex: "#2F7F7C"), .init(name: "Terracotta", hex: "#C9684A"),
    ]
    static let jacket: [Swatch] = [
        .init(name: "Coral", hex: "#F08A73"), .init(name: "Sage", hex: "#7FA38A"),
        .init(name: "Mustard", hex: "#E2A93B"), .init(name: "Lavender", hex: "#B9A3D9"),
        .init(name: "Navy", hex: "#2E3F66"), .init(name: "Terracotta", hex: "#C9684A"),
        .init(name: "Teal", hex: "#2F7F7C"), .init(name: "Dusty rose", hex: "#D99A9A"),
    ]
}

extension Color {
    /// "#RRGGBB" → Color (nil if malformed).
    init?(hexString: String?) {
        guard var s = hexString?.trimmingCharacters(in: .whitespaces) else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}

/// One character, recoloured: the original image, then each shading layer (skin, hair, jacket)
/// masked and multiplied by the chosen colour, so the original shadows stay.
struct CharacterView: View {
    var characterID: String
    var pose: CharacterPose
    var skin: Color? = nil
    var hairColor: Color? = nil
    var jacketColor: Color? = nil

    var body: some View {
        ZStack {
            Image(Characters.assetName(characterID, pose)).resizable().scaledToFit()
            if let skin { layer("skin", skin) }
            if let hairColor { layer("hair", hairColor) }
            if let jacketColor { layer("jacket", jacketColor) }
        }
    }

    private func layer(_ part: String, _ color: Color) -> some View {
        Image(Characters.maskName(characterID, pose, part))
            .resizable()
            .scaledToFit()
            .colorMultiply(color)
    }
}

extension CharacterView {
    init(avatar: Avatar, pose: CharacterPose) {
        self.init(characterID: avatar.characterID, pose: pose,
                  skin: Color(hexString: avatar.skin), hairColor: Color(hexString: avatar.hair),
                  jacketColor: Color(hexString: avatar.jacket))
    }
}

/// A single character (kept for call sites that only know the id and pose).
struct CharacterImage: View {
    var characterID: String
    var pose: CharacterPose
    var avatar: Avatar? = nil

    var body: some View {
        CharacterView(avatar: avatar ?? Avatar(characterID: characterID), pose: pose)
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

/// A bust in a circle (03, 25, widgets). `avatar == nil` draws the dashed partner outline.
struct BustCircle: View {
    var avatar: Avatar?
    var size: CGFloat
    var ring: Color = .peach
    var ringWidth: CGFloat = 0
    var fill: Color = .peach

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let avatar {
                // Top of the head stays inside the circle; shoulders run off the bottom.
                CharacterView(avatar: avatar, pose: .bust)
                    .frame(width: size * 0.86)
                    .offset(y: size * 0.12)
            } else {
                Image("partner_outline")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.74)
                    .offset(y: size * 0.48)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring, lineWidth: ringWidth))
    }
}
