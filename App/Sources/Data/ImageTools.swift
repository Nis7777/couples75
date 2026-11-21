import UIKit

enum ImageTools {
    /// Burns the stamp into the bottom-left corner, resizes to max 1080 px on the long side and
    /// compresses to JPEG, aiming for ~150 KB.
    static func prepareCheckInPhoto(_ image: UIImage, stamp: String) -> Data? {
        let resized = resize(image, maxSide: 1080)
        let stamped = burnStamp(stamp, into: resized)
        var quality: CGFloat = 0.6
        var data = stamped.jpegData(compressionQuality: quality)
        while let d = data, d.count > 180_000, quality > 0.25 {
            quality -= 0.1
            data = stamped.jpegData(compressionQuality: quality)
        }
        return data
    }

    static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Dark pill with white text, bottom left: "DAY 14 · SAT 21 NOV · 07:14".
    static func burnStamp(_ text: String, into image: UIImage) -> UIImage {
        let size = image.size
        let fontSize = max(14, size.width * 0.032)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: AppFont.uiFont(fontSize, .bold),
            .foregroundColor: UIColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let padH = fontSize * 0.8, padV = fontSize * 0.45
        let margin = size.width * 0.04
        let pill = CGRect(x: margin, y: size.height - margin - textSize.height - padV * 2,
                          width: textSize.width + padH * 2, height: textSize.height + padV * 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            UIColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 0.9).setFill()
            UIBezierPath(roundedRect: pill, cornerRadius: pill.height * 0.28).fill()
            (text as NSString).draw(at: CGPoint(x: pill.minX + padH, y: pill.minY + padV), withAttributes: attrs)
        }
    }

    /// Generated photo for the Simulator / Mock mode (no camera).
    static func placeholderPhoto(title: String, stamp: String) -> Data? {
        let size = CGSize(width: 1080, height: 1440)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let colors = [UIColor(red: 0.99, green: 0.89, blue: 0.85, alpha: 1).cgColor,
                          UIColor(red: 0.91, green: 0.65, blue: 0.29, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
                                         locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height),
                                                 options: [])
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .heavy),
                .foregroundColor: UIColor(red: 0.16, green: 0.09, blue: 0.08, alpha: 1),
            ]
            let s = title as NSString
            let ts = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: size.height * 0.42), withAttributes: attrs)
            let small: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
                .foregroundColor: UIColor(red: 0.29, green: 0.2, blue: 0.17, alpha: 1),
            ]
            let note = "Simulator photo" as NSString
            let ns = note.size(withAttributes: small)
            note.draw(at: CGPoint(x: (size.width - ns.width) / 2, y: size.height * 0.42 + ts.height + 24),
                      withAttributes: small)
        }
        return prepareCheckInPhoto(image, stamp: stamp)
    }
}
