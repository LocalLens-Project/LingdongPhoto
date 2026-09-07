import SwiftUI
import UIKit
import CoreLocation
internal import Contacts
import MapKit

private struct StoredPaletteEntry: Codable {
    var red: Double
    var green: Double
    var blue: Double
}

private struct StoredTicket: Codable {
    var id: UUID
    var ticketID: String
    var fingerprint: String
    var headerTitle: String?
    var title: String
    var subtitle: String?
    var message: String
    var city: String?
    var place: String?
    var device: String?
    var captureDate: Date
    var captureTimeText: String
    var layout: String
    var theme: String
    var palette: [StoredPaletteEntry]
    var isSealed: Bool
    var isCapsule: Bool
    var artworkFileName: String?

    var codeStyle: String?

    var qrPayload: String?
    var barcodeValue: String?

    var isArchivedWork: Bool?
    var physicalTicketType: String?
    var isPhysicalImport: Bool?
    var ticketColorName: String?
    var ticketEdition: String?

    var usesSupporterLayout: Bool?

    var deliverAfter: Date?
}

private struct StoredCollection: Codable {
    var id: UUID
    var name: String
    var icon: String
    var tickets: [StoredTicket]
}

private struct StoredSnapshot: Codable {
    var cityTickets: [StoredTicket]
    var customCollections: [StoredCollection]
    var cityRepresentatives: [String: UUID]
}

enum PiaogenceVault {

    struct Snapshot {
        var cityTickets: [TicketStub] = []
        var customCollections: [TicketCollection] = []
        var cityRepresentatives: [String: UUID] = [:]
    }

    private static var rootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PiaogenceVault", isDirectory: true)
    }
    private static var indexURL: URL { rootURL.appendingPathComponent("snapshot.json") }
    private static var artworkDirectory: URL {
        rootURL.appendingPathComponent("artworks", isDirectory: true)
    }

    static func load() -> Snapshot {
        var snapshot = Snapshot()
        guard let data = try? Data(contentsOf: indexURL),
              let stored = decode(data) else { return snapshot }
        snapshot.cityTickets = stored.cityTickets.map { hydrate($0) }
        snapshot.customCollections = stored.customCollections.map { item in
            TicketCollection(
                id: item.id,
                name: item.name,
                icon: item.icon,
                tickets: item.tickets.map { hydrate($0) })
        }
        snapshot.cityRepresentatives = stored.cityRepresentatives
        return snapshot
    }

    static func save(cityTickets: [TicketStub],
                     customCollections: [TicketCollection],
                     cityRepresentatives: [String: UUID]) {
        try? FileManager.default.createDirectory(
            at: artworkDirectory, withIntermediateDirectories: true)
        let stored = StoredSnapshot(
            cityTickets: cityTickets.map { dehydrate($0) },
            customCollections: customCollections.map { collection in
                StoredCollection(
                    id: collection.id,
                    name: collection.name,
                    icon: collection.icon,
                    tickets: collection.tickets.map { dehydrate($0) })
            },
            cityRepresentatives: cityRepresentatives)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(stored) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private static func decode(_ data: Data) -> StoredSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StoredSnapshot.self, from: data)
    }

    private static func hydrate(_ stored: StoredTicket) -> TicketStub {
        var ticket = TicketStub(
            id: stored.id,
            ticketID: stored.ticketID,
            fingerprint: stored.fingerprint,
            headerTitle: stored.headerTitle,
            title: stored.title,
            subtitle: stored.subtitle,
            message: stored.message,
            city: stored.city,
            place: stored.place,
            device: stored.device,
            captureDate: stored.captureDate,
            captureTimeText: stored.captureTimeText,
            layout: PiaogenceLayoutStyle(rawValue: stored.layout) ?? .classic,
            theme: SceneTheme(rawValue: stored.theme) ?? .sunset,
            palette: stored.palette.map {
                PiaogenceRGBColor(
                    red: CGFloat($0.red), green: CGFloat($0.green), blue: CGFloat($0.blue))
            },
            isSealed: stored.isSealed,
            isCapsule: stored.isCapsule)
        if let fileName = stored.artworkFileName {
            ticket.artworkImageData = try? Data(contentsOf:
                artworkDirectory.appendingPathComponent(fileName))
        }
        ticket.codeStyle = stored.codeStyle.flatMap { TicketCodeStyle(rawValue: $0) }
        ticket.qrPayload = stored.qrPayload
        ticket.barcodeValue = stored.barcodeValue
        ticket.isArchivedWork = stored.isArchivedWork ?? false
        ticket.physicalTicketType = stored.physicalTicketType.flatMap(PhysicalTicketType.init(rawValue:))
        ticket.isPhysicalImport = stored.isPhysicalImport ?? false
        ticket.ticketColorName = stored.ticketColorName
        ticket.ticketEdition = stored.ticketEdition.flatMap(TicketEdition.init(rawValue:))
            ?? ((stored.usesSupporterLayout ?? false) ? .collector : .standard)
        return ticket
    }

    private static func dehydrate(_ ticket: TicketStub) -> StoredTicket {
        var artworkFileName: String?
        if let data = ticket.artworkImageData {
            let fileName = "\(ticket.id.uuidString).jpg"
            if (try? data.write(to: artworkDirectory.appendingPathComponent(fileName),
                                 options: .atomic)) != nil {
                artworkFileName = fileName
            }
        }
        return StoredTicket(
            id: ticket.id,
            ticketID: ticket.ticketID,
            fingerprint: ticket.fingerprint,
            headerTitle: ticket.headerTitle,
            title: ticket.title,
            subtitle: ticket.subtitle,
            message: ticket.message,
            city: ticket.city,
            place: ticket.place,
            device: ticket.device,
            captureDate: ticket.captureDate,
            captureTimeText: ticket.captureTimeText,
            layout: ticket.layout.rawValue,
            theme: ticket.theme.rawValue,
            palette: ticket.palette.map {
                StoredPaletteEntry(red: $0.red, green: $0.green, blue: $0.blue)
            },
            isSealed: ticket.isSealed,
            isCapsule: ticket.isCapsule,
            artworkFileName: artworkFileName,
            codeStyle: ticket.codeStyle?.rawValue,
            qrPayload: ticket.qrPayload,
            barcodeValue: ticket.barcodeValue,
            isArchivedWork: ticket.isArchivedWork ? true : nil,
            physicalTicketType: ticket.physicalTicketType?.rawValue,
            isPhysicalImport: ticket.isPhysicalImport ? true : nil,
            ticketColorName: ticket.ticketColorName,
            ticketEdition: ticket.ticketEdition.rawValue,
            usesSupporterLayout: ticket.ticketEdition == .collector ? true : nil,
            deliverAfter: nil)
    }
}

