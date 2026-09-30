// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreImage
import SwiftUI
import UIKit
import Vision

enum SketchStyle: String, CaseIterable, Identifiable, Sendable {
    case pencil = "铅笔"
    case charcoal = "炭笔"
    case watercolor = "水色"
    case ink = "墨意"

    var id: String { rawValue }

    nonisolated var symbol: String {
        switch self {
        case .pencil: "pencil"
        case .charcoal: "paintbrush"
        case .watercolor: "drop.degreesign.fill"
        case .ink: "aqi.medium"
        }
    }

    nonisolated var artworkTitle: String {
        switch self {
        case .pencil: "PENCIL STUDY"
        case .charcoal: "CHARCOAL STUDY"
        case .watercolor: "WATERCOLOUR STUDY"
        case .ink: "INK & MEMORY"
        }
    }

    var defaultParameters: SketchParameters {
        switch self {
        case .pencil:
            SketchParameters(style: .pencil, intensity: 0.62, stroke: 0.50,
                             wetness: 0.18, blankness: 0.18, colorRetention: 0,
                             paper: .cotton, presentation: .artwork, brush: .horizontal)
        case .charcoal:
            SketchParameters(style: .charcoal, intensity: 0.70, stroke: 0.58,
                             wetness: 0.12, blankness: 0.22, colorRetention: 0,
                             paper: .rough, presentation: .artwork, brush: .dry)
        case .watercolor:
            SketchParameters(style: .watercolor, intensity: 0.16, stroke: 0.52,
                             wetness: 0.58, blankness: 0.18, colorRetention: 1,
                             paper: .cotton, presentation: .studySheet, brush: .horizontal)
        case .ink:
            SketchParameters(style: .ink, intensity: 0.68, stroke: 0.62,
                             wetness: 0.52, blankness: 0.42, colorRetention: 0.16,
                             paper: .xuan, presentation: .studySheet, brush: .rising)
        }
    }
}

enum SketchPaper: String, CaseIterable, Identifiable, Sendable {
    case cotton = "棉纸"
    case xuan = "细宣"
    case rough = "粗纹"

    var id: String { rawValue }

    nonisolated var symbol: String {
        switch self {
        case .cotton: "square.fill.text.grid.1x2"
        case .xuan: "scroll"
        case .rough: "circle.hexagongrid"
        }
    }

    nonisolated var uiColor: UIColor {
        switch self {
        case .cotton: UIColor(red: 0.985, green: 0.980, blue: 0.958, alpha: 1)
        case .xuan: UIColor(red: 0.954, green: 0.941, blue: 0.892, alpha: 1)
        case .rough: UIColor(red: 0.941, green: 0.916, blue: 0.842, alpha: 1)
        }
    }

    nonisolated var grainContrast: Double {
        switch self {
        case .cotton: 0.12
        case .xuan: 0.08
        case .rough: 0.23
        }
    }
}

enum SketchPresentation: String, CaseIterable, Identifiable, Sendable {
    case artwork = "独幅画心"
    case studySheet = "一照两境"

    var id: String { rawValue }

    nonisolated var symbol: String {
        switch self {
        case .artwork: "photo"
        case .studySheet: "rectangle.split.2x1"
        }
    }
}

enum SketchBrush: String, CaseIterable, Identifiable, Sendable {
    case horizontal = "横扫"
    case rising = "上扬"
    case falling = "下掠"
    case vertical = "竖落"
    case arc = "弧扫"
    case dry = "枯笔"

    var id: String { rawValue }

    nonisolated var symbol: String {
        switch self {
        case .horizontal: "arrow.right"
        case .rising: "arrow.up.right"
        case .falling: "arrow.down.right"
        case .vertical: "arrow.down"
        case .arc: "arrow.turn.up.right"
        case .dry: "scribble"
        }
    }

    nonisolated var angle: CGFloat {
        switch self {
        case .horizontal, .arc, .dry: 0
        case .rising: -.pi / 11
        case .falling: .pi / 11
        case .vertical: .pi / 2
        }
    }
}

struct SketchParameters: Equatable, Sendable {
    var style: SketchStyle
    var intensity: Double
    var stroke: Double
    var wetness: Double
    var blankness: Double
    var colorRetention: Double
    var paper: SketchPaper
    var presentation: SketchPresentation
    var brush: SketchBrush
    var activePigmentIndexes: Set<Int> = Set(0..<6)
    var typographyRaw = "original"
    var customTitle = ""
    var customLocation = ""

    static let defaultPencil = SketchStyle.pencil.defaultParameters
    static let defaultBrush = SketchStyle.watercolor.defaultParameters

    nonisolated func pigments(from palette: [RGBColor]) -> [RGBColor] {
        let source = palette.isEmpty ? Self.fallbackPigments : palette
        let selected = source.enumerated().compactMap { index, color in
            activePigmentIndexes.contains(index) ? color : nil
        }
        return selected.isEmpty ? [source[0]] : selected
    }

    nonisolated private static let fallbackPigments: [RGBColor] = [
        RGBColor(red: 0.78, green: 0.91, blue: 0.48),
        RGBColor(red: 0.34, green: 0.53, blue: 0.31),
        RGBColor(red: 0.91, green: 0.95, blue: 0.64),
        RGBColor(red: 0.18, green: 0.32, blue: 0.18),
        RGBColor(red: 0.66, green: 0.76, blue: 0.37),
        RGBColor(red: 0.93, green: 0.87, blue: 0.54)
    ]
}

enum SketchFilterEngine {
    nonisolated private static let context = CIContext(options: [
        .cacheIntermediates: false,
        .useSoftwareRenderer: false
    ])

    nonisolated static func render(
        _ image: UIImage,
        parameters: SketchParameters,
        palette: [RGBColor],
        maxDimension: CGFloat = 1600
    ) -> UIImage? {
        guard let normalized = normalizedImage(image), let cgImage = normalized.cgImage else { return nil }
        var input = CIImage(cgImage: cgImage)
        let longEdge = max(input.extent.width, input.extent.height)
        if longEdge > maxDimension {
            let scale = maxDimension / longEdge
            input = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        return renderedImage(input: input, parameters: parameters,
                             palette: parameters.pigments(from: palette), stylizedOverride: nil)
    }

    nonisolated static func renderForExport(
        _ image: UIImage,
        parameters: SketchParameters,
        palette: [RGBColor],
        targetLongEdge: CGFloat
    ) -> UIImage? {
        guard !Task.isCancelled,
              let normalized = normalizedImage(image),
              let prepared = resizedImage(normalized, maxDimension: min(max(targetLongEdge, 1), 4096)),
              let preparedCG = prepared.cgImage else { return nil }

        let input = CIImage(cgImage: preparedCG)
        let stylizedOverride: CIImage?
        if parameters.style == .pencil || parameters.style == .charcoal {
            let tiled = StyleTransferEngine.stylizeTiled(prepared, style: .pencil)
            guard !Task.isCancelled else { return nil }
            let global = StyleTransferEngine.stylize(
                prepared,
                style: .pencil,
                maxDimension: min(max(input.extent.width, input.extent.height), 1280)
            )
            stylizedOverride = coherentStylizedLayer(
                tiled: tiled, global: global, extent: input.extent,
                detailAmount: parameters.style == .pencil ? 0.46 : 0.38
            )
        } else {
            stylizedOverride = nil
        }
        guard !Task.isCancelled else { return nil }
        return renderedImage(input: input, parameters: parameters,
                             palette: parameters.pigments(from: palette),
                             stylizedOverride: stylizedOverride)
    }

    nonisolated private static func renderedImage(
        input: CIImage,
        parameters: SketchParameters,
        palette: [RGBColor],
        stylizedOverride: CIImage?
    ) -> UIImage? {
        let extent = input.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }
        let focusMask = sceneFocusMask(input: input, extent: extent)
        let painted: CIImage
        switch parameters.style {
        case .pencil:
            painted = pencilSketch(input: input, parameters: parameters, extent: extent,
                                   stylizedOverride: stylizedOverride)
        case .charcoal:
            painted = charcoalSketch(input: input, parameters: parameters, extent: extent,
                                     stylizedOverride: stylizedOverride)
        case .watercolor:
            painted = watercolor(input: input, parameters: parameters, palette: palette,
                                 focusMask: focusMask, extent: extent)
        case .ink:
            painted = inkPainting(input: input, parameters: parameters, palette: palette,
                                  focusMask: focusMask, extent: extent)
        }

        let colorAdjusted: CIImage
        if parameters.style == .pencil || parameters.style == .charcoal {
            colorAdjusted = blend(input: input, background: painted,
                                  amount: parameters.colorRetention.clamped, extent: extent)
        } else {
            colorAdjusted = painted
        }
        let surfaced = applyPaperSurface(to: colorAdjusted, paper: parameters.paper, extent: extent)
        guard let outputCG = context.createCGImage(surfaced.cropped(to: extent), from: extent) else {
            return nil
        }
        return UIImage(cgImage: outputCG, scale: 1, orientation: .up)
    }

