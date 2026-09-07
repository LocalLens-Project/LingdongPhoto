import ImageIO
import SwiftUI
import UIKit

enum PiaogenceCodeRenderer {

    static func barcodeImage(text: String, foreground: UIColor) -> UIImage? {
        try? TicketCodeRenderer.barcodeImage(
            value: text,
            pixelSize: CGSize(width: 1_200, height: 400),
            foregroundColor: foreground,
            backgroundColor: nil
        )
    }

    static func qrImage(text: String, foreground: UIColor) -> UIImage? {
        try? TicketCodeRenderer.qrImage(
            value: text,
            pixelSize: CGSize(width: 900, height: 900),
            foregroundColor: foreground,
            backgroundColor: nil
        )
    }
}

enum TicketArtworkImageQuality: String {
    case full
    case thumbnail
}

@MainActor
private final class TicketArtworkImageCache {
    static let shared = TicketArtworkImageCache()

    private let images = NSCache<NSString, UIImage>()

    private init() {
        images.countLimit = 72
        images.totalCostLimit = 48 * 1_024 * 1_024
    }

    func image(for ticket: TicketStub, quality: TicketArtworkImageQuality) -> UIImage? {
        guard let data = ticket.artworkImageData else { return nil }
        let key = "\(ticket.id.uuidString)-\(quality.rawValue)-\(data.count)" as NSString
        if let cached = images.object(forKey: key) { return cached }

        let image: UIImage?
        switch quality {
        case .full:
            image = UIImage(data: data)
        case .thumbnail:
            image = downsampledImage(from: data, maxPixelSize: 520)
        }

        if let image {
            let pixelWidth = Int(image.size.width * image.scale)
            let pixelHeight = Int(image.size.height * image.scale)
            images.setObject(image, forKey: key, cost: pixelWidth * pixelHeight * 4)
        }
        return image
    }

    private func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: image)
    }
}

struct PiaogenceTicketMask: View {
    let layout: PiaogenceLayoutStyle

    var body: some View {
        GeometryReader { proxy in
            Path(Self.maskPath(
                in: CGRect(origin: .zero, size: proxy.size),
                layout: layout
            ))
            .fill(Color.white, style: FillStyle(eoFill: true, antialiased: true))
        }
    }

    static func maskPath(in bounds: CGRect, layout: PiaogenceLayoutStyle) -> CGPath {
        let cornerRadius: CGFloat
        switch layout {
        case .classic:
            cornerRadius = max(12, bounds.width * 0.024)
        case .vertical:
            cornerRadius = max(18, bounds.width * 0.060)
        }
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        if layout == .classic {
            let notchDiameter = max(18, bounds.height * 0.20)
            let notchCenter = CGPoint(x: bounds.maxX + notchDiameter * 0.02, y: bounds.midY)
            path.append(UIBezierPath(ovalIn: CGRect(
                x: notchCenter.x - notchDiameter / 2,
                y: notchCenter.y - notchDiameter / 2,
                width: notchDiameter,
                height: notchDiameter
            )))
        }
        path.usesEvenOddFillRule = true
        return path.cgPath
    }
}

private struct TicketScallopedPanel: View {
    let color: Color
    let scallopCount: Int

    var body: some View {
        Canvas { context, size in
            let count = max(1, scallopCount)
            let step = size.height / CGFloat(count)

            let radius = step * 0.50
            let panelRect = CGRect(x: 0, y: 0, width: size.width - radius, height: size.height)
            context.fill(Path(panelRect), with: .color(color))
            for index in 0..<count {
                let centerY = (CGFloat(index) + 0.5) * step
                let scallop = CGRect(
                    x: size.width - radius * 2,
                    y: centerY - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: scallop), with: .color(color))
            }
        }
    }
}

struct TicketArtworkView: View {
    let ticket: TicketStub

    var codeStyle: TicketCodeStyleOverride?
    var artworkImageQuality: TicketArtworkImageQuality = .full

    enum TicketCodeStyleOverride {
        case barcode
        case verificationQR
    }

    private var resolvedCodeStyle: TicketCodeStyleOverride {
        if let codeStyle { return codeStyle }

        if let stored = ticket.codeStyle {
            return stored == .verificationQR ? .verificationQR : .barcode
        }
        return ticket.layout == .classic ? .barcode : .verificationQR
    }

    private var colors: [PiaogenceRGBColor] {
        return ticket.palette.isEmpty ? PiaogenceRGBColor.fallback : ticket.palette
    }

    private var darkestColor: PiaogenceRGBColor {
        colors.min(by: { $0.relativeLuminance < $1.relativeLuminance }) ?? PiaogenceRGBColor.fallback[3]
    }

    private func readableForeground(preferred: PiaogenceRGBColor, background: PiaogenceRGBColor) -> PiaogenceRGBColor {
        guard preferred.contrastRatio(with: background) < 4.5 else { return preferred }
        let black = PiaogenceRGBColor(red: 0.035, green: 0.035, blue: 0.035)
        let white = PiaogenceRGBColor(red: 0.965, green: 0.965, blue: 0.965)
        return black.contrastRatio(with: background) >= white.contrastRatio(with: background)
            ? black : white
    }

