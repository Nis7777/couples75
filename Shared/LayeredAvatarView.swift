import SwiftUI
import UIKit

// MARK: - Canvas

/// Every layer is drawn on the same 200 × 400 canvas (points; art at @3x = 600 × 1200 px), so parts always
/// line up. Head centre (100, 80); shoulders at y 128; waist y 232; ankles y 360; floor y 382.
/// The bust/head-only view shows the region y 14…214 (200 × 200).
enum AvatarCanvas {
    static let size = CGSize(width: 200, height: 400)
    /// Head and shoulders. With the final art the head is smaller and higher than the placeholder head
    /// (scalp ≈ y 52, chin ≈ y 107, shoulders ≈ y 116 in points), so the crop follows the art.
    static var bustRect: CGRect {
        AvatarArt.layeredEnabled ? CGRect(x: 52, y: 38, width: 96, height: 96)
                                 : CGRect(x: 0, y: 14, width: 200, height: 200)
    }
    static let fullAspect: CGFloat = size.width / size.height   // 0.5
    static let bustAspect: CGFloat = 1

    static let headCenter = CGPoint(x: 100, y: 80)
    static let headRX: CGFloat = 33
    static let headRY: CGFloat = 38
    static let line = Color(hex: 0x2A1814)
    static let lineWidth: CGFloat = 2
}

/// Optional final art. For a part to use art instead of the code-drawn placeholder, add to the asset catalogue:
/// - `avatar_<layer>_<id>` (or `avatar_<layer>_<id>_<pose>` for pose-specific art): a 600 × 1200 px transparent
///   PNG or PDF on the full canvas, **template** rendering (white/grey shapes; the app tints it), and
/// - `avatar_<layer>_<id>_shade` (optional, same canvas, NOT tinted): the line art and soft shading on top.
enum AvatarArt {
    private static var cache: [String: Bool] = [:]

    /// The layered avatar turns on by itself once the base art is in the asset catalogue
    /// (`avatar_head_head` and `avatar_body_neutral_stand`). Until then the app keeps the 12 illustrated
    /// characters and the original builder, so the code-drawn placeholders never ship.
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

struct AvatarPainter {
    var config: AvatarConfig
    var pose: CharacterPose

    private var skin: Color { Color(hexString: config.skinTone) ?? Color(hex: 0xE0AC84) }
    private var hair: Color { Color(hexString: config.hairColor) ?? Color(hex: 0x3B2A20) }
    private var topColor: Color { Color(hexString: config.topColor) ?? Color(hex: 0xF08A73) }
    private var bottomsColor: Color { Color(hexString: config.bottomsColor) ?? Color(hex: 0x2E3F66) }
    private let line = AvatarCanvas.line
    private let lw = AvatarCanvas.lineWidth
    private let hc = AvatarCanvas.headCenter
    private let rx = AvatarCanvas.headRX
    private let ry = AvatarCanvas.headRY

    // Body proportions by shape.
    private var shoulder: CGFloat { config.body == .masculine ? 46 : config.body == .feminine ? 39 : 42 }
    private var waist: CGFloat { config.body == .masculine ? 36 : config.body == .feminine ? 28 : 32 }
    private var hip: CGFloat { config.body == .masculine ? 35 : config.body == .feminine ? 38 : 35 }

    /// The hairstyle actually drawn: the chosen one, or its closest relative with art.
    private var hairStyle: String { AvatarArt.hairWithArt(config.hairStyle) }

    func draw(in ctx: inout GraphicsContext) {
        layer(&ctx, .hairBack, hairStyle, tint: hair) { c in drawHairBack(&c) }
        layer(&ctx, .body, config.body.rawValue, tint: skin) { c in drawLegs(&c) }
        if config.top != "dress" {
            layer(&ctx, .bottoms, config.bottoms, tint: bottomsColor) { c in drawBottoms(&c) }
        }
        layer(&ctx, .shoes, config.shoes, tint: nil) { c in drawShoes(&c) }
        layer(&ctx, .top, config.top, tint: topColor) { c in drawTop(&c) }
        // Final art only: hands that sit in front of the top (hands on hips, crossed arms). The placeholders
        // already draw hands with the arms.
        if let hands = AvatarArt.name(.hands, "skin", pose: pose) {
            var art = ctx.resolve(Image(hands).renderingMode(.template))
            art.shading = .color(skin)
            ctx.draw(art, in: CGRect(origin: .zero, size: AvatarCanvas.size))
        }
        layer(&ctx, .head, "head", tint: skin) { c in drawHead(&c) }
        layer(&ctx, .brows, config.brows, tint: hair) { c in drawBrows(&c) }
        layer(&ctx, .eyes, config.eyes, tint: nil) { c in drawEyes(&c) }
        layer(&ctx, .mouth, config.mouth, tint: nil) { c in drawMouth(&c) }
        layer(&ctx, .facialHair, config.facialHair, tint: hair) { c in drawFacialHair(&c) }
        layer(&ctx, .hairFront, hairStyle, tint: hair) { c in drawHairFront(&c) }
        layer(&ctx, .accessory, config.accessory, tint: topColor) { c in drawAccessory(&c) }
    }

