import SwiftUI

// MARK: - Couple composition

/// Two single-person images composed side by side: A on the left, slightly overlapping, bottoms aligned,
/// scaled to the available height. `crop` shows only the top part of each figure (1 = full body,
/// ~0.6 = cut at the hips, like the mockups); heads are never cropped. `right == nil` shows the dashed outline.
/// `overlap` is a fraction of the pair's width; negative values leave a gap between the two.
struct CoupleScene: View {
    var left: SceneCharacter
    var right: SceneCharacter?
    var leftPose: CharacterPose = .stand
    var rightPose: CharacterPose = .stand
    var crop: CGFloat = 1
    var overlap: CGFloat = 0.06
    /// Where the pair sits when the space is bigger than it needs (bottom by default; top for 14).
    var alignment: VerticalAlignment = .bottom
    /// Show as much of the figures as the height allows (at least `crop`), so there's no empty band.
    var fillHeight = false

    private var leftAsset: String { Characters.assetName(left.characterID, leftPose) }
    private var rightAsset: String { right.map { Characters.assetName($0.characterID, rightPose) } ?? "partner_outline" }

    var body: some View {
        GeometryReader { geo in
            let aL = Characters.aspect(of: leftAsset)
            let aR = Characters.aspect(of: rightAsset)
            let byWidth = geo.size.width / ((aL + aR) * (1 - overlap))
            let c = fillHeight ? max(min(1, geo.size.height / max(byWidth, 1)), max(0.2, crop)) : max(0.2, min(1, crop))
            let full = max(1, min(geo.size.height / c, byWidth))
            HStack(alignment: .top, spacing: -(aL + aR) * full * overlap) {
                CharacterView(avatar: left.avatar, pose: leftPose)
                    .frame(width: aL * full, height: full)
                    .frame(height: full * c, alignment: .top)
                    .clipped()
                    .zIndex(1)
                Group {
                    if let right {
                        CharacterView(avatar: right.avatar, pose: rightPose)
                    } else {
                        Image("partner_outline").resizable().scaledToFit()
                    }
                }
                .frame(width: aR * full, height: full)
                .frame(height: full * c, alignment: .top)
                .clipped()
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: alignment == .top ? .top : .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(right.map { "\(left.name) and \($0.name)" } ?? "\(left.name) and a partner who hasn't joined yet")
    }
}

/// Two busts side by side, bottoms flat (05, 30).
struct CoupleBusts: View {
    var left: SceneCharacter
    var right: SceneCharacter?

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let a = Characters.aspect(of: Characters.assetName(left.characterID, .bust), fallback: 0.8)
            HStack(alignment: .bottom, spacing: -h * a * 0.16) {
                CharacterView(avatar: left.avatar, pose: .bust)
                    .frame(height: h * 0.9)
                    .zIndex(1)
                if let right {
                    CharacterView(avatar: right.avatar, pose: .bust)
                        .frame(height: h)
                } else {
                    Image("partner_outline")
                        .resizable().scaledToFit()
                        .frame(height: h * 1.6, alignment: .top)
                        .frame(height: h, alignment: .top)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: h, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Peach backdrops

/// A soft organic blob behind illustrations (01).
struct PeachBlob: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        var path = Path()
        path.move(to: p(0.06, 0.62))
        path.addCurve(to: p(0.22, 0.08), control1: p(0.0, 0.35), control2: p(0.08, 0.12))
        path.addCurve(to: p(0.62, 0.10), control1: p(0.36, 0.03), control2: p(0.50, 0.14))
        path.addCurve(to: p(0.96, 0.32), control1: p(0.76, 0.05), control2: p(0.95, 0.12))
        path.addCurve(to: p(0.94, 0.86), control1: p(0.98, 0.52), control2: p(1.0, 0.74))
        path.addCurve(to: p(0.45, 1.0), control1: p(0.86, 1.0), control2: p(0.62, 1.0))
        path.addCurve(to: p(0.06, 0.62), control1: p(0.22, 1.0), control2: p(0.10, 0.84))
        path.closeSubpath()
        return path
    }
}

/// Peach fill used for full-width illustration panels (08, 11, 15).
struct PeachPanelFill: View {
    var radius: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: [Color.peach.opacity(0.75), Color.peach],
                                 startPoint: .top, endPoint: .bottom))
    }
}

