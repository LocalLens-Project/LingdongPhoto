// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

/// A deliberately finite set of literary color names. Colors are matched to
/// the nearest reference swatch in OKLab, whose distances better reflect
/// perceived differences than raw RGB channel distances.
enum LiteraryColorCatalog {
    static let count = swatches.count

    static func name(red: Double, green: Double, blue: Double) -> String {
        let target = OKLab(
            red: min(max(red, 0), 1),
            green: min(max(green, 0), 1),
            blue: min(max(blue, 0), 1)
        )
        return swatches.min {
            target.distanceSquared(to: $0.lab)
                < target.distanceSquared(to: $1.lab)
        }?.name ?? "烟雨灰"
    }

    static func name(hex: UInt32) -> String {
        name(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Exposed internally so deterministic catalog validation can verify that
    /// every reference swatch remains reachable after future edits.
    static var referenceSamples: [(name: String, hex: UInt32)] {
        swatches.map { ($0.name, $0.hex) }
    }

    private struct Swatch {
        let name: String
        let hex: UInt32
        let lab: OKLab

        init(_ name: String, _ hex: UInt32) {
            self.name = name
            self.hex = hex
            lab = OKLab(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255
            )
        }
    }

    // 76 stable semantic buckets: neutral 12, red 9, orange/brown 8,
    // yellow 9, green 12, cyan 7, blue 9 and purple 10.
    private static let swatches: [Swatch] = [
        // Neutral, ink and earth-grey
        Swatch("玄夜", 0x101214),
        Swatch("乌金", 0x1B1B1F),
        Swatch("墨黛", 0x24242A),
        Swatch("鸦青", 0x313541),
        Swatch("苍墨", 0x3B4443),
        Swatch("远山黛", 0x4A5257),
        Swatch("烟栗", 0x605455),
        Swatch("烟雨灰", 0x81878A),
        Swatch("银鼠", 0xAAA7A2),
        Swatch("素绡", 0xD8D5CF),
        Swatch("月白", 0xF1F5F3),
        Swatch("云絮", 0xFBF7F1),

        // Red and pink
        Swatch("胭脂", 0x9D2933),
        Swatch("朱砂", 0xD94A3D),
        Swatch("绯红", 0xC83C4A),
        Swatch("茜草", 0xB7474D),
        Swatch("海棠", 0xDB6B73),
        Swatch("桃夭", 0xF2A6A0),
        Swatch("樱粉", 0xF4C3C2),
        Swatch("梅染", 0x8E4A62),
        Swatch("酡颜", 0xC77878),

        // Orange and brown
        Swatch("赭石", 0x8A4B2D),
        Swatch("杏子", 0xF2B36D),
        Swatch("橘柚", 0xE9883D),
        Swatch("琥珀", 0xC77B30),
        Swatch("桂皮", 0x9A6446),
        Swatch("栗壳", 0x6F4E3D),
        Swatch("驼绒", 0xB69B7C),
        Swatch("蜜蜡", 0xE2A95A),

        // Yellow
        Swatch("秋香", 0xD8B24A),
        Swatch("缃叶", 0xF1D79A),
        Swatch("鹅黄", 0xF3DC75),
        Swatch("苍黄", 0xA99445),
        Swatch("麦秆", 0xD6C184),
        Swatch("金桂", 0xD8A737),
        Swatch("豆蔻黄", 0xE8E1B4),
        Swatch("青柠", 0xA8C928),
        Swatch("嫩蕊", 0xD4E157),

        // Green
        Swatch("竹青", 0x4F7A5A),
        Swatch("柳芽", 0xA8C879),
        Swatch("豆绿", 0x86B88A),
        Swatch("松花", 0xB7C8A5),
        Swatch("松柏", 0x315C47),
        Swatch("青苔", 0x647A55),
        Swatch("翡翠", 0x2F8C69),
        Swatch("荷叶", 0x607F61),
        Swatch("薄荷", 0xA6D8B4),
        Swatch("艾绿", 0x8BA888),
        Swatch("芭蕉", 0x6AAF45),
        Swatch("葱青", 0x2FB36C),

        // Cyan and teal
        Swatch("青瓷", 0x6FA9A3),
        Swatch("水碧", 0xA2D4CF),
        Swatch("天水碧", 0x8FD3D6),
        Swatch("湖蓝", 0x4FA4B8),
        Swatch("鸭卵青", 0xC1D5CE),
        Swatch("石青", 0x3B7F84),
        Swatch("孔雀蓝", 0x197C88),

        // Blue
        Swatch("黛蓝", 0x35536B),
        Swatch("晴山", 0x8AAFC7),
        Swatch("群青", 0x35599A),
        Swatch("靛青", 0x2F477A),
        Swatch("霁蓝", 0x4A77B5),
        Swatch("月影蓝", 0x6F839B),
        Swatch("瓷蓝", 0x2D6F9F),
        Swatch("海天", 0x75B9D1),
        Swatch("缥色", 0xB4CFDA),

        // Purple
        Swatch("紫苑", 0x76528B),
        Swatch("雪青", 0xB6A7CC),
        Swatch("藕荷", 0xC4A0B6),
        Swatch("绛紫", 0x713B5F),
        Swatch("藤萝", 0x9A7BA8),
        Swatch("丁香", 0xB59CB7),
        Swatch("木槿", 0xA35C7A),
        Swatch("葡萄", 0x5E3F66),
        Swatch("暮云紫", 0x6E627B),
        Swatch("烟紫", 0x8A788C)
    ]

    private struct OKLab {
        let lightness: Double
        let a: Double
        let b: Double

        init(red: Double, green: Double, blue: Double) {
            func linear(_ component: Double) -> Double {
                component <= 0.04045
                    ? component / 12.92
                    : pow((component + 0.055) / 1.055, 2.4)
            }

            let red = linear(red)
            let green = linear(green)
            let blue = linear(blue)
            let l = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue
            let m = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue
            let s = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue
            let lRoot = cbrt(l)
            let mRoot = cbrt(m)
            let sRoot = cbrt(s)
            lightness = 0.2104542553 * lRoot
                + 0.7936177850 * mRoot
                - 0.0040720468 * sRoot
            a = 1.9779984951 * lRoot
                - 2.4285922050 * mRoot
                + 0.4505937099 * sRoot
            b = 0.0259040371 * lRoot
                + 0.7827717662 * mRoot
                - 0.8086757660 * sRoot
        }

        func distanceSquared(to other: OKLab) -> Double {
            let lightnessDelta = lightness - other.lightness
            let aDelta = a - other.a
            let bDelta = b - other.b
            return lightnessDelta * lightnessDelta
                + aDelta * aDelta
                + bDelta * bDelta
        }
    }
}