    nonisolated private static func sceneFocusMask(input: CIImage, extent: CGRect) -> CIImage {
        guard let cgImage = context.createCGImage(input, from: extent) else {
            return constantMask(0, extent: extent)
        }
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([saliencyRequest, faceRequest])

        var mask = constantMask(0, extent: extent)
        if let observation = saliencyRequest.results?.first,
           let saliency = scaledToExtent(CIImage(cvPixelBuffer: observation.pixelBuffer), extent: extent) {
            let softened = gaussianBlur(saliency, radius: 10)?.cropped(to: extent) ?? saliency
            mask = maximum(top: softened, bottom: mask) ?? softened
        }
        for face in faceRequest.results ?? [] {
            let bounds = face.boundingBox
            let expanded = bounds.insetBy(dx: -bounds.width * 0.22, dy: -bounds.height * 0.22)
            let rect = CGRect(
                x: extent.minX + expanded.minX * extent.width,
                y: extent.minY + expanded.minY * extent.height,
                width: expanded.width * extent.width,
                height: expanded.height * extent.height
            ).intersection(extent)
            let faceLayer = CIImage(color: .white).cropped(to: rect)
            let feathered = gaussianBlur(faceLayer.clampedToExtent(), radius: max(8, rect.width * 0.06))?
                .cropped(to: extent) ?? faceLayer
            mask = maximum(top: feathered, bottom: mask) ?? mask
        }
        return colorControls(mask, brightness: -0.06, contrast: 1.34, saturation: 0)?
            .cropped(to: extent) ?? mask
    }

    nonisolated private static func pencilSketch(
        input: CIImage,
        parameters: SketchParameters,
        extent: CGRect,
        stylizedOverride: CIImage?
    ) -> CIImage {
        if let stylized = stylizedOverride ?? stylizedLayer(for: input, extent: extent) {
            let gray = photoEffectMono(stylized)
            let toned = colorControls(
                gray,
                brightness: -0.015 + parameters.intensity.clamped * 0.035,
                contrast: 0.90 + parameters.stroke.clamped * 0.58,
                saturation: 0
            ) ?? gray
            return (gaussianBlur(toned, radius: 0.45 + parameters.intensity.clamped * 1.1) ?? toned)
                .cropped(to: extent)
        }
        let gray = photoEffectMono(input)
        let inverted = colorInvert(gray)
        let blurred = gaussianBlur(inverted, radius: 3 + parameters.intensity.clamped * 16)?
            .cropped(to: extent) ?? inverted
        let dodge = colorDodgeBlend(top: blurred, bottom: gray) ?? gray
        return (colorControls(dodge, brightness: -0.035,
                              contrast: 0.94 + parameters.stroke.clamped * 0.76,
                              saturation: 0) ?? dodge).cropped(to: extent)
    }

    nonisolated private static func charcoalSketch(
        input: CIImage,
        parameters: SketchParameters,
        extent: CGRect,
        stylizedOverride: CIImage?
    ) -> CIImage {
        let baseSource = stylizedOverride ?? stylizedLayer(for: input, extent: extent) ?? input
        let gray = photoEffectMono(baseSource)
        let base = colorControls(gray,
                                 brightness: 0.025 - parameters.intensity.clamped * 0.085,
                                 contrast: 1.06 + parameters.stroke.clamped * 0.54,
                                 saturation: 0) ?? gray
        let edgeImage = edges(photoEffectMono(input), intensity: 1.1 + parameters.stroke.clamped * 1.2) ?? gray
        let invertedEdges = colorInvert(edgeImage)
        let brokenLine = displacement(input: invertedEdges,
                                      map: paperNoise(extent: extent, paper: .rough),
                                      scale: 1.2 + parameters.intensity.clamped * 2.4) ?? invertedEdges
        let ink = colorControls(
            gaussianBlur(brokenLine, radius: 0.35 + parameters.stroke.clamped * 0.7) ?? brokenLine,
            brightness: 0.08,
            contrast: 1.08 + parameters.intensity.clamped * 0.52,
            saturation: 0
        ) ?? brokenLine
        return (multiplyBlend(top: ink, bottom: base) ?? base).cropped(to: extent)
    }

    nonisolated private static func watercolor(
        input: CIImage,
        parameters: SketchParameters,
        palette _: [RGBColor],
        focusMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let expression = parameters.intensity.clamped
        let wetness = parameters.wetness.clamped
        let structure = parameters.stroke.clamped
        let cleaned = noiseReduction(input, level: 0.008 + expression * 0.018,
                                     sharpness: 0.34 + structure * 0.16) ?? input
        let natural = colorControls(
            cleaned,
            brightness: 0.006 + expression * 0.018,
            contrast: 1.01 - expression * 0.06,
            saturation: 1.0 - expression * 0.08
        ) ?? cleaned
        let softlyDiffused = gaussianBlur(natural, radius: 0.18 + wetness * 0.62)?
            .cropped(to: extent) ?? natural
        let subtleWash = blend(input: softlyDiffused, background: natural,
                               amount: 0.08 + wetness * 0.10, extent: extent)
        let focused = blendWithMask(input: input, background: subtleWash, mask: focusMask)
            .cropped(to: extent)
        return applyHighlightReserve(to: focused, source: input,
                                     amount: parameters.blankness.clamped * 0.10,
                                     paper: parameters.paper, extent: extent)
    }

