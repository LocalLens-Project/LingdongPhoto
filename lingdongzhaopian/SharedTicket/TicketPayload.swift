// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CryptoKit
import Compression
import Foundation
import SwiftUI

enum TicketCodeStyle: String, CaseIterable, Codable, Identifiable {
    case barcode
    case verificationQR

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barcode: "经典一维码"
        case .verificationQR: "验证二维码"
        }
    }

    var shortTitle: String {
        switch self {
        case .barcode: "一维码"
        case .verificationQR: "二维码"
        }
    }

    var symbol: String {
        switch self {
        case .barcode: "barcode"
        case .verificationQR: "qrcode"
        }
    }

    var explanation: String {
        switch self {
        case .barcode:
            "显示真实可扫描的票根编号，不包含照片或拍摄隐私，适合保存与分享。"
        case .verificationQR:
            "扫描后通过 App Clip 查看色盘、拍摄信息与文案，无需安装完整应用。"
        }
    }
}

enum TicketLayoutStyle: String, CaseIterable, Identifiable {
    case classic = "横向经典"
    case vertical = "纵向旅行"
    case minimal = "极简凭证"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .classic: "ticket"
        case .vertical: "rectangle.portrait"
        case .minimal: "rectangle.inset.filled"
        }
    }
}

enum TicketRevealLayout: String, Codable, Equatable {
    case classic = "c"
    case vertical = "v"
}

extension TicketLayoutStyle {
    var revealLayout: TicketRevealLayout? {
        switch self {
        case .classic: .classic
        case .vertical: .vertical
        case .minimal: nil
        }
    }
}

enum TicketHeaderMode: String, CaseIterable, Identifiable {
    case custom = "自定义"
    case city = "照片城市"

    var id: String { rawValue }
}

enum TicketCityNameStyle: String, CaseIterable, Identifiable {
    case pinyin = "拼音"
    case chinese = "中文"

    var id: String { rawValue }
}

struct TicketPaletteEntry: Codable, Equatable, Hashable, Identifiable {
    let hex: String
    let percentage: Double

    private enum CodingKeys: String, CodingKey {
        case hex = "h"
        case percentage = "p"
    }

    var id: String { "\(hex)-\(percentage)" }

    var color: Color {
        Color(ticketHex: hex)
    }
}

struct TicketPayload: Codable, Equatable, Identifiable {
    static let currentVersion = 1
    static let messageCharacterLimit = 80

