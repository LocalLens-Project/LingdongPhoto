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
    var showsCaptureTime = true
    var copy: ArtworkCopy = ArtworkCopy()
    var fontStyle: ArtworkFontStyle = .rounded
    var templateStyle: ArtworkTemplateStyle = .classic
    var motionCardHeaderStyle: MotionCardHeaderStyle = .solid
    var motionCardHeaderPalette: [RGBColor]?
    var motionCardHeaderPercentages: [Double]?
    var textScale: CGFloat = 1
    var bubbleScale: CGFloat = 1
    var paletteOffset: CGFloat = 0
    var paletteLayout: PaletteLayoutMode = .floating
    var useLiteraryColorNames = false
    var usePoeticColorNames = false
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
    var ticketDeviceSealEnabled = true
    var ticketCodeImageOverride: UIImage?
    var sketchImage: UIImage? = nil
    var sketchParameters: SketchParameters = .defaultBrush
    var classicSketchImage: UIImage? = nil
    var classicSketchParameters: ClassicSketchParameters = .defaultPencil
    var showsColorPaletteOverlay = true
    var lightToneOverlay: UIImage? = nil
    var glassArchiveMark: GlassArchiveMark = .apple

    var glassArchiveHidesMissingTime = false

    var glassArchiveShowsLocation = true
    var glassArchiveBarPosition: CGFloat = 1
    var glassArchivePinnedColors: [RGBColor] = []
    var glassArchivePinnedEdge: GlassArchivePinnedEdge = .leading
    var glassArchiveCustomText: String? = nil
    var glassArchiveCustomFont: PostalFont = .original

    var featurePaletteSide: FeaturePaletteSide = .bottom
    var featurePaletteBandRatio: Double = 0.295
    var featurePaletteSwatchOrder: [Int] = []
    var featurePaletteSwatchMove: ((Int, Int) -> Void)? = nil
    var featurePaletteBandRectChange: ((CGRect?) -> Void)? = nil
    var featureCalendarCity: String?
    var featureCalendarShowsLocation = true
    var featureCalendarLayoutStyle: MonthlyCalendarLayoutStyle = .glass
    var featureCalendarPanelColorMode: MonthlyCalendarPanelColorMode = .fixed
    var featureCalendarCustomPanelColor = RGBColor(red: 0.972, green: 0.964, blue: 0.936)
    var featureCalendarUsesEnglishMonthTitle = false
    var featureCalendarShowsFooter = true
    var featureCalendarPhotoScale: CGFloat = 1
    var featureCalendarPhotoOffset: CGSize = .zero
    var signatureStampPage: SignatureStampPage = .bubble
    var signatureStampText = ""
    var signatureStampFont: PostalFont = .original
    var signatureStampImage: UIImage? = nil
    var signatureStampSource: SignatureStampSource = .text
    var signatureStampTextScale: CGFloat = 1
    var signatureStampImageScale: CGFloat = 1
    var signatureStampOffset: CGSize = .zero
    var signatureStampShowsDate = false
    var signatureStampShowsTime = false
    var signatureStampUsesEnglishDateTime = false
    var signatureStampDateTimeScale: CGFloat = 1
    var signatureStampDateTimeOffset = CGSize(width: 0.25, height: 0.40)
    var onEditCopy: (() -> Void)? = nil

    private var colors: [RGBColor] {
        let base = palette.isEmpty ? RGBColor.fallback : palette
        return motionCardHeaderPalette ?? base
    }

    private var paletteSwatchColors: [RGBColor] {
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

    static func ticketCodeForeground(
        palette: [RGBColor],
        motionCardHeaderPalette: [RGBColor]?,
        layout: TicketLayoutStyle
    ) -> RGBColor {
        let colors = motionCardHeaderPalette
            ?? (palette.isEmpty ? RGBColor.fallback : palette)
        let dominant = colors[0]
        let darkest = colors.min(by: {
            $0.relativeLuminance < $1.relativeLuminance
        }) ?? RGBColor.fallback[3]
        let background: RGBColor
        switch layout {
        case .classic:
            background = dominant.adjusted(
                brightness: dominant.relativeLuminance < 0.18
                    ? 0.10
                    : (dominant.relativeLuminance < 0.48 ? 0.26 : -0.06),
                saturation: -0.38
            )
        case .vertical:
            background = dominant.adjusted(
                brightness: dominant.relativeLuminance < 0.18
                    ? 0.10
                    : (dominant.relativeLuminance < 0.48 ? 0.24 : -0.05),
                saturation: -0.30
            )
        case .minimal:
            background = dominant.adjusted(
                brightness: dominant.relativeLuminance < 0.30 ? 0.14 : -0.18,
                saturation: -0.12
            )
        }
        guard darkest.contrastRatio(with: background) < 4.5 else {
            return darkest
        }
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
        case .glassArchive, .paletteCard, .monthlyCalendar: 0
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
        case .sketch:
            classicSketch(size: size)
        case .imagePainting:
            sketch(size: size)
        case .glassArchive:
            glassArchive(size: size)
        case .paletteCard:
            if let image = images.first {
                PaletteCardCanvas(
                    image: image,
                    palette: palette,
                    side: featurePaletteSide,
                    bandRatio: featurePaletteBandRatio,
                    percentages: palettePercentages,
                    swatchOrder: featurePaletteSwatchOrder,
                    showHexValues: showHexValues,
                    useLiteraryColorNames: useLiteraryColorNames,
                    usePoeticColorNames: usePoeticColorNames,
                    showPalettePercentages: showPalettePercentages,
                    isExporting: isExporting,
                    onMoveSwatch: featurePaletteSwatchMove,
                    onBandRectChange: featurePaletteBandRectChange
                )
            } else {
                Color.clear
            }
        case .monthlyCalendar:
            if let image = images.first {
                MonthlyCalendarCanvas(image: image, palette: palette,
                                      captureDate: metadata.captureDate, cityName: featureCalendarCity,
                                      showsLocation: featureCalendarShowsLocation,
                                      layoutStyle: featureCalendarLayoutStyle,
                                      panelColorMode: featureCalendarPanelColorMode,
                                      customPanelColor: featureCalendarCustomPanelColor,
                                      usesEnglishMonthTitle: featureCalendarUsesEnglishMonthTitle,
                                      showsFooter: featureCalendarShowsFooter,
                                      photoScale: featureCalendarPhotoScale,
                                      normalizedPhotoOffset: featureCalendarPhotoOffset)
            } else {
                Color.clear
            }
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
        let referenceHeight = size.width * 9.0 / 21.0
        let heightScale = max(1.0, size.height / referenceHeight)
        let fontScaleFactor = sqrt(heightScale)
        let verticalPadding = contentInset * 0.80 * heightScale
        let scallopRadius = ticketHeight / CGFloat(max(1, 7)) * 0.50
        let textMaxWidth = stubWidth - scallopRadius - contentInset * 0.80 * 2

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

            VStack(alignment: .center, spacing: max(3, size.height * 0.018 * heightScale)) {
                if let headerTitle = ticketPayload.headerTitle,
                   !headerTitle.isEmpty {
                    Text(LocalizedStringKey(headerTitle))
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

                Text(LocalizedStringKey(ticketPayload.title))
                    .font(fontStyle.font(
                        size: max(7, size.width * 0.014) * textScale * fontScaleFactor,
                        weight: .semibold
                    ))
                    .lineLimit(3)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(foreground.color.opacity(0.72))
                    .frame(width: textMaxWidth)

                VStack(alignment: .center, spacing: max(2, size.height * 0.007 * heightScale)) {
                    if let time = ticketPayload.captureTime {
                        Text(LocalizedStringKey(time))
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
            primaryPhoto(
                size: CGSize(
                    width: size.width - inset * 2,
                    height: photoHeight
                ),
                cornerRadius: 0
            )
            .overlay(alignment: .topTrailing) {
                Text(LocalizedStringKey(ticketPayload.ticketID))
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
                        Text(LocalizedStringKey(ticketPayload.title))
                            .font(fontStyle.font(
                                size: max(11, size.width * 0.050) * textScale,
                                weight: .bold
                            ))
                            .lineLimit(2)
                        if let subtitle = ticketPayload.subtitle {
                            Text(LocalizedStringKey(subtitle))
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
                    Text(LocalizedStringKey(ticketPayload.title))
                        .font(fontStyle.font(
                            size: max(12, size.width * 0.036) * textScale,
                            weight: .bold
                        ))
                        .lineLimit(2)

                    HStack(spacing: 7) {
                        if let place = ticketPayload.place {
                            Label(LocalizedStringKey(place), systemImage: "location.fill")
                        }
                        if let time = ticketPayload.captureTime {
                            Label(LocalizedStringKey(time), systemImage: "calendar")
                        }
                    }
                    .font(.system(size: max(6, size.width * 0.014), weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(panelForeground.color.opacity(0.70))

                    Text(LocalizedStringKey(ticketPayload.ticketID))
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
        if #available(iOS 18.0, *) {
            synchronousTicketCode(
                availableSize: availableSize,
                foreground: foreground,
                codePixelSize: codePixelSize
            )
        } else if let ticketCodeImageOverride {
            ticketCodeImage(
                ticketCodeImageOverride,
                availableSize: availableSize,
                codePixelSize: codePixelSize
            )
        } else if isExporting {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .frame(
                    width: min(availableSize.width, 44),
                    height: min(availableSize.height, 44)
                )
                .accessibilityLabel("票根编码生成失败")
        } else {
            IOS17TicketCodeImage(
                style: ticketCodeStyle,
                payload: ticketPayload,
                baseURLString: ticketAppClipBaseURL,
                deviceSealEnabled: ticketDeviceSealEnabled,
                pixelSize: codePixelSize,
                availableSize: availableSize,
                foreground: foreground
            )
        }
    }

    @ViewBuilder
    private func synchronousTicketCode(
        availableSize: CGSize,
        foreground: RGBColor,
        codePixelSize: CGSize
    ) -> some View {
        if let image = try? TicketCodeRenderer.image(
            for: ticketCodeStyle,
            payload: ticketPayload,
            baseURLString: ticketAppClipBaseURL,
            signer: ticketDeviceSealEnabled ? TicketDeviceSealService.shared : nil,
            pixelSize: codePixelSize,
            foregroundColor: UIColor(
                red: foreground.red,
                green: foreground.green,
                blue: foreground.blue,
                alpha: 1
            ),
            backgroundColor: nil
        ) {
            ticketCodeImage(
                image,
                availableSize: availableSize,
                codePixelSize: codePixelSize
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

    private func ticketCodeImage(
        _ image: UIImage,
        availableSize: CGSize,
        codePixelSize: CGSize
    ) -> some View {
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
            ForEach(Array(paletteSwatchColors.prefix(6).enumerated()), id: \.offset) { _, color in
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
            Text(LocalizedStringKey(title))
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .opacity(0.46)
            Text(LocalizedStringKey(value))
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func motionCard(size: CGSize) -> some View {
        let headerColors = motionCardHeaderPalette.flatMap { $0.isEmpty ? nil : $0 } ?? colors
        let headerPercentages = motionCardHeaderPercentages ?? palettePercentages
        let theme = MotionCardColorTheme.resolve(
            palette: headerColors.map {
                MotionCardColor(
                    red: Double($0.red),
                    green: Double($0.green),
                    blue: Double($0.blue)
                )
            },
            percentages: headerPercentages
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
            palette: headerColors.map {
                MotionCardColor(
                    red: Double($0.red),
                    green: Double($0.green),
                    blue: Double($0.blue)
                )
            },
            percentages: headerPercentages
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
                        Text(LocalizedStringKey(copy.title))
                            .font(fontStyle.font(size: max(10, size.width * 0.040) * textScale, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        if showsCaptureTime && (metadata.captureDate != nil || showMissingCaptureTime) {
                            Text(LocalizedStringKey(metadata.captureTimeText))
                                .font(.system(size: max(7, size.width * 0.020), weight: .medium))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.96))
                    .shadow(color: .black.opacity(0.34), radius: 9, y: 3)
                    .padding(.horizontal, size.width * 0.10)
                    .padding(.bottom, size.height * 0.075)
                    .contentShape(Rectangle())
                    .onTapGesture { onEditCopy?() }
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
                    Text(LocalizedStringKey(copy.title))
                        .font(fontStyle.font(size: max(8, size.width * 0.026) * textScale, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if showsCaptureTime && (metadata.captureDate != nil || showMissingCaptureTime) {
                        Text(LocalizedStringKey(metadata.captureTimeText))
                            .font(.system(size: max(6, size.width * 0.017), weight: .medium))
                    }
                }
                .foregroundStyle(
                    motionCardHeaderStyle == .sampledGradient
                        ? gradientForeground
                        : foreground.color
                )
                .contentShape(Rectangle())
                .onTapGesture { onEditCopy?() }
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
        let usesLandscapeStrip = size.width > size.height * 1.18
        let visiblePaletteOffset = PalettePanelGeometry.clampedOffset(
            paletteOffset,
            in: size,
            layout: paletteLayout
        )
        return ZStack {
            colorInsightPhoto(size: size)
                .overlay(.black.opacity(0.05))

            if let lightToneOverlay {
                Image(uiImage: lightToneOverlay)
                    .resizable()
                    .aspectRatio(contentMode: showsColorPaletteOverlay ? .fill : .fit)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(showsColorPaletteOverlay ? imageScale : 1)
                    .offset(
                        x: showsColorPaletteOverlay ? imageOffset.width : 0,
                        y: showsColorPaletteOverlay ? imageOffset.height : 0
                    )
                    .clipped()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if showsColorPaletteOverlay {
                VStack(spacing: 0) {
                    if usesLandscapeStrip { Spacer() }

                    palettePanel(size: size)
                        .scaleEffect(
                            paletteRevealStage >= 1 ? 1 : 0.86,
                            anchor: usesLandscapeStrip ? .bottom : .top
                        )
                        .opacity(paletteRevealStage >= 1 ? 1 : 0)
                        .offset(y: visiblePaletteOffset)

                    if !usesLandscapeStrip { Spacer() }
                }
                .padding(.vertical, PalettePanelGeometry.verticalInset)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: lightToneOverlay != nil)
    }

    @ViewBuilder
    private func colorInsightPhoto(size: CGSize) -> some View {
        if showsColorPaletteOverlay {
            primaryPhoto(size: size, cornerRadius: 0)
        } else if let image = images.first {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
        } else {
            RoundedRectangle(cornerRadius: 0)
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
    private func palettePanel(size: CGSize) -> some View {
        let usesLandscapeStrip = size.width > size.height * 1.18
        let isCompact = paletteLayout == .compact || usesLandscapeStrip
        let panelSize = PalettePanelGeometry.size(in: size, layout: paletteLayout)
        let poeticEntries = usePoeticColorNames
            ? TraditionalColorLexicon.uniqueMatches(
                colors: Array(paletteSwatchColors.prefix(6)),
                percentages: Array(percentages.prefix(6))
            )
            : []
        let panel = Group {
            if isCompact {
                HStack(spacing: 4) {
                    ForEach(Array(paletteSwatchColors.prefix(6).enumerated()), id: \.offset) { index, color in
                        paletteSwatch(
                            index: index,
                            color: color,
                            poeticName: poeticEntries.indices.contains(index)
                                ? poeticEntries[index].localizedName
                                : nil,
                            referenceWidth: panelSize.width,
                            compact: true
                        )
                    }
                }
                .padding(.horizontal, usesLandscapeStrip ? 12 : 10)
                .padding(.vertical, usesLandscapeStrip ? 8 : 11)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                LazyVGrid(columns: columns, spacing: 11) {
                    ForEach(Array(paletteSwatchColors.prefix(6).enumerated()), id: \.offset) { index, color in
                        paletteSwatch(
                            index: index,
                            color: color,
                            poeticName: poeticEntries.indices.contains(index)
                                ? poeticEntries[index].localizedName
                                : nil,
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
                .palettePanelOutline(colors: paletteSwatchColors)
        } else {
            panel
                .paletteLiquidGlassPanel(colors: paletteSwatchColors)
        }
    }

    private func paletteSwatch(
        index: Int,
        color: RGBColor,
        poeticName: String?,
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
            if showHexValues || useLiteraryColorNames || usePoeticColorNames {
                Text(
                    usePoeticColorNames
                        ? (poeticName ?? color.poeticEntry().localizedName)
                        : (useLiteraryColorNames ? color.literaryName : color.hex)
                )
                    .font(.system(
                        size: max(5, referenceWidth * (compact ? 0.015 : 0.022)),
                        weight: (useLiteraryColorNames || usePoeticColorNames) ? .semibold : .regular,
                        design: (useLiteraryColorNames || usePoeticColorNames) ? .rounded : .monospaced
                    ))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
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

            Text(LocalizedStringKey(copy.emojis))
                .font(.system(size: max(10, size.width * 0.031)))
                .multilineTextAlignment(.center)
                .position(x: size.width * 0.50, y: size.height * 0.18)

            journalPhotoGrid(size: CGSize(width: size.width * 0.50, height: size.height * 0.505))
                .shadow(color: .black.opacity(0.22), radius: 16, y: 10)
                .position(x: size.width * 0.50, y: size.height * 0.50)

            Text(LocalizedStringKey(copy.journalCaption))
                .font(fontStyle.font(size: max(6, size.width * 0.018) * textScale))
                .italic()
                .foregroundStyle(captionColor)
                .position(x: size.width * 0.50, y: size.height * 0.765)
        }
    }

    private func bubbleStamp(size: CGSize) -> AnyView {
        if signatureStampPage == .signature {
            return AnyView(signatureStamp(size: size))
        }

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
                            Text(LocalizedStringKey(copy.title))
                                .font(fontStyle.font(size: max(9, size.width * 0.030) * textScale, weight: .bold))
                                .lineLimit(2)
                            Text(LocalizedStringKey(copy.subtitle))
                                .font(fontStyle.font(size: max(6, size.width * 0.017) * textScale))
                                .fontWeight(.semibold)
                                .opacity(0.78)
                            if showDeviceInfo, let deviceLine = metadata.deviceLine {
                                Text(LocalizedStringKey(deviceLine))
                                    .font(.system(size: max(5, size.width * 0.014)))
                                    .opacity(0.52)
                            }
                            if showDeviceInfo, isCamera {
                                if let lensLine = metadata.cameraLensLine {
                                    Text(LocalizedStringKey(lensLine))
                                        .font(.system(size: max(4, size.width * 0.013)))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.62)
                                        .allowsTightening(true)
                                        .opacity(0.46)
                                }
                                if let settingsLine = metadata.captureSettingsLine {
                                    Text(LocalizedStringKey(settingsLine))
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
                        Text(LocalizedStringKey(copy.title))
                            .font(fontStyle.font(size: max(8, size.width * 0.027) * textScale, weight: .bold))
                            .lineLimit(2)
                        Text(LocalizedStringKey(copy.subtitle))
                            .font(fontStyle.font(size: max(5, size.width * 0.016) * textScale))
                            .fontWeight(.semibold)
                            .opacity(0.70)

                        if showDeviceInfo {
                            if let deviceLine = metadata.deviceLine {
                                Text(LocalizedStringKey(deviceLine))
                                    .font(.system(size: max(4, size.width * 0.014)))
                                    .opacity(0.42)
                            }
                            if isCamera {
                                if let lensLine = metadata.cameraLensLine {
                                    Text(LocalizedStringKey(lensLine))
                                        .font(.system(size: max(4, size.width * 0.013)))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.62)
                                        .allowsTightening(true)
                                        .opacity(0.38)
                                }
                                if let settingsLine = metadata.captureSettingsLine {
                                    Text(LocalizedStringKey(settingsLine))
                                        .font(.system(size: max(4, size.width * 0.0125)))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                        .opacity(0.32)
                                }
                            } else if let cameraLine = metadata.cameraLine {
                                Text(LocalizedStringKey(cameraLine))
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

    private func signatureStamp(size: CGSize) -> some View {
        ZStack {
            Color.black
            if let image = images.first {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
            }
            signatureStampOverlay(size: size)
            signatureStampDateTimeOverlay(size: size)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func signatureStampDateTimeOverlay(size: CGSize) -> some View {
        if let text = signatureStampDateTimeText {
            Text(verbatim: text)
                .font(Font(signatureStampFont.uiFont(size: max(10, size.width * 0.030) * signatureStampDateTimeScale)))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, size.width * 0.018)
                .padding(.vertical, size.width * 0.010)
                .background(.black.opacity(0.20), in: Capsule())
                .shadow(color: .black.opacity(0.82), radius: max(1.5, size.width * 0.008), y: 1)
                .position(
                    x: size.width * (0.5 + signatureStampDateTimeOffset.width),
                    y: size.height * (0.5 + signatureStampDateTimeOffset.height)
                )
        }
    }

    private var signatureStampDateTimeText: String? {
        guard signatureStampShowsDate || signatureStampShowsTime,
              let date = metadata.captureDate else { return nil }
        let formatter = DateFormatter()
        let usesEnglish = signatureStampUsesEnglishDateTime || LexiconLanguage.current == .english
        formatter.locale = Locale(identifier: usesEnglish ? "en_US" : "zh_CN")
        if signatureStampShowsDate && signatureStampShowsTime {
            formatter.dateFormat = usesEnglish ? "MMM d, yyyy · h:mm a" : "yyyy年M月d日 HH:mm"
        } else if signatureStampShowsDate {
            formatter.dateFormat = usesEnglish ? "MMM d, yyyy" : "yyyy年M月d日"
        } else {
            formatter.dateFormat = usesEnglish ? "h:mm a" : "HH:mm"
        }
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func signatureStampOverlay(size: CGSize) -> some View {
        let center = CGPoint(
            x: size.width * (0.5 + signatureStampOffset.width),
            y: size.height * (0.5 + signatureStampOffset.height)
        )
        if signatureStampSource == .image, let image = signatureStampImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: size.width * 0.30 * signatureStampImageScale,
                    height: size.height * 0.22 * signatureStampImageScale
                )
                .shadow(color: .black.opacity(0.28), radius: max(1, size.width * 0.008), y: 1)
                .position(center)
        } else if !signatureStampText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(verbatim: signatureStampText)
                .font(Font(signatureStampFont.uiFont(size: max(18, size.width * 0.075) * signatureStampTextScale)))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, size.width * 0.025)
                .shadow(color: .black.opacity(0.78), radius: max(1.5, size.width * 0.010), y: 1)
                .position(center)
        }
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
            } else if showDeviceInfo, GlassArchiveMarkResolver.isAppleDevice(
                metadata.captureDevice.displayName
            ) {

                Image(systemName: "applelogo")
                    .font(.system(size: diameter, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: diameter, height: diameter)
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

    private func glassArchive(size: CGSize) -> some View {
        let barFrame = GlassArchiveBarGeometry.barFrame(
            in: size,
            position: glassArchiveBarPosition
        )
        let barHeight = barFrame.height
        let deviceName = metadata.captureDevice.displayName
            ?? "未知设备".appLocalized
        let recordedTime = metadata.archiveTimeText

        let hidesMissingTime = recordedTime == nil && glassArchiveHidesMissingTime
        let timeText = recordedTime ?? "时间未记录".appLocalized
        let settingsLine = metadata.archiveSettingsLine
        let coordinateLine = glassArchiveShowsLocation
            ? metadata.archiveCoordinateLine
            : nil

        let bar = HStack(spacing: barHeight * 0.18) {
            if let customText = glassArchiveCustomText {
                if glassArchivePinnedEdge == .leading {
                    glassArchivePinnedSwatches(barHeight: barHeight)
                }
                Text(customText.isEmpty ? "轻点档案栏，写下此刻".appLocalized : customText)
                    .font(glassArchiveCustomTextFont(barHeight: barHeight))
                    .opacity(customText.isEmpty ? 0.62 : 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .allowsTightening(true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: glassArchivePinnedColors.isEmpty
                            ? .center
                            : (glassArchivePinnedEdge == .leading ? .trailing : .leading)
                    )
                if glassArchivePinnedEdge == .trailing {
                    glassArchivePinnedSwatches(barHeight: barHeight)
                }
            } else {
            VStack(alignment: .leading, spacing: barHeight * 0.05) {

                Text(LocalizedStringKey(deviceName))
                    .font(.system(size: barHeight * 0.20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .allowsTightening(true)
                if !hidesMissingTime {
                    Text(LocalizedStringKey(timeText))
                        .font(.system(size: barHeight * 0.185, weight: .medium))
                        .opacity(0.82)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .allowsTightening(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if glassArchiveMark != .none {
                glassArchiveMarkView(height: barHeight * 0.50)

                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 1, height: barHeight * 0.50)
            }

            VStack(alignment: .leading, spacing: barHeight * 0.05) {
                if let settingsLine {
                    Text(settingsLine)
                        .font(.system(size: barHeight * 0.23, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                }
                if let coordinateLine {
                    Text(coordinateLine)
                        .font(.system(size: barHeight * 0.225, weight: .medium))
                        .opacity(0.82)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                }
                if settingsLine == nil && coordinateLine == nil {
                    Text("拍摄信息未记录".appLocalized)
                        .font(.system(size: barHeight * 0.24, weight: .medium))
                        .opacity(0.72)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, barHeight * 0.34)
        .frame(width: barFrame.width, height: barHeight)
        .background {
            if isExporting {
                Capsule()
                    .fill(.black.opacity(0.30))
            }
        }

        .liquidGlass(in: Capsule(), variant: .clear)
        .shadow(color: .black.opacity(0.20), radius: 12, y: 5)
        .position(x: barFrame.midX, y: barFrame.midY)

        let barStateDescription: String
        if let customText = glassArchiveCustomText, !customText.isEmpty {
            barStateDescription = customText
        } else {
            barStateDescription = "\(deviceName)，\(timeText)"
        }

        return ZStack {
            primaryPhoto(size: size, cornerRadius: 0)

            bar
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "琉璃档案预览，\(barStateDescription)，可拖动档案栏调整位置，双击中间标志可更换标志"
        )
    }

    private func glassArchiveCustomTextFont(barHeight: CGFloat) -> Font {
        let size = barHeight * 0.26
        if glassArchiveCustomFont == .original {
            return .system(size: size, weight: .semibold)
        }
        return Font(glassArchiveCustomFont.uiFont(size: size))
    }

    @ViewBuilder
    private func glassArchivePinnedSwatches(barHeight: CGFloat) -> some View {
        if !glassArchivePinnedColors.isEmpty {
            HStack(spacing: barHeight * 0.10) {
                ForEach(Array(glassArchivePinnedColors.enumerated()), id: \.offset) { _, pinnedColor in
                    Circle()
                        .fill(pinnedColor.color)
                        .frame(width: barHeight * 0.28, height: barHeight * 0.28)
                }
            }
        }
    }

    @ViewBuilder
    private func glassArchiveMarkView(height: CGFloat) -> some View {
        if glassArchiveMark == .camera, let cameraWatermarkImage {
            Group {
                if cameraWatermarkImage.renderingMode == .alwaysOriginal {
                    Image(uiImage: cameraWatermarkImage)
                        .resizable()
                } else {
                    Image(uiImage: cameraWatermarkImage.withRenderingMode(.alwaysTemplate))
                        .resizable()
                        .foregroundStyle(.white)
                }
            }
            .scaledToFit()
            .frame(
                width: customWatermarkWidth(for: cameraWatermarkImage, height: height),
                height: height
            )
            .shadow(color: .black.opacity(0.30), radius: 2, y: 1)
        } else {
            Image(systemName: "applelogo")
                .font(.system(size: height * 0.86, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.30), radius: 2, y: 1)
        }
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
    private func sketch(size: CGSize) -> some View {
        SketchCanvas(
            sourceImage: images.first,
            sketchImage: sketchImage,
            palette: palette,
            palettePercentages: palettePercentages,
            metadata: metadata,
            parameters: sketchParameters,
            imageScale: imageScale,
            imageOffset: imageOffset,
            isExporting: isExporting
        )
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func classicSketch(size: CGSize) -> some View {
        ClassicSketchCanvas(
            sourceImage: images.first,
            sketchImage: classicSketchImage,
            imageScale: imageScale,
            imageOffset: imageOffset,
            isExporting: isExporting
        )
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

private struct IOS17TicketCodeImage: View {
    let style: TicketCodeStyle
    let payload: TicketPayload
    let baseURLString: String
    let deviceSealEnabled: Bool
    let pixelSize: CGSize
    let availableSize: CGSize
    let foreground: RGBColor

    @State private var cachedImage: UIImage?
    @State private var isLoading = true
    @State private var generationFailed = false

    private struct Request: Equatable {
        let style: TicketCodeStyle
        let payload: TicketPayload
        let baseURLString: String
        let deviceSealEnabled: Bool
        let pixelSize: CGSize
        let foreground: RGBColor
    }

    private var request: Request {
        Request(
            style: style,
            payload: payload,
            baseURLString: baseURLString,
            deviceSealEnabled: deviceSealEnabled,
            pixelSize: pixelSize,
            foreground: foreground
        )
    }

    var body: some View {
        Group {
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(
                        style == .barcode
                            ? pixelSize.width / pixelSize.height
                            : 1,
                        contentMode: .fit
                    )
                    .frame(
                        maxWidth: availableSize.width,
                        maxHeight: availableSize.height
                    )
                    .accessibilityLabel(
                        style == .barcode
                            ? "真实一维票根码"
                            : "App Clip 验证二维码"
                    )
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(
                        width: min(availableSize.width, 44),
                        height: min(availableSize.height, 44)
                    )
                    .accessibilityLabel("正在生成票根编码…")
            } else if generationFailed {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .frame(
                        width: min(availableSize.width, 44),
                        height: min(availableSize.height, 44)
                    )
                    .accessibilityLabel("票根编码生成失败")
            }
        }
        .task(id: request) {
            await generate(request)
        }
    }

    @MainActor
    private func generate(_ request: Request) async {
        cachedImage = nil
        generationFailed = false
        isLoading = true

        let result = await Task.detached(priority: .userInitiated) {
            () -> Result<UIImage, Error> in
            do {
                let image = try TicketCodeRenderer.image(
                    for: request.style,
                    payload: request.payload,
                    baseURLString: request.baseURLString,
                    signer: request.deviceSealEnabled
                        ? TicketDeviceSealService.shared
                        : nil,
                    pixelSize: request.pixelSize,
                    foregroundColor: UIColor(
                        red: request.foreground.red,
                        green: request.foreground.green,
                        blue: request.foreground.blue,
                        alpha: 1
                    ),
                    backgroundColor: nil
                )
                return .success(image)
            } catch {
                return .failure(error)
            }
        }.value

        guard !Task.isCancelled, self.request == request else { return }
        isLoading = false
        switch result {
        case let .success(image):
            cachedImage = image
        case .failure:
            generationFailed = true
        }
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
