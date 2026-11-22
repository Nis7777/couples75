import SwiftUI

/// Avatar builder (02_avatar_builder): a big live preview on a gold pedestal, then a white card with tabs
/// (Hairstyle, Skin, Hair colour, Outfit), the options and "Looks like me ›".
/// Used by A (onboarding step 2) and B (joining).
struct AvatarBuilderView: View {
    @Binding var avatar: Avatar
    var step: Int?
    var total: Int? = nil
    var back: (() -> Void)?
    var title = "Build your avatar"
    var next: () -> Void

    enum Tab: String, CaseIterable, Identifiable {
        case hairstyle, skin, hair, outfit
        var id: String { rawValue }
    }

    @State private var tab: Tab = .hairstyle

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
                        .animation(.easeInOut(duration: 0.2), value: avatar)
                        .accessibilityLabel("Your avatar preview")
                }
                .frame(maxHeight: .infinity)
                .padding(.bottom, 2)
            }
        } actions: {
            VStack(spacing: 12) {
                tabs
                Group {
                    switch tab {
                    case .hairstyle: hairstyles
                    case .skin: swatches(AvatarPalette.skin, original: original.skin, value: $avatar.skin, label: "Skin")
                    case .hair:
                        swatches(avatar.hasHijab ? AvatarPalette.hijab : AvatarPalette.hair,
                                 original: original.hair, value: $avatar.hair,
                                 label: avatar.hasHijab ? "Hijab colour" : "Hair colour")
                    case .outfit: swatches(AvatarPalette.jacket, original: original.jacket, value: $avatar.jacket, label: "Jacket")
                    }
                }
                .frame(height: 212)
                PrimaryButton("Looks like me") { next() }
            }
            .padding(14)
            .card(radius: 24)
        }
    }

    private var original: (skin: String, hair: String, jacket: String) {
        Characters.originals[avatar.characterID] ?? ("#FDBB8A", "#39281E", "#F67C66")
    }

    private func title(_ t: Tab) -> String {
        switch t {
        case .hairstyle: return "Hairstyle"
        case .skin: return "Skin"
        case .hair: return avatar.hasHijab ? "Hijab" : "Hair colour"
        case .outfit: return "Outfit"
        }
    }

    // MARK: Tabs

    /// Scrollable tab row at natural widths: on narrow phones the next tab is visibly half-cut, so it's clear
    /// there's more. The selected tab scrolls into view.
    private var tabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Tab.allCases) { t in
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
                            .padding(.horizontal, 14)
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

    // MARK: Hairstyles

    private var hairstyles: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(Characters.all, id: \.self) { id in
                let selected = avatar.characterID == id
                Button {
                    Haptics.tap()
                    var a = avatar
                    // The hijab and hair palettes differ: switching between them resets that colour.
                    if (id == "w5") != a.hasHijab { a.hair = nil }
                    a.characterID = id
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { avatar = a }
                } label: {
                    BustCircle(avatar: Avatar(characterID: id, skin: avatar.skin,
                                              hair: (id == "w5") == avatar.hasHijab ? avatar.hair : nil,
                                              jacket: avatar.jacket),
                               size: 64, ring: selected ? Color.gold : Color.cardBorder,
                               ringWidth: selected ? 3 : 1, fill: selected ? Color.peach : Color.ivory)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Hairstyle \((Characters.all.firstIndex(of: id) ?? 0) + 1)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: Swatches

    private func swatches(_ palette: [AvatarPalette.Swatch], original: String, value: Binding<String?>,
                          label: String) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
        return VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.app(14, .medium))
                .foregroundStyle(Color.textSecondary)
            LazyVGrid(columns: columns, spacing: 14) {
                swatch(hex: original, name: "Original", selected: value.wrappedValue == nil) {
                    value.wrappedValue = nil
                }
                ForEach(palette) { s in
                    swatch(hex: s.hex, name: s.name, selected: value.wrappedValue == s.hex) {
                        value.wrappedValue = s.hex
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func swatch(hex: String, name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color(hexString: hex) ?? .gray)
                        .frame(width: 42, height: 42)
                        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    Circle()
                        .stroke(selected ? Color.textPrimary : Color.clear, lineWidth: 2.5)
                        .frame(width: 52, height: 52)
                }
                .frame(width: 54, height: 54)
                Text(name)
                    .font(.app(10, .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
