import Foundation
import Observation
import UIKit
import UserNotifications

enum PhotoBackPerspective: String, Codable, CaseIterable, Identifiable, Sendable {
    case inside
    case outside
    case future
    case later

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inside: "画面里".appLocalized
        case .outside: "画面外".appLocalized
        case .future: "写给以后".appLocalized
        case .later: "后来".appLocalized
        }
    }

    var prompt: String {
        switch self {
        case .inside: "那一刻，你真正看见了什么？".appLocalized
        case .outside: "有什么没有被镜头收进来？".appLocalized
        case .future: "下次再见它时，你想对自己说什么？".appLocalized
        case .later: "过了一段时间，你又想起了什么？".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .inside: "viewfinder"
        case .outside: "rectangle.dashed"
        case .future: "hourglass"
        case .later: "arrow.turn.down.right"
        }
    }
}

enum PhotoBackRevisitOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case nextSolarTerm
    case thirtyDays
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "不设日期".appLocalized
        case .nextSolarTerm: "下一个节气".appLocalized
        case .thirtyDays: "30 天后".appLocalized
        case .oneYear: "一年后".appLocalized
        }
    }

    func date(from date: Date = .now) -> Date? {
        switch self {
        case .none:
            nil
        case .nextSolarTerm:
            PhotoBackCalendar.nextSolarTerm(after: date)?.instant
                ?? Calendar.current.date(byAdding: .day, value: 15, to: date)
        case .thirtyDays:
            Calendar.current.date(byAdding: .day, value: 30, to: date)
        case .oneYear:
            Calendar.current.date(byAdding: .year, value: 1, to: date)
        }
    }
}

enum PhotoBackCalendar {
    static func nextSolarTerm(after date: Date) -> SolarTermOccurrence? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SolarTermCalendar.chinaTimeZone
        let year = calendar.component(.year, from: date)
        return (SolarTermCalendar.occurrences(inGregorianYear: year)
            + SolarTermCalendar.occurrences(inGregorianYear: year + 1))
            .filter { $0.instant > date }
            .min { $0.instant < $1.instant }
    }
}

struct PhotoBackInk: Codable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ color: RGBColor) {
        red = Double(color.red)
        green = Double(color.green)
        blue = Double(color.blue)
    }
}

struct PhotoBackEcho: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    var perspective: PhotoBackPerspective
    var text: String
    var fontRawValue: String

    var font: PostalFont { PostalFont(rawValue: fontRawValue) ?? .wenkai }
}

struct PhotoBackRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    let captureDate: Date?
    let placeName: String?
    let imageFileName: String
    let thumbnailFileName: String
    let ink: PhotoBackInk
    var revisitAt: Date?
    var echoes: [PhotoBackEcho]

    var latestEcho: PhotoBackEcho? { echoes.max { $0.createdAt < $1.createdAt } }
    var isDue: Bool { revisitAt.map { $0 <= .now } ?? false }
}

private struct PhotoBackSnapshot: Codable {
    var schemaVersion = 1
    var updatedAt = Date.now
    var records: [PhotoBackRecord] = []
}

enum PhotoBackStoreError: LocalizedError {
    case imageEncoding
    case damagedLibrary

    var errorDescription: String? {
        switch self {
        case .imageEncoding: "这张照片无法收进照片抽屉，请换一张重试。".appLocalized
        case .damagedLibrary: "照片背面资料库无法读取。".appLocalized
        }
    }
}

@MainActor @Observable
final class PhotoBackStore {
    static let shared = PhotoBackStore()
    private static let schemaVersion = 1

    private(set) var records: [PhotoBackRecord] = []
    private(set) var loadError: String?
    private let root: URL
    private let imageCache = NSCache<NSString, UIImage>()

    init(root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PhotoBacks", isDirectory: true)) {
        self.root = root
        imageCache.totalCostLimit = 40 * 1024 * 1024
        do {
            try loadIfPresent()
        } catch {
            loadError = error.localizedDescription
        }
    }

