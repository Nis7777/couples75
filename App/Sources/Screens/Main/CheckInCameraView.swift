import SwiftUI
import AVFoundation
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

    private var useSimulatedCamera: Bool { AppEnvironment.isSimulator || !camera.isAvailable }

    private var stamp: String {
        let tz = model.me?.tz ?? .current
        return model.stampText(dayNumber: model.isWarmup ? nil : model.myToday?.dayNumber, at: model.now(), tz: tz)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let captured {
                Image(uiImage: captured)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Your photo for \(rule.title)")
            } else if useSimulatedCamera {
                VStack(spacing: 12) {
                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 48))
                    Text("No camera here. The shutter makes a sample photo.")
                        .font(.app(14))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(40)
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .accessibilityLabel("Camera preview")
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
        }
        .statusBarHidden()
        .task {
            guard !useSimulatedCamera else { return }
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
            HonourSheet(rule: rule, fallback: true).presentationDetents([.height(320)])
        }
    }

    private var topBar: some View {
        VStack(spacing: 6) {
            HStack {
                Pill(text: "LIVE", fill: .coral)
                Spacer()
            }
            Text(rule.title)
                .font(.rounded(22))
                .foregroundStyle(.white)
            Text("Live photo · not from your camera roll")
                .font(.app(13, .medium))
                .foregroundStyle(.white.opacity(0.8))
            Text(RuleLibrary.photoPrompt(for: rule.libraryKey))
                .font(.app(13))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .top, endPoint: .bottom))
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 14) {
            if captured != nil {
                HStack(spacing: 12) {
                    Button {
                        captured = nil
                    } label: {
                        Text("Retake")
                            .font(.app(17, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
                    }
                    PrimaryButton("Send", isLoading: sending) { Task { await send() } }
                }
            } else {
                Text("Snap proof for \(model.partnerName)")
                    .font(.app(15, .semibold))
                    .foregroundStyle(.white)
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.app(17, .medium))
                        .foregroundStyle(.white)
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    Button {
                        shutter()
                    } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                            Circle().fill(.white).frame(width: 64, height: 64)
                        }
                    }
                    .accessibilityLabel("Take photo")
                    Spacer()
                    Button {
                        camera.flip()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .disabled(useSimulatedCamera)
                    .accessibilityLabel("Flip camera")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 20)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
    }

    private func shutter() {
        Haptics.tap()
        if useSimulatedCamera {
            if let data = ImageTools.placeholderPhoto(title: rule.title, stamp: ""), let img = UIImage(data: data) {
                captured = img
            }
            return
        }
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
