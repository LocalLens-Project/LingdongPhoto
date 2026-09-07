import Foundation

enum SolarTerm: String, CaseIterable {
    case lichun = "立春"
    case yushui = "雨水"
    case jingzhe = "惊蛰"
    case chunfen = "春分"
    case qingming = "清明"
    case guyu = "谷雨"
    case lixia = "立夏"
    case xiaoman = "小满"
    case mangzhong = "芒种"
    case xiazhi = "夏至"
    case xiaoshu = "小暑"
    case dashu = "大暑"
    case liqiu = "立秋"
    case chushu = "处暑"
    case bailu = "白露"
    case qiufen = "秋分"
    case hanlu = "寒露"
    case shuangjiang = "霜降"
    case lidong = "立冬"
    case xiaoxue = "小雪"
    case daxue = "大雪"
    case dongzhi = "冬至"
    case xiaohan = "小寒"
    case dahan = "大寒"
}

extension SolarTerm {
    var localizedName: String {
        switch LexiconLanguage.current {
        case .simplified:
            rawValue
        case .traditional:
            TraditionalColorLexiconTranslations.traditionalSolarTerms[self] ?? rawValue
        case .english:
            TraditionalColorLexiconTranslations.englishSolarTerms[self] ?? rawValue
        }
    }
}

enum ColorRole: String {
    case qi = "起"
    case cheng = "承"
    case zhuan = "转"
    case he = "合"
}

struct TraditionalColorEntry {
    let name: String
    let term: SolarTerm
    let pentad: String
    let role: ColorRole
    let rgb: (Int, Int, Int)
    let cmyk: (Int, Int, Int, Int)
    let quote: String
    let author: String
    let source: String

    var displayText: String {
        let byline = [author, source].filter { !$0.isEmpty }.joined()
        if quote.isEmpty {
            return byline.isEmpty ? name : "\(name) 自\(byline)"
        }
        if byline.isEmpty {
            return "\(name) 『\(quote)』"
        }
        return "\(name) 自\(byline)『\(quote)』"
    }

    fileprivate var lab: OKLab {
        OKLab(
            red: Double(rgb.0) / 255,
            green: Double(rgb.1) / 255,
            blue: Double(rgb.2) / 255
        )
    }
}

enum LexiconLanguage {
    case simplified
    case traditional
    case english

    static var current: LexiconLanguage {

        let identifier = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if identifier.contains("hans") { return .simplified }
        if identifier.contains("hant") { return .traditional }
        if identifier.contains("-hk") || identifier.contains("_hk")
            || identifier.contains("-mo") || identifier.contains("_mo") { return .traditional }
        if identifier.hasPrefix("zh") { return .simplified }
        return .english
    }
}

extension TraditionalColorEntry {
    var localizedName: String {
        translated(name,
                   traditional: TraditionalColorLexiconTranslations.traditionalNames,
                   english: TraditionalColorLexiconTranslations.englishNames)
    }

    var localizedQuote: String {
        translated(quote,
                   traditional: TraditionalColorLexiconTranslations.traditionalQuotes,
                   english: TraditionalColorLexiconTranslations.englishQuotes)
    }

    var localizedAuthor: String {
        translated(author,
                   traditional: TraditionalColorLexiconTranslations.traditionalAuthors,
                   english: TraditionalColorLexiconTranslations.englishAuthors)
    }

    var localizedSource: String {
        translated(source,
                   traditional: TraditionalColorLexiconTranslations.traditionalSources,
                   english: TraditionalColorLexiconTranslations.englishSources)
    }

    var localizedTerm: String {
        switch LexiconLanguage.current {
        case .simplified:
            return term.rawValue
        case .traditional:
            return TraditionalColorLexiconTranslations.traditionalSolarTerms[term] ?? term.rawValue
        case .english:
            return TraditionalColorLexiconTranslations.englishSolarTerms[term] ?? term.rawValue
        }
    }

    var localizedRole: String {
        switch LexiconLanguage.current {
        case .simplified:
            return role.rawValue
        case .traditional:
            return TraditionalColorLexiconTranslations.traditionalRoles[role] ?? role.rawValue
        case .english:
            return TraditionalColorLexiconTranslations.englishRoles[role] ?? role.rawValue
        }
    }

    var localizedByline: String {
        [localizedAuthor, localizedSource].filter { !$0.isEmpty }.joined()
    }

    var localizedDisplayText: String {
        let byline = localizedByline
        if localizedQuote.isEmpty {
            return byline.isEmpty ? localizedName : "\(localizedName) 自\(byline)"
        }
        if byline.isEmpty {
            return "\(localizedName) 『\(localizedQuote)』"
        }
        return "\(localizedName) 自\(byline)『\(localizedQuote)』"
    }

    private func translated(_ source: String, traditional: [String], english: [String]) -> String {
        let index = TraditionalColorLexicon.entryIndexesByName[name]
        switch LexiconLanguage.current {
        case .simplified:
            return source
        case .traditional:
            if let index, traditional.indices.contains(index) { return traditional[index] }
            return source
        case .english:
            if let index, english.indices.contains(index) { return english[index] }
            return source
        }
    }
}

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

enum TraditionalColorLexicon {
    static let count = entries.count

