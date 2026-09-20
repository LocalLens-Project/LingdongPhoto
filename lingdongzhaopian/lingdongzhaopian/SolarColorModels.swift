import CryptoKit
import Foundation
import ImageIO
import Observation
import UIKit

enum SolarColorCaptureDateSource: String, Codable, Sendable {
    case exifOriginal
    case exifDigitized
    case tiff
    case manuallyProvided

    var title: String {
        switch self {
        case .exifOriginal: "照片原始拍摄时间".appLocalized
        case .exifDigitized: "照片数字化时间".appLocalized
        case .tiff: "照片文件拍摄时间".appLocalized
        case .manuallyProvided: "手动补录日期".appLocalized
        }
    }
}

struct SolarColorCaptureDate: Equatable, Sendable {
    let date: Date
    let source: SolarColorCaptureDateSource
    let timeZoneIdentifier: String?
    let usedFallbackTimeZone: Bool
}

enum SolarColorCaptureDateReader {
    static func read(from data: Data) -> SolarColorCaptureDate? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

        if let value = exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
           let parsed = parse(value, offset: exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String) {
            return .init(
                date: parsed.date,
                source: .exifOriginal,
                timeZoneIdentifier: parsed.timeZoneIdentifier,
                usedFallbackTimeZone: parsed.usedFallback
            )
        }
        if let value = exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
           let parsed = parse(value, offset: exif?[kCGImagePropertyExifOffsetTimeDigitized] as? String) {
            return .init(
                date: parsed.date,
                source: .exifDigitized,
                timeZoneIdentifier: parsed.timeZoneIdentifier,
                usedFallbackTimeZone: parsed.usedFallback
            )
        }
        if let value = tiff?[kCGImagePropertyTIFFDateTime] as? String,
           let parsed = parse(value, offset: nil) {
            return .init(
                date: parsed.date,
                source: .tiff,
                timeZoneIdentifier: parsed.timeZoneIdentifier,
                usedFallbackTimeZone: parsed.usedFallback
            )
        }
        return nil
    }

    private static func parse(_ value: String, offset: String?) -> (
        date: Date, timeZoneIdentifier: String?, usedFallback: Bool
    )? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let offset, !offset.isEmpty {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss XXX"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            guard let date = formatter.date(from: "\(value) \(offset)") else { return nil }
            return (date, offset, false)
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        guard let date = formatter.date(from: value) else { return nil }
        return (date, TimeZone.current.identifier, true)
    }
}

struct SolarColorStoredColor: Codable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let percentage: Double

    init(_ color: RGBColor, percentage: Double) {
        red = Double(color.red)
        green = Double(color.green)
        blue = Double(color.blue)
        self.percentage = percentage
    }

    var rgb: RGBColor {
        RGBColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue))
    }
}

struct SolarColorRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    let captureDate: Date
    let captureDateSource: SolarColorCaptureDateSource
    let captureTimeZoneIdentifier: String?
    let usedFallbackTimeZone: Bool
    let seasonYear: Int
    let term: SolarTerm
    let occurrenceStart: Date
    let occurrenceEnd: Date
    let calendarDataVersion: String
    let matcherVersion: String
    let lexiconVersion: String
    let photoFingerprint: String
    let imageFileName: String
    let thumbnailFileName: String
    let extractedColors: [SolarColorStoredColor]
    let suggestedColorNames: [String]
    var selectedColorName: String
    let isNearOccurrence: Bool
    let wasDateManuallyProvided: Bool
    var personalNote: String?
}

struct SolarColorVaultSnapshot: Codable, Sendable {
    var schemaVersion = 1
    var createdAt = Date.now
    var updatedAt = Date.now
    var records: [SolarColorRecord] = []
    var representatives: [String: UUID] = [:]
}

enum SolarColorStoreError: LocalizedError {
    case damagedLibrary
    case unsupportedBackup
    case imageEncoding
    case duplicate(SolarColorRecord)
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .damagedLibrary: "节气寻色资料库无法读取，请从备份恢复。".appLocalized
        case .unsupportedBackup: "这不是可识别的节气寻色备份，或备份版本过新。".appLocalized
        case .imageEncoding: "照片处理失败，请换一张照片重试。".appLocalized
        case .duplicate(let record):
            String(format: "这张照片已经收藏在%@。".appLocalized, record.term.localizedName)
        case .invalidDate: "这张照片的日期无法归入受支持的节气年份。".appLocalized
        }
    }
}

@MainActor @Observable
final class SolarColorStore {
    static let shared = SolarColorStore()
    static let schemaVersion = 1

