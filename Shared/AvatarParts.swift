import SwiftUI

// MARK: - Layered avatar: configuration and parts catalogue
//
// An avatar is a stack of independent layers (hair, skin, face, clothes, accessory) drawn on one shared
// canvas (`AvatarCanvas`), so every part lines up at every size. `AvatarConfig` stores only ids and colours.
// To add a part: add one line to the catalogue below (and, optionally, drop its art in the asset catalogue,
// see `AvatarArt`). Parts without art are drawn as flat vector placeholders in code.

enum AvatarBody: String, Codable, CaseIterable, Hashable {
    case feminine, masculine, neutral

    var title: String {
        switch self {
        case .feminine: return "Curvy"
        case .masculine: return "Broad"
        case .neutral: return "Straight"
        }
    }
}

/// Everything needed to draw an avatar. Colours are "#RRGGBB"; parts are catalogue ids.
struct AvatarConfig: Codable, Equatable, Hashable {
    var body: AvatarBody
    var skinTone: String
    var hairStyle: String
    var hairColor: String
    var eyes: String
    var brows: String
    var mouth: String
    var facialHair: String
    var top: String
    var topColor: String
    var bottoms: String
    var bottomsColor: String
    var shoes: String
    var accessory: String

    static let `default` = AvatarConfig(body: .feminine, skinTone: "#E0AC84", hairStyle: "wavy", hairColor: "#3B2A20",
                                        eyes: "dot", brows: "soft", mouth: "smile", facialHair: "none",
                                        top: "zip", topColor: "#F08A73", bottoms: "jeans", bottomsColor: "#2E3F66",
                                        shoes: "sneakers", accessory: "none")

    var hasHijab: Bool { hairStyle == "hijab" }

    /// A random but tasteful look (new users don't all start as the same person).
    static func random() -> AvatarConfig {
        let body = AvatarBody.allCases.randomElement() ?? .neutral
        let masc = body == .masculine
        let hairPool = masc ? ["short", "sidePart", "curly", "fade", "buzz", "manBun", "locs", "wavyShort"]
                            : ["wavy", "longStraight", "bob", "ponytail", "bun", "curlyLong", "braids", "pixie", "afro"]
        let hair = hairPool.randomElement() ?? "short"
        let natural = Array(AvatarPalette.hairColors.prefix(8))
        return AvatarConfig(
            body: body,
            skinTone: AvatarPalette.skinTones.randomElement()?.hex ?? "#E0AC84",
            hairStyle: hair,
            hairColor: natural.randomElement()?.hex ?? "#3B2A20",
            eyes: ["dot", "almond", "wide"].randomElement() ?? "dot",
            brows: masc ? "straight" : "soft",
            mouth: ["smile", "grin", "small"].randomElement() ?? "smile",
            facialHair: masc ? ["none", "none", "stubble", "shortBeard"].randomElement() ?? "none" : "none",
            top: ["zip", "tee", "hoodie", "sweater"].randomElement() ?? "zip",
            topColor: ["#F08A73", "#7FA38A", "#E2A93B", "#2F7F7C", "#B9A3D9", "#2E3F66"].randomElement() ?? "#F08A73",
            bottoms: ["jeans", "trousers"].randomElement() ?? "jeans",
            bottomsColor: ["#2E3F66", "#4A4A4F", "#1E1A18", "#F3E6D3"].randomElement() ?? "#2E3F66",
            shoes: ["sneakers", "boots", "flats"].randomElement() ?? "sneakers",
            accessory: "none")
    }

