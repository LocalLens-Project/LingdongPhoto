// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

enum CreationMode: String, CaseIterable, Identifiable {
    case motionCard
    case colorPalette
    case journal
    case bubbleStamp
    case spectrumWallpaper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .motionCard: "灵动卡片"
        case .colorPalette: "琉璃色盘"
        case .journal: "一键手帐"
        case .bubbleStamp: "气泡印章"
        case .spectrumWallpaper: "色谱壁纸"
        }
    }

    var subtitle: String {
        switch self {
        case .motionCard: "封存地理与时间的印记，重塑身临其境的沉浸式体验"
        case .colorPalette: "在如琉璃般的通透质感中，萃取影像的本源色彩"
        case .journal: "选取 1～5 张照片，自动排版电子手帐"
        case .bubbleStamp: "随心而动的有机气泡，捕捉影像跳动的呼吸节奏"
        case .spectrumWallpaper: "拒绝千篇一律，每一次亮屏都是你的专属艺术创作"
        }
    }

    var introSubtitle: String {
        switch self {
        case .motionCard:
            "拒绝平淡的叙事\n让每一段生动的记忆都拥有专属色彩"
        case .colorPalette:
            "穿越影像的表象，重现色彩最本真的纯净美学"
        case .journal:
            "选取 1～5 张照片，自动排版电子手帐"
        case .bubbleStamp:
            "记忆像气泡般轻盈跳动"
        case .spectrumWallpaper:
            "拒绝千篇一律\n每一次亮屏都是你的专属艺术创作"
        }
    }

    var symbol: String {
        switch self {
        case .motionCard: "livephoto"
        case .colorPalette: "paintpalette"
        case .journal: "bookmark"
        case .bubbleStamp: "seal"
        case .spectrumWallpaper: "rectangle.on.rectangle"
        }
    }

    var accent: Color {
        switch self {
        case .motionCard: Color(red: 0.76, green: 0.92, blue: 0.67)
        case .colorPalette: Color(red: 0.72, green: 0.88, blue: 0.74)
        case .journal: Color(red: 0.99, green: 0.79, blue: 0.62)
        case .bubbleStamp: Color(red: 0.82, green: 0.93, blue: 0.55)
        case .spectrumWallpaper: Color(red: 0.86, green: 1.00, blue: 0.83)
        }
    }

    var defaultRatio: ArtworkRatio {
        switch self {
        case .journal, .spectrumWallpaper:
            .nineSixteen
        case .motionCard, .colorPalette, .bubbleStamp:
            .threeFour
        }
    }
}

enum ArtworkRatio: String, CaseIterable, Identifiable {
    case threeFour = "3:4"
    case nineSixteen = "9:16"

    var id: String { rawValue }
    var value: CGFloat { self == .threeFour ? 3.0 / 4.0 : 9.0 / 16.0 }
}

enum PaletteLayoutMode: String, CaseIterable, Identifiable {
    case floating = "经典浮动"
    case compact = "紧凑横排"
    case bottom = "底部悬浮"

    var id: String { rawValue }
}

enum ArtworkFontStyle: String, CaseIterable, Identifiable {
    case rounded = "圆体"
    case song = "宋体"
    case serif = "衬线"
    case monospaced = "等宽"

    var id: String { rawValue }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .rounded:
            .system(size: size, weight: weight, design: .rounded)
        case .song:
            .custom("Songti SC", size: size).weight(weight)
        case .serif:
            .system(size: size, weight: weight, design: .serif)
        case .monospaced:
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    func advanced(by delta: Int) -> ArtworkFontStyle {
        let values = Self.allCases
        let current = values.firstIndex(of: self) ?? 0
        return values[(current + delta + values.count) % values.count]
    }
}

struct ArtworkCopy: Equatable {
    var title = "正在理解这一刻"
    var subtitle = "A Moment Taking Shape"
    var journalCaption = "A Moment Taking Shape"
    var emojis = "✨  📷\n🌿  🤍"
}