    private struct BackupEnvelope: Codable {
        let format: String
        let version: Int
        let exportedAt: Date
        let snapshot: SolarColorVaultSnapshot
        let images: [String: Data]
    }

    private(set) var snapshot = SolarColorVaultSnapshot()
    private(set) var loadError: String?
    private let root: URL
    private let imageCache = NSCache<NSString, UIImage>()

    init(root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SolarColorVault", isDirectory: true)) {
        self.root = root
        imageCache.totalCostLimit = 32 * 1024 * 1024
        do {
            try loadIfPresent()
        } catch {
            loadError = error.localizedDescription
        }
    }

    var records: [SolarColorRecord] {
        snapshot.records.sorted {
            $0.captureDate == $1.captureDate
                ? $0.id.uuidString < $1.id.uuidString
                : $0.captureDate < $1.captureDate
        }
    }

    var seasonYears: [Int] {
        Array(Set(records.map(\.seasonYear))).sorted()
    }

    func records(seasonYear: Int, term: SolarTerm) -> [SolarColorRecord] {
        records.filter { $0.seasonYear == seasonYear && $0.term == term }
    }

    func representative(seasonYear: Int, term: SolarTerm) -> SolarColorRecord? {
        let candidates = records(seasonYear: seasonYear, term: term)
        let key = Self.slotKey(seasonYear: seasonYear, term: term)
        if let id = snapshot.representatives[key],
           let value = candidates.first(where: { $0.id == id }) {
            return value
        }
        return candidates.first
    }

    func completionCount(seasonYear: Int) -> Int {
        SolarTermCalendar.seasonOrder.filter {
            representative(seasonYear: seasonYear, term: $0) != nil
        }.count
    }