    nonisolated private static func inkPainting(
        input: CIImage,
        parameters: SketchParameters,
        palette: [RGBColor],
        focusMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let expression = parameters.intensity.clamped
        let structure = parameters.stroke.clamped
        let wetness = parameters.wetness.clamped
        let paper = paperBase(parameters.paper, extent: extent)
        let mono = photoEffectMono(noiseReduction(input, level: 0.025, sharpness: 0.20) ?? input)
        let masses = colorPosterize(mono, levels: 8 - expression * 3.2) ?? mono
        let diluted = gaussianBlur(masses, radius: 0.8 + wetness * 3.6)?
            .cropped(to: extent) ?? masses
        let displaced = displacement(input: diluted,
                                     map: paperNoise(extent: extent, paper: parameters.paper),
                                     scale: 1.2 + wetness * 5.2)?.cropped(to: extent) ?? diluted
        let toned = colorControls(displaced,
                                  brightness: 0.035 + parameters.blankness.clamped * 0.07,
                                  contrast: 1.04 + expression * 0.46,
                                  saturation: 0) ?? displaced

        let edgeMap = edges(mono, intensity: 0.9 + structure * 1.9) ?? mono
        let dryMap = displacement(input: colorInvert(edgeMap),
                                  map: paperNoise(extent: extent, paper: .rough),
                                  scale: 1.0 + structure * 3.2) ?? colorInvert(edgeMap)
        let line = colorControls(
            gaussianBlur(dryMap, radius: 0.25 + wetness * 0.55) ?? dryMap,
            brightness: 0.04, contrast: 1.0 + structure * 0.72, saturation: 0
        ) ?? dryMap
        var ink = multiplyBlend(top: line, bottom: toned) ?? toned

        let colorAmount = parameters.colorRetention.clamped
        if colorAmount > 0.01 {
            let accent = paletteMap(input, palette: palette,
                                    fidelity: min(0.78, colorAmount + 0.26),
                                    expression: 0.78, extent: extent)
            let paleAccent = colorControls(accent, brightness: 0.08,
                                           contrast: 0.92, saturation: 0.62) ?? accent
            ink = blend(input: multiplyBlend(top: ink, bottom: paleAccent) ?? ink,
                        background: ink, amount: colorAmount * 0.62, extent: extent)
        }

        let focusedInk = multiplyBlend(top: colorInvert(edgeMap), bottom: ink) ?? ink
        ink = blendWithMask(
            input: focusedInk,
            background: ink,
            mask: blend(input: focusMask, background: constantMask(0, extent: extent),
                        amount: 0.18 + structure * 0.34, extent: extent)
        )
        let reserved = applyHighlightReserve(to: ink, source: input,
                                             amount: parameters.blankness.clamped,
                                             paper: parameters.paper, extent: extent)
        return multiplyBlend(top: reserved, bottom: paper) ?? reserved
    }

    nonisolated private static func paletteMap(
        _ input: CIImage,
        palette: [RGBColor],
        fidelity: Double,
        expression: Double,
        extent: CGRect
    ) -> CIImage {
        let colors = palette.isEmpty ? RGBColor.fallback : palette
        let dimension = 16
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)
        for blueIndex in 0..<dimension {
            let blue = Double(blueIndex) / Double(dimension - 1)
            for greenIndex in 0..<dimension {
                let green = Double(greenIndex) / Double(dimension - 1)
                for redIndex in 0..<dimension {
                    let red = Double(redIndex) / Double(dimension - 1)
                    let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
                    let nearest = colors.min { lhs, rhs in
                        rgbDistance(red, green, blue, lhs) < rgbDistance(red, green, blue, rhs)
                    } ?? colors[0]
                    let pigmentLuminance = max(Double(nearest.red) * 0.2126
                        + Double(nearest.green) * 0.7152
                        + Double(nearest.blue) * 0.0722, 0.08)
                    let toneScale = min(max(0.38 + luminance / pigmentLuminance * 0.62, 0.38), 1.45)
                    let mappedRed = min(Double(nearest.red) * toneScale, 1)
                    let mappedGreen = min(Double(nearest.green) * toneScale, 1)
                    let mappedBlue = min(Double(nearest.blue) * toneScale, 1)
                    let weight = min(max((0.44 + expression * 0.42) * (1 - fidelity * 0.34), 0), 0.92)
                    cube.append(Float(red * (1 - weight) + mappedRed * weight))
                    cube.append(Float(green * (1 - weight) + mappedGreen * weight))
                    cube.append(Float(blue * (1 - weight) + mappedBlue * weight))
                    cube.append(1)
                }
            }
        }
        let data = cube.withUnsafeBytes { Data($0) }
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(dimension, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(CGColorSpace(name: CGColorSpace.sRGB), forKey: "inputColorSpace")
        return (filter.outputImage ?? input).cropped(to: extent)
    }

    nonisolated private static func rgbDistance(
        _ red: Double, _ green: Double, _ blue: Double, _ color: RGBColor
    ) -> Double {
        let redDelta = red - Double(color.red)
        let greenDelta = green - Double(color.green)
        let blueDelta = blue - Double(color.blue)
        return redDelta * redDelta * 0.30
            + greenDelta * greenDelta * 0.58
            + blueDelta * blueDelta * 0.12
    }

    nonisolated private static func applyHighlightReserve(
        to image: CIImage,
        source: CIImage,
        amount: Double,
        paper: SketchPaper,
        extent: CGRect
    ) -> CIImage {
        guard amount > 0.001 else { return image }
        let luminance = photoEffectMono(source)
        let highlightMask = colorControls(luminance,
                                          brightness: -0.10 + amount * 0.14,
                                          contrast: 1.30 + amount * 0.65,
                                          saturation: 0) ?? luminance
        let strength = constantMask(0.10 + amount * 0.56, extent: extent)
        let mask = multiplyBlend(top: highlightMask, bottom: strength) ?? highlightMask
        return blendWithMask(input: paperBase(paper, extent: extent),
                             background: image, mask: mask).cropped(to: extent)
    }

    nonisolated private static func applyPaperSurface(
        to image: CIImage,
        paper: SketchPaper,
        extent: CGRect
    ) -> CIImage {
        let surface = paperBase(paper, extent: extent)
        let noise = paperNoise(extent: extent, paper: paper)
        let texturedPaper = multiplyBlend(top: noise, bottom: surface) ?? surface
        let paperMix = multiplyBlend(top: image, bottom: texturedPaper) ?? image
        return blend(input: paperMix, background: image,
                     amount: 0.22 + paper.grainContrast, extent: extent)
    }

    nonisolated private static func paperBase(_ paper: SketchPaper, extent: CGRect) -> CIImage {
        let color = paper.uiColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return CIImage(color: CIColor(red: red, green: green, blue: blue, alpha: 1))
            .cropped(to: extent)
    }

    nonisolated private static func paperNoise(extent: CGRect, paper: SketchPaper) -> CIImage {
        guard let generator = CIFilter(name: "CIRandomGenerator"),
              let generated = generator.outputImage else {
            return constantMask(0.93, extent: extent)
        }
        let scale: CGFloat = paper == .rough ? 1.8 : (paper == .xuan ? 0.72 : 1.15)
        let shifted = generated
            .transformed(by: CGAffineTransform(translationX: 47, y: 113))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return (colorControls(shifted, brightness: 0.56,
                              contrast: paper.grainContrast, saturation: -1) ?? shifted)
            .cropped(to: extent)
    }

    nonisolated private static func stylizedLayer(for input: CIImage, extent: CGRect) -> CIImage? {
        guard StyleTransferEngine.isAvailable(style: .pencil),
              let cgImage = context.createCGImage(input, from: extent) else { return nil }
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        guard let stylized = StyleTransferEngine.stylize(image, style: .pencil, maxDimension: 720),
              let stylizedCG = stylized.cgImage else { return nil }
        return scaledToExtent(CIImage(cgImage: stylizedCG), extent: extent)
    }

