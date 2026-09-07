import Foundation


struct PostalGeocodingFields {
    var administrativeArea: String?
    var locality: String?
    var subAdministrativeArea: String?
    var subLocality: String?
    var postalCity: String?
    var postalSubLocality: String?
    var postalSubAdministrativeArea: String?
    var postalState: String?

    var isoRegionCode: String?
}




enum PostalCityResolver {
    struct Area: Hashable {
        let code: String
        let name: String
        var provinceCode: String { String(code.prefix(2)) + "0000" }
        var isProvince: Bool { code.hasSuffix("0000") }
        var isCounty: Bool { !code.hasSuffix("00") }
        var isCity: Bool { name.hasSuffix("市") }
        var parentCode: String {
            if ["11", "12", "31", "50"].contains(String(code.prefix(2))) { return provinceCode }
            return String(code.prefix(4)) + "00"
        }
    }

    static let areas: [Area] = {
        guard let url = Bundle.main.url(forResource: "PostalAdministrativeNames", withExtension: "json"),
              let data = try? Data(contentsOf: url), let rows = try? JSONDecoder().decode([[String]].self, from: data) else { return [] }
        return rows.compactMap { row in
            guard row.count == 2, row[0].count == 6 else { return nil }
            return Area(code: row[0], name: row[1])
        }
    }()
    private static let byCode = Dictionary(uniqueKeysWithValues: areas.map { ($0.code, $0) })
    private static let byName: [String: [Area]] = {
        var index: [String: [Area]] = [:]
        for area in areas {
            index[normalized(area.name), default: []].append(area)

            if area.isCity { index[normalized(String(area.name.dropLast())), default: []].append(area) }
        }
        return index
    }()
    private static let provinceAliases: [String: String] = {
        var index: [String: String] = [:]
        for area in areas where area.isProvince {
            index[normalized(area.name)] = area.code
            for suffix in ["维吾尔自治区", "壮族自治区", "回族自治区", "自治区", "省", "市"] where area.name.hasSuffix(suffix) {
                index[normalized(String(area.name.dropLast(suffix.count)))] = area.code
                break
            }
        }
        return index
    }()
    private static func normalized(_ value: String) -> String {
        let text = value.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text
    }



    private static func collectionCity(for area: Area) -> PostalCity? {
        if area.isCounty {
            guard let parent = byCode[area.parentCode], parent.isCity, !parent.isCounty else { return nil }
            return PostalCity(name: parent.name)
        }
        return area.isCity ? PostalCity(name: area.name) : nil
    }



    static func collectionCity(for city: PostalCity) -> PostalCity? {
        let name = city.name.components(separatedBy: "·").last ?? city.name
        if let match = PostalSupplementaryCatalog.match(name) {

            return match.cityName.map { PostalCity(name: $0) }
        }
        let matches = byName[normalized(name)] ?? []
        guard !matches.isEmpty else { return city }
        let candidates = matches.compactMap { collectionCity(for: $0) }
        guard candidates.count == matches.count, Set(candidates.map(\.id)).count == 1 else { return nil }
        return candidates.first
    }

    static func resolve(_ fields: PostalGeocodingFields) throws -> PostalCity {
        guard !areas.isEmpty else { throw PostalError.unresolvedCity }
        let coarse = [fields.locality, fields.subAdministrativeArea, fields.postalCity, fields.postalSubAdministrativeArea].compactMap { $0 }
        let fine = [fields.subLocality, fields.postalSubLocality].compactMap { $0 }
        let stateFields = [fields.administrativeArea, fields.postalState].compactMap { $0 }.filter { !normalized($0).isEmpty }
        let hasMainlandConflict = (stateFields + coarse).contains { value in
            provinceAliases[normalized(value)] != nil
                || (byName[normalized(value)] ?? []).contains { !$0.isCounty || $0.isCity }
        }
        if let city = try PostalSupplementaryCatalog.resolve(fields, hasMainlandConflict: hasMainlandConflict) {
            return city
        }
        let provinceCodes = Set(stateFields.compactMap { provinceAliases[normalized($0)] })
        guard provinceCodes.count <= 1 else { throw PostalError.conflictingCity }
        let province = provinceCodes.first
        let rawMatches = (coarse + fine).flatMap { byName[normalized($0)] ?? [] }


        if province == nil && rawMatches.isEmpty {
            let legacy = [fields.locality, fields.subAdministrativeArea, fields.administrativeArea, fields.postalCity].compactMap { $0 }
            guard let name = legacy.map({ normalized($0) }).first(where: { $0.hasSuffix("市") && $0.count > 1 }) else {
                throw PostalError.unresolvedCity
            }
            return PostalCity(name: name)
        }
        if let province, rawMatches.contains(where: { $0.provinceCode != province }),
           (coarse + fine).contains(where: { value in
               let matches = byName[normalized(value)] ?? []
               return !matches.isEmpty && !matches.contains(where: { $0.provinceCode == province })
           }) { throw PostalError.conflictingCity }

        if !rawMatches.isEmpty, stateFields.contains(where: { provinceAliases[normalized($0)] == nil }) {
            throw PostalError.conflictingCity
        }
        let eligible = rawMatches.filter { province == nil || $0.provinceCode == province }
        let parentHints = Set(coarse.flatMap { byName[normalized($0)] ?? [] }.filter {
            !$0.isCounty && (!$0.isProvince || $0.isCity) && (province == nil || $0.provinceCode == province)
        })
        guard parentHints.count <= 1 else { throw PostalError.conflictingCity }
        let parentHint = parentHints.first
        let countyCandidates = Set(eligible.filter { $0.isCounty }.filter {
            parentHint == nil || $0.parentCode == parentHint?.code
        })
        if parentHint != nil, eligible.contains(where: { $0.isCounty }), countyCandidates.isEmpty {
            throw PostalError.conflictingCity
        }

        guard countyCandidates.count <= 1 else { throw PostalError.conflictingCity }
        if let county = countyCandidates.first {

            for value in coarse + fine {
                let matches = (byName[normalized(value)] ?? []).filter { $0.isCounty && (province == nil || $0.provinceCode == province) }
                if !matches.isEmpty && !matches.contains(county) { throw PostalError.conflictingCity }
            }
            guard let city = collectionCity(for: county) else { throw PostalError.cityNotCollected }
            return city
        }
        let municipality = province.flatMap { byCode[$0] }.flatMap { $0.isCity ? $0 : nil }
        guard let city = parentHint ?? municipality else { throw PostalError.unresolvedCity }
        guard city.isCity else { throw PostalError.cityNotCollected }

        return PostalCity(name: city.name)
    }
}