    var orderedRecords: [PhotoBackRecord] {
        records.sorted {
            if $0.isDue != $1.isDue { return $0.isDue }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var dueCount: Int { records.filter(\.isDue).count }

    func image(for record: PhotoBackRecord, thumbnail: Bool = false) -> UIImage? {
        let name = thumbnail ? record.thumbnailFileName : record.imageFileName
        let key = name as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: root.appendingPathComponent(name).path) else { return nil }
        imageCache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    @discardableResult
    func add(
        photo: SelectedPhoto,
        perspective: PhotoBackPerspective,
        text: String,
        font: PostalFont,
        revisitAt: Date?,
        ink: RGBColor
    ) throws -> PhotoBackRecord {
        guard let full = Self.scaledJPEG(photo.image, maximumPixel: 2400, quality: 0.91),
              let thumbnail = Self.scaledJPEG(photo.image, maximumPixel: 640, quality: 0.80) else {
            throw PhotoBackStoreError.imageEncoding
        }
        let id = UUID()
        let record = PhotoBackRecord(
            id: id,
            createdAt: .now,
            updatedAt: .now,
            captureDate: photo.metadata.captureDate,
            placeName: photo.metadata.placeName,
            imageFileName: "images/\(id.uuidString).jpg",
            thumbnailFileName: "thumbnails/\(id.uuidString).jpg",
            ink: PhotoBackInk(ink),
            revisitAt: revisitAt,
            echoes: [PhotoBackEcho(
                id: UUID(), createdAt: .now, perspective: perspective,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                fontRawValue: font.rawValue
            )]
        )

        try ensureDirectories()
        try full.write(to: root.appendingPathComponent(record.imageFileName), options: .atomic)
        do {
            try thumbnail.write(to: root.appendingPathComponent(record.thumbnailFileName), options: .atomic)
            var next = records
            next.append(record)
            try commit(next)
        } catch {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(record.imageFileName))
            try? FileManager.default.removeItem(at: root.appendingPathComponent(record.thumbnailFileName))
            throw error
        }
        PhotoBackReminderScheduler.update(for: record)
        return record
    }

    func append(
        text: String,
        font: PostalFont,
        revisitAt: Date?,
        to record: PhotoBackRecord
    ) throws {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        var next = records
        next[index].echoes.append(PhotoBackEcho(
            id: UUID(), createdAt: .now, perspective: .later,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            fontRawValue: font.rawValue
        ))
        next[index].revisitAt = revisitAt
        next[index].updatedAt = .now
        try commit(next)
        PhotoBackReminderScheduler.update(for: next[index])
    }

    func delete(_ record: PhotoBackRecord) throws {
        var next = records
        next.removeAll { $0.id == record.id }
        try commit(next)
        imageCache.removeObject(forKey: record.imageFileName as NSString)
        imageCache.removeObject(forKey: record.thumbnailFileName as NSString)
        try? FileManager.default.removeItem(at: root.appendingPathComponent(record.imageFileName))
        try? FileManager.default.removeItem(at: root.appendingPathComponent(record.thumbnailFileName))
        PhotoBackReminderScheduler.remove(for: record.id)
    }

    private func loadIfPresent() throws {
        let url = root.appendingPathComponent("snapshot.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let snapshot = try JSONDecoder().decode(PhotoBackSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion <= Self.schemaVersion else { throw PhotoBackStoreError.damagedLibrary }
        records = snapshot.records
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

    private func commit(_ records: [PhotoBackRecord]) throws {
        try ensureDirectories()
        let snapshot = PhotoBackSnapshot(
            schemaVersion: Self.schemaVersion,
            updatedAt: .now,
            records: records
        )
        try JSONEncoder().encode(snapshot)
            .write(to: root.appendingPathComponent("snapshot.json"), options: .atomic)
        self.records = records
        loadError = nil
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
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}

enum PhotoBackReminderScheduler {
    private static func identifier(_ id: UUID) -> String { "photo-back.\(id.uuidString)" }

    static func update(for record: PhotoBackRecord) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(record.id)])
        guard let revisitAt = record.revisitAt, revisitAt > .now else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "有一张照片，到了再看一眼的时候".appLocalized
            content.body = "翻到背面，看看当时的你留下了什么。".appLocalized
            content.sound = .default
            content.userInfo = ["photoBackRecordID": record.id.uuidString]
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: revisitAt
            )
            let request = UNNotificationRequest(
                identifier: identifier(record.id),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            center.add(request)
        }
    }

    static func remove(for id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(id)])
    }
}
