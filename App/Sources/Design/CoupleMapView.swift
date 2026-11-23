import SwiftUI

// "Your couple map": a six-axis radar, one filled shape per partner (A caramel, B sage), drawn with Canvas.
// Pure (no AppModel), so ImageRenderer can draw it into the share cards.

struct MapSeries: Equatable {
    var name: String
    var color: Color
    /// nil: this partner hasn't answered yet (a dashed outline).
    var scores: MapScores?
}

/// The chart. `draw` (0…1) grows the shapes out from the centre; `showValues` writes the whole numbers on.
struct CoupleMapChart: View {
    var series: [MapSeries]
    var size: CGFloat = 260
    var draw: Double = 1
    var showValues = false
    var labelSize: CGFloat = 12

    private var labelPad: CGFloat { labelSize * 3.4 }
    private var radius: CGFloat { size / 2 - labelPad }
    private var axes: [MapAxis] { MapAxis.allCases }

    private func angle(_ i: Int) -> Double { -Double.pi / 2 + Double(i) * 2 * .pi / Double(MapAxis.allCases.count) }

    private func point(_ i: Int, _ r: CGFloat, center c: CGPoint) -> CGPoint {
        CGPoint(x: c.x + CGFloat(cos(angle(i))) * r, y: c.y + CGFloat(sin(angle(i))) * r)
    }

