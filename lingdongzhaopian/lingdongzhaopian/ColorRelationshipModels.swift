// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct RelationshipPhoto: Identifiable {
    let id = UUID()
    var image: UIImage
    var title: String
    var detail: String
    var sourceImageURL: URL? = nil
    var originalPixelSize: CGSize? = nil
}

struct PaletteColor: Identifiable, Hashable {
    let id = UUID()
    let red: Double
    let green: Double
    let blue: Double
    let weight: Double

    var color: Color { Color(red: red, green: green, blue: blue) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }

    var hex: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var perceivedLightness: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    var relativeLuminance: Double {
        func linearized(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }

    func mixed(with other: PaletteColor, amount: Double = 0.5) -> PaletteColor {
        let t = min(max(amount, 0), 1)
        return PaletteColor(
            red: red * (1 - t) + other.red * t,
            green: green * (1 - t) + other.green * t,
            blue: blue * (1 - t) + other.blue * t,
            weight: (weight + other.weight) / 2
        )
    }
}

struct ColorPair: Identifiable {
    let id = UUID()
    let left: PaletteColor
    let right: PaletteColor
    let distance: Double

    var middle: PaletteColor { left.mixed(with: right) }
}

enum RelationshipLens: String, CaseIterable, Identifiable {
    case resonance = "共鸣"
    case contrast = "对照"
    case bridge = "过渡"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .resonance: "point.3.connected.trianglepath.dotted"
        case .contrast: "circle.lefthalf.filled.inverse"
        case .bridge: "water.waves"
        }
    }

    var caption: String {
        switch self {
        case .resonance: "寻找两张照片里互相认出的颜色"
        case .contrast: "看看它们把彼此推向了哪里"
        case .bridge: "生成从一张照片走向另一张的色阶"
        }
    }
}

struct RelationshipCopy: Equatable {
    let title: String
    let narrative: String
}

struct RelationshipCopySet: Equatable {
    let resonance: RelationshipCopy
    let contrast: RelationshipCopy
    let bridge: RelationshipCopy

    func copy(for lens: RelationshipLens) -> RelationshipCopy {
        switch lens {
        case .resonance: resonance
        case .contrast: contrast
        case .bridge: bridge
        }
    }
}

struct ColorRelationship {
    let leftPalette: [PaletteColor]
    let rightPalette: [PaletteColor]
    let resonancePairs: [ColorPair]
    let contrastPairs: [ColorPair]
    let bridge: [PaletteColor]
    let affinity: Int
    let lightDifference: Int
    let temperatureDifference: Int
    let copies: RelationshipCopySet

    func copy(for lens: RelationshipLens) -> RelationshipCopy {
        copies.copy(for: lens)
    }

    var signatureColor: PaletteColor {
        resonancePairs.first?.middle
            ?? leftPalette.first?.mixed(with: rightPalette.first ?? leftPalette[0])
            ?? PaletteColor(red: 0.45, green: 0.52, blue: 0.46, weight: 1)
    }

    var inkColor: Color {
        signatureColor.perceivedLightness > 0.58 ? Color.black.opacity(0.88) : Color.white.opacity(0.94)
    }
}

enum RelationshipPhotoSide {
    case left
    case right
}

enum DemoPhotos {
    static func pair() -> [RelationshipPhoto] {
        [
            RelationshipPhoto(
                image: makeLandscape(
                    top: UIColor(red: 0.12, green: 0.25, blue: 0.39, alpha: 1),
                    middle: UIColor(red: 0.86, green: 0.48, blue: 0.35, alpha: 1),
                    bottom: UIColor(red: 0.16, green: 0.25, blue: 0.22, alpha: 1),
                    sun: UIColor(red: 1.00, green: 0.77, blue: 0.45, alpha: 1),
                    seed: 3
                ),
                title: "山谷日落",
                detail: "示例 · 18:42"
            ),
            RelationshipPhoto(
                image: makeLandscape(
                    top: UIColor(red: 0.18, green: 0.35, blue: 0.52, alpha: 1),
                    middle: UIColor(red: 0.74, green: 0.62, blue: 0.53, alpha: 1),
                    bottom: UIColor(red: 0.09, green: 0.28, blue: 0.31, alpha: 1),
                    sun: UIColor(red: 0.92, green: 0.45, blue: 0.34, alpha: 1),
                    seed: 11
                ),
                title: "海边入夜",
                detail: "示例 · 19:06"
            )
        ]
    }