    /// The closest layered look for one of the 12 original preset characters (keeps their colour overrides).
    static func migrated(from avatar: Avatar) -> AvatarConfig {
        var c: AvatarConfig
        switch avatar.characterID {
        case "w1": c = .init(body: .feminine, skinTone: "#D9A27C", hairStyle: "wavy", hairColor: "#3B2A20", eyes: "dot",
                             brows: "soft", mouth: "smile", facialHair: "none", top: "zip", topColor: "#F08A73",
                             bottoms: "jeans", bottomsColor: "#2E3F66", shoes: "sneakers", accessory: "earrings")
        case "w2": c = .init(body: .feminine, skinTone: "#8A5233", hairStyle: "curlyBun", hairColor: "#1E1A18", eyes: "dot",
                             brows: "soft", mouth: "smile", facialHair: "none", top: "zip", topColor: "#E2A93B",
                             bottoms: "trousers", bottomsColor: "#4A4A4F", shoes: "sneakers", accessory: "earrings")
        case "w3": c = .init(body: .feminine, skinTone: "#F2C9A8", hairStyle: "longFringe", hairColor: "#1E1A18", eyes: "dot",
                             brows: "soft", mouth: "small", facialHair: "none", top: "zip", topColor: "#B9A3D9",
                             bottoms: "jeans", bottomsColor: "#2E3F66", shoes: "flats", accessory: "none")
        case "w4": c = .init(body: .feminine, skinTone: "#C68B5F", hairStyle: "sideBraid", hairColor: "#1E1A18", eyes: "dot",
                             brows: "soft", mouth: "smile", facialHair: "none", top: "zip", topColor: "#2F7F7C",
                             bottoms: "trousers", bottomsColor: "#4A4A4F", shoes: "sneakers", accessory: "none")
        case "w5": c = .init(body: .feminine, skinTone: "#EBC1A0", hairStyle: "hijab", hairColor: "#D99A9A", eyes: "dot",
                             brows: "soft", mouth: "smile", facialHair: "none", top: "zip", topColor: "#7FA38A",
                             bottoms: "trousers", bottomsColor: "#4A4A4F", shoes: "flats", accessory: "none")
        case "w6": c = .init(body: .feminine, skinTone: "#EBC1A0", hairStyle: "ponytail", hairColor: "#8C3F24", eyes: "dot",
                             brows: "soft", mouth: "smile", facialHair: "none", top: "zip", topColor: "#2E3F66",
                             bottoms: "jeans", bottomsColor: "#2E3F66", shoes: "sneakers", accessory: "none")
        case "m2": c = .init(body: .masculine, skinTone: "#8A5233", hairStyle: "fade", hairColor: "#1E1A18", eyes: "dot",
                             brows: "thick", mouth: "grin", facialHair: "fullBeard", top: "zip", topColor: "#2E3F66",
                             bottoms: "trousers", bottomsColor: "#4A4A4F", shoes: "sneakers", accessory: "none")
        case "m3": c = .init(body: .masculine, skinTone: "#F2C9A8", hairStyle: "short", hairColor: "#1E1A18", eyes: "dot",
                             brows: "straight", mouth: "smile", facialHair: "none", top: "zip", topColor: "#C9684A",
                             bottoms: "jeans", bottomsColor: "#2E3F66", shoes: "sneakers", accessory: "none")
        case "m4": c = .init(body: .masculine, skinTone: "#C68B5F", hairStyle: "curly", hairColor: "#1E1A18", eyes: "dot",
                             brows: "thick", mouth: "smile", facialHair: "fullBeard", top: "zip", topColor: "#E2A93B",
                             bottoms: "trousers", bottomsColor: "#4A4A4F", shoes: "boots", accessory: "none")
        case "m5": c = .init(body: .masculine, skinTone: "#E0AC84", hairStyle: "curly", hairColor: "#3B2A20", eyes: "dot",
                             brows: "straight", mouth: "smile", facialHair: "stubble", top: "zip", topColor: "#F08A73",
                             bottoms: "jeans", bottomsColor: "#2E3F66", shoes: "sneakers", accessory: "none")
        case "m6": c = .init(body: .masculine, skinTone: "#F2C9A8", hairStyle: "sidePart", hairColor: "#E2B96A", eyes: "dot",
                             brows: "straight", mouth: "smile", facialHair: "none", top: "zip", topColor: "#B9A3D9",
                             bottoms: "jeans", bottomsColor: "#2E3F66", shoes: "sneakers", accessory: "none")
        default:   c = .init(body: .masculine, skinTone: "#F2C9A8", hairStyle: "curly", hairColor: "#3B2A20", eyes: "dot",
                             brows: "straight", mouth: "smile", facialHair: "none", top: "zip", topColor: "#7FA38A",
                             bottoms: "jeans", bottomsColor: "#2E3F66", shoes: "sneakers", accessory: "none")
        }
        // Keep the colours they picked with the old builder.
        if let s = avatar.skin { c.skinTone = s }
        if let h = avatar.hair { c.hairColor = h }
        if let j = avatar.jacket { c.topColor = j }
        return c
    }
}

