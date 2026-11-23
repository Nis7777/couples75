import SwiftUI
import UIKit

// The Pact Card: the couple's own card. Both busts, both signatures, the date you signed, your rank and streak,
// and the seal. Shown when you sign (your signature writes itself on), when your partner joins (theirs does),
// and in Profile, where you can share it. Custom art: `card_texture` (background) and `pact_seal` (the seal),
// see docs/IMAGE_PROMPTS.md; both fall back to drawn versions.

struct PactCardData: Equatable {
    var nameA: String
    var nameB: String
    var avatarA: Avatar
    /// nil: the partner hasn't built an avatar yet (dashed outline).
    var avatarB: Avatar?
    var signedA: Date?
    /// nil: the partner hasn't signed yet ("Waiting for {B}").
    var signedB: Date?
    var rank: Rank
    var streak: Int
}

extension AppModel {
    /// The card from the current couple (or, during onboarding, from the draft).
    var pactCard: PactCardData {
        let a = memberA
        let b = memberB
        return PactCardData(
            nameA: a?.name ?? (draft.myName.isEmpty ? "You" : draft.myName),
            nameB: b?.name ?? (draft.partnerName.isEmpty ? nameB : draft.partnerName),
            avatarA: sceneA.avatar,
            avatarB: sceneBBuilt?.avatar,
            signedA: facts.couple?.createdAt ?? now(),
            signedB: b?.joinedAt,
            rank: xp.rank,
            streak: state.streak)
    }
}

enum PactCardMetrics {
    /// Fits an iPhone SE (375 pt wide) with the app's side margins.
    static let width: CGFloat = 320
    static let height: CGFloat = 226
}

/// The card itself, drawn at 320 × 226 pt. `drawA` / `drawB` (0…1) write each signature on; `seal` (0…1) stamps it.
struct PactCard: View {
    var data: PactCardData
    var drawA: Double = 1
    var drawB: Double = 1
    var seal: Double = 1
    var sheen: Double = 1      // 0…1: a light band sweeping across once

