import SwiftUI
import CoreLocation
import Photos
import ImageIO
internal import Contacts

struct PostalTint: Codable, Equatable {
    var red: Double = 0.28
    var green: Double = 0.53
    var blue: Double = 0.58
    var color: Color { Color(red: red, green: green, blue: blue) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
    func ink(in scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color(red: red * 0.35 + 0.65, green: green * 0.35 + 0.65, blue: blue * 0.35 + 0.65)
        }
        return Color(red: red * 0.45, green: green * 0.45, blue: blue * 0.45)
    }
    static func extract(_ image: UIImage) -> Self {
        guard let c = ColorRelationshipAnalyzer.extractPalette(from: image, count: 3).first else { return Self() }
        return Self(red: c.red, green: c.green, blue: c.blue)
    }
}

struct PostalCity: Codable, Identifiable, Equatable {
    let name: String
    var id: String { Self.normalize(name) }


    static func normalize(_ locality: String) -> String {
        var value = locality.precomposedStringWithCompatibilityMapping
            .components(separatedBy: "·").last ?? locality
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? value
        for suffix in ["特别行政区", "自治州", "地区", "市"] where value.hasSuffix(suffix) {
            value.removeLast(suffix.count); break
        }
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { !$0.isWhitespace }
    }

    static func resolve(_ metadata: PhotoMetadata) async throws -> Self {
        guard let latitude = metadata.latitude, let longitude = metadata.longitude,
              latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { throw PostalError.missingLocation }
        let geocoder = CLGeocoder()
        let places = try await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: latitude, longitude: longitude), preferredLocale: Locale(identifier: "zh_CN"))
        guard let place = places.first else { throw PostalError.unresolvedCity }
        return try PostalCityResolver.resolve(PostalGeocodingFields(
            administrativeArea: place.administrativeArea, locality: place.locality,
            subAdministrativeArea: place.subAdministrativeArea, subLocality: place.subLocality,
            postalCity: place.postalAddress?.city, postalSubLocality: place.postalAddress?.subLocality,
            postalSubAdministrativeArea: place.postalAddress?.subAdministrativeArea, postalState: place.postalAddress?.state,
            isoRegionCode: place.isoCountryCode))
    }
}

struct PostalStamp: Codable, Identifiable, Equatable {
    let id: UUID
    let format: StampFormat
    let addedAt: Date
    let captureDate: Date?
    var city: PostalCity?
    let tint: PostalTint

    var originalCity: PostalCity? = nil
    var fileName: String { id.uuidString + ".png" }
    var liveVideoFileName: String { id.uuidString + ".mov" }
}

struct PostalCitySlot: Codable, Identifiable, Equatable {
    let city: PostalCity
    let tint: PostalTint
    let discoveredAt: Date

    var firstUnlockedAt: Date? = nil
    var id: String { city.id }
}

@MainActor @Observable
final class PostalStore {
    static let shared = PostalStore()
    private struct Snapshot: Codable {
        var version = 3
        var stamps: [PostalStamp] = []
        var cities: [PostalCitySlot] = []
        var cityRepresentatives: [String: UUID] = [:]
    }
    private var snapshot = Snapshot()
    private let root: URL
    private let thumbnails = NSCache<NSString, UIImage>()
    private(set) var loadError: String?
    var stamps: [PostalStamp] { snapshot.stamps.sorted(by: Self.earlier) }
    var cities: [PostalCitySlot] { snapshot.cities.sorted { $0.discoveredAt < $1.discoveredAt } }
    var litCityCount: Int { cities.filter { representative(for: $0.city) != nil }.count }

