@preconcurrency import AVFoundation
import UIKit

/// Exports progress photos as a vertical 9:16 timelapse video (1080×1920, H.264) with a small
/// "Pact" watermark. Each photo shows for 0.15 s; the last one holds for a second.
enum TimelapseExporter {
    static let size = CGSize(width: 1080, height: 1920)
    static let secondsPerPhoto: Double = 0.15
    static let finalHold: Double = 1.0

    enum ExportError: Error { case noPhotos, writerFailed }

    static func export(_ images: [UIImage], labels: [String]) async throws -> URL {
        guard !images.isEmpty else { throw ExportError.noPhotos }
        // Render the frames first (UIKit drawing is thread-safe with UIGraphicsImageRenderer).
        let frames: [CGImage] = zip(images, labels.count == images.count ? labels : images.map { _ in "" })
            .compactMap { renderFrame($0.0, label: $0.1) }
        return try await Task.detached(priority: .userInitiated) { try write(frames) }.value
    }

    /// One 1080×1920 frame: the photo (aspect fill), the day label and the watermark.
    static func renderFrame(_ image: UIImage, label: String) -> CGImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(red: 0.99, green: 0.89, blue: 0.85, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let s = image.size
            let scale = max(size.width / max(s.width, 1), size.height / max(s.height, 1))
            let w = s.width * scale, h = s.height * scale
            image.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = 8
            if !label.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFont.uiFont(64, .bold), .foregroundColor: UIColor.white, .shadow: shadow,
                ]
                (label as NSString).draw(at: CGPoint(x: 64, y: 96), withAttributes: attrs)
            }
            let mark: [NSAttributedString.Key: Any] = [
                .font: AppFont.uiFont(40, .semibold), .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .shadow: shadow,
            ]
            let text = Brand.appName as NSString
            let ts = text.size(withAttributes: mark)
            text.draw(at: CGPoint(x: size.width - ts.width - 56, y: size.height - ts.height - 72), withAttributes: mark)
        }
        return rendered.cgImage
    }

    private static func write(_ frames: [CGImage]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Pact-timelapse.mp4")
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        guard writer.canAdd(input) else { throw ExportError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ExportError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        let timescale: CMTimeScale = 600
        let step = CMTime(seconds: secondsPerPhoto, preferredTimescale: timescale)
        var time = CMTime.zero
        // The last frame is appended twice so it holds on screen.
        let sequence = frames + [frames[frames.count - 1]]
        for (i, frame) in sequence.enumerated() {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            guard let buffer = pixelBuffer(frame, pool: adaptor.pixelBufferPool) else { throw ExportError.writerFailed }
            if !adaptor.append(buffer, withPresentationTime: time) { throw ExportError.writerFailed }
            time = i == frames.count - 1 ? time + CMTime(seconds: finalHold, preferredTimescale: timescale) : time + step
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: time)
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw ExportError.writerFailed }
        return url
    }

    private static func pixelBuffer(_ image: CGImage, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        } else {
            CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &buffer)
        }
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                  width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                    | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
