// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreImage
import CoreML
import OSLog
import UIKit
import Vision

nonisolated enum StyleTransferStyle: Sendable {
    case pencil
    case watercolor

    var resourceName: String {
        switch self {
        case .pencil: return "Sketch"
        case .watercolor: return "starry_night"
        }
    }

    var tileSize: CGSize {
        switch self {
        case .pencil: return CGSize(width: 512, height: 512)
        case .watercolor: return CGSize(width: 640, height: 960)
        }
    }
}

enum StyleTransferEngine {
    nonisolated(unsafe) private static var cachedModels: [StyleTransferStyle: MLModel] = [:]
    nonisolated(unsafe) private static var cachedVisionModels: [StyleTransferStyle: VNCoreMLModel] = [:]
    nonisolated private static let cacheLock = NSLock()
    nonisolated private static let logger = Logger(
        subsystem: "top.locallensapp.lingdongzhaopian",
        category: "StyleTransfer"
    )

    nonisolated private static func model(for style: StyleTransferStyle) -> MLModel? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cachedModels[style] {
            return cached
        }
        let loaded = loadModel(for: style)
        if let loaded {
            cachedModels[style] = loaded
        }
        return loaded
    }

    nonisolated private static func loadModel(for style: StyleTransferStyle) -> MLModel? {
        let bundle = Bundle.main
        let config = modelConfiguration()
        if let compiledURL = bundle.url(forResource: style.resourceName, withExtension: "mlmodelc") {
            do {
                return try MLModel(contentsOf: compiledURL, configuration: config)
            } catch {
                logger.error("加载模型 \(style.resourceName, privacy: .public) 失败：\(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        if let sourceURL = bundle.url(forResource: style.resourceName, withExtension: "mlmodel") {
            do {
                return try MLModel(contentsOf: sourceURL, configuration: config)
            } catch {
                logger.error("加载模型 \(style.resourceName, privacy: .public) 失败：\(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        logger.error("未找到模型资源 \(style.resourceName, privacy: .public)")
        return nil
    }

    nonisolated private static func visionModel(for style: StyleTransferStyle) -> VNCoreMLModel? {
        cacheLock.lock()
        if let cached = cachedVisionModels[style] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let coreModel = model(for: style) else { return nil }
        do {
            let created = try VNCoreMLModel(for: coreModel)
            cacheLock.lock()
            let resolved = cachedVisionModels[style] ?? created
            cachedVisionModels[style] = resolved
            cacheLock.unlock()
            return resolved
        } catch {
            logger.error("创建 Vision 模型 \(style.resourceName, privacy: .public) 失败：\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    nonisolated private static func modelConfiguration() -> MLModelConfiguration {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return config
    }

    nonisolated static func isAvailable(style: StyleTransferStyle) -> Bool {
        model(for: style) != nil
    }

    nonisolated static var isAvailable: Bool { isAvailable(style: .watercolor) }

    nonisolated static func stylize(
        _ image: UIImage,
        style: StyleTransferStyle,
        maxDimension: CGFloat = 720
    ) -> UIImage? {
        guard let vnModel = visionModel(for: style) else { return nil }
        guard let cgImage = image.cgImage, cgImage.width > 0, cgImage.height > 0 else { return nil }

        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill

        let orientation = cgImagePropertyOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        do {
            try handler.perform([request])
        } catch {
            logger.error("执行模型 \(style.resourceName, privacy: .public) 失败：\(error.localizedDescription, privacy: .public)")
            return nil
        }

        guard let observation = request.results?.first as? VNPixelBufferObservation else {
            logger.error("模型 \(style.resourceName, privacy: .public) 未返回图像结果")
            return nil
        }

        let stylizedCI = CIImage(cvPixelBuffer: observation.pixelBuffer)
        let context = CIContext(options: [.cacheIntermediates: false, .useSoftwareRenderer: false])
        guard let stylizedCG = context.createCGImage(stylizedCI, from: stylizedCI.extent) else {
            logger.error("模型 \(style.resourceName, privacy: .public) 的结果无法转换为图像")
            return nil
        }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return UIImage(cgImage: stylizedCG, scale: 1, orientation: .up)
        }

        let longEdge = max(sourceSize.width, sourceSize.height)
        let scale = min(1.0, maxDimension / longEdge)
        let targetSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { ctx in
            UIImage(cgImage: stylizedCG, scale: 1, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: targetSize))
            _ = ctx
        }
    }

    nonisolated static func stylizeTiled(
        _ image: UIImage,
        style: StyleTransferStyle
    ) -> UIImage? {
        guard let cgImage = image.cgImage, cgImage.width > 0, cgImage.height > 0 else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let nativeSize = style.tileSize
        let tileScale = min(
            1,
            min(CGFloat(width) / nativeSize.width, CGFloat(height) / nativeSize.height)
        )
        let tileWidth = max(1, Int((nativeSize.width * tileScale).rounded(.down)))
        let tileHeight = max(1, Int((nativeSize.height * tileScale).rounded(.down)))
        let overlapX = max(1, Int((CGFloat(tileWidth) * 0.40).rounded()))
        let overlapY = max(1, Int((CGFloat(tileHeight) * 0.40).rounded()))
        let xOrigins = tileOrigins(length: width, tileLength: tileWidth, overlap: overlapX)
        let yOrigins = tileOrigins(length: height, tileLength: tileHeight, overlap: overlapY)
        let pixelCount = width * height
        var accumulated = [Float](repeating: 0, count: pixelCount * 3)
        var weights = [Float](repeating: 0, count: pixelCount)

        for (yIndex, originY) in yOrigins.enumerated() {
            for (xIndex, originX) in xOrigins.enumerated() {
                guard !Task.isCancelled else { return nil }
                let cropRect = CGRect(
                    x: originX,
                    y: originY,
                    width: tileWidth,
                    height: tileHeight
                )
                guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
                let tileImage = UIImage(cgImage: cropped, scale: 1, orientation: .up)
                guard let styled = autoreleasepool(invoking: {
                    stylize(
                        tileImage,
                        style: style,
                        maxDimension: max(CGFloat(tileWidth), CGFloat(tileHeight))
                    )
                }),
                let tilePixels = rgbaPixels(styled, width: tileWidth, height: tileHeight) else {
                    return nil
                }

                let xWeights = featherWeights(
                    length: tileWidth,
                    leadingOverlap: xIndex > 0
                        ? xOrigins[xIndex - 1] + tileWidth - originX
                        : 0,
                    trailingOverlap: xIndex + 1 < xOrigins.count
                        ? originX + tileWidth - xOrigins[xIndex + 1]
                        : 0
                )
                let yWeights = featherWeights(
                    length: tileHeight,
                    leadingOverlap: yIndex > 0
                        ? yOrigins[yIndex - 1] + tileHeight - originY
                        : 0,
                    trailingOverlap: yIndex + 1 < yOrigins.count
                        ? originY + tileHeight - yOrigins[yIndex + 1]
                        : 0
                )

                for localY in 0..<tileHeight {
                    let destinationY = originY + localY
                    let rowWeight = yWeights[localY]
                    for localX in 0..<tileWidth {
                        let destinationX = originX + localX
                        let weight = rowWeight * xWeights[localX]
                        let destinationIndex = destinationY * width + destinationX
                        let colorIndex = destinationIndex * 3
                        let tileIndex = (localY * tileWidth + localX) * 4
                        accumulated[colorIndex] += Float(tilePixels[tileIndex]) * weight
                        accumulated[colorIndex + 1] += Float(tilePixels[tileIndex + 1]) * weight
                        accumulated[colorIndex + 2] += Float(tilePixels[tileIndex + 2]) * weight
                        weights[destinationIndex] += weight
                    }
                }
            }
        }

        var output = [UInt8](repeating: 255, count: pixelCount * 4)
        for index in 0..<pixelCount {
            let weight = max(weights[index], 0.0001)
            let sourceIndex = index * 3
            let destinationIndex = index * 4
            output[destinationIndex] = UInt8(clamping: Int((accumulated[sourceIndex] / weight).rounded()))
            output[destinationIndex + 1] = UInt8(clamping: Int((accumulated[sourceIndex + 1] / weight).rounded()))
            output[destinationIndex + 2] = UInt8(clamping: Int((accumulated[sourceIndex + 2] / weight).rounded()))
        }
        return imageFromRGBA(output, width: width, height: height)
    }

    nonisolated static func stylize(_ image: UIImage, maxDimension: CGFloat = 720) -> UIImage? {
        stylize(image, style: .watercolor, maxDimension: maxDimension)
    }

    nonisolated private static func tileOrigins(
        length: Int,
        tileLength: Int,
        overlap: Int
    ) -> [Int] {
        guard tileLength < length else { return [0] }
        let step = max(1, tileLength - overlap)
        let tileCount = max(
            2,
            Int(ceil(Double(length - overlap) / Double(step)))
        )
        let availableDistance = length - tileLength
        return (0..<tileCount).map { index in
            Int(
                (Double(availableDistance) * Double(index) / Double(tileCount - 1))
                    .rounded()
            )
        }
    }

    nonisolated private static func featherWeights(
        length: Int,
        leadingOverlap: Int,
        trailingOverlap: Int
    ) -> [Float] {
        (0..<length).map { position in
            var value: Double = 1
            if leadingOverlap > 0, position < leadingOverlap {
                let progress = Double(position + 1) / Double(leadingOverlap + 1)
                value *= 0.5 - 0.5 * cos(.pi * progress)
            }
            if trailingOverlap > 0, position >= length - trailingOverlap {
                let progress = Double(length - position) / Double(trailingOverlap + 1)
                value *= 0.5 - 0.5 * cos(.pi * progress)
            }
            return Float(max(value, 0.0001))
        }
    }

    nonisolated private static func rgbaPixels(
        _ image: UIImage,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        guard let cgImage = image.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return false }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return rendered ? pixels : nil
    }

    nonisolated private static func imageFromRGBA(
        _ pixels: [UInt8],
        width: Int,
        height: Int
    ) -> UIImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    nonisolated private static func cgImagePropertyOrientation(
        from orientation: UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
