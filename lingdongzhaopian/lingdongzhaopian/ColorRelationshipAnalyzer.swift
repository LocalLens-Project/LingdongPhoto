// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import UIKit

enum ColorRelationshipAnalyzer {
    private struct Lab {
        let l: Double
        let a: Double
        let b: Double

        init(red: Double, green: Double, blue: Double) {
            func linear(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            let r = linear(red)
            let g = linear(green)
            let b = linear(blue)
            let x = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
            let y = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
            let z = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
            let xRoot = cbrt(x)
            let yRoot = cbrt(y)
            let zRoot = cbrt(z)
            l = 0.2104542553 * xRoot + 0.7936177850 * yRoot - 0.0040720468 * zRoot
            a = 1.9779984951 * xRoot - 2.4285922050 * yRoot + 0.4505937099 * zRoot
            self.b = 0.0259040371 * xRoot + 0.7827717662 * yRoot - 0.8086757660 * zRoot
        }

        func distance(to other: Lab) -> Double {
            let dl = l - other.l
            let da = a - other.a
            let db = b - other.b
            return sqrt(dl * dl + da * da + db * db)
        }
    }

    private struct Bucket {
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0
        var count: Double = 0

        var color: PaletteColor {
            PaletteColor(red: red / count, green: green / count, blue: blue / count, weight: count)
        }
    }

    static func analyze(left: UIImage, right: UIImage) -> ColorRelationship {
        let leftPalette = extractPalette(from: left)
        let rightPalette = extractPalette(from: right)
        let matched = bestMatches(left: leftPalette, right: rightPalette)
        let resonance = matched.sorted { $0.distance < $1.distance }

        var allPairs: [ColorPair] = []
        for leftColor in leftPalette {
            for rightColor in rightPalette {
                allPairs.append(ColorPair(
                    left: leftColor,
                    right: rightColor,
                    distance: distance(leftColor, rightColor)
                ))
            }
        }
        let contrast = allPairs.sorted { $0.distance > $1.distance }

        let weightedDistance = matched.reduce(0.0) { partial, pair in
            partial + pair.distance * max((pair.left.weight + pair.right.weight) / 2, 0.05)
        } / max(matched.reduce(0.0) { $0 + max(($1.left.weight + $1.right.weight) / 2, 0.05) }, 0.01)
        let affinity = Int(((1 - min(weightedDistance / 0.34, 1)) * 100).rounded())

        let leftLight = leftPalette.reduce(0.0) { $0 + $1.perceivedLightness * $1.weight }
        let rightLight = rightPalette.reduce(0.0) { $0 + $1.perceivedLightness * $1.weight }
        let lightDifference = Int((abs(leftLight - rightLight) * 100).rounded())
        let leftWarmth = warmth(of: leftPalette)
        let rightWarmth = warmth(of: rightPalette)
        let temperatureDifference = Int((abs(leftWarmth - rightWarmth) * 100).rounded())
        let leftSaturation = saturation(of: leftPalette)
        let rightSaturation = saturation(of: rightPalette)
        let leftNeutrality = neutralShare(of: leftPalette)
        let rightNeutrality = neutralShare(of: rightPalette)

        let bridgeSource = resonance.first ?? matched.first!
        let bridge = (0..<7).map { index in
            bridgeSource.left.mixed(with: bridgeSource.right, amount: Double(index) / 6)
        }

        let strongestContrast = contrast.first ?? bridgeSource
        let resonanceCoverage = min(1, resonance.prefix(2).reduce(0.0) { partial, pair in
            partial + (pair.left.weight + pair.right.weight) / 2
        })
        let copyInput = RelationshipCopyInput(
            leftPalette: leftPalette,
            rightPalette: rightPalette,
            resonancePairs: resonance,
            contrastPairs: contrast,
            affinity: affinity,
            lightShift: rightLight - leftLight,
            warmthShift: rightWarmth - leftWarmth,
            saturationShift: rightSaturation - leftSaturation,
            neutralShift: rightNeutrality - leftNeutrality,
            hueSeparation: hueSeparation(leftPalette.first, rightPalette.first),
            resonanceCoverage: resonanceCoverage,
            closestDistance: resonance.first?.distance ?? 1,
            averageLightness: (leftLight + rightLight) / 2,
            averageSaturation: (leftSaturation + rightSaturation) / 2,
            leftDominantName: colorName(for: leftPalette[0]),
            rightDominantName: colorName(for: rightPalette[0]),
            sharedName: colorName(for: bridgeSource.middle),
            contrastLeftName: colorName(for: strongestContrast.left),
            contrastRightName: colorName(for: strongestContrast.right),
            bridgeLeftName: colorName(for: bridgeSource.left),
            bridgeRightName: colorName(for: bridgeSource.right)
        )
        let copies = RelationshipCopywriter.compose(copyInput)

        return ColorRelationship(
            leftPalette: leftPalette,
            rightPalette: rightPalette,
            resonancePairs: resonance,
            contrastPairs: contrast,
            bridge: bridge,
            affinity: affinity,
            lightDifference: lightDifference,
            temperatureDifference: temperatureDifference,
            copies: copies
        )
    }

