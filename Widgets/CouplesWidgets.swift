import WidgetKit
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
        let entry = SnapshotEntry(date: Date(), snapshot: snap ?? .placeholder, isPlaceholder: snap == nil)
        // The app reloads timelines after every change; refresh hourly as a fallback.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

@main
struct CouplesWidgets: WidgetBundle {
    var body: some Widget {
        CoupleSmallWidget()
        CoupleMediumWidget()
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

private func dayText(_ s: WidgetSnapshot) -> String {
    if let d = s.dayNumber { return "Day \(d)/\(s.roundLength)" }
    return s.statusLine ?? "Not started"
}

struct SmallWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        let s = entry.snapshot
        let progress = Double(s.dayNumber ?? 0) / Double(max(s.roundLength, 1))
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
                    Image(systemName: "flame.fill").foregroundStyle(Color(hex: 0xE07A2E))
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
