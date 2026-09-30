// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreImage
import SwiftUI
import UIKit

enum ClassicSketchStyle: String, CaseIterable, Identifiable {
    case pencil = "铅笔素描"
    case charcoal = "炭笔速写"
    case watercolor = "水彩绘画"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .pencil: "pencil"
        case .charcoal: "paintbrush"
        case .watercolor: "drop.degreesign.fill"
        }
    }

    var defaultParameters: ClassicSketchParameters {
        switch self {
        case .pencil:
            ClassicSketchParameters(
                style: .pencil,
                intensity: 0.62,
                stroke: 0.50,
                paperTexture: true,
                colorRetention: 0.0
            )
        case .charcoal:
            ClassicSketchParameters(
                style: .charcoal,
                intensity: 0.70,
                stroke: 0.55,
                paperTexture: true,
                colorRetention: 0.0
            )
        case .watercolor:
            ClassicSketchParameters(
                style: .watercolor,
                intensity: 0.55,
                stroke: 0.45,
                paperTexture: false,
                colorRetention: 0.42
            )
        }
    }
}

struct ClassicSketchParameters: Equatable {
    var style: ClassicSketchStyle
    var intensity: Double
    var stroke: Double
    var paperTexture: Bool
    var colorRetention: Double

    static let defaultPencil = ClassicSketchStyle.pencil.defaultParameters
}

enum ClassicSketchFilterEngine {
    nonisolated private static let context: CIContext = {
        CIContext(options: [
            .cacheIntermediates: false,
            .useSoftwareRenderer: false
        ])
    }()

    nonisolated private static let paperColor = CIColor(
        red: 0.965,
        green: 0.945,
        blue: 0.882,
        alpha: 1.0
    )

    nonisolated static func render(
        _ image: UIImage,
        parameters: ClassicSketchParameters,
        maxDimension: CGFloat = 2048
    ) -> UIImage? {
        guard let normalized = normalizedImage(image),
              let cgImage = normalized.cgImage else { return nil }

        var input = CIImage(cgImage: cgImage)
        let longEdge = max(input.extent.width, input.extent.height)
        if longEdge > maxDimension {
            let scale = maxDimension / longEdge
            input = input.transformed(
                by: CGAffineTransform(scaleX: scale, y: scale)
            )
        }

        let extent = input.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        return renderedImage(
            input: input,
            parameters: parameters,
            extent: extent,
            stylizedOverride: nil
        )
    }

    nonisolated static func renderForExport(
        _ image: UIImage,
        parameters: ClassicSketchParameters,
        targetLongEdge: CGFloat
    ) -> UIImage? {
        guard !Task.isCancelled,
              let normalized = normalizedImage(image),
              let prepared = resizedImage(
                normalized,
                maxDimension: min(max(targetLongEdge, 1), 1536)
              ),
              let preparedCG = prepared.cgImage else { return nil }

        let input = CIImage(cgImage: preparedCG)
        let extent = input.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        let transferStyle: StyleTransferStyle = parameters.style == .watercolor
            ? .watercolor
            : .pencil
        let tiled = StyleTransferEngine.stylizeTiled(prepared, style: transferStyle)
        guard !Task.isCancelled else { return nil }
        let global = StyleTransferEngine.stylize(
            prepared,
            style: transferStyle,
            maxDimension: max(extent.width, extent.height)
        )
        guard !Task.isCancelled else { return nil }
        let stylizedOverride = coherentStylizedLayer(
            tiled: tiled,
            global: global,
            extent: extent,
            detailAmount: parameters.style == .watercolor ? 0.35 : 0.45
        )
        return renderedImage(
            input: input,
            parameters: parameters,
            extent: extent,
            stylizedOverride: stylizedOverride
        )
    }

