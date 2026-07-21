// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

struct MotionCardColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
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

    var chromaSpan: Double {
        max(red, green, blue) - min(red, green, blue)
    }

    func contrastRatio(with other: MotionCardColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func mixed(with other: MotionCardColor, amount: Double) -> MotionCardColor {
        let fraction = min(max(amount, 0), 1)
        return MotionCardColor(
            red: red + (other.red - red) * fraction,
            green: green + (other.green - green) * fraction,
            blue: blue + (other.blue - blue) * fraction
        )
    }
}

struct MotionCardColorTheme: Equatable {
    static let minimumTextContrast = 7.0

    let anchor: MotionCardColor
    let background: MotionCardColor
    let foreground: MotionCardColor

    static func resolve(
        palette: [MotionCardColor],
        percentages: [Double]
    ) -> MotionCardColorTheme {
        let source = palette.isEmpty
            ? [MotionCardColor(red: 0.34, green: 0.53, blue: 0.31)]
            : palette
        let entries = source.enumerated().map { index, color in
            Entry(
                color: color,
                weight: index < percentages.count
                    ? max(percentages[index], 0)
                    : 0
            )
        }
        let weightedEntries: [Entry]
        if entries.contains(where: { $0.weight > 0 }) {
            weightedEntries = entries.filter { $0.weight > 0 }
        } else {
            weightedEntries = entries.map { Entry(color: $0.color, weight: 1) }
        }

        let strongestWeight = weightedEntries.map(\.weight).max() ?? 1
        let minimumSubjectWeight = max(1.5, strongestWeight * 0.04)
        let subjectCandidates = weightedEntries.filter { entry in
            !entry.isNeutralExtreme
                && entry.weight >= minimumSubjectWeight
                && (entry.color.chromaSpan >= 0.075 || entry.weight >= strongestWeight * 0.18)
        }
        let anchor = (subjectCandidates.isEmpty ? weightedEntries : subjectCandidates)
            .max { $0.subjectScore < $1.subjectScore }?
            .color
            ?? source[0]

        let wantsDarkSurface = anchor.relativeLuminance < 0.12
        var background = tonedBackground(for: anchor, dark: wantsDarkSurface)
        background = backgroundEnsuringContrast(
            background,
            dark: wantsDarkSurface,
            minimum: minimumTextContrast
        )

        let black = MotionCardColor(red: 0.025, green: 0.025, blue: 0.028)
        let white = MotionCardColor(red: 0.975, green: 0.975, blue: 0.97)
        let preferred = wantsDarkSurface
            ? anchor.mixed(with: white, amount: 0.88)
            : anchor.mixed(with: black, amount: 0.82)
        let foreground: MotionCardColor
        if preferred.contrastRatio(with: background) >= minimumTextContrast {
            foreground = preferred
        } else {
            foreground = black.contrastRatio(with: background)
                >= white.contrastRatio(with: background)
                ? black
                : white
        }

        return MotionCardColorTheme(
            anchor: anchor,
            background: background,
            foreground: foreground
        )
    }

    private static func tonedBackground(
        for anchor: MotionCardColor,
        dark: Bool
    ) -> MotionCardColor {
        let black = MotionCardColor(red: 0.025, green: 0.025, blue: 0.028)
        let white = MotionCardColor(red: 0.965, green: 0.965, blue: 0.95)

        if dark {
            return anchor.mixed(with: white, amount: 0.13)
        }
        if anchor.relativeLuminance > 0.76 {
            let result = anchor.mixed(with: black, amount: 0.075)
            if result.chromaSpan < 0.035, result.relativeLuminance > 0.82 {
                return MotionCardColor(red: 0.91, green: 0.905, blue: 0.885)
            }
            return result
        }
        let whiteAmount = anchor.relativeLuminance < 0.30 ? 0.62 : 0.50
        return anchor.mixed(with: white, amount: whiteAmount)
    }

    private static func backgroundEnsuringContrast(
        _ initial: MotionCardColor,
        dark: Bool,
        minimum: Double
    ) -> MotionCardColor {
        let black = MotionCardColor(red: 0.025, green: 0.025, blue: 0.028)
        let white = MotionCardColor(red: 0.975, green: 0.975, blue: 0.97)
        var result = initial

        for _ in 0..<16 {
            let contrast = dark
                ? white.contrastRatio(with: result)
                : black.contrastRatio(with: result)
            if contrast >= minimum { break }
            result = result.mixed(with: dark ? black : white, amount: 0.10)
        }
        return result
    }

    private struct Entry {
        let color: MotionCardColor
        let weight: Double

        var isNeutralExtreme: Bool {
            let isNearWhite = color.relativeLuminance >= 0.84 && color.chromaSpan < 0.10
            let isNearBlack = color.relativeLuminance <= 0.025 && color.chromaSpan < 0.08
            return isNearWhite || isNearBlack
        }

        var subjectScore: Double {
            weight + min(color.chromaSpan, 0.80) * 10
        }
    }
}