private actor PiaogenceCityAnchorCache {
    static let shared = PiaogenceCityAnchorCache()

    private struct Anchor {
        let latitude: Double
        let longitude: Double
        let province: String
        let label: String
    }

    private var anchors: [Anchor] = []

    func record(latitude: Double, longitude: Double, province: String, label: String) {
        guard !anchors.contains(where: {
            $0.label == label
                && abs($0.latitude - latitude) < 0.000_1
                && abs($0.longitude - longitude) < 0.000_1
        }) else { return }
        anchors.append(Anchor(
            latitude: latitude,
            longitude: longitude,
            province: province,
            label: label
        ))
    }

    func nearestLabel(
        latitude: Double,
        longitude: Double,
        province: String,
        maximumDistance: CLLocationDistance = 35_000
    ) -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return anchors
            .filter { $0.province == province }
            .map { anchor in
                (
                    anchor.label,
                    location.distance(from: CLLocation(
                        latitude: anchor.latitude,
                        longitude: anchor.longitude
                    ))
                )
            }
            .filter { $0.1 <= maximumDistance }
            .min(by: { $0.1 < $1.1 })?
            .0
    }
}

enum PiaogenceCollector {

    static func collect(payload: TicketPayload,
                        metadata: PhotoMetadata,
                        layout: TicketLayoutStyle,
                        codeStyle: TicketCodeStyle,
                        deviceSealEnabled: Bool,
                        photoData: Data?) async {
        let captureDate = metadata.captureDate ?? .now
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy.MM.dd HH:mm"

        let city = await cityName(for: metadata)

        let qrPayload = await Task.detached(priority: .userInitiated) {
            () -> String? in
            let signer: TicketEnvelopeSigning? = deviceSealEnabled
                ? TicketDeviceSealService.shared : nil
            return try? TicketEnvelope.invocationURL(
                for: payload,
                baseURLString: TicketEnvelope.configuredBaseURLString,
                signer: signer
            ).absoluteString
        }.value
        let barcodeValue = TicketEnvelope.barcodeValue(for: payload)

        let stub = TicketStub(
            ticketID: payload.ticketID,
            fingerprint: payload.fingerprint,
            headerTitle: payload.headerTitle,
            title: payload.title,
            subtitle: payload.subtitle,
            message: payload.message ?? "这一张票根替我记住此刻。".appLocalized,
            city: city,
            place: payload.place,
            device: payload.device,
            captureDate: captureDate,
            captureTimeText: payload.captureTime ?? timeFormatter.string(from: captureDate),
            layout: layout == .vertical ? .vertical : .classic,
            theme: .sunset,
            palette: payload.palette.compactMap { PiaogenceRGBColor(hex: $0.hex) },
            isSealed: payload.sealedAt != nil,
            isCapsule: false,
            artworkImageData: scaledPhoto(from: photoData),
            codeStyle: codeStyle,
            qrPayload: qrPayload,
            barcodeValue: barcodeValue)
        await MainActor.run {
            TicketStore.shared.addTicket(stub)
        }
    }

