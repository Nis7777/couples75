import SwiftUI
import UIKit

// Section 1.2 components.

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Full width, 58pt capsule, coral, white 18pt semibold label ending in " ›".
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
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title.hasSuffix("›") ? title : "\(title) ›")
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(Color.coral.opacity(isEnabled ? 1 : 0.4)))
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title.replacingOccurrences(of: " ›", with: ""))
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
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(Color.buttonBorder, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .underline(false)
                .padding(.vertical, 8)
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 72pt radio card. Selected: peach fill, 1.5pt coral border, filled coral check circle on the left.
struct OptionCard<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var isSelected: Bool
    var trailing: Trailing
    var action: () -> Void

    init(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
        } label: {
            HStack(spacing: 14) {
                CheckCircle(isOn: isSelected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.peach : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.coral : Color.cardBorder, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

extension OptionCard where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, isSelected: isSelected, action: action) { EmptyView() }
    }
}

struct CheckCircle: View {
    var isOn: Bool
    var color: Color = .coral
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .stroke(isOn ? color : Color.buttonBorder, lineWidth: 1.5)
                .background(Circle().fill(isOn ? color : Color.white))
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 6pt gold progress bar and "Step X of N".
struct OnboardingHeader: View {
    var step: Int
    var total: Int

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.peach)
                    Capsule().fill(Color.gold)
                        .frame(width: geo.size.width * CGFloat(step) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 6)
            Text("Step \(step) of \(total)")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(total)")
    }
}

struct CardBackground: ViewModifier {
    var fill: Color = .card
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
    }
}

extension View {
    func card(fill: Color = .card, radius: CGFloat = 20) -> some View {
        modifier(CardBackground(fill: fill, radius: radius))
    }

    func screenBackground() -> some View {
        background(Color.ivory.ignoresSafeArea())
    }
}

struct Pill: View {
    var text: String
    var fill: Color
    var foreground: Color = .white

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(fill))
    }
}

struct SmallLabel: View {
    var text: String
    var color: Color = .coral

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

struct TitleText: View {
    var text: String
    var size: CGFloat = 30

    init(_ text: String, size: CGFloat = 30) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(.rounded(size))
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct BodyText: View {
    var text: String
    var alignment: TextAlignment = .center

    init(_ text: String, alignment: TextAlignment = .center) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A coral banner (evening warning, frozen run, ...).
struct Banner: View {
    var text: String
    var fill: Color = .coral
    var foreground: Color = .white
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let icon { Image(systemName: icon) }
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(foreground)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
        .accessibilityElement(children: .combine)
    }
}

/// A close (×) button for full-screen sheets.
struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
        }
        .accessibilityLabel("Close")
    }
}

/// Bottom-pinned action area used by most onboarding screens.
struct BottomActions<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 10) { content }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .padding(.top, 8)
    }
}
