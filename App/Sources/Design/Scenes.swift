import SwiftUI

/// Who appears in a scene.
struct SceneCharacter: Equatable {
    var characterID: String
    var name: String
}

/// Two single-person images composed side by side: A on the left, slightly overlapping,
/// bottoms aligned, scaled to the available height (never cropped at the head).
/// `right == nil` shows the dashed partner outline.
struct CoupleScene: View {
    var left: SceneCharacter
    var right: SceneCharacter?
    var leftPose: CharacterPose = .stand
    var rightPose: CharacterPose = .stand

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let figureWidth = min(h * 0.46, geo.size.width * 0.52)
            HStack(alignment: .bottom, spacing: -figureWidth * 0.14) {
                CharacterImage(characterID: left.characterID, pose: leftPose, initial: left.name)
                    .frame(width: figureWidth, height: h, alignment: .bottom)
                    .zIndex(1)
                Group {
                    if let right {
                        CharacterImage(characterID: right.characterID, pose: rightPose, initial: right.name)
                    } else {
                        PartnerOutlineImage()
                    }
                }
                .frame(width: figureWidth, height: h, alignment: .bottom)
            }
            .frame(width: geo.size.width, height: h, alignment: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(right.map { "\(left.name) and \($0.name)" } ?? "\(left.name) and a partner who hasn't joined yet")
    }
}

/// Gold circular ring with "DAY n / 75" and the two characters overlapping it.
struct DayRing: View {
    var day: Int?
    var total: Int = Brand.roundLengthDays
    var caption: String?
    var lineWidth: CGFloat = 14

    var progress: Double { Double(day ?? 0) / Double(total) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.peach, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Color.gold, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                if let day {
                    Text("DAY \(day)")
                        .font(.rounded(26, .heavy))
                        .foregroundStyle(Color.textPrimary)
                    Text("/ \(total)")
                        .font(.rounded(15, .semibold))
                        .foregroundStyle(Color.textSecondary)
                } else if let caption {
                    Text(caption)
                        .font(.rounded(16, .bold))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(lineWidth * 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.map { "Day \($0) of \(total)" } ?? (caption ?? "Not started"))
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// The ring scene (15_today / 11_plan_reveal): a ring behind and above, both characters in front.
struct RingScene: View {
    var left: SceneCharacter
    var right: SceneCharacter?
    var day: Int?
    var caption: String?
    var leftPose: CharacterPose = .stand
    var rightPose: CharacterPose = .stand

    var body: some View {
        GeometryReader { geo in
            let ringSize = min(geo.size.width * 0.62, geo.size.height * 0.62)
            ZStack(alignment: .top) {
                DayRing(day: day, caption: caption, lineWidth: max(8, ringSize * 0.07))
                    .frame(width: ringSize, height: ringSize)
                    .offset(y: 0)
                CoupleScene(left: left, right: right, leftPose: leftPose, rightPose: rightPose)
                    .frame(height: geo.size.height * 0.78)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .accessibilityHidden(true)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Simple confetti burst for Day 75.
struct ConfettiView: View {
    @State private var animate = false
    private let pieces: [ConfettiPiece] = (0..<70).map { _ in ConfettiPiece() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.8)
                        .rotationEffect(.degrees(animate ? p.spin : 0))
                        .position(x: p.x * geo.size.width,
                                  y: animate ? geo.size.height + 40 : -40 - p.delay * 300)
                        .animation(.easeIn(duration: 2.4 + p.delay * 1.5).delay(p.delay), value: animate)
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
    let x = Double.random(in: 0...1)
    let delay = Double.random(in: 0...0.8)
    let size = CGFloat.random(in: 6...11)
    let spin = Double.random(in: 180...720)
    let color = [Color.coral, Color.gold, Color.sage, Color.peach].randomElement() ?? Color.gold
}

/// Floating tab bar (not the system bar): Today, Progress, Profile.
enum MainTab: String, CaseIterable, Identifiable {
    case today, progress, profile
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .progress: return "circle.grid.2x2"
        case .profile: return "person"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack {
            ForEach(MainTab.allCases) { tab in
                Button {
                    Haptics.tap()
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? tab.icon + ".fill" : tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.title).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.coral : Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white)
            .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6))
        .padding(.horizontal, 20)
    }
}
