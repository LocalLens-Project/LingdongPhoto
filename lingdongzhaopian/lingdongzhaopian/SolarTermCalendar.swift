import Foundation

struct SolarTermOccurrence: Identifiable, Equatable, Sendable {
    let term: SolarTerm
    let instant: Date
    let nextInstant: Date
    let gregorianYear: Int
    let seasonYear: Int

    var id: String { "\(gregorianYear).\(term.rawValue)" }
}

enum SolarTermCalendar {
    static let dataVersion = "astronomical-1"
    static let supportedYears = 1901...2099
    static let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!

    static let chronologicalTerms: [SolarTerm] = [
        .xiaohan, .dahan, .lichun, .yushui, .jingzhe, .chunfen,
        .qingming, .guyu, .lixia, .xiaoman, .mangzhong, .xiazhi,
        .xiaoshu, .dashu, .liqiu, .chushu, .bailu, .qiufen,
        .hanlu, .shuangjiang, .lidong, .xiaoxue, .daxue, .dongzhi,
    ]

    static let seasonOrder: [SolarTerm] = [
        .lichun, .yushui, .jingzhe, .chunfen, .qingming, .guyu,
        .lixia, .xiaoman, .mangzhong, .xiazhi, .xiaoshu, .dashu,
        .liqiu, .chushu, .bailu, .qiufen, .hanlu, .shuangjiang,
        .lidong, .xiaoxue, .daxue, .dongzhi, .xiaohan, .dahan,
    ]

    private struct Definition {
        let term: SolarTerm
        let longitude: Double
        let month: Int
        let approximateDay: Int
    }

    private static let definitions: [Definition] = [
        .init(term: .xiaohan, longitude: 285, month: 1, approximateDay: 5),
        .init(term: .dahan, longitude: 300, month: 1, approximateDay: 20),
        .init(term: .lichun, longitude: 315, month: 2, approximateDay: 4),
        .init(term: .yushui, longitude: 330, month: 2, approximateDay: 19),
        .init(term: .jingzhe, longitude: 345, month: 3, approximateDay: 5),
        .init(term: .chunfen, longitude: 0, month: 3, approximateDay: 20),
        .init(term: .qingming, longitude: 15, month: 4, approximateDay: 5),
        .init(term: .guyu, longitude: 30, month: 4, approximateDay: 20),
        .init(term: .lixia, longitude: 45, month: 5, approximateDay: 5),
        .init(term: .xiaoman, longitude: 60, month: 5, approximateDay: 21),
        .init(term: .mangzhong, longitude: 75, month: 6, approximateDay: 5),
        .init(term: .xiazhi, longitude: 90, month: 6, approximateDay: 21),
        .init(term: .xiaoshu, longitude: 105, month: 7, approximateDay: 7),
        .init(term: .dashu, longitude: 120, month: 7, approximateDay: 23),
        .init(term: .liqiu, longitude: 135, month: 8, approximateDay: 7),
        .init(term: .chushu, longitude: 150, month: 8, approximateDay: 23),
        .init(term: .bailu, longitude: 165, month: 9, approximateDay: 7),
        .init(term: .qiufen, longitude: 180, month: 9, approximateDay: 23),
        .init(term: .hanlu, longitude: 195, month: 10, approximateDay: 8),
        .init(term: .shuangjiang, longitude: 210, month: 10, approximateDay: 23),
        .init(term: .lidong, longitude: 225, month: 11, approximateDay: 7),
        .init(term: .xiaoxue, longitude: 240, month: 11, approximateDay: 22),
        .init(term: .daxue, longitude: 255, month: 12, approximateDay: 7),
        .init(term: .dongzhi, longitude: 270, month: 12, approximateDay: 21),
    ]

    static func occurrences(inGregorianYear year: Int) -> [SolarTermOccurrence] {
        guard (supportedYears.lowerBound - 1...supportedYears.upperBound + 1).contains(year) else {
            return []
        }
        let instants = definitions.map { definition in
            (definition.term, crossing(
                longitude: definition.longitude,
                year: year,
                month: definition.month,
                day: definition.approximateDay
            ))
        }
        return instants.enumerated().map { index, value in
            let next: Date
            if instants.indices.contains(index + 1) {
                next = instants[index + 1].1
            } else {
                next = crossing(longitude: 285, year: year + 1, month: 1, day: 5)
            }
            return SolarTermOccurrence(
                term: value.0,
                instant: value.1,
                nextInstant: next,
                gregorianYear: year,
                seasonYear: value.0 == .xiaohan || value.0 == .dahan ? year - 1 : year
            )
        }
    }

