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

enum RelationshipPhotoSide: Equatable {
    case left
    case right
}