    func image(for record: SolarColorRecord, thumbnail: Bool = false) -> UIImage? {
        let fileName = thumbnail ? record.thumbnailFileName : record.imageFileName
        let key = fileName as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: root.appendingPathComponent(fileName).path) else {
            return nil
        }
        imageCache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    @discardableResult
    func add(
        photo: SelectedPhoto,
        captureDate: Date,
        dateSource: SolarColorCaptureDateSource,
        captureTimeZoneIdentifier: String?,
        usedFallbackTimeZone: Bool,
        occurrence: SolarTermOccurrence,
        palette: PaletteResult,
        suggestedColorNames: [String],
        selectedColorName: String
    ) throws -> SolarColorRecord {
        guard captureDate <= Date.now.addingTimeInterval(24 * 60 * 60) else {
            throw SolarColorStoreError.invalidDate
        }
        guard captureDate >= occurrence.instant, captureDate < occurrence.nextInstant else {
            throw SolarColorStoreError.invalidDate
        }
        let fingerprint = SHA256.hash(data: photo.originalData)
            .map { String(format: "%02x", $0) }.joined()
        if let existing = snapshot.records.first(where: { $0.photoFingerprint == fingerprint }) {
            throw SolarColorStoreError.duplicate(existing)
        }
        guard let full = Self.scaledJPEG(photo.image, maximumPixel: 2048, quality: 0.88),
              let thumbnail = Self.scaledJPEG(photo.image, maximumPixel: 560, quality: 0.78) else {
            throw SolarColorStoreError.imageEncoding
        }

        let id = UUID()
        let record = SolarColorRecord(
            id: id,
            createdAt: .now,
            updatedAt: .now,
            captureDate: captureDate,
            captureDateSource: dateSource,
            captureTimeZoneIdentifier: captureTimeZoneIdentifier,
            usedFallbackTimeZone: usedFallbackTimeZone,
            seasonYear: occurrence.seasonYear,
            term: occurrence.term,
            occurrenceStart: occurrence.instant,
            occurrenceEnd: occurrence.nextInstant,
            calendarDataVersion: SolarTermCalendar.dataVersion,
            matcherVersion: SolarColorMatcher.version,
            lexiconVersion: "traditional-384-1",
            photoFingerprint: fingerprint,
            imageFileName: "images/\(id.uuidString).jpg",
            thumbnailFileName: "thumbnails/\(id.uuidString).jpg",
            extractedColors: zip(palette.colors, palette.percentages).map(SolarColorStoredColor.init),
            suggestedColorNames: suggestedColorNames,
            selectedColorName: selectedColorName,
            isNearOccurrence: SolarTermCalendar.isNearBoundary(captureDate, occurrence: occurrence),
            wasDateManuallyProvided: dateSource == .manuallyProvided,
            personalNote: nil
        )

        try ensureDirectories()
        try full.write(to: root.appendingPathComponent(record.imageFileName), options: .atomic)
        do {
            try thumbnail.write(to: root.appendingPathComponent(record.thumbnailFileName), options: .atomic)
            var next = snapshot
            next.records.append(record)
            let key = Self.slotKey(seasonYear: record.seasonYear, term: record.term)
            if next.representatives[key] == nil { next.representatives[key] = record.id }
            try commit(next)
        } catch {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(record.imageFileName))
            try? FileManager.default.removeItem(at: root.appendingPathComponent(record.thumbnailFileName))
            throw error
        }
        return record
    }

    func chooseRepresentative(_ record: SolarColorRecord) throws {
        guard snapshot.records.contains(where: { $0.id == record.id }) else { return }
        var next = snapshot
        next.representatives[Self.slotKey(seasonYear: record.seasonYear, term: record.term)] = record.id
        try commit(next)
    }

    func changeSelectedColor(_ name: String, for record: SolarColorRecord) throws {
        guard TraditionalColorLexicon.entries(for: record.term).contains(where: { $0.name == name }),
              let index = snapshot.records.firstIndex(where: { $0.id == record.id }) else { return }
        var next = snapshot
        next.records[index].selectedColorName = name
        next.records[index].updatedAt = .now
        try commit(next)
    }

    func updateNote(_ note: String?, for record: SolarColorRecord) throws {
        guard let index = snapshot.records.firstIndex(where: { $0.id == record.id }) else { return }
        var next = snapshot
        next.records[index].personalNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        next.records[index].updatedAt = .now
        try commit(next)
    }

    func delete(_ record: SolarColorRecord) throws {
        var next = snapshot
        next.records.removeAll { $0.id == record.id }
        let key = Self.slotKey(seasonYear: record.seasonYear, term: record.term)
        if next.representatives[key] == record.id {
            next.representatives[key] = next.records.first {
                $0.seasonYear == record.seasonYear && $0.term == record.term
            }?.id
        }
        try commit(next)
        imageCache.removeObject(forKey: record.imageFileName as NSString)
        imageCache.removeObject(forKey: record.thumbnailFileName as NSString)
        try? FileManager.default.removeItem(at: root.appendingPathComponent(record.imageFileName))
        try? FileManager.default.removeItem(at: root.appendingPathComponent(record.thumbnailFileName))
    }

    func makeBackupURL() throws -> URL {
        var files: [String: Data] = [:]
        for record in snapshot.records {
            for name in [record.imageFileName, record.thumbnailFileName] {
                let url = root.appendingPathComponent(name)
                if let data = try? Data(contentsOf: url) { files[name] = data }
            }
        }
        let envelope = BackupEnvelope(
            format: "com.locallens.lingdong.solar-colors",
            version: Self.schemaVersion,
            exportedAt: .now,
            snapshot: snapshot,
            images: files
        )
        let data = try JSONEncoder().encode(envelope)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(String(
                format: "我的节气颜色-%@".appLocalized,
                Self.backupDate.string(from: .now)
            ))
            .appendingPathExtension("lingdongseasons")
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    func restore(from url: URL) throws -> Int {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let envelope: BackupEnvelope
        do {
            envelope = try JSONDecoder().decode(BackupEnvelope.self, from: Data(contentsOf: url))
        } catch {
            throw SolarColorStoreError.unsupportedBackup
        }
        guard envelope.format == "com.locallens.lingdong.solar-colors",
              envelope.version <= Self.schemaVersion,
              envelope.snapshot.schemaVersion <= Self.schemaVersion else {
            throw SolarColorStoreError.unsupportedBackup
        }
        try ensureDirectories()
        var next = snapshot
        var addedIDs = Set<UUID>()
        let fingerprints = Set(next.records.map(\.photoFingerprint))
        for record in envelope.snapshot.records where !fingerprints.contains(record.photoFingerprint) {
            guard envelope.images[record.imageFileName] != nil else { continue }
            for name in [record.imageFileName, record.thumbnailFileName] {
                if let data = envelope.images[name] {
                    try data.write(to: root.appendingPathComponent(name), options: .atomic)
                }
            }
            next.records.append(record)
            addedIDs.insert(record.id)
        }
        for (key, id) in envelope.snapshot.representatives
            where addedIDs.contains(id) && next.representatives[key] == nil {
            next.representatives[key] = id
        }
        try commit(next)
        return addedIDs.count
    }

    private func loadIfPresent() throws {
        let url = root.appendingPathComponent("snapshot.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let decoded = try JSONDecoder().decode(SolarColorVaultSnapshot.self, from: Data(contentsOf: url))
        guard decoded.schemaVersion <= Self.schemaVersion else {
            throw SolarColorStoreError.damagedLibrary
        }
        snapshot = decoded
    }

    private func ensureDirectories() throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("images", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("thumbnails", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    private func commit(_ nextValue: SolarColorVaultSnapshot) throws {
        try ensureDirectories()
        var next = nextValue
        next.schemaVersion = Self.schemaVersion
        next.updatedAt = .now
        try JSONEncoder().encode(next)
            .write(to: root.appendingPathComponent("snapshot.json"), options: .atomic)
        snapshot = next
        loadError = nil
    }

    private static func slotKey(seasonYear: Int, term: SolarTerm) -> String {
        "\(seasonYear):\(term.rawValue)"
    }

    private static func scaledJPEG(_ image: UIImage, maximumPixel: CGFloat, quality: CGFloat) -> Data? {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixels.width, pixels.height)
        guard longest > 0 else { return nil }
        let ratio = min(1, maximumPixel / longest)
        let target = CGSize(
            width: max(1, (pixels.width * ratio).rounded()),
            height: max(1, (pixels.height * ratio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let result = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return result.jpegData(compressionQuality: quality)
    }

    private static let backupDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }()
}

struct SolarColorMatchCandidate: Identifiable {
    let entry: TraditionalColorEntry
    let sampledColor: RGBColor
    let sampledPercentage: Double
    let score: Double

    var id: String { entry.name }
}

enum SolarColorMatcher {
    static let version = "oklab-term-scoped-1"

    static func candidates(
        palette: PaletteResult,
        term: SolarTerm,
        limit: Int = 3
    ) -> [SolarColorMatchCandidate] {
        let colors = Array(palette.colors.prefix(6))
        guard !colors.isEmpty else { return [] }
        let percentages = Array(palette.percentages.prefix(colors.count))
        let maximum = max(percentages.max() ?? 0, 1)
        return TraditionalColorLexicon.entries(for: term).compactMap { entry in
            let target = SolarColorLab(
                red: Double(entry.rgb.0) / 255,
                green: Double(entry.rgb.1) / 255,
                blue: Double(entry.rgb.2) / 255
            )
            let best = colors.indices.min { lhs, rhs in
                score(colors[lhs], percentage: percentages[safe: lhs] ?? 0, maximum: maximum, target: target)
                    < score(colors[rhs], percentage: percentages[safe: rhs] ?? 0, maximum: maximum, target: target)
            } ?? 0
            return SolarColorMatchCandidate(
                entry: entry,
                sampledColor: colors[best],
                sampledPercentage: percentages[safe: best] ?? 0,
                score: score(
                    colors[best],
                    percentage: percentages[safe: best] ?? 0,
                    maximum: maximum,
                    target: target
                )
            )
        }
        .sorted {
            $0.score == $1.score
                ? (TraditionalColorLexicon.entryIndexesByName[$0.entry.name] ?? 0)
                    < (TraditionalColorLexicon.entryIndexesByName[$1.entry.name] ?? 0)
                : $0.score < $1.score
        }
        .prefix(max(1, limit))
        .map { $0 }
    }

    private static func score(
        _ color: RGBColor,
        percentage: Double,
        maximum: Double,
        target: SolarColorLab
    ) -> Double {
        let source = SolarColorLab(
            red: Double(color.red), green: Double(color.green), blue: Double(color.blue)
        )
        let dominancePenalty = 0.045 * (1 - max(percentage, 0) / maximum)
        return source.distanceSquared(to: target) + dominancePenalty
    }
}

private struct SolarColorLab {
    let lightness: Double
    let a: Double
    let b: Double

    init(red: Double, green: Double, blue: Double) {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = linear(min(max(red, 0), 1))
        let green = linear(min(max(green, 0), 1))
        let blue = linear(min(max(blue, 0), 1))
        let l = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue
        let m = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue
        let s = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue
        let lRoot = cbrt(l), mRoot = cbrt(m), sRoot = cbrt(s)
        lightness = 0.2104542553 * lRoot + 0.793617785 * mRoot - 0.0040720468 * sRoot
        a = 1.9779984951 * lRoot - 2.428592205 * mRoot + 0.4505937099 * sRoot
        b = 0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.808675766 * sRoot
    }

    func distanceSquared(to other: SolarColorLab) -> Double {
        let dl = lightness - other.lightness, da = a - other.a, db = b - other.b
        return dl * dl + da * da + db * db
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