    nonisolated private static func renderedImage(
        input: CIImage,
        parameters: ClassicSketchParameters,
        extent: CGRect,
        stylizedOverride: CIImage?
    ) -> UIImage? {

        let sketch: CIImage
        switch parameters.style {
        case .pencil:
            sketch = pencilSketch(
                input: input,
                parameters: parameters,
                extent: extent,
                stylizedOverride: stylizedOverride
            )
        case .charcoal:
            sketch = charcoalSketch(
                input: input,
                parameters: parameters,
                extent: extent,
                stylizedOverride: stylizedOverride
            )
        case .watercolor:
            sketch = watercolor(
                input: input,
                parameters: parameters,
                extent: extent,
                stylizedOverride: stylizedOverride
            )
        }

        let blended: CIImage
        let retention = min(max(parameters.colorRetention, 0), 1)
        if retention >= 0.999 {
            blended = input.cropped(to: extent)
        } else if retention <= 0.001 {
            blended = sketch
        } else {
            let mask = CIImage(color: CIColor(
                red: retention,
                green: retention,
                blue: retention,
                alpha: 1.0
            )).cropped(to: extent)
            blended = blendWithMask(
                input: input.cropped(to: extent),
                background: sketch,
                mask: mask
            )
        }

        let final = parameters.paperTexture
            ? applyPaperTexture(to: blended, extent: extent)
            : blended

        guard let output = final.cropped(to: extent) as CIImage?,
              let outputCG = context.createCGImage(output, from: extent) else {
            return nil
        }
        return UIImage(cgImage: outputCG, scale: 1, orientation: .up)
    }

    nonisolated private static func coherentStylizedLayer(
        tiled: UIImage?,
        global: UIImage?,
        extent: CGRect,
        detailAmount: Double
    ) -> CIImage? {
        let tiledImage = tiled?.cgImage.map { CIImage(cgImage: $0) }
        let globalImage = global?.cgImage.map { CIImage(cgImage: $0) }
        guard let tiledImage else { return globalImage }
        guard let globalImage else { return tiledImage }
        let amount = min(max(detailAmount, 0), 1)
        let mask = CIImage(
            color: CIColor(red: amount, green: amount, blue: amount, alpha: 1)
        ).cropped(to: extent)
        return blendWithMask(
            input: tiledImage.cropped(to: extent),
            background: globalImage.cropped(to: extent),
            mask: mask
        ).cropped(to: extent)
    }

    nonisolated private static func pencilSketch(
        input: CIImage,
        parameters: ClassicSketchParameters,
        extent: CGRect,
        stylizedOverride: CIImage? = nil
    ) -> CIImage {
        if let stylized = stylizedOverride
            ?? stylizedLayer(for: input, extent: extent, style: .pencil) {
            let gray = photoEffectMono(stylized)
            let contrast = 0.90 + max(0, min(1, parameters.stroke)) * 0.55
            let brightness = -0.02 + max(0, min(1, parameters.intensity)) * 0.04
            let toned = colorControls(
                gray,
                brightness: brightness,
                contrast: contrast,
                saturation: 0
            ) ?? gray
            let radius = 0.6 + max(0, min(1, parameters.intensity)) * 1.4
            let softened = gaussianBlur(toned, radius: radius)?.cropped(to: extent) ?? toned
            return softened.cropped(to: extent)
        }
        return pencilSketchFallback(input: input, parameters: parameters, extent: extent)
    }

    nonisolated private static func pencilSketchFallback(
        input: CIImage,
        parameters: ClassicSketchParameters,
        extent: CGRect
    ) -> CIImage {
        let gray = photoEffectMono(input)
        let inverted = colorInvert(gray)
        let radius = 3.0 + max(0, min(1, parameters.intensity)) * 18.0
        let blurred = gaussianBlur(inverted, radius: radius)?.cropped(to: extent) ?? inverted
        let dodge = colorDodgeBlend(top: blurred, bottom: gray) ?? gray
        let contrast = 0.90 + max(0, min(1, parameters.stroke)) * 0.80
        let toned = colorControls(
            dodge,
            brightness: -0.04,
            contrast: contrast,
            saturation: 0
        ) ?? dodge
        return toned.cropped(to: extent)
    }