// MARK: - Ring

/// Gold progress arc on a light track.
struct RingArc: View {
    var progress: Double
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.ivory.opacity(0.9), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(Color.gold, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}

struct StatusChip: Equatable {
    var text: String
    var color: Color
}

/// The hero of Today (15) and the plan reveal (11): a peach panel, a big gold ring centred behind the couple,
/// the day between their heads, status chips across their waists and an optional speech bubble.
/// Both characters are shown head to waist and always fit inside the panel with at least `inset` margin.
struct RingHero: View {
    var left: SceneCharacter
    var right: SceneCharacter?
    var progress: Double
    var centerTitle: String
    var centerSubtitle: String?
    var topLabel: String? = nil
    var leftChip: StatusChip? = nil
    var rightChip: StatusChip? = nil
    var bubble: String? = nil
    var bubbleFromLeft = true
    var panelRadius: CGFloat = 24
    var inset: CGFloat = 16
    var leftPose: CharacterPose = .stand
    var rightPose: CharacterPose = .stand

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let labelSpace: CGFloat = topLabel == nil ? 0 : 26
            let ring = min(w - inset * 2, (h - labelSpace) * 0.86)
            let ringCenterY = labelSpace + (h - labelSpace) * 0.47
            let hasChips = leftChip != nil || rightChip != nil
            let chipHeight: CGFloat = 40
            ZStack(alignment: .topLeading) {
                PeachPanelFill(radius: panelRadius)
                if let topLabel {
                    Text(topLabel.uppercased())
                        .font(.app(13, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: w)
                        .padding(.top, 10)
                }
                RingArc(progress: progress, lineWidth: max(10, ring * 0.075))
                    .frame(width: ring, height: ring)
                    .position(x: w / 2, y: ringCenterY)
                VStack(spacing: 0) {
                    Text(centerTitle)
                        .font(.app(min(30, ring * 0.12), .bold))
                        .foregroundStyle(Color.textPrimary)
                    if let centerSubtitle {
                        Text(centerSubtitle)
                            .font(.app(min(22, ring * 0.085), .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: ring * 0.34)
                .position(x: w / 2, y: ringCenterY - ring * 0.05)
                // Head to waist, inside the panel with a margin on every side.
                CoupleScene(left: left, right: right, leftPose: leftPose, rightPose: rightPose,
                            crop: 0.56, overlap: -0.46)
                    .frame(width: w - inset * 2, height: h * 0.70)
                    .position(x: w / 2, y: h - h * 0.35)
                    .accessibilityHidden(true)
                if hasChips {
                    HStack(spacing: w * 0.1) {
                        chip(leftChip)
                        chip(rightChip)
                    }
                    .frame(width: w - inset * 2 - w * 0.08)
                    .position(x: w / 2, y: h - inset - chipHeight / 2)
                }
                if let bubble {
                    SpeechBubble(text: bubble, tailOnLeft: bubbleFromLeft)
                        .frame(maxWidth: w * 0.42)
                        .fixedSize(horizontal: false, vertical: true)
                        .position(x: bubbleFromLeft ? w * 0.27 : w * 0.73, y: labelSpace + h * 0.16)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: panelRadius, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([centerTitle, centerSubtitle].compactMap { $0 }.joined(separator: " "))
        .accessibilityValue([leftChip.map { "\(left.name): \($0.text)" }, rightChip.map { "\(right?.name ?? ""): \($0.text)" }]
            .compactMap { $0 }.joined(separator: ", "))
    }

    @ViewBuilder
    private func chip(_ c: StatusChip?) -> some View {
        if let c {
            Text(c.text)
                .font(.app(17, .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.color))
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: 40)
        }
    }
}

/// White bubble with a small tail.
struct SpeechBubble: View {
    var text: String
    var tailOnLeft = true

    var body: some View {
        Text(text)
            .font(.app(14, .medium))
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            )
            .overlay(alignment: tailOnLeft ? .bottomTrailing : .bottomLeading) {
                BubbleTail()
                    .fill(Color.white)
                    .frame(width: 14, height: 12)
                    .offset(x: tailOnLeft ? -26 : 26, y: 10)
            }
    }
}

struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Trophy

/// Both characters cheering, the trophy in front, optionally a gold ribbon and a "Day 75" ring badge (13a, 19).
struct TrophyScene: View {
    var left: SceneCharacter
    var right: SceneCharacter?
    var ribbon = true
    var badge = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .bottom) {
                CoupleScene(left: left, right: right, leftPose: .cheer, rightPose: .cheer, crop: 0.7, overlap: -0.12)
                    .frame(height: h * 0.96)
                if ribbon {
                    RibbonShape()
                        .fill(LinearGradient(colors: [Color(hex: 0xE2A03F), Color(hex: 0xF2C470), Color(hex: 0xE2A03F)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * 1.1, height: h * 0.07)
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                        .padding(.bottom, h * 0.12)
                }
                Ellipse()
                    .fill(Color.peachDeep.opacity(0.7))
                    .frame(width: w * 0.36, height: h * 0.03)
                TrophyImage()
                    .frame(width: w * 0.36, height: h * 0.38)
                    .padding(.bottom, h * 0.01)
                if badge {
                    VStack(spacing: -4) {
                        Text("Day").font(.app(h * 0.06, .semibold))
                        Text("75").font(.app(h * 0.08, .bold))
                    }
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: h * 0.24, height: h * 0.24)
                    .background(Circle().fill(Color.ivory.opacity(0.85)))
                    .overlay(Circle().stroke(Color.gold, lineWidth: max(3, h * 0.014)))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, h * 0.08)
                }
            }
            .frame(width: w, height: h)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You both cheering with a trophy")
    }
}

/// A gently curved band across the scene.
struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.25))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.25),
                       control: CGPoint(x: r.midX, y: r.minY + r.height * 0.9))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.05))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.05),
                       control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.6))
        p.closeSubpath()
        return p
    }
}

