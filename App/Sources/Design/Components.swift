import SwiftUI
import UIKit

// Section 1.2 components, styled after the mockups in reference/.

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

enum Metrics {
    static let side: CGFloat = 20
    static let buttonHeight: CGFloat = 58
    static let cardRadius: CGFloat = 20
    static let optionRadius: CGFloat = 18
}

// MARK: - Background

/// Ivory with a very soft peach glow.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.ivory
            RadialGradient(colors: [Color.peach.opacity(0.55), Color.ivory.opacity(0)],
                           center: UnitPoint(x: 0.5, y: 0.28), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color.peach.opacity(0.35), Color.ivory.opacity(0)],
                           center: UnitPoint(x: 0.9, y: 1.0), startRadius: 10, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Buttons

/// Full width, 58pt coral capsule, white 18pt semibold label ending in " ›".
struct PrimaryButton: View {
    var title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    init(_ title: String, isEnabled: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            PrimaryButtonLabel(title: title, isEnabled: isEnabled, isLoading: isLoading)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title.replacingOccurrences(of: " ›", with: ""))
    }
}

/// The look of the primary button (also used inside ShareLink labels).
struct PrimaryButtonLabel: View {
    var title: String
    var isEnabled = true
    var isLoading = false

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                Text(title.hasSuffix("›") ? title : "\(title) ›")
                    .font(.app(18, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.buttonHeight)
        .background(Capsule().fill(Color.coral.opacity(isEnabled ? 1 : 0.45)))
        .contentShape(Capsule())
    }
}

/// White capsule, 1pt border, primary text.
struct SecondaryButton: View {
    var title: String
    var action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            SecondaryButtonLabel(title: title)
        }
        .buttonStyle(PressableStyle())
    }
}

struct SecondaryButtonLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.app(18, .semibold))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().stroke(Color.buttonBorder, lineWidth: 1))
            .contentShape(Capsule())
    }
}

/// Quiet text button.
struct TextLinkButton: View {
    var title: String
    var color: Color = .textSecondary
    var action: () -> Void

    init(_ title: String, color: Color = .textSecondary, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.app(15, .medium))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .frame(minHeight: 36)
        }
    }
}

/// Fires only on a real tap: a swipe or drag across the card never triggers it (no swipe-to-advance).
/// Keeps Button semantics for VoiceOver.
struct TapOnlyStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TapOnlyBody(configuration: configuration)
    }

    private struct TapOnlyBody: View {
        var configuration: PrimitiveButtonStyleConfiguration
        @GestureState private var pressed = false

        var body: some View {
            configuration.label
                .scaleEffect(pressed ? 0.97 : 1)
                .opacity(pressed ? 0.92 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
                .onTapGesture { configuration.trigger() }
                .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { v, state, _ in
                    state = abs(v.translation.width) < 10 && abs(v.translation.height) < 10
                })
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Option card

/// White card, 1pt border, radius 18, 64–72pt tall. Selected: peach fill, 1.5pt coral border,
/// filled coral check circle on the left.
struct OptionCard<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var isSelected: Bool
    var minHeight: CGFloat = 68
    /// Grow to fill the height offered (04's tall cards).
    var expands = false
    var trailing: Trailing
    var action: () -> Void

    func expanding() -> OptionCard {
        var copy = self
        copy.expands = true
        return copy
    }

    init(title: String, subtitle: String? = nil, isSelected: Bool, minHeight: CGFloat = 68,
         action: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.minHeight = minHeight
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
        } label: {
            HStack(spacing: 14) {
                CheckCircle(isOn: isSelected, size: 26)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 10) {
                        Text(title)
                            .font(.app(18, .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        trailing
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.app(14))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: expands ? .infinity : nil, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.optionRadius, style: .continuous)
                .fill(isSelected ? Color.peach : Color.white))
            .overlay(RoundedRectangle(cornerRadius: Metrics.optionRadius, style: .continuous)
                .stroke(isSelected ? Color.coral : Color.cardBorder, lineWidth: isSelected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.optionRadius, style: .continuous))
        }
        .buttonStyle(TapOnlyStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

extension OptionCard where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, isSelected: Bool, minHeight: CGFloat = 68,
         action: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, isSelected: isSelected, minHeight: minHeight,
                  action: action) { EmptyView() }
    }
}

