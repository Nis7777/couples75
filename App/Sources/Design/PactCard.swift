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
    /// nil: the partner hasn't signed yet.
    var signedB: Date?
    var rank: Rank
    var streak: Int
    /// "0427": the membership-card number, the same forever (from the couple's ID).
    var cardNumber: String = "0001"
    /// "Daily pact", or the running challenge ("The 75").
    var mode: String = "Daily pact"
    /// When the pact was made (signed by the first partner).
    var startDate: Date = Date()
    /// The streak grid: one cell per day of the challenge, or the first / last 30 days on daily habits.
    var grid: [PactDay] = Array(repeating: .future, count: 30)
    var gridTitle: String = "Your first 30 days"
    /// This week, Sunday to Saturday (the compact card on Today).
    var week: [PactDay] = Array(repeating: .future, count: 7)

    /// FNV-1a of the couple ID, 0001…9999. Deterministic on both phones.
    static func number(for coupleID: String) -> String {
        var h: UInt32 = 2_166_136_261
        for b in coupleID.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return String(format: "%04d", Int(h % 9999) + 1)
    }
}

/// One cell of the streak grid.
enum PactDay: Equatable {
    /// Both of you completed the day.
    case done
    /// A past day that wasn't completed by both.
    case open
    case today
    case todayDone
    case future
}

enum PactCardMetrics {
    /// Fits an iPhone SE (375 pt wide) with the app's side margins.
    static let width: CGFloat = 320
    static let height: CGFloat = 262
}

/// The espresso card background (shared by the full card and Today's compact one).
struct PactCardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x4A382D), Color(hex: 0x382A22), Color(hex: 0x271C16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if UIImage(named: "card_texture") != nil {
                // White line art on black: `.screen` drops the black, so only the fine lines lighten the card.
                Image("card_texture").resizable().scaledToFill().opacity(0.28).blendMode(.screen)
            } else {
                // Two soft glows, so the card isn't flat.
                Circle().fill(Color.gold.opacity(0.35)).frame(width: 220).blur(radius: 50).offset(x: 160, y: -80)
                Circle().fill(Color.white.opacity(0.12)).frame(width: 180).blur(radius: 40).offset(x: -40, y: 140)
            }
        }
    }
}

/// The streak grid: up to 30 columns and 3 rows, drawn in one Canvas. `reveal` (0…1) fades the cells in left to
/// right. Done = caramel, today = outlined, past days you missed = faint, future = fainter.
struct PactGrid: View {
    var cells: [PactDay]
    var width: CGFloat
    var maxCell: CGFloat = 10
    var gap: CGFloat = 2
    var reveal: Double = 1
    var onDark = true

    private var rows: Int { max(1, min(3, Int(ceil(Double(cells.count) / 30)))) }
    private var cols: Int { max(1, Int(ceil(Double(cells.count) / Double(rows)))) }
    private var cell: CGFloat { min(maxCell, (width - gap * CGFloat(cols - 1)) / CGFloat(cols)) }
    var height: CGFloat { CGFloat(rows) * cell + CGFloat(rows - 1) * gap }

