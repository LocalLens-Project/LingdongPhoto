import SwiftUI

enum SceneTheme: String, CaseIterable, Hashable {
    case sunset = "日落"
    case sea = "海风"
    case forest = "山林"
    case nightCity = "夜景"
    case snowMountain = "雪山"
    case sakura = "樱季"
    case desert = "沙丘"
    case aurora = "极光"

    var skyGradient: [Color] {
        switch self {
        case .sunset:
            return [Color(red: 0.99, green: 0.78, blue: 0.45),
                    Color(red: 0.96, green: 0.52, blue: 0.38),
                    Color(red: 0.55, green: 0.28, blue: 0.42)]
        case .sea:
            return [Color(red: 0.62, green: 0.84, blue: 0.92),
                    Color(red: 0.32, green: 0.63, blue: 0.82),
                    Color(red: 0.13, green: 0.38, blue: 0.62)]
        case .forest:
            return [Color(red: 0.85, green: 0.92, blue: 0.80),
                    Color(red: 0.47, green: 0.68, blue: 0.52),
                    Color(red: 0.16, green: 0.36, blue: 0.28)]
        case .nightCity:
            return [Color(red: 0.09, green: 0.10, blue: 0.24),
                    Color(red: 0.16, green: 0.17, blue: 0.38),
                    Color(red: 0.30, green: 0.22, blue: 0.44)]
        case .snowMountain:
            return [Color(red: 0.80, green: 0.88, blue: 0.96),
                    Color(red: 0.62, green: 0.75, blue: 0.90),
                    Color(red: 0.42, green: 0.56, blue: 0.78)]
        case .sakura:
            return [Color(red: 0.99, green: 0.90, blue: 0.92),
                    Color(red: 0.96, green: 0.76, blue: 0.82),
                    Color(red: 0.82, green: 0.56, blue: 0.68)]
        case .desert:
            return [Color(red: 0.99, green: 0.86, blue: 0.62),
                    Color(red: 0.94, green: 0.68, blue: 0.44),
                    Color(red: 0.72, green: 0.44, blue: 0.30)]
        case .aurora:
            return [Color(red: 0.05, green: 0.10, blue: 0.22),
                    Color(red: 0.08, green: 0.18, blue: 0.30),
                    Color(red: 0.10, green: 0.24, blue: 0.28)]
        }
    }

    var silhouette: Color {
        switch self {
        case .sunset: return Color(red: 0.28, green: 0.15, blue: 0.26)
        case .sea: return Color(red: 0.10, green: 0.30, blue: 0.50)
        case .forest: return Color(red: 0.10, green: 0.26, blue: 0.20)
        case .nightCity: return Color(red: 0.05, green: 0.06, blue: 0.14)
        case .snowMountain: return Color(red: 0.36, green: 0.48, blue: 0.68)
        case .sakura: return Color(red: 0.55, green: 0.32, blue: 0.42)
        case .desert: return Color(red: 0.55, green: 0.34, blue: 0.24)
        case .aurora: return Color(red: 0.04, green: 0.07, blue: 0.12)
        }
    }
}

struct PiaogenceRGBColor: Hashable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    var relativeLuminance: CGFloat {
        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }

    func contrastRatio(with other: PiaogenceRGBColor) -> CGFloat {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func adjusted(brightness: CGFloat = 0, saturation: CGFloat = 0) -> PiaogenceRGBColor {
        let average = (red + green + blue) / 3
        let factor = 1 + saturation
        return PiaogenceRGBColor(
            red: (average + (red - average) * factor) + brightness,
            green: (average + (green - average) * factor) + brightness,
            blue: (average + (blue - average) * factor) + brightness
        )
    }

    static let fallback: [PiaogenceRGBColor] = [
        PiaogenceRGBColor(red: 0.78, green: 0.91, blue: 0.48),
        PiaogenceRGBColor(red: 0.34, green: 0.53, blue: 0.31),
        PiaogenceRGBColor(red: 0.91, green: 0.95, blue: 0.64),
        PiaogenceRGBColor(red: 0.18, green: 0.32, blue: 0.18),
        PiaogenceRGBColor(red: 0.66, green: 0.76, blue: 0.37),
        PiaogenceRGBColor(red: 0.93, green: 0.87, blue: 0.54)
    ]
}

