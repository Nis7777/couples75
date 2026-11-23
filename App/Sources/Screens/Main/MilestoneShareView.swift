import SwiftUI
import UIKit
import Photos

/// The share card's two formats: 9:16 for stories (1080 × 1920) and 1:1 (1080 × 1080).
enum ShareFormat: Int, CaseIterable {
    case story, square
    var size: CGSize { self == .story ? CGSize(width: 360, height: 640) : CGSize(width: 360, height: 360) }
    var title: String { self == .story ? "Story 9:16" : "Square 1:1" }
}

/// The image people post. Pure (no environment), so ImageRenderer draws exactly what the preview shows:
/// the same Pact Card and couple map as in the app. No usernames, no proof photo unless they turn it on.
struct MilestoneCard: View {
    var milestone: PactMilestone
    var card: PactCardData
    var map: CoupleMapData
    var format: ShareFormat
    var photo: UIImage?

    var body: some View {
        let story = format == .story
        ZStack {
            Color.ivory
            Circle().fill(Color.peach).frame(width: 420).blur(radius: 60).offset(y: story ? -170 : -60)
            VStack(spacing: 0) {
                Text(Brand.appName.uppercased())
                    .font(.app(story ? 15 : 13, .heavy))
                    .tracking(5)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, story ? 30 : 18)
                headline(story: story)
                    .padding(.top, story ? 18 : 8)
                Text("\(card.nameA) & \(card.nameB) · \(milestone.subtitle)")
                    .font(.app(story ? 15 : 13, .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                PactCard(data: card)
                    .scaleEffect(story ? 0.92 : 0.66)
                    .frame(width: PactCardMetrics.width * (story ? 0.92 : 0.66),
                           height: PactCardMetrics.height * (story ? 0.92 : 0.66))
                    .padding(.top, story ? 18 : 10)
                if story {
                    VStack(spacing: 4) {
                        CoupleMapChart(series: map.series(.now), size: 150, labelSize: 9)
                        CoupleMapLegend(series: map.series(.now), fontSize: 10)
                    }
                    .padding(.top, 14)
                }
                Spacer(minLength: 0)
                Text("\(Brand.appName): Couples Habits · on the App Store")
                    .font(.app(story ? 11 : 9.5, .semibold))
                    .foregroundStyle(Color.textSecondary.opacity(0.8))
                    .padding(.bottom, story ? 22 : 12)
            }
            if let photo {
                // A polaroid, tilted, top right.
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: story ? 96 : 70, height: story ? 96 : 70)
                    .clipped()
                    .padding(5)
                    .padding(.bottom, 12)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
                    .rotationEffect(.degrees(7))
                    .position(x: format.size.width - (story ? 64 : 50), y: story ? 120 : 64)
            }
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
    }

    @ViewBuilder
    private func headline(story: Bool) -> some View {
        switch milestone.kind {
        case .streak:
            Text(milestone.headline)
                .font(.app(story ? 76 : 52, .heavy))
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()
        case .rank(let r):
            HStack(spacing: 12) {
                RankBadge(rank: r, size: story ? 72 : 48)
                Text(r.title)
                    .font(.app(story ? 58 : 42, .heavy))
                    .foregroundStyle(Color.textPrimary)
            }
        case .challenge:
            Text(milestone.headline)
                .font(.app(story ? 54 : 40, .heavy))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 20)
        }
    }
}

