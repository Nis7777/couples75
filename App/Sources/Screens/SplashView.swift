import SwiftUI

/// The opening animation. Its first frame is identical to the launch screen (Info.plist `UILaunchScreen`:
/// `LaunchPeach` background, the `LaunchLogo` icon at 120 pt centred on the full screen), so there is no
/// blank flash. Then (~1.2 s): the 75 + heart logo scales up with a gentle spring, the two avatars slide in
/// from the left and right and meet in the middle (light haptic), and everything cross-fades into the app.
/// With Reduce Motion it only fades. It never holds the user longer than ~1.5 s.
struct SplashView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onDone: () -> Void

    static let logoSize: CGFloat = 120

    @State private var logoScale: CGFloat = 1
    @State private var avatarsIn = false
    @State private var fading = false

    private var me: Avatar { model.me?.avatar ?? model.draft.avatar }
    /// The partner's avatar, or nil for the dashed outline (not joined and not built on A's phone yet).
    private var partner: Avatar? {
        if let p = model.partner, p.joinedAt != nil { return p.avatar }
        return model.facts.couple?.invitedAvatar ?? model.draft.partnerAvatar
    }

    var body: some View {
        GeometryReader { geo in
            let offscreen = geo.size.width * 0.75
            ZStack {
                Color("LaunchPeach")
                Image("LaunchLogo")
                    .resizable()
                    .frame(width: Self.logoSize, height: Self.logoSize)
                    .scaleEffect(logoScale)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                if !reduceMotion {
                    HStack(alignment: .bottom, spacing: -24) {
                        CharacterView(avatar: me, pose: .bust)
                            .frame(height: 150)
                            .offset(x: avatarsIn ? 0 : -offscreen)
                            .zIndex(1)
                        Group {
                            if let partner {
                                CharacterView(avatar: partner, pose: .bust)
                                    .frame(height: 150)
                            } else {
                                Image("partner_outline")
                                    .resizable().scaledToFit()
                                    .frame(height: 240, alignment: .top)
                                    .frame(height: 150, alignment: .top)
                                    .clipped()
                            }
                        }
                        .offset(x: avatarsIn ? 0 : offscreen)
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + Self.logoSize * 0.6 + 95)
                }
            }
            .opacity(fading ? 0 : 1)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(!fading)
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.easeOut(duration: 0.25)) { fading = true }
            try? await Task.sleep(nanoseconds: 260_000_000)
            onDone()
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { logoScale = 1.18 }
        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { avatarsIn = true }
        try? await Task.sleep(nanoseconds: 520_000_000)
        Haptics.light()                         // the avatars meet
        try? await Task.sleep(nanoseconds: 220_000_000)
        withAnimation(.easeInOut(duration: 0.32)) { fading = true }
        try? await Task.sleep(nanoseconds: 330_000_000)
        onDone()                                // ≈ 1.2 s in total
    }
}
