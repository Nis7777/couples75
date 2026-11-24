import WidgetKit
import AppIntents
import ActivityKit
import SwiftUI

// 4.10 widgets. They only read the WidgetSnapshot the app writes to the App Group. Never photos.

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let isPlaceholder: Bool
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snap = WidgetSnapshot.load()
        completion(SnapshotEntry(date: Date(), snapshot: snap ?? .placeholder, isPlaceholder: snap == nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snap = WidgetSnapshot.load()
        let now = Date()
        var entries = [SnapshotEntry(date: now, snapshot: snap ?? .placeholder, isPlaceholder: snap == nil)]
        // Honour rules become tappable at 18:00: add an entry then so the widget updates on time.
        if let six = Calendar.current.date(bySettingHour: HonourWindow.opensAtHour, minute: 0, second: 0, of: now), six > now {
            entries.append(SnapshotEntry(date: six, snapshot: snap ?? .placeholder, isPlaceholder: snap == nil))
        }
        // The app reloads timelines after every change; refresh hourly as a fallback.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

@main
struct CouplesWidgets: WidgetBundle {
    var body: some Widget {
        CoupleSmallWidget()
        CoupleMediumWidget()
        PactCardWidget()
        MyRulesWidget()
        LockScreenWidget()
        TodayLiveActivity()
    }
}

struct CoupleSmallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CoupleSmall", provider: SnapshotProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(Color.ivory, for: .widget)
        }
        .configurationDisplayName("Our ring")
        .description("Your day and your partner's, at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct CoupleMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CoupleMedium", provider: SnapshotProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(Color.ivory, for: .widget)
        }
        .configurationDisplayName("Today together")
        .description("Day, who's done and your streak.")
        .supportedFamilies([.systemMedium])
    }
}

/// A challenge: its days. Daily habits: today's done state for the two of you.
private func ringProgress(_ s: WidgetSnapshot) -> Double {
    if s.roundLength > 0 { return Double(s.dayNumber ?? 0) / Double(s.roundLength) }
    return (s.doneA ? 0.5 : 0) + (s.doneB ? 0.5 : 0)
}

private func dayText(_ s: WidgetSnapshot) -> String {
    // roundLength 0: daily habits (no end).
    if let d = s.dayNumber { return s.roundLength > 0 ? "Day \(d)/\(s.roundLength)" : "🔥 \(s.streak) · habits" }
    return s.statusLine ?? "Not started"
}

