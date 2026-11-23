import SwiftUI
import UIKit

// Living pieces built on Motion.swift (the rossark motion method): calm, small amplitudes, no teleporting,
// frozen at frame 0 with Reduce Motion, paused when off screen. Every number sits in `MotionTokens`.

enum MotionTokens {
    // Breathing couple: each person rises 1.5 pt (in the hero's points) on their own period, out of phase.
    static let breathePeriodA: Double = 3600
    static let breathePeriodB: Double = 4100
    static let breatheLift: CGFloat = 1.6
    static let breatheSway: Double = 0.6          // degrees, around the feet
    // Flame: lean 3° and stretch 5% on two waves (700 / 1100 ms); the inner flame on a third (900 ms).
    static let flameLean: Double = 3
    static let flameStretch: Double = 0.05
    static let flamePeriod1: Double = 700
    static let flamePeriod2: Double = 1100
    static let flamePeriod3: Double = 900
    // XP bar: grows with ease-out.
    static let xpGrow: Double = 0.9
}

// MARK: - Custom art with a fallback

/// A custom image from the asset catalogue (made from docs/IMAGE_PROMPTS.md) when it's there, else an SF Symbol.
/// Dropping a PNG named `asset` into Assets.xcassets is all it takes to replace a symbol.
struct CustomIcon: View {
    var asset: String
    var symbol: String
    var size: CGFloat
    var color: Color = .coral
    /// The symbol fallback sits on a peach circle (the custom art draws its own circle).
    var circled = false

    var body: some View {
        if UIImage(named: asset) != nil {
            // The art has ~12% padding of its own: scale it up a little so it fills the same space as a symbol.
            Image(asset).resizable().scaledToFit()
                .scaleEffect(circled ? 1.18 : 1.1)
                .frame(width: size, height: size)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * (circled ? 0.5 : 0.62), weight: .semibold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Circle().fill(circled ? Color.peach : Color.clear))
        }
    }
}

// MARK: - Visibility

/// Tracks whether a view is on screen, so its clock can pause (nothing runs unseen).
private struct OnScreen: ViewModifier {
    @Binding var visible: Bool
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .onAppear { visible = true }
            .onDisappear { visible = false }
            .onChange(of: phase) { _, p in visible = p == .active }
    }
}

extension View {
    func tracksVisibility(_ visible: Binding<Bool>) -> some View { modifier(OnScreen(visible: visible)) }
}

// MARK: - Breathing

/// Idle life for a standing character: a slow rise and a tiny sway around the feet. One clock per person.
struct Breathing: ViewModifier {
    var period: Double
    var phase: Double = 0
    @State private var visible = false

    func body(content: Content) -> some View {
        LoopClock(period: period * 2, paused: !visible) { t in
            let breath = (wave(t, period: period, phase: phase) + 1) / 2
            content
                .offset(y: -MotionTokens.breatheLift * breath)
                .rotationEffect(.degrees(MotionTokens.breatheSway * wave(t, period: period * 2, phase: phase + 0.25)),
                                anchor: .bottom)
        }
        .tracksVisibility($visible)
    }
}

extension View {
    @ViewBuilder
    func breathing(_ on: Bool, period: Double, phase: Double = 0) -> some View {
        if on { modifier(Breathing(period: period, phase: phase)) } else { self }
    }
}

// MARK: - Streak flame

/// The streak flame: leans and stretches from its base on two waves, the inner flame on a third.
/// Unlit (no streak): a still, grey flame. A custom `icon_flame` image replaces the drawn one.
struct LivingFlame: View {
    var size: CGFloat = 18
    var lit = true
    @State private var visible = false

    var body: some View {
        LoopClock(period: 7700, paused: !visible || !lit) { t in
            let lean = MotionTokens.flameLean * (0.6 * wave(t, period: MotionTokens.flamePeriod1)
                                                 + 0.4 * wave(t, period: MotionTokens.flamePeriod2, phase: 0.3))
            let stretch = 1 + MotionTokens.flameStretch * (wave(t, period: MotionTokens.flamePeriod2) + 1) / 2
            let inner = 1 + 0.08 * (wave(t, period: MotionTokens.flamePeriod3, phase: 0.5) + 1) / 2
            ZStack(alignment: .bottom) {
                if UIImage(named: "icon_flame") != nil {
                    Image("icon_flame").resizable().scaledToFit()
                        .saturation(lit ? 1 : 0).opacity(lit ? 1 : 0.5)
                } else {
                    Image(systemName: "flame.fill")
                        .resizable().scaledToFit()
                        .foregroundStyle(lit ? LinearGradient(colors: [Color(hex: 0xF2A03D), Color.coral],
                                                              startPoint: .top, endPoint: .bottom)
                                             : LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                    if lit {
                        Image(systemName: "flame.fill")
                            .resizable().scaledToFit()
                            .foregroundStyle(Color(hex: 0xFFE08A))
                            .frame(width: size * 0.45, height: size * 0.5)
                            .scaleEffect(x: 1, y: inner, anchor: .bottom)
                            .padding(.bottom, size * 0.04)
                    }
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(x: 1 / pow(stretch, 0.6), y: stretch, anchor: .bottom)
            .rotationEffect(.degrees(lit ? lean : 0), anchor: .bottom)
        }
        .frame(width: size, height: size)
        .tracksVisibility($visible)
        .accessibilityHidden(true)
    }
}

// MARK: - Rank badge and XP bar

struct RankBadge: View {
    var rank: Rank
    var size: CGFloat = 44

    var body: some View {
        if UIImage(named: rank.asset) != nil {
            Image(rank.asset).resizable().scaledToFit().frame(width: size, height: size)
                .accessibilityLabel("Rank \(rank.title)")
        } else {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xF6D58E), Color.gold], startPoint: .top, endPoint: .bottom))
                Circle().stroke(Color.white.opacity(0.8), lineWidth: max(1.5, size * 0.05)).padding(size * 0.08)
                Image(systemName: rank.icon)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color(hex: 0x7A4A12))
            }
            .frame(width: size, height: size)
            .accessibilityLabel("Rank \(rank.title)")
        }
    }
}

