import SwiftUI

enum EmptyCanvasTheme: String, CaseIterable, Identifiable {
    case lingdong = "灵动青"
    case celadon = "青瓷"
    case sky = "天水"
    case dusk = "暮霞"
    case amber = "秋岚"
    case wisteria = "藤紫"
    case midnight = "夜海"
    case mist = "雾银"
    case vermilion = "朱砂"

    var id: String { rawValue }

    var palette: [RGBColor] {
        switch self {
        case .lingdong:
            RGBColor.intro
        case .celadon:
            colors((0.15, 0.37, 0.34), (0.12, 0.29, 0.28), (0.27, 0.48, 0.42), (0.09, 0.22, 0.23))
        case .sky:
            colors((0.16, 0.34, 0.47), (0.12, 0.27, 0.39), (0.28, 0.48, 0.60), (0.09, 0.20, 0.31))
        case .dusk:
            colors((0.43, 0.25, 0.35), (0.31, 0.20, 0.31), (0.56, 0.36, 0.40), (0.22, 0.15, 0.26))
        case .amber:
            colors((0.43, 0.31, 0.18), (0.32, 0.24, 0.16), (0.54, 0.41, 0.24), (0.23, 0.17, 0.13))
        case .wisteria:
            colors((0.31, 0.26, 0.48), (0.23, 0.21, 0.38), (0.44, 0.36, 0.57), (0.17, 0.15, 0.29))
        case .midnight:
            colors((0.11, 0.23, 0.37), (0.08, 0.17, 0.29), (0.20, 0.34, 0.48), (0.06, 0.12, 0.22))
        case .mist:
            colors((0.28, 0.34, 0.38), (0.21, 0.27, 0.31), (0.40, 0.46, 0.49), (0.16, 0.21, 0.25))
        case .vermilion:
            colors((0.45, 0.23, 0.22), (0.33, 0.17, 0.18), (0.57, 0.32, 0.26), (0.24, 0.12, 0.15))
        }
    }

    var gradient: LinearGradient {
        let values = palette
        return LinearGradient(
            colors: [values[0].color, values[2].color, values[1].color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var accent: Color {
        let anchor = palette[2]
        let lift: CGFloat = anchor.relativeLuminance < 0.12 ? 0.38 : 0.30
        return anchor.adjusted(brightness: lift, saturation: -0.08).color
    }

    private func colors(
        _ first: (CGFloat, CGFloat, CGFloat),
        _ second: (CGFloat, CGFloat, CGFloat),
        _ third: (CGFloat, CGFloat, CGFloat),
        _ fourth: (CGFloat, CGFloat, CGFloat)
    ) -> [RGBColor] {
        let base = [first, second, third, fourth]
        return (base + [third, second]).map {
            RGBColor(red: $0.0, green: $0.1, blue: $0.2)
        }
    }
}
