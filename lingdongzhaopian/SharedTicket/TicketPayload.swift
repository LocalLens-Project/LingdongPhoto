// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CryptoKit
import Compression
import Foundation
import SwiftUI

extension String {
    /// Resolves runtime strings such as enum titles and generated copy through
    /// the same catalog used by SwiftUI string literals.
    nonisolated var appLocalized: String {
        Bundle.main.localizedString(
            forKey: self,
            value: self,
            table: "Localizable"
        )
    }
}

enum TicketCodeStyle: String, CaseIterable, Codable, Identifiable {
    case barcode
    case verificationQR

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barcode: "经典一维码".appLocalized
        case .verificationQR: "验证二维码".appLocalized
        }
    }

    var shortTitle: String {
        switch self {
        case .barcode: "一维码".appLocalized
        case .verificationQR: "二维码".appLocalized
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

enum TicketCanvasWidthMode: String, CaseIterable, Identifiable {
    case compact = "紧凑"
    case standard = "标准"
    case poster = "海报"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .compact: "rectangle.lefthalf.inset.filled"
        case .standard: "rectangle"
        case .poster: "photo"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .compact: 21.0 / 9.0
        case .standard: 16.0 / 9.0
        case .poster: 4.0 / 3.0
        }
    }
}

enum TicketRevealLayout: String, Codable, Equatable {
    case classic = "c"
    case vertical = "v"
}

enum TicketRevealWidthMode: String, Codable, Equatable {
    case compact = "c"
    case standard = "s"
    case poster = "p"

    var portraitAspectRatio: CGFloat {
        switch self {
        case .compact: 21.0 / 9.0
        case .standard: 16.0 / 9.0
        case .poster: 4.0 / 3.0
        }
    }
}

nonisolated enum TicketSealOrigin: String, Equatable {
    case appleSecureEnclave = "apple-se"
    case androidHardware = "android-hw"
    case androidSoftware = "android-sw"
    case simulatorTest = "sim-test"
    case unknown

    init(wireValue: String) {
        self = Self(rawValue: wireValue) ?? .unknown
    }

    var isHardwareBacked: Bool {
        self == .appleSecureEnclave || self == .androidHardware
    }
}

nonisolated struct TicketEnvelopeSignature: Equatable {
    static let algorithm = "ES256"
    private static let domain = "LingdongPhoto/TicketSeal/v1"

    let publicKey: Data
    let signature: Data
    let origin: TicketSealOrigin

    static func signingData(
        payloadData: Data,
        publicKey: Data,
        origin: TicketSealOrigin
    ) -> Data {
        var data = Data("\(domain)\0\(algorithm)\0\(origin.rawValue)\0".utf8)
        data.append(publicKey)
        data.append(0)
        data.append(payloadData)
        return data
    }
}

nonisolated protocol TicketEnvelopeSigning {
    func signature(for payloadData: Data) throws -> TicketEnvelopeSignature
}

nonisolated enum TicketSealValidation: Equatable {
    case unsigned
    case valid(origin: TicketSealOrigin, keyID: String)
    case invalid(origin: TicketSealOrigin, keyID: String?)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

nonisolated struct VerifiedTicket: Equatable, Identifiable {
    let payload: TicketPayload
    let sealValidation: TicketSealValidation
    let sourceURL: URL?

    var id: String { payload.id }

    static func unsigned(_ payload: TicketPayload) -> VerifiedTicket {
        VerifiedTicket(
            payload: payload,
            sealValidation: .unsigned,
            sourceURL: nil
        )
    }
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

extension TicketCanvasWidthMode {
    var revealWidthMode: TicketRevealWidthMode {
        switch self {
        case .compact: .compact
        case .standard: .standard
        case .poster: .poster
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

nonisolated struct TicketPaletteEntry: Codable, Equatable, Hashable, Identifiable {
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

nonisolated struct TicketPayload: Codable, Equatable, Identifiable {
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
    let revealWidthMode: TicketRevealWidthMode?
    let style: String?
    let narrative: String?
    let sealedAt: String?

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
        case revealWidthMode = "w"
        case style = "x"
        case narrative = "n"
        case sealedAt = "q"
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
        revealLayout: TicketRevealLayout? = nil,
        revealWidthMode: TicketRevealWidthMode? = nil,
        style: String? = nil,
        narrative: String? = nil,
        sealedAt: String? = nil
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
        self.revealWidthMode = revealWidthMode
        self.style = style
        self.narrative = narrative
        self.sealedAt = sealedAt
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
            revealLayout: .classic,
            revealWidthMode: .compact,
            sealedAt: "2026/07/26, 10:24"
        )
    }

    var isEmotionalStyle: Bool { style == "e" }

    var isSelfNarrative: Bool {
        guard let narrative else { return true }
        return narrative == "self"
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
                revealLayout: revealLayout,
                revealWidthMode: revealWidthMode,
                style: style,
                narrative: narrative,
                sealedAt: sealedAt
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
                revealLayout: revealLayout,
                revealWidthMode: revealWidthMode,
                style: style,
                narrative: narrative,
                sealedAt: sealedAt
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
                revealLayout: revealLayout,
                revealWidthMode: revealWidthMode,
                style: style,
                narrative: narrative,
                sealedAt: sealedAt
            )
        }
    }
}

nonisolated enum TicketEnvelopeError: LocalizedError, Equatable {
    case invalidURL
    case missingPayload
    case corruptedPayload
    case unsupportedVersion
    case payloadTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL: "这不是有效的影像票根链接。".appLocalized
        case .missingPayload: "二维码没有提供影像票根数据。".appLocalized
        case .corruptedPayload: "票根内容不完整或已被修改。".appLocalized
        case .unsupportedVersion: "这张票根由更新版本生成，请升级后再试。".appLocalized
        case .payloadTooLarge: "公开信息过多，无法生成稳定可扫描的二维码。".appLocalized
        }
    }
}

