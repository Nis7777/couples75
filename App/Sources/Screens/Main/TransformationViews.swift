import SwiftUI
import StoreKit
import UIKit

/// Progress tab → "Transformation": a before/after slider (Day 1 vs the latest photo), a timeline of every
/// progress photo (tap for full screen), "Play" (timelapse, ~0.15 s per photo) and "Save / Share"
/// (a 9:16 video with a small "Couples 75" watermark). Only my own photos, plus the partner's when they share.
struct TransformationSection: View {
    @Environment(AppModel.self) private var model
    var takePhoto: () -> Void
    @State private var viewing: ViewerItem?
    @State private var playing: PlayerItem?
    @State private var exporting = false
    @State private var exported: ExportedVideo?
    @State private var partnerImages: [UIImage] = []
    @State private var partnerLabels: [String] = []

    struct ViewerItem: Identifiable { var image: UIImage; var label: String; var id: String }
    struct PlayerItem: Identifiable { var images: [UIImage]; var labels: [String]; var id = UUID() }
    struct ExportedVideo: Identifiable { var url: URL; var id: String { url.absoluteString } }

    private var photos: [ProgressPhoto] { model.progress.sorted }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transformation")
                .font(.app(20, .semibold))
                .foregroundStyle(Color.textPrimary)
            if photos.isEmpty {
                EmptyStateCard(text: "No progress photos yet. Take your first one today.", height: 120)
                PrimaryButton("Take today's progress pic") { takePhoto() }
            } else {
                if let first = photos.first, let last = photos.last,
                   let before = model.progress.image(for: first), let after = model.progress.image(for: last) {
                    BeforeAfterSlider(before: before, after: after,
                                      beforeLabel: label(first), afterLabel: photos.count > 1 ? label(last) : "Today")
                        .frame(height: 360)
                }
                timeline
                HStack(spacing: 10) {
                    Button { play(mine: true) } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.app(16, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Capsule().fill(Color.coral))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(photos.count < 2)
                    .opacity(photos.count < 2 ? 0.5 : 1)
                    Button { Task { await export() } } label: {
                        Group {
                            if exporting {
                                ProgressView().tint(Color.coral)
                            } else {
                                Label("Save / Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        .font(.app(16, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Color.buttonBorder, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(exporting)
                }
                if photos.count < 2 {
                    Text("Take another tomorrow to start your timelapse.")
                        .font(.app(13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            if !model.partnerProgressShares.isEmpty {
                partnerRow
            }
            Text(model.shareProgressPhotos
                 ? "Shared with \(model.partnerName). Turn this off in Profile."
                 : "Private: only you can see these. You can share them with \(model.partnerName) in Profile.")
                .font(.app(12))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .fullScreenCover(item: $viewing) { v in ProgressPhotoViewer(image: v.image, label: v.label) }
        .fullScreenCover(item: $playing) { p in TimelapsePlayer(images: p.images, labels: p.labels) }
        .sheet(item: $exported) { v in ActivityView(items: [v.url]).ignoresSafeArea() }
        .task(id: model.partnerProgressShares.count) { await loadPartner() }
    }

    private func label(_ p: ProgressPhoto) -> String {
        p.dayNumber.map { "Day \($0)" } ?? "Warm-up"
    }

    private var timeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos) { p in
                    if let img = model.progress.image(for: p) {
                        Button { viewing = ViewerItem(image: img, label: label(p), id: p.id) } label: {
                            VStack(spacing: 4) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 64, height: 86)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text(label(p))
                                    .font(.app(11, .semibold))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Progress photo, \(label(p))")
                    }
                }
            }
        }
    }

    private var partnerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(model.partnerName)'s progress")
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if partnerImages.count > 1 {
                    Button("Play") { play(mine: false) }
                        .font(.app(14, .semibold))
                        .foregroundStyle(Color.coral)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(partnerImages.enumerated()), id: \.offset) { i, img in
                        Button {
                            viewing = ViewerItem(image: img, label: partnerLabels[i], id: "p\(i)")
                        } label: {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 56, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private func loadPartner() async {
        var imgs: [UIImage] = []
        var labels: [String] = []
        for f in model.partnerProgressShares {
            if let img = await model.partnerProgressImage(f) {
                imgs.append(img)
                labels.append(f.dayNumber.map { "Day \($0)" } ?? "Warm-up")
            }
        }
        partnerImages = imgs
        partnerLabels = labels
    }

    private func myImages() -> ([UIImage], [String]) {
        var imgs: [UIImage] = []
        var labels: [String] = []
        for p in photos {
            if let img = model.progress.image(for: p) { imgs.append(img); labels.append(label(p)) }
        }
        return (imgs, labels)
    }

    private func play(mine: Bool) {
        if mine {
            let (imgs, labels) = myImages()
            guard imgs.count > 1 else { return }
            playing = PlayerItem(images: imgs, labels: labels)
        } else {
            playing = PlayerItem(images: partnerImages, labels: partnerLabels)
        }
    }

    private func export() async {
        let (imgs, labels) = myImages()
        guard !imgs.isEmpty else { return }
        exporting = true
        defer { exporting = false }
        do {
            let url = try await TimelapseExporter.export(imgs, labels: labels)
            exported = ExportedVideo(url: url)
            Haptics.success()
        } catch {
            model.errorMessage = "Couldn't make the video. Try again."
        }
    }
}

/// Day 1 on the left, today on the right; drag the handle to compare.
struct BeforeAfterSlider: View {
    var before: UIImage
    var after: UIImage
    var beforeLabel = "Day 1"
    var afterLabel = "Today"
    @State private var split: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let x = w * split
            ZStack(alignment: .leading) {
                Image(uiImage: after)
                    .resizable().scaledToFill()
                    .frame(width: w, height: h).clipped()
                Image(uiImage: before)
                    .resizable().scaledToFill()
                    .frame(width: w, height: h).clipped()
                    .mask(alignment: .leading) { Rectangle().frame(width: x) }
                tag(beforeLabel).position(x: 46, y: 22)
                tag(afterLabel).position(x: w - 46, y: 22)
                // The handle.
                Rectangle().fill(Color.white).frame(width: 3, height: h).position(x: x, y: h / 2)
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    .overlay(Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.coral))
                    .position(x: x, y: h / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                split = min(max(g.location.x / max(w, 1), 0.04), 0.96)
            })
            .accessibilityElement()
            .accessibilityLabel("Before and after: \(beforeLabel) and \(afterLabel)")
            .accessibilityValue("\(Int(split * 100)) percent \(beforeLabel)")
            .accessibilityAdjustableAction { dir in
                switch dir {
                case .increment: split = min(split + 0.1, 0.96)
                case .decrement: split = max(split - 0.1, 0.04)
                @unknown default: break
                }
            }
        }
    }

    private func tag(_ t: String) -> some View {
        Text(t)
            .font(.app(13, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(Color.black.opacity(0.45)))
    }
}

/// Full-screen progress photo.
struct ProgressPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    var image: UIImage
    var label: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text(label).font(.app(18, .bold)).foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .accessibilityLabel("Close")
            }
            .padding(16)
        }
    }
}