    nonisolated private static func coherentStylizedLayer(
        tiled: UIImage?, global: UIImage?, extent: CGRect, detailAmount: Double
    ) -> CIImage? {
        let tiledImage = tiled?.cgImage.flatMap { scaledToExtent(CIImage(cgImage: $0), extent: extent) }
        let globalImage = global?.cgImage.flatMap { scaledToExtent(CIImage(cgImage: $0), extent: extent) }
        guard let tiledImage else { return globalImage }
        guard let globalImage else { return tiledImage }
        return blend(input: tiledImage, background: globalImage,
                     amount: detailAmount, extent: extent)
    }

    nonisolated private static func scaledToExtent(_ image: CIImage, extent: CGRect) -> CIImage? {
        guard image.extent.width > 0, image.extent.height > 0 else { return nil }
        let translated = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.minX, y: -image.extent.minY
        ))
        return translated.transformed(by: CGAffineTransform(
            scaleX: extent.width / image.extent.width,
            y: extent.height / image.extent.height
        )).transformed(by: CGAffineTransform(
            translationX: extent.minX, y: extent.minY
        )).cropped(to: extent)
    }

    nonisolated private static func blend(
        input: CIImage, background: CIImage, amount: Double, extent: CGRect
    ) -> CIImage {
        blendWithMask(input: input, background: background,
                      mask: constantMask(amount, extent: extent)).cropped(to: extent)
    }

    nonisolated private static func constantMask(_ value: Double, extent: CGRect) -> CIImage {
        let value = min(max(value, 0), 1)
        return CIImage(color: CIColor(red: value, green: value, blue: value, alpha: 1))
            .cropped(to: extent)
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
        filter.setValue(max(radius, 0), forKey: kCIInputRadiusKey)
        return filter.outputImage
    }

    nonisolated private static func colorDodgeBlend(top: CIImage, bottom: CIImage) -> CIImage? {
        blendFilter("CIColorDodgeBlendMode", top: top, bottom: bottom)
    }

    nonisolated private static func multiplyBlend(top: CIImage, bottom: CIImage) -> CIImage? {
        blendFilter("CIMultiplyBlendMode", top: top, bottom: bottom)
    }

    nonisolated private static func maximum(top: CIImage, bottom: CIImage) -> CIImage? {
        blendFilter("CIMaximumCompositing", top: top, bottom: bottom)
    }

    nonisolated private static func blendFilter(
        _ name: String, top: CIImage, bottom: CIImage
    ) -> CIImage? {
        guard let filter = CIFilter(name: name) else { return nil }
        filter.setValue(top, forKey: kCIInputImageKey)
        filter.setValue(bottom, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage
    }

    nonisolated private static func blendWithMask(
        input: CIImage, background: CIImage, mask: CIImage
    ) -> CIImage {
        guard let filter = CIFilter(name: "CIBlendWithMask") else { return background }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(background, forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)
        return filter.outputImage ?? background
    }

    nonisolated private static func colorControls(
        _ input: CIImage, brightness: Double, contrast: Double, saturation: Double
    ) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        return filter.outputImage
    }

    nonisolated private static func edges(_ input: CIImage, intensity: Double) -> CIImage? {
        guard let filter = CIFilter(name: "CIEdges") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        return filter.outputImage
    }

    nonisolated private static func bloom(
        _ input: CIImage, radius: Double, intensity: Double
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

    nonisolated private static func noiseReduction(
        _ input: CIImage, level: Double, sharpness: Double
    ) -> CIImage? {
        guard let filter = CIFilter(name: "CINoiseReduction") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(level, forKey: "inputNoiseLevel")
        filter.setValue(sharpness, forKey: "inputSharpness")
        return filter.outputImage
    }

    nonisolated private static func colorPosterize(_ input: CIImage, levels: Double) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorPosterize") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(max(levels, 2), forKey: "inputLevels")
        return filter.outputImage
    }

    nonisolated private static func displacement(
        input: CIImage, map: CIImage, scale: Double
    ) -> CIImage? {
        guard let filter = CIFilter(name: "CIDisplacementDistortion") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(map, forKey: "inputDisplacementImage")
        filter.setValue(scale, forKey: kCIInputScaleKey)
        return filter.outputImage
    }

    nonisolated private static func normalizedImage(_ image: UIImage) -> UIImage? {
        if image.imageOrientation == .up, image.scale == 1, image.cgImage != nil { return image }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    nonisolated private static func resizedImage(
        _ image: UIImage, maxDimension: CGFloat
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let longEdge = max(width, height)
        guard longEdge > 0 else { return nil }
        let scale = min(1, maxDimension / longEdge)
        if scale >= 0.999 { return image }
        let targetSize = CGSize(width: max(1, (width * scale).rounded()),
                                height: max(1, (height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private extension Double {
    nonisolated var clamped: Double { min(max(self, 0), 1) }
}

struct SketchCanvas: View {
    let sourceImage: UIImage?
    let sketchImage: UIImage?
    let palette: [RGBColor]
    let palettePercentages: [Double]
    let metadata: PhotoMetadata
    let parameters: SketchParameters
    let imageScale: CGFloat
    let imageOffset: CGSize
    let isExporting: Bool

    var body: some View {
        GeometryReader { proxy in
            switch parameters.presentation {
            case .artwork:
                artwork(size: proxy.size)
            case .studySheet:
                studySheet(size: proxy.size)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(parameters.presentation == .studySheet
            ? "一照两境画笺"
            : "影像入画作品")
    }

    @ViewBuilder
    private func artwork(size: CGSize) -> some View {
        ZStack {
            SketchPaperSurface(paper: parameters.paper)
            if let displayed = sketchImage ?? sourceImage {
                Image(uiImage: displayed)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width * 0.92, height: size.height * 0.92)
                    .scaleEffect(imageScale)
                    .offset(imageOffset)
                    .clipped()
                    .mask {
                        DirectionalBrushMask(
                            brush: parameters.brush,
                            roughness: parameters.stroke,
                            feather: parameters.wetness,
                            dryAmount: parameters.blankness
                        )
                    }
            } else {
                Image(systemName: "paintbrush.pointed")
                    .font(.largeTitle)
                    .foregroundStyle(.black.opacity(0.34))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func studySheet(size: CGSize) -> some View {
        let image = sourceImage
        let sourceAspect = image.map { max($0.size.width / max($0.size.height, 1), 0.2) } ?? 1
        let isPortrait = sourceAspect < 0.82
        let usesVerticalCanvas = isPortrait && parameters.brush == .vertical
        let paintingRect = usesVerticalCanvas
            ? CGRect(x: size.width * 0.18, y: size.height * 0.045,
                     width: size.width * 0.64, height: size.height * 0.59)
            : CGRect(x: size.width * 0.055, y: size.height * 0.055,
                     width: size.width * 0.89, height: size.height * 0.51)
        let footerTop = size.height * (usesVerticalCanvas ? 0.665 : 0.615)
        let sourceRect = CGRect(
            x: size.width * 0.065,
            y: footerTop + size.height * 0.048,
            width: size.width * 0.285,
            height: size.height * 0.205
        )
        let informationRect = CGRect(
            x: size.width * 0.405,
            y: footerTop,
            width: size.width * 0.53,
            height: size.height * 0.275
        )

        ZStack(alignment: .topLeading) {
            SketchPaperSurface(paper: parameters.paper)

            if let displayed = sketchImage ?? sourceImage {
                Image(uiImage: displayed)
                    .resizable()
                    .scaledToFill()
                    .frame(width: paintingRect.width, height: paintingRect.height)
                    .scaleEffect(imageScale)
                    .offset(imageOffset)
                    .clipped()
                    .mask {
                        DirectionalBrushMask(
                            brush: parameters.brush,
                            roughness: parameters.stroke,
                            feather: parameters.wetness,
                            dryAmount: parameters.blankness
                        )
                    }
                    .frame(width: paintingRect.width, height: paintingRect.height)
                    .position(x: paintingRect.midX, y: paintingRect.midY)
            }

            if let image {
                VStack(alignment: .leading, spacing: max(3, size.width * 0.008)) {
                    Text(verbatim: studyCopy(
                        simplified: "原 片",
                        traditional: "原 片",
                        english: "ORIGINAL"
                    ))
                        .font(Font(studyFont.uiFont(size: max(7, size.width * 0.020))))
                        .tracking(size.width * 0.002)
                        .foregroundStyle(.black.opacity(0.46))
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: sourceRect.width, height: sourceRect.height, alignment: .topLeading)
                }
                .frame(width: sourceRect.width, height: sourceRect.height, alignment: .topLeading)
                .position(x: sourceRect.midX, y: sourceRect.midY)
            }

            studyInformation(size: size)
                .frame(width: informationRect.width, height: informationRect.height,
                       alignment: .topLeading)
                .position(x: informationRect.midX, y: informationRect.midY)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func studyInformation(size: CGSize) -> some View {
        let base = max(min(size.width, size.height), 1)
        let source = palette.isEmpty ? RGBColor.fallback : palette
        let active = source.enumerated().filter {
            parameters.activePigmentIndexes.contains($0.offset)
        }
        return VStack(alignment: .leading, spacing: base * 0.022) {
            VStack(alignment: .leading, spacing: base * 0.004) {
                Text(verbatim: studyTitle)
                    .font(Font(studyFont.uiFont(size: base * 0.052)))
                    .tracking(base * 0.004)
                Text(verbatim: artworkSubtitle)
                    .font(Font(studyFont.uiFont(size: base * 0.021)))
                    .tracking(base * 0.004)
                    .foregroundStyle(.black.opacity(0.54))
            }

            HStack(alignment: .top, spacing: base * 0.055) {
                metadataColumn(title: studyCopy(
                                   simplified: "地 点",
                                   traditional: "地 點",
                                   english: "LOCATION"
                               ),
                               value: studyLocation,
                               base: base)
                metadataColumn(title: studyCopy(
                                   simplified: "日 期",
                                   traditional: "日 期",
                                   english: "DATE"
                               ),
                               value: dateText, base: base)
            }

            HStack(spacing: base * 0.009) {
                ForEach(Array(active.prefix(5)), id: \.offset) { index, color in
                    WatercolorDeckleShape(seed: index * 37 + Int(color.red * 255))
                        .fill(color.color.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: base * 0.040)
                }
            }

            Text(verbatim: artworkFooter)
                .font(Font(studyFont.uiFont(size: base * 0.017)))
                .tracking(base * 0.003)
                .foregroundStyle(.black.opacity(0.42))
        }
        .foregroundStyle(.black.opacity(0.78))
    }

    private func metadataColumn(title: String, value: String, base: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: base * 0.005) {
            Text(verbatim: title)
                .font(Font(studyFont.uiFont(size: base * 0.016)))
                .tracking(base * 0.003)
                .foregroundStyle(.black.opacity(0.44))
            Text(verbatim: value)
                .font(Font(studyFont.uiFont(size: base * 0.020)))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateText: String {
        guard let date = metadata.captureDate else { return "---- / -- / --" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy / MM / dd"
        return formatter.string(from: date)
    }

    private var studyFont: PostalFont {
        PostalFont(rawValue: parameters.typographyRaw) ?? .brush
    }

    private var studyTitle: String {
        let title = parameters.customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return studyCopy(
            simplified: "一 照 两 境",
            traditional: "一 照 兩 境",
            english: "PHOTO · PAINTING"
        )
    }

    private var studyLocation: String {
        let location = parameters.customLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty { return location }
        return metadata.placeName?.isEmpty == false ? metadata.displayTitle : "────"
    }

    private var usesSimplifiedChinese: Bool {
        preferredLanguageIdentifier.hasPrefix("zh-hans")
    }

    private var usesTraditionalChinese: Bool {
        preferredLanguageIdentifier.hasPrefix("zh-hant")
            || preferredLanguageIdentifier.hasPrefix("zh-tw")
            || preferredLanguageIdentifier.hasPrefix("zh-hk")
            || preferredLanguageIdentifier.hasPrefix("zh-mo")
    }

    private var preferredLanguageIdentifier: String {
        (Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "en").lowercased()
    }

    private func studyCopy(
        simplified: String,
        traditional: String,
        english: String
    ) -> String {
        if usesSimplifiedChinese { return simplified }
        if usesTraditionalChinese { return traditional }
        return english
    }

    private var artworkSubtitle: String {
        if usesSimplifiedChinese {
            return switch parameters.style {
            case .pencil: "铅 笔 画 意"
            case .charcoal: "炭 笔 画 意"
            case .watercolor: "水 色 画 意"
            case .ink: "墨 意 留 痕"
            }
        }
        if usesTraditionalChinese {
            return switch parameters.style {
            case .pencil: "鉛 筆 畫 意"
            case .charcoal: "炭 筆 畫 意"
            case .watercolor: "水 色 畫 意"
            case .ink: "墨 意 留 痕"
            }
        }
        return parameters.style.artworkTitle
    }

    private var artworkFooter: String {
        if usesSimplifiedChinese {
            return parameters.style == .ink ? "墨 意 留 痕" : "影 像 入 画 · 由 光 入 画"
        }
        if usesTraditionalChinese {
            return parameters.style == .ink ? "墨 意 留 痕" : "影 像 入 畫 · 由 光 入 畫"
        }
        return parameters.style == .ink ? "INK MEMORY" : "PAINTED FROM LIGHT"
    }
}

private struct SketchPaperSurface: View {
    let paper: SketchPaper

    var body: some View {
        Color(uiColor: paper.uiColor)
            .overlay {
                Canvas { context, size in
                    let count = paper == .rough ? 150 : 90
                    for index in 0..<count {
                        let x = deterministic(index * 17 + 3) * size.width
                        let y = deterministic(index * 29 + 11) * size.height
                        let length = (paper == .xuan ? 10 : 4) + deterministic(index * 13) * 18
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(
                            x: min(size.width, x + length),
                            y: y + (deterministic(index * 7) - 0.5) * 2
                        ))
                        context.stroke(
                            path,
                            with: .color(.black.opacity(paper == .rough ? 0.026 : 0.016)),
                            lineWidth: paper == .rough ? 0.75 : 0.45
                        )
                    }
                }
                .blendMode(.multiply)
            }
    }

    private func deterministic(_ value: Int) -> CGFloat {
        var state = UInt64(bitPattern: Int64(value &+ 0x9E37))
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        state = state &* 2_685_821_657_736_338_717
        return CGFloat(state % 10_000) / 10_000
    }
}

private struct DirectionalBrushMask: View {
    let brush: SketchBrush
    let roughness: Double
    let feather: Double
    let dryAmount: Double

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { context, size in
            let angle = brush.angle
            let direction = CGVector(dx: cos(angle), dy: sin(angle))
            let normal = CGVector(dx: -direction.dy, dy: direction.dx)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let dryness = min(max(dryAmount, 0), 1)
            let rough = min(max(roughness, 0), 1)
            let halfLength = alongExtent(size: size, vector: direction) * 0.89
            let halfBreadth = alongExtent(size: size, vector: normal) * (brush == .dry ? 0.68 : 0.77)
            let sampleCount = 96
            let washLayers = 14

            for layer in 0..<washLayers {
                let progress = CGFloat(layer) / CGFloat(washLayers - 1)
                let alongScale = 1 - progress * 0.105
                let crossScale = 1 - progress * 0.165
                var wash = Path()
                for index in 0...sampleCount {
                    let theta = CGFloat(index) / CGFloat(sampleCount) * .pi * 2
                    let location = outlinePoint(theta: theta, layer: layer,
                                                center: center, direction: direction, normal: normal,
                                                halfLength: halfLength * alongScale,
                                                halfBreadth: halfBreadth * crossScale,
                                                roughness: rough)
                    if index == 0 { wash.move(to: location) } else { wash.addLine(to: location) }
                }
                wash.closeSubpath()
                context.fill(wash, with: .color(.white.opacity(0.055 + Double(progress) * 0.070)))
            }

            var heart = Path()
            for index in 0...sampleCount {
                let theta = CGFloat(index) / CGFloat(sampleCount) * .pi * 2
                let location = outlinePoint(theta: theta, layer: washLayers + 2,
                                            center: center, direction: direction, normal: normal,
                                            halfLength: halfLength * 0.875,
                                            halfBreadth: halfBreadth * 0.79,
                                            roughness: rough)
                if index == 0 { heart.move(to: location) } else { heart.addLine(to: location) }
            }
            heart.closeSubpath()
            context.fill(heart, with: .color(.white.opacity(0.72)))

            for index in 0..<28 {
                let theta = CGFloat(index) / 28 * .pi * 2 + 0.11
                let anchor = outlinePoint(theta: theta, layer: index % 7,
                                          center: center, direction: direction, normal: normal,
                                          halfLength: halfLength * 0.99,
                                          halfBreadth: halfBreadth * 0.99,
                                          roughness: rough)
                let radius = max(3.5, halfBreadth * (0.035 + CGFloat(index % 6) * 0.011))
                let rect = CGRect(x: anchor.x - radius,
                                  y: anchor.y - radius * (0.72 + CGFloat(index % 3) * 0.10),
                                  width: radius * 2,
                                  height: radius * (1.44 + CGFloat(index % 3) * 0.20))
                context.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(0.075 + Double(index % 5) * 0.026)))
            }

            for index in 0..<20 {
                let progress = CGFloat(index) / 19
                let crossSign: CGFloat = index.isMultiple(of: 2) ? -1 : 1
                let cross = crossSign * halfBreadth * (0.76 + CGFloat(index % 4) * 0.075)
                let centerDistance = halfLength * (-0.72 + progress * 1.44)
                let strokeHalf = halfLength * (0.055 + CGFloat(index % 5) * 0.012)
                let start = point(center: center, along: direction, normal: normal,
                                  distance: centerDistance - strokeHalf, cross: cross)
                let end = point(center: center, along: direction, normal: normal,
                                distance: centerDistance + strokeHalf, cross: cross)
                var waterline = Path()
                waterline.move(to: start)
                waterline.addQuadCurve(to: end, control: point(
                    center: center, along: direction, normal: normal,
                    distance: centerDistance,
                    cross: cross + crossSign * halfBreadth * 0.018 * sin(CGFloat(index + 1))
                ))
                context.stroke(waterline,
                               with: .color(.white.opacity(0.10 + Double(index % 4) * 0.035)),
                               style: StrokeStyle(lineWidth: max(2.2, halfBreadth * (0.020 + CGFloat(index % 3) * 0.010)),
                                                  lineCap: .round,
                                                  lineJoin: .round))
            }

            if brush == .dry {
                context.blendMode = .destinationOut
                let gapCount = 3 + Int((dryness * 2).rounded())
                for index in 0..<gapCount {
                    let t = -0.48 + CGFloat(index) * 0.25
                    let cross = halfBreadth * (-0.38 + CGFloat(index % 3) * 0.34)
                    let start = point(center: center, along: direction, normal: normal,
                                      distance: halfLength * t, cross: cross)
                    let end = point(center: center, along: direction, normal: normal,
                                    distance: halfLength * (t + 0.22 + CGFloat(index % 2) * 0.08),
                                    cross: cross + halfBreadth * 0.035)
                    var gap = Path()
                    gap.move(to: start)
                    gap.addQuadCurve(to: end, control: point(
                        center: center, along: direction, normal: normal,
                        distance: halfLength * (t + 0.12), cross: cross - halfBreadth * 0.025
                    ))
                    context.stroke(gap, with: .color(.white.opacity(0.58 + dryness * 0.28)),
                                   style: StrokeStyle(lineWidth: max(2, halfBreadth * 0.026), lineCap: .round))
                }
            }
        }
        .padding(minimumPadding)
        .blur(radius: blurRadius)
        .compositingGroup()
    }

    private var minimumPadding: CGFloat {
        brush == .vertical ? 5 : 3
    }

    private var blurRadius: CGFloat {
        0.35 + CGFloat(min(max(feather, 0), 1)) * 2.1
    }

    private func alongExtent(size: CGSize, vector: CGVector) -> CGFloat {
        let xLimit = abs(vector.dx) > 0.001 ? size.width / (2 * abs(vector.dx)) : .greatestFiniteMagnitude
        let yLimit = abs(vector.dy) > 0.001 ? size.height / (2 * abs(vector.dy)) : .greatestFiniteMagnitude
        return min(xLimit, yLimit)
    }

    private func outlinePoint(
        theta: CGFloat,
        layer: Int,
        center: CGPoint,
        direction: CGVector,
        normal: CGVector,
        halfLength: CGFloat,
        halfBreadth: CGFloat,
        roughness: CGFloat
    ) -> CGPoint {
        let cosine = cos(theta)
        let sine = sin(theta)
        let exponent: CGFloat
        switch brush {
        case .horizontal: exponent = 0.98
        case .rising, .falling: exponent = 0.94
        case .vertical: exponent = 0.92
        case .arc: exponent = 1.02
        case .dry: exponent = 0.86
        }
        let u = (cosine < 0 ? -1.0 : 1.0) * pow(abs(cosine), exponent)
        let v = (sine < 0 ? -1.0 : 1.0) * pow(abs(sine), exponent)
        let waveStrength = 0.72 + roughness * 0.68
        let phase = CGFloat(layer) * 0.29
        let alongWave = (sin(theta * 3 + 0.45 + phase) * 0.038
                         + sin(theta * 7 - 0.30 - phase * 0.7) * 0.017) * waveStrength
        let crossWave = (sin(theta * 4 - 0.55 - phase) * 0.078
                         + sin(theta * 9 + 0.80 + phase * 0.5) * 0.028) * waveStrength
        let distance = halfLength * u * (1 + alongWave)
        let arcLift = brush == .arc ? -halfBreadth * 0.18 * (1 - u * u) : 0
        let asymmetricLift: CGFloat
        switch brush {
        case .horizontal: asymmetricLift = halfBreadth * 0.025 * sin(u * .pi)
        case .rising: asymmetricLift = halfBreadth * 0.032 * sin((u + 0.2) * .pi)
        case .falling: asymmetricLift = -halfBreadth * 0.032 * sin((u + 0.2) * .pi)
        case .vertical: asymmetricLift = halfBreadth * 0.024 * sin((u - 0.15) * .pi * 1.4)
        case .arc: asymmetricLift = 0
        case .dry: asymmetricLift = halfBreadth * 0.042 * sin((u + 0.1) * .pi * 1.6)
        }
        return point(center: center, along: direction, normal: normal,
                     distance: distance,
                     cross: arcLift + asymmetricLift + halfBreadth * v * (1 + crossWave))
    }

    private func point(
        center: CGPoint,
        along: CGVector,
        normal: CGVector,
        distance: CGFloat,
        cross: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: center.x + along.dx * distance + normal.dx * cross,
            y: center.y + along.dy * distance + normal.dy * cross
        )
    }

}

private struct WatercolorDeckleShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        let inset = min(rect.width, rect.height) * 0.018
        let drawingRect = rect.insetBy(dx: inset, dy: inset)
        let segments = 34
        let amplitude = min(rect.width, rect.height) * 0.018
        var path = Path()
        path.move(to: point(edge: 0, step: 0, segments: segments,
                            rect: drawingRect, amplitude: amplitude))
        for edge in 0..<4 {
            for step in 1...segments {
                path.addLine(to: point(edge: edge, step: step, segments: segments,
                                       rect: drawingRect, amplitude: amplitude))
            }
        }
        path.closeSubpath()
        return path
    }

    private func point(
        edge: Int,
        step: Int,
        segments: Int,
        rect: CGRect,
        amplitude: CGFloat
    ) -> CGPoint {
        let progress = CGFloat(step) / CGFloat(segments)
        let jitter = (noise(edge * 101 + step * 17 + seed) - 0.5) * amplitude * 2
        switch edge {
        case 0: return CGPoint(x: rect.minX + rect.width * progress, y: rect.minY + jitter)
        case 1: return CGPoint(x: rect.maxX + jitter, y: rect.minY + rect.height * progress)
        case 2: return CGPoint(x: rect.maxX - rect.width * progress, y: rect.maxY + jitter)
        default: return CGPoint(x: rect.minX + jitter, y: rect.maxY - rect.height * progress)
        }
    }

    private func noise(_ value: Int) -> CGFloat {
        var state = UInt64(bitPattern: Int64(value &+ 0x632B))
        state ^= state >> 15
        state = state &* 2_246_822_519
        state ^= state >> 13
        return CGFloat(state % 10_000) / 10_000
    }
}

struct SketchEditorControls: View {
    @Binding var parameters: SketchParameters
    let palette: [RGBColor]
    let palettePercentages: [Double]
    let isRendering: Bool
    let isSupporter: Bool
    let locationPlaceholder: String
    @Binding var isCropEditing: Bool
    let onLockedFontTap: () -> Void
    let onResetCrop: () -> Void
    let onStyleChange: (SketchStyle) -> Void

    @State private var typographyExpanded = false
    @State private var activePanel: ControlPanel = .composition

    private enum ControlPanel: String, CaseIterable, Identifiable {
        case composition = "构图"
        case brush = "笔触"
        case sheet = "画笺"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .composition: "rectangle.on.rectangle"
            case .brush: "paintbrush.pointed"
            case .sheet: "text.document"
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            panelSwitcher
            activePanelContent
        }
        .animation(.easeInOut(duration: 0.18), value: isRendering)
        .animation(.snappy(duration: 0.22), value: activePanel)
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: typographyExpanded)
        .onChange(of: isSupporter) { _, unlocked in
            if !unlocked {
                typographyExpanded = false
                parameters.typographyRaw = PostalFont.original.rawValue
            }
        }
    }

    @ViewBuilder
    private var activePanelContent: some View {
        switch activePanel {
        case .composition:
            compositionPanel
        case .brush:
            brushPanel
        case .sheet:
            sheetPanel
        }
    }

    private var selectedPostalFont: PostalFont {
        guard isSupporter else { return .original }
        return PostalFont(rawValue: parameters.typographyRaw) ?? .original
    }

    private var panelSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(ControlPanel.allCases) { panel in
                Button {
                    activePanel = panel
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(LocalizedStringKey(panel.rawValue), systemImage: panel.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(activePanel == panel ? .white : .primary.opacity(0.62))
                        .background(
                            activePanel == panel ? Color.black.opacity(0.78) : .clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activePanel == panel ? .isSelected : [])
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            Button {
                resetCurrentStyle()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.primary.opacity(0.68))
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("恢复当前画法")
        }
        .padding(4)
        .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
    }

    private var compositionPanel: some View {
        panelCard {
            panelHeading("成片构图", symbol: "rectangle.on.rectangle", detail: "版式、画法与取景")
            presentationPicker
            panelDivider
            stylePicker
            panelDivider
            cropEditor
        }
    }

    private var brushPanel: some View {
        panelCard {
            brushPicker
            panelDivider
            VStack(spacing: 0) {
                sliderRow(
                    label: "笔锋",
                    value: $parameters.stroke,
                    symbol: "scribble.variable",
                    legend: parameters.stroke < 0.34 ? "收敛" : parameters.stroke < 0.68 ? "自然" : "奔放"
                )
                sliderDivider
                sliderRow(
                    label: "晕染",
                    value: $parameters.wetness,
                    symbol: "drop.fill",
                    legend: parameters.wetness < 0.34 ? "清脆" : parameters.wetness < 0.68 ? "柔边" : "湿边"
                )
                sliderDivider
                sliderRow(
                    label: "飞白",
                    value: $parameters.blankness,
                    symbol: "circle.dotted",
                    legend: parameters.blankness < 0.34 ? "少" : parameters.blankness < 0.68 ? "适中" : "多"
                )
                if parameters.style == .pencil || parameters.style == .charcoal || parameters.style == .ink {
                    sliderDivider
                    sliderRow(
                        label: "画意",
                        value: $parameters.intensity,
                        symbol: "wand.and.stars",
                        legend: parameters.intensity < 0.34 ? "轻" : parameters.intensity < 0.68 ? "适中" : "深"
                    )
                }
            }
        }
    }

    private var sheetPanel: some View {
        panelCard {
            panelHeading("画笺纸面", symbol: "doc.richtext", detail: "纸感与题签")
            paperPicker

            if parameters.presentation == .studySheet {
                panelDivider
                VStack(spacing: 0) {
                    titleEditor
                    sliderDivider
                    locationEditor
                }
                panelDivider
                typographyEntry
                if isSupporter && typographyExpanded {
                    panelDivider
                    typographyPicker
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                panelDivider
                Label("切换到“一照两境”后可编辑标题、地点与字体", systemImage: "info.circle")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }

    private func panelCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(12)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), variant: .clear)
    }

    private func panelHeading(_ title: String, symbol: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(LocalizedStringKey(detail))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var panelDivider: some View {
        Divider().opacity(0.55)
    }

    private var sliderDivider: some View {
        Divider().padding(.leading, 28).opacity(0.45)
    }

    private func resetCurrentStyle() {
        let currentBrush = parameters.brush
        let currentTypography = parameters.typographyRaw
        let currentTitle = parameters.customTitle
        let currentLocation = parameters.customLocation
        parameters = parameters.style.defaultParameters
        parameters.brush = currentBrush
        parameters.typographyRaw = currentTypography
        parameters.customTitle = currentTitle
        parameters.customLocation = currentLocation
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private var typographyEntry: some View {
        Button {
            if isSupporter {
                typographyExpanded.toggle()
                UISelectionFeedbackGenerator().selectionChanged()
            } else {
                onLockedFontTap()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "textformat")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text("自定义字体")
                        .font(.system(size: 13, weight: .semibold))
                    Text(verbatim: isSupporter
                        ? selectedPostalFont.title
                        : "一照两境画笺专属字体".appLocalized)
                        .font(isSupporter
                              ? Font(selectedPostalFont.uiFont(size: 12))
                              : .system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSupporter {
                    Image(systemName: typographyExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                } else {
                    ProBadge(compact: true)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary.opacity(0.82))
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .accessibilityLabel("自定义画笺字体")
        .accessibilityValue(isSupporter ? selectedPostalFont.title : "PRO 专属功能".appLocalized)
    }

    private var cropEditor: some View {
        HStack(spacing: 8) {
            Button {
                isCropEditing.toggle()
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isCropEditing ? "checkmark" : "crop")
                        .font(.system(size: 14, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCropEditing ? "完成取景" : "调整取景")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isCropEditing ? "在上方拖动照片，双指缩放" : "默认使用自动裁切")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .foregroundStyle(.primary.opacity(0.82))
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(LiquidPressButtonStyle())

            if isCropEditing {
                Button {
                    onResetCrop()
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary.opacity(0.82))
                .background(Color.primary.opacity(0.07), in: Circle())
                .accessibilityLabel("复位取景")
            }
        }
    }

    private var titleEditor: some View {
        HStack(spacing: 11) {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text("标题")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            TextField("一照两境", text: Binding(
                get: { parameters.customTitle },
                set: { parameters.customTitle = String($0.prefix(12)) }
            ))
            .font(.system(size: 13, weight: .semibold))
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
            if !parameters.customTitle.isEmpty {
                Button {
                    parameters.customTitle = ""
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空画笺标题")
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 40)
        .accessibilityElement(children: .contain)
    }

    private var locationEditor: some View {
        HStack(spacing: 11) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text("地点")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            TextField(locationPlaceholder, text: Binding(
                get: { parameters.customLocation },
                set: { parameters.customLocation = String($0.prefix(20)) }
            ))
            .font(.system(size: 13, weight: .semibold))
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            if !parameters.customLocation.isEmpty {
                Button {
                    parameters.customLocation = ""
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("恢复照片地点")
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 40)
        .accessibilityElement(children: .contain)
    }

    private var typographyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("画笺字体", systemImage: "textformat")
                .font(.caption.weight(.semibold))
            HStack(spacing: 0) {
                ForEach(PostalFont.allCases) { font in
                    Button {
                        parameters.typographyRaw = font.rawValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 7) {
                            Text(verbatim: font.compactPickerTitle)
                                .font(Font(font.uiFont(size: 13)))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Circle()
                                .fill(selectedPostalFont == font
                                    ? Color.primary : Color.secondary.opacity(0.18))
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: font.title))
                    .accessibilityValue(selectedPostalFont == font ? "已选择" : "未选择")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var brushPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("笔刷外形", systemImage: "paintbrush.pointed")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("原片裁入笔触")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(SketchBrush.allCases) { brush in
                        Button {
                            parameters.brush = brush
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(LocalizedStringKey(brush.rawValue), systemImage: brush.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(parameters.brush == brush
                                    ? Color.white : Color.primary.opacity(0.68))
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .background(parameters.brush == brush
                                    ? Color.black.opacity(0.78) : Color.clear,
                                    in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var stylePicker: some View {
        HStack(spacing: 7) {
            ForEach(SketchStyle.allCases) { style in
                Button {
                    let currentBrush = parameters.brush
                    let currentTypography = parameters.typographyRaw
                    let currentTitle = parameters.customTitle
                    let currentLocation = parameters.customLocation
                    onStyleChange(style)
                    parameters.brush = currentBrush
                    parameters.typographyRaw = currentTypography
                    parameters.customTitle = currentTitle
                    parameters.customLocation = currentLocation
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(LocalizedStringKey(style.rawValue), systemImage: style.symbol)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(parameters.style == style ? .white : .primary.opacity(0.68))
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                        .background(
                            parameters.style == style ? Color.black.opacity(0.78) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(parameters.style == style ? .isSelected : [])
            }
            Spacer(minLength: 2)
            if isRendering {
                ProgressView().controlSize(.small).padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 0)
        .frame(minHeight: 42)
    }

    private var presentationPicker: some View {
        HStack(spacing: 8) {
            ForEach(SketchPresentation.allCases) { presentation in
                Button {
                    parameters.presentation = presentation
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(LocalizedStringKey(presentation.rawValue), systemImage: presentation.symbol)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(parameters.presentation == presentation ? .white : .primary.opacity(0.68))
                        .background(
                            parameters.presentation == presentation ? Color.black.opacity(0.78) : .clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private var pigmentPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("琉璃颜料", systemImage: "swatchpalette")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("轻点决定入画颜色")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(Array((palette.isEmpty ? RGBColor.fallback : palette).prefix(6).enumerated()), id: \.offset) { index, color in
                    let selected = parameters.activePigmentIndexes.contains(index)
                    Button {
                        togglePigment(index)
                    } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(color.color)
                                .frame(height: 32)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selected ? Color.primary.opacity(0.78) : .clear, lineWidth: 2)
                                }
                                .overlay {
                                    if !selected {
                                        Image(systemName: "slash.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.58))
                                    }
                                }
                            Text(color.literaryName)
                                .font(.system(size: 8.5, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(
                        "\(color.literaryName)\((selected ? "已入画" : "未入画").appLocalized)"
                    )
                    .accessibilityValue(index < palettePercentages.count
                        ? String(format: "%.1f%%", palettePercentages[index])
                        : "")
                }
            }
        }
        .padding(12)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), variant: .clear)
    }

    private var paperPicker: some View {
        HStack(spacing: 8) {
            ForEach(SketchPaper.allCases) { paper in
                Button {
                    parameters.paper = paper
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(LocalizedStringKey(paper.rawValue), systemImage: paper.symbol)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(parameters.paper == paper ? .white : .primary.opacity(0.68))
                        .background(
                            parameters.paper == paper ? Color.black.opacity(0.78) : .clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
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
                .frame(width: 34, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(.primary)
                .frame(minWidth: 68)
            Text(LocalizedStringKey(legend))
                .font(.caption2.bold())
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 2)
        .frame(height: 39)
    }

    private func togglePigment(_ index: Int) {
        var updated = parameters.activePigmentIndexes
        if updated.contains(index) {
            guard updated.count > 1 else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            updated.remove(index)
        } else {
            updated.insert(index)
        }
        parameters.activePigmentIndexes = updated
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