    let version: Int
    let ticketID: String
    let fingerprint: String
    let headerTitle: String?
    let title: String
    let subtitle: String?
    let message: String?
    let captureTime: String?
    let place: String?
    let device: String?
    let lens: String?
    let captureSettings: String?
    let palette: [TicketPaletteEntry]
    let revealLayout: TicketRevealLayout?

    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case ticketID = "i"
        case fingerprint = "f"
        case headerTitle = "b"
        case title = "t"
        case subtitle = "s"
        case message = "m"
        case captureTime = "d"
        case place = "p"
        case device = "c"
        case lens = "l"
        case captureSettings = "e"
        case palette = "a"
        case revealLayout = "r"
    }

    var id: String { ticketID }

    init(
        version: Int = Self.currentVersion,
        ticketID: String,
        fingerprint: String,
        headerTitle: String? = nil,
        title: String,
        subtitle: String?,
        message: String? = nil,
        captureTime: String?,
        place: String?,
        device: String?,
        lens: String?,
        captureSettings: String?,
        palette: [TicketPaletteEntry],
        revealLayout: TicketRevealLayout? = nil
    ) {
        self.version = version
        self.ticketID = ticketID
        self.fingerprint = fingerprint
        self.headerTitle = headerTitle
        self.title = title
        self.subtitle = subtitle
        self.message = Self.normalizedMessage(message)
        self.captureTime = captureTime
        self.place = place
        self.device = device
        self.lens = lens
        self.captureSettings = captureSettings
        self.palette = Array(palette.prefix(6))
        self.revealLayout = revealLayout
    }

    static func normalizedMessage(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = String(value.prefix(messageCharacterLimit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    static func fingerprintText(from signature: UInt64) -> String {
        String(format: "%016llX", signature)
    }

    static func contentSignature(for data: Data, fallback: UInt64) -> UInt64 {
        guard !data.isEmpty else { return fallback }
        return SHA256.hash(data: data)
            .prefix(8)
            .reduce(UInt64.zero) { partial, byte in
                (partial << 8) | UInt64(byte)
            }
    }

    static func ticketIdentifier(from signature: UInt64) -> String {
        let high = UInt16((signature >> 32) & 0xFFFF)
        let low = UInt16(signature & 0xFFFF)
        return String(format: "LD-%04X-%04X", high, low)
    }

    static var sample: TicketPayload {
        TicketPayload(
            ticketID: "LD-7A2F-19C8",
            fingerprint: "7A2F41D819C8A350",
            headerTitle: "DA LI",
            title: "风把远方写进了这一刻",
            subtitle: "A quiet journey, kept in color.",
            message: "愿很多年以后，我们仍然记得海风吹来的方向。",
            captureTime: "2026/07/26, 10:24",
            place: "海边 · 夏日旅途",
            device: "Sony α7R II",
            lens: "FE 24-70mm F2.8 GM",
            captureSettings: "ƒ/4 · 1/320s · ISO 100 · 35mm",
            palette: [
                TicketPaletteEntry(hex: "#E9B477", percentage: 31.4),
                TicketPaletteEntry(hex: "#D97858", percentage: 22.8),
                TicketPaletteEntry(hex: "#5D7180", percentage: 17.6),
                TicketPaletteEntry(hex: "#263C48", percentage: 12.1),
                TicketPaletteEntry(hex: "#F0D8B8", percentage: 9.2),
                TicketPaletteEntry(hex: "#879B9B", percentage: 6.9)
            ],
            revealLayout: .classic
        )
    }

    func compacted(level: Int) -> TicketPayload {
        func trimmed(_ value: String?, limit: Int) -> String? {
            guard let value else { return nil }
            let result = String(value.prefix(limit))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? nil : result
        }

        switch level {
        case 0:
            return TicketPayload(
                ticketID: ticketID,
                fingerprint: fingerprint,
                headerTitle: trimmed(headerTitle, limit: 24),
                title: trimmed(title, limit: 56) ?? "一张影像票根",
                subtitle: trimmed(subtitle, limit: 72),
                message: trimmed(message, limit: Self.messageCharacterLimit),
                captureTime: trimmed(captureTime, limit: 32),
                place: trimmed(place, limit: 40),
                device: trimmed(device, limit: 48),
                lens: trimmed(lens, limit: 64),
                captureSettings: trimmed(captureSettings, limit: 64),
                palette: palette,
                revealLayout: revealLayout
            )
        case 1:
            return TicketPayload(
                ticketID: ticketID,
                fingerprint: fingerprint,
                headerTitle: trimmed(headerTitle, limit: 20),
                title: trimmed(title, limit: 42) ?? "一张影像票根",
                subtitle: trimmed(subtitle, limit: 42),
                message: trimmed(message, limit: Self.messageCharacterLimit),
                captureTime: trimmed(captureTime, limit: 24),
                place: trimmed(place, limit: 24),
                device: trimmed(device, limit: 32),
                lens: trimmed(lens, limit: 36),
                captureSettings: trimmed(captureSettings, limit: 40),
                palette: palette,
                revealLayout: revealLayout
            )
        default:
            return TicketPayload(
                ticketID: ticketID,
                fingerprint: fingerprint,
                headerTitle: trimmed(headerTitle, limit: 16),
                title: trimmed(title, limit: 34) ?? "一张影像票根",
                subtitle: nil,
                message: trimmed(message, limit: Self.messageCharacterLimit),
                captureTime: trimmed(captureTime, limit: 24),
                place: trimmed(place, limit: 20),
                device: trimmed(device, limit: 28),
                lens: nil,
                captureSettings: trimmed(captureSettings, limit: 32),
                palette: palette,
                revealLayout: revealLayout
            )
        }
    }
}

enum TicketEnvelopeError: LocalizedError, Equatable {
    case invalidURL
    case missingPayload
    case corruptedPayload
    case unsupportedVersion
    case payloadTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL: "这不是有效的影像票根链接。"
        case .missingPayload: "二维码没有提供影像票根数据。"
        case .corruptedPayload: "票根内容不完整或已被修改。"
        case .unsupportedVersion: "这张票根由更新版本生成，请升级后再试。"
        case .payloadTooLarge: "公开信息过多，无法生成稳定可扫描的二维码。"
        }
    }
}

enum TicketEnvelope {
    static let payloadKey = "t"
    static let checksumKey = "c"
    private static let maximumURLLength = 2_000
    private static let compressedPayloadMarker: UInt8 = 0x5A
    private static let plainPayloadMarker: UInt8 = 0x4A

    static var configuredBaseURLString: String {
        let configured = Bundle.main.object(
            forInfoDictionaryKey: "TicketAppClipBaseURL"
        ) as? String
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.hasPrefix("https://"), !trimmed.contains("$(") {
            return trimmed
        }
        return "https://appclip.apple.com/id?p=com.example.lingdongphoto.Clip"
    }

    static func invocationURL(
        for payload: TicketPayload,
        baseURLString: String = configuredBaseURLString
    ) throws -> URL {
        guard var components = URLComponents(string: baseURLString),
              components.scheme?.lowercased() == "https",
              components.host != nil else {
            throw TicketEnvelopeError.invalidURL
        }

        for level in 0...2 {
            let candidate = payload.compacted(level: level)
            let encoded = try encodedPayload(candidate)
            var queryItems = components.queryItems ?? []
            queryItems.removeAll { $0.name == payloadKey || $0.name == checksumKey }
            queryItems.append(URLQueryItem(name: payloadKey, value: encoded.token))
            queryItems.append(URLQueryItem(name: checksumKey, value: encoded.checksum))
            components.queryItems = queryItems
            if let url = components.url,
               url.absoluteString.utf8.count <= maximumURLLength {
                return url
            }
        }
        throw TicketEnvelopeError.payloadTooLarge
    }

