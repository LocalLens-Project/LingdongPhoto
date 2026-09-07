import CoreGraphics


enum FeatureArtworkLayout {
    struct Palette {
        let canvas: CGSize
        let photo: CGRect
        let band: CGRect

        func fitted(in bounds: CGSize) -> Palette {
            let scale = min(max(0, bounds.width) / canvas.width, max(0, bounds.height) / canvas.height)
            let origin = CGPoint(x: (bounds.width - canvas.width * scale) / 2,
                                 y: (bounds.height - canvas.height * scale) / 2)
            func fit(_ rect: CGRect) -> CGRect {
                CGRect(x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale,
                       width: rect.width * scale, height: rect.height * scale)
            }
            return Palette(canvas: bounds, photo: fit(photo), band: fit(band))
        }
    }

    static func validSize(_ size: CGSize?) -> CGSize {
        guard let size, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return CGSize(width: 3, height: 4) }
        return size
    }

    static func palette(imageSize: CGSize?, side: FeaturePaletteSide, bandRatio: Double) -> Palette {
        let size = validSize(imageSize)
        let band = CGFloat(bandRatio.isFinite ? min(max(bandRatio, 0.08), 0.5) : 0.295)
        if side == .bottom {
            let extra = size.height * band / (1 - band)
            return Palette(canvas: CGSize(width: size.width, height: size.height + extra),
                           photo: CGRect(origin: .zero, size: size),
                           band: CGRect(x: 0, y: size.height, width: size.width, height: extra))
        }
        let extra = size.width * band / (1 - band)
        return Palette(canvas: CGSize(width: size.width + extra, height: size.height),
                       photo: CGRect(x: side == .leading ? extra : 0, y: 0, width: size.width, height: size.height),
                       band: CGRect(x: side == .leading ? 0 : size.width, y: 0, width: extra, height: size.height))
    }

    static func aspectRatio(mode: CreationMode, imageSize: CGSize?, side: FeaturePaletteSide,
                            bandRatio: Double) -> CGFloat {
        let size = mode == .paletteCard ? palette(imageSize: imageSize, side: side, bandRatio: bandRatio).canvas
                                       : validSize(imageSize)
        return size.width / size.height
    }

    static func photoFrame(imageSize: CGSize, in bounds: CGSize) -> CGRect {
        let size = validSize(imageSize)
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fit = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: (bounds.width - fit.width) / 2, y: (bounds.height - fit.height) / 2,
                      width: fit.width, height: fit.height)
    }

    static func calendarFrame(in photo: CGRect) -> CGRect {

        let width = min(photo.width * 0.82, photo.height * 0.80 / 1.5)
        return CGRect(x: photo.midX - width / 2, y: photo.midY - width * 1.5 / 2,
                      width: width, height: width * 1.5)
    }
}
