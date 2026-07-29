// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ImageIO
import SwiftUI
import UIKit

/// The single source of truth for the visible ticket silhouette.
///
/// SwiftUI uses this geometry for the live preview, while the exporter applies
/// the same path to the rendered bitmap. The bitmap pass is intentional:
/// `ImageRenderer` can preserve the RGB values outside a SwiftUI mask even when
/// those pixels should have zero alpha.
struct TicketArtworkMask: View {
    let layout: TicketLayoutStyle

    var body: some View {
        GeometryReader { proxy in
            Path(TicketArtworkGeometry.maskPath(
                in: CGRect(origin: .zero, size: proxy.size),
                layout: layout
            ))
            .fill(
                Color.white,
                style: FillStyle(eoFill: true, antialiased: true)
            )
        }
    }
}

enum TicketArtworkAlphaMask {
    static func applying(
        to image: UIImage,
        layout: TicketLayoutStyle
    ) -> UIImage? {
        guard layout != .minimal,
              image.size.width > 0,
              image.size.height > 0 else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        format.preferredRange = .standard
        let bounds = CGRect(origin: .zero, size: image.size)
        let path = TicketArtworkGeometry.maskPath(
            in: bounds,
            layout: layout
        )
        return UIGraphicsImageRenderer(
            size: image.size,
            format: format
        ).image { renderer in
            renderer.cgContext.addPath(path)
            renderer.cgContext.clip(using: .evenOdd)
            image.draw(in: bounds, blendMode: .copy, alpha: 1)
        }
    }

    /// Checks the four outer corner pixels and, for the classic ticket, the
    /// right-hand punched notch. It also checks an interior pixel so a fully
    /// transparent render can never pass accidentally.
    static func hasExpectedTransparency(
        _ image: UIImage,
        layout: TicketLayoutStyle
    ) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        return hasExpectedTransparency(cgImage, layout: layout)
    }

    static func hasExpectedTransparency(
        pngData: Data,
        layout: TicketLayoutStyle
    ) -> Bool {
        guard let source = CGImageSourceCreateWithData(
            pngData as CFData,
            nil
        ),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return false
        }
        return hasExpectedTransparency(image, layout: layout)
    }

    private static func hasExpectedTransparency(
        _ image: CGImage,
        layout: TicketLayoutStyle
    ) -> Bool {
        guard layout != .minimal,
              image.width > 2,
              image.height > 2 else {
            return true
        }

        var transparentPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: image.width - 1, y: 0),
            CGPoint(x: 0, y: image.height - 1),
            CGPoint(x: image.width - 1, y: image.height - 1)
        ]
        if layout == .classic {
            transparentPoints.append(
                CGPoint(x: image.width - 1, y: image.height / 2)
            )
        }

        let cutoutsAreTransparent = transparentPoints.allSatisfy { point in
            guard let alpha = alpha(
                in: image,
                x: Int(point.x),
                y: Int(point.y)
            ) else {
                return false
            }
            return alpha <= 3
        }
        guard cutoutsAreTransparent,
              let interiorAlpha = alpha(
                in: image,
                x: image.width / 2,
                y: image.height / 2
              ) else {
            return false
        }
        return interiorAlpha >= 250
    }

    private static func alpha(
        in image: CGImage,
        x: Int,
        y: Int
    ) -> UInt8? {
        var pixel = [UInt8](repeating: 0, count: 4)
        return pixel.withUnsafeMutableBytes { bytes in
            guard let address = bytes.baseAddress,
                  let context = CGContext(
                    data: address,
                    width: 1,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                  ) else {
                return nil
            }
            context.setBlendMode(.copy)
            context.interpolationQuality = .none
            context.translateBy(x: -CGFloat(x), y: -CGFloat(y))
            context.draw(
                image,
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: image.width,
                    height: image.height
                )
            )
            return bytes[3]
        }
    }
}

private enum TicketArtworkGeometry {
    static func maskPath(
        in bounds: CGRect,
        layout: TicketLayoutStyle
    ) -> CGPath {
        let cornerRadius: CGFloat
        switch layout {
        case .classic:
            cornerRadius = max(12, bounds.width * 0.024)
        case .vertical:
            cornerRadius = max(18, bounds.width * 0.060)
        case .minimal:
            cornerRadius = 0
        }

        let path = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cornerRadius
        )
        if layout == .classic {
            let notchDiameter = max(18, bounds.height * 0.20)
            let notchCenter = CGPoint(
                x: bounds.maxX + notchDiameter * 0.02,
                y: bounds.midY
            )
            path.append(UIBezierPath(
                ovalIn: CGRect(
                    x: notchCenter.x - notchDiameter / 2,
                    y: notchCenter.y - notchDiameter / 2,
                    width: notchDiameter,
                    height: notchDiameter
                )
            ))
        }
        path.usesEvenOddFillRule = true
        return path.cgPath
    }
}
