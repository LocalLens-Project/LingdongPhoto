// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct ColorRelationshipCanvas: View {
    let leftPhoto: RelationshipPhoto
    let rightPhoto: RelationshipPhoto
    let relationship: ColorRelationship
    let lens: RelationshipLens
    var isExporting = false
    var comparisonOnly = false
    var showsPhotoLabels = true

    private enum PhotoOrientation {
        case landscape
        case portrait
        case square
    }

    private enum PairLayout: Equatable {
        case stacked
        case sideBySide
        case mixedPortraitLeft
        case mixedPortraitRight
    }

    private enum PhotoLabelPlacement {
        case top
        case bottom
    }

    static func preferredAspectRatio(left: UIImage, right: UIImage) -> CGFloat {
        switch resolvedLayout(left: left, right: right) {
        case .stacked:
            return 2.0 / 3.0
        case .sideBySide:
            return 0.86
        case .mixedPortraitLeft, .mixedPortraitRight:
            return 1.0
        }
    }

    static func preferredComparisonAspectRatio(left: UIImage, right: UIImage) -> CGFloat {
        let layout = resolvedLayout(left: left, right: right)
        let leftRatio = imageAspectRatio(left)
        let rightRatio = imageAspectRatio(right)
        let contentWidth: CGFloat = 1.0
        let height: CGFloat
        switch layout {
        case .stacked:
            height = contentWidth / leftRatio + contentWidth / rightRatio + 0.002
        case .sideBySide:
            let photoWidth = (contentWidth - 0.002) / 2
            height = max(photoWidth / leftRatio, photoWidth / rightRatio) + 0.14
        case .mixedPortraitLeft:
            height = max(contentWidth * 0.44 / leftRatio, contentWidth * 0.558 / rightRatio)
        case .mixedPortraitRight:
            height = max(contentWidth * 0.558 / leftRatio, contentWidth * 0.44 / rightRatio)
        }
        return 1 / max(height, 0.4)
    }

    /// Returns a canvas width that uses the smaller source in each allocated
    /// column at native resolution. This avoids calling an export "original"
    /// while silently enlarging one of the two photographs.
    static func nativeExportCanvasWidth(
        left: RelationshipPhoto,
        right: RelationshipPhoto,
        comparisonOnly: Bool
    ) -> CGFloat {
        let leftSize = sourcePixelSize(left)
        let rightSize = sourcePixelSize(right)
        switch resolvedLayout(left: left.image, right: right.image) {
        case .stacked:
            let nativePhotoWidth = min(leftSize.width, rightSize.width)
            guard !comparisonOnly else { return nativePhotoWidth }
            let naturalHeightFactor = 1 / imageAspectRatio(left.image)
                + 1 / imageAspectRatio(right.image)
            // A full stacked artwork reserves 34% of its height for the
            // analysis field. Compensate so the photographs can still reach
            // their native width before applying the global 8192 px cap.
            let displayedWidthScale = min(1, 0.99 / max(0.01, naturalHeightFactor))
            return nativePhotoWidth / displayedWidthScale
        case .sideBySide:
            return min(leftSize.width, rightSize.width) * 2 + 2
        case .mixedPortraitLeft:
            return min(leftSize.width / 0.44, rightSize.width / 0.558)
        case .mixedPortraitRight:
            return min(leftSize.width / 0.558, rightSize.width / 0.44)
        }
    }

    /// Calculates the largest decoded dimension each source needs for a given
    /// export canvas. The original files can therefore be decoded only as far
    /// as the layout will actually display them.
    static func requiredSourceMaximumDimensions(
        canvasWidth: CGFloat,
        left: RelationshipPhoto,
        right: RelationshipPhoto,
        comparisonOnly: Bool
    ) -> (left: Int, right: Int) {
        let ratio = comparisonOnly
            ? preferredComparisonAspectRatio(left: left.image, right: right.image)
            : preferredAspectRatio(left: left.image, right: right.image)
        let canvasHeight = canvasWidth / ratio
        let layout = resolvedLayout(left: left.image, right: right.image)
        let mediaMaximum = comparisonOnly
            ? canvasHeight
            : canvasHeight * (layout == .stacked ? 0.66 : 0.62)
        let leftRatio = imageAspectRatio(left.image)
        let rightRatio = imageAspectRatio(right.image)

        func rounded(_ value: CGFloat) -> Int {
            max(1, Int(ceil(value)))
        }

        switch layout {
        case .stacked:
            let leftHeight = canvasWidth / leftRatio
            let rightHeight = canvasWidth / rightRatio
            let naturalTotal = leftHeight + rightHeight + 2
            let scale = min(1, max(0, mediaMaximum - 2) / max(1, naturalTotal - 2))
            return (
                rounded(max(canvasWidth * scale, leftHeight * scale)),
                rounded(max(canvasWidth * scale, rightHeight * scale))
            )
        case .sideBySide:
            let photoWidth = (canvasWidth - 2) / 2
            let mediaHeight = min(
                mediaMaximum,
                max(photoWidth / leftRatio, photoWidth / rightRatio)
            )
            return (
                rounded(max(photoWidth, min(mediaHeight, photoWidth / leftRatio))),
                rounded(max(photoWidth, min(mediaHeight, photoWidth / rightRatio)))
            )
        case .mixedPortraitLeft, .mixedPortraitRight:
            let portraitWidth = canvasWidth * 0.44
            let otherWidth = canvasWidth - portraitWidth - 2
            let leftWidth = layout == .mixedPortraitLeft ? portraitWidth : otherWidth
            let rightWidth = layout == .mixedPortraitLeft ? otherWidth : portraitWidth
            let mediaHeight = min(
                mediaMaximum,
                max(leftWidth / leftRatio, rightWidth / rightRatio)
            )
            return (
                rounded(max(leftWidth, min(mediaHeight, leftWidth / leftRatio))),
                rounded(max(rightWidth, min(mediaHeight, rightWidth / rightRatio)))
            )
        }
    }

    private var layout: PairLayout {
        Self.resolvedLayout(left: leftPhoto.image, right: rightPhoto.image)
    }

    private var canvasAspectRatio: CGFloat {
        if comparisonOnly {
            return Self.preferredComparisonAspectRatio(
                left: leftPhoto.image,
                right: rightPhoto.image
            )
        }
        switch layout {
        case .stacked:
            return 2.0 / 3.0
        case .sideBySide:
            return 0.86
        case .mixedPortraitLeft, .mixedPortraitRight:
            return 1.0
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let mediaSize = CGSize(
                width: size.width,
                height: size.height
            )
            ZStack {
                if isExporting {
                    exportBackground
                }
                mediaLayout(size: mediaSize)
                    .offset(x: (size.width - mediaSize.width) / 2)
                if !comparisonOnly {
                    lowerField(size: size, reservesBand: layout == .sideBySide)
                }
                glassRelationshipBand(size: size, mediaSize: mediaSize)
            }
        }
        .aspectRatio(canvasAspectRatio, contentMode: .fit)
    }

    private var exportBackground: some View {
        let palette = relationship.leftPalette + relationship.rightPalette
        let first = palette.first ?? relationship.signatureColor
        let second = palette.dropFirst().first ?? relationship.signatureColor
        let third = palette.dropFirst(2).first ?? relationship.signatureColor
        return LinearGradient(
            colors: [
                adjusted(first, brightness: 0.20, saturation: -0.16).color,
                adjusted(second, brightness: 0.13, saturation: -0.22).color,
                adjusted(third, brightness: 0.18, saturation: -0.18).color
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func mediaLayout(size: CGSize) -> some View {
        let height = mediaHeight(size: size)
        switch layout {
        case .stacked:
            let naturalLeftHeight = size.width / photoAspectRatio(leftPhoto)
            let naturalRightHeight = size.width / photoAspectRatio(rightPhoto)
            let naturalTotal = naturalLeftHeight + naturalRightHeight
            let scale = min(1, (height - 2) / naturalTotal)
            VStack(spacing: 2) {
                canvasPhoto(
                    leftPhoto,
                    index: "01",
                    width: size.width,
                    height: naturalLeftHeight * scale
                )
                canvasPhoto(
                    rightPhoto,
                    index: "02",
                    width: size.width,
                    height: naturalRightHeight * scale,
                    labelPlacement: .bottom
                )
            }
            .frame(width: size.width, height: height)
            .position(x: size.width / 2, y: height / 2)

        case .sideBySide:
            let photoWidth = (size.width - 2) / 2
            HStack(spacing: 2) {
                canvasPhoto(
                    leftPhoto,
                    index: "01",
                    width: photoWidth,
                    height: min(height, photoWidth / photoAspectRatio(leftPhoto))
                )
                canvasPhoto(
                    rightPhoto,
                    index: "02",
                    width: photoWidth,
                    height: min(height, photoWidth / photoAspectRatio(rightPhoto))
                )
            }
            .frame(width: size.width, height: height)
            .position(x: size.width / 2, y: height / 2)

        case .mixedPortraitLeft:
            mixedMedia(size: size, portraitOnLeft: true)

        case .mixedPortraitRight:
            mixedMedia(size: size, portraitOnLeft: false)
        }
    }

    private func mixedMedia(size: CGSize, portraitOnLeft: Bool) -> some View {
        let height = mediaHeight(size: size)
        let portraitWidth = size.width * 0.44
        let otherWidth = size.width - portraitWidth - 2
        let portraitPhoto = portraitOnLeft ? leftPhoto : rightPhoto
        let landscapePhoto = portraitOnLeft ? rightPhoto : leftPhoto
        let portraitIndex = portraitOnLeft ? "01" : "02"
        let landscapeIndex = portraitOnLeft ? "02" : "01"
        let portraitHeight = min(height, portraitWidth / photoAspectRatio(portraitPhoto))
        let landscapeHeight = min(height, otherWidth / photoAspectRatio(landscapePhoto))
        return HStack(spacing: 2) {
            if !portraitOnLeft {
                mixedSecondaryColumn(
                    photo: landscapePhoto,
                    index: landscapeIndex,
                    width: otherWidth,
                    photoHeight: landscapeHeight,
                    totalHeight: height
                )
            }

            canvasPhoto(
                portraitPhoto,
                index: portraitIndex,
                width: portraitWidth,
                height: portraitHeight
            )
            .frame(width: portraitWidth, height: height, alignment: .top)

            if portraitOnLeft {
                mixedSecondaryColumn(
                    photo: landscapePhoto,
                    index: landscapeIndex,
                    width: otherWidth,
                    photoHeight: landscapeHeight,
                    totalHeight: height
                )
            }
        }
        .frame(width: size.width, height: height)
        .position(x: size.width / 2, y: height / 2)
    }

    private func mixedSecondaryColumn(
        photo: RelationshipPhoto,
        index: String,
        width: CGFloat,
        photoHeight: CGFloat,
        totalHeight: CGFloat
    ) -> some View {
        VStack(spacing: 2) {
            canvasPhoto(
                photo,
                index: index,
                width: width,
                height: photoHeight
            )
            Spacer(minLength: 0)
        }
        .frame(width: width, height: totalHeight)
    }

    private func canvasPhoto(
        _ photo: RelationshipPhoto,
        index: String,
        width: CGFloat,
        height: CGFloat,
        labelPlacement: PhotoLabelPlacement = .top
    ) -> some View {
        let reference = min(width, height)
        return ZStack {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(alignment: labelPlacement == .top ? .topLeading : .bottomLeading) {
            if showsPhotoLabels {
                Text(index)
                    .font(.system(size: max(8, reference * 0.08), weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, reference * 0.065)
                    .frame(height: reference * 0.16)
                    .background(.black.opacity(0.24), in: Capsule())
                    .padding(.horizontal, reference * 0.065)
                    .padding(.vertical, reference * 0.065)
            }
        }
    }

    private func lowerField(size: CGSize, reservesBand: Bool) -> some View {
        let ink = Color.primary.opacity(0.78)
        let mediaHeight = mediaHeight(size: size)
        let fieldHeight = size.height - mediaHeight
        let copy = relationship.copy(for: lens)
        return VStack(alignment: .leading, spacing: size.width * 0.022) {
            HStack(alignment: .firstTextBaseline) {
                Text(copy.title)
                    .font(.system(size: size.width * 0.065, weight: .bold, design: .rounded))
                Spacer()
                Text(lens.rawValue)
                    .font(.system(size: size.width * 0.027, weight: .bold, design: .rounded))
                    .padding(.horizontal, size.width * 0.035)
                    .frame(height: size.width * 0.075)
                    .background(ink.opacity(0.10), in: Capsule())
            }

            Text(copy.narrative)
                .font(.system(size: size.width * 0.035, weight: .medium, design: .rounded))
                .lineSpacing(size.width * 0.012)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            HStack(spacing: 0) {
                metric("色彩亲近", relationship.affinity, width: size.width)
                metric("明暗距离", relationship.lightDifference, width: size.width)
                metric("冷暖距离", relationship.temperatureDifference, width: size.width)
            }
            .padding(.top, size.width * 0.005)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, size.width * 0.065)
        .padding(.top, reservesBand ? size.width * 0.15 : size.width * 0.045)
        .padding(.bottom, size.width * 0.045)
        .frame(width: size.width, height: fieldHeight, alignment: .topLeading)
        .position(x: size.width / 2, y: mediaHeight + fieldHeight / 2)
    }

    private func metric(
        _ title: String,
        _ value: Int,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: width * 0.006) {
            Text(title)
                .font(.system(size: width * 0.022, weight: .medium, design: .rounded))
                .opacity(0.58)
            Text(String(format: "%02d", value))
                .font(.system(size: width * 0.038, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func glassRelationshipBand(size: CGSize, mediaSize: CGSize) -> some View {
        Group {
            switch lens {
            case .resonance:
                resonanceBand(size: size)
            case .contrast:
                contrastBand(size: size)
            case .bridge:
                bridgeBand(size: size)
            }
        }
        .frame(width: glassBandWidth(size: size, mediaSize: mediaSize), height: size.width * 0.25)
        .prototypeGlass(
            in: RoundedRectangle(cornerRadius: size.width * 0.055, style: .continuous),
            variant: .clear
        )
        .overlay {
            RoundedRectangle(cornerRadius: size.width * 0.055, style: .continuous)
                .stroke(.white.opacity(0.36), lineWidth: 1)
        }
        .position(
            x: size.width / 2,
            y: glassBandY(size: mediaSize)
        )
    }

    private func glassBandY(size: CGSize) -> CGFloat {
        switch layout {
        case .stacked:
            return stackedFirstPhotoHeight(size: size)
        case .sideBySide:
            return mediaHeight(size: size)
        case .mixedPortraitLeft, .mixedPortraitRight:
            return mixedLandscapeHeight(size: size)
        }
    }

    private func glassBandWidth(size: CGSize, mediaSize: CGSize) -> CGFloat {
        guard layout == .stacked else { return size.width * 0.84 }
        return mediaSize.width * stackedPhotoScale(size: mediaSize) * 0.84
    }

    private func stackedPhotoScale(size: CGSize) -> CGFloat {
        let naturalLeftHeight = size.width / photoAspectRatio(leftPhoto)
        let naturalRightHeight = size.width / photoAspectRatio(rightPhoto)
        let naturalTotal = naturalLeftHeight + naturalRightHeight
        return min(1, (mediaHeight(size: size) - 2) / naturalTotal)
    }

    private func stackedFirstPhotoHeight(size: CGSize) -> CGFloat {
        let naturalLeftHeight = size.width / photoAspectRatio(leftPhoto)
        return naturalLeftHeight * stackedPhotoScale(size: size)
    }

    private func mediaHeight(size: CGSize) -> CGFloat {
        let maximum = comparisonOnly
            ? size.height
            : size.height * (layout == .stacked ? 0.66 : 0.62)
        switch layout {
        case .stacked:
            let natural = size.width / photoAspectRatio(leftPhoto)
                + size.width / photoAspectRatio(rightPhoto)
                + 2
            return min(maximum, natural)
        case .sideBySide:
            let photoWidth = (size.width - 2) / 2
            let natural = max(
                photoWidth / photoAspectRatio(leftPhoto),
                photoWidth / photoAspectRatio(rightPhoto)
            )
            return min(maximum, natural)
        case .mixedPortraitLeft, .mixedPortraitRight:
            let portraitWidth = size.width * 0.44
            let otherWidth = size.width - portraitWidth - 2
            let portraitPhoto = layout == .mixedPortraitLeft ? leftPhoto : rightPhoto
            let landscapePhoto = layout == .mixedPortraitLeft ? rightPhoto : leftPhoto
            let natural = max(
                portraitWidth / photoAspectRatio(portraitPhoto),
                otherWidth / photoAspectRatio(landscapePhoto)
            )
            return min(maximum, natural)
        }
    }

    private func mixedLandscapeHeight(size: CGSize) -> CGFloat {
        let otherWidth = size.width - size.width * 0.44 - 2
        let landscapePhoto = layout == .mixedPortraitLeft ? rightPhoto : leftPhoto
        return min(mediaHeight(size: size), otherWidth / photoAspectRatio(landscapePhoto))
    }

    private func photoAspectRatio(_ photo: RelationshipPhoto) -> CGFloat {
        guard photo.image.size.height > 0 else { return 1 }
        return max(0.1, photo.image.size.width / photo.image.size.height)
    }

    private func resonanceBand(size: CGSize) -> some View {
        HStack(spacing: size.width * 0.024) {
            ForEach(relationship.resonancePairs.prefix(4)) { pair in
                VStack(spacing: size.width * 0.012) {
                    HStack(spacing: -size.width * 0.018) {
                        Circle().fill(pair.left.color)
                        Circle().fill(pair.right.color)
                    }
                    .frame(width: size.width * 0.11, height: size.width * 0.075)
                    Text(pair.middle.hex)
                        .font(.system(size: size.width * 0.019, weight: .semibold, design: .monospaced))
                        .foregroundStyle(evidenceInk)
                        .shadow(
                            color: evidenceInkShadow,
                            radius: usesDarkEvidenceInk ? 0.6 : 1,
                            y: 0.4
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, size.width * 0.035)
    }

    private func contrastBand(size: CGSize) -> some View {
        HStack(spacing: size.width * 0.025) {
            ForEach(relationship.contrastPairs.prefix(3)) { pair in
                VStack(spacing: size.width * 0.014) {
                    HStack(spacing: 0) {
                        Rectangle().fill(pair.left.color)
                        Rectangle().fill(pair.right.color)
                    }
                    .frame(height: size.width * 0.09)
                    .clipShape(Capsule())
                    Text("Δ \(Int((pair.distance * 100).rounded()))")
                        .font(.system(size: size.width * 0.021, weight: .bold, design: .monospaced))
                        .foregroundStyle(evidenceInk)
                        .shadow(
                            color: evidenceInkShadow,
                            radius: usesDarkEvidenceInk ? 0.6 : 1,
                            y: 0.4
                        )
                }
            }
        }
        .padding(.horizontal, size.width * 0.045)
    }

    private func bridgeBand(size: CGSize) -> some View {
        HStack(spacing: size.width * 0.012) {
            ForEach(relationship.bridge) { color in
                RoundedRectangle(cornerRadius: size.width * 0.025, style: .continuous)
                    .fill(color.color)
                    .frame(height: size.width * 0.12)
            }
        }
        .padding(.horizontal, size.width * 0.045)
    }

    private var evidenceColors: [PaletteColor] {
        switch lens {
        case .resonance:
            relationship.resonancePairs.prefix(4).map(\.middle)
        case .contrast:
            relationship.contrastPairs.prefix(3).map(\.middle)
        case .bridge:
            relationship.bridge
        }
    }

    private var usesDarkEvidenceInk: Bool {
        guard !evidenceColors.isEmpty else { return false }
        let averageLuminance = evidenceColors
            .map(\.relativeLuminance)
            .reduce(0, +) / Double(evidenceColors.count)
        return averageLuminance > 0.19
    }

    private var evidenceInk: Color {
        usesDarkEvidenceInk
            ? Color.black.opacity(0.90)
            : Color.white.opacity(0.94)
    }

    private var evidenceInkShadow: Color {
        usesDarkEvidenceInk
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.38)
    }

    private static func resolvedLayout(left: UIImage, right: UIImage) -> PairLayout {
        let leftOrientation = orientation(of: left)
        let rightOrientation = orientation(of: right)

        switch (leftOrientation, rightOrientation) {
        case (.landscape, .landscape), (.landscape, .square), (.square, .landscape):
            return .stacked
        case (.portrait, .portrait), (.portrait, .square), (.square, .portrait), (.square, .square):
            return .sideBySide
        case (.portrait, .landscape):
            return .mixedPortraitLeft
        case (.landscape, .portrait):
            return .mixedPortraitRight
        }
    }

    private static func orientation(of image: UIImage) -> PhotoOrientation {
        guard image.size.height > 0 else { return .square }
        let ratio = image.size.width / image.size.height
        if ratio > 1.08 { return .landscape }
        if ratio < 0.92 { return .portrait }
        return .square
    }

    private static func imageAspectRatio(_ image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 1 }
        return max(0.1, image.size.width / image.size.height)
    }

    private static func sourcePixelSize(_ photo: RelationshipPhoto) -> CGSize {
        if let size = photo.originalPixelSize, size.width > 0, size.height > 0 {
            return size
        }
        if let cgImage = photo.image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return photo.image.size
    }

    private func adjusted(
        _ color: PaletteColor,
        brightness: Double,
        saturation: Double
    ) -> PaletteColor {
        let average = (color.red + color.green + color.blue) / 3
        let factor = 1 + saturation
        return PaletteColor(
            red: min(max(average + (color.red - average) * factor + brightness, 0), 1),
            green: min(max(average + (color.green - average) * factor + brightness, 0), 1),
            blue: min(max(average + (color.blue - average) * factor + brightness, 0), 1),
            weight: color.weight
        )
    }
}