    var body: some View {
        if ticket.isArchivedWork {
            archivedWorkArtwork
        } else if ticket.isPhysicalImport {
            PhysicalMemoryTicketView(ticket: ticket)
        } else {
            templatedArtwork
        }
    }

    @ViewBuilder
    private var archivedWorkArtwork: some View {
        if let image = TicketArtworkImageCache.shared.image(
            for: ticket,
            quality: artworkImageQuality
        ) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            templatedArtwork
        }
    }

    private var templatedArtwork: some View {
        GeometryReader { proxy in
            Group {
                switch ticket.layout {
                case .classic:
                    classicTravelTicket(size: proxy.size)
                        .mask { PiaogenceTicketMask(layout: .classic) }
                case .vertical:
                    verticalTravelTicket(size: proxy.size)
                        .mask { PiaogenceTicketMask(layout: .vertical) }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(ticket.layout.aspectRatio, contentMode: .fit)
    }

    private func primaryPhoto(size: CGSize, cornerRadius: CGFloat) -> some View {
        Group {

            if let image = TicketArtworkImageCache.shared.image(
                for: ticket,
                quality: artworkImageQuality
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                SceneArtView(theme: ticket.theme, seed: seedValue)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if ticket.isPhysicalImport {
                HStack(spacing: 5) {
                    Image(systemName: ticket.physicalTicketType?.symbol ?? "ticket.fill")
                    Text(ticket.ticketEdition == .collector ? "COLLECTOR" : "实体票重生".appLocalized)
                    if let colorName = ticket.ticketColorName {
                        Text("· \(colorName)")
                    }
                }
                .font(.system(size: max(7, size.width * 0.021), weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, max(7, size.width * 0.024))
                .padding(.vertical, max(5, size.width * 0.014))
                .background(.black.opacity(0.48), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(ticket.ticketEdition == .collector ? 0.46 : 0.18), lineWidth: 0.7))
                .padding(max(7, size.width * 0.025))
            }
        }
    }

    private var seedValue: UInt64 {
        UInt64(abs(ticket.ticketID.hashValue % 99991)) + 7
    }

    private func classicTravelTicket(size: CGSize) -> some View {
        let dominant = colors[0]
        let themeBrightness: CGFloat
        if dominant.relativeLuminance < 0.18 {
            themeBrightness = 0.10
        } else if dominant.relativeLuminance < 0.48 {
            themeBrightness = 0.26
        } else {
            themeBrightness = -0.06
        }
        let background = dominant.adjusted(brightness: themeBrightness, saturation: -0.38)
        let foreground = readableForeground(preferred: darkestColor, background: background)
        let contentInset = max(8, size.width * 0.026)
        let ticketHeight = size.height
        let ticketWidth = size.width
        let stubWidth = ticketWidth * (resolvedCodeStyle == .verificationQR ? 0.335 : 0.285)
        let referenceHeight = size.width * 9.0 / 21.0
        let heightScale = max(1.0, size.height / referenceHeight)
        let fontScaleFactor = sqrt(heightScale)
        let verticalPadding = contentInset * 0.80 * heightScale
        let scallopRadius = ticketHeight / CGFloat(max(1, 7)) * 0.50
        let textMaxWidth = stubWidth - scallopRadius - contentInset * 0.80 * 2

        return ZStack(alignment: .leading) {
            primaryPhoto(size: CGSize(width: ticketWidth, height: ticketHeight), cornerRadius: 0)

            TicketScallopedPanel(color: background.color, scallopCount: 7)
                .frame(width: stubWidth, height: ticketHeight)

            VStack(alignment: .center, spacing: max(3, size.height * 0.018 * heightScale)) {
                if let headerTitle = ticket.headerTitle, !headerTitle.isEmpty {
                    Text(headerTitle)
                        .font(.system(
                            size: max(9, size.width * 0.027) * fontScaleFactor,
                            weight: .black,
                            design: .rounded
                        ))
                        .lineLimit(3)
                        .minimumScaleFactor(0.62)
                        .multilineTextAlignment(.center)
                        .tracking(max(0.6, size.width * 0.003))
                        .frame(width: textMaxWidth)
                }

                Text(ticket.title)
                    .font(.system(
                        size: max(7, size.width * 0.014) * fontScaleFactor,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .lineLimit(3)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(foreground.color.opacity(0.72))
                    .frame(width: textMaxWidth)

                VStack(alignment: .center, spacing: max(2, size.height * 0.007 * heightScale)) {
                    Text(ticket.captureTimeText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                    Text("NO.\(ticket.ticketID.replacingOccurrences(of: "LD-", with: ""))")
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Text(String(ticket.fingerprint.suffix(8)))
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
                .font(.system(
                    size: max(6, size.width * 0.0108) * fontScaleFactor,
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(foreground.color.opacity(0.70))
                .frame(width: textMaxWidth)

                Spacer(minLength: 2)

                ticketCode(
                    availableSize: CGSize(
                        width: stubWidth - contentInset * 1.85,
                        height: resolvedCodeStyle == .barcode
                            ? ticketHeight * 0.24
                            : ticketHeight * 0.47
                    ),
                    foreground: foreground
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .foregroundStyle(foreground.color)
            .padding(.horizontal, contentInset * 0.80)
            .padding(.top, verticalPadding + (heightScale > 1.0 ? contentInset * 0.3 * (heightScale - 1.0) : 0))
            .padding(.bottom, verticalPadding)
            .frame(width: stubWidth, height: ticketHeight, alignment: .center)
        }
        .frame(width: ticketWidth, height: ticketHeight)
    }

    private func verticalTravelTicket(size: CGSize) -> some View {
        let dominant = colors[0]
        let background = dominant.adjusted(
            brightness: dominant.relativeLuminance < 0.18
                ? 0.10
                : (dominant.relativeLuminance < 0.48 ? 0.24 : -0.05),
            saturation: -0.30
        )
        let foreground = readableForeground(preferred: darkestColor, background: background)
        let inset: CGFloat = 0
        let photoHeight = size.height * 0.52

        return VStack(spacing: 0) {
            primaryPhoto(size: CGSize(width: size.width - inset * 2, height: photoHeight), cornerRadius: 0)
                .overlay(alignment: .topTrailing) {
                    Text(ticket.ticketID)
                        .font(.system(
                            size: max(7, size.width * 0.024),
                            weight: .bold,
                            design: .monospaced
                        ))
                        .foregroundStyle(.white.opacity(0.90))
                        .shadow(color: .black.opacity(0.48), radius: 6, y: 2)
                        .padding(max(9, size.width * 0.040))
                }

            VStack(alignment: .leading, spacing: max(8, size.height * 0.014)) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(ticket.title)
                            .font(.system(
                                size: max(11, size.width * 0.050),
                                weight: .bold,
                                design: .rounded
                            ))
                            .lineLimit(2)
                        if let subtitle = ticket.subtitle {
                            Text(subtitle)
                                .font(.system(size: max(7, size.width * 0.025), weight: .medium))
                                .lineLimit(2)
                                .foregroundStyle(foreground.color.opacity(0.60))
                        }
                    }

                    Spacer(minLength: 4)

                    ticketCode(
                        availableSize: CGSize(
                            width: size.width * 0.30,
                            height: resolvedCodeStyle == .barcode
                                ? size.height * 0.10
                                : size.width * 0.30
                        ),
                        foreground: foreground
                    )
                }

                Divider()
                    .overlay(foreground.color.opacity(0.18))

                HStack(spacing: 8) {
                    ticketInfoLabel(title: "DATE", value: ticket.captureTimeText)
                    ticketInfoLabel(title: "CAMERA", value: ticket.device ?? "未公开")
                }

                ticketPaletteDots
            }
            .foregroundStyle(foreground.color)
            .padding(max(12, size.width * 0.050))
            .frame(maxHeight: .infinity)
            .background(background.color)
        }
        .frame(width: size.width - inset * 2, height: size.height - inset * 2)
    }

    private func renderedCodeImage(foreground: PiaogenceRGBColor) -> (image: UIImage?, aspect: CGFloat) {
        let uiForeground = UIColor(
            red: foreground.red, green: foreground.green, blue: foreground.blue, alpha: 1)
        switch resolvedCodeStyle {
        case .barcode:

            let barcodeText = ticket.barcodeValue
                ?? ticket.ticketID.replacingOccurrences(of: "LD-", with: "")
            return (PiaogenceCodeRenderer.barcodeImage(
                text: barcodeText,
                foreground: uiForeground), 1200.0 / 400.0)
        case .verificationQR:

            let qrText = ticket.qrPayload
                ?? "lingdong://ticket/\(ticket.ticketID)?fp=\(ticket.fingerprint)"
            return (PiaogenceCodeRenderer.qrImage(
                text: qrText,
                foreground: uiForeground), 1)
        }
    }

    @ViewBuilder
    private func ticketCode(availableSize: CGSize, foreground: PiaogenceRGBColor) -> some View {
        let rendered = renderedCodeImage(foreground: foreground)
        if let image = rendered.image {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(rendered.aspect, contentMode: .fit)
                .frame(maxWidth: availableSize.width, maxHeight: availableSize.height)
        } else {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .frame(width: min(availableSize.width, 44),
                       height: min(availableSize.height, 44))
        }
    }

    private var ticketPaletteDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color.color)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white.opacity(0.42), lineWidth: 0.6))
            }
        }
        .accessibilityLabel("照片的六种代表色")
    }

    private func ticketInfoLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .opacity(0.46)
            Text(value)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("票根作品") {
    VStack(spacing: 24) {
        if let first = TicketStore.shared.cityTickets.first {
            TicketArtworkView(ticket: first)
                .frame(width: 300)
        } else {
            Text("票根集为空")
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.95, green: 0.94, blue: 0.92))
}
