import SwiftUI

/// Picks the builder: the layered one once its art exists, the original preset builder until then.
struct AvatarBuilderView: View {
    @Binding var avatar: Avatar
    var step: Int?
    var total: Int? = nil
    var back: (() -> Void)?
    var title = "Build your avatar"
    var next: () -> Void

    var body: some View {
        if AvatarArt.layeredEnabled {
            LayeredAvatarBuilderView(avatar: $avatar, step: step, total: total, back: back, title: title, next: next)
        } else {
            PresetAvatarBuilderView(avatar: $avatar, step: step, total: total, back: back, title: title, next: next)
        }
    }
}

/// Avatar builder (02_avatar_builder): the same screen as before (big live preview on the gold pedestal, a
/// white card with tabs, the options and "Looks like me ›"), now with a layered avatar: hair, hair colour,
/// skin, face, top, bottoms, shoes and extras are chosen independently.
/// Used by A (onboarding step 2), B on A's phone ("Hand the phone to {B}") and B when joining.
struct LayeredAvatarBuilderView: View {
    @Binding var avatar: Avatar
    var step: Int?
    var total: Int? = nil
    var back: (() -> Void)?
    var title = "Build your avatar"
    var next: () -> Void

    @State private var tab: AvatarTab = .hair
    @State private var history: [AvatarConfig] = []
    @State private var bounce = false

    /// The look being edited (a hairstyle without art shows as its closest relative that has art).
    private var config: AvatarConfig {
        var c = avatar.resolvedConfig
        c.hairStyle = AvatarArt.hairWithArt(c.hairStyle)
        return c
    }

    /// With final art, only parts that have art are offered ("none" options always are).
    private static func available(_ part: AvatarPart) -> Bool {
        guard AvatarArt.layeredEnabled else { return true }
        if part.layer == .hairFront { return AvatarArt.hairHasArt(part.id) }
        return part.id == "none" || AvatarArt.hasArt(part.layer, part.id)
    }

    private static func hasChoices(_ parts: [AvatarPart]) -> Bool { parts.filter(available).count > 1 }

    /// Tabs with something to choose. Colour tabs need tintable art (hair now; skin once the head is a shape).
    private var visibleTabs: [AvatarTab] {
        guard AvatarArt.layeredEnabled else { return AvatarTab.allCases }
        let hairTint = AvatarParts.hair.contains { p in
            [AvatarLayer.hairFront, .hairBack].contains { l in
                AvatarArt.name(l, p.id, pose: .stand).map(AvatarArt.isTintable) ?? false
            }
        }
        let skinTint = AvatarArt.name(.head, "head", pose: .stand).map(AvatarArt.isTintable) ?? false
        let bodies = AvatarBody.allCases.filter { AvatarArt.exists("avatar_body_\($0.rawValue)_stand") }.count > 1
        return AvatarTab.allCases.filter { t in
            switch t {
            case .hair: return true
            case .hairColor: return hairTint
            case .skin: return skinTint
            case .face: return bodies || [AvatarParts.eyes, AvatarParts.brows, AvatarParts.mouths,
                                          AvatarParts.facialHair].contains(where: Self.hasChoices)
            case .top: return Self.hasChoices(AvatarParts.tops)
            case .bottoms: return Self.hasChoices(AvatarParts.bottoms)
            case .shoes: return Self.hasChoices(AvatarParts.shoes)
            case .extras: return Self.hasChoices(AvatarParts.accessories)
            }
        }
    }

    var body: some View {
        OnboardingPage(step: step, total: total, back: back) {
            VStack(spacing: 6) {
                TitleText(title, size: 28)
                    .padding(.top, 12)
                ZStack(alignment: .bottom) {
                    Pedestal()
                        .frame(width: 180, height: 36)
                    CharacterView(avatar: avatar, pose: .stand)
                        .padding(.bottom, 18)
                        .scaleEffect(bounce ? 0.97 : 1, anchor: .bottom)
                        .id(config)
                        .transition(.opacity)
                        .accessibilityLabel("Your avatar preview")
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topTrailing) { previewButtons }
                .padding(.bottom, 2)
            }
        } actions: {
            VStack(spacing: 12) {
                tabs
                ScrollView(showsIndicators: false) {
                    options
                        .padding(.vertical, 6)
                }
                .frame(height: 212)
                PrimaryButton("Looks like me") {
                    avatar = Avatar(config: config)   // saves the layered config
                    next()
                }
            }
            .padding(14)
            .card(radius: 24)
        }
    }

    // MARK: Changing the config