    static func cycle(forSeasonYear year: Int) -> [SolarTermOccurrence] {
        let current = occurrences(inGregorianYear: year)
        let following = occurrences(inGregorianYear: year + 1)
        let requested = current.filter { $0.term != .xiaohan && $0.term != .dahan }
            + following.filter { $0.term == .xiaohan || $0.term == .dahan }
        return seasonOrder.compactMap { term in requested.first { $0.term == term } }
    }

    static func occurrence(containing date: Date) -> SolarTermOccurrence? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chinaTimeZone
        let year = calendar.component(.year, from: date)
        guard supportedYears.contains(year) else { return nil }
        let values = (occurrences(inGregorianYear: year - 1)
            + occurrences(inGregorianYear: year)
            + occurrences(inGregorianYear: year + 1))
            .sorted { $0.instant < $1.instant }
        guard let index = values.lastIndex(where: { $0.instant <= date }),
              values.indices.contains(index + 1) else { return nil }
        let value = values[index]
        return SolarTermOccurrence(
            term: value.term,
            instant: value.instant,
            nextInstant: values[index + 1].instant,
            gregorianYear: value.gregorianYear,
            seasonYear: value.seasonYear
        )
    }

    static func seasonYear(containing date: Date) -> Int? {
        occurrence(containing: date)?.seasonYear
    }

    static func occurrence(term: SolarTerm, seasonYear: Int) -> SolarTermOccurrence? {
        cycle(forSeasonYear: seasonYear).first { $0.term == term }
    }

    static func isNearBoundary(_ date: Date, occurrence: SolarTermOccurrence, days: Double = 3) -> Bool {
        abs(date.timeIntervalSince(occurrence.instant)) <= days * 86_400
    }

    static func dateRangeText(_ occurrence: SolarTermOccurrence) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = chinaTimeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let end = occurrence.nextInstant.addingTimeInterval(-1)
        return "\(formatter.string(from: occurrence.instant))—\(formatter.string(from: end))"
    }

    static func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = chinaTimeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Apparent solar longitude follows the standard low-order Meeus/NOAA
    // expression. Bisection within a ten-day window makes every term resolve
    // to one stable UTC instant while keeping the feature entirely offline.
    private static func crossing(longitude target: Double, year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let center = calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: 12
        ))!
        var lower = center.addingTimeInterval(-5 * 86_400)
        var upper = center.addingTimeInterval(5 * 86_400)
        for _ in 0..<56 {
            let middle = lower.addingTimeInterval(upper.timeIntervalSince(lower) / 2)
            if signedAngle(apparentSolarLongitude(at: middle) - target) < 0 {
                lower = middle
            } else {
                upper = middle
            }
        }
        return lower.addingTimeInterval(upper.timeIntervalSince(lower) / 2)
    }

    private static func apparentSolarLongitude(at date: Date) -> Double {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let centuries = (julianDay - 2_451_545) / 36_525
        let meanLongitude = normalized(
            280.46646 + centuries * (36_000.76983 + centuries * 0.0003032)
        )
        let meanAnomaly = normalized(
            357.52911 + centuries * (35_999.05029 - 0.0001537 * centuries)
        )
        let radians = meanAnomaly * .pi / 180
        let center = sin(radians) * (1.914602 - centuries * (0.004817 + 0.000014 * centuries))
            + sin(2 * radians) * (0.019993 - 0.000101 * centuries)
            + sin(3 * radians) * 0.000289
        let omega = (125.04 - 1934.136 * centuries) * .pi / 180
        return normalized(meanLongitude + center - 0.00569 - 0.00478 * sin(omega))
    }

    private static func normalized(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result < 0 ? result + 360 : result
    }

    private static func signedAngle(_ value: Double) -> Double {
        var result = normalized(value)
        if result >= 180 { result -= 360 }
        return result
    }
}

extension SolarTerm {
    var seasonIndex: Int {
        max(0, (SolarTermCalendar.seasonOrder.firstIndex(of: self) ?? 0) / 6)
    }

    var seasonName: String {
        ["春", "夏", "秋", "冬"][seasonIndex].appLocalized
    }
}