nonisolated enum TicketEnvelope {
    static let payloadKey = "t"
    static let checksumKey = "c"
    static let sealAlgorithmKey = "a"
    static let sealPublicKey = "k"
    static let sealSignatureKey = "s"
    static let sealOriginKey = "o"
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
        baseURLString: String = configuredBaseURLString,
        signer: TicketEnvelopeSigning? = nil
    ) throws -> URL {
        guard var components = URLComponents(string: baseURLString),
              components.scheme?.lowercased() == "https",
              components.host != nil else {
            throw TicketEnvelopeError.invalidURL
        }

        let sealLengthReserve = signer != nil ? 220 : 0

        for level in 0...2 {
            let candidate = payload.compacted(level: level)
            let encoded = try encodedPayload(candidate)
            var queryItems = components.queryItems ?? []
            let reservedKeys = Set([
                payloadKey,
                checksumKey,
                sealAlgorithmKey,
                sealPublicKey,
                sealSignatureKey,
                sealOriginKey
            ])
            queryItems.removeAll { reservedKeys.contains($0.name) }
            queryItems.append(URLQueryItem(name: payloadKey, value: encoded.token))
            queryItems.append(URLQueryItem(name: checksumKey, value: encoded.checksum))
            components.queryItems = queryItems
            guard let unsignedURL = components.url,
                  unsignedURL.absoluteString.utf8.count + sealLengthReserve
                      <= maximumURLLength else {
                continue
            }
            let signature = try signer?.signature(for: encoded.payloadData)
            if let signature {
                queryItems.append(URLQueryItem(
                    name: sealAlgorithmKey,
                    value: TicketEnvelopeSignature.algorithm
                ))
                queryItems.append(URLQueryItem(
                    name: sealPublicKey,
                    value: signature.publicKey.base64URLEncodedString()
                ))
                queryItems.append(URLQueryItem(
                    name: sealSignatureKey,
                    value: signature.signature.base64URLEncodedString()
                ))
                queryItems.append(URLQueryItem(
                    name: sealOriginKey,
                    value: signature.origin.rawValue
                ))
            }
            components.queryItems = queryItems
            if let url = components.url,
               url.absoluteString.utf8.count <= maximumURLLength {
                return url
            }
        }
        throw TicketEnvelopeError.payloadTooLarge
    }

    static func decode(from url: URL) throws -> TicketPayload {
        try decodeVerified(from: url).payload
    }

    static func decodeVerified(from url: URL) throws -> VerifiedTicket {
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
        return VerifiedTicket(
            payload: payload,
            sealValidation: sealValidation(for: items, payloadData: payloadData),
            sourceURL: url
        )
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
    ) throws -> (token: String, checksum: String, payloadData: Data) {
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
            checksumValue(for: envelopeData),
            data
        )
    }

    private static func sealValidation(
        for items: [URLQueryItem],
        payloadData: Data
    ) -> TicketSealValidation {
        let values = items.reduce(into: [String: String]()) { result, item in
            guard result[item.name] == nil, let value = item.value else { return }
            result[item.name] = value
        }
        let reserved = [
            sealAlgorithmKey,
            sealPublicKey,
            sealSignatureKey,
            sealOriginKey
        ]
        guard reserved.contains(where: { values[$0] != nil }) else {
            return .unsigned
        }

        let origin = TicketSealOrigin(
            wireValue: values[sealOriginKey] ?? TicketSealOrigin.unknown.rawValue
        )
        guard values[sealAlgorithmKey] == TicketEnvelopeSignature.algorithm,
              let publicKeyValue = values[sealPublicKey],
              let signatureValue = values[sealSignatureKey],
              let publicKeyData = Data(base64URLEncoded: publicKeyValue),
              let signatureData = Data(base64URLEncoded: signatureValue) else {
            return .invalid(origin: origin, keyID: nil)
        }

        let keyID = sealKeyID(for: publicKeyData)
        do {
            let publicKey = try P256.Signing.PublicKey(
                x963Representation: publicKeyData
            )
            let signature = try P256.Signing.ECDSASignature(
                derRepresentation: signatureData
            )
            let signingData = TicketEnvelopeSignature.signingData(
                payloadData: payloadData,
                publicKey: publicKeyData,
                origin: origin
            )
            return publicKey.isValidSignature(signature, for: signingData)
                ? .valid(origin: origin, keyID: keyID)
                : .invalid(origin: origin, keyID: keyID)
        } catch {
            return .invalid(origin: origin, keyID: keyID)
        }
    }

    private static func sealKeyID(for publicKey: Data) -> String {
        SHA256.hash(data: publicKey)
            .prefix(6)
            .map { String(format: "%02X", $0) }
            .joined()
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
    nonisolated func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated init?(base64URLEncoded value: String) {
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
    nonisolated init(ticketHex value: String) {
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

enum TicketNarrativeStyle: String, CaseIterable, Identifiable {
    case standard = "s"
    case emotional = "e"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "标准模式".appLocalized
        case .emotional: "时光胶囊".appLocalized
        }
    }

    var description: String {
        switch self {
        case .standard:
            "扫描后显示照片指纹、设备封印等技术信息".appLocalized
        case .emotional:
            "扫描后显示时光跨度与情感化文案，适合留念与分享".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .standard: "checkmark.shield"
        case .emotional: "clock.arrow.circlepath"
        }
    }
}

enum TicketNarrativePerspective: String, CaseIterable, Identifiable {
    case `self` = "self"
    case shared = "shared"

    static var defaultRawValue: String { "self" }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .self: "写给未来的我".appLocalized
        case .shared: "分享给朋友".appLocalized
        }
    }

    var description: String {
        switch self {
        case .self:
            "用私域口吻呈现，适合自己收藏、偶尔回看".appLocalized
        case .shared:
            "用温暖中性的口吻呈现，适合分享到朋友圈或发给朋友".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .self: "person.text.rectangle"
        case .shared: "person.2.text.rectangle"
        }
    }
}