    private func apply(_ change: (inout AvatarConfig) -> Void) {
        var c = config
        change(&c)
        guard c != config else { return }
        Haptics.light()
        history.append(config)
        if history.count > 30 { history.removeFirst() }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
            avatar = Avatar(config: c)
            bounce = true
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.08)) { bounce = false }
    }

    private var previewButtons: some View {
        VStack(spacing: 8) {
            Button {
                apply { $0 = .random() }
            } label: {
                Label("Randomize", systemImage: "dice.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.coral)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
            }
            .accessibilityLabel("Randomize avatar")
            Button {
                guard let last = history.popLast() else { return }
                Haptics.light()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) { avatar = Avatar(config: last) }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(history.isEmpty ? Color.textSecondary.opacity(0.4) : Color.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
            }
            .disabled(history.isEmpty)
            .accessibilityLabel("Undo last change")
        }
        .padding(.trailing, 4)
    }

    // MARK: Tabs

    private func title(_ t: AvatarTab) -> String {
        if t == .hairColor && config.hasHijab { return "Hijab colour" }
        return t.title
    }

    /// Scrollable tab row at natural widths: on narrow phones the next tab is visibly half-cut, so it's clear
    /// there's more. The selected tab keeps the coral underline and scrolls into view.
    private var tabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(visibleTabs) { t in
                        Button {
                            Haptics.tap()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tab = t
                                proxy.scrollTo(t, anchor: .center)
                            }
                        } label: {
                            VStack(spacing: 7) {
                                Text(title(t))
                                    .font(.app(16, tab == t ? .semibold : .medium))
                                    .foregroundStyle(tab == t ? Color.textPrimary : Color.textSecondary)
                                    .fixedSize()
                                Capsule()
                                    .fill(tab == t ? Color.coral : Color.clear)
                                    .frame(height: 3)
                            }
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(t)
                        .accessibilityAddTraits(tab == t ? .isSelected : [])
                    }
                }
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.cardBorder).frame(height: 1) }
        }
    }

    // MARK: Options

    @ViewBuilder
    private var options: some View {
        switch tab {
        case .hair:
            partGrid(AvatarParts.hair, selected: config.hairStyle, headOnly: true) { c, id in
                c.hairStyle = id
                // Hijab and hair colours come from different palettes.
                if id == "hijab", !AvatarPalette.hijab.contains(where: { $0.hex == c.hairColor }) {
                    c.hairColor = AvatarPalette.hijab[0].hex
                } else if id != "hijab", AvatarPalette.hijab.contains(where: { $0.hex == c.hairColor }),
                          !AvatarPalette.hairColors.contains(where: { $0.hex == c.hairColor }) {
                    c.hairColor = AvatarPalette.hairColors[1].hex
                }
            }
        case .hairColor:
            swatchGrid(config.hasHijab ? AvatarPalette.hijab : AvatarPalette.hairColors, selected: config.hairColor) { c, hex in
                c.hairColor = hex
            }
        case .skin:
            swatchGrid(AvatarPalette.skinTones, selected: config.skinTone) { c, hex in c.skinTone = hex }
        case .face:
            VStack(alignment: .leading, spacing: 14) {
                if Self.hasChoices(AvatarParts.eyes) {
                    section("Eyes") { partGrid(AvatarParts.eyes, selected: config.eyes, headOnly: true) { c, id in c.eyes = id } }
                }
                if Self.hasChoices(AvatarParts.brows) {
                    section("Brows") { partGrid(AvatarParts.brows, selected: config.brows, headOnly: true) { c, id in c.brows = id } }
                }
                if Self.hasChoices(AvatarParts.mouths) {
                    section("Mouth") { partGrid(AvatarParts.mouths, selected: config.mouth, headOnly: true) { c, id in c.mouth = id } }
                }
                if Self.hasChoices(AvatarParts.facialHair) {
                    section("Facial hair") {
                        partGrid(AvatarParts.facialHair, selected: config.facialHair, headOnly: true) { c, id in c.facialHair = id }
                    }
                }
                if !AvatarArt.layeredEnabled
                    || AvatarBody.allCases.filter({ AvatarArt.exists("avatar_body_\($0.rawValue)_stand") }).count > 1 {
                    section("Body shape") { bodyPicker }
                }
            }
        case .top:
            VStack(alignment: .leading, spacing: 12) {
                swatchRow(AvatarPalette.clothing, selected: config.topColor) { c, hex in c.topColor = hex }
                partGrid(AvatarParts.tops, selected: config.top, headOnly: false) { c, id in c.top = id }
            }
        case .bottoms:
            VStack(alignment: .leading, spacing: 12) {
                swatchRow(AvatarPalette.clothing, selected: config.bottomsColor) { c, hex in c.bottomsColor = hex }
                if config.top == "dress" {
                    Text("Wearing a dress. Pick another top to choose bottoms.")
                        .font(.app(13))
                        .foregroundStyle(Color.textSecondary)
                }
                partGrid(AvatarParts.bottoms, selected: config.bottoms, headOnly: false) { c, id in c.bottoms = id }
            }
        case .shoes:
            partGrid(AvatarParts.shoes, selected: config.shoes, headOnly: false) { c, id in c.shoes = id }
        case .extras:
            partGrid(AvatarParts.accessories, selected: config.accessory, headOnly: true) { c, id in c.accessory = id }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.app(14, .semibold))
                .foregroundStyle(Color.textSecondary)
            content()
        }
    }

    private var bodyPicker: some View {
        HStack(spacing: 8) {
            ForEach(AvatarBody.allCases, id: \.self) { b in
                let selected = config.body == b
                Button { apply { $0.body = b } } label: {
                    Text(b.title)
                        .font(.app(14, .semibold))
                        .foregroundStyle(selected ? Color.white : Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Capsule().fill(selected ? Color.coral : Color.white))
                        .overlay(Capsule().stroke(selected ? Color.coral : Color.cardBorder, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(b.title) body shape")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// 4 circular thumbnails per row, each showing MY avatar with that option applied.
    private func partGrid(_ all: [AvatarPart], selected: String, headOnly: Bool,
                          set: @escaping (inout AvatarConfig, String) -> Void) -> some View {
        let parts = all.filter(Self.available)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
            ForEach(parts) { part in
                let isOn = part.id == selected
                let preview: AvatarConfig = {
                    var c = config
                    set(&c, part.id)
                    return c
                }()
                Button { apply { set(&$0, part.id) } } label: {
                    VStack(spacing: 4) {
                        AvatarThumb(config: preview, headOnly: headOnly, size: 62,
                                    ring: isOn ? Color.gold : Color.cardBorder, ringWidth: isOn ? 3 : 1,
                                    fill: isOn ? Color.peach : Color.ivory)
                        Text(part.name)
                            .font(.app(10, .medium))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(part.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func swatchGrid(_ palette: [AvatarPalette.Swatch], selected: String,
                            set: @escaping (inout AvatarConfig, String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 14) {
            ForEach(palette) { s in swatch(s, selected: s.hex == selected) { apply { set(&$0, s.hex) } } }
        }
    }

    private func swatchRow(_ palette: [AvatarPalette.Swatch], selected: String,
                           set: @escaping (inout AvatarConfig, String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(palette) { s in swatch(s, selected: s.hex == selected, small: true) { apply { set(&$0, s.hex) } } }
            }
            .padding(.horizontal, 2)
        }
    }

    private func swatch(_ s: AvatarPalette.Swatch, selected: Bool, small: Bool = false,
                        action: @escaping () -> Void) -> some View {
        let d: CGFloat = small ? 32 : 42
        return Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color(hexString: s.hex) ?? .gray)
                        .frame(width: d, height: d)
                        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    Circle()
                        .stroke(selected ? Color.textPrimary : Color.clear, lineWidth: 2.5)
                        .frame(width: d + 10, height: d + 10)
                }
                .frame(width: d + 12, height: d + 12)
                if !small {
                    Text(s.name.replacingOccurrences(of: " skin", with: "").replacingOccurrences(of: " hair", with: ""))
                        .font(.app(10, .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A round thumbnail of a layered avatar, rendered once and cached (smooth scrolling in the option grids).
struct AvatarThumb: View {
    var config: AvatarConfig
    var headOnly: Bool
    var size: CGFloat
    var ring: Color = .cardBorder
    var ringWidth: CGFloat = 1
    var fill: Color = .ivory

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let img = AvatarThumbCache.shared.image(config, headOnly: headOnly, size: size) {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(width: headOnly ? size * 0.92 : size * 0.5, height: headOnly ? size * 0.92 : size * 0.96)
                    .offset(y: headOnly ? size * 0.1 : size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring, lineWidth: ringWidth))
    }
}

@MainActor
final class AvatarThumbCache {
    static let shared = AvatarThumbCache()
    private var cache: [String: UIImage] = [:]

    func image(_ config: AvatarConfig, headOnly: Bool, size: CGFloat) -> UIImage? {
        let key = "\(config.hashValue)|\(headOnly)|\(Int(size))"
        if let img = cache[key] { return img }
        let w = headOnly ? size : size * 0.5
        let h = size
        let renderer = ImageRenderer(content: LayeredAvatarView(config: config, pose: .stand, headOnly: headOnly)
            .frame(width: w, height: h))
        renderer.scale = 3
        guard let img = renderer.uiImage else { return nil }
        if cache.count > 400 { cache.removeAll() }
        cache[key] = img
        return img
    }
}

/// The gold disc the preview stands on.
struct Pedestal: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0xC98B33))
                .offset(y: 6)
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0xF0C178), Color.gold], startPoint: .top, endPoint: .bottom))
        }
        .accessibilityHidden(true)
    }
}

struct OnboardingCharacterStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        AvatarBuilderView(avatar: $model.draft.avatar, step: model.draft.stepNumber, back: back, next: next)
    }
}