    private static func cityName(for metadata: PhotoMetadata) async -> String? {
        if let latitude = metadata.latitude, let longitude = metadata.longitude {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let chinesePlacemark = try? await CLGeocoder().reverseGeocodeLocation(
                location, preferredLocale: Locale(identifier: "zh_CN")
            ).first

            if let chinesePlacemark {
                let countryCode = chinesePlacemark.isoCountryCode?.uppercased()
                let chineseRegionCodes: Set<String> = ["CN", "HK", "MO", "TW"]
                if countryCode.map(chineseRegionCodes.contains) == true {
                    let province = normalizedProvince(chinesePlacemark.administrativeArea)
                    if let city = preferredChineseCity(from: chinesePlacemark) {
                        let label = domesticRegionLabel(province: province, city: city)
                        if let province {
                            await PiaogenceCityAnchorCache.shared.record(
                                latitude: latitude,
                                longitude: longitude,
                                province: province,
                                label: label
                            )
                        }
                        return label
                    }

                    if let province,
                       let cached = await PiaogenceCityAnchorCache.shared.nearestLabel(
                           latitude: latitude,
                           longitude: longitude,
                           province: province
                       ) {
                        return cached
                    }

                    if let province,
                       let city = await nearbyChineseCity(
                           from: location,
                           province: province
                       ) {
                        let label = domesticRegionLabel(province: province, city: city)
                        await PiaogenceCityAnchorCache.shared.record(
                            latitude: latitude,
                            longitude: longitude,
                            province: province,
                            label: label
                        )
                        return label
                    }
                } else {
                    let englishPlacemark = try? await CLGeocoder().reverseGeocodeLocation(
                        location,
                        preferredLocale: Locale(identifier: "en_US")
                    ).first
                    if let label = foreignRegionLabel(
                        chinesePlacemark: chinesePlacemark,
                        englishPlacemark: englishPlacemark
                    ) {
                        return label
                    }
                }
            }
        }
        if let city = cityFromPlaceName(metadata.placeName) {
            return city
        }
        if let city = metadata.ticketCityName,
           !isLowerLevelRegion(city) {
            return stripCitySuffix(city)
        }
        return nil
    }

    private static func domesticRegionLabel(province: String?, city: String) -> String {
        if let province, province != city {
            return "\(province)·\(city)"
        }
        return city
    }

    private static func nearbyChineseCity(
        from location: CLLocation,
        province: String
    ) async -> String? {
        guard #available(iOS 26.0, *) else { return nil }
        let rings: [(radius: CLLocationDistance, samples: Int)] = [
            (5_000, 8),
            (12_000, 12),
            (22_000, 16),
        ]

        for ring in rings {
            let coordinates = probeCoordinates(
                around: location.coordinate,
                radius: ring.radius,
                count: ring.samples
            )
            let names = await withTaskGroup(of: String?.self) { group in
                for coordinate in coordinates {
                    group.addTask {
                        await mapKitCity(
                            at: coordinate,
                            expectedProvince: province
                        )
                    }
                }
                var results: [String] = []
                for await result in group {
                    if let result { results.append(result) }
                }
                return results
            }
            if let winner = names.reduce(into: [String: Int](), { counts, name in
                counts[name, default: 0] += 1
            }).max(by: { lhs, rhs in
                lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
            })?.key {
                return winner
            }
        }
        return nil
    }

    nonisolated private static func probeCoordinates(
        around center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        count: Int
    ) -> [CLLocationCoordinate2D] {
        let earthRadius = 6_371_000.0
        let latitudeRadians = center.latitude * .pi / 180
        return (0..<count).map { index in
            let bearing = Double(index) / Double(count) * 2 * .pi
            let latitudeDelta = radius * cos(bearing) / earthRadius * 180 / .pi
            let longitudeDelta = radius * sin(bearing)
                / (earthRadius * max(0.01, cos(latitudeRadians))) * 180 / .pi
            return CLLocationCoordinate2D(
                latitude: center.latitude + latitudeDelta,
                longitude: center.longitude + longitudeDelta
            )
        }
    }