    var body: some View {
        Canvas { ctx, _ in
            let n = max(cells.count, 1)
            for (i, day) in cells.enumerated() {
                let r = i / cols, c = i % cols
                let rect = CGRect(x: CGFloat(c) * (cell + gap), y: CGFloat(r) * (cell + gap), width: cell, height: cell)
                let start = Double(i) / Double(n) * 0.6
                let o = seg(reveal, start, start + 0.4)
                guard o > 0 else { continue }
                let shape = Path(roundedRect: rect, cornerRadius: cell * 0.28)
                let base = onDark ? Color.white : Color.textPrimary
                switch day {
                case .done:
                    ctx.fill(shape, with: .color(Color.gold.opacity(o)))
                case .todayDone:
                    ctx.fill(shape, with: .color(Color.gold.opacity(o)))
                    ctx.stroke(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: cell * 0.32),
                               with: .color(base.opacity(0.95 * o)), lineWidth: 1.2)
                case .today:
                    ctx.fill(shape, with: .color(base.opacity(0.08 * o)))
                    ctx.stroke(Path(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6), cornerRadius: cell * 0.28),
                               with: .color(base.opacity(0.95 * o)), lineWidth: 1.2)
                case .open:
                    ctx.fill(shape, with: .color(base.opacity(0.16 * o)))
                case .future:
                    ctx.fill(shape, with: .color(base.opacity(0.08 * o)))
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// The card itself, drawn at 320 × 262 pt. Animation inputs (0…1, all 1 = the finished card):
/// `typeA` / `typeB` type an unsigned name in, `stamp` stamps the date on, `gridIn` fades the grid in,
/// `drawA` / `drawB` write each signature on, `seal` stamps the seal, `signedStamp` slams "SIGNED" on (0 = hidden).
struct PactCard: View {
    var data: PactCardData
    var drawA: Double = 1
    var drawB: Double = 1
    var seal: Double = 1
    var sheen: Double = 1      // 0…1: a light band sweeping across once
    var typeA: Double = 1
    var typeB: Double = 1
    var stamp: Double = 1
    var gridIn: Double = 1
    var signedStamp: Double = 0

    private var ink: Color { .white }
    private var pad: CGFloat { 18 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PactCardBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Brand.appName.uppercased())
                            .font(.app(17, .heavy))
                            .tracking(4)
                        Text("#\(data.cardNumber)")
                            .font(.app(11, .bold))
                            .monospacedDigit()
                            .opacity(0.6)
                    }
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
                // "Daily pact · Pact signed 23 Nov 2026": the date stamps on.
                HStack(spacing: 0) {
                    Text("\(data.mode) · ")
                    Text(dateLine)
                        .scaleEffect(1 + 0.6 * (1 - stamp), anchor: .leading)
                        .opacity(stamp)
                }
                .font(.app(11, .semibold))
                .foregroundStyle(ink.opacity(0.75))
                .lineLimit(1)
                .padding(.top, 2)
                Spacer(minLength: 6)
                HStack(alignment: .bottom, spacing: 12) {
                    person(name: data.nameA, avatar: data.avatarA, signed: data.signedA, draw: drawA, typed: typeA,
                           waiting: "Not signed yet")
                    person(name: data.nameB, avatar: data.avatarB, signed: data.signedB, draw: drawB, typed: typeB,
                           waiting: data.signedA == nil ? "Not signed yet" : "Signs when they join")
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(data.gridTitle.uppercased())
                        Spacer()
                        Text(doneText)
                    }
                    .font(.app(9.5, .bold))
                    .tracking(1)
                    .foregroundStyle(ink.opacity(0.7))
                    PactGrid(cells: data.grid, width: PactCardMetrics.width - pad * 2, reveal: gridIn)
                }
                .opacity(min(1, gridIn * 3))
                .frame(height: 40, alignment: .top)
                .padding(.top, 12)
            }
            .padding(pad)
            sealView
                .frame(width: 58, height: 58)
                .scaleEffect(0.6 + 0.4 * seal + 0.12 * bell(min(seal * 1.4, 1)))
                .opacity(seal)
                .rotationEffect(.degrees(-12 * (1 - seal)))
                .position(x: PactCardMetrics.width - 40, y: 122)
            signedStampView
                .scaleEffect(1 + 0.8 * (1 - signedStamp) - 0.08 * bell(signedStamp))
                .opacity(min(1, signedStamp * 2))
                .rotationEffect(.degrees(-14))
                .position(x: PactCardMetrics.width - 66, y: 112)
            sheenBand
        }
        .frame(width: PactCardMetrics.width, height: PactCardMetrics.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1))
        .shadow(color: Color.coral.opacity(0.28), radius: 18, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var dateLine: String {
        let d = data.startDate.formatted(.dateTime.day().month(.abbreviated).year())
        return data.signedA == nil ? "Made \(d)" : "Pact signed \(d)"
    }

    private var doneText: String {
        let n = data.grid.filter { $0 == .done || $0 == .todayDone }.count
        return "\(n) done"
    }

    private var accessibility: String {
        let b = data.signedB == nil ? "\(data.nameB) hasn't signed yet" : "signed by \(data.nameB)"
        let a = data.signedA == nil ? "\(data.nameA) hasn't signed yet" : "Signed by \(data.nameA)"
        return "\(Brand.appName) #\(data.cardNumber), \(data.mode). \(a), \(b). Rank \(data.rank.title). \(data.gridTitle), \(doneText)."
    }

    @ViewBuilder
    private var sealView: some View {
        if UIImage(named: "pact_seal") != nil {
            Image("pact_seal").resizable().scaledToFit()
        } else {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xE6D7B8), Color.gold], startPoint: .top, endPoint: .bottom))
                Circle().stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).padding(5)
                Image(systemName: "flame.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.highlight)
            }
        }
    }

    /// The "SIGNED" ink stamp (signing is an achievement: coral).
    private var signedStampView: some View {
        Text("SIGNED")
            .font(.app(17, .heavy))
            .tracking(3)
            .foregroundStyle(Color.highlight)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.highlight, lineWidth: 2.5))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.highlight.opacity(0.6), lineWidth: 1).padding(3))
            .opacity(0.92)
            .allowsHitTesting(false)
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

    /// Bust, the signature (written on left to right) or the typed name, the line and "Signed".
    private func person(name: String, avatar: Avatar?, signed: Date?, draw: Double, typed: Double,
                        waiting: String) -> some View {
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
                    // Typed in, letter by letter.
                    Text(String(name.prefix(Int((Double(name.count) * typed).rounded(.up)))))
                        .font(.app(17, .bold))
                        .foregroundStyle(ink.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(height: 30, alignment: .bottomLeading)
            // The signature line: solid once signed, dashed while waiting.
            Line()
                .stroke(ink.opacity(signed == nil ? 0.5 : 0.7),
                        style: StrokeStyle(lineWidth: 1, dash: signed == nil ? [4, 3] : []))
                .frame(height: 1)
            Text(signed == nil ? waiting : "Signed")
                .font(.app(11, .medium))
                .foregroundStyle(ink.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 108, alignment: .leading)
    }
}