/// The builder's tabs, in order.
enum AvatarTab: String, CaseIterable, Identifiable {
    case hair, hairColor, skin, face, top, bottoms, shoes, extras
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hair: return "Hair"
        case .hairColor: return "Hair colour"
        case .skin: return "Skin"
        case .face: return "Face"
        case .top: return "Top"
        case .bottoms: return "Bottoms"
        case .shoes: return "Shoes"
        case .extras: return "Extras"
        }
    }
}

enum AvatarLayer: String {
    case hairBack, body, bottoms, shoes, top, hands, head, brows, eyes, mouth, facialHair, hairFront, accessory
}

/// One selectable part.
struct AvatarPart: Identifiable, Hashable {
    var id: String
    var name: String
    var layer: AvatarLayer
}

/// The catalogue: every part with its id, display name (also its accessibility label) and layer.
enum AvatarParts {
    static let hair: [AvatarPart] = [
        ("bald", "Bald"), ("buzz", "Buzz cut"), ("short", "Short"), ("fade", "Fade"), ("sidePart", "Side part"),
        ("fringe", "Fringe"), ("pixie", "Pixie"), ("curly", "Short curly"), ("wavyShort", "Short wavy"),
        ("mohawk", "Mohawk"), ("afro", "Afro"), ("coily", "Coily"), ("wavy", "Wavy"), ("bob", "Bob"),
        ("longStraight", "Long straight"), ("longFringe", "Long with fringe"), ("curlyLong", "Long curly"),
        ("ponytail", "Ponytail"), ("highPonytail", "High ponytail"), ("bun", "Bun"), ("curlyBun", "Curly bun"),
        ("spaceBuns", "Space buns"), ("manBun", "Man bun"), ("braids", "Two braids"), ("sideBraid", "Side braid"),
        ("locs", "Locs"), ("mullet", "Mullet"), ("hijab", "Hijab"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .hairFront) }

    static let eyes: [AvatarPart] = [
        ("dot", "Round eyes"), ("almond", "Almond eyes"), ("wide", "Wide eyes"), ("smile", "Smiling eyes"),
        ("sleepy", "Sleepy eyes"), ("lashes", "Eyes with lashes"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .eyes) }

    static let brows: [AvatarPart] = [
        ("soft", "Soft brows"), ("straight", "Straight brows"), ("thick", "Thick brows"), ("arched", "Arched brows"),
        ("none", "No brows"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .brows) }

    static let mouths: [AvatarPart] = [
        ("smile", "Smile"), ("grin", "Big grin"), ("small", "Small smile"), ("neutral", "Neutral"), ("laugh", "Laugh"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .mouth) }

    static let facialHair: [AvatarPart] = [
        ("none", "No facial hair"), ("stubble", "Stubble"), ("moustache", "Moustache"), ("goatee", "Goatee"),
        ("shortBeard", "Short beard"), ("fullBeard", "Full beard"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .facialHair) }

    static let tops: [AvatarPart] = [
        ("zip", "Zip jacket"), ("tee", "T-shirt"), ("tank", "Tank top"), ("hoodie", "Hoodie"), ("jacket", "Open jacket"),
        ("sweater", "Sweater"), ("dress", "Dress"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .top) }