struct RGBColor: Hashable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    init(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: red, green: green, blue: blue)
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    var hex: String {
        String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }

    var luminance: CGFloat { red * 0.299 + green * 0.587 + blue * 0.114 }

    var literaryName: String {
        let lab = OKLab(rgb: self)
        let chroma = hypot(lab.a, lab.b)
        let hue = (atan2(lab.b, lab.a) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)

        if lab.lightness < 0.23 { return chroma < 0.035 ? "玄夜" : "墨黛" }
        if lab.lightness > 0.94 { return chroma < 0.025 ? "月白" : "云絮" }
        if chroma < 0.025 {
            if lab.lightness < 0.48 { return "远山黛" }
            if lab.lightness < 0.75 { return "烟雨灰" }
            return "素绡"
        }

        switch hue {
        case 0..<18, 348..<360:
            return lab.lightness > 0.72 ? "桃夭" : "胭脂"
        case 18..<42:
            return lab.lightness > 0.76 ? "杏子" : "赭石"
        case 42..<68:
            return lab.lightness > 0.82 ? "缃叶" : "秋香"
        case 68..<102:
            return lab.lightness > 0.80 ? "鹅黄" : "苍黄"
        case 102..<145:
            return lab.lightness > 0.76 ? "柳芽" : "竹青"
        case 145..<178:
            return lab.lightness > 0.72 ? "豆绿" : "松花"
        case 178..<205:
            return lab.lightness > 0.76 ? "水碧" : "青瓷"
        case 205..<235:
            return lab.lightness > 0.75 ? "天水碧" : "黛蓝"
        case 235..<270:
            return lab.lightness > 0.70 ? "晴山" : "群青"
        case 270..<305:
            return lab.lightness > 0.72 ? "雪青" : "紫苑"
        default:
            return lab.lightness > 0.72 ? "藕荷" : "绛紫"
        }
    }

    func adjusted(brightness: CGFloat = 0, saturation: CGFloat = 0) -> RGBColor {
        let average = (red + green + blue) / 3
        let factor = 1 + saturation
        return RGBColor(
            red: (average + (red - average) * factor) + brightness,
            green: (average + (green - average) * factor) + brightness,
            blue: (average + (blue - average) * factor) + brightness
        )
    }

    static let fallback: [RGBColor] = [
        RGBColor(red: 0.78, green: 0.91, blue: 0.48),
        RGBColor(red: 0.34, green: 0.53, blue: 0.31),
        RGBColor(red: 0.91, green: 0.95, blue: 0.64),
        RGBColor(red: 0.18, green: 0.32, blue: 0.18),
        RGBColor(red: 0.66, green: 0.76, blue: 0.37),
        RGBColor(red: 0.93, green: 0.87, blue: 0.54)
    ]

    static let intro: [RGBColor] = [
        RGBColor(red: 0.18, green: 0.39, blue: 0.24),
        RGBColor(red: 0.14, green: 0.31, blue: 0.21),
        RGBColor(red: 0.24, green: 0.45, blue: 0.28),
        RGBColor(red: 0.10, green: 0.24, blue: 0.18),
        RGBColor(red: 0.26, green: 0.48, blue: 0.30),
        RGBColor(red: 0.13, green: 0.30, blue: 0.21)
    ]
}

struct PaletteResult {
    let colors: [RGBColor]
    let percentages: [Double]
}

private struct OKLab {
    var lightness: Double
    var a: Double
    var b: Double

    init(lightness: Double, a: Double, b: Double) {
        self.lightness = lightness
        self.a = a
        self.b = b
    }

    init(rgb: RGBColor) {
        func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        let red = linear(Double(rgb.red))
        let green = linear(Double(rgb.green))
        let blue = linear(Double(rgb.blue))
        let l = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue
        let m = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue
        let s = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue
        let lRoot = cbrt(l)
        let mRoot = cbrt(m)
        let sRoot = cbrt(s)
        lightness = 0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot
        a = 1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot
        b = 0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot
    }

    func distanceSquared(to other: OKLab) -> Double {
        let lightnessDelta = lightness - other.lightness
        let aDelta = a - other.a
        let bDelta = b - other.b
        return lightnessDelta * lightnessDelta + aDelta * aDelta + bDelta * bDelta
    }
}

enum PaletteExtractor {
    private struct Point {
        var rgb: RGBColor
        var lab: OKLab
        var weight: Double
    }

