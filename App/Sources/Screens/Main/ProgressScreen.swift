import SwiftUI
import UIKit

/// 16: Progress. Two characters at the top, the 75-dot gold grid in a card, rounded photo thumbnails in a row.
struct ProgressScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewing: CheckInFact?

    private var round: RoundState? { model.currentRound }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 6), count: 12) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress")
                        .font(.app(34, .bold))
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(model.nameA) & \(model.nameB)")
                        .font(.app(17, .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 14)

                // Both busts above the grid, also before the partner has joined (their avatar as made on A's phone).
                CoupleScene(left: model.sceneA, right: model.sceneBBuilt, crop: 0.56, overlap: -0.04)
                    .frame(height: 220)
                    .padding(.bottom, -18)
                    .zIndex(0)

                gridCard.zIndex(1)
                photoStrip
                statsRow
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.gold)
                    Text("Stakes: \(round?.betText ?? model.currentBet)")
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .card(radius: 16)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $viewing) { c in PhotoViewer(checkIn: c) }
    }

    // MARK: 75-day grid

    private enum Cell { case both, half, saves, miss, today, future }

    private var todayNumber: Int? { model.myToday?.dayNumber }

    private func cell(_ n: Int) -> Cell {
        guard let r = round, r.members.count == 2 else { return n == 1 && todayNumber == 1 ? .today : .future }
        let a = r.members[0].days.first { $0.dayNumber == n }
        let b = r.members[1].days.first { $0.dayNumber == n }
        if let a, let b {
            switch (a.outcome, b.outcome) {
            case (.complete, .complete): return .both
            case (.complete, .miss), (.miss, .complete):
                return (a.coveredBySave || b.coveredBySave) ? .half : .miss
            default:
                return (a.coveredBySave && b.coveredBySave) ? .saves : .miss
            }
        }
        if n == todayNumber { return .today }
        if a != nil || b != nil { return .half }
        return .future
    }

    private var currentDay: Int {
        todayNumber ?? round?.members.map { $0.countedDays }.max() ?? 0
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("75-day grid")
                    .font(.app(20, .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                // The warm-up day counts as done: the grid is never empty.
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.gold)
                    Text("Warm-up done")
                        .font(.app(12, .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.peach))
                .accessibilityElement(children: .combine)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...Brand.roundLengthDays, id: \.self) { n in
                    cellView(cell(n))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("75-day grid")
            .accessibilityValue(gridSummary)
            Text(currentDay == 0 ? "Day 0 done. \(Brand.roundLengthDays) to go." : "Day \(currentDay) of \(Brand.roundLengthDays)")
                .font(.app(18, .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
            HStack(spacing: 14) {
                legend(.both, "Both done")
                legend(.half, "One + save")
                legend(.today, "Today")
            }
            .font(.app(12))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .card()
    }

    private var gridSummary: String {
        let cells = (1...Brand.roundLengthDays).map(cell)
        let both = cells.filter { if case .both = $0 { return true } else { return false } }.count
        if currentDay == 0 { return "Warm-up done. Day 1 has not started yet." }
        return "Day \(currentDay) of 75. \(both) days complete for both."
    }

    @ViewBuilder
    private func cellView(_ c: Cell) -> some View {
        switch c {
        case .both:
            Circle().fill(Color.gold)
        case .half:
            Circle().stroke(Color.gold, lineWidth: 1.4)
                .overlay(HalfCircle().fill(Color.gold))
        case .saves:
            Circle().fill(Color.peach).overlay(Circle().stroke(Color.coral.opacity(0.6), lineWidth: 1.4))
        case .miss:
            Circle().stroke(Color.coral.opacity(0.6), lineWidth: 1.4)
        case .today:
            Circle().stroke(Color.coral, lineWidth: 2.2)
        case .future:
            Circle().stroke(Color.gold.opacity(0.75), lineWidth: 1.3)
        }
    }

    private func legend(_ c: Cell, _ text: String) -> some View {
        HStack(spacing: 5) {
            cellView(c).frame(width: 11, height: 11)
            Text(text)
        }
    }

    // MARK: Photos

    private var photos: [CheckInFact] {
        Array(model.facts.checkIns.filter { $0.hasPhoto }.sorted { $0.capturedAt > $1.capturedAt }.prefix(30))
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent photos")
                .font(.app(20, .semibold))
                .foregroundStyle(Color.textPrimary)
            if photos.isEmpty {
                Text("Photo check-ins from both of you show up here. Only the two of you can see them.")
                    .font(.app(15))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos) { c in
                            Button { viewing = c } label: { PhotoThumb(checkIn: c) }
                                .accessibilityLabel("\(model.name(of: c.memberID))'s photo, \(c.stampText)")
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("\(model.state.bestStreak)", "Best streak")
            stat("\(max(model.state.roundsPlayed, 1))", "Rounds")
            stat("\(round?.savesLeft ?? Brand.savesPerRound)", "Saves left")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.app(28, .bold)).foregroundStyle(Color.textPrimary)
            Text(label).font(.app(13, .medium)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(radius: 16)
        .accessibilityElement(children: .combine)
    }
}

struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct PhotoThumb: View {
    @Environment(AppModel.self) private var model
    var checkIn: CheckInFact
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.peach)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().tint(.coral)
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(checkIn.memberID == model.memberA?.id ? Color.coral : Color.sage)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .padding(5)
        }
        .task(id: checkIn.id) {
            if let data = model.cachedPhoto(checkIn.id) { image = UIImage(data: data); return }
            if let data = await model.photoData(for: checkIn) { image = UIImage(data: data) }
        }
    }
}

/// Full-screen photo with the burned-in stamp and the reactions.
struct PhotoViewer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var checkIn: CheckInFact
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Photo, \(checkIn.stampText)")
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(model.name(of: checkIn.memberID)) · \(model.facts.rules.first { $0.id == checkIn.ruleID }?.title ?? "")")
                        .font(.app(16, .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                    .accessibilityLabel("Close")
                }
                Spacer()
                let reactions = model.reactions(for: checkIn.id).filter { $0.kind != .seen }
                if !reactions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(reactions) { r in
                            Text(reactionText(r))
                                .font(.app(14, .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.55)))
                }
            }
            .padding(20)
        }
        .task {
            if let data = model.cachedPhoto(checkIn.id) { image = UIImage(data: data) }
            if image == nil, let data = await model.photoData(for: checkIn) { image = UIImage(data: data) }
        }
    }

    private func reactionText(_ r: ReactionFact) -> String {
        let who = r.memberID == model.meID ? "You" : model.name(of: r.memberID)
        switch r.kind {
        case .approve: return "\(who) approved ❤️"
        case .emoji: return "\(who) \(r.emoji ?? "")"
        case .comment: return "\(who): \(r.comment ?? "")"
        case .sus: return "\(who) 🤨"
        case .seen: return ""
        }
    }
}