/// One-shot reveal (rossark motion): the card rises and settles flat from a 16° tilt (ease-out), a sheen sweeps
/// once, the signatures write themselves on, then the seal stamps (and, when signing, "SIGNED" slams on).
/// Final frame = the whole card; Reduce Motion shows it straight away.
/// `signA` / `signB` choose which signatures are written during the reveal.
struct PactCardReveal: View {
    var data: PactCardData
    var signA = true
    var signB = false
    /// Hold to sign: end on the "SIGNED" stamp.
    var stampSigned = false
    @State private var play = false

    private enum Beat {
        static let rise: (Double, Double) = (0, 700)
        static let sheen: (Double, Double) = (450, 1350)
        static let signA: (Double, Double) = (700, 1500)
        static let signB: (Double, Double) = (1300, 2100)
        static let seal: (Double, Double) = (2000, 2450)
        static let stamp: (Double, Double) = (2550, 2850)
        static let total: Double = 2500
        static let totalStamped: Double = 2950
    }

    var body: some View {
        OneShotClock(duration: stampSigned ? Beat.totalStamped : Beat.total, play: play) { t in
            let rise = seg(t, Beat.rise.0, Beat.rise.1)
            PactCard(data: data,
                     drawA: signA ? seg(t, Beat.signA.0, Beat.signA.1, easeOut: false) : 1,
                     drawB: signB ? seg(t, Beat.signB.0, Beat.signB.1, easeOut: false) : 1,
                     seal: seg(t, Beat.seal.0, Beat.seal.1),
                     sheen: seg(t, Beat.sheen.0, Beat.sheen.1, easeOut: false),
                     signedStamp: stampSigned ? seg(t, Beat.stamp.0, Beat.stamp.1) : 0)
                .rotation3DEffect(.degrees(16 * (1 - rise)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .scaleEffect(0.94 + 0.06 * rise)
                .offset(y: 40 * (1 - rise))
                .opacity(rise)
        }
        .frame(width: PactCardMetrics.width, height: PactCardMetrics.height)
        .onAppear {
            play = true
            guard signA || signB else { return }
            // Haptics on the beats: the signature lands, then the seal (then the stamp).
            Task { @MainActor in
                let signEnd = signB ? Beat.signB.1 : Beat.signA.1
                try? await Task.sleep(nanoseconds: UInt64(signEnd * 1_000_000))
                Haptics.light()
                try? await Task.sleep(nanoseconds: UInt64((Beat.seal.1 - signEnd) * 1_000_000))
                Haptics.success()
                guard stampSigned else { return }
                try? await Task.sleep(nanoseconds: UInt64((Beat.stamp.1 - Beat.seal.1) * 1_000_000))
                Haptics.tap()
            }
        }
    }
}

/// Today's header: the compact Pact Card. Names with the card number and mode; rank and streak; both busts either
/// side of today's ring ("2/8": habits both of you have done today, out of all of them); one status line
/// ("Warm-up · Day 1 starts tomorrow", "Day 12", "Day 12 of 21 · 1 save left"). `trailing` sits at the end of the
/// top row (Today's "…" menu). Tapping the card is handled by the caller (it opens the full card).
struct PactCardCompact<Trailing: View>: View {
    var data: PactCardData
    var done: Int
    var total: Int
    var status: String
    var shields: Int = 0
    @ViewBuilder var trailing: Trailing

    private var progress: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(data.nameA) & \(data.nameB)")
                        .font(.app(20, .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(Brand.appName) #\(data.cardNumber) · \(data.mode)")
                        .font(.app(11, .semibold))
                        .opacity(0.7)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    RankBadge(rank: data.rank, size: 26)
                    LivingFlame(size: 16, lit: data.streak > 0)
                    Text("\(data.streak)")
                        .font(.app(17, .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if shields > 0 {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.sageLight)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(data.rank.title), \(data.streak)-day streak\(shields > 0 ? ", \(shields) streak shield\(shields == 1 ? "" : "s")" : "")")
                trailing
            }
            .foregroundStyle(Color.white)
            HStack(spacing: 0) {
                BustCircle(avatar: data.avatarA, size: 72, ring: .white, ringWidth: 2, fill: Color.white.opacity(0.92))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                ring
                Spacer(minLength: 8)
                BustCircle(avatar: data.avatarB, size: 72, ring: .white, ringWidth: 2, fill: Color.white.opacity(0.92))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 6)
            Text(status)
                .font(.app(13, .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(PactCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.gold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(done)/\(total)")
                    .font(.app(24, .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Color.white)
                Text("today")
                    .font(.app(10, .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .frame(width: 88, height: 88)
        .animation(.open(0.6), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today: \(done) of \(total) habits done between you")
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
            Text("Your rank, streak and grid update as you go.")
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