struct SmallWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        let s = entry.snapshot
        let progress = ringProgress(s)
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.track, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(Color.gold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                WidgetBusts(a: s.avatarA ?? Avatar(characterID: s.characterA), b: s.characterB.isEmpty ? nil : (s.avatarB ?? Avatar(characterID: s.characterB)))
                    .padding(10)
                    .clipShape(Circle())
                    .padding(6)
            }
            Text(dayText(s))
                .font(.app(17, .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .widgetURL(URL(string: "\(Brand.urlScheme)://today"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.nameA) and \(s.nameB), \(dayText(s))")
    }
}

/// Two busts side by side with flat bottoms.
struct WidgetBusts: View {
    var a: Avatar
    /// nil: B hasn't joined, draw the dashed outline.
    var b: Avatar?

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: -geo.size.width * 0.14) {
                CharacterView(avatar: a, pose: .bust)
                    .frame(height: geo.size.height * 0.88)
                    .zIndex(1)
                if let b {
                    CharacterView(avatar: b, pose: .bust)
                        .frame(height: geo.size.height)
                } else {
                    Image("partner_outline").resizable().scaledToFit()
                        .frame(height: geo.size.height * 1.7, alignment: .top)
                        .frame(height: geo.size.height, alignment: .top)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }
}

struct MediumWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        let s = entry.snapshot
        HStack(spacing: 14) {
            WidgetBusts(a: s.avatarA ?? Avatar(characterID: s.characterA), b: s.characterB.isEmpty ? nil : (s.avatarB ?? Avatar(characterID: s.characterB)))
                .frame(width: 150)
                .padding(.top, 6)
                .padding(.bottom, -16)
            VStack(alignment: .leading, spacing: 10) {
                Text(dayText(s))
                    .font(.app(26, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 6) {
                    Text("\(s.nameA) \(s.doneA ? "✓" : "…")  \(s.nameB) \(s.doneB ? "✓" : "…")")
                        .font(.app(15, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "flame.fill").foregroundStyle(Color(hex: 0xE2704C))
                    Text("\(s.streak)")
                        .font(.app(15, .bold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "\(Brand.urlScheme)://today"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dayText(s)). \(s.nameA) \(s.doneA ? "done" : "not done"), \(s.nameB) \(s.doneB ? "done" : "not done"). Streak \(s.streak).")
    }
}


/// Honour rules can be ticked off from 18:00 local (same as in the app).
enum HonourWindow {
    static let opensAtHour = 18
    static func isOpen(at date: Date) -> Bool { Calendar.current.component(.hour, from: date) >= opensAtHour }
}

// MARK: - Interactive "My rules" widget

struct MyRulesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MyRules", provider: SnapshotProvider()) { entry in
            MyRulesWidgetView(entry: entry)
                .containerBackground(Color.ivory, for: .widget)
        }
        .configurationDisplayName("My rules today")
        .description("Tick off honour rules from your Home Screen. Photo rules open the camera.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct MyRulesWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.snapshot
        let limit = family == .systemLarge ? 6 : 3
        VStack(alignment: .leading, spacing: family == .systemLarge ? 9 : 5) {
            HStack {
                Text(s.myRules.isEmpty ? dayText(s) : "\(s.myLeft == 0 ? "All done" : "\(s.myLeft) left") · \(dayText(s))")
                    .font(.app(15, .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if !s.partnerName.isEmpty, s.partnerTotal > 0 {
                    Text(s.partnerLeft == 0 ? "\(s.partnerName) ✓" : "\(s.partnerName) \(s.partnerLeft) left")
                        .font(.app(12, .semibold))
                        .foregroundStyle(Color.sage)
                        .lineLimit(1)
                }
            }
            if s.myRules.isEmpty {
                Text("Open \(Brand.appName) to see today's habits.")
                    .font(.app(13))
                    .foregroundStyle(Color.textSecondary)
            }
            ForEach(s.myRules.prefix(limit)) { r in row(r) }
            if s.myRules.count > limit {
                Text("+\(s.myRules.count - limit) more")
                    .font(.app(12, .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "\(Brand.urlScheme)://today"))
    }

    @ViewBuilder
    private func row(_ r: SnapshotRule) -> some View {
        let label = HStack(spacing: 8) {
            ZStack {
                Circle().fill(r.done ? Color.coral : Color.white)
                Circle().stroke(r.done ? Color.coral : Color.radio, lineWidth: 1.6)
                if r.done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                } else if !r.isHonour {
                    Image(systemName: "camera.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.coral)
                }
            }
            .frame(width: 20, height: 20)
            Text(r.title)
                .font(.app(14, .medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .strikethrough(r.done, color: Color.textSecondary)
            Spacer(minLength: 0)
            if r.isHonour, !r.done, !HonourWindow.isOpen(at: entry.date) {
                Text("Tonight")
                    .font(.app(11, .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        if r.done {
            label
        } else if r.isHonour {
            if HonourWindow.isOpen(at: entry.date) {
                Button(intent: CheckHonourRuleIntent(ruleID: r.id)) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        } else if let url = URL(string: "\(Brand.urlScheme)://rule/\(r.id)") {
            Link(destination: url) { label }
        }
    }
}

// MARK: - Lock Screen widgets

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockScreen", provider: SnapshotProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Brand.appName)
        .description("Your day and rules left.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryCircular:
            Gauge(value: ringProgress(s), in: 0...1) {
                Text("Day")
            } currentValueLabel: {
                Text("\(s.dayNumber ?? 0)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            Text(s.myRules.isEmpty ? dayText(s) : "\(dayText(s)) · \(s.myLeft) left")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(dayText(s)).font(.headline).widgetAccentable()
                Text(s.myLeft == 0 && !s.myRules.isEmpty ? "All done today" : "\(s.myLeft) rules left")
                if !s.partnerName.isEmpty {
                    Text(s.partnerLeft == 0 ? "\(s.partnerName) is done" : "\(s.partnerName): \(s.partnerLeft) left")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Live Activity (evening progress)

struct TodayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayActivityAttributes.self) { context in
            LiveActivityView(attributes: context.attributes, state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.ivory)
                .activitySystemActionForegroundColor(Color.coral)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.myLeft) left").font(.app(15, .bold)).foregroundStyle(Color.coral)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.partnerLeft == 0 ? "\(context.attributes.partnerName) ✓"
                                                       : "\(context.attributes.partnerName) \(context.state.partnerLeft)")
                        .font(.app(15, .semibold)).foregroundStyle(Color.sage)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: Double(context.state.myTotal - context.state.myLeft),
                                 total: Double(max(context.state.myTotal, 1)))
                        .tint(Color.coral)
                }
            } compactLeading: {
                Text("\(context.state.myLeft)").font(.app(14, .bold)).foregroundStyle(Color.coral)
            } compactTrailing: {
                Image(systemName: context.state.partnerLeft == 0 ? "checkmark.circle.fill" : "heart.fill")
                    .foregroundStyle(Color.sage)
            } minimal: {
                Text("\(context.state.myLeft)").font(.app(14, .bold)).foregroundStyle(Color.coral)
            }
            .widgetURL(URL(string: "\(Brand.urlScheme)://today"))
        }
    }
}

struct LiveActivityView: View {
    let attributes: TodayActivityAttributes
    let state: TodayActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(state.day.map { "Day \($0)" } ?? "Today")
                    .font(.app(17, .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(Brand.appName).font(.app(13, .semibold)).foregroundStyle(Color.textSecondary)
            }
            bar(name: attributes.myName.isEmpty ? "You" : attributes.myName,
                left: state.myLeft, total: state.myTotal, color: .coral)
            bar(name: attributes.partnerName, left: state.partnerLeft, total: state.partnerTotal, color: .sage)
        }
    }

    private func bar(name: String, left: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.app(14, .semibold)).foregroundStyle(Color.textPrimary)
                Spacer()
                Text(left == 0 ? "Done" : "\(left) left").font(.app(13, .semibold)).foregroundStyle(color)
            }
            ProgressView(value: Double(total - left), total: Double(max(total, 1))).tint(color)
        }
    }
}

// MARK: - Pact Card widget

/// The couple's Pact Card on the Home Screen: logo, rank and streak, both busts and both signatures.
/// Medium is the card itself; small is the logo, the two of you and the streak.
struct PactCardWidget: Widget {
    /// A plain String, not an interpolated literal: WidgetKit reads an interpolated literal as a localized key and
    /// crashed resolving it ("ResolvedWidgetBundleHost.allDescriptors").
    private static let displayName: String = Brand.appName + " Card"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PactCard", provider: SnapshotProvider()) { entry in
            PactCardWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(hex: 0x4A382D), Color(hex: 0x382A22), Color(hex: 0x271C16)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .widgetURL(URL(string: "\(Brand.urlScheme)://today"))
        }
        .configurationDisplayName(Self.displayName)
        .description("Your couple card: signed by both of you, with your rank and streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PactCardWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family
    private let ink = Color(hex: 0xF7F1E8)

    var body: some View {
        let s = entry.snapshot
        if family == .systemSmall { small(s) } else { medium(s) }
    }

    private func header(_ s: WidgetSnapshot, compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image("LaunchLogo").resizable().scaledToFit().frame(width: compact ? 26 : 30, height: compact ? 26 : 30)
            if !compact {
                Text(Brand.appName.uppercased())
                    .font(.app(14, .heavy))
                    .tracking(3)
                    .foregroundStyle(ink)
            }
            Spacer(minLength: 0)
            if let rank = s.rankTitle {
                HStack(spacing: 4) {
                    Image(systemName: s.rankSymbol ?? "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: 0xE6C28E))
                    Text(rank).font(.app(12, .bold)).foregroundStyle(ink)
                }
            }
        }
    }

    private func streak(_ s: WidgetSnapshot) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0xE2704C))
            Text("\(s.streak)").font(.app(12, .bold)).foregroundStyle(ink)
        }
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header(s, compact: false)
                streak(s).padding(.leading, 8)
            }
            Spacer(minLength: 4)
            HStack(alignment: .bottom, spacing: 14) {
                person(name: s.nameA, avatar: s.avatarA ?? Avatar(characterID: s.characterA), signed: s.signedA)
                person(name: s.nameB, avatar: s.characterB.isEmpty ? nil : (s.avatarB ?? Avatar(characterID: s.characterB)),
                       signed: s.signedB)
            }
        }
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(s, compact: true)
            Spacer(minLength: 0)
            HStack(spacing: -10) {
                BustCircle(avatar: s.avatarA ?? Avatar(characterID: s.characterA), size: 44, ring: ink, ringWidth: 2,
                           fill: ink.opacity(0.92))
                BustCircle(avatar: s.characterB.isEmpty ? nil : (s.avatarB ?? Avatar(characterID: s.characterB)), size: 44,
                           ring: ink, ringWidth: 2, fill: ink.opacity(0.92))
            }
            Text("\(s.nameA) & \(s.nameB)")
                .font(.custom("SnellRoundhand-Bold", size: 18))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            streak(s)
        }
    }

    private func person(name: String, avatar: Avatar?, signed: Date?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            BustCircle(avatar: avatar, size: 40, ring: ink, ringWidth: 1.5, fill: ink.opacity(0.92))
            Group {
                if signed != nil {
                    Text(name)
                        .font(.custom("SnellRoundhand-Bold", size: 20))
                        .foregroundStyle(ink)
                } else {
                    Text("Waiting for \(name)")
                        .font(.app(11, .medium))
                        .foregroundStyle(ink.opacity(0.7))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(height: 24, alignment: .bottomLeading)
            Rectangle().fill(ink.opacity(signed == nil ? 0.4 : 0.7)).frame(height: 1)
            Text(signed.map { "Signed \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Not signed yet")
                .font(.app(10, .medium))
                .foregroundStyle(ink.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