    nonisolated private static func charcoalSketch(
        input: CIImage,
        parameters: ClassicSketchParameters,
        extent: CGRect,
        stylizedOverride: CIImage? = nil
    ) -> CIImage {
        if let stylized = stylizedOverride
            ?? stylizedLayer(for: input, extent: extent, style: .pencil) {
            let gray = photoEffectMono(stylized)
            let intensity = max(0, min(1, parameters.intensity))
            let stroke = max(0, min(1, parameters.stroke))
            let base = colorControls(
                gray,
                brightness: 0.02 - intensity * 0.08,
                contrast: 1.05 + stroke * 0.55,
                saturation: 0
            ) ?? gray
            let edgeImage = edges(gray) ?? gray
            let invertedEdges = colorInvert(edgeImage)
            let edgeRadius = 0.35 + stroke * 1.10
            let softenedEdges = gaussianBlur(invertedEdges, radius: edgeRadius)?.cropped(to: extent) ?? invertedEdges
            let ink = colorControls(
                softenedEdges,
                brightness: 0.10,
                contrast: 1.0 + intensity * 0.45,
                saturation: 0
            ) ?? softenedEdges
            let blended = multiplyBlend(top: ink, bottom: base) ?? base
            return blended.cropped(to: extent)
        }
        return charcoalSketchFallback(input: input, parameters: parameters, extent: extent)
    }

    nonisolated private static func charcoalSketchFallback(
        input: CIImage,
        parameters: ClassicSketchParameters,
        extent: CGRect
    ) -> CIImage {
        let gray = photoEffectMono(input)
        let intensity = max(0, min(1, parameters.intensity))
        let stroke = max(0, min(1, parameters.stroke))
        let base = colorControls(
            gray,
            brightness: 0.04 - intensity * 0.10,
            contrast: 1.0 + stroke * 0.65,
            saturation: 0
        ) ?? gray
        let edgeImage = edges(gray) ?? gray
        let invertedEdges = colorInvert(edgeImage)
        let softenedEdges = gaussianBlur(invertedEdges, radius: 0.5 + stroke)?.cropped(to: extent) ?? invertedEdges
        let ink = colorControls(
            softenedEdges,
            brightness: 0.12,
            contrast: 1.0 + intensity * 0.4,
            saturation: 0
        ) ?? softenedEdges
        let blended = multiplyBlend(top: ink, bottom: base) ?? base
        return blended.cropped(to: extent)
    }

    nonisolated private static func watercolor(
        input: CIImage,
        parameters: ClassicSketchParameters,
        extent: CGRect,
        stylizedOverride: CIImage? = nil
    ) -> CIImage {
        if let stylized = stylizedOverride
            ?? stylizedLayer(for: input, extent: extent, style: .watercolor) {
            return applyWatercolorWash(
                stylized: stylized,
                original: input,
                parameters: parameters,
                extent: extent
            )
        }
        return applyWatercolorWash(
            stylized: input,
            original: input,
            parameters: parameters,
            extent: extent
        )
    }