    private let ink = Color.white

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text(Brand.appName.uppercased())
                        .font(.app(17, .heavy))
                        .tracking(4)
                        .foregroundStyle(ink)
                    Spacer()
                    HStack(spacing: 6) {
                        RankBadge(rank: data.rank, size: 26)
                        Text(data.rank.title)
                            .font(.app(13, .bold))
                            .foregroundStyle(ink)
                        if data.streak > 0 {
                            Text("· 🔥 \(data.streak)")
                                .font(.app(13, .bold))
                                .foregroundStyle(ink)
                        }
                    }
                }
                Spacer(minLength: 6)
                HStack(alignment: .bottom, spacing: 12) {
                    person(name: data.nameA, avatar: data.avatarA, signed: data.signedA, draw: drawA)
                    person(name: data.nameB, avatar: data.avatarB, signed: data.signedB, draw: drawB)
                }
            }
            .padding(18)
            sealView
                .frame(width: 58, height: 58)
                .scaleEffect(0.6 + 0.4 * seal + 0.12 * bell(min(seal * 1.4, 1)))
                .opacity(seal)
                .rotationEffect(.degrees(-12 * (1 - seal)))
                .position(x: PactCardMetrics.width - 40, y: PactCardMetrics.height / 2 - 6)
            sheenBand
        }
        .frame(width: PactCardMetrics.width, height: PactCardMetrics.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1))
        .shadow(color: Color.coral.opacity(0.28), radius: 18, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        let b = data.signedB == nil ? "\(data.nameB) hasn't signed yet" : "signed by \(data.nameB)"
        return "\(Brand.appName) card. Signed by \(data.nameA), \(b). Rank \(data.rank.title)."
    }

    @ViewBuilder
    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xE2603F), Color.coral, Color(hex: 0xA8331C)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if UIImage(named: "card_texture") != nil {
                // White line art on black: `.screen` drops the black, so only the fine lines lighten the card.
                Image("card_texture").resizable().scaledToFill().opacity(0.28).blendMode(.screen)
            } else {
                // Two soft gold flames' glow, so the card isn't flat.
                Circle().fill(Color.gold.opacity(0.35)).frame(width: 220).blur(radius: 50).offset(x: 160, y: -80)
                Circle().fill(Color.white.opacity(0.12)).frame(width: 180).blur(radius: 40).offset(x: -40, y: 140)
            }
        }
    }

    @ViewBuilder
    private var sealView: some View {
        if UIImage(named: "pact_seal") != nil {
            Image("pact_seal").resizable().scaledToFit()
        } else {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xF6D58E), Color.gold], startPoint: .top, endPoint: .bottom))
                Circle().stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).padding(5)
                Image(systemName: "flame.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.coral)
            }
        }
    }

    private var sheenBand: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.35), .white.opacity(0)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 90, height: geo.size.height * 1.6)
                .rotationEffect(.degrees(20))
                .offset(x: -120 + (geo.size.width + 240) * sheen, y: -geo.size.height * 0.3)
                .opacity(sheen > 0 && sheen < 1 ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    /// Bust, the signature (written on left to right), the line and the date.
    private func person(name: String, avatar: Avatar?, signed: Date?, draw: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BustCircle(avatar: avatar, size: 56, ring: .white, ringWidth: 2, fill: Color.white.opacity(0.92))
            ZStack(alignment: .leading) {
                if signed != nil {
                    Text(name)
                        .font(.custom("SnellRoundhand-Bold", size: 24))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .mask(alignment: .leading) {
                            GeometryReader { g in Rectangle().frame(width: g.size.width * draw) }
                        }
                } else {
                    Text("Waiting for \(name)")
                        .font(.app(12, .medium))
                        .foregroundStyle(ink.opacity(0.7))
                }
            }
            .frame(height: 34, alignment: .bottomLeading)
            // The signature line: solid once signed, dashed while waiting.
            Line()
                .stroke(ink.opacity(signed == nil ? 0.5 : 0.7),
                        style: StrokeStyle(lineWidth: 1, dash: signed == nil ? [4, 3] : []))
                .frame(height: 1)
            Text(signed.map { "Signed \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Not signed yet")
                .font(.app(11, .medium))
                .foregroundStyle(ink.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 108, alignment: .leading)
    }
}

/// One-shot reveal (rossark motion): the card rises and settles flat from a 16° tilt (ease-out), a sheen sweeps
/// once, the signatures write themselves on, then the seal stamps. Final frame = the whole card; Reduce Motion
/// shows it straight away. `signA` / `signB` choose which signatures are written during the reveal.
struct PactCardReveal: View {
    var data: PactCardData
    var signA = true
    var signB = false
    @State private var play = false

    private enum Beat {
        static let rise: (Double, Double) = (0, 700)
        static let sheen: (Double, Double) = (450, 1350)
        static let signA: (Double, Double) = (700, 1500)
        static let signB: (Double, Double) = (1300, 2100)
        static let seal: (Double, Double) = (2000, 2450)
        static let total: Double = 2500
    }

    var body: some View {
        OneShotClock(duration: Beat.total, play: play) { t in
            let rise = seg(t, Beat.rise.0, Beat.rise.1)
            PactCard(data: data,
                     drawA: signA ? seg(t, Beat.signA.0, Beat.signA.1, easeOut: false) : 1,
                     drawB: signB ? seg(t, Beat.signB.0, Beat.signB.1, easeOut: false) : 1,
                     seal: seg(t, Beat.seal.0, Beat.seal.1),
                     sheen: seg(t, Beat.sheen.0, Beat.sheen.1, easeOut: false))
                .rotation3DEffect(.degrees(16 * (1 - rise)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .scaleEffect(0.94 + 0.06 * rise)
                .offset(y: 40 * (1 - rise))
                .opacity(rise)
        }
        .frame(width: PactCardMetrics.width, height: PactCardMetrics.height)
        .onAppear {
            play = true
            guard signA || signB else { return }
            // Haptics on the beats: the signature lands, then the seal.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((signB ? Beat.signB.1 : Beat.signA.1) * 1_000_000))
                Haptics.light()
                try? await Task.sleep(nanoseconds: UInt64((Beat.seal.1 - (signB ? Beat.signB.1 : Beat.signA.1)) * 1_000_000))
                Haptics.success()
            }
        }
    }
}

/// Profile → "Our Pact card": the card (with a soft idle float) and Share.
struct PactCardSheet: View {
    @Environment(AppModel.self) private var model
    @State private var image: UIImage?
    @State private var visible = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Our \(Brand.appName) card")
                .font(.app(24, .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 28)
            // Idle: a slow float and a tiny tilt, out of phase (2–3 s), paused off screen.
            LoopClock(period: 6000, paused: !visible) { t in
                PactCardReveal(data: model.pactCard, signA: false, signB: false)
                    .offset(y: -3 * (wave(t, period: 3000) + 1) / 2)
                    .rotation3DEffect(.degrees(2 * wave(t, period: 6000, phase: 0.25)), axis: (x: 0, y: 1, z: 0))
            }
            .frame(height: PactCardMetrics.height + 16)
            .tracksVisibility($visible)
            Text("Signed by both of you. Your rank and streak update as you go.")
                .font(.app(14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer(minLength: 0)
            if let image {
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview("Our \(Brand.appName) card", image: Image(uiImage: image))) {
                    PrimaryButtonLabel(title: "Share our card")
                }
                .padding(.horizontal, Metrics.side)
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ivory.ignoresSafeArea())
        .onAppear { render() }
    }

    private func render() {
        let card = PactCard(data: model.pactCard)
            .padding(30)
            .background(Color.ivory)
        let r = ImageRenderer(content: card)
        r.scale = 3
        image = r.uiImage
    }
}

/// Shown once to the person who invited, when their partner joins: the partner's signature writes itself on.
struct PartnerJoinedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 14) {
                SmallLabel(text: "It's official")
                    .padding(.top, 30)
                TitleText("\(model.nameB) signed your pact", size: 30)
                PactCardReveal(data: model.pactCard, signA: false, signB: true)
                    .padding(.vertical, 12)
                BodyText("Day 1 starts tomorrow. Today is a free warm-up: try a check-in, it doesn't count.")
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
            }
        } actions: {
            PrimaryButton("Let's go") { model.dismissPartnerJoined() }
        }
        .screenBackground()
    }
}

/// A horizontal line through the middle of its frame.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