    static func decode(from url: URL) throws -> TicketPayload {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw TicketEnvelopeError.invalidURL
        }
        let items = components.queryItems ?? []
        guard let token = items.first(where: { $0.name == payloadKey })?.value,
              let checksum = items.first(where: { $0.name == checksumKey })?.value else {
            throw TicketEnvelopeError.missingPayload
        }
        guard let envelopeData = Data(base64URLEncoded: token),
              checksumValue(for: envelopeData) == checksum.lowercased(),
              let payloadData = decodedPayloadData(from: envelopeData),
              let payload = try? JSONDecoder().decode(
                  TicketPayload.self,
                  from: payloadData
              ) else {
            throw TicketEnvelopeError.corruptedPayload
        }
        guard payload.version == TicketPayload.currentVersion else {
            throw TicketEnvelopeError.unsupportedVersion
        }
        return payload
    }

    static func barcodeValue(for payload: TicketPayload) -> String {
        // Keep the visible credential compact enough to remain reliably
        // scannable when it is embedded in the narrow ticket stub. An
        // even-length numeric value lets Code 128 use its dense Code Set C.
        let source = Data("\(payload.ticketID)|\(payload.fingerprint)".utf8)
        let digest = SHA256.hash(data: source)
        let value = digest.prefix(8).reduce(UInt64.zero) { partial, byte in
            (partial << 8) | UInt64(byte)
        } % 1_000_000_000_000
        return String(format: "%012llu", value)
    }

    private static func encodedPayload(
        _ payload: TicketPayload
    ) throws -> (token: String, checksum: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else {
            throw TicketEnvelopeError.corruptedPayload
        }
        let envelopeData: Data
        if let compressed = zlibCompressed(data),
           compressed.count < data.count {
            envelopeData = Data([compressedPayloadMarker]) + compressed
        } else {
            envelopeData = Data([plainPayloadMarker]) + data
        }
        return (
            envelopeData.base64URLEncodedString(),
            checksumValue(for: envelopeData)
        )
    }

    private static func decodedPayloadData(from envelopeData: Data) -> Data? {
        guard let marker = envelopeData.first else { return nil }
        let body = envelopeData.dropFirst()
        switch marker {
        case compressedPayloadMarker:
            return zlibDecompressed(Data(body))
        case plainPayloadMarker:
            return Data(body)
        default:
            // Backward compatibility with tickets generated before compact
            // transport was introduced, where the token was raw JSON.
            return envelopeData
        }
    }

    private static func zlibCompressed(_ data: Data) -> Data? {
        guard !data.isEmpty else { return data }
        let destinationCapacity = max(256, data.count * 2)
        var destination = Data(count: destinationCapacity)
        let encodedCount = data.withUnsafeBytes { sourceBytes in
            destination.withUnsafeMutableBytes { destinationBytes in
                guard
                    let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress,
                    let output = destinationBytes
                        .bindMemory(to: UInt8.self)
                        .baseAddress
                else {
                    return 0
                }
                return compression_encode_buffer(
                    output,
                    destinationCapacity,
                    source,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard encodedCount > 0 else { return nil }
        destination.count = encodedCount
        return destination
    }

    private static func zlibDecompressed(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        var destinationCapacity = max(1_024, data.count * 4)
        let maximumCapacity = 64 * 1_024

        while destinationCapacity <= maximumCapacity {
            var destination = Data(count: destinationCapacity)
            let decodedCount = data.withUnsafeBytes { sourceBytes in
                destination.withUnsafeMutableBytes { destinationBytes in
                    guard
                        let source = sourceBytes
                            .bindMemory(to: UInt8.self)
                            .baseAddress,
                        let output = destinationBytes
                            .bindMemory(to: UInt8.self)
                            .baseAddress
                    else {
                        return 0
                    }
                    return compression_decode_buffer(
                        output,
                        destinationCapacity,
                        source,
                        data.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }
            if decodedCount > 0 {
                destination.count = decodedCount
                return destination
            }
            destinationCapacity *= 2
        }
        return nil
    }

    private static func checksumValue(for data: Data) -> String {
        SHA256.hash(data: data)
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: base64)
    }
}

extension Color {
    init(ticketHex value: String) {
        let cleaned = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var number: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&number)
        if cleaned.count == 6 {
            self.init(
                red: Double((number >> 16) & 0xFF) / 255,
                green: Double((number >> 8) & 0xFF) / 255,
                blue: Double(number & 0xFF) / 255
            )
        } else {
            self = Color(red: 0.18, green: 0.39, blue: 0.24)
        }
    }
}