    static func extractPalette(from image: UIImage, count: Int = 5) -> [PaletteColor] {
        guard let pixels = pixels(from: image, side: 88), !pixels.isEmpty else {
            return fallbackPalette(count: count)
        }

        var buckets: [Int: Bucket] = [:]
        for pixel in pixels {
            let r = Int(pixel.0 * 15)
            let g = Int(pixel.1 * 15)
            let b = Int(pixel.2 * 15)
            let key = (r << 8) | (g << 4) | b
            var bucket = buckets[key] ?? Bucket()
            let chroma = max(pixel.0, pixel.1, pixel.2) - min(pixel.0, pixel.1, pixel.2)
            let weight = 0.72 + chroma * 0.42
            bucket.red += pixel.0 * weight
            bucket.green += pixel.1 * weight
            bucket.blue += pixel.2 * weight
            bucket.count += weight
            buckets[key] = bucket
        }

        let candidates = buckets.values.map(\.color).sorted { $0.weight > $1.weight }
        guard !candidates.isEmpty else { return fallbackPalette(count: count) }

        var centers = [candidates[0]]
        while centers.count < min(count, candidates.count) {
            let next = candidates.max { first, second in
                seedScore(first, centers: centers) < seedScore(second, centers: centers)
            }!
            centers.append(next)
        }

        for _ in 0..<10 {
            var groups = Array(repeating: Bucket(), count: centers.count)
            for candidate in candidates {
                let index = centers.indices.min { distance(candidate, centers[$0]) < distance(candidate, centers[$1]) }!
                groups[index].red += candidate.red * candidate.weight
                groups[index].green += candidate.green * candidate.weight
                groups[index].blue += candidate.blue * candidate.weight
                groups[index].count += candidate.weight
            }
            for index in centers.indices where groups[index].count > 0 {
                centers[index] = groups[index].color
            }
        }

        var totals = Array(repeating: 0.0, count: centers.count)
        var rgbTotals = Array(repeating: (0.0, 0.0, 0.0), count: centers.count)
        for candidate in candidates {
            let index = centers.indices.min { distance(candidate, centers[$0]) < distance(candidate, centers[$1]) }!
            totals[index] += candidate.weight
            rgbTotals[index].0 += candidate.red * candidate.weight
            rgbTotals[index].1 += candidate.green * candidate.weight
            rgbTotals[index].2 += candidate.blue * candidate.weight
        }
        let grandTotal = max(totals.reduce(0, +), 1)
        var result = centers.indices.map { index -> PaletteColor in
            let total = max(totals[index], 0.001)
            return PaletteColor(
                red: rgbTotals[index].0 / total,
                green: rgbTotals[index].1 / total,
                blue: rgbTotals[index].2 / total,
                weight: total / grandTotal
            )
        }
        result.sort { $0.weight > $1.weight }
        while result.count < count { result.append(result.last!) }
        return Array(result.prefix(count))
    }

    private static func bestMatches(left: [PaletteColor], right: [PaletteColor]) -> [ColorPair] {
        let count = min(left.count, right.count)
        var bestOrder = Array(0..<count)
        var bestCost = Double.greatestFiniteMagnitude
        for order in permutations(Array(0..<count)) {
            var cost = 0.0
            for index in 0..<count {
                let importance = 0.45 + (left[index].weight + right[order[index]].weight) / 2
                cost += distance(left[index], right[order[index]]) * importance
            }
            if cost < bestCost {
                bestCost = cost
                bestOrder = order
            }
        }
        return (0..<count).map { index in
            ColorPair(
                left: left[index],
                right: right[bestOrder[index]],
                distance: distance(left[index], right[bestOrder[index]])
            )
        }
    }

    private static func permutations(_ values: [Int]) -> [[Int]] {
        guard values.count > 1 else { return [values] }
        return values.indices.flatMap { index -> [[Int]] in
            var rest = values
            let head = rest.remove(at: index)
            return permutations(rest).map { [head] + $0 }
        }
    }