enum TicketTimeCalculator {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd, HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    static func daysSinceCapture(_ captureTime: String?) -> Int? {
        guard let captureTime,
              let date = formatter.date(from: captureTime) else {
            return nil
        }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: date, to: now)
        return components.day
    }

    static func daysBetweenCaptureAndSeal(
        captureTime: String?,
        sealedAt: String?
    ) -> Int? {
        guard let captureTime, let sealedAt,
              let captureDate = formatter.date(from: captureTime),
              let sealDate = formatter.date(from: sealedAt) else {
            return nil
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: captureDate, to: sealDate)
        return components.day
    }

    static func formattedTimeSinceCapture(_ captureTime: String?) -> String? {
        guard let days = daysSinceCapture(captureTime) else { return nil }
        return formattedDayCount(days)
    }

    static func formattedTimeSinceSeal(_ sealedAt: String?) -> String? {
        guard let sealedAt,
              let date = formatter.date(from: sealedAt) else {
            return nil
        }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: date, to: now)
        guard let days = components.day else { return nil }
        return formattedDayCount(days)
    }

    private static func formattedDayCount(_ days: Int) -> String {
        if days <= 0 {
            return "今天".appLocalized
        } else if days == 1 {
            return "昨天".appLocalized
        } else if days < 30 {
            return "(days) 天前".appLocalized
                .replacingOccurrences(of: "(days)", with: String(days))
        } else if days < 365 {
            let months = days / 30
            return "(months) 个月前".appLocalized
                .replacingOccurrences(of: "(months)", with: String(months))
        } else {
            let years = days / 365
            let remainingDays = days % 365
            if remainingDays < 30 {
                return "(years) 年前".appLocalized
                    .replacingOccurrences(of: "(years)", with: String(years))
            } else {
                let months = remainingDays / 30
                return "(years) 年 (months) 个月前".appLocalized
                    .replacingOccurrences(of: "(years)", with: String(years))
                    .replacingOccurrences(of: "(months)", with: String(months))
            }
        }
    }

    static func nowFormatted() -> String {
        formatter.string(from: Date())
    }
}