    private func polygon(_ radii: [CGFloat], center c: CGPoint) -> Path {
        var p = Path()
        for (i, r) in radii.enumerated() {
            let pt = point(i, r, center: c)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    var body: some View {
        let c = CGPoint(x: size / 2, y: size / 2)
        ZStack {
            Canvas { ctx, _ in
                // Rings at 25 / 50 / 75 / 100 and the spokes.
                for ring in [0.25, 0.5, 0.75, 1.0] {
                    let path = polygon(Array(repeating: radius * ring, count: axes.count), center: c)
                    ctx.stroke(path, with: .color(Color.cardBorder.opacity(ring == 1 ? 1 : 0.8)), lineWidth: ring == 1 ? 1.2 : 0.8)
                }
                for i in axes.indices {
                    var spoke = Path()
                    spoke.move(to: c)
                    spoke.addLine(to: point(i, radius, center: c))
                    ctx.stroke(spoke, with: .color(Color.cardBorder.opacity(0.8)), lineWidth: 0.8)
                }
                for s in series {
                    if let scores = s.scores {
                        let radii = axes.map { radius * CGFloat(min(100, max(0, scores[$0] ?? 0)) / 100 * draw) }
                        let shape = polygon(radii, center: c)
                        ctx.fill(shape, with: .color(s.color.opacity(0.26)))
                        ctx.stroke(shape, with: .color(s.color), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                        for (i, r) in radii.enumerated() {
                            let pt = point(i, r, center: c)
                            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)),
                                     with: .color(s.color))
                        }
                    } else {
                        // Waiting for their answers: a dashed outline at the middle ring.
                        let shape = polygon(Array(repeating: radius * 0.55 * CGFloat(draw), count: axes.count), center: c)
                        ctx.stroke(shape, with: .color(s.color.opacity(0.9)),
                                   style: StrokeStyle(lineWidth: 1.6, lineJoin: .round, dash: [5, 4]))
                    }
                }
            }
            ForEach(Array(axes.enumerated()), id: \.offset) { i, axis in
                Text(axis.title)
                    .font(.app(labelSize, .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize()
                    .position(point(i, radius + labelSize * 1.6, center: c))
            }
            if showValues {
                ForEach(Array(series.enumerated()), id: \.offset) { si, s in
                    if let scores = s.scores {
                        ForEach(Array(axes.enumerated()), id: \.offset) { i, axis in
                            let v = scores[axis] ?? 0
                            // A's number just outside its point, B's just inside, so they don't sit on each other.
                            let r = radius * CGFloat(v / 100) + (si == 0 ? 12 : -12)
                            Text("\(Int(v.rounded()))")
                                .font(.app(labelSize - 1, .bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(s.color))
                                .fixedSize()
                                .position(point(i, max(10, r), center: c))
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        series.map { s in
            guard let scores = s.scores else { return "\(s.name): waiting for their answers" }
            let parts = axes.map { "\($0.title) \(Int((scores[$0] ?? 0).rounded()))" }
            return "\(s.name): " + parts.joined(separator: ", ")
        }.joined(separator: ". ")
    }
}

/// The two names with their colours; B dashed with "Waiting for {B}'s answers" while they haven't answered.
struct CoupleMapLegend: View {
    var series: [MapSeries]
    var fontSize: CGFloat = 13

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                HStack(spacing: 6) {
                    if s.scores != nil {
                        Circle().fill(s.color).frame(width: 10, height: 10)
                    } else {
                        Circle().stroke(s.color, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2])).frame(width: 10, height: 10)
                    }
                    Text(s.scores == nil ? "Waiting for \(s.name)'s answers" : s.name)
                        .font(.app(fontSize, .semibold))
                        .foregroundStyle(s.scores == nil ? Color.textSecondary : Color.textPrimary)
                        .lineLimit(1)
                }
            }
        }
    }
}

extension CoupleMapData {
    enum Moment { case dayOne, now }

    func series(_ moment: Moment) -> [MapSeries] {
        [MapSeries(name: nameA, color: .gold, scores: moment == .now ? nowA : startA),
         MapSeries(name: nameB, color: .sage, scores: moment == .now ? (nowB ?? startB) : startB)]
    }

    /// Onboarding: where 90 days of checking in every day would take you.
    func projectedSeries(keysA: [String], keysB: [String]?) -> [MapSeries] {
        [MapSeries(name: nameA, color: .gold, scores: CoupleMapScoring.projected(from: startA, habitKeys: keysA)),
         MapSeries(name: nameB, color: .sage,
                   scores: startB.map { CoupleMapScoring.projected(from: $0, habitKeys: keysB ?? []) })]
    }
}

/// Mixes two sets of series (onboarding's "today → in 90 days").
func blendMap(_ a: [MapSeries], _ b: [MapSeries], _ p: Double) -> [MapSeries] {
    zip(a, b).map { x, y in
        guard let xs = x.scores, let ys = y.scores else { return x }
        var out: MapScores = [:]
        for axis in MapAxis.allCases {
            let from = xs[axis] ?? 0, to = ys[axis] ?? 0
            out[axis] = from + (to - from) * p
        }
        return MapSeries(name: x.name, color: x.color, scores: out)
    }
}

/// Progress → "Your couple map": Now / Day 1, tap for the numbers. Clean enough to screenshot.
struct CoupleMapCard: View {
    @Environment(AppModel.self) private var model
    @State private var moment = 0          // 0 = Now, 1 = Day 1
    @State private var showValues = false
    @State private var drawn = false

    var body: some View {
        let data = model.coupleMap
        let series = data.series(moment == 0 ? .now : .dayOne)
        VStack(spacing: 12) {
            HStack {
                Text("Your couple map")
                    .font(.app(19, .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                PillSegmentedControl(options: ["Now", "Day 1"], selection: $moment)
                    .frame(width: 150)
            }
            OneShotClock(duration: 900, play: drawn) { t in
                CoupleMapChart(series: series, size: 280, draw: seg(t, 0, 900), showValues: showValues)
            }
            .frame(width: 280, height: 280)
            .id(moment)   // switching Now / Day 1 draws the shapes in again
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                withAnimation(.open(0.25)) { showValues.toggle() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(showValues ? "Hides the numbers" : "Shows the numbers")
            CoupleMapLegend(series: series)
            Text(showValues ? "Updated daily · tap to hide the numbers" : "Updated daily · tap for the numbers")
                .font(.app(12))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .card(radius: 20, shadow: false)
        .onAppear { drawn = true }
    }
}
