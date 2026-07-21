// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

@main
private enum MotionCardColorThemeValidation {
    private struct Scenario {
        let name: String
        let palette: [MotionCardColor]
        let percentages: [Double]
        let verify: (MotionCardColorTheme) -> Bool
    }

    static func main() {
        let black = color(0x050505)
        let white = color(0xFAFAFA)
        let scenarios: [Scenario] = [
            Scenario(
                name: "black-white",
                palette: [black, white, color(0x555555)],
                percentages: [58, 39, 3],
                verify: { theme in
                    theme.anchor.relativeLuminance < 0.03
                        && theme.background.relativeLuminance < 0.10
                        && theme.background.relativeLuminance > theme.anchor.relativeLuminance
                }
            ),
            Scenario(
                name: "red-white",
                palette: [white, color(0xF52242), color(0xEBA3AE)],
                percentages: [51, 45, 4],
                verify: { theme in
                    theme.anchor.red > theme.anchor.green * 2
                        && theme.background.red > theme.background.green
                        && theme.background.green > 0.45
                        && theme.background != white
                }
            ),
            Scenario(
                name: "deep-blue",
                palette: [color(0x17345D), color(0xF6F7F9), color(0x527EB9)],
                percentages: [66, 21, 13],
                verify: { theme in
                    theme.background.blue > theme.background.red
                        && theme.background.relativeLuminance < 0.10
                }
            ),
            Scenario(
                name: "pastel-blue",
                palette: [color(0xD6EAF7), white, color(0xA5CEE8)],
                percentages: [54, 31, 15],
                verify: { theme in
                    theme.background.blue > theme.background.red
                        && theme.background.chromaSpan > 0.04
                }
            ),
            Scenario(
                name: "saturated-yellow",
                palette: [color(0xFFD21F), white, color(0x332A03)],
                percentages: [64, 30, 6],
                verify: { theme in
                    theme.anchor.red > 0.9
                        && theme.background.red > theme.background.blue * 1.5
                }
            ),
            Scenario(
                name: "white-only",
                palette: [white],
                percentages: [100],
                verify: { theme in
                    theme.background.relativeLuminance < 0.90
                        && theme.background.relativeLuminance > 0.70
                }
            ),
            Scenario(
                name: "tiny-red-accent",
                palette: [black, color(0xFF193D), white],
                percentages: [94, 2, 4],
                verify: { theme in
                    theme.anchor.relativeLuminance < 0.03
                        && theme.background.relativeLuminance < 0.10
                }
            )
        ]

        for scenario in scenarios {
            let theme = MotionCardColorTheme.resolve(
                palette: scenario.palette,
                percentages: scenario.percentages
            )
            require(scenario.verify(theme), "\(scenario.name) hue relationship failed")
            let contrast = theme.foreground.contrastRatio(with: theme.background)
            require(
                contrast >= MotionCardColorTheme.minimumTextContrast,
                "\(scenario.name) contrast \(contrast) is below minimum"
            )
            print(String(
                format: "PASS %-18@ bg=%@ fg=%@ contrast=%.2f",
                scenario.name as NSString,
                hex(theme.background) as NSString,
                hex(theme.foreground) as NSString,
                contrast
            ))
        }
    }

    private static func color(_ hex: UInt32) -> MotionCardColor {
        MotionCardColor(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private static func hex(_ color: MotionCardColor) -> String {
        String(
            format: "#%02X%02X%02X",
            Int((color.red * 255).rounded()),
            Int((color.green * 255).rounded()),
            Int((color.blue * 255).rounded())
        )
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
            exit(1)
        }
    }
}