/// Plays the progress photos as a timelapse (~0.15 s per photo), then holds the last one.
struct TimelapsePlayer: View {
    @Environment(\.dismiss) private var dismiss
    var images: [UIImage]
    var labels: [String]
    @State private var index = 0
    @State private var running = true

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if images.indices.contains(index) {
                Image(uiImage: images[index]).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                Text(labels.indices.contains(index) ? labels[index] : "")
                    .font(.app(20, .bold)).foregroundStyle(.white)
                Spacer()
                Button {
                    index = 0
                    running = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .accessibilityLabel("Replay")
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .accessibilityLabel("Close")
            }
            .padding(16)
            Text(Brand.appName)
                .font(.app(13, .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(20)
        }
        .task(id: running) {
            guard running else { return }
            while index < images.count - 1 {
                try? await Task.sleep(nanoseconds: 150_000_000)
                if Task.isCancelled { return }
                index += 1
            }
            running = false
        }
    }
}

/// UIKit share sheet (for the exported video file).
struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Day 25, 50 and 75: a celebration with Day 1 next to today. Only my own photos, plus my partner's
/// if they share theirs.
struct MilestoneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    var day: Int
    @State private var partnerFirst: UIImage?
    @State private var partnerLatest: UIImage?
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SmallLabel(text: "Milestone")
                    .padding(.top, 28)
                TitleText("Day \(day)!", size: 40)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                BodyText(day == Brand.roundLengthDays
                         ? "You made it. Look how far you've come."
                         : "\(Brand.roundLengthDays - day) days to go. Look how far you've come.")
                pair(name: model.me?.name ?? "You",
                     first: model.progress.first.flatMap { model.progress.image(for: $0) },
                     latest: model.progress.latest.flatMap { model.progress.image(for: $0) })
                if partnerFirst != nil || partnerLatest != nil {
                    pair(name: model.partnerName, first: partnerFirst, latest: partnerLatest)
                }
            }
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                PrimaryButton("Keep going") {
                    if ReviewPrompt.canAsk {
                        ReviewPrompt.markAsked()
                        requestReview()
                    }
                    dismiss()
                }
            }
                .background(Color.ivory.opacity(0.95))
        }
        .background(AppBackground())
        .task {
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            let shares = model.partnerProgressShares
            if let f = shares.first { partnerFirst = await model.partnerProgressImage(f) }
            if shares.count > 1, let l = shares.last { partnerLatest = await model.partnerProgressImage(l) }
        }
    }

    private func pair(name: String, first: UIImage?, latest: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.app(17, .bold)).foregroundStyle(Color.textPrimary)
            HStack(spacing: 10) {
                photo(first, label: "Day 1")
                photo(latest, label: "Day \(day)")
            }
        }
        .padding(14)
        .card()
    }

    private func photo(_ image: UIImage?, label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.peach.overlay(Image(systemName: "photo").foregroundStyle(Color.coral))
            }
            Text(label)
                .font(.app(13, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