    static let entryIndexesByName: [String: Int] = {
        var indexes = [String: Int]()
        for (index, entry) in entries.enumerated() where indexes[entry.name] == nil {
            indexes[entry.name] = index
        }
        return indexes
    }()

    static func entry(named name: String) -> TraditionalColorEntry? {
        entries.first { $0.name == name }
    }

    static func entries(for term: SolarTerm) -> [TraditionalColorEntry] {
        entries.filter { $0.term == term }
    }

    static func nearest(red: Double, green: Double, blue: Double) -> TraditionalColorEntry {
        let target = OKLab(
            red: min(max(red, 0), 1),
            green: min(max(green, 0), 1),
            blue: min(max(blue, 0), 1)
        )
        return entries.min {
            target.distanceSquared(to: $0.lab)
                < target.distanceSquared(to: $1.lab)
        } ?? entries[0]
    }

    static func uniqueMatches(
        colors: [RGBColor],
        percentages: [Double] = []
    ) -> [TraditionalColorEntry] {
        guard !colors.isEmpty, !entries.isEmpty else { return [] }

        let matchCount = min(colors.count, entries.count)
        let targets = Array(colors.prefix(matchCount)).map {
            OKLab(
                red: min(max(Double($0.red), 0), 1),
                green: min(max(Double($0.green), 0), 1),
                blue: min(max(Double($0.blue), 0), 1)
            )
        }
        let candidateLabs = entries.map(\.lab)
        let maximumPercentage = percentages.prefix(matchCount).max() ?? 0

        let costs: [[Double]] = targets.enumerated().map { colorIndex, target in
            let normalizedShare: Double
            if maximumPercentage > 0, percentages.indices.contains(colorIndex) {
                normalizedShare = max(percentages[colorIndex], 0) / maximumPercentage
            } else {
                normalizedShare = 1 - Double(colorIndex) / Double(max(matchCount, 1))
            }

            let salienceWeight = 0.85 + 0.15 * sqrt(max(normalizedShare, 0))
            return candidateLabs.enumerated().map { candidateIndex, candidate in
                target.distanceSquared(to: candidate) * salienceWeight
                    + Double(candidateIndex) * 1e-12
            }
        }

        let assignment = minimumCostAssignment(costs)
        guard assignment.count == matchCount,
              assignment.allSatisfy({ entries.indices.contains($0) }),
              Set(assignment).count == matchCount else {
            return colors.map {
                nearest(red: Double($0.red), green: Double($0.green), blue: Double($0.blue))
            }
        }
        var result = assignment.map { entries[$0] }

        if colors.count > matchCount {
            result.append(contentsOf: colors.dropFirst(matchCount).map {
                nearest(red: Double($0.red), green: Double($0.green), blue: Double($0.blue))
            })
        }
        return result
    }

    private static func minimumCostAssignment(_ costs: [[Double]]) -> [Int] {
        let rowCount = costs.count
        guard rowCount > 0 else { return [] }
        let columnCount = costs[0].count
        guard columnCount >= rowCount,
              costs.allSatisfy({ $0.count == columnCount }) else { return [] }

        var rowPotential = [Double](repeating: 0, count: rowCount + 1)
        var columnPotential = [Double](repeating: 0, count: columnCount + 1)
        var matchedRow = [Int](repeating: 0, count: columnCount + 1)
        var previousColumn = [Int](repeating: 0, count: columnCount + 1)

        for row in 1...rowCount {
            matchedRow[0] = row
            var currentColumn = 0
            var minimumSlack = [Double](repeating: .infinity, count: columnCount + 1)
            var usedColumn = [Bool](repeating: false, count: columnCount + 1)

            repeat {
                usedColumn[currentColumn] = true
                let currentRow = matchedRow[currentColumn]
                var delta = Double.infinity
                var nextColumn = 0

                for column in 1...columnCount where !usedColumn[column] {
                    let reducedCost = costs[currentRow - 1][column - 1]
                        - rowPotential[currentRow]
                        - columnPotential[column]
                    if reducedCost < minimumSlack[column] {
                        minimumSlack[column] = reducedCost
                        previousColumn[column] = currentColumn
                    }
                    if minimumSlack[column] < delta {
                        delta = minimumSlack[column]
                        nextColumn = column
                    }
                }

                for column in 0...columnCount {
                    if usedColumn[column] {
                        rowPotential[matchedRow[column]] += delta
                        columnPotential[column] -= delta
                    } else if column > 0 {
                        minimumSlack[column] -= delta
                    }
                }
                currentColumn = nextColumn
            } while matchedRow[currentColumn] != 0

            repeat {
                let nextColumn = previousColumn[currentColumn]
                matchedRow[currentColumn] = matchedRow[nextColumn]
                currentColumn = nextColumn
            } while currentColumn != 0
        }

        var assignment = [Int](repeating: -1, count: rowCount)
        for column in 1...columnCount where matchedRow[column] != 0 {
            assignment[matchedRow[column] - 1] = column - 1
        }
        return assignment
    }

    static func nearest(hex: UInt32) -> TraditionalColorEntry {
        nearest(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static var entries: [TraditionalColorEntry] {
        TraditionalColorLexiconData.entries
    }
}
