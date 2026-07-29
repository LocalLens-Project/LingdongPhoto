// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum TicketCodeRenderer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func image(
        for style: TicketCodeStyle,
        payload: TicketPayload,
        baseURLString: String = TicketEnvelope.configuredBaseURLString,
        pixelSize: CGSize,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor? = nil
    ) throws -> UIImage {
        switch style {
        case .barcode:
            return try barcodeImage(
                value: TicketEnvelope.barcodeValue(for: payload),
                pixelSize: pixelSize,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
        case .verificationQR:
            let url = try TicketEnvelope.invocationURL(
                for: payload,
                baseURLString: baseURLString
            )
            return try qrImage(
                value: url.absoluteString,
                pixelSize: pixelSize,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
        }
    }

    static func exportCard(
        for style: TicketCodeStyle,
        payload: TicketPayload,
        baseURLString: String = TicketEnvelope.configuredBaseURLString
    ) throws -> UIImage {
        let canvasSize = style == .barcode
            ? CGSize(width: 1_600, height: 920)
            : CGSize(width: 1_260, height: 1_520)
        let codeSize = style == .barcode
            ? CGSize(width: 1_260, height: 300)
            : CGSize(width: 760, height: 760)
        let colors = payload.palette.prefix(3).map { UIColor(ticketHex: $0.hex).cgColor }
        let baseColor = colors.first.map(UIColor.init(cgColor:))
            ?? UIColor(red: 0.72, green: 0.86, blue: 0.76, alpha: 1)
        let codeColor: UIColor = baseColor.ticketLuminance > 0.52 ? .black : .white
        let gradientColors: [CGColor] = colors.isEmpty
            ? [
                baseColor.ticketMixed(with: .white, amount: 0.18).cgColor,
                baseColor.ticketMixed(with: .black, amount: 0.08).cgColor
            ]
            : colors.map {
                UIColor(cgColor: $0)
                    .ticketMixed(
                        with: baseColor.ticketLuminance > 0.52 ? .white : .black,
                        amount: 0.08
                    )
                    .cgColor
            }
        let code = try image(
            for: style,
            payload: payload,
            baseURLString: baseURLString,
            pixelSize: codeSize,
            foregroundColor: codeColor,
            backgroundColor: nil
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { renderer in
            let context = renderer.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: gradientColors as CFArray,
                locations: nil
            )
            context.drawLinearGradient(
                gradient ?? CGGradient(
                    colorsSpace: colorSpace,
                    colors: [UIColor.systemTeal.cgColor, UIColor.systemIndigo.cgColor] as CFArray,
                    locations: nil
                )!,
                start: .zero,
                end: CGPoint(x: canvasSize.width, y: canvasSize.height),
                options: []
            )

            let titleStyle = NSMutableParagraphStyle()
            titleStyle.alignment = .center
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: style == .barcode ? 54 : 48, weight: .bold),
                .foregroundColor: codeColor,
                .paragraphStyle: titleStyle
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: codeColor.withAlphaComponent(0.62),
                .paragraphStyle: titleStyle
            ]
            NSString(string: style.title).draw(
                in: CGRect(x: 120, y: 130, width: canvasSize.width - 240, height: 72),
                withAttributes: titleAttributes
            )
            NSString(string: payload.ticketID).draw(
                in: CGRect(x: 120, y: 208, width: canvasSize.width - 240, height: 46),
                withAttributes: subtitleAttributes
            )

            let codeRect: CGRect
            if style == .barcode {
                codeRect = CGRect(
                    x: (canvasSize.width - codeSize.width) / 2,
                    y: 330,
                    width: codeSize.width,
                    height: codeSize.height
                )
            } else {
                codeRect = CGRect(
                    x: (canvasSize.width - codeSize.width) / 2,
                    y: 310,
                    width: codeSize.width,
                    height: codeSize.height
                )
            }
            code.draw(in: codeRect)

            let note = style == .barcode
                ? "真实票根编号 · 不包含照片与拍摄隐私"
                : "扫描以查看色盘、拍摄信息与文案"
            let noteAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .medium),
                .foregroundColor: codeColor.withAlphaComponent(0.66),
                .paragraphStyle: titleStyle
            ]
            NSString(string: note).draw(
                in: CGRect(
                    x: 110,
                    y: codeRect.maxY + 54,
                    width: canvasSize.width - 220,
                    height: 80
                ),
                withAttributes: noteAttributes
            )
        }
    }

    private static func barcodeImage(
        value: String,
        pixelSize: CGSize,
        foregroundColor: UIColor,
        backgroundColor: UIColor?
    ) throws -> UIImage {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(value.utf8)
        filter.quietSpace = 12
        guard let output = filter.outputImage else {
            throw TicketEnvelopeError.corruptedPayload
        }
        return try rasterized(
            colored(
                output,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            ),
            targetSize: pixelSize,
            padding: UIEdgeInsets(top: 22, left: 30, bottom: 22, right: 30),
            backgroundColor: backgroundColor,
            stretchesVertically: true
        )
    }

    private static func qrImage(
        value: String,
        pixelSize: CGSize,
        foregroundColor: UIColor,
        backgroundColor: UIColor?
    ) throws -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else {
            throw TicketEnvelopeError.corruptedPayload
        }
        return try rasterized(
            colored(
                output,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            ),
            targetSize: pixelSize,
            padding: UIEdgeInsets(top: 34, left: 34, bottom: 34, right: 34),
            backgroundColor: backgroundColor
        )
    }

    private static func colored(
        _ image: CIImage,
        foregroundColor: UIColor,
        backgroundColor: UIColor?
    ) -> CIImage {
        let filter = CIFilter.falseColor()
        filter.inputImage = image
        filter.color0 = CIColor(color: foregroundColor)
        filter.color1 = CIColor(color: backgroundColor ?? .clear)
        return filter.outputImage ?? image
    }

    private static func rasterized(
        _ image: CIImage,
        targetSize: CGSize,
        padding: UIEdgeInsets,
        backgroundColor: UIColor?,
        stretchesVertically: Bool = false
    ) throws -> UIImage {
        let availableWidth = max(1, targetSize.width - padding.left - padding.right)
        let availableHeight = max(1, targetSize.height - padding.top - padding.bottom)
        let uniformScale = max(
            1,
            floor(min(
                availableWidth / image.extent.width,
                availableHeight / image.extent.height
            ))
        )
        let horizontalScale = stretchesVertically
            ? max(1, floor(availableWidth / image.extent.width))
            : uniformScale
        let verticalScale = stretchesVertically
            ? max(1, floor(availableHeight / image.extent.height))
            : uniformScale
        let transformed = image.transformed(
            by: CGAffineTransform(
                scaleX: horizontalScale,
                y: verticalScale
            )
        )
        guard let cgImage = context.createCGImage(
            transformed,
            from: transformed.extent.integral
        ) else {
            throw TicketEnvelopeError.corruptedPayload
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = backgroundColor != nil
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { renderer in
            if let backgroundColor {
                backgroundColor.setFill()
                renderer.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            } else {
                renderer.cgContext.clear(CGRect(origin: .zero, size: targetSize))
            }
            let drawSize = CGSize(width: cgImage.width, height: cgImage.height)
            let rect = CGRect(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ).integral
            renderer.cgContext.interpolationQuality = .none
            renderer.cgContext.draw(cgImage, in: rect)
        }
    }
}

private extension UIColor {
    convenience init(ticketHex value: String) {
        let cleaned = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var number: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&number)
        self.init(
            red: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }

    var ticketLuminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0.5
        }
        return red * 0.299 + green * 0.587 + blue * 0.114
    }

    func ticketMixed(with color: UIColor, amount: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var otherRed: CGFloat = 0
        var otherGreen: CGFloat = 0
        var otherBlue: CGFloat = 0
        var otherAlpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              color.getRed(
                &otherRed,
                green: &otherGreen,
                blue: &otherBlue,
                alpha: &otherAlpha
              ) else {
            return self
        }
        let value = min(max(amount, 0), 1)
        return UIColor(
            red: red + (otherRed - red) * value,
            green: green + (otherGreen - green) * value,
            blue: blue + (otherBlue - blue) * value,
            alpha: alpha + (otherAlpha - alpha) * value
        )
    }
}
