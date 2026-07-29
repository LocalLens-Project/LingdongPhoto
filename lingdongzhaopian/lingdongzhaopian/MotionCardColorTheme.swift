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

struct MotionCardGradientTheme: Equatable {
    static let minimumTextContrast = MotionCardColorTheme.minimumTextContrast

    let colors: [MotionCardColor]
    let foreground: MotionCardColor

    static func resolve(
        palette: [MotionCardColor],
        percentages: [Double]
    ) -> MotionCardGradientTheme {
        let source = palette.isEmpty
            ? [MotionCardColor(red: 0.34, green: 0.53, blue: 0.31)]
            : palette
        let solidTheme = MotionCardColorTheme.resolve(
            palette: source,
            percentages: percentages
        )
        let weights = source.indices.map { index in
            index < percentages.count ? max(percentages[index], 0) : 0
        }
        let strongestWeight = max(weights.max() ?? 0, 1)
        let support = source.indices
            .filter { index in
                source[index] != solidTheme.anchor
                    && (weights[index] >= strongestWeight * 0.08 || weights[index] >= 2)
            }
            .max { left, right in
                supportScore(
                    color: source[left],
                    weight: weights[left],
                    anchor: solidTheme.anchor,
                    strongestWeight: strongestWeight
                ) < supportScore(
                    color: source[right],
                    weight: weights[right],
                    anchor: solidTheme.anchor,
                    strongestWeight: strongestWeight
                )
            }
            .map { source[$0] }
            ?? solidTheme.background

        // The upper stop borrows a sufficiently represented secondary tone,
        // while the lower edge returns to the dominant image tone. This gives
        // the impression that the photograph continues upward without copying
        // or blurring recognizable image content.
        let rawColors = [
            support.mixed(with: solidTheme.anchor, amount: 0.42),
            support.mixed(with: solidTheme.anchor, amount: 0.68),
            solidTheme.anchor.mixed(with: solidTheme.background, amount: 0.16),
            solidTheme.anchor
        ]

        let black = MotionCardColor(red: 0.025, green: 0.025, blue: 0.028)
        let white = MotionCardColor(red: 0.975, green: 0.975, blue: 0.97)
        let blackMinimum = rawColors
            .map { black.contrastRatio(with: $0) }
            .min() ?? 0
        let whiteMinimum = rawColors
            .map { white.contrastRatio(with: $0) }
            .min() ?? 0
        let neutralForeground = blackMinimum >= whiteMinimum ? black : white
        var safeColors = rawColors.map {
            colorEnsuringContrast(
                $0,
                foreground: neutralForeground,
                minimum: minimumTextContrast
            )
        }
        // Nearly monochrome photographs can otherwise produce a gradient that
        // is mathematically present but visually indistinguishable from a
        // solid fill. Strengthen only the far edge; keep the lower stop intact
        // so the transition into the photograph still feels continuous.
        if neutralForeground.relativeLuminance > 0.5 {
            safeColors[0] = safeColors[0].mixed(with: black, amount: 0.38)
            safeColors[1] = safeColors[1].mixed(with: black, amount: 0.16)
        } else {
            safeColors[0] = colorEnsuringContrast(
                safeColors[0].mixed(with: black, amount: 0.12),
                foreground: neutralForeground,
                minimum: minimumTextContrast
            )
            safeColors[1] = colorEnsuringContrast(
                safeColors[1].mixed(with: black, amount: 0.05),
                foreground: neutralForeground,
                minimum: minimumTextContrast
            )
        }

        let tintedForeground = solidTheme.anchor.mixed(
            with: neutralForeground,
            amount: 0.88
        )
        let foreground = safeColors.allSatisfy {
            tintedForeground.contrastRatio(with: $0) >= minimumTextContrast
        } ? tintedForeground : neutralForeground

        return MotionCardGradientTheme(
            colors: safeColors,
            foreground: foreground
        )
    }

    private static func supportScore(
        color: MotionCardColor,
        weight: Double,
        anchor: MotionCardColor,
        strongestWeight: Double
    ) -> Double {
        let redDelta = color.red - anchor.red
        let greenDelta = color.green - anchor.green
        let blueDelta = color.blue - anchor.blue
        let colorDistance = sqrt(
            redDelta * redDelta
                + greenDelta * greenDelta
                + blueDelta * blueDelta
        )
        let luminanceDistance = abs(
            color.relativeLuminance - anchor.relativeLuminance
        )
        let normalizedWeight = min(weight / strongestWeight, 1)
        return normalizedWeight * 0.52
            + min(colorDistance, 1.2) * 0.30
            + min(luminanceDistance, 1) * 0.18
    }

    private static func colorEnsuringContrast(
        _ initial: MotionCardColor,
        foreground: MotionCardColor,
        minimum: Double
    ) -> MotionCardColor {
        let black = MotionCardColor(red: 0.018, green: 0.018, blue: 0.020)
        let white = MotionCardColor(red: 0.985, green: 0.985, blue: 0.98)
        let adjustmentTarget = foreground.relativeLuminance > 0.5
            ? black
            : white
        var result = initial

        for _ in 0..<24 {
            if foreground.contrastRatio(with: result) >= minimum {
                break
            }
            result = result.mixed(with: adjustmentTarget, amount: 0.08)
        }
        return result
    }
}
