import SwiftUI
import UIKit

/// 16: Progress. Two characters at the top, the gold day grid in a card, rounded photo thumbnails in a row,
/// stats, badges, finished challenges and the bucket list.
struct ProgressScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewing: CheckInFact?
    @State private var showProgressCamera = false
    @State private var recap: WeeklyRecap?

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

                if let r = model.weeklyRecap {
                    Button { recap = r } label: {
                        HStack {
                            Image(systemName: "calendar").foregroundStyle(Color.coral)
                            Text("Our week: \(r.me.completeDays)/7 days")
                                .font(.app(16, .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("See recap ›").font(.app(14, .semibold)).foregroundStyle(Color.coral)
                        }
                        .padding(14)
                        .card(radius: 16, shadow: false)
                    }
                    .buttonStyle(PressableStyle())
                }

                TransformationSection(takePhoto: { showProgressCamera = true })

                // Both busts above the grid, also before the partner has joined (their avatar as made on A's phone).
                CoupleScene(left: model.sceneA, right: model.sceneBBuilt, crop: 0.56, overlap: -0.04)
                    .frame(height: 220)
                    .padding(.bottom, -18)
                    .zIndex(0)

                gridCard.zIndex(1)
                photoStrip
                statsRow
                BadgesCard()
                BucketListCard()
                if model.activeChallenge != nil, let bet = round?.betText, !bet.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.gold)
                        Text("Stakes: \(bet)")
                            .font(.app(16, .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .card(radius: 16)
                    .accessibilityElement(children: .combine)
                }
                FinishedChallengesCard()
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .fullScreenCover(item: $viewing) { c in PhotoViewer(checkIn: c) }
        .fullScreenCover(isPresented: $showProgressCamera) { ProgressCameraView() }
        .sheet(item: $recap) { r in WeeklyRecapView(recap: r) }
    }

    // MARK: Day grid (a challenge's days, or the latest 48 days of habits)

    private var isChallenge: Bool { round.map { !$0.mode.isMaintenance } ?? false }

    private var gridRange: ClosedRange<Int> {
        if isChallenge, let r = round { return 1...max(1, r.length) }
        let end = max(currentDay, 1)
        let start = max(1, end - 47)
        return start...(start + 47)
    }

    private var gridTitle: String {
        if isChallenge { return model.activeChallenge?.title ?? "\(round?.length ?? 0)-day grid" }
        return "Daily habits"
    }

    private var dayLine: String {
        if isChallenge {
            let total = round?.length ?? 0
            return currentDay == 0 ? "Day 0 done. \(total) to go." : "Day \(currentDay) of \(total)"
        }
        return currentDay == 0 ? "Your habits start tomorrow." : "Day \(currentDay) of your habits"
    }

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
                Text(gridTitle)
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
                ForEach(Array(gridRange), id: \.self) { n in
                    cellView(cell(n))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(gridTitle)
            .accessibilityValue(gridSummary)
            Text(dayLine)
                .font(.app(18, .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
            HStack(spacing: 16) {
                legend(.both, "Both done")
                legend(.half, "One + save")
                legend(.today, "Today")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .card()
    }

    private var gridSummary: String {
        let cells = gridRange.map(cell)
        let both = cells.filter { if case .both = $0 { return true } else { return false } }.count
        if currentDay == 0 { return "Warm-up done. Day 1 has not started yet." }
        return "\(dayLine). \(both) days complete for both."
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
        HStack(spacing: 6) {
            cellView(c).frame(width: 13, height: 13)
            Text(text)
                .font(.app(13, .medium))
                .foregroundStyle(Color.textPrimary)
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
                EmptyStateCard(text: "No proof photos yet. Snap your first check-in today.", height: 120, art: "empty_proof")
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
            stat("\(model.finishedChallenges.count)", "Challenges")
            stat("\(model.xp.total)", "Couple XP")
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

/// Challenges finished together, newest first.
struct FinishedChallengesCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let done = model.finishedChallenges
        if done.isEmpty {
            Button { model.tab = .challenges } label: {
                EmptyStateCard(text: "No challenges finished yet. Pick one and finish it together ›", height: 130,
                               art: "empty_challenges")
            }
            .buttonStyle(PressableStyle())
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Challenges finished").font(.app(20, .semibold)).foregroundStyle(Color.textPrimary)
                ForEach(done) { r in
                    let c = Challenges.challenge(r.challengeID)
                    HStack(spacing: 12) {
                        CustomIcon(asset: c?.asset ?? "challenge_the75", symbol: c?.icon ?? "flame.fill", size: 38, circled: true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c?.title ?? "The 75").font(.app(16, .semibold)).foregroundStyle(Color.textPrimary)
                            Text("\(r.length) days · \(r.endedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .font(.app(13)).foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.sage)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}
