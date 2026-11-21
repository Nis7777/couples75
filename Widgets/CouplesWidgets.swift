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
                Circle().stroke(Color.peach, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(0.001, progress))
                    .stroke(Color.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(spacing: -10) {
                    bust(s.characterA)
                    if !s.characterB.isEmpty { bust(s.characterB) }
                }
            }
            .padding(4)
            Text(dayText(s))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .widgetURL(URL(string: "\(Brand.urlScheme)://today"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.nameA) and \(s.nameB), \(dayText(s))")
    }

    private func bust(_ id: String) -> some View {
        CharacterImage(characterID: id, pose: .bust)
            .frame(width: 42, height: 42)
            .background(Circle().fill(Color.white))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
}

struct MediumWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        let s = entry.snapshot
        HStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: -14) {
                CharacterImage(characterID: s.characterA, pose: .stand)
                if !s.characterB.isEmpty {
                    CharacterImage(characterID: s.characterB, pose: .stand)
                }
            }
            .frame(maxWidth: 130, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                Text(dayText(s))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(s.nameA) \(s.doneA ? "✓" : "…") · \(s.nameB) \(s.doneB ? "✓" : "…")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.gold)
                    Text("\(s.streak)")
                        .font(.system(size: 15, weight: .bold))
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