/// Filled coral circle with a white check; an empty peach ring when off.
struct CheckCircle: View {
    var isOn: Bool
    var color: Color = .coral
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(color)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                Circle().fill(Color.white)
                Circle().stroke(Color.radio, lineWidth: 1.8)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
        .accessibilityHidden(true)
    }
}

// MARK: - Onboarding header

/// 6pt gold bar on a light peach track, "Step X of N" under it.
struct OnboardingHeader: View {
    var step: Int
    var total: Int

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track)
                    Capsule().fill(Color.gold)
                        .frame(width: max(6, geo.size.width * CGFloat(step) / CGFloat(max(total, 1))))
                }
            }
            .frame(height: 6)
            Text("Step \(step) of \(total)")
                .font(.app(14, .medium))
                .foregroundStyle(Color.textPrimary)
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(total)")
    }
}

// MARK: - Cards

/// White, radius 20, faint border and a soft shadow.
struct CardBackground: ViewModifier {
    var fill: Color = .card
    var radius: CGFloat = Metrics.cardRadius
    var shadow = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(color: .black.opacity(shadow ? 0.05 : 0), radius: 12, y: 4)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
    }
}

extension View {
    func card(fill: Color = .card, radius: CGFloat = Metrics.cardRadius, shadow: Bool = true) -> some View {
        modifier(CardBackground(fill: fill, radius: radius, shadow: shadow))
    }

    /// Peach box with a thin coral border (warm-up banner, bet box, saves card).
    func peachBox(radius: CGFloat = 16) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.peach))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.coral.opacity(0.55), lineWidth: 1))
    }

    func screenBackground() -> some View {
        background(AppBackground())
    }
}

// MARK: - Text

struct Pill: View {
    var text: String
    var fill: Color
    var foreground: Color = .white
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.app(size, .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, size * 0.9)
            .padding(.vertical, size * 0.42)
            .background(Capsule().fill(fill))
    }
}

/// Small coral label above a title ("You're in", "Round over", "Pause request").
struct SmallLabel: View {
    var text: String
    var color: Color = .coral

    var body: some View {
        Text(text)
            .font(.app(15, .semibold))
            .foregroundStyle(color)
    }
}

struct TitleText: View {
    var text: String
    var size: CGFloat = 28
    var alignment: TextAlignment = .center

    init(_ text: String, size: CGFloat = 28, alignment: TextAlignment = .center) {
        self.text = text
        self.size = size
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.app(size, .bold))
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(alignment)
            .lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
            .accessibilityAddTraits(.isHeader)
    }
}

struct BodyText: View {
    var text: String
    var alignment: TextAlignment = .center
    var size: CGFloat = 16

    init(_ text: String, alignment: TextAlignment = .center, size: CGFloat = 16) {
        self.text = text
        self.alignment = alignment
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(.app(size))
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(alignment)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A coloured banner (evening warning, frozen run, ...).
struct Banner: View {
    var text: String
    var fill: Color = .coral
    var foreground: Color = .white
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
            Text(text)
                .font(.app(15, .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(fill == .peach ? Color.coral.opacity(0.55) : .clear, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// A plain × (top-left of sheets and full-screen pages).
struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Close")
    }
}

/// Bottom-pinned action area: 20pt side margins and space below.
struct BottomActions<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) { content }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 16)
            .padding(.top, 10)
    }
}

/// A large SF Symbol on a soft peach disc (notification priming, Android, iCloud, honour tap).
struct IconBadge: View {
    var systemName: String
    var color: Color = .coral
    var size: CGFloat = 132

    var body: some View {
        ZStack {
            Circle().fill(Color.peach)
            Circle().fill(Color.white.opacity(0.55)).padding(size * 0.14)
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Single-answer questions move on by themselves about 0.3 s after a tap (after the selection animation).
@MainActor
/// Pending auto-advances. Any navigation (forward or back) bumps the generation, so a tap made just before
/// leaving a step can never push a later step forward on its own.
@MainActor
enum AutoAdvanceGate {
    static var generation = 0
    static func cancelPending() { generation += 1 }
}

/// Single-answer steps move on ~0.3 s after a tap (never on their own, never twice).
@MainActor
func autoAdvance(_ next: @escaping () -> Void) {
    AutoAdvanceGate.generation += 1
    let mine = AutoAdvanceGate.generation
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard AutoAdvanceGate.generation == mine else { return }
        AutoAdvanceGate.generation += 1
        next()
    }
}
