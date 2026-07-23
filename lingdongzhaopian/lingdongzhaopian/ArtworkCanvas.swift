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
    var copy: ArtworkCopy = ArtworkCopy()
    var fontStyle: ArtworkFontStyle = .rounded
    var templateStyle: ArtworkTemplateStyle = .classic
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
        }
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
                        Text(metadata.captureTimeText)
                            .font(.system(size: max(7, size.width * 0.020), weight: .medium))
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
                background.color

                VStack(spacing: 3) {
                    Text(copy.title)
                        .font(fontStyle.font(size: max(8, size.width * 0.026) * textScale, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(metadata.captureTimeText)
                        .font(.system(size: max(6, size.width * 0.017), weight: .medium))
                }
                .foregroundStyle(foreground.color)
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
