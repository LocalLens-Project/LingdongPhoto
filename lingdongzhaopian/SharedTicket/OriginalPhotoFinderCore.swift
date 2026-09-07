import CryptoKit
import Foundation

enum OriginalPhotoFinderCore {

    static func signatureValue(fromHex text: String) -> UInt64? {
        UInt64(text.trimmingCharacters(in: .whitespacesAndNewlines), radix: 16)
    }

    static func signature(of data: Data) -> UInt64? {
        guard !data.isEmpty else { return nil }
        return Self.reduce(SHA256.hash(data: data))
    }

    private static func reduce(_ digest: some Sequence<UInt8>) -> UInt64 {
        digest.prefix(8).reduce(UInt64.zero) { partial, byte in
            (partial << 8) | UInt64(byte)
        }
    }

    final class StreamingSignature: @unchecked Sendable {
        private let lock = NSLock()
        private var hasher = SHA256()
        private var isEmpty = true

        func update(_ chunk: Data) {
            guard !chunk.isEmpty else { return }
            lock.lock()
            defer { lock.unlock() }
            isEmpty = false
            hasher.update(data: chunk)
        }

        func finalize() -> UInt64? {
            lock.lock()
            defer { lock.unlock() }
            guard !isEmpty else { return nil }
            return OriginalPhotoFinderCore.reduce(hasher.finalize())
        }
    }

    static let fixedCaptureTimeFormats: [String] = [
        "yyyy/MM/dd, HH:mm",
        "yyyy/M/d, HH:mm",
        "yyyy-MM-dd, HH:mm",
        "yyyy/MM/dd HH:mm",
        "M/d/yy, h:mm a",
        "MM/dd/yyyy, h:mm a",
        "dd/MM/yyyy, HH:mm",
    ]

    static func parseCaptureDate(from text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        for format in fixedCaptureTimeFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        let localized = DateFormatter()
        localized.dateStyle = .short
        localized.timeStyle = .short
        return localized.date(from: text)
    }

    static let prefilterWindows: [TimeInterval] = [3_600, 86_400]

    static func candidateIndexes(dates: [Date], target: Date, window: TimeInterval) -> [Int] {
        var result: [Int] = []
        for (index, date) in dates.enumerated()
        where abs(date.timeIntervalSince(target)) <= window {
            result.append(index)
        }
        return result
    }
}