    private static func seedScore(_ color: PaletteColor, centers: [PaletteColor]) -> Double {
        let nearest = centers.map { distance(color, $0) }.min() ?? 0
        return nearest * nearest * sqrt(max(color.weight, 0.001))
    }

    private static func distance(_ first: PaletteColor, _ second: PaletteColor) -> Double {
        Lab(red: first.red, green: first.green, blue: first.blue).distance(
            to: Lab(red: second.red, green: second.green, blue: second.blue)
        )
    }

    private static func warmth(of palette: [PaletteColor]) -> Double {
        palette.reduce(0.0) { partial, color in
            partial + ((color.red - color.blue + 1) / 2) * color.weight
        }
    }

    private static func saturation(of palette: [PaletteColor]) -> Double {
        palette.reduce(0.0) { partial, color in
            let chroma = max(color.red, color.green, color.blue) - min(color.red, color.green, color.blue)
            return partial + chroma * color.weight
        }
    }

    private static func neutralShare(of palette: [PaletteColor]) -> Double {
        palette.reduce(0.0) { partial, color in
            let chroma = max(color.red, color.green, color.blue) - min(color.red, color.green, color.blue)
            return partial + (chroma < 0.12 ? color.weight : 0)
        }
    }

    private static func hueSeparation(_ first: PaletteColor?, _ second: PaletteColor?) -> Double {
        guard let first, let second, let firstHue = hue(of: first), let secondHue = hue(of: second) else {
            return 0
        }
        let difference = abs(firstHue - secondHue)
        return min(difference, 360 - difference)
    }

    private static func hue(of color: PaletteColor) -> Double? {
        let maximum = max(color.red, color.green, color.blue)
        let minimum = min(color.red, color.green, color.blue)
        let chroma = maximum - minimum
        guard chroma >= 0.08 else { return nil }

        let rawHue: Double
        if maximum == color.red {
            rawHue = ((color.green - color.blue) / chroma).truncatingRemainder(dividingBy: 6) * 60
        } else if maximum == color.green {
            rawHue = ((color.blue - color.red) / chroma + 2) * 60
        } else {
            rawHue = ((color.red - color.green) / chroma + 4) * 60
        }
        return rawHue < 0 ? rawHue + 360 : rawHue
    }

    private static func colorName(for color: PaletteColor) -> String {
        let maxValue = max(color.red, color.green, color.blue)
        let minValue = min(color.red, color.green, color.blue)
        let chroma = maxValue - minValue
        if color.perceivedLightness < 0.18 { return "墨色" }
        if color.perceivedLightness > 0.82 && chroma < 0.12 { return "月白" }
        if chroma < 0.10 { return color.perceivedLightness > 0.52 ? "雾灰" : "岩灰" }

        let hue: Double
        if maxValue == color.red {
            hue = ((color.green - color.blue) / chroma).truncatingRemainder(dividingBy: 6) * 60
        } else if maxValue == color.green {
            hue = ((color.blue - color.red) / chroma + 2) * 60
        } else {
            hue = ((color.red - color.green) / chroma + 4) * 60
        }
        let normalized = hue < 0 ? hue + 360 : hue
        switch normalized {
        case 0..<18, 345...360: return "朱砂"
        case 18..<45: return "陶橙"
        case 45..<72: return "麦金"
        case 72..<155: return "苔绿"
        case 155..<200: return "雨青"
        case 200..<255: return "暮蓝"
        case 255..<300: return "藤紫"
        default: return "胭脂"
        }
    }

    private static func pixels(from image: UIImage, side: Int) -> [(Double, Double, Double)]? {
        guard let cgImage = image.cgImage else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var data = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        guard let context = CGContext(
            data: &data,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var result: [(Double, Double, Double)] = []
        result.reserveCapacity(side * side)
        for index in stride(from: 0, to: data.count, by: 4) where data[index + 3] > 18 {
            result.append((
                Double(data[index]) / 255,
                Double(data[index + 1]) / 255,
                Double(data[index + 2]) / 255
            ))
        }
        return result
    }

    private static func fallbackPalette(count: Int) -> [PaletteColor] {
        let colors = [
            PaletteColor(red: 0.20, green: 0.31, blue: 0.31, weight: 0.32),
            PaletteColor(red: 0.74, green: 0.44, blue: 0.34, weight: 0.24),
            PaletteColor(red: 0.73, green: 0.65, blue: 0.52, weight: 0.18),
            PaletteColor(red: 0.35, green: 0.48, blue: 0.52, weight: 0.15),
            PaletteColor(red: 0.84, green: 0.77, blue: 0.64, weight: 0.11)
        ]
        return Array(colors.prefix(count))
    }
}