    init(root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PostalVault", isDirectory: true)) {
        self.root = root
        thumbnails.totalCostLimit = 24 * 1024 * 1024
        let index = root.appendingPathComponent("snapshot.json")
        if FileManager.default.fileExists(atPath: index.path) {
            do {
                snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: index))
                guard (1...3).contains(snapshot.version) else { throw PostalError.damagedLibrary }
                if snapshot.version < 3 {

                    guard !PostalCityResolver.areas.isEmpty else { throw PostalError.damagedLibrary }
                    try commit(Self.groupedByPrefecture(snapshot))
                }
            } catch { loadError = PostalError.damagedLibrary.localizedDescription }
        }
    }

    func stamps(in city: PostalCity) -> [PostalStamp] {
        guard let city = PostalCityResolver.collectionCity(for: city) else { return [] }
        return stamps.filter { $0.city?.id == city.id }
    }
    func representative(for city: PostalCity) -> PostalStamp? {
        guard let city = PostalCityResolver.collectionCity(for: city) else { return nil }
        let candidates = stamps(in: city)
        if let id = snapshot.cityRepresentatives[city.id], let picked = candidates.first(where: { $0.id == id }) { return picked }
        return candidates.first
    }
    func fileURL(_ stamp: PostalStamp) -> URL { root.appendingPathComponent(stamp.fileName) }
    func liveVideoURL(for stamp: PostalStamp) -> URL? {
        let url = root.appendingPathComponent(stamp.liveVideoFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    func image(_ stamp: PostalStamp, fullSize: Bool = false) -> UIImage? {
        if fullSize { return UIImage(contentsOfFile: fileURL(stamp).path) }
        let key = stamp.id.uuidString as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(fileURL(stamp) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 900
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cg)
        thumbnails.setObject(image, forKey: key, cost: cg.width * cg.height * 4)
        return image
    }

    @discardableResult
    func add(image: UIImage, format: StampFormat, metadata: PhotoMetadata, city: PostalCity?,
             tint: PostalTint, targetCity: PostalCity? = nil, addedAt: Date = .now,
             liveVideoURL: URL? = nil) throws -> PostalStamp {
        let validLocation = metadata.latitude.map { $0.isFinite && (-90...90).contains($0) } == true
            && metadata.longitude.map { $0.isFinite && (-180...180).contains($0) } == true
        if city != nil && !validLocation { throw PostalError.missingLocation }
        let originalCity = city
        let city = city.flatMap { PostalCityResolver.collectionCity(for: $0) }
        let collectionTarget = targetCity.flatMap { PostalCityResolver.collectionCity(for: $0) }
        if let targetCity {
            guard validLocation else { throw PostalError.missingLocation }
            guard let collectionTarget else { throw PostalError.cityNotCollected }
            guard city != nil else { throw PostalError.unresolvedCity }
            guard city?.id == collectionTarget.id else { throw PostalError.wrongCity(targetCity.name) }
        }
        guard let data = image.pngData() else { throw PostalError.image }
        let stamp = PostalStamp(id: UUID(), format: format, addedAt: addedAt,
                                captureDate: metadata.captureDate, city: city, tint: tint,
                                originalCity: originalCity == city ? nil : originalCity)
        try ensureWritable()
        try data.write(to: fileURL(stamp), options: .atomic)
        let storedLiveURL = root.appendingPathComponent(stamp.liveVideoFileName)
        var hasLiveVideo = false
        if let liveVideoURL {
            hasLiveVideo = (try? FileManager.default.copyItem(at: liveVideoURL, to: storedLiveURL)) != nil
        }
        var next = snapshot
        next.stamps.append(stamp)
        if let city {
            if let index = next.cities.firstIndex(where: { $0.id == city.id }) {
                if next.cities[index].firstUnlockedAt == nil { next.cities[index].firstUnlockedAt = addedAt }
            } else {
                next.cities.append(PostalCitySlot(city: city, tint: tint, discoveredAt: addedAt, firstUnlockedAt: addedAt))
            }
        }
        if let collectionTarget { next.cityRepresentatives[collectionTarget.id] = stamp.id }
        do { try commit(next) }
        catch {
            try? FileManager.default.removeItem(at: fileURL(stamp))
            if hasLiveVideo { try? FileManager.default.removeItem(at: storedLiveURL) }
            throw error
        }
        return stamp
    }

    func choose(_ stamp: PostalStamp, for city: PostalCity) throws {
        guard let collectionCity = PostalCityResolver.collectionCity(for: city),
              let saved = snapshot.stamps.first(where: { $0.id == stamp.id }),
              saved.city?.id == collectionCity.id else {
            throw PostalError.wrongCity(city.name)
        }
        var next = snapshot; next.cityRepresentatives[collectionCity.id] = stamp.id
        try commit(next)
    }

    func delete(_ stamp: PostalStamp) throws {
        var next = snapshot
        next.stamps.removeAll { $0.id == stamp.id }
        next.cityRepresentatives = next.cityRepresentatives.filter { $0.value != stamp.id }
        try commit(next)
        thumbnails.removeObject(forKey: stamp.id.uuidString as NSString)

        try? FileManager.default.removeItem(at: fileURL(stamp))
        try? FileManager.default.removeItem(at: root.appendingPathComponent(stamp.liveVideoFileName))
    }

    func importTicketCities(_ tickets: [TicketStub]) throws {
        var next = snapshot
        for ticket in tickets.sorted(by: { $0.captureDate < $1.captureDate }) {
            guard let name = ticket.city, !PostalCity.normalize(name).isEmpty else { continue }
            let recordedCity = PostalCity(name: name.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces) ?? name)
            guard let city = PostalCityResolver.collectionCity(for: recordedCity) else { continue }
            guard !next.cities.contains(where: { $0.id == city.id }) else { continue }
            let c = ticket.palette.first
            let tint = PostalTint(red: Double(c?.red ?? 0.28), green: Double(c?.green ?? 0.53), blue: Double(c?.blue ?? 0.58))
            next.cities.append(PostalCitySlot(city: city, tint: tint, discoveredAt: ticket.captureDate))
        }
        if next.cities != snapshot.cities { try commit(next) }
    }

    private static func earlier(_ lhs: PostalStamp, _ rhs: PostalStamp) -> Bool {
        lhs.addedAt == rhs.addedAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.addedAt < rhs.addedAt
    }


    private static func groupedByPrefecture(_ previous: Snapshot) -> Snapshot {
        var next = previous
        next.version = 3
        next.stamps = previous.stamps.map { stamp in
            var result = stamp
            result.city = stamp.city.flatMap { PostalCityResolver.collectionCity(for: $0) }
            if result.city != stamp.city, result.originalCity == nil { result.originalCity = stamp.city }
            return result
        }

        var slots: [String: PostalCitySlot] = [:]

        let orderedSlots = previous.cities.sorted { lhs, rhs in
            let lhsNative = PostalCityResolver.collectionCity(for: lhs.city)?.id == lhs.id
            let rhsNative = PostalCityResolver.collectionCity(for: rhs.city)?.id == rhs.id
            if lhsNative != rhsNative { return lhsNative }
            return lhs.discoveredAt == rhs.discoveredAt ? lhs.id < rhs.id : lhs.discoveredAt < rhs.discoveredAt
        }
        for slot in orderedSlots {
            guard let city = PostalCityResolver.collectionCity(for: slot.city) else { continue }
            let existing = slots[city.id]
            slots[city.id] = PostalCitySlot(city: city, tint: existing?.tint ?? slot.tint,
                discoveredAt: min(existing?.discoveredAt ?? slot.discoveredAt, slot.discoveredAt),
                firstUnlockedAt: [existing?.firstUnlockedAt, slot.firstUnlockedAt].compactMap { $0 }.min())
        }
        for stamp in next.stamps.sorted(by: earlier) {
            guard let city = stamp.city else { continue }
            let existing = slots[city.id]
            slots[city.id] = PostalCitySlot(city: city, tint: existing?.tint ?? stamp.tint,
                discoveredAt: min(existing?.discoveredAt ?? stamp.addedAt, stamp.addedAt),
                firstUnlockedAt: min(existing?.firstUnlockedAt ?? stamp.addedAt, stamp.addedAt))
        }
        next.cities = slots.values.sorted { lhs, rhs in
            lhs.discoveredAt == rhs.discoveredAt ? lhs.id < rhs.id : lhs.discoveredAt < rhs.discoveredAt
        }


        var covers: [(cityID: String, isNative: Bool, stamp: PostalStamp)] = []
        for (key, stampID) in previous.cityRepresentatives {
            guard let original = previous.stamps.first(where: { $0.id == stampID }), original.city?.id == key,
                  let stamp = next.stamps.first(where: { $0.id == stampID }), let city = stamp.city else { continue }
            covers.append((city.id, key == city.id, stamp))
        }
        next.cityRepresentatives = [:]
        for cover in covers.sorted(by: { lhs, rhs in
            if lhs.isNative != rhs.isNative { return lhs.isNative }
            return earlier(lhs.stamp, rhs.stamp)
        }) where next.cityRepresentatives[cover.cityID] == nil {
            next.cityRepresentatives[cover.cityID] = cover.stamp.id
        }
        return next
    }
    private func ensureWritable() throws {
        guard loadError == nil else { throw PostalError.damagedLibrary }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    private func commit(_ next: Snapshot) throws {
        try ensureWritable()
        try JSONEncoder().encode(next).write(to: root.appendingPathComponent("snapshot.json"), options: .atomic)
        snapshot = next
    }
}

enum PostalPhotoWriter {
    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PostalError.libraryDenied }
        guard let data = image.pngData() else { throw PostalError.image }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = "public.png"
            request.addResource(with: .photo, data: data, options: options)
        }
    }
}