    nonisolated private static func stylizedLayer(
        for input: CIImage,
        extent: CGRect,
        style: StyleTransferStyle
    ) -> CIImage? {
        guard StyleTransferEngine.isAvailable(style: style) else { return nil }
        let context = CIContext(options: [.cacheIntermediates: false, .useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(input, from: extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        guard let stylized = StyleTransferEngine.stylize(uiImage, style: style, maxDimension: 720),
              let stylizedCG = stylized.cgImage else { return nil }
        let stylizedCI = CIImage(cgImage: stylizedCG)
        let stylizedExtent = stylizedCI.extent
        guard stylizedExtent.width > 0, stylizedExtent.height > 0 else { return nil }
        let scaleX = extent.width / stylizedExtent.width
        let scaleY = extent.height / stylizedExtent.height
        return stylizedCI.transformed(
            by: CGAffineTransform(
                translationX: -stylizedExtent.origin.x,
                y: -stylizedExtent.origin.y
            )
        ).transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    nonisolated private static func applyWatercolorWash(
        stylized: CIImage,
        original: CIImage,
        parameters: ClassicSketchParameters,
        extent: CGRect
    ) -> CIImage {
        let bloomRadius = 4.0 + max(0, min(1, parameters.intensity)) * 8.0
        let softened = bloom(stylized, radius: bloomRadius, intensity: 0.45) ?? stylized
        let saturation = 0.90 - max(0, min(1, parameters.intensity)) * 0.15
        let brightnessDelta = 0.02 + max(0, min(1, parameters.stroke)) * 0.03
        let toned = colorControls(
            softened,
            brightness: brightnessDelta,
            contrast: 1.06,
            saturation: saturation
        ) ?? softened

        let edges = edges(original) ?? CIImage()
        let edgesBloomed = bloom(edges, radius: 1.5, intensity: 0.4) ?? edges
        let ink = colorControls(
            edgesBloomed,
            brightness: -0.05,
            contrast: 0.9,
            saturation: -1.0
        ) ?? edgesBloomed
        let composited = multiplyBlend(top: ink, bottom: toned) ?? toned
        return composited.cropped(to: extent)
    }

    nonisolated private static func applyPaperTexture(
        to image: CIImage,
        extent: CGRect
    ) -> CIImage {
        let paper = CIImage(color: paperColor).cropped(to: extent)
        let noise = randomNoise(extent: extent)
        let tonedNoise = colorControls(
            noise,
            brightness: 0.62,
            contrast: 0.18,
            saturation: -1.0
        ) ?? noise
        let texturedPaper = multiplyBlend(top: tonedNoise, bottom: paper) ?? paper
        return multiplyBlend(top: image, bottom: texturedPaper) ?? image
    }

    nonisolated private static func photoEffectMono(_ input: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIPhotoEffectMono") else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        return filter.outputImage ?? input
    }

    nonisolated private static func colorInvert(_ input: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorInvert") else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        return filter.outputImage ?? input
    }

    nonisolated private static func gaussianBlur(_ input: CIImage, radius: Double) -> CIImage? {
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        return filter.outputImage
    }

    nonisolated private static func colorDodgeBlend(top: CIImage, bottom: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorDodgeBlendMode") else { return nil }
        filter.setValue(top, forKey: kCIInputImageKey)
        filter.setValue(bottom, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage
    }

    nonisolated private static func multiplyBlend(top: CIImage, bottom: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIMultiplyBlendMode") else { return nil }
        filter.setValue(top, forKey: kCIInputImageKey)
        filter.setValue(bottom, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage
    }

    nonisolated private static func blendWithMask(
        input: CIImage,
        background: CIImage,
        mask: CIImage
    ) -> CIImage {
        guard let filter = CIFilter(name: "CIBlendWithMask") else { return background }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(background, forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)
        return filter.outputImage ?? background
    }

    nonisolated private static func colorControls(
        _ input: CIImage,
        brightness: Double,
        contrast: Double,
        saturation: Double
    ) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        return filter.outputImage
    }

    nonisolated private static func edges(_ input: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIEdges") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(1.0, forKey: kCIInputIntensityKey)
        return filter.outputImage
    }

    nonisolated private static func bloom(
        _ input: CIImage,
        radius: Double,
        intensity: Double
    ) -> CIImage? {
        guard let filter = CIFilter(name: "CIBloom") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        return filter.outputImage
    }

    nonisolated private static func medianFilter(_ input: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIMedianFilter") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        return filter.outputImage
    }

    nonisolated private static func randomNoise(extent: CGRect) -> CIImage {
        guard let generator = CIFilter(name: "CIRandomGenerator") else {
            return CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
                .cropped(to: extent)
        }
        let noise = generator.outputImage ?? CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
        return noise.cropped(to: extent)
    }

    nonisolated private static func normalizedImage(_ image: UIImage) -> UIImage? {
        if image.imageOrientation == .up, image.scale == 1, image.cgImage != nil {
            return image
        }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    nonisolated private static func resizedImage(
        _ image: UIImage,
        maxDimension: CGFloat
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let longEdge = max(width, height)
        guard longEdge > 0 else { return nil }
        let scale = min(1, maxDimension / longEdge)
        if scale >= 0.999 { return image }
        let targetSize = CGSize(
            width: max(1, (width * scale).rounded()),
            height: max(1, (height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct ClassicSketchCanvas: View {
    let sourceImage: UIImage?
    let sketchImage: UIImage?
    let imageScale: CGFloat
    let imageOffset: CGSize
    let isExporting: Bool

    var body: some View {
        GeometryReader { proxy in
            let canvas = proxy.size
            let displayed = sketchImage ?? sourceImage
            let contentSize = aspectFitSize(
                imageSize: displayed?.size ?? canvas,
                canvasSize: canvas
            )
            ZStack {
                Color.black.opacity(0.88)

                if let displayed {
                    Image(uiImage: displayed)
                        .resizable()
                        .scaledToFill()
                        .frame(width: contentSize.width, height: contentSize.height)
                        .clipped()
                        .scaleEffect(imageScale)
                        .offset(imageOffset)
                } else {
                    Image(systemName: "pencil.and.ruler")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: canvas.width, height: canvas.height)
            .clipped()
        }
    }

    private func aspectFitSize(imageSize: CGSize, canvasSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return canvasSize }
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

struct ClassicSketchEditorControls: View {
    @Binding var parameters: ClassicSketchParameters
    let isRendering: Bool
    let onStyleChange: (ClassicSketchStyle) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                ForEach(ClassicSketchStyle.allCases) { style in
                    Button {
                        onStyleChange(style)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Label(LocalizedStringKey(style.rawValue), systemImage: style.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(parameters.style == style ? .white : .primary.opacity(0.68))
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(
                                parameters.style == style ? Color.black.opacity(0.78) : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.rawValue)
                    .accessibilityAddTraits(parameters.style == style ? .isSelected : [])
                }
                Spacer(minLength: 4)
                if isRendering {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 42)
            .liquidGlass(in: Capsule(), variant: .clear)

            sliderRow(
                label: "强度",
                value: $parameters.intensity,
                symbol: "waveform",
                legend: parameters.intensity < 0.34 ? "淡" : parameters.intensity < 0.68 ? "中" : "强"
            )

            sliderRow(
                label: "笔触",
                value: $parameters.stroke,
                symbol: "scribble.variable",
                legend: parameters.stroke < 0.34 ? "细" : parameters.stroke < 0.68 ? "中" : "粗"
            )

            sliderRow(
                label: "色彩保留",
                value: $parameters.colorRetention,
                symbol: "paintpalette.fill",
                legend: parameters.colorRetention < 0.05
                    ? "纯素描"
                    : parameters.colorRetention > 0.95
                        ? "原色"
                        : "混色"
            )

            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: parameters.paperTexture ? "doc.text.fill" : "doc.text")
                        .font(.system(size: 14, weight: .semibold))
                    Toggle("纸张纹理", isOn: $parameters.paperTexture)
                        .labelsHidden()
                        .tint(.primary)
                    Text(parameters.paperTexture ? "纸面" : "无纸")
                        .font(.caption2.bold())
                        .frame(width: 30, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .liquidGlass(in: Capsule(), variant: .clear)
                .accessibilityLabel("纸张纹理 \(parameters.paperTexture ? "已开启" : "已关闭")")

                Button {
                    parameters = parameters.style.defaultParameters
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 84, height: 44)
                }
                .buttonStyle(LiquidPressButtonStyle())
                .foregroundStyle(.primary.opacity(0.82))
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                .accessibilityLabel("恢复当前风格的默认参数")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isRendering)
    }

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        symbol: String,
        legend: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
            Text(LocalizedStringKey(label))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)
            Slider(value: value, in: 0...1)
                .tint(.primary)
                .frame(minWidth: 68)
            Text(LocalizedStringKey(legend))
                .font(.caption2.bold())
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .liquidGlass(in: Capsule(), variant: .clear)
    }
}
