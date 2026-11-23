import SwiftUI
// AVFoundation predates Swift concurrency annotations: AVCaptureSession is safe to start and stop on our own
// serial queue (Apple's documented pattern), but isn't marked Sendable.
@preconcurrency import AVFoundation
import UIKit

/// 21: full-screen dark camera. Live photo only, never from the photo library.
struct CheckInCameraView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var rule: RuleFact

    @State private var camera = CameraController()
    @State private var captured: UIImage?
    @State private var sending = false
    @State private var showQuotaAlert = false
    @State private var showHonourFallback = false
    @State private var showNoPhoto = false

    /// No usable camera (Simulator, or access denied).
    private var cameraMissing: Bool { AppEnvironment.isSimulator || !camera.isAvailable }

    /// DEBUG only: the shutter makes a sample photo when there is no camera. Never in Release.
    private var useSimulatedCamera: Bool {
        #if DEBUG
        return cameraMissing
        #else
        return false
        #endif
    }

    private var stamp: String {
        let tz = model.me?.tz ?? .current
        return model.stampText(dayNumber: model.isWarmup ? nil : model.myToday?.dayNumber, at: model.now(), tz: tz)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack(alignment: .bottomLeading) {
                Color(hex: 0x1A1412)
                if let captured {
                    Image(uiImage: captured)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .accessibilityLabel("Your photo for \(rule.title)")
                } else if cameraMissing {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.metering.unknown")
                            .font(.system(size: 44))
                        #if DEBUG
                        Text("No camera here. The shutter makes a sample photo.")
                            .font(.app(15))
                            .multilineTextAlignment(.center)
                        #else
                        Text("Allow camera access in Settings to check in with a photo.")
                            .font(.app(15))
                            .multilineTextAlignment(.center)
                        #endif
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    CameraPreview(session: camera.session)
                        .accessibilityLabel("Camera preview")
                }
                StampPill(text: stamp)
                    .padding(16)
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
        .alert("iCloud is full", isPresented: $showQuotaAlert) {
            Button("Check in with an honour tap") { showHonourFallback = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.lastSaveError?.errorDescription ?? "")
        }
        .sheet(isPresented: $showHonourFallback, onDismiss: { dismiss() }) {
            HonourSheet(rule: rule, fallback: true).presentationDetents([.height(430)])
        }
        .sheet(isPresented: $showNoPhoto, onDismiss: {
            if model.myToday?.items.first(where: { $0.rule.id == rule.id })?.isChecked == true { dismiss() }
        }) {
            HonourSheet(rule: rule, withoutPhoto: true).presentationDetents([.height(430)])
        }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.title)
                    .font(.app(24, .bold))
                    .foregroundStyle(.white)
                Text("Live photo · not from your camera roll")
                    .font(.app(13, .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(RuleLibrary.photoPrompt(for: rule))
                    .font(.app(13))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("LIVE")
                .font(.app(15, .bold))
                .foregroundStyle(.white)
                .padding(.leading, 16)
                .padding(.trailing, 44)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.coral))
                .accessibilityLabel("Live camera")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var bottomBar: some View {
        VStack(spacing: 18) {
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
                            .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
                    }
                    PrimaryButton("Send", isLoading: sending) { Task { await send() } }
                }
                .padding(.top, 18)
            } else {
                Text("Snap proof for \(model.partnerName)")
                    .font(.app(16, .medium))
                    .foregroundStyle(Color(hex: 0xF3E6DC))
                    .padding(.top, 16)
                // Proof is optional but recommended, except in challenges that require it (The 75).
                if !model.photoProofRequired {
                    Button("No photo? Check it off") { showNoPhoto = true }
                        .font(.app(14, .semibold))
                        .foregroundStyle(Color(hex: 0xF3E6DC).opacity(0.8))
                        .padding(.top, -8)
                }
                ZStack {
                    HStack {
                        Button("Cancel") { dismiss() }
                            .font(.app(18, .medium))
                            .foregroundStyle(Color(hex: 0xF3E6DC))
                        Spacer()
                        Button {
                            camera.flip()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(.white.opacity(cameraMissing ? 0.3 : 0.9))
                                .frame(width: 44, height: 44)
                        }
                        .disabled(cameraMissing)
                        .accessibilityLabel("Flip camera")
                    }
                    Button {
                        shutter()
                    } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 84, height: 84)
                            Circle().fill(.white).frame(width: 68, height: 68)
                        }
                    }
                    .accessibilityLabel("Take photo")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func shutter() {
        Haptics.tap()
        #if DEBUG
        if useSimulatedCamera {
            if let data = ImageTools.placeholderPhoto(title: rule.title, stamp: ""), let img = UIImage(data: data) {
                captured = img
            }
            return
        }
        #endif
        guard !cameraMissing else { return }
        Task {
            if let img = await camera.capture() { captured = img }
        }
    }

    private func send() async {
        guard let captured, let data = ImageTools.prepareCheckInPhoto(captured, stamp: stamp) else { return }
        sending = true
        let ok = await model.checkIn(rule: rule, photo: data)
        sending = false
        if ok {
            dismiss()
        } else if case .quotaExceeded = model.lastSaveError {
            showQuotaAlert = true
        }
    }
}

/// The dark stamp pill shown on the viewfinder (the same text is burned into the photo).
struct StampPill: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.app(15, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x14100E).opacity(0.92)))
            .accessibilityLabel("Stamp: \(text)")
    }
}

/// AVCaptureSession wrapper: back camera by default, flip, single photo capture.
@Observable
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private var position: AVCaptureDevice.Position = .back
    @ObservationIgnored private var continuation: CheckedContinuation<UIImage?, Never>?
    @ObservationIgnored private let queue = DispatchQueue(label: "camera.session")
    private(set) var isAvailable = AVCaptureDevice.default(for: .video) != nil

    func start() async {
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard granted else {
            isAvailable = false
            return
        }
        configure()
        let session = self.session
        queue.async { session.startRunning() }
    }

    func stop() {
        let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        for input in session.inputs { session.removeInput(input) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        if !session.outputs.contains(output), session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    func flip() {
        position = position == .back ? .front : .back
        configure()
    }

    func capture() async -> UIImage? {
        // The app is portrait-only: rotate the captured photo upright.
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return await withCheckedContinuation { (c: CheckedContinuation<UIImage?, Never>) in
            continuation = c
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        continuation?.resume(returning: image)
        continuation = nil
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
