// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct ArtworkCanvas: View {
    let mode: CreationMode
    let images: [UIImage]
    let palette: [RGBColor]
    let palettePercentages: [Double]
    let ratio: ArtworkRatio
    let showHexValues: Bool
    let showPalettePercentages: Bool
    let showDeviceInfo: Bool
    let showBubbles: Bool
    var cameraWatermarkImage: UIImage? = nil
    let gentleBackground: Bool
    let imageScale: CGFloat
    let imageOffset: CGSize
    var metadata: PhotoMetadata = .empty
    var showMissingCaptureTime = true
    var copy: ArtworkCopy = ArtworkCopy()
    var fontStyle: ArtworkFontStyle = .rounded
    var templateStyle: ArtworkTemplateStyle = .classic
    var motionCardHeaderStyle: MotionCardHeaderStyle = .solid
    var textScale: CGFloat = 1
    var bubbleScale: CGFloat = 1
    var paletteOffset: CGFloat = 0
    var paletteLayout: PaletteLayoutMode = .floating
    var useLiteraryColorNames = false
    var preservePaletteBackground = true
    var applyLiquidGlassOnExport = true
    var isExporting = false
    var paletteRevealStage: Int = 4
    var generationProgress: CGFloat = 1
    var privacyMasks: [PrivacyMask] = []
    var privacyStrokes: [PrivacyStroke] = []
    var privacyPixelatedImage: UIImage?
    var journalLayout: JournalLayoutMode = .automatic
    var journalTransforms: [JournalPhotoTransform] = []
    var selectedJournalIndex: Int?
    var ticketPayload: TicketPayload = .sample
    var ticketCodeStyle: TicketCodeStyle = .barcode
    var ticketLayout: TicketLayoutStyle = .classic
    var ticketAppClipBaseURL: String = TicketEnvelope.configuredBaseURLString

    private var colors: [RGBColor] {
        palette.isEmpty ? RGBColor.fallback : palette
    }

    private var lightestColor: RGBColor {
        colors.max(by: { $0.relativeLuminance < $1.relativeLuminance }) ?? RGBColor.fallback[2]
    }

    private var darkestColor: RGBColor {
        colors.min(by: { $0.relativeLuminance < $1.relativeLuminance }) ?? RGBColor.fallback[3]
    }

    private func readableForeground(preferred: RGBColor, background: RGBColor) -> RGBColor {
        guard preferred.contrastRatio(with: background) < 4.5 else { return preferred }
        let black = RGBColor(red: 0.035, green: 0.035, blue: 0.035)
        let white = RGBColor(red: 0.965, green: 0.965, blue: 0.965)
        return black.contrastRatio(with: background) >= white.contrastRatio(with: background)
            ? black
            : white
    }

    private var percentages: [Double] {
        if palettePercentages.count >= 6 {
            return palettePercentages
        }
        return palettePercentages + Array(repeating: 0, count: 6 - palettePercentages.count)
    }

    private var canvasCornerRadius: CGFloat {
        switch mode {
        case .bubbleStamp: 0
        case .spectrumWallpaper: 28
        case .travelTicket: 0
        default: 22
        }
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if isExporting {
                    canvasContent(size: proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    canvasContent(size: proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipShape(RoundedRectangle(
                            cornerRadius: canvasCornerRadius,
                            style: .continuous
                        ))
                }
            }
        }
    }

    @ViewBuilder
    private func canvasContent(size: CGSize) -> some View {
        switch mode {
        case .motionCard:
            motionCard(size: size)
        case .colorPalette:
            colorPalette(size: size)
        case .journal:
            journal(size: size)
        case .bubbleStamp:
            bubbleStamp(size: size)
        case .spectrumWallpaper:
            spectrumWallpaper(size: size)
        case .privacyMosaic:
            privacyMosaic(size: size)
        case .travelTicket:
            travelTicket(size: size)
        }
    }

    @ViewBuilder
    private func travelTicket(size: CGSize) -> some View {
        switch ticketLayout {
        case .classic:
            classicTravelTicket(size: size)
                .mask { TicketArtworkMask(layout: .classic) }
        case .vertical:
            verticalTravelTicket(size: size)
                .mask { TicketArtworkMask(layout: .vertical) }
        case .minimal:
            minimalTravelTicket(size: size)
        }
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
        let background = dominant.adjusted(
            brightness: themeBrightness,
            saturation: -0.38
        )
        let foreground = readableForeground(
            preferred: darkestColor,
            background: background
        )
        let contentInset = max(8, size.width * 0.026)
        let ticketHeight = size.height
        let ticketWidth = size.width
        let stubWidth = ticketWidth * (
            ticketCodeStyle == .verificationQR ? 0.335 : 0.285
        )

        return ZStack(alignment: .leading) {
            primaryPhoto(
                size: CGSize(width: ticketWidth, height: ticketHeight),
                cornerRadius: 0
            )

            TicketScallopedPanel(
                color: background.color,
                scallopCount: 7
            )
            .frame(width: stubWidth, height: ticketHeight)

            VStack(alignment: .center, spacing: max(3, size.height * 0.018)) {
                if let headerTitle = ticketPayload.headerTitle,
                   !headerTitle.isEmpty {
                    Text(headerTitle)
                        .font(.system(
                            size: max(9, size.width * 0.027),
                            weight: .black,
                            design: .rounded
                        ))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .multilineTextAlignment(.center)
                        .tracking(max(0.6, size.width * 0.003))
                        .frame(maxWidth: .infinity)
                }

                Text(ticketPayload.title)
                    .font(fontStyle.font(
                        size: max(7, size.width * 0.014) * textScale,
                        weight: .semibold
                    ))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(foreground.color.opacity(0.72))
                    .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: max(2, size.height * 0.007)) {
                    if let time = ticketPayload.captureTime {
                        Text(time)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }
                    Text("NO.\(ticketPayload.ticketID.replacingOccurrences(of: "LD-", with: ""))")
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Text(String(ticketPayload.fingerprint.suffix(8)))
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
                .font(.system(
                    size: max(6, size.width * 0.0108),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(foreground.color.opacity(0.70))
                .frame(maxWidth: .infinity)

                Spacer(minLength: 2)

                ticketCode(
                    availableSize: CGSize(
                        width: stubWidth - contentInset * 1.85,
                        height: ticketCodeStyle == .barcode
                            ? ticketHeight * 0.24
                            : ticketHeight * 0.47
                    ),
                    foreground: foreground
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .foregroundStyle(foreground.color)
            .padding(.horizontal, contentInset * 0.80)
            .padding(.vertical, contentInset * 0.80)
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
            primaryPhoto(
                size: CGSize(
                    width: size.width - inset * 2,
                    height: photoHeight
                ),
                cornerRadius: 0
            )
            .overlay(alignment: .topTrailing) {
                Text(ticketPayload.ticketID)
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
                        Text(ticketPayload.title)
                            .font(fontStyle.font(
                                size: max(11, size.width * 0.050) * textScale,
                                weight: .bold
                            ))
                            .lineLimit(2)
                        if let subtitle = ticketPayload.subtitle {
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
                            height: ticketCodeStyle == .barcode
                                ? size.height * 0.10
                                : size.width * 0.30
                        ),
                        foreground: foreground
                    )
                }

                Divider()
                    .overlay(foreground.color.opacity(0.18))

                HStack(spacing: 8) {
                    ticketInfoLabel(
                        title: "DATE",
                        value: ticketPayload.captureTime ?? "未记录"
                    )
                    ticketInfoLabel(
                        title: "CAMERA",
                        value: ticketPayload.device ?? "未公开"
                    )
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

    private func minimalTravelTicket(size: CGSize) -> some View {
        let dominant = colors[0]
        let panelBackground = dominant.adjusted(
            brightness: dominant.relativeLuminance < 0.30 ? 0.14 : -0.18,
            saturation: -0.12
        )
        let panelForeground = readableForeground(
            preferred: darkestColor,
            background: panelBackground
        )
        return ZStack(alignment: .bottom) {
            primaryPhoto(size: size, cornerRadius: 0)

            LinearGradient(
                colors: [
                    .clear,
                    panelBackground.color.opacity(0.10),
                    panelBackground.color.opacity(0.76)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: max(10, size.width * 0.028)) {
                VStack(alignment: .leading, spacing: max(4, size.height * 0.014)) {
                    Text(ticketPayload.title)
                        .font(fontStyle.font(
                            size: max(12, size.width * 0.036) * textScale,
                            weight: .bold
                        ))
                        .lineLimit(2)

                    HStack(spacing: 7) {
                        if let place = ticketPayload.place {
                            Label(place, systemImage: "location.fill")
                        }
                        if let time = ticketPayload.captureTime {
                            Label(time, systemImage: "calendar")
                        }
                    }
                    .font(.system(size: max(6, size.width * 0.014), weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(panelForeground.color.opacity(0.70))

                    Text(ticketPayload.ticketID)
                        .font(.system(
                            size: max(6, size.width * 0.013),
                            weight: .semibold,
                            design: .monospaced
                        ))
                        .foregroundStyle(panelForeground.color.opacity(0.58))
                }

                Spacer(minLength: 4)

                ticketCode(
                    availableSize: CGSize(
                        width: size.width * (ticketCodeStyle == .barcode ? 0.30 : 0.30),
                        height: size.height * (ticketCodeStyle == .barcode ? 0.22 : 0.50)
                    ),
                    foreground: panelForeground
                )
            }
            .foregroundStyle(panelForeground.color)
            .padding(max(14, size.width * 0.040))
            .background {
                RoundedRectangle(
                    cornerRadius: max(14, size.width * 0.038),
                    style: .continuous
                )
                .fill(panelBackground.color.opacity(isExporting ? 0.88 : 0.78))
                .overlay {
                    RoundedRectangle(
                        cornerRadius: max(14, size.width * 0.038),
                        style: .continuous
                    )
                    .stroke(panelForeground.color.opacity(0.18), lineWidth: 1)
                }
            }
            .padding(max(10, size.width * 0.026))
        }
    }

    @ViewBuilder
    private func ticketCode(
        availableSize: CGSize,
        foreground: RGBColor
    ) -> some View {
        let codePixelSize = ticketCodeStyle == .barcode
            ? CGSize(width: 1_200, height: 400)
            : CGSize(width: 900, height: 900)
        if let image = try? TicketCodeRenderer.image(
            for: ticketCodeStyle,
            payload: ticketPayload,
            baseURLString: ticketAppClipBaseURL,
            pixelSize: codePixelSize,
            foregroundColor: UIColor(
                red: foreground.red,
                green: foreground.green,
                blue: foreground.blue,
                alpha: 1
            ),
            backgroundColor: nil
        ) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(
                    ticketCodeStyle == .barcode
                        ? codePixelSize.width / codePixelSize.height
                        : 1,
                    contentMode: .fit
                )
                .frame(
                    maxWidth: availableSize.width,
                    maxHeight: availableSize.height
                )
                .accessibilityLabel(
                    ticketCodeStyle == .barcode
                        ? "真实一维票根码"
                        : "App Clip 验证二维码"
                )
        } else {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .frame(
                    width: min(availableSize.width, 44),
                    height: min(availableSize.height, 44)
                )
                .accessibilityLabel("票根编码生成失败")
        }
    }

    private func ticketTearLine(height: CGFloat) -> some View {
        VStack(spacing: max(3, height * 0.025)) {
            ForEach(0..<12, id: \.self) { _ in
                Circle()
                    .fill(.white.opacity(0.66))
                    .frame(
                        width: max(3, height * 0.020),
                        height: max(3, height * 0.020)
                    )
            }
        }
        .offset(x: max(2, height * 0.010))
    }

    private func ticketNotches(
        size: CGSize,
        inset: CGFloat,
        background: Color
    ) -> some View {
        let diameter = max(14, size.height * 0.16)
        return HStack {
            Circle()
                .fill(background)
                .frame(width: diameter, height: diameter)
                .offset(x: -diameter / 2)
            Spacer()
            Circle()
                .fill(background)
                .frame(width: diameter, height: diameter)
                .offset(x: diameter / 2)
        }
        .frame(width: size.width - inset * 2 + diameter, height: diameter)
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

    private func motionCard(size: CGSize) -> some View {
        let theme = MotionCardColorTheme.resolve(
            palette: colors.map {
                MotionCardColor(
                    red: Double($0.red),
                    green: Double($0.green),
                    blue: Double($0.blue)
                )
            },
            percentages: palettePercentages
        )
        let background = RGBColor(
            red: CGFloat(theme.background.red),
            green: CGFloat(theme.background.green),
            blue: CGFloat(theme.background.blue)
        )
        let foreground = RGBColor(
            red: CGFloat(theme.foreground.red),
            green: CGFloat(theme.foreground.green),
            blue: CGFloat(theme.foreground.blue)
        )
        let gradientTheme = MotionCardGradientTheme.resolve(
            palette: colors.map {
                MotionCardColor(
                    red: Double($0.red),
                    green: Double($0.green),
                    blue: Double($0.blue)
                )
            },
            percentages: palettePercentages
        )
        let gradientColors = gradientTheme.colors.map {
            Color(
                red: $0.red,
                green: $0.green,
                blue: $0.blue
            )
        }
        let gradientForeground = Color(
            red: gradientTheme.foreground.red,
            green: gradientTheme.foreground.green,
            blue: gradientTheme.foreground.blue
        )
        if templateStyle == .immersive {
            return AnyView(
                ZStack(alignment: .bottom) {
                    primaryPhoto(size: size, cornerRadius: 0)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.08), .black.opacity(0.74)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    VStack(spacing: 4) {
                        Text(copy.title)
                            .font(fontStyle.font(size: max(10, size.width * 0.040) * textScale, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        if metadata.captureDate != nil || showMissingCaptureTime {
                            Text(metadata.captureTimeText)
                                .font(.system(size: max(7, size.width * 0.020), weight: .medium))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.96))
                    .shadow(color: .black.opacity(0.34), radius: 9, y: 3)
                    .padding(.horizontal, size.width * 0.10)
                    .padding(.bottom, size.height * 0.075)
                }
            )
        }
        let headerFraction: CGFloat = templateStyle == .airy ? 0.34 : 0.43
        return AnyView(VStack(spacing: 0) {
            ZStack {
                if motionCardHeaderStyle == .sampledGradient {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    background.color
                }

                VStack(spacing: 3) {
                    Text(copy.title)
                        .font(fontStyle.font(size: max(8, size.width * 0.026) * textScale, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if metadata.captureDate != nil || showMissingCaptureTime {
                        Text(metadata.captureTimeText)
                            .font(.system(size: max(6, size.width * 0.017), weight: .medium))
                    }
                }
                .foregroundStyle(
                    motionCardHeaderStyle == .sampledGradient
                        ? gradientForeground
                        : foreground.color
                )
            }
            .frame(height: size.height * headerFraction)

            primaryPhoto(
                size: CGSize(width: size.width, height: size.height * (1 - headerFraction)),
                cornerRadius: 0
            )
        }
        )
    }

    private func colorPalette(size: CGSize) -> some View {
        let visiblePaletteOffset = PalettePanelGeometry.clampedOffset(
            paletteOffset,
            in: size,
            layout: paletteLayout
        )
        return ZStack {
            primaryPhoto(size: size, cornerRadius: 0)
                .overlay(.black.opacity(0.05))

            VStack(spacing: 0) {
                if paletteLayout == .bottom { Spacer() }

                palettePanel(size: size)
                    .scaleEffect(paletteRevealStage >= 1 ? 1 : 0.86, anchor: paletteLayout == .bottom ? .bottom : .top)
                    .opacity(paletteRevealStage >= 1 ? 1 : 0)
                    .offset(y: visiblePaletteOffset)

                if paletteLayout != .bottom { Spacer() }
            }
            .padding(.vertical, PalettePanelGeometry.verticalInset)
        }
    }

    @ViewBuilder
    private func palettePanel(size: CGSize) -> some View {
        let isCompact = paletteLayout == .compact
        let panelSize = PalettePanelGeometry.size(in: size, layout: paletteLayout)
        let panel = Group {
            if isCompact {
                HStack(spacing: 4) {
                    ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { index, color in
                        paletteSwatch(
                            index: index,
                            color: color,
                            referenceWidth: panelSize.width,
                            compact: true
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 11)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                LazyVGrid(columns: columns, spacing: 11) {
                    ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { index, color in
                        paletteSwatch(
                            index: index,
                            color: color,
                            referenceWidth: panelSize.width,
                            compact: false
                        )
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
            }
        }
        .frame(
            width: panelSize.width,
            height: panelSize.height
        )

        if isExporting && !preservePaletteBackground {
            panel
        } else if isExporting && !applyLiquidGlassOnExport {
            panel
                .background(.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .palettePanelOutline(colors: colors)
        } else {
            panel
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                    variant: .clear
                )
                .palettePanelOutline(colors: colors)
        }
    }

    private func paletteSwatch(
        index: Int,
        color: RGBColor,
        referenceWidth: CGFloat,
        compact: Bool
    ) -> some View {
        let requiredStage = index < 3 ? 2 : 3
        let diameter = referenceWidth * (compact ? 0.090 : 0.14)
        return VStack(spacing: compact ? 2 : 4) {
            Circle()
                .fill(color.color)
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.12), radius: 7, y: 4)
            if showHexValues || useLiteraryColorNames {
                Text(useLiteraryColorNames ? color.literaryName : color.hex)
                    .font(.system(
                        size: max(5, referenceWidth * (compact ? 0.015 : 0.022)),
                        weight: useLiteraryColorNames ? .semibold : .regular,
                        design: useLiteraryColorNames ? .rounded : .monospaced
                    ))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            if showPalettePercentages {
                Text(String(format: "%.1f%%", percentages[index]))
                    .font(.system(
                        size: max(5, referenceWidth * (compact ? 0.014 : 0.020)),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(paletteRevealStage >= requiredStage ? 1 : 0.18)
        .opacity(paletteRevealStage >= requiredStage ? 1 : 0)
    }

    private func journal(size: CGSize) -> some View {
        let background = colors[min(3, colors.count - 1)]
            .adjusted(
                brightness: gentleBackground ? 0.18 : -0.24,
                saturation: gentleBackground ? -0.22 : 0.18
            )
        let captionColor = background.luminance > 0.58
            ? Color.black.opacity(0.62)
            : Color.white.opacity(0.76)
        return ZStack {
            background.color

            Text(copy.emojis)
                .font(.system(size: max(10, size.width * 0.031)))
                .multilineTextAlignment(.center)
                .position(x: size.width * 0.50, y: size.height * 0.18)

            journalPhotoGrid(size: CGSize(width: size.width * 0.50, height: size.height * 0.505))
                .shadow(color: .black.opacity(0.22), radius: 16, y: 10)
                .position(x: size.width * 0.50, y: size.height * 0.50)

            Text(copy.journalCaption)
                .font(fontStyle.font(size: max(6, size.width * 0.018) * textScale))
                .italic()
                .foregroundStyle(captionColor)
                .position(x: size.width * 0.50, y: size.height * 0.765)
        }
    }

    private func bubbleStamp(size: CGSize) -> AnyView {
        let isCamera = metadata.captureDevice.category == .camera
        let deviceBubbleDiameter = size.width * (isCamera ? 0.11 : 0.10) * bubbleScale
        let deviceMarkWidth = cameraWatermarkImage.map {
            customWatermarkWidth(for: $0, height: deviceBubbleDiameter)
        } ?? deviceBubbleDiameter

        if templateStyle == .immersive {
            return AnyView(
                ZStack(alignment: .bottom) {
                    primaryPhoto(size: size, cornerRadius: 0)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.06), .black.opacity(0.76)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    HStack(spacing: 12) {
                        if showBubbles {
                            captureDeviceBubble(
                                diameter: deviceBubbleDiameter,
                                fill: .white.opacity(0.76),
                                symbol: .black.opacity(0.66),
                                watermark: .white.opacity(0.88)
                            )
                                .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(copy.title)
                                .font(fontStyle.font(size: max(9, size.width * 0.030) * textScale, weight: .bold))
                                .lineLimit(2)
                            Text(copy.subtitle)
                                .font(fontStyle.font(size: max(6, size.width * 0.017) * textScale))
                                .fontWeight(.semibold)
                                .opacity(0.78)
                            if showDeviceInfo, let deviceLine = metadata.deviceLine {
                                Text(deviceLine)
                                    .font(.system(size: max(5, size.width * 0.014)))
                                    .opacity(0.52)
                            }
                            if showDeviceInfo, isCamera {
                                if let lensLine = metadata.cameraLensLine {
                                    Text(lensLine)
                                        .font(.system(size: max(4, size.width * 0.013)))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.62)
                                        .allowsTightening(true)
                                        .opacity(0.46)
                                }
                                if let settingsLine = metadata.captureSettingsLine {
                                    Text(settingsLine)
                                        .font(.system(size: max(4, size.width * 0.0125)))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                        .opacity(0.38)
                                }
                            }
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.36), radius: 7, y: 2)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, size.width * 0.10)
                    .padding(.bottom, size.height * 0.065)
                }
            )
        }

        let usesLightBackground = templateStyle == .airy
        let background = usesLightBackground
            ? lightestColor.adjusted(brightness: 0.15, saturation: -0.18)
            : darkestColor.adjusted(brightness: -0.06, saturation: 0.12)
        let foregroundRGB = readableForeground(
            preferred: usesLightBackground
                ? darkestColor.adjusted(brightness: -0.08, saturation: 0.04)
                : lightestColor.adjusted(brightness: 0.18, saturation: -0.04),
            background: background
        )
        let foreground = foregroundRGB.color
        let horizontalInset: CGFloat = templateStyle == .airy ? 52 : 32
        let photoSide = min(size.width - horizontalInset, size.height * (size.width > size.height ? 0.60 : 0.76))
        return AnyView(ZStack {
            background.color

            VStack(spacing: 0) {
                primaryPhoto(
                    size: CGSize(width: photoSide, height: photoSide),
                    cornerRadius: 0
                )
                .padding(.top, templateStyle == .airy ? 26 : 16)

                HStack(spacing: 12) {
                    Group {
                        if showBubbles {
                            captureDeviceBubble(
                                diameter: deviceBubbleDiameter,
                                fill: foreground.opacity(0.68),
                                symbol: background.color.opacity(0.78),
                                watermark: foreground.opacity(0.84)
                            )
                        } else {
                            Circle().fill(.clear)
                        }
                    }
                    .frame(width: deviceMarkWidth, height: deviceBubbleDiameter)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.title)
                            .font(fontStyle.font(size: max(8, size.width * 0.027) * textScale, weight: .bold))
                            .lineLimit(2)
                        Text(copy.subtitle)
                            .font(fontStyle.font(size: max(5, size.width * 0.016) * textScale))
                            .fontWeight(.semibold)
                            .opacity(0.70)

                        if showDeviceInfo {
                            if let deviceLine = metadata.deviceLine {
                                Text(deviceLine)
                                    .font(.system(size: max(4, size.width * 0.014)))
                                    .opacity(0.42)
                            }
                            if isCamera {
                                if let lensLine = metadata.cameraLensLine {
                                    Text(lensLine)
                                        .font(.system(size: max(4, size.width * 0.013)))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.62)
                                        .allowsTightening(true)
                                        .opacity(0.38)
                                }
                                if let settingsLine = metadata.captureSettingsLine {
                                    Text(settingsLine)
                                        .font(.system(size: max(4, size.width * 0.0125)))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                        .opacity(0.32)
                                }
                            } else if let cameraLine = metadata.cameraLine {
                                Text(cameraLine)
                                    .font(.system(size: max(4, size.width * 0.013)))
                                    .opacity(0.34)
                            }
                        }
                    }
                    .foregroundStyle(foreground)

                    Spacer()
                }
                .padding(.horizontal, size.width * (templateStyle == .airy ? 0.16 : 0.13))
                .frame(maxHeight: .infinity)
            }
        })
    }

    private func captureDeviceBubble(
        diameter: CGFloat,
        fill: Color,
        symbol: Color,
        watermark: Color
    ) -> some View {
        Group {
            if let cameraWatermarkImage {
                Group {
                    if cameraWatermarkImage.renderingMode == .alwaysOriginal {
                        Image(uiImage: cameraWatermarkImage)
                            .resizable()
                    } else {
                        Image(uiImage: cameraWatermarkImage.withRenderingMode(.alwaysTemplate))
                            .resizable()
                            .foregroundStyle(watermark)
                    }
                }
                    .scaledToFit()
                    .frame(
                        width: customWatermarkWidth(
                            for: cameraWatermarkImage,
                            height: diameter
                        ),
                        height: diameter * 0.86
                    )
                    .shadow(color: .white.opacity(0.16), radius: 0.8)
                    .shadow(color: .black.opacity(0.42), radius: 2.2, y: 1)
            } else {
                ZStack {
                    Circle().fill(fill)
                    if showDeviceInfo {
                        Image(systemName: metadata.captureDevice.systemImageName)
                            .font(.system(size: diameter * 0.36, weight: .medium))
                            .foregroundStyle(symbol)
                    }
                }
                .frame(width: diameter, height: diameter)
            }
        }
        .frame(
            width: cameraWatermarkImage.map {
                customWatermarkWidth(for: $0, height: diameter)
            } ?? diameter,
            height: diameter
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            cameraWatermarkImage == nil
                ? metadata.captureDevice.displayName ?? "照片"
                : "\(metadata.captureDevice.displayName ?? "相机")图标水印"
        )
    }

    private func customWatermarkWidth(for image: UIImage, height: CGFloat) -> CGFloat {
        guard image.size.height > 0 else { return height }
        let aspectRatio = image.size.width / image.size.height
        let multiplier: CGFloat
        if aspectRatio >= 8 {
            multiplier = 2.05
        } else if aspectRatio >= 3 {
            multiplier = 1.72
        } else if aspectRatio >= 1.25 {
            multiplier = 1.38
        } else {
            multiplier = 1
        }
        return height * multiplier
    }

    private func spectrumWallpaper(size: CGSize) -> some View {
        let blurPhase = min(max(generationProgress / 0.56, 0), 1)
        let gradientPhase = min(max((generationProgress - 0.48) / 0.38, 0), 1)

        return ZStack {
            colors[min(2, colors.count - 1)]
                .adjusted(brightness: 0.18, saturation: -0.18)
                .color

            if let image = images.first {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(imageScale)
                    .offset(x: imageOffset.width, y: imageOffset.height)
                    .blur(radius: 34 * blurPhase)
                    .saturation(1 + 0.22 * blurPhase)
                    .opacity(1 - gradientPhase * (gentleBackground ? 0.76 : 0.58))
            }

            LinearGradient(
                colors: [
                    colors[min(2, colors.count - 1)].adjusted(brightness: 0.18, saturation: -0.18).color,
                    Color.white.opacity(0.88),
                    Color.white.opacity(0.92),
                    colors[0].adjusted(brightness: 0.10, saturation: -0.34).color
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)
            .opacity(gradientPhase * (gentleBackground ? 0.94 : 0.76))
        }
    }

    private func privacyMosaic(size: CGSize) -> some View {
        Group {
            if let image = images.first {
                PrivacyMosaicCanvas(
                    image: image,
                    pixelatedImage: privacyPixelatedImage,
                    masks: privacyMasks,
                    strokes: privacyStrokes,
                    imageScale: imageScale,
                    imageOffset: imageOffset,
                    isExporting: isExporting
                )
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.black.opacity(0.72))
                    .overlay {
                        Image(systemName: "eye.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.72))
                    }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func primaryPhoto(size: CGSize, cornerRadius: CGFloat) -> some View {
        if let image = images.first {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(imageScale)
                .offset(x: imageOffset.width, y: imageOffset.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.24))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.65))
                }
        }
    }

    @ViewBuilder
    private func journalPhotoGrid(size: CGSize) -> some View {
        let selected = Array(images.prefix(5))
        let frames = JournalGridGeometry.frames(count: selected.count, in: size, layout: journalLayout)
        ZStack(alignment: .topLeading) {
            ForEach(Array(selected.enumerated()), id: \.offset) { index, image in
                let frame = frames[index]
                journalCell(image, index: index, size: frame.size)
                    .frame(width: frame.width, height: frame.height)
                    .overlay {
                        if !isExporting, selectedJournalIndex == index {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(.white, lineWidth: 2)
                                .shadow(color: .black.opacity(0.28), radius: 4)
                                .padding(1)
                        }
                    }
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func journalCell(_ image: UIImage, index: Int, size: CGSize) -> some View {
        let transform = journalTransforms.indices.contains(index)
            ? journalTransforms[index]
            : JournalPhotoTransform()
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(transform.scale)
            .offset(
                x: transform.normalizedOffset.width * size.width,
                y: transform.normalizedOffset.height * size.height
            )
            .clipped()
    }
}

private struct TicketScallopedPanel: View {
    let color: Color
    let scallopCount: Int

    var body: some View {
        Canvas { context, size in
            let count = max(1, scallopCount)
            let step = size.height / CGFloat(count)
            // Adjacent circles meet exactly, forming one uninterrupted
            // perforated edge instead of separate bumps.
            let radius = step * 0.50
            let panelRect = CGRect(
                x: 0,
                y: 0,
                width: size.width - radius,
                height: size.height
            )
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

private extension View {
    func palettePanelOutline(colors: [RGBColor]) -> some View {
        self
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.58),
                                (colors.first ?? RGBColor.fallback[0]).adjusted(brightness: 0.18).color.opacity(0.34),
                                .white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.13), radius: 13, y: 7)
    }
}