    /// Uses the part's art when it exists (tinted shape + untinted shading, or a finished drawing as it is).
    /// With final art switched on, a part without art is simply not drawn (no placeholders over real art);
    /// placeholders only appear in previews before any art exists.
    private func layer(_ ctx: inout GraphicsContext, _ layer: AvatarLayer, _ id: String, tint: Color?,
                       placeholder: (inout GraphicsContext) -> Void) {
        let rect = CGRect(origin: .zero, size: AvatarCanvas.size)
        guard let name = AvatarArt.name(layer, id, pose: pose) else {
            if !AvatarArt.layeredEnabled { placeholder(&ctx) }
            return
        }
        let tinted = tint != nil && AvatarArt.isTintable(name)
        var art = ctx.resolve(Image(name).renderingMode(tinted ? .template : .original))
        if tinted, let tint { art.shading = .color(tint) }
        ctx.draw(art, in: rect)
        if AvatarArt.exists(name + "_shade") {
            ctx.draw(ctx.resolve(Image(name + "_shade")), in: rect)
        }
    }

    // MARK: Fill helpers

    /// Flat fill, soft shading from the light side, and the line.
    private func paint(_ ctx: inout GraphicsContext, _ path: Path, _ color: Color, shade: Bool = true, stroke: Bool = true) {
        ctx.fill(path, with: .color(color))
        if shade {
            let b = path.boundingRect
            ctx.fill(path, with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.13)]),
                                                 startPoint: CGPoint(x: b.minX + b.width * 0.45, y: b.minY),
                                                 endPoint: CGPoint(x: b.maxX, y: b.maxY)))
        }
        if stroke { ctx.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)) }
    }

    private func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }

    /// Points along an ellipse from angle a0 to a1 (radians; 0 = right, π/2 = down, 3π/2 = up).
    private func arc(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ a0: CGFloat, _ a1: CGFloat, n: Int = 28) -> [CGPoint] {
        (0...n).map { i in
            let t = a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)
            return CGPoint(x: c.x + rx * cos(t), y: c.y + ry * sin(t))
        }
    }

    /// A blob made of overlapping circles (curly/coily textures).
    private func curls(_ points: [CGPoint], r: CGFloat) -> Path {
        var p = Path()
        for pt in points { p.addEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)) }
        return p
    }

    // MARK: Body, legs, arms

    private var legTop: CGFloat { 236 }
    private var ankle: CGFloat { 360 }

    private func legPath(left: Bool, to bottom: CGFloat, widen: CGFloat = 0) -> Path {
        let outer: CGFloat = left ? 100 - hip + 4 : 100 + hip - 4
        let inner: CGFloat = left ? 98.5 : 101.5
        let footOuter: CGFloat = left ? 78 : 122
        let footInner: CGFloat = left ? 95 : 105
        let t = (bottom - legTop) / (ankle - legTop)
        let bo = outer + (footOuter - outer) * t
        let bi = inner + (footInner - inner) * t
        var p = Path()
        p.move(to: CGPoint(x: outer - (left ? widen : -widen), y: legTop))
        p.addLine(to: CGPoint(x: inner, y: legTop))
        p.addLine(to: CGPoint(x: bi, y: bottom))
        p.addLine(to: CGPoint(x: bo - (left ? widen : -widen), y: bottom))
        p.closeSubpath()
        return p
    }

    private func drawLegs(_ ctx: inout GraphicsContext) {
        paint(&ctx, legPath(left: true, to: ankle + 4), skin)
        paint(&ctx, legPath(left: false, to: ankle + 4), skin)
    }

    private func drawBottoms(_ ctx: inout GraphicsContext) {
        let c = bottomsColor
        switch config.bottoms {
        case "shorts":
            paint(&ctx, waistBand(), c)
            paint(&ctx, legPath(left: true, to: 296, widen: 3), c)
            paint(&ctx, legPath(left: false, to: 296, widen: 3), c)
        case "skirt":
            var p = Path()
            p.move(to: CGPoint(x: 100 - waist - 4, y: 228))
            p.addLine(to: CGPoint(x: 100 + waist + 4, y: 228))
            p.addLine(to: CGPoint(x: 100 + hip + 16, y: 304))
            p.addQuadCurve(to: CGPoint(x: 100 - hip - 16, y: 304), control: CGPoint(x: 100, y: 312))
            p.closeSubpath()
            paint(&ctx, p, c)
        case "leggings":
            paint(&ctx, waistBand(), c)
            paint(&ctx, legPath(left: true, to: ankle - 4), c)
            paint(&ctx, legPath(left: false, to: ankle - 4), c)
        default: // jeans, trousers
            paint(&ctx, waistBand(), c)
            paint(&ctx, legPath(left: true, to: ankle - 2, widen: 1.5), c)
            paint(&ctx, legPath(left: false, to: ankle - 2, widen: 1.5), c)
            if config.bottoms == "jeans" {
                var seams = Path()
                seams.move(to: CGPoint(x: 100 - hip / 2, y: 246)); seams.addLine(to: CGPoint(x: 100 - 13, y: ankle - 6))
                seams.move(to: CGPoint(x: 100 + hip / 2, y: 246)); seams.addLine(to: CGPoint(x: 100 + 13, y: ankle - 6))
                ctx.stroke(seams, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }

    private func waistBand() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 100 - waist - 3, y: 226))
        p.addLine(to: CGPoint(x: 100 + waist + 3, y: 226))
        p.addLine(to: CGPoint(x: 100 + hip - 2, y: legTop + 4))
        p.addLine(to: CGPoint(x: 100 - hip + 2, y: legTop + 4))
        p.closeSubpath()
        return p
    }

    private func drawShoes(_ ctx: inout GraphicsContext) {
        for left in [true, false] {
            let cx: CGFloat = left ? 100 - 14 : 100 + 14
            let toe: CGFloat = left ? -8 : 8
            switch config.shoes {
            case "boots":
                var p = Path(roundedRect: CGRect(x: cx - 11, y: ankle - 22, width: 22, height: 26), cornerRadius: 4)
                p.addEllipse(in: CGRect(x: cx - 12 + toe, y: ankle - 2, width: 24, height: 16))
                paint(&ctx, p, Color(hex: 0x6B4630))
            case "flats":
                paint(&ctx, ellipse(CGPoint(x: cx + toe * 0.6, y: ankle + 10), 13, 6), Color(hex: 0x2A1814))
            case "sandals":
                paint(&ctx, ellipse(CGPoint(x: cx + toe * 0.6, y: ankle + 10), 13, 6), skin)
                var strap = Path()
                strap.move(to: CGPoint(x: cx - 9 + toe * 0.6, y: ankle + 8)); strap.addLine(to: CGPoint(x: cx + 9 + toe * 0.6, y: ankle + 8))
                ctx.stroke(strap, with: .color(Color(hex: 0xA86B45)), lineWidth: 3)
                ctx.fill(Path(roundedRect: CGRect(x: cx - 13 + toe * 0.6, y: ankle + 14, width: 26, height: 3), cornerRadius: 1.5),
                         with: .color(Color(hex: 0xA86B45)))
            default: // sneakers
                let shoe = ellipse(CGPoint(x: cx + toe * 0.6, y: ankle + 8), 14, 8)
                paint(&ctx, shoe, .white)
                ctx.fill(Path(roundedRect: CGRect(x: cx - 14 + toe * 0.6, y: ankle + 11, width: 28, height: 5), cornerRadius: 2.5),
                         with: .color(Color(hex: 0xC9452A).opacity(0.85)))
            }
        }
    }

    /// Shoulder → elbow → hand, per pose.
    private func armPoints(left: Bool) -> [CGPoint] {
        let s: CGFloat = left ? -1 : 1
        let sh = CGPoint(x: 100 + s * (shoulder - 6), y: 138)
        switch pose {
        case .cheer where !left:
            return [sh, CGPoint(x: 100 + s * (shoulder + 16), y: 100), CGPoint(x: 100 + s * (shoulder + 6), y: 54)]
        case .crossed:
            return [sh, CGPoint(x: 100 + s * (shoulder + 2), y: 194), CGPoint(x: 100 - s * 22, y: left ? 178 : 186)]
        case .stretch:
            return [sh, CGPoint(x: 100 + s * (shoulder + 12), y: 98), CGPoint(x: 100 + s * (shoulder - 2), y: 48)]
        default: // hands on hips
            return [sh, CGPoint(x: 100 + s * (shoulder + 15), y: 190), CGPoint(x: 100 + s * (waist + 1), y: 226)]
        }
    }

    private func polyline(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        return p
    }

    /// Sleeve length as a fraction of the arm (0 = none, 0.5 = short, 1 = long).
    private var sleeve: CGFloat {
        switch config.top {
        case "tank": return 0
        case "tee", "dress": return 0.45
        default: return 0.92
        }
    }

    private func partial(_ pts: [CGPoint], _ f: CGFloat) -> [CGPoint] {
        guard f < 1, pts.count == 3 else { return pts }
        if f <= 0 { return [pts[0]] }
        if f <= 0.5 {
            let t = f / 0.5
            return [pts[0], CGPoint(x: pts[0].x + (pts[1].x - pts[0].x) * t, y: pts[0].y + (pts[1].y - pts[0].y) * t)]
        }
        let t = (f - 0.5) / 0.5
        return [pts[0], pts[1], CGPoint(x: pts[1].x + (pts[2].x - pts[1].x) * t, y: pts[1].y + (pts[2].y - pts[1].y) * t)]
    }

    private func drawArm(_ ctx: inout GraphicsContext, left: Bool) {
        let pts = armPoints(left: left)
        let arm = polyline(pts)
        ctx.stroke(arm, with: .color(line), style: StrokeStyle(lineWidth: 19 + lw * 2, lineCap: .round, lineJoin: .round))
        ctx.stroke(arm, with: .color(skin), style: StrokeStyle(lineWidth: 19, lineCap: .round, lineJoin: .round))
        let sl = partial(pts, sleeve)
        if sl.count > 1 {
            let sp = polyline(sl)
            ctx.stroke(sp, with: .color(line), style: StrokeStyle(lineWidth: 22 + lw * 2, lineCap: .round, lineJoin: .round))
            ctx.stroke(sp, with: .color(topColor), style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
        }
        // Hand.
        if let h = pts.last { paint(&ctx, ellipse(h, 9.5, 9.5), skin, shade: false) }
    }

    // MARK: Top

    private func torso(hem: CGFloat = 236) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 100 - shoulder, y: 150))
        p.addQuadCurve(to: CGPoint(x: 100 - shoulder + 16, y: 127), control: CGPoint(x: 100 - shoulder, y: 129))
        p.addLine(to: CGPoint(x: 100 + shoulder - 16, y: 127))
        p.addQuadCurve(to: CGPoint(x: 100 + shoulder, y: 150), control: CGPoint(x: 100 + shoulder, y: 129))
        p.addLine(to: CGPoint(x: 100 + waist + 5, y: hem))
        p.addLine(to: CGPoint(x: 100 - waist - 5, y: hem))
        p.closeSubpath()
        return p
    }

    private func drawTop(_ ctx: inout GraphicsContext) {
        let crossed = pose == .crossed
        if !crossed {
            drawArm(&ctx, left: true)
            drawArm(&ctx, left: false)
        }
        let c = topColor
        switch config.top {
        case "dress":
            var p = torso(hem: 236)
            p.move(to: CGPoint(x: 100 - waist - 5, y: 232))
            p.addLine(to: CGPoint(x: 100 + waist + 5, y: 232))
            p.addLine(to: CGPoint(x: 100 + hip + 20, y: 312))
            p.addQuadCurve(to: CGPoint(x: 100 - hip - 20, y: 312), control: CGPoint(x: 100, y: 320))
            p.closeSubpath()
            paint(&ctx, p, c)
        case "tank":
            paint(&ctx, torso(), c)
        case "hoodie":
            // Hood behind the neck, pocket and strings.
            paint(&ctx, ellipse(CGPoint(x: 100, y: 128), 30, 12), c.opacity(0.95))
            paint(&ctx, torso(hem: 240), c)
            var pocket = Path()
            pocket.move(to: CGPoint(x: 78, y: 214)); pocket.addLine(to: CGPoint(x: 122, y: 214))
            pocket.addLine(to: CGPoint(x: 128, y: 236)); pocket.addLine(to: CGPoint(x: 72, y: 236))
            pocket.closeSubpath()
            ctx.stroke(pocket, with: .color(line.opacity(0.6)), lineWidth: 1.3)
            var strings = Path()
            strings.move(to: CGPoint(x: 94, y: 132)); strings.addLine(to: CGPoint(x: 93, y: 156))
            strings.move(to: CGPoint(x: 106, y: 132)); strings.addLine(to: CGPoint(x: 107, y: 156))
            ctx.stroke(strings, with: .color(.white.opacity(0.85)), lineWidth: 1.6)
        case "jacket":
            paint(&ctx, torso(), Color(hex: 0xF3E6D3))
            var left = Path(), right = Path()
            left.move(to: CGPoint(x: 100 - shoulder, y: 150))
            left.addQuadCurve(to: CGPoint(x: 100 - shoulder + 16, y: 127), control: CGPoint(x: 100 - shoulder, y: 129))
            left.addLine(to: CGPoint(x: 92, y: 127)); left.addLine(to: CGPoint(x: 86, y: 236))
            left.addLine(to: CGPoint(x: 100 - waist - 5, y: 236)); left.closeSubpath()
            right.move(to: CGPoint(x: 100 + shoulder, y: 150))
            right.addQuadCurve(to: CGPoint(x: 100 + shoulder - 16, y: 127), control: CGPoint(x: 100 + shoulder, y: 129))
            right.addLine(to: CGPoint(x: 108, y: 127)); right.addLine(to: CGPoint(x: 114, y: 236))
            right.addLine(to: CGPoint(x: 100 + waist + 5, y: 236)); right.closeSubpath()
            paint(&ctx, left, c)
            paint(&ctx, right, c)
        case "sweater":
            paint(&ctx, torso(hem: 238), c)
            var rib = Path()
            for i in 0..<9 {
                let x = 100 - waist + CGFloat(i) * (waist * 2 / 8)
                rib.move(to: CGPoint(x: x, y: 228)); rib.addLine(to: CGPoint(x: x, y: 236))
            }
            ctx.stroke(rib, with: .color(line.opacity(0.35)), lineWidth: 1)
        case "tee":
            paint(&ctx, torso(), c)
        default: // zip jacket (the original look): high collar and zip
            paint(&ctx, torso(), c)
            var collar = Path()
            collar.move(to: CGPoint(x: 86, y: 128)); collar.addLine(to: CGPoint(x: 88, y: 112))
            collar.addLine(to: CGPoint(x: 112, y: 112)); collar.addLine(to: CGPoint(x: 114, y: 128))
            collar.closeSubpath()
            paint(&ctx, collar, c)
            var zip = Path()
            zip.move(to: CGPoint(x: 100, y: 114)); zip.addLine(to: CGPoint(x: 100, y: 234))
            ctx.stroke(zip, with: .color(line.opacity(0.55)), lineWidth: 1.2)
            ctx.fill(Path(roundedRect: CGRect(x: 98, y: 128, width: 4, height: 9), cornerRadius: 1.5), with: .color(.gray))
        }
        if crossed {
            drawArm(&ctx, left: true)
            drawArm(&ctx, left: false)
        }
    }

    // MARK: Head and face

    private func drawHead(_ ctx: inout GraphicsContext) {
        // Neck (under the collar for zip jackets).
        if config.top != "zip" {
            paint(&ctx, Path(roundedRect: CGRect(x: 90, y: 106, width: 20, height: 26), cornerRadius: 6), skin)
        } else {
            paint(&ctx, Path(roundedRect: CGRect(x: 91, y: 106, width: 18, height: 10), cornerRadius: 4), skin)
        }
        if !config.hasHijab {
            paint(&ctx, ellipse(CGPoint(x: hc.x - rx, y: hc.y + 4), 6, 8.5), skin)
            paint(&ctx, ellipse(CGPoint(x: hc.x + rx, y: hc.y + 4), 6, 8.5), skin)
        }
        paint(&ctx, ellipse(hc, rx, ry), skin)
        // Cheeks.
        ctx.fill(ellipse(CGPoint(x: hc.x - 18, y: hc.y + 14), 6, 3.5), with: .color(Color(hex: 0xE8826B).opacity(0.28)))
        ctx.fill(ellipse(CGPoint(x: hc.x + 18, y: hc.y + 14), 6, 3.5), with: .color(Color(hex: 0xE8826B).opacity(0.28)))
        // Nose.
        var nose = Path()
        nose.move(to: CGPoint(x: hc.x, y: hc.y + 3))
        nose.addQuadCurve(to: CGPoint(x: hc.x - 2, y: hc.y + 12), control: CGPoint(x: hc.x + 3, y: hc.y + 10))
        ctx.stroke(nose, with: .color(line.opacity(0.45)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }

    private let eyeY: CGFloat = 80
    private let eyeDX: CGFloat = 12

    private func drawEyes(_ ctx: inout GraphicsContext) {
        for s in [-1.0, 1.0] {
            let c = CGPoint(x: hc.x + CGFloat(s) * eyeDX, y: eyeY)
            switch config.eyes {
            case "smile":
                var p = Path()
                p.move(to: CGPoint(x: c.x - 4.5, y: c.y + 1))
                p.addQuadCurve(to: CGPoint(x: c.x + 4.5, y: c.y + 1), control: CGPoint(x: c.x, y: c.y - 5))
                ctx.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            case "almond":
                var p = Path()
                p.move(to: CGPoint(x: c.x - 6, y: c.y))
                p.addQuadCurve(to: CGPoint(x: c.x + 6, y: c.y), control: CGPoint(x: c.x, y: c.y - 6))
                p.addQuadCurve(to: CGPoint(x: c.x - 6, y: c.y), control: CGPoint(x: c.x, y: c.y + 5))
                ctx.fill(p, with: .color(.white))
                ctx.fill(ellipse(c, 2.6, 2.6), with: .color(line))
                ctx.stroke(p, with: .color(line), lineWidth: 1.2)
            case "wide":
                ctx.fill(ellipse(c, 5, 5.5), with: .color(.white))
                ctx.stroke(ellipse(c, 5, 5.5), with: .color(line), lineWidth: 1.2)
                ctx.fill(ellipse(CGPoint(x: c.x, y: c.y + 0.8), 3, 3.4), with: .color(line))
                ctx.fill(ellipse(CGPoint(x: c.x + 1.2, y: c.y - 0.6), 1, 1), with: .color(.white))
            case "sleepy":
                ctx.fill(ellipse(CGPoint(x: c.x, y: c.y + 1), 3, 2), with: .color(line))
                var lid = Path()
                lid.move(to: CGPoint(x: c.x - 4.5, y: c.y - 0.5)); lid.addLine(to: CGPoint(x: c.x + 4.5, y: c.y - 0.5))
                ctx.stroke(lid, with: .color(line), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            case "lashes":
                ctx.fill(ellipse(c, 3, 3.6), with: .color(line))
                var lash = Path()
                lash.move(to: CGPoint(x: c.x + CGFloat(s) * 2.5, y: c.y - 2.5))
                lash.addLine(to: CGPoint(x: c.x + CGFloat(s) * 5.5, y: c.y - 5))
                ctx.stroke(lash, with: .color(line), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            default: // dot
                ctx.fill(ellipse(c, 3, 3.6), with: .color(line))
                ctx.fill(ellipse(CGPoint(x: c.x + 1, y: c.y - 1.2), 0.9, 0.9), with: .color(.white))
            }
        }
    }

    private func drawBrows(_ ctx: inout GraphicsContext) {
        guard config.brows != "none" else { return }
        let browColor = hair.opacity(config.hasHijab ? 1 : 0.95)
        for s in [-1.0, 1.0] {
            let x = hc.x + CGFloat(s) * eyeDX
            var p = Path()
            switch config.brows {
            case "straight":
                p.move(to: CGPoint(x: x - 6, y: 71)); p.addLine(to: CGPoint(x: x + 6, y: 70.5))
            case "arched":
                p.move(to: CGPoint(x: x - 6, y: 72))
                p.addQuadCurve(to: CGPoint(x: x + 6, y: 71), control: CGPoint(x: x + CGFloat(s) * 2, y: 65))
            default:
                p.move(to: CGPoint(x: x - 6, y: 72))
                p.addQuadCurve(to: CGPoint(x: x + 6, y: 71.5), control: CGPoint(x: x, y: 68))
            }
            let w: CGFloat = config.brows == "thick" ? 3.6 : 2.2
            ctx.stroke(p, with: .color(browColor), style: StrokeStyle(lineWidth: w, lineCap: .round))
        }
    }

    private func drawMouth(_ ctx: inout GraphicsContext) {
        let y: CGFloat = 97
        var p = Path()
        switch config.mouth {
        case "grin":
            p.move(to: CGPoint(x: hc.x - 9, y: y - 1))
            p.addQuadCurve(to: CGPoint(x: hc.x + 9, y: y - 1), control: CGPoint(x: hc.x, y: y + 12))
            p.closeSubpath()
            ctx.fill(p, with: .color(.white))
            ctx.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        case "laugh":
            let o = ellipse(CGPoint(x: hc.x, y: y + 2), 6, 5)
            ctx.fill(o, with: .color(Color(hex: 0x7A2E22)))
            ctx.stroke(o, with: .color(line), lineWidth: 1.4)
        case "small":
            p.move(to: CGPoint(x: hc.x - 4, y: y))
            p.addQuadCurve(to: CGPoint(x: hc.x + 4, y: y), control: CGPoint(x: hc.x, y: y + 3.5))
            ctx.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        case "neutral":
            p.move(to: CGPoint(x: hc.x - 5, y: y + 1)); p.addLine(to: CGPoint(x: hc.x + 5, y: y + 1))
            ctx.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        default: // smile
            p.move(to: CGPoint(x: hc.x - 7, y: y - 1))
            p.addQuadCurve(to: CGPoint(x: hc.x + 7, y: y - 1), control: CGPoint(x: hc.x, y: y + 6))
            ctx.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private func drawFacialHair(_ ctx: inout GraphicsContext) {
        switch config.facialHair {
        case "stubble":
            var jaw = Path()
            jaw.addLines(arc(hc, rx - 1, ry - 1, 0.05 * .pi, 0.95 * .pi))
            jaw.addQuadCurve(to: CGPoint(x: hc.x + rx - 2, y: hc.y + 4), control: CGPoint(x: hc.x, y: hc.y + 12))
            ctx.fill(jaw, with: .color(hair.opacity(0.22)))
        case "moustache":
            ctx.fill(moustache(), with: .color(hair))
        case "goatee":
            ctx.fill(moustache(), with: .color(hair))
            paint(&ctx, ellipse(CGPoint(x: hc.x, y: hc.y + 31), 7, 6), hair, shade: false)
        case "shortBeard", "fullBeard":
            let full = config.facialHair == "fullBeard"
            // Along the jaw from cheek to cheek, with a top edge that dips under the nose.
            var b = Path()
            b.addLines(arc(hc, rx + (full ? 2 : 0), ry + (full ? 4 : 1), 0.08 * .pi, 0.92 * .pi))
            b.addQuadCurve(to: CGPoint(x: hc.x + (rx + (full ? 2 : 0)) * cos(0.08 * CGFloat.pi),
                                       y: hc.y + (ry + (full ? 4 : 1)) * sin(0.08 * CGFloat.pi)),
                           control: CGPoint(x: hc.x, y: hc.y + (full ? 20 : 26)))
            b.closeSubpath()
            ctx.fill(b, with: .color(hair))
            ctx.stroke(b, with: .color(line), lineWidth: 1.2)
            ctx.fill(moustache(), with: .color(hair))
            // Keep the mouth visible on top of the beard.
            drawMouth(&ctx)
        default:
            break
        }
    }

    private func moustache() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: hc.x - 11, y: 95))
        p.addQuadCurve(to: CGPoint(x: hc.x, y: 90), control: CGPoint(x: hc.x - 6, y: 88))
        p.addQuadCurve(to: CGPoint(x: hc.x + 11, y: 95), control: CGPoint(x: hc.x + 6, y: 88))
        p.addQuadCurve(to: CGPoint(x: hc.x - 11, y: 95), control: CGPoint(x: hc.x, y: 93))
        return p
    }

    // MARK: Hair

    /// The top of the head down to `hairline` (a cap), slightly bigger than the head by `e`.
    private func cap(e: CGFloat, down: CGFloat = 0.1, hairline: CGFloat = 60, dip: CGFloat = 4, sweep: CGFloat = 0) -> Path {
        var p = Path()
        let pts = arc(hc, rx + e, ry + e, .pi + down * .pi, 2 * .pi - down * .pi)
        p.addLines(pts)
        if let last = pts.last, let first = pts.first {
            p.addLine(to: CGPoint(x: last.x - 2, y: max(last.y, hairline)))
            p.addQuadCurve(to: CGPoint(x: first.x + 2, y: max(first.y, hairline + sweep)),
                           control: CGPoint(x: hc.x + sweep * 2, y: hairline + dip))
        }
        p.closeSubpath()
        return p
    }

    /// Long hair behind the head and shoulders down to `bottom`.
    private func longBack(bottom: CGFloat, width: CGFloat = 8, wavy: Bool = false) -> Path {
        var p = Path()
        let top = arc(hc, rx + width, ry + width, .pi, 2 * .pi)
        p.addLines(top)
        let right = CGPoint(x: hc.x + rx + width, y: bottom)
        let left = CGPoint(x: hc.x - rx - width, y: bottom)
        if wavy {
            p.addQuadCurve(to: CGPoint(x: right.x + 4, y: (hc.y + bottom) / 2), control: CGPoint(x: right.x - 6, y: hc.y + 30))
            p.addQuadCurve(to: right, control: CGPoint(x: right.x + 10, y: bottom - 15))
        } else {
            p.addLine(to: right)
        }
        p.addQuadCurve(to: left, control: CGPoint(x: hc.x, y: bottom + 8))
        if wavy {
            p.addQuadCurve(to: CGPoint(x: left.x - 4, y: (hc.y + bottom) / 2), control: CGPoint(x: left.x - 10, y: bottom - 15))
        }
        p.closeSubpath()
        return p
    }

    private func drawHairBack(_ ctx: inout GraphicsContext) {
        switch config.hairStyle {
        case "afro":
            paint(&ctx, curls(arc(CGPoint(x: 100, y: 70), 46, 44, 0, 2 * .pi, n: 22), r: 14), hair)
            paint(&ctx, ellipse(CGPoint(x: 100, y: 70), 50, 48), hair, stroke: false)
        case "coily":
            paint(&ctx, curls(arc(CGPoint(x: 100, y: 68), 38, 36, 0.85 * .pi, 2.15 * .pi, n: 16), r: 11), hair)
        case "curlyLong":
            paint(&ctx, curls(arc(CGPoint(x: 100, y: 100), 44, 62, 0, 2 * .pi, n: 26), r: 13), hair)
        case "wavy":
            paint(&ctx, longBack(bottom: 142, width: 9, wavy: true), hair)
        case "bob":
            paint(&ctx, longBack(bottom: 112, width: 8), hair)
        case "longStraight", "longFringe":
            paint(&ctx, longBack(bottom: 200, width: 7), hair)
        case "locs":
            var p = Path()
            for i in 0..<9 {
                let x = 66 + CGFloat(i) * 8.5
                p.addRoundedRect(in: CGRect(x: x, y: 50, width: 7, height: 125 - abs(CGFloat(i) - 4) * 6),
                                 cornerSize: CGSize(width: 3.5, height: 3.5))
            }
            paint(&ctx, p, hair)
        case "ponytail":
            var p = Path()
            p.move(to: CGPoint(x: 124, y: 52))
            p.addQuadCurve(to: CGPoint(x: 150, y: 150), control: CGPoint(x: 164, y: 70))
            p.addQuadCurve(to: CGPoint(x: 130, y: 70), control: CGPoint(x: 140, y: 100))
            p.closeSubpath()
            paint(&ctx, p, hair)
        case "highPonytail":
            paint(&ctx, ellipse(CGPoint(x: 100, y: 34), 11, 9), hair)
            var p = Path()
            p.move(to: CGPoint(x: 104, y: 30))
            p.addQuadCurve(to: CGPoint(x: 142, y: 140), control: CGPoint(x: 160, y: 40))
            p.addQuadCurve(to: CGPoint(x: 112, y: 38), control: CGPoint(x: 134, y: 70))
            p.closeSubpath()
            paint(&ctx, p, hair)
        case "bun":
            paint(&ctx, ellipse(CGPoint(x: 100, y: 34), 17, 15), hair)
        case "curlyBun":
            paint(&ctx, curls(arc(CGPoint(x: 100, y: 30), 14, 12, 0, 2 * .pi, n: 10), r: 9), hair)
        case "spaceBuns":
            paint(&ctx, ellipse(CGPoint(x: 72, y: 42), 13, 12), hair)
            paint(&ctx, ellipse(CGPoint(x: 128, y: 42), 13, 12), hair)
        case "manBun":
            paint(&ctx, ellipse(CGPoint(x: 100, y: 38), 11, 9), hair)
        case "mullet":
            paint(&ctx, longBack(bottom: 124, width: 5), hair)
        case "hijab":
            var p = Path()
            p.addLines(arc(hc, rx + 12, ry + 12, .pi * 0.98, 2.02 * .pi))
            p.addQuadCurve(to: CGPoint(x: 150, y: 150), control: CGPoint(x: 150, y: 120))
            p.addQuadCurve(to: CGPoint(x: 50, y: 150), control: CGPoint(x: 100, y: 170))
            p.addQuadCurve(to: CGPoint(x: hc.x - rx - 12, y: hc.y), control: CGPoint(x: 50, y: 120))
            p.closeSubpath()
            paint(&ctx, p, hair)
        default:
            // Short styles: a thin rim behind the head adds volume.
            if !["bald", "buzz", "fade", "mohawk"].contains(config.hairStyle) {
                paint(&ctx, ellipse(CGPoint(x: hc.x, y: hc.y - 4), rx + 4, ry + 3), hair, stroke: false)
            }
        }
    }

    private func drawHairFront(_ ctx: inout GraphicsContext) {
        switch config.hairStyle {
        case "bald":
            break
        case "buzz":
            ctx.fill(cap(e: 0.5, down: 0.12, hairline: 58, dip: 2), with: .color(hair.opacity(0.75)))
        case "fade":
            ctx.fill(cap(e: 0.5, down: 0.08, hairline: 64, dip: 2), with: .color(hair.opacity(0.35)))
            paint(&ctx, cap(e: 3, down: 0.22, hairline: 54, dip: 2), hair)
        case "mohawk":
            ctx.fill(cap(e: 0.5, down: 0.1, hairline: 60, dip: 2), with: .color(hair.opacity(0.3)))
            paint(&ctx, Path(roundedRect: CGRect(x: 91, y: 26, width: 18, height: 36), cornerRadius: 8), hair)
        case "short", "manBun", "mullet":
            paint(&ctx, cap(e: 4, down: 0.12, hairline: 58, dip: 8, sweep: -4), hair)
        case "sidePart":
            paint(&ctx, cap(e: 5, down: 0.1, hairline: 60, dip: -6, sweep: 8), hair)
            var part = Path()
            part.move(to: CGPoint(x: 84, y: 44)); part.addQuadCurve(to: CGPoint(x: 120, y: 58), control: CGPoint(x: 100, y: 44))
            ctx.stroke(part, with: .color(line.opacity(0.35)), lineWidth: 1.2)
        case "fringe", "longFringe", "bob":
            paint(&ctx, cap(e: 4, down: 0.06, hairline: 66, dip: 0), hair)
        case "pixie":
            paint(&ctx, cap(e: 3, down: 0.04, hairline: 64, dip: -4, sweep: 10), hair)
        case "curly", "coily", "afro", "curlyBun":
            let r: CGFloat = config.hairStyle == "curly" ? 9 : 8
            paint(&ctx, curls(arc(hc, rx + 1, ry - 2, 1.08 * .pi, 1.92 * .pi, n: 9), r: r), hair)
            ctx.fill(cap(e: 2, down: 0.1, hairline: 56, dip: 4), with: .color(hair))
        case "wavyShort":
            paint(&ctx, cap(e: 5, down: 0.08, hairline: 60, dip: 10, sweep: -6), hair)
        case "wavy", "longStraight", "curlyLong", "locs":
            paint(&ctx, cap(e: 4, down: 0.02, hairline: 58, dip: 12, sweep: 4), hair)
            if config.hairStyle != "locs" {
                // Strands framing the face.
                var l = Path()
                l.move(to: CGPoint(x: hc.x - rx - 4, y: hc.y - 10))
                l.addQuadCurve(to: CGPoint(x: hc.x - rx + 2, y: hc.y + 34), control: CGPoint(x: hc.x - rx - 8, y: hc.y + 14))
                l.addLine(to: CGPoint(x: hc.x - rx + 8, y: hc.y - 6)); l.closeSubpath()
                var r = Path()
                r.move(to: CGPoint(x: hc.x + rx + 4, y: hc.y - 10))
                r.addQuadCurve(to: CGPoint(x: hc.x + rx - 2, y: hc.y + 34), control: CGPoint(x: hc.x + rx + 8, y: hc.y + 14))
                r.addLine(to: CGPoint(x: hc.x + rx - 8, y: hc.y - 6)); r.closeSubpath()
                paint(&ctx, l, hair)
                paint(&ctx, r, hair)
            }
        case "ponytail", "highPonytail", "bun", "spaceBuns":
            paint(&ctx, cap(e: 3, down: 0.08, hairline: 56, dip: 6), hair)
        case "braids", "sideBraid":
            paint(&ctx, cap(e: 3, down: 0.06, hairline: 58, dip: 6), hair)
            let sides: [CGFloat] = config.hairStyle == "braids" ? [-1, 1] : [-1]
            for s in sides {
                var braid = Path()
                for i in 0..<7 {
                    let x = hc.x + s * (rx - 2) + s * CGFloat(i) * 1.2
                    braid.addEllipse(in: CGRect(x: x - 6.5, y: hc.y + 6 + CGFloat(i) * 13, width: 13, height: 15))
                }
                paint(&ctx, braid, hair)
            }
        case "hijab":
            // Frame around the face (even-odd: the face shows through).
            var f = Path()
            f.addEllipse(in: CGRect(x: hc.x - rx - 10, y: hc.y - ry - 10, width: (rx + 10) * 2, height: (ry + 12) * 2))
            f.addEllipse(in: CGRect(x: hc.x - rx + 5, y: hc.y - ry + 9, width: (rx - 5) * 2, height: (ry - 4) * 2))
            ctx.fill(f, with: .color(hair), style: FillStyle(eoFill: true))
            ctx.stroke(f, with: .color(line), lineWidth: lw)
        default:
            paint(&ctx, cap(e: 4, down: 0.1, hairline: 60, dip: 6), hair)
        }
    }

    // MARK: Accessories

    private func drawAccessory(_ ctx: inout GraphicsContext) {
        switch config.accessory {
        case "glasses", "sunglasses":
            let sun = config.accessory == "sunglasses"
            var frame = Path()
            for s in [-1.0, 1.0] {
                frame.addRoundedRect(in: CGRect(x: hc.x + CGFloat(s) * eyeDX - 8, y: eyeY - 6.5, width: 16, height: 13),
                                     cornerSize: CGSize(width: 5, height: 5))
            }
            if sun { ctx.fill(frame, with: .color(Color(hex: 0x1E1A18).opacity(0.88))) }
            frame.move(to: CGPoint(x: hc.x - 4, y: eyeY - 1)); frame.addLine(to: CGPoint(x: hc.x + 4, y: eyeY - 1))
            ctx.stroke(frame, with: .color(line), lineWidth: 1.8)
        case "earrings":
            guard !config.hasHijab else { return }
            for s in [-1.0, 1.0] {
                let c = CGPoint(x: hc.x + CGFloat(s) * rx, y: hc.y + 15)
                ctx.stroke(ellipse(c, 3.5, 3.5), with: .color(Color(hex: 0xE8A54B)), lineWidth: 2)
            }
        case "cap":
            var dome = Path()
            dome.addLines(arc(CGPoint(x: hc.x, y: hc.y - 6), rx + 4, ry - 2, .pi, 2 * .pi))
            dome.closeSubpath()
            paint(&ctx, dome, topColor)
            paint(&ctx, Path(roundedRect: CGRect(x: hc.x - 8, y: hc.y - 10, width: rx + 34, height: 7), cornerRadius: 3.5),
                  topColor)
        case "beanie":
            var dome = Path()
            dome.addLines(arc(CGPoint(x: hc.x, y: hc.y - 6), rx + 4, ry + 2, .pi, 2 * .pi))
            dome.closeSubpath()
            paint(&ctx, dome, topColor)
            paint(&ctx, Path(roundedRect: CGRect(x: hc.x - rx - 5, y: hc.y - 14, width: (rx + 5) * 2, height: 11),
                             cornerRadius: 4), topColor)
            paint(&ctx, ellipse(CGPoint(x: hc.x, y: hc.y - ry - 10), 6, 6), topColor)
        default:
            break
        }
    }
}