/// A milestone: (optionally) the full-screen celebration once, then the card preview with Share, Save to Photos and
/// Not now. Opened from the milestone itself, from Rank up / challenge finished, and from Progress → Milestones.
struct MilestoneShareView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var milestone: PactMilestone
    var celebrate = true
    var onDone: (() -> Void)?

    @State private var celebrating = true
    @State private var format = 0
    @State private var includePhoto = false
    @State private var image: UIImage?
    @State private var proof: UIImage?
    @State private var saving = false
    @State private var saved = false
    @State private var saveError: String?

    var body: some View {
        ZStack {
            if celebrate && celebrating {
                celebration
                    .transition(.opacity)
            } else {
                preview
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.open(0.4), value: celebrating)
        .screenBackground()
        .onAppear {
            proof = model.latestProofPhoto.flatMap(UIImage.init(data:))
            render()
        }
        .onChange(of: format) { _, _ in render() }
        .onChange(of: includePhoto) { _, _ in render() }
    }

    // MARK: Celebration

    private var celebration: some View {
        ZStack {
            OnboardingPage(step: nil, back: nil) {
                VStack(spacing: 14) {
                    Spacer(minLength: 30)
                    SmallLabel(text: celebrationLabel)
                    MilestoneStamp(milestone: milestone)
                    TitleText(celebrationTitle, size: 28)
                    BodyText(celebrationBody)
                        .padding(.horizontal, 16)
                    CoupleScene(left: model.sceneA, right: model.sceneB, leftPose: .cheer, rightPose: .cheer, crop: 0.6)
                        .frame(height: 200)
                    Spacer(minLength: 0)
                }
            } actions: {
                PrimaryButton("See our card") { celebrating = false }
                TextLinkButton("Not now", color: .coral) { close() }
            }
            ConfettiView().ignoresSafeArea().allowsHitTesting(false)
        }
    }

    private var celebrationLabel: String {
        if case .streak = milestone.kind { return "Streak" }
        return "Milestone"
    }

    private var celebrationTitle: String {
        if case .streak(let n) = milestone.kind { return "\(n) days in a row, together" }
        return milestone.headline
    }

    private var celebrationBody: String {
        if case .streak(let n) = milestone.kind {
            return "\(model.nameA) & \(model.nameB), you haven't let each other slide for \(n) days. That's worth a post."
        }
        return milestone.subtitle
    }

    // MARK: Preview

    private var preview: some View {
        OnboardingPage(step: nil, back: nil) {
            VStack(spacing: 14) {
                HStack {
                    CloseButton { close() }
                    Spacer()
                }
                .padding(.horizontal, -8)
                TitleText("Share the moment", size: 28)
                PillSegmentedControl(options: ShareFormat.allCases.map(\.title), selection: $format)
                    .padding(.horizontal, 30)
                previewImage
                if proof != nil {
                    Toggle(isOn: $includePhoto) {
                        Text("Include a proof photo")
                            .font(.app(15, .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .tint(Color.sage)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .card(radius: 14, shadow: false)
                }
                if let saveError {
                    Text(saveError)
                        .font(.app(13))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 8)
        } actions: {
            if let image {
                ShareLink(item: Image(uiImage: image), message: Text(milestone.shareText),
                          preview: SharePreview(milestone.shareText, image: Image(uiImage: image))) {
                    PrimaryButtonLabel(title: "Share")
                }
                SecondaryButton(saved ? "Saved to Photos ✓" : "Save to Photos") {
                    guard !saving, !saved else { return }
                    Task { await save(image) }
                }
            }
            TextLinkButton("Not now", color: .coral) { close() }
        }
    }

    private var previewImage: some View {
        let f = ShareFormat(rawValue: format) ?? .story
        let height: CGFloat = 380
        let scale = height / f.size.height
        return Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.peach
            }
        }
        .frame(width: f.size.width * scale, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
        .shadow(color: Color.coral.opacity(0.15), radius: 14, y: 8)
        .accessibilityLabel("Preview of your share card: \(milestone.headline)")
    }

    // MARK: Actions

    private func render() {
        let f = ShareFormat(rawValue: format) ?? .story
        let card = MilestoneCard(milestone: milestone, card: model.pactCard, map: model.coupleMap, format: f,
                                 photo: includePhoto ? proof : nil)
        let r = ImageRenderer(content: card)
        r.scale = 3          // 360 × 640 pt → 1080 × 1920 px
        r.proposedSize = ProposedViewSize(f.size)
        image = r.uiImage
        saved = false
    }

    /// Asks for "add photos" access only now, when they tap Save.
    private func save(_ image: UIImage) async {
        guard let data = image.pngData() else { return }
        saving = true
        defer { saving = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveError = "To save it, allow Pact to add photos in Settings → Privacy & Security → Photos."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            saveError = nil
            saved = true
            Haptics.success()
        } catch {
            saveError = "Couldn't save the image. Try again, or use Share → Save Image."
        }
    }

    private func close() {
        if let onDone { onDone() } else { dismiss() }
    }
}

/// The big number stamping on (rossark motion: drops from 1.6× with a small overshoot, then settles).
struct MilestoneStamp: View {
    var milestone: PactMilestone
    @State private var play = false

    var body: some View {
        OneShotClock(duration: 900, play: play) { t in
            let p = seg(t, 120, 620)
            content
                .scaleEffect(1.6 - 0.6 * p - 0.06 * bell(seg(t, 520, 900)))
                .rotationEffect(.degrees(-8 * (1 - p)))
                .opacity(min(1, p * 2))
        }
        .frame(height: 140)
        .onAppear {
            play = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 620_000_000)
                Haptics.success()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch milestone.kind {
        case .rank(let r):
            RankBadge(rank: r, size: 130)
        default:
            Text(milestone.headline)
                .font(.app(84, .heavy))
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

/// Progress → "Milestones": every card you've unlocked, to re-share any time.
struct MilestonesCard: View {
    @Environment(AppModel.self) private var model
    @State private var opened: PactMilestone?

    var body: some View {
        let all = model.unlockedMilestones
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.app(19, .bold))
                .foregroundStyle(Color.textPrimary)
            if all.isEmpty {
                Text("Your first one is a 7-day streak. Then you can share it from here any time.")
                    .font(.app(14))
                    .foregroundStyle(Color.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(all) { m in
                            Button { opened = m } label: { tile(m) }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("\(m.headline), \(m.tileLabel). Share")
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, -16)
                .contentMargins(.horizontal, 16, for: .scrollContent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20, shadow: false)
        .sheet(item: $opened) { m in MilestoneShareView(milestone: m, celebrate: false) }
    }

    private func tile(_ m: PactMilestone) -> some View {
        VStack(spacing: 6) {
            Group {
                switch m.kind {
                case .rank(let r): RankBadge(rank: r, size: 40)
                case .streak(let n):
                    Text("\(n)").font(.app(24, .heavy)).foregroundStyle(Color.textPrimary).monospacedDigit()
                case .challenge:
                    Image(systemName: "trophy.fill").font(.system(size: 22)).foregroundStyle(Color.gold)
                }
            }
            .frame(height: 40)
            Text(m.headline)
                .font(.app(12, .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(m.tileLabel)
                .font(.app(11))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(width: 84, height: 104)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.peach))
    }
}