    @available(iOS 26.0, *)
    @MainActor
    private static func mapKitCity(
        at coordinate: CLLocationCoordinate2D,
        expectedProvince: String
    ) async -> String? {
        guard let request = MKReverseGeocodingRequest(
            location: CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        ) else { return nil }
        request.preferredLocale = Locale(identifier: "zh_CN")
        guard let address = try? await request.mapItems.first?.addressRepresentations,
              let rawCity = trimmedLocationComponent(address.cityName),
              !isLowerLevelRegion(rawCity) else {
            return nil
        }
        let city = stripCitySuffix(rawCity)
        guard city != expectedProvince,
              address.cityWithContext?.contains(expectedProvince) == true else {
            return nil
        }
        return city
    }

    private static func preferredChineseCity(from placemark: CLPlacemark) -> String? {
        let candidates = [
            placemark.postalAddress?.city,
            placemark.locality,
            placemark.subAdministrativeArea,
        ]
            .compactMap(trimmedLocationComponent)

        if let city = candidates.first(where: { !isLowerLevelRegion($0) }) {
            return stripCitySuffix(city)
        }

        if let administrativeArea = trimmedLocationComponent(placemark.administrativeArea),
           isMunicipality(administrativeArea) {
            return stripCitySuffix(administrativeArea)
        }
        return nil
    }

    private static func foreignRegionLabel(
        chinesePlacemark: CLPlacemark,
        englishPlacemark: CLPlacemark?
    ) -> String? {
        let countryCode = chinesePlacemark.isoCountryCode?.uppercased()
        let country = trimmedLocationComponent(chinesePlacemark.country)
            ?? countryCode.flatMap {
                Locale(identifier: "zh_CN").localizedString(forRegionCode: $0)
            }
        let englishRegion = [
            englishPlacemark?.postalAddress?.city,
            englishPlacemark?.locality,
            englishPlacemark?.subAdministrativeArea,
            englishPlacemark?.administrativeArea,
        ].compactMap(trimmedLocationComponent).first

        switch (country, englishRegion) {
        case let (country?, region?) where country.caseInsensitiveCompare(region) != .orderedSame:
            return "\(country)·\(region)"
        case let (country?, _):
            return country
        case let (_, region?):
            return region
        default:
            return nil
        }
    }

    nonisolated private static func trimmedLocationComponent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isLowerLevelRegion(_ value: String) -> Bool {
        let lowerLevelSuffixes = [
            "区", "县", "旗", "岛", "镇", "乡", "街道", "村", "景区", "开发区",
        ]
        return lowerLevelSuffixes.contains { value.hasSuffix($0) }
    }

    private static func isMunicipality(_ value: String) -> Bool {
        let municipalities = [
            "北京市", "上海市", "天津市", "重庆市",
            "香港特别行政区", "澳门特别行政区",
        ]
        return municipalities.contains(value)
    }

    private static func normalizedProvince(_ value: String?) -> String? {
        guard var value = trimmedLocationComponent(value) else { return nil }
        let replacements = [
            "广西壮族自治区": "广西",
            "宁夏回族自治区": "宁夏",
            "新疆维吾尔自治区": "新疆",
            "内蒙古自治区": "内蒙古",
            "西藏自治区": "西藏",
            "香港特别行政区": "香港",
            "澳门特别行政区": "澳门",
        ]
        if let replacement = replacements[value] { return replacement }
        for suffix in ["特别行政区", "自治区", "省", "市"] where value.hasSuffix(suffix) {
            value.removeLast(suffix.count)
            break
        }
        return value.isEmpty ? nil : value
    }

    private static func stripCitySuffix(_ value: String) -> String {
        let suffixes = ["特别行政区", "自治州", "地区", "盟", "市"]
        for suffix in suffixes where value.hasSuffix(suffix) {
            let stripped = String(value.dropLast(suffix.count))
            if !stripped.isEmpty { return stripped }
        }
        return value
    }

    private static func cityFromPlaceName(_ placeName: String?) -> String? {
        guard let placeName else { return nil }
        let components = placeName
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let suffixes = ["特别行政区", "自治州", "地区", "盟", "市"]
        for component in components {
            for suffix in suffixes where component.hasSuffix(suffix) {
                return String(component.dropLast(suffix.count))
            }
        }
        return nil
    }

    private static func scaledPhoto(from data: Data?) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let pixelSize = CGSize(width: image.size.width * image.scale,
                               height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > 0 else { return nil }
        let ratio = min(1, 1600 / longest)
        let target = CGSize(width: (pixelSize.width * ratio).rounded(),
                            height: (pixelSize.height * ratio).rounded())
        let renderer = UIGraphicsImageRenderer(size: target)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return scaled.jpegData(compressionQuality: 0.86)
    }
}

extension PiaogenceRGBColor {

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt64(value, radix: 16) else { return nil }
        self.init(
            red: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255)
    }
}