    static func landscapePair() -> [RelationshipPhoto] {
        pair().map { photo in
            var copy = photo
            copy.image = landscapeCrop(of: photo.image)
            return copy
        }
    }

    static func brightPair() -> [RelationshipPhoto] {
        [
            RelationshipPhoto(
                image: makeLandscape(
                    top: UIColor(red: 1.00, green: 0.98, blue: 0.42, alpha: 1),
                    middle: UIColor(red: 1.00, green: 0.83, blue: 0.16, alpha: 1),
                    bottom: UIColor(red: 0.95, green: 0.91, blue: 0.48, alpha: 1),
                    sun: UIColor(red: 1.00, green: 1.00, blue: 0.88, alpha: 1),
                    seed: 5
                ),
                title: "高亮暖色",
                detail: "对比度测试"
            ),
            RelationshipPhoto(
                image: makeLandscape(
                    top: UIColor(red: 0.66, green: 0.88, blue: 1.00, alpha: 1),
                    middle: UIColor(red: 0.18, green: 0.68, blue: 1.00, alpha: 1),
                    bottom: UIColor(red: 0.63, green: 0.91, blue: 0.94, alpha: 1),
                    sun: UIColor(red: 0.98, green: 0.98, blue: 0.55, alpha: 1),
                    seed: 13
                ),
                title: "高亮冷色",
                detail: "对比度测试"
            )
        ]
    }

    static func mixedPair(portraitFirst: Bool = true) -> [RelationshipPhoto] {
        let originals = pair()
        var landscape = originals[portraitFirst ? 1 : 0]
        landscape.image = landscapeCrop(of: landscape.image)
        if portraitFirst {
            return [originals[0], landscape]
        }
        return [landscape, originals[1]]
    }

    private static func landscapeCrop(of image: UIImage) -> UIImage {
        let size = CGSize(width: 1200, height: 760)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
    }

    private static func makeLandscape(
        top: UIColor,
        middle: UIColor,
        bottom: UIColor,
        sun: UIColor,
        seed: Int
    ) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let colors = [top.cgColor, middle.cgColor, bottom.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.58, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            cg.setFillColor(sun.withAlphaComponent(0.92).cgColor)
            cg.fillEllipse(in: CGRect(x: CGFloat(520 + seed * 7), y: 330, width: 170, height: 170))

            cg.setFillColor(bottom.withAlphaComponent(0.78).cgColor)
            let ridge = CGMutablePath()
            ridge.move(to: CGPoint(x: 0, y: 770))
            for index in 0...9 {
                let x = CGFloat(index) * 100
                let y = CGFloat(680 + ((index * 73 + seed * 31) % 190))
                ridge.addLine(to: CGPoint(x: x, y: y))
            }
            ridge.addLine(to: CGPoint(x: size.width, y: size.height))
            ridge.addLine(to: CGPoint(x: 0, y: size.height))
            ridge.closeSubpath()
            cg.addPath(ridge)
            cg.fillPath()

            cg.setFillColor(UIColor.black.withAlphaComponent(0.22).cgColor)
            for index in 0..<18 {
                let x = CGFloat((index * 137 + seed * 43) % 900)
                let height = CGFloat(90 + ((index * 47 + seed) % 260))
                cg.fillEllipse(in: CGRect(x: x, y: size.height - height, width: 46, height: height * 0.55))
                cg.fill(CGRect(x: x + 20, y: size.height - height * 0.62, width: 7, height: height * 0.62))
            }

            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.17).cgColor)
            cg.setLineWidth(3)
            for index in 0..<7 {
                let y = CGFloat(870 + index * 34)
                cg.move(to: CGPoint(x: CGFloat(40 + index * 18), y: y))
                cg.addCurve(
                    to: CGPoint(x: 850, y: y + 10),
                    control1: CGPoint(x: 260, y: y - 28),
                    control2: CGPoint(x: 620, y: y + 35)
                )
                cg.strokePath()
            }
        }
    }
}
