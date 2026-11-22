import SwiftUI
import UIKit

// MARK: - Canvas

/// Every layer is drawn on the same 200 × 400 canvas (points; art at @3x = 600 × 1200 px), so parts always
/// line up. Anchors follow the base art: eyes ≈ y 78, shoulders ≈ y 116, soles y 382 (points).
/// The bust/head-only view shows the region y 14…214 (200 × 200).
enum AvatarCanvas {
    static let size = CGSize(width: 200, height: 400)
    /// Head and shoulders, fitted to the art (scalp ≈ y 52, chin ≈ y 107, shoulders ≈ y 116 in points).
    static let bustRect = CGRect(x: 52, y: 38, width: 96, height: 96)
    static let fullAspect: CGFloat = size.width / size.height   // 0.5
    static let bustAspect: CGFloat = 1

}

/// The avatar art. For a part to appear, add to the asset catalogue:
/// - `avatar_<layer>_<id>` (or `avatar_<layer>_<id>_<pose>` for pose-specific art): a 600 × 1200 px transparent
///   PNG or PDF on the full canvas, **template** rendering (white/grey shapes; the app tints it), and
/// - `avatar_<layer>_<id>_shade` (optional, same canvas, NOT tinted): the line art and soft shading on top.
enum AvatarArt {
    private static var cache: [String: Bool] = [:]

    /// The layered avatar is on once the base art is in the asset catalogue (`avatar_head_head` and
    /// `avatar_body_neutral_stand`). Without it the app shows the 12 illustrated characters and the original builder.
    static var layeredEnabled: Bool {
        exists("avatar_head_head") && exists("avatar_body_neutral_stand")
    }

    static func exists(_ name: String) -> Bool {
        if let v = cache[name] { return v }
        let v = UIImage(named: name) != nil
        cache[name] = v
        return v
    }

    /// Art that comes with a `_shade` file is a flat shape the app tints (hair, and later skin and clothes);
    /// art without one is a finished colour drawing and is drawn as it is (the test head and body).
    static func isTintable(_ name: String) -> Bool { exists(name + "_shade") }

    /// Hairstyles with art (front or back), plus bald, which needs none.
    static func hasArt(_ layer: AvatarLayer, _ id: String) -> Bool {
        name(layer, id, pose: .stand) != nil
    }

    static func hairHasArt(_ id: String) -> Bool {
        id == "bald" || hasArt(.hairFront, id) || hasArt(.hairBack, id)
    }

    /// The closest hairstyle that has art (so old presets and random looks never come out bald by accident).
    static func hairWithArt(_ id: String) -> String {
        if !layeredEnabled || hairHasArt(id) { return id }
        let family: [String: [String]] = [
            "wavy": ["longStraight", "longFringe", "bob", "curlyLong", "wavyShort", "mullet", "pixie", "fringe"],
            "curly": ["afro", "coily", "curlyBun", "locs", "curlyLong"],
            "ponytail": ["highPonytail", "bun", "spaceBuns", "braids", "sideBraid", "manBun"],
            "short": ["buzz", "fade", "sidePart", "mohawk", "fringe", "pixie", "wavyShort", "hijab"],
        ]
        for (target, members) in family where members.contains(id) && hairHasArt(target) { return target }
        return ["short", "wavy", "curly", "ponytail"].first(where: hairHasArt) ?? id
    }

    /// The best art name for a part and pose, if any art exists.
    /// Lookup order: this pose, no pose, the stand pose (so a first batch drawn only in `stand` works for
    /// every pose); for the body, the neutral body as a last resort.
    static func name(_ layer: AvatarLayer, _ id: String, pose: CharacterPose) -> String? {
        let ids = layer == .body && id != "neutral" ? [id, "neutral"] : [id]
        for i in ids {
            for candidate in ["avatar_\(layer.rawValue)_\(i)_\(pose.rawValue)", "avatar_\(layer.rawValue)_\(i)",
                              "avatar_\(layer.rawValue)_\(i)_stand"] where exists(candidate) {
                return candidate
            }
        }
        return nil
    }
}

// MARK: - View

/// The layered avatar. Layers, back to front: hair (back) → body/skin → bottoms → shoes → top (with arms and
/// sleeves) → neck/head → brows, eyes, mouth → facial hair → hair (front) → accessory.
struct LayeredAvatarView: View {
    var config: AvatarConfig
    var pose: CharacterPose = .stand
    /// Head and shoulders only (circular thumbnails).
    var headOnly = false

    var body: some View {
        let bust = headOnly || pose == .bust
        Canvas { ctx, size in
            let region = bust ? AvatarCanvas.bustRect : CGRect(origin: .zero, size: AvatarCanvas.size)
            ctx.scaleBy(x: size.width / region.width, y: size.height / region.height)
            ctx.translateBy(x: -region.minX, y: -region.minY)
            AvatarPainter(config: config, pose: pose == .bust ? .stand : pose).draw(in: &ctx)
        }
        .aspectRatio(bust ? AvatarCanvas.bustAspect : AvatarCanvas.fullAspect, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - Painter

/// Draws the avatar from the art in the asset catalogue only. A part without art is simply not drawn;
/// there are no code-drawn shapes.
struct AvatarPainter {
    var config: AvatarConfig
    var pose: CharacterPose

    private var skin: Color { Color(hexString: config.skinTone) ?? Color(hex: 0xE0AC84) }
    private var hair: Color { Color(hexString: config.hairColor) ?? Color(hex: 0x3B2A20) }
    private var topColor: Color { Color(hexString: config.topColor) ?? Color(hex: 0xF08A73) }
    private var bottomsColor: Color { Color(hexString: config.bottomsColor) ?? Color(hex: 0x2E3F66) }

    /// The hairstyle actually drawn: the chosen one, or its closest relative with art.
    private var hairStyle: String { AvatarArt.hairWithArt(config.hairStyle) }

    func draw(in ctx: inout GraphicsContext) {
        layer(&ctx, .hairBack, hairStyle, tint: hair)
        layer(&ctx, .body, config.body.rawValue, tint: skin)
        if config.top != "dress" { layer(&ctx, .bottoms, config.bottoms, tint: bottomsColor) }
        layer(&ctx, .shoes, config.shoes, tint: nil)
        layer(&ctx, .top, config.top, tint: topColor)
        layer(&ctx, .hands, "skin", tint: skin)          // hands in front of the top (hands on hips, crossed arms)
        layer(&ctx, .head, "head", tint: skin)
        layer(&ctx, .brows, config.brows, tint: hair)
        layer(&ctx, .eyes, config.eyes, tint: nil)
        layer(&ctx, .mouth, config.mouth, tint: nil)
        layer(&ctx, .facialHair, config.facialHair, tint: hair)
        layer(&ctx, .hairFront, hairStyle, tint: hair)
        layer(&ctx, .accessory, config.accessory, tint: topColor)
    }

    /// A part's art: a tinted shape plus its untinted `_shade`, or a finished drawing as it is.
    private func layer(_ ctx: inout GraphicsContext, _ layer: AvatarLayer, _ id: String, tint: Color?) {
        guard let name = AvatarArt.name(layer, id, pose: pose) else { return }
        let rect = CGRect(origin: .zero, size: AvatarCanvas.size)
        let tinted = tint != nil && AvatarArt.isTintable(name)
        var art = ctx.resolve(Image(name).renderingMode(tinted ? .template : .original))
        if tinted, let tint { art.shading = .color(tint) }
        ctx.draw(art, in: rect)
        if AvatarArt.exists(name + "_shade") {
            ctx.draw(ctx.resolve(Image(name + "_shade")), in: rect)
        }
    }
}