enum PiaogenceLayoutStyle: String, CaseIterable, Identifiable {
    case classic = "横向经典"
    case vertical = "纵向旅行"

    var id: String { rawValue }

    var localizedTitle: String { rawValue.appLocalized }

    var aspectRatio: CGFloat {
        switch self {
        case .classic: 21.0 / 9.0
        case .vertical: 3.0 / 4.0
        }
    }
}

enum TicketEdition: String, CaseIterable, Identifiable, Hashable {
    case standard
    case collector

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "标准票面".appLocalized
        case .collector: "典藏票面".appLocalized
        }
    }

    var shortTitle: String {
        switch self {
        case .standard: "标准".appLocalized
        case .collector: "典藏".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .standard: "ticket"
        case .collector: "sparkles"
        }
    }
}

struct TicketStub: Identifiable, Hashable {

    var id = UUID()
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
    var layout: PiaogenceLayoutStyle
    var theme: SceneTheme
    var palette: [PiaogenceRGBColor]
    var isSealed: Bool
    var isCapsule: Bool

    var artworkImageData: Data? = nil

    var codeStyle: TicketCodeStyle? = nil

    var qrPayload: String? = nil

    var barcodeValue: String? = nil

    var isArchivedWork: Bool = false

    var physicalTicketType: PhysicalTicketType? = nil
    var isPhysicalImport: Bool = false
    var ticketColorName: String? = nil
    var ticketEdition: TicketEdition = .standard
}

struct TicketCollection: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var tickets: [TicketStub]
}

@Observable
final class TicketStore {

    static let shared = TicketStore()

    var cityTickets: [TicketStub]
    var customCollections: [TicketCollection]

    var cityRepresentatives: [String: UUID] = [:]

    init() {
        let snapshot = PiaogenceVault.load()
        self.cityTickets = snapshot.cityTickets
        self.customCollections = snapshot.customCollections
        self.cityRepresentatives = snapshot.cityRepresentatives

        if consolidateEquivalentCityLabels() {
            PiaogenceVault.save(
                cityTickets: cityTickets,
                customCollections: customCollections,
                cityRepresentatives: cityRepresentatives
            )
        }
    }

    func addTicket(_ ticket: TicketStub) {
        cityTickets.removeAll { $0.ticketID == ticket.ticketID }
        cityTickets.append(ticket)
        if let city = ticket.city, cityRepresentatives[city] == nil {
            cityRepresentatives[city] = ticket.id
        }
        persist()
    }

    func addDevelopedTickets(_ tickets: [TicketStub]) {
        guard !tickets.isEmpty else { return }
        let collectionName = "票根显影"
        if let index = customCollections.firstIndex(where: { $0.name == collectionName }) {
            for ticket in tickets {
                customCollections[index].tickets.removeAll { $0.ticketID == ticket.ticketID }
                customCollections[index].tickets.append(ticket)
            }
            customCollections[index].tickets.sort { $0.captureDate < $1.captureDate }
        } else {
            customCollections.append(TicketCollection(
                name: collectionName,
                icon: "viewfinder",
                tickets: tickets.sorted { $0.captureDate < $1.captureDate }
            ))
        }
        persist()
    }

    func updateTicket(_ ticket: TicketStub) {
        if let index = cityTickets.firstIndex(where: { $0.id == ticket.id }) {
            cityTickets[index] = ticket
        }
        for collectionIndex in customCollections.indices {
            if let ticketIndex = customCollections[collectionIndex].tickets
                .firstIndex(where: { $0.id == ticket.id }) {
                customCollections[collectionIndex].tickets[ticketIndex] = ticket
            }
        }
        persist()
    }

    func persist() {
        consolidateEquivalentCityLabels()
        PiaogenceVault.save(
            cityTickets: cityTickets,
            customCollections: customCollections,
            cityRepresentatives: cityRepresentatives)
    }

