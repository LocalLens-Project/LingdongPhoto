import CoreImage
import UIKit

@MainActor
enum SpectrumWallpaperRenderer {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let context = CIContext(options: [
        .workingColorSpace: colorSpace,
        .outputColorSpace: colorSpace,
        .cacheIntermediates: false
    ])
    private static let regularCache = NSMapTable<UIImage, UIImage>(
        keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory
    )
    private static let gentleCache = NSMapTable<UIImage, UIImage>(
        keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory
    )

    static func gradient(from image: UIImage, gentle: Bool = true) -> UIImage? {
        let cache = gentle ? gentleCache : regularCache
        if let cached = cache.object(forKey: image) { return cached }
        guard image.size.width.isFinite, image.size.height.isFinite,
              image.size.width > 0, image.size.height > 0 else { return nil }

        let scale = 192 / max(image.size.width, image.size.height)
        let size = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let pixels = thumbnail.cgImage else { return nil }
        let source = CIImage(cgImage: pixels)
        let radius = min(size.width, size.height) * (gentle ? 0.30 : 0.20)
        let smoothed = source.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: source.extent)
        guard let output = context.createCGImage(
            smoothed, from: source.extent, format: .RGBA8, colorSpace: colorSpace
        ) else { return nil }
        let result = UIImage(cgImage: output)
        cache.setObject(result, forKey: image)
        return result
    }
}
