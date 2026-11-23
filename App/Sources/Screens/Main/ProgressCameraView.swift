import SwiftUI
import UIKit

/// "Take today's progress pic": the live camera with Day 1's progress photo as a ghost at ~30% opacity
/// so the pose lines up. Not a rule check-in. One photo per person per day (retaking replaces it).
/// Private unless "Share progress pics with partner" is on.
struct ProgressCameraView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraController()
    @State private var captured: UIImage?
    @State private var saving = false
    @State private var showGhost = true

    private var cameraMissing: Bool { AppEnvironment.isSimulator || !camera.isAvailable }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                Color(hex: 0x1A1412)
                if let captured {
                    Image(uiImage: captured)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .accessibilityLabel("Your progress photo")
                } else if cameraMissing {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.metering.unknown").font(.system(size: 44))
                        #if DEBUG
                        Text("No camera here. The shutter makes a sample photo.")
                            .font(.app(15)).multilineTextAlignment(.center)
                        #else
                        Text("Allow camera access in Settings to take a progress pic.")
                            .font(.app(15)).multilineTextAlignment(.center)
                        #endif
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(40)
                } else {
                    CameraPreview(session: camera.session)
                        .accessibilityLabel("Camera preview")
                }
                // Day 1's photo as a ghost so the pose lines up.
                if captured == nil, showGhost, let ghost = model.ghostProgressImage {
                    Image(uiImage: ghost)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .opacity(0.3)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            bottomBar
        }
        .background(Color(hex: 0x14100E).ignoresSafeArea())
        .statusBarHidden()
        .task {
            guard !cameraMissing else { return }
            await camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's progress pic")
                    .font(.app(24, .bold))
                    .foregroundStyle(.white)
                Text(model.shareProgressPhotos ? "Shared with \(model.partnerName)" : "Private: only you can see it")
                    .font(.app(13, .medium))
                    .foregroundStyle(.white.opacity(0.85))
                if model.ghostProgressImage != nil {
                    Text("Line up with your Day 1 photo.")
                        .font(.app(13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer(minLength: 8)
            if model.ghostProgressImage != nil, captured == nil {
                Button {
                    showGhost.toggle()
                } label: {
                    Text(showGhost ? "Ghost on" : "Ghost off")
                        .font(.app(14, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Capsule().fill(showGhost ? Color.gold : Color.white.opacity(0.2)))
                }
                .accessibilityLabel(showGhost ? "Hide Day 1 overlay" : "Show Day 1 overlay")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if captured != nil {
                HStack(spacing: 12) {
                    Button {
                        captured = nil
                    } label: {
                        Text("Retake")
                            .font(.app(18, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: Metrics.buttonHeight)
                            .background(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                    }
                    PrimaryButton("Save", isLoading: saving) { Task { await save() } }
                        .environment(\.primaryOnDark, true)
                }
                .padding(.top, 18)
            } else {
                ZStack {
                    HStack {
                        Button("Cancel") { dismiss() }
                            .font(.app(18, .medium))
                            .foregroundStyle(Color(hex: 0xF2E6D4))
                        Spacer()
                        Button {
                            camera.flip()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(cameraMissing ? 0.3 : 0.9))
                                .frame(width: 44, height: 44)
                        }
                        .disabled(cameraMissing)
                        .accessibilityLabel("Flip camera")
                    }
                    Button { shutter() } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 84, height: 84)
                            Circle().fill(.white).frame(width: 68, height: 68)
                        }
                    }
                    .accessibilityLabel("Take photo")
                }
                .padding(.top, 18)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func shutter() {
        Haptics.tap()
        #if DEBUG
        if cameraMissing {
            let day = model.myToday?.dayNumber.map { "Day \($0)" } ?? "Warm-up"
            if let data = ImageTools.placeholderPhoto(title: day, stamp: ""), let img = UIImage(data: data) {
                captured = img
            }
            return
        }
        #endif
        guard !cameraMissing else { return }
        Task { if let img = await camera.capture() { captured = img } }
    }

    private func save() async {
        guard let captured else { return }
        saving = true
        let resized = ImageTools.resize(captured, maxSide: 1440)
        guard let data = resized.jpegData(compressionQuality: 0.7) else { saving = false; return }
        await model.saveProgressPhoto(data)
        saving = false
        dismiss()
    }
}