    @discardableResult
    private func consolidateEquivalentCityLabels() -> Bool {
        var completeLabelsByCity = [String: Set<String>]()
        for city in cityTickets.compactMap(\.city) {
            let components = city.split(separator: "·", omittingEmptySubsequences: true)
            guard components.count >= 2, let cityComponent = components.last else { continue }
            completeLabelsByCity[Self.cityIdentity(String(cityComponent)), default: []]
                .insert(city)
        }

        var replacements = [String: String]()
        for city in Set(cityTickets.compactMap(\.city)) where !city.contains("·") {
            let candidates = completeLabelsByCity[Self.cityIdentity(city)] ?? []
            if candidates.count == 1, let completeLabel = candidates.first {
                replacements[city] = completeLabel
            }
        }

        var changed = false
        if !replacements.isEmpty {
            for index in cityTickets.indices {
                guard let city = cityTickets[index].city,
                      let completeLabel = replacements[city] else { continue }
                cityTickets[index].city = completeLabel
                changed = true
            }
        }

        let previousRepresentatives = cityRepresentatives
        var rebuiltRepresentatives = [String: UUID]()
        for city in Set(cityTickets.compactMap(\.city)) {
            let tickets = cityTickets.filter { $0.city == city }
            let validIDs = Set(tickets.map(\.id))
            let legacyKeys = replacements
                .filter { $0.value == city }
                .map(\.key)
                .sorted()
            let candidateKeys = [city] + legacyKeys
            let preserved = candidateKeys
                .compactMap { previousRepresentatives[$0] }
                .first(where: validIDs.contains)
            rebuiltRepresentatives[city] = preserved
                ?? tickets.max(by: { $0.captureDate < $1.captureDate })?.id
        }
        if rebuiltRepresentatives != previousRepresentatives {
            cityRepresentatives = rebuiltRepresentatives
            changed = true
        }
        return changed
    }

    private static func cityIdentity(_ city: String) -> String {
        var value = city.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in ["特别行政区", "自治州", "地区", "市", "盟"] where value.hasSuffix(suffix) {
            value.removeLast(suffix.count)
            break
        }
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var cities: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for ticket in cityTickets {
            guard let city = ticket.city, !seen.contains(city) else { continue }
            seen.insert(city)
            result.append(city)
        }
        return result
    }

    func tickets(inCity city: String) -> [TicketStub] {
        cityTickets.filter { $0.city == city }
    }

    func representativeTicket(forCity city: String) -> TicketStub? {
        let tickets = tickets(inCity: city)
        if let picked = cityRepresentatives[city],
           let ticket = tickets.first(where: { $0.id == picked }) {
            return ticket
        }
        return tickets.max(by: { $0.captureDate < $1.captureDate })
    }

    var totalTicketCount: Int {
        cityTickets.count + customCollections.reduce(0) { $0 + $1.tickets.count }
    }
}

extension TicketStub {

    private static func randomFingerprint(seed: UInt64) -> String {
        var rng = SeededGenerator(seed: seed)
        let hexChars = Array("0123456789ABCDEF")
        var text = ""
        for _ in 0..<16 { text.append(hexChars[Int(rng.next() % 16)]) }
        return text
    }

    static func archivedWorkTicket(workID: UUID, title: String,
                                   createdAt: Date, city: String?,
                                   pixelWidth: Int, pixelHeight: Int,
                                   artworkImageData: Data?) -> TicketStub {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        let serial = Int(abs(workID.hashValue % 9000)) + 1000
        let year = Calendar.current.component(.year, from: createdAt)
        return TicketStub(
            ticketID: "LD-\(year)-\(serial)",
            fingerprint: randomFingerprint(seed: UInt64(workID.hashValue.magnitude &* 733)),
            headerTitle: nil,
            title: title, subtitle: nil,
            message: "这张作品曾经被做成影像票根，现在收进票根集。".appLocalized,

            city: city, place: nil, device: nil,
            captureDate: createdAt, captureTimeText: formatter.string(from: createdAt),
            layout: pixelWidth >= pixelHeight ? .classic : .vertical,
            theme: .sunset,
            palette: [PiaogenceRGBColor(red: 0.96, green: 0.95, blue: 0.92)],
            isSealed: false, isCapsule: false,
            artworkImageData: artworkImageData,
            isArchivedWork: true)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}