    static func extract(from image: UIImage, colorCount: Int = 6) -> PaletteResult {
        let points = sampledPoints(from: image)
        guard !points.isEmpty else {
            return PaletteResult(
                colors: Array(RGBColor.fallback.prefix(colorCount)),
                percentages: Array(repeating: 100 / Double(colorCount), count: colorCount)
            )
        }

        let clusterCount = min(colorCount, points.count)
        var centers: [OKLab] = []
        let first = points.indices.max { points[$0].weight < points[$1].weight } ?? 0
        centers.append(points[first].lab)

        while centers.count < clusterCount {
            let next = points.indices.max { left, right in
                seedScore(points[left], centers: centers) < seedScore(points[right], centers: centers)
            } ?? 0
            centers.append(points[next].lab)
        }

        var assignments = [Int](repeating: 0, count: points.count)
        for _ in 0..<18 {
            var lightnessSums = [Double](repeating: 0, count: clusterCount)
            var aSums = lightnessSums
            var bSums = lightnessSums
            var weights = lightnessSums

            for index in points.indices {
                let cluster = centers.indices.min {
                    points[index].lab.distanceSquared(to: centers[$0])
                        < points[index].lab.distanceSquared(to: centers[$1])
                } ?? 0
                assignments[index] = cluster
                let weight = points[index].weight
                lightnessSums[cluster] += points[index].lab.lightness * weight
                aSums[cluster] += points[index].lab.a * weight
                bSums[cluster] += points[index].lab.b * weight
                weights[cluster] += weight
            }

            var maximumMovement = 0.0
            for cluster in centers.indices where weights[cluster] > 0 {
                let updated = OKLab(
                    lightness: lightnessSums[cluster] / weights[cluster],
                    a: aSums[cluster] / weights[cluster],
                    b: bSums[cluster] / weights[cluster]
                )
                maximumMovement = max(maximumMovement, centers[cluster].distanceSquared(to: updated))
                centers[cluster] = updated
            }
            if maximumMovement < 0.0000001 { break }
        }

        var weights = [Double](repeating: 0, count: clusterCount)
        var redSums = weights
        var greenSums = weights
        var blueSums = weights
        for index in points.indices {
            let cluster = centers.indices.min {
                points[index].lab.distanceSquared(to: centers[$0])
                    < points[index].lab.distanceSquared(to: centers[$1])
            } ?? assignments[index]
            assignments[index] = cluster
            let weight = points[index].weight
            weights[cluster] += weight
            redSums[cluster] += Double(points[index].rgb.red) * weight
            greenSums[cluster] += Double(points[index].rgb.green) * weight
            blueSums[cluster] += Double(points[index].rgb.blue) * weight
        }

        let sortedClusters = weights.indices.sorted { weights[$0] > weights[$1] }
        let totalWeight = max(weights.reduce(0, +), 1)
        var colors: [RGBColor] = []
        var percentages: [Double] = []
        for cluster in sortedClusters where weights[cluster] > 0 {
            colors.append(RGBColor(
                red: CGFloat(redSums[cluster] / weights[cluster]),
                green: CGFloat(greenSums[cluster] / weights[cluster]),
                blue: CGFloat(blueSums[cluster] / weights[cluster])
            ))
            percentages.append((weights[cluster] / totalWeight * 1_000).rounded() / 10)
        }

        var fallbackIndex = 0
        while colors.count < colorCount {
            colors.append(RGBColor.fallback[fallbackIndex % RGBColor.fallback.count])
            percentages.append(0)
            fallbackIndex += 1
        }
        colors = Array(colors.prefix(colorCount))
        percentages = Array(percentages.prefix(colorCount))
        if let largest = percentages.indices.max(by: { percentages[$0] < percentages[$1] }) {
            percentages[largest] += (1000 - (percentages.reduce(0, +) * 10).rounded()) / 10
        }
        return PaletteResult(colors: colors, percentages: percentages)
    }

    static func colors(from image: UIImage) -> [RGBColor] {
        extract(from: image).colors
    }

    static func percentages(from image: UIImage, palette: [RGBColor]) -> [Double] {
        guard !palette.isEmpty else { return extract(from: image).percentages }
        return percentagesMatching(image: image, palette: palette)
    }

    private static func sampledPoints(from image: UIImage) -> [Point] {
        guard let cgImage = image.cgImage else { return [] }
        let width = 96
        let height = 96
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        struct Bucket { var red = 0.0; var green = 0.0; var blue = 0.0; var count = 0.0 }
        var buckets: [Int: Bucket] = [:]
        for pixel in 0..<(width * height) {
            let index = pixel * bytesPerPixel
            let alpha = pixels[index + 3]
            guard alpha > 16 else { continue }
            let red = Double(pixels[index]) / 255
            let green = Double(pixels[index + 1]) / 255
            let blue = Double(pixels[index + 2]) / 255
            let key = (Int(red * 31) << 10) | (Int(green * 31) << 5) | Int(blue * 31)
            var bucket = buckets[key, default: Bucket()]
            bucket.red += red
            bucket.green += green
            bucket.blue += blue
            bucket.count += 1
            buckets[key] = bucket
        }
        return buckets.values.map { bucket in
            let rgb = RGBColor(
                red: CGFloat(bucket.red / bucket.count),
                green: CGFloat(bucket.green / bucket.count),
                blue: CGFloat(bucket.blue / bucket.count)
            )
            return Point(rgb: rgb, lab: OKLab(rgb: rgb), weight: bucket.count)
        }
    }

    private static func percentagesMatching(image: UIImage, palette: [RGBColor]) -> [Double] {
        guard !palette.isEmpty, let cgImage = image.cgImage else {
            return Array(repeating: 0, count: palette.count)
        }

        let width = 160
        let height = 160
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Array(repeating: 0, count: palette.count)
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var counts = [Int](repeating: 0, count: palette.count)
        for pixelIndex in 0..<(width * height) {
            let index = pixelIndex * bytesPerPixel
            let rgb = RGBColor(
                red: CGFloat(pixels[index]) / 255,
                green: CGFloat(pixels[index + 1]) / 255,
                blue: CGFloat(pixels[index + 2]) / 255
            )
            let lab = OKLab(rgb: rgb)

            let nearest = palette.indices.min { left, right in
                lab.distanceSquared(to: OKLab(rgb: palette[left]))
                    < lab.distanceSquared(to: OKLab(rgb: palette[right]))
            } ?? 0
            counts[nearest] += 1
        }

        let total = Double(width * height)
        var values = counts.map { (Double($0) / total * 1_000).rounded() / 10 }
        if let largestIndex = counts.indices.max(by: { counts[$0] < counts[$1] }) {
            let correction = (1_000 - (values.reduce(0, +) * 10).rounded()) / 10
            values[largestIndex] += correction
        }
        return values
    }

    private static func seedScore(_ point: Point, centers: [OKLab]) -> Double {
        let distance = centers.map { point.lab.distanceSquared(to: $0) }.min() ?? 0
        return distance * log2(point.weight + 2)
    }
}
