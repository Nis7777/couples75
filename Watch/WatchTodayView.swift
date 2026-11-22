import SwiftUI
import WatchKit

/// Today on the wrist: the day, my rules (honour rules tick off from 18:00), and how my partner is doing.
struct WatchTodayView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        NavigationStack {
            if let p = store.payload {
                List {
                    Section {
                        HStack {
                            Text(p.day.map { "Day \($0)" } ?? "Warm-up")
                                .font(.system(.title3, design: .rounded).bold())
                            Spacer()
                            Label("\(p.streak)", systemImage: "flame.fill")
                                .font(.system(.footnote, design: .rounded).bold())
                                .foregroundStyle(WatchColors.gold)
                        }
                        Text(p.myLeft == 0 ? "All done today" : "\(p.myLeft) left")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Section("My rules") {
                        ForEach(p.rules) { r in row(r) }
                    }
                    if !p.partnerName.isEmpty {
                        Section {
                            Label(p.partnerLeft == 0 ? "\(p.partnerName) is done" : "\(p.partnerName): \(p.partnerLeft) left",
                                  systemImage: p.partnerLeft == 0 ? "checkmark.circle.fill" : "heart.fill")
                                .foregroundStyle(WatchColors.sage)
                        }
                    }
                }
                .navigationTitle("Couples 75")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.title2)
                        .foregroundStyle(WatchColors.coral)
                    Text("Open Couples 75 on your iPhone to start.")
                        .font(.system(.footnote, design: .rounded))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    private var honourOpen: Bool { Calendar.current.component(.hour, from: Date()) >= WatchMessage.honourOpensAtHour }

    @ViewBuilder
    private func row(_ r: WatchPayload.Rule) -> some View {
        let done = r.done || store.sentRuleIDs.contains(r.id)
        let content = HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : (r.isHonour ? "circle" : "camera"))
                .foregroundStyle(done ? WatchColors.coral : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(r.title)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(2)
                if !done {
                    Text(r.isHonour ? (honourOpen ? "Tap when you've stuck to it" : "Tap tonight") : "Use your iPhone camera")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        if !done, r.isHonour, honourOpen {
            Button { store.checkIn(r) } label: { content }
        } else {
            content
        }
    }
}
