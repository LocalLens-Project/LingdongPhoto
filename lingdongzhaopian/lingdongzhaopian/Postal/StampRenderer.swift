import UIKit

enum StampFormat: String, CaseIterable, Codable, Identifiable {
    case square, tall, portrait, classic, landscape
    case equilateralTriangle, wideTriangle, narrowTriangle, fan, circle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .square: "1:1"
        case .tall: "1:2"
        case .portrait: "2:3"
        case .classic: "3:4"
        case .landscape: "4:3"
        case .equilateralTriangle: "等边三角形".appLocalized
        case .wideTriangle: "等腰三角形 · 长底".appLocalized
        case .narrowTriangle: "等腰三角形 · 短底".appLocalized
        case .fan: "扇形".appLocalized
        case .circle: "圆形".appLocalized
        }
    }
    var assetName: String {
        switch self {
        case .square: "stamp_1x1"
        case .tall: "stamp_1x2"
        case .portrait: "stamp_2x3"
        case .classic, .landscape: "stamp_3x4"
        case .equilateralTriangle: "stamp_dengbian"
        case .wideTriangle: "stamp_dengyaodichang"
        case .narrowTriangle: "stamp_dengyaodiduan"
        case .fan: "stamp_shanxing"
        case .circle: "stamp_yuanxing"
        }
    }
    var requiresPro: Bool { self != .classic }
    var isShaped: Bool { [.equilateralTriangle, .wideTriangle, .narrowTriangle, .fan, .circle].contains(self) }
}

struct StampTransform: Equatable {
    var scale: Double = 1

    var x: Double = 0
    var y: Double = 0
    var clamped: Self {
        Self(scale: min(4, max(1, scale)), x: min(1, max(-1, x)), y: min(1, max(-1, y)))
    }
}

struct ProcessedStampTemplate {
    let paper: UIImage
    let windowMask: UIImage
    let window: CGRect

    let contentRect: CGRect
    var size: CGSize { paper.size }
}

enum PostalError: LocalizedError {
    case template, image, missingLocation, unresolvedCity, cityNotCollected, conflictingCity, wrongCity(String), libraryDenied, damagedLibrary
    var errorDescription: String? {
        switch self {
        case .template: "邮票模板无法读取，请重新打开后重试。"
        case .image: "无法生成图片，请重新选择照片。"
        case .missingLocation: "这张照片没有定位信息，可以制作普通邮票，但不能加入城市邮集。"
        case .unresolvedCity: "暂时无法确定照片所在城市，请检查网络后重试。照片仍可制作普通邮票。"
        case .cityNotCollected: "该地区暂不提供独立城市解锁，也不会归入其他城市。照片仍可制作并收藏为普通邮票。".appLocalized
        case .conflictingCity: "定位返回的城市信息不一致，请重试识别。照片仍可制作普通邮票，暂不点亮城市。".appLocalized
        case .wrongCity(let city): "照片不属于「\(city)」，请选择同一城市拍摄的照片。"
        case .libraryDenied: "没有保存照片的权限。请在系统设置中允许灵动照片添加照片，再返回编辑页重试。"
        case .damagedLibrary: "邮集索引无法读取，已保留原文件。请先恢复备份，避免覆盖现有收藏。"
        }
    }
}


enum StampRenderer {
    private static var cache: [StampFormat: ProcessedStampTemplate] = [:]

    static func template(_ format: StampFormat) throws -> ProcessedStampTemplate {
        if let cached = cache[format] { return cached }
        guard let source = UIImage(named: format.assetName)?.cgImage else { throw PostalError.template }
        let processed = try process(source, rotate: format == .landscape,
                                    alphaCutoff: format.isShaped ? 24 : 12, fitContent: format.isShaped)
        cache[format] = processed
        return processed
    }

    static func process(_ source: CGImage, rotate: Bool = false, alphaCutoff: UInt8 = 12,
                        fitContent: Bool = false) throws -> ProcessedStampTemplate {
        let sw = source.width, sh = source.height
        var raw = try rgba(source)


        for i in stride(from: 0, to: raw.count, by: 4) where raw[i + 3] <= alphaCutoff {
            for c in 0..<4 { raw[i + c] = 0 }
        }
        var minX = sw, minY = sh, maxX = -1, maxY = -1
        for y in 0..<sh { for x in 0..<sw where raw[(y * sw + x) * 4 + 3] > 0 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        } }
        guard maxX > minX, maxY > minY else { throw PostalError.template }
        let cw = maxX - minX + 1, ch = maxY - minY + 1
        let w = rotate ? ch : cw, h = rotate ? cw : ch
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<ch { for x in 0..<cw {
            let from = ((y + minY) * sw + x + minX) * 4
            let to = rotate ? (x * w + (ch - 1 - y)) * 4 : (y * w + x) * 4
            for c in 0..<4 { pixels[to + c] = raw[from + c] }
        } }