    static let bottoms: [AvatarPart] = [
        ("jeans", "Jeans"), ("trousers", "Trousers"), ("leggings", "Leggings"), ("shorts", "Shorts"), ("skirt", "Skirt"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .bottoms) }

    static let shoes: [AvatarPart] = [
        ("sneakers", "Sneakers"), ("boots", "Boots"), ("flats", "Flats"), ("sandals", "Sandals"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .shoes) }

    static let accessories: [AvatarPart] = [
        ("none", "No accessory"), ("glasses", "Glasses"), ("sunglasses", "Sunglasses"), ("earrings", "Earrings"),
        ("cap", "Cap"), ("beanie", "Beanie"),
    ].map { AvatarPart(id: $0.0, name: $0.1, layer: .accessory) }

    static func name(_ id: String, in list: [AvatarPart]) -> String { list.first { $0.id == id }?.name ?? id }
}

/// Colour choices.
extension AvatarPalette {
    /// 10 skin tones, light to deep.
    static let skinTones: [Swatch] = [
        .init(name: "Porcelain skin", hex: "#F6D7C3"), .init(name: "Fair skin", hex: "#F2C9A8"),
        .init(name: "Light skin", hex: "#EBC1A0"), .init(name: "Light medium skin", hex: "#E0AC84"),
        .init(name: "Medium skin", hex: "#D9A27C"), .init(name: "Olive skin", hex: "#C68B5F"),
        .init(name: "Tan skin", hex: "#A86B45"), .init(name: "Brown skin", hex: "#8A5233"),
        .init(name: "Dark brown skin", hex: "#6B3D25"), .init(name: "Deep skin", hex: "#4A2A1A"),
    ]
    /// 8 natural hair colours and 2 fun ones.
    static let hairColors: [Swatch] = [
        .init(name: "Black hair", hex: "#1E1A18"), .init(name: "Dark brown hair", hex: "#3B2A20"),
        .init(name: "Brown hair", hex: "#6B4630"), .init(name: "Auburn hair", hex: "#8C3F24"),
        .init(name: "Ginger hair", hex: "#C8642E"), .init(name: "Blonde hair", hex: "#E2B96A"),
        .init(name: "Platinum hair", hex: "#EFE3C8"), .init(name: "Grey hair", hex: "#A8A29E"),
        .init(name: "Pink hair", hex: "#E68AA6"), .init(name: "Blue hair", hex: "#5B7FD1"),
    ]
    /// 10 clothing colours from the brand.
    static let clothing: [Swatch] = [
        .init(name: "Coral", hex: "#F08A73"), .init(name: "Peach", hex: "#F9C4A8"), .init(name: "Gold", hex: "#E2A93B"),
        .init(name: "Sage", hex: "#7FA38A"), .init(name: "Navy", hex: "#2E3F66"), .init(name: "Teal", hex: "#2F7F7C"),
        .init(name: "Lavender", hex: "#B9A3D9"), .init(name: "Cream", hex: "#F3E6D3"), .init(name: "Charcoal", hex: "#4A4A4F"),
        .init(name: "Black", hex: "#1E1A18"),
    ]
}

extension Avatar {
    /// The layered look: the saved config, or the closest one for an old preset.
    var resolvedConfig: AvatarConfig { config ?? AvatarConfig.migrated(from: self) }

    /// The starting avatar for a new person: a random layered look, or the preset until the layered art exists.
    static func newDefault(preset: String) -> Avatar {
        AvatarArt.layeredEnabled ? Avatar(config: .random()) : Avatar(characterID: preset)
    }

    /// A new layered avatar (characterID is kept for older app versions and records).
    init(config: AvatarConfig) {
        self.init(characterID: config.body == .masculine ? "m1" : "w1")
        self.config = config
    }
}
