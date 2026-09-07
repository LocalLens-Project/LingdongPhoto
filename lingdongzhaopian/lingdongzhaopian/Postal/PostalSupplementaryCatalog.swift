import Foundation




enum PostalSupplementaryCatalog {
    enum Region: String, Hashable { case hongKong = "HK", macao = "MO", taiwan = "TW" }
    struct Match {
        let region: Region
        var cityName: String? = nil
        var excluded = false
    }

    static let taiwanCities = ["台北市", "新北市", "桃园市", "台中市", "台南市", "高雄市", "基隆市", "新竹市", "嘉义市"]
    static var groups: [PostalProvinceCatalog.Province] {
        [
            .init(id: "hk", title: "香港特别行政区", names: ["香港特别行政区"]),
            .init(id: "mo", title: "澳门特别行政区", names: ["澳门特别行政区"]),
            .init(id: "tw", title: "台湾地区", names: taiwanCities)
        ]
    }

    private static func normalized(_ value: String) -> String {
        let text = value.precomposedStringWithCompatibilityMapping
        let simplified = text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text
        return simplified.replacingOccurrences(of: "臺", with: "台")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { !$0.isWhitespace && $0 != "." && $0 != "-" }
    }

    private static let names: [String: Match] = {
        var result: [String: Match] = [:]
        func add(_ aliases: [String], _ match: Match) {
            for name in aliases { result[normalized(name)] = match }
        }
        add(["香港", "香港特别行政区", "Hong Kong", "Hong Kong SAR"],
            Match(region: .hongKong, cityName: "香港特别行政区"))
        add(["澳门", "澳门特别行政区", "Macao", "Macau", "Macao SAR", "Macau SAR"],
            Match(region: .macao, cityName: "澳门特别行政区"))
        add(["台湾", "台湾省", "台湾地区", "Taiwan"], Match(region: .taiwan))
        let english = ["Taipei", "New Taipei", "Taoyuan", "Taichung", "Tainan", "Kaohsiung", "Keelung", "Hsinchu", "Chiayi"]
        for (city, englishName) in zip(taiwanCities, english) {
            let match = Match(region: .taiwan, cityName: city)
            add([city, englishName + " City"], match)

            let shortMatch = ["新竹市", "嘉义市"].contains(city) ? Match(region: .taiwan) : match
            add([String(city.dropLast()), englishName], shortMatch)
        }
        let counties = ["新竹县", "苗栗县", "彰化县", "南投县", "云林县", "嘉义县", "屏东县", "宜兰县", "花莲县", "台东县", "澎湖县", "金门县", "连江县"]
        let englishCounties = ["Hsinchu", "Miaoli", "Changhua", "Nantou", "Yunlin", "Chiayi", "Pingtung", "Yilan", "Hualien", "Taitung", "Penghu", "Kinmen", "Lienchiang"]
        for (county, englishName) in zip(counties, englishCounties) {
            add([county, englishName + " County"], Match(region: .taiwan, excluded: true))
        }

        let countyCities = ["竹北市", "苗栗市", "头份市", "彰化市", "员林市", "南投市", "斗六市", "太保市", "朴子市", "屏东市", "宜兰市", "花莲市", "台东市", "马公市"]
        let englishCountyCities = ["Zhubei", "Miaoli", "Toufen", "Changhua", "Yuanlin", "Nantou", "Douliu", "Taibao", "Puzi", "Pingtung", "Yilan", "Hualien", "Taitung", "Magong"]
        for (city, englishName) in zip(countyCities, englishCountyCities) {
            add([city, String(city.dropLast()), englishName, englishName + " City"], Match(region: .taiwan, excluded: true))
        }
        return result
    }()

    static func match(_ name: String) -> Match? { names[normalized(name)] }


    static func resolve(_ fields: PostalGeocodingFields, hasMainlandConflict: Bool) throws -> PostalCity? {
        let values = [fields.administrativeArea, fields.postalState, fields.locality,
                      fields.subAdministrativeArea, fields.postalCity, fields.postalSubAdministrativeArea].compactMap { $0 }
        let matches = values.compactMap { match($0) }
        let iso = fields.isoRegionCode?.uppercased()
        var regions = Set(matches.map(\.region))
        if let iso, let region = Region(rawValue: iso) { regions.insert(region) }
        guard !regions.isEmpty else { return nil }
        if hasMainlandConflict {
            let explicitRegion = iso.flatMap { Region(rawValue: $0) } != nil
                || matches.contains { $0.cityName != nil }
                || [fields.administrativeArea, fields.postalState].compactMap { $0 }
                    .contains { match($0).map { !$0.excluded } == true }

            if !explicitRegion { return nil }
        }
        guard regions.count == 1, !hasMainlandConflict, let region = regions.first else {
            throw PostalError.conflictingCity
        }
        if let iso, !iso.isEmpty, iso != "CN", iso != region.rawValue { throw PostalError.conflictingCity }
        switch region {
        case .hongKong: return PostalCity(name: "香港特别行政区")
        case .macao: return PostalCity(name: "澳门特别行政区")
        case .taiwan:
            let cities = Set(matches.compactMap(\.cityName))
            guard cities.count <= 1 else { throw PostalError.conflictingCity }
            if matches.contains(where: \.excluded) {
                throw cities.isEmpty ? PostalError.cityNotCollected : PostalError.conflictingCity
            }
            guard let city = cities.first else { throw PostalError.unresolvedCity }
            return PostalCity(name: city)
        }
    }
}
