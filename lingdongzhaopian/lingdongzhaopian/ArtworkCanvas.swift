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
    let showDeviceInfo: Bool
    let showBubbles: Bool
    let gentleBackground: Bool
    let imageScale: CGFloat
    let imageOffset: CGSize
    var metadata: PhotoMetadata = .empty
    var copy: ArtworkCopy = ArtworkCopy()
    var fontStyle: ArtworkFontStyle = .rounded
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
        let background = lightestColor.adjusted(brightness: 0.10, saturation: -0.08)
        let foreground = readableForeground(
            preferred: darkestColor.adjusted(brightness: -0.04, saturation: 0.04),
            background: background
        )
        return VStack(spacing: 0) {
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
            .frame(height: size.height * 0.43)

            primaryPhoto(
                size: CGSize(width: size.width, height: size.height * 0.57),
                cornerRadius: 0
            )
        }
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
                        paletteSwatch(index: index, color: color, size: size, compact: true)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 11)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                LazyVGrid(columns: columns, spacing: 11) {
                    ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { index, color in
                        paletteSwatch(index: index, color: color, size: size, compact: false)
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

    private func paletteSwatch(index: Int, color: RGBColor, size: CGSize, compact: Bool) -> some View {
        let requiredStage = index < 3 ? 2 : 3
        let diameter = size.width * (compact ? 0.090 : 0.14)
        return VStack(spacing: compact ? 2 : 4) {
            Circle()
                .fill(color.color)
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.12), radius: 7, y: 4)
            if showHexValues || useLiteraryColorNames {
                Text(useLiteraryColorNames ? color.literaryName : color.hex)
                    .font(.system(
                        size: max(5, size.width * (compact ? 0.015 : 0.022)),
                        weight: useLiteraryColorNames ? .semibold : .regular,
                        design: useLiteraryColorNames ? .rounded : .monospaced
                    ))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Text(String(format: "%.1f%%", percentages[index]))
                .font(.system(
                    size: max(5, size.width * (compact ? 0.014 : 0.020)),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(.white.opacity(0.76))
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

    private func bubbleStamp(size: CGSize) -> some View {
        let background = darkestColor.adjusted(brightness: -0.06, saturation: 0.12)
        let foregroundRGB = readableForeground(
            preferred: lightestColor.adjusted(brightness: 0.18, saturation: -0.04),
            background: background
        )
        let foreground = foregroundRGB.color
        let photoSide = size.width - 32
        return ZStack {
            background.color

            VStack(spacing: 0) {
                primaryPhoto(
                    size: CGSize(width: photoSide, height: photoSide),
                    cornerRadius: 0
                )
                .padding(.top, 16)

                HStack(spacing: 12) {
                    ZStack {
                        if showBubbles {
                            Circle()
                                .fill(foreground)
                        } else {
                            Circle().fill(.clear)
                        }
                    }
                    .frame(width: size.width * 0.1 * bubbleScale, height: size.width * 0.1 * bubbleScale)

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
                            if let cameraLine = metadata.cameraLine {
                                Text(cameraLine)
                                    .font(.system(size: max(4, size.width * 0.013)))
                                    .opacity(0.34)
                            }
                        }
                    }
                    .foregroundStyle(foreground)

                    Spacer()
                }
                .padding(.horizontal, size.width * 0.13)
                .frame(maxHeight: .infinity)
            }
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
        if selected.count <= 1 {
            primaryPhoto(size: size, cornerRadius: 3)
        } else if selected.count == 2 {
            VStack(spacing: 5) {
                journalCell(selected[0], size: CGSize(width: size.width, height: (size.height - 5) / 2))
                journalCell(selected[1], size: CGSize(width: size.width, height: (size.height - 5) / 2))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        } else if selected.count == 3 {
            HStack(spacing: 5) {
                journalCell(selected[0], size: CGSize(width: size.width * 0.58, height: size.height))
                VStack(spacing: 5) {
                    journalCell(selected[1], size: CGSize(width: size.width * 0.42 - 5, height: (size.height - 5) / 2))
                    journalCell(selected[2], size: CGSize(width: size.width * 0.42 - 5, height: (size.height - 5) / 2))
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        } else if selected.count == 4 {
            VStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(0..<2, id: \.self) { column in
                            journalCell(
                                selected[row * 2 + column],
                                size: CGSize(width: (size.width - 5) / 2, height: (size.height - 5) / 2)
                            )
                        }
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        } else {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    ForEach(0..<2, id: \.self) { index in
                        journalCell(
                            selected[index],
                            size: CGSize(width: (size.width - 5) / 2, height: size.height * 0.56)
                        )
                    }
                }
                HStack(spacing: 5) {
                    ForEach(2..<5, id: \.self) { index in
                        journalCell(
                            selected[index],
                            size: CGSize(width: (size.width - 10) / 3, height: size.height * 0.44 - 5)
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private func journalCell(_ image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
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
