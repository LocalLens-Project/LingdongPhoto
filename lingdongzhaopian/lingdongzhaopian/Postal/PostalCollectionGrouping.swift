import Foundation

enum PostalCollectionLanguage {
    static var usesProvinceLayout: Bool {
        usesProvinceLayout(for: Locale.preferredLanguages.first ?? "en")
    }
    static func usesProvinceLayout(for identifier: String) -> Bool {
        let language = Locale(identifier: identifier).language
        return language.languageCode?.identifier == "zh" && language.script?.identifier == "Hans"
    }
}


enum PostalCollectionGrouping {
    struct Entry: Identifiable {
        let id: String
        let slot: PostalCitySlot
        let unlockedAt: Date?
        var isUnlocked: Bool { unlockedAt != nil }
    }
    struct Group: Identifiable {
        let id: String
        let title: String
        let entries: [Entry]
        var unlockedCount: Int { entries.filter(\.isUnlocked).count }
    }

    static func groups(slots: [PostalCitySlot], stamps: [PostalStamp]) -> [Group] {
        var saved: [String: PostalCitySlot] = [:]
        for slot in slots where saved[slot.id] == nil { saved[slot.id] = slot }
        var earliest: [String: Date] = [:]
        for stamp in stamps {
            guard let city = stamp.city else { continue }
            earliest[city.id] = min(earliest[city.id] ?? stamp.addedAt, stamp.addedAt)
        }
        func entry(id: String, slot: PostalCitySlot) -> Entry {
            Entry(id: id, slot: slot, unlockedAt: earliest[id].map { slot.firstUnlockedAt ?? $0 })
        }

        func ordered(_ entries: [Entry]) -> [Entry] {
            entries.enumerated().sorted { lhs, rhs in
                switch (lhs.element.unlockedAt, rhs.element.unlockedAt) {
                case let (a?, b?) where a != b: return a < b
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.offset < rhs.offset
                }
            }.map(\.element)
        }
        var known = Set<String>()
        var groups = PostalProvinceCatalog.provinces.map { province in
            let entries = province.cities.map { city in
                known.insert(city.id)
                let slot = saved[city.id] ?? PostalCitySlot(city: city.city, tint: .init(), discoveredAt: .distantPast)
                return entry(id: city.id, slot: slot)
            }
            return Group(id: province.id, title: province.title, entries: ordered(entries))
        }

        let other = slots.filter { !known.contains($0.id) }.map { entry(id: $0.id, slot: $0) }
        if !other.isEmpty { groups.append(Group(id: "other", title: "其他足迹".appLocalized, entries: ordered(other))) }
        return groups
    }
}