// MARK: - Confetti

/// Gold confetti for Day 75.
struct ConfettiView: View {
    @State private var animate = false
    @State private var pieces: [ConfettiPiece] = (0..<60).map { _ in ConfettiPiece() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size * 1.8, height: p.size)
                        .rotationEffect(.degrees(animate ? p.spin : p.startAngle))
                        .position(x: p.x * geo.size.width,
                                  y: animate ? geo.size.height * p.endY : -30 - p.delay * 200)
                        .animation(.easeOut(duration: 2.6 + p.delay * 1.4).delay(p.delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { animate = true }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x = Double.random(in: 0.02...0.98)
    let endY = Double.random(in: 0.08...0.98)
    let delay = Double.random(in: 0...0.7)
    let size = CGFloat.random(in: 9...15)
    let startAngle = Double.random(in: 0...90)
    let spin = Double.random(in: 120...420)
    let color = [Color(hex: 0xE8A54B), Color(hex: 0xF2C470), Color(hex: 0xD9952F), Color(hex: 0xF6D58E)]
        .randomElement() ?? Color.gold
}

// MARK: - Floating tab bar

enum MainTab: String, CaseIterable, Identifiable {
    case today, proof, progress, profile
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .proof: return "Proof"
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .proof: return "checkmark.seal"
        case .progress: return "circle.grid.2x2"
        case .profile: return "person"
        }
    }
}

/// Plain white rounded bar with a soft shadow, floating above the bottom edge; the active item is coral.
/// Proof shows a coral number badge.
struct FloatingTabBar: View {
    @Binding var selection: MainTab
    var proofBadge: Int = 0

    static let height: CGFloat = 66

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                let active = selection == tab
                Button {
                    Haptics.tap()
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: active ? tab.icon + ".fill" : tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(height: 24)
                            .overlay(alignment: .topTrailing) {
                                if tab == .proof && proofBadge > 0 {
                                    Text("\(min(proofBadge, 99))")
                                        .font(.app(11, .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 18, minHeight: 18)
                                        .background(Capsule().fill(Color.coral))
                                        .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
                                        .offset(x: 12, y: -6)
                                }
                            }
                        Text(tab.title).font(.app(12, .semibold))
                    }
                    .foregroundStyle(active ? Color.coral : Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.height)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab == .proof && proofBadge > 0 ? "Proof, \(proofBadge) to react" : tab.title)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.10), radius: 16, y: 6)
        )
        .padding(.horizontal, Metrics.side)
    }
}
