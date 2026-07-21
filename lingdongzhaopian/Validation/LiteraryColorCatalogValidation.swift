// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

@main
private enum LiteraryColorCatalogValidation {
    static func main() {
        require(LiteraryColorCatalog.count == 76, "expected 76 names")
        require(
            LiteraryColorCatalog.name(hex: 0x313541) == "鸦青",
            "#313541 should be 鸦青"
        )
        require(
            LiteraryColorCatalog.name(hex: 0x605455) == "烟栗",
            "#605455 should be 烟栗"
        )

        let previousNames: Set<String> = [
            "云絮", "墨黛", "天水碧", "晴山", "月白", "杏子", "松花", "柳芽", "桃夭", "水碧",
            "烟雨灰", "玄夜", "秋香", "竹青", "素绡", "紫苑", "绛紫", "缃叶", "群青", "胭脂",
            "苍黄", "藕荷", "豆绿", "赭石", "远山黛", "雪青", "青瓷", "鹅黄", "黛蓝"
        ]
        let currentNames = Set(LiteraryColorCatalog.referenceSamples.map(\.name))
        require(
            previousNames.isSubset(of: currentNames),
            "all previous literary names must remain available"
        )

        let unreachableReferences = LiteraryColorCatalog.referenceSamples.filter {
            LiteraryColorCatalog.name(hex: $0.hex) != $0.name
        }
        require(
            unreachableReferences.isEmpty,
            "every reference swatch must map back to itself"
        )

        var coverage: [String: Int] = [:]
        let levels = stride(from: 0, through: 248, by: 8).map { $0 } + [255]
        for red in levels {
            for green in levels {
                for blue in levels {
                    let hex = UInt32(red << 16 | green << 8 | blue)
                    coverage[LiteraryColorCatalog.name(hex: hex), default: 0] += 1
                }
            }
        }

        require(
            coverage.count == LiteraryColorCatalog.count,
            "all names must occur in the sampled RGB gamut"
        )
        let sampleCount = levels.count * levels.count * levels.count
        let largest = coverage.max { $0.value < $1.value }!
        let largestShare = Double(largest.value) / Double(sampleCount)
        require(
            largestShare < 0.08,
            "no name should consume 8% or more of the sampled RGB gamut"
        )

        print("PASS catalog=\(LiteraryColorCatalog.count)")
        print("PASS #313541=\(LiteraryColorCatalog.name(hex: 0x313541))")
        print("PASS #605455=\(LiteraryColorCatalog.name(hex: 0x605455))")
        print("PASS gridSamples=\(sampleCount) coveredNames=\(coverage.count)")
        print(String(
            format: "PASS largest=%@ %.2f%%",
            largest.key,
            largestShare * 100
        ))
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