/// Rank, XP and a gold bar that draws on (ease-out) from the last value this phone showed.
struct XPCard: View {
    var xp: CoupleXP
    var compact = false
    @State private var shown: Double = UserDefaults.standard.double(forKey: "xpBarShown")

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: xp.rank, size: compact ? 38 : 46)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(xp.rank.title)
                        .font(.app(compact ? 16 : 17, .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Level \(xp.rank.level)")
                        .font(.app(13, .medium))
                        .foregroundStyle(Color.textSecondary)
                    Spacer(minLength: 4)
                    Text("\(xp.total) XP")
                        .font(.app(14, .bold))
                        .foregroundStyle(Color.coral)
                        .contentTransition(.numericText())
                        .animation(.open(0.5), value: xp.total)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.track)
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: 0xF6D58E), Color.gold], startPoint: .leading,
                                                 endPoint: .trailing))
                            .frame(width: max(shown > 0 ? 8 : 0, geo.size.width * shown))
                    }
                }
                .frame(height: 8)
                Text(xp.next.map { "\(xp.toNext) XP to \($0.title)" } ?? "Top rank. Legends.")
                    .font(.app(12, .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .card(radius: 18, shadow: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(xp.rank.title), level \(xp.rank.level), \(xp.total) XP"
                            + (xp.next.map { ", \(xp.toNext) to \($0.title)" } ?? ""))
        .onAppear { grow(to: xp.progress) }
        .onChange(of: xp.progress) { _, p in grow(to: p) }
    }

    private func grow(to p: Double) {
        let target = min(max(p, 0), 1)
        // A new rank starts the bar again from empty, never sliding backwards.
        if target < shown { shown = 0 }
        withAnimation(.open(MotionTokens.xpGrow).delay(0.15)) { shown = target }
        UserDefaults.standard.set(target, forKey: "xpBarShown")
    }
}

// MARK: - Celebration (rank up, challenge complete)

/// Beats of the badge reveal (ms). Outside `BadgeReveal`: generic types can't hold static stored properties.
private enum BadgeRevealBeat {
    static let rise: (Double, Double) = (0, 650)
    static let burst: (Double, Double) = (250, 1500)
    static let total: Double = 1600
}

/// One-shot: the badge rises in from 0.9 with ease-out, a ring of seeded sparkles opens around it and fades,
/// then the badge rests with a slow glow. Final frame: the badge, still. Reduce Motion: the final frame.
struct BadgeReveal<Art: View>: View {
    var size: CGFloat = 150
    @ViewBuilder var badge: Art
    @State private var play = false
    @State private var visible = false

    var body: some View {
        ZStack {
            OneShotClock(duration: BadgeRevealBeat.total, play: play) { t in
                let rise = seg(t, BadgeRevealBeat.rise.0, BadgeRevealBeat.rise.1)
                let burst = seg(t, BadgeRevealBeat.burst.0, BadgeRevealBeat.burst.1, easeOut: true)
                ZStack {
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        for i in 0..<14 {
                            let angle = Double(i) / 14 * .pi * 2 + seeded(i) * 0.4
                            let dist = size * (0.45 + 0.3 * burst) * (0.85 + 0.3 * seeded(i, salt: 1))
                            let r = (3 + 3 * seeded(i, salt: 2)) * bell(burst)
                            let p = CGPoint(x: c.x + cos(angle) * dist, y: c.y + sin(angle) * dist)
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                     with: .color(i % 2 == 0 ? Color.gold : Color.coral))
                        }
                    }
                    badge
                        .frame(width: size, height: size)
                        .scaleEffect(0.92 + 0.08 * rise)
                        .opacity(rise)
                        .offset(y: 12 * (1 - rise))
                }
            }
            // After the reveal: a slow glow behind the badge (2–5%), only while visible.
            LoopClock(period: 3200, paused: !visible) { t in
                Circle()
                    .fill(Color.gold.opacity(0.22))
                    .frame(width: size * 1.15, height: size * 1.15)
                    .scaleEffect(1 + 0.03 * wave(t, period: 3200))
            }
            .allowsHitTesting(false)
            .zIndex(-1)
        }
        .frame(width: size * 1.9, height: size * 1.9)
        .tracksVisibility($visible)
        .onAppear { play = true }
    }
}

/// Full-screen: "You're now {Rank}" for the couple.
struct RankUpView: View {
    @Environment(AppModel.self) private var model
    var rank: Rank

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 10) {
                Spacer(minLength: 20)
                SmallLabel(text: "Level \(rank.level)")
                BadgeReveal(size: 150) { RankBadge(rank: rank, size: 150) }
                TitleText("You're \(rank.title) now", size: 32)
                BodyText("\(model.nameA) & \(model.nameB), together. \(Ranks.next(after: rank).map { "Next up: \($0.title) at \($0.minXP) XP." } ?? "The top rank. Nothing left but to keep it.")")
                    .padding(.horizontal, 12)
                CoupleScene(left: model.sceneA, right: model.sceneB, leftPose: .cheer, rightPose: .cheer, crop: 0.6)
                    .frame(height: 220)
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Keep going") { model.presentedRankUp = nil }
        }
        .screenBackground()
    }
}