        var visited = [Bool](repeating: false, count: w * h)
        var exterior = [Bool](repeating: false, count: w * h)
        var largest: [Int] = []
        for seed in 0..<(w * h) where !visited[seed] && pixels[seed * 4 + 3] <= 12 {
            var queue = [seed], cursor = 0, touchesEdge = false
            visited[seed] = true
            while cursor < queue.count {
                let i = queue[cursor]; cursor += 1
                let x = i % w, y = i / w
                if x == 0 || y == 0 || x == w - 1 || y == h - 1 { touchesEdge = true }
                for n in [x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1,
                          y > 0 ? i - w : -1, y < h - 1 ? i + w : -1] {
                    if n >= 0 && !visited[n] && pixels[n * 4 + 3] <= 12 {
                        visited[n] = true; queue.append(n)
                    }
                }
            }
            if touchesEdge {
                for i in queue { exterior[i] = true }
            } else if queue.count > largest.count { largest = queue }
        }
        guard largest.count > 100 else { throw PostalError.template }
        var interior = [Bool](repeating: false, count: w * h)
        minX = w; minY = h; maxX = 0; maxY = 0
        for i in largest {
            interior[i] = true
            minX = min(minX, i % w); maxX = max(maxX, i % w)
            minY = min(minY, i / w); maxY = max(maxY, i / w)
        }

        var edgeQueue = largest, cursor = 0
        var edgeDistance = [UInt8](repeating: 0, count: w * h)
        while cursor < edgeQueue.count {
            let i = edgeQueue[cursor]; cursor += 1


            if fitContent && edgeDistance[i] >= 2 { continue }
            let x = i % w, y = i / w
            for n in [x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1,
                      y > 0 ? i - w : -1, y < h - 1 ? i + w : -1] {

                if n >= 0 && !interior[n] && !exterior[n] && pixels[n * 4 + 3] < 220 {
                    edgeDistance[n] = min(2, edgeDistance[i] + 1)
                    interior[n] = true; edgeQueue.append(n)
                }
            }
        }
        var paper = pixels, mask = [UInt8](repeating: 0, count: pixels.count)
        for i in 0..<(w * h) {
            let p = i * 4, a = Double(pixels[p + 3]) / 255

            let x = i % w, y = i / w
            let neighbours = [x > 0 ? i-1 : i, x < w-1 ? i+1 : i,
                              y > 0 ? i-w : i, y < h-1 ? i+w : i]
            let isPaperInterior = pixels[p+3] >= 128 && neighbours.allSatisfy { pixels[$0 * 4 + 3] >= 128 }
            let coverage = isPaperInterior ? 1 : min(1, Double(pixels[p + 3]) / 230)
            for c in 0..<3 {
                let onWhite = Double(pixels[p + c]) / 255 + (1 - a)
                paper[p + c] = UInt8(min(255, (onWhite * coverage * 255).rounded()))
            }
            paper[p + 3] = UInt8((coverage * 255).rounded())
            if interior[i] {

                for c in 0..<4 { mask[p + c] = 255 }
            }
        }
        let window = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        return ProcessedStampTemplate(
            paper: try image(paper, width: w, height: h),
            windowMask: try image(mask, width: w, height: h),
            window: window,
            contentRect: fitContent ? largestInteriorRect(interior, width: w, height: h) : window
        )
    }


    private static func largestInteriorRect(_ interior: [Bool], width: Int, height: Int) -> CGRect {
        var heights = [Int](repeating: 0, count: width + 1)
        var best = CGRect.zero
        var bestArea = 0
        var stack: [Int] = []
        for y in 0..<height {
            for x in 0..<width { heights[x] = interior[y * width + x] ? heights[x] + 1 : 0 }
            stack.removeAll(keepingCapacity: true)
            for x in 0...width {
                while let last = stack.last, heights[last] > heights[x] {
                    let h = heights[stack.removeLast()]
                    let left = (stack.last ?? -1) + 1
                    let area = (x - left) * h
                    if area > bestArea {
                        bestArea = area
                        best = CGRect(x: left, y: y - h + 1, width: x - left, height: h)
                    }
                }
                stack.append(x)
            }
        }
        return best
    }

    static func render(photo: UIImage, format: StampFormat, transform: StampTransform = .init(),
                       lettering: StampLettering = .init(), maxDimension: CGFloat? = nil) throws -> UIImage {
        let template = try template(format)
        let factor = maxDimension.map { min(1, $0 / max(template.size.width, template.size.height)) } ?? 1
        let size = CGSize(width: (template.size.width * factor).rounded(), height: (template.size.height * factor).rounded())
        let rendererFormat = UIGraphicsImageRendererFormat(); rendererFormat.scale = 1; rendererFormat.opaque = false
        return UIGraphicsImageRenderer(size: size, format: rendererFormat).image { context in
            context.cgContext.scaleBy(x: size.width / template.size.width, y: size.height / template.size.height)
            let bounds = CGRect(origin: .zero, size: template.size)
            context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
            drawCover(photo, in: template.window.insetBy(dx: -2, dy: -2), transform: transform)
            lettering.draw(in: template.contentRect)
            template.windowMask.draw(in: bounds, blendMode: .destinationIn, alpha: 1)
            context.cgContext.endTransparencyLayer()
            template.paper.draw(in: bounds)
        }
    }

    static func drawCover(_ image: UIImage, in rect: CGRect, transform: StampTransform = .init()) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let t = transform.clamped
        let scale = max(rect.width / image.size.width, rect.height / image.size.height) * t.scale
        let width = image.size.width * scale, height = image.size.height * scale
        let x = rect.midX - width / 2 + (width - rect.width) / 2 * t.x
        let y = rect.midY - height / 2 + (height - rect.height) / 2 * t.y
        image.draw(in: CGRect(x: x, y: y, width: width, height: height))
    }

    static func rgba(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let success = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard success else { throw PostalError.image }
        return bytes
    }

    private static func image(_ pixels: [UInt8], width: Int, height: Int) throws -> UIImage {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw PostalError.image }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }
}
