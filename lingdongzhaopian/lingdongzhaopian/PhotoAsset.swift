// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreLocation
import Foundation
import ImageIO
import Photos
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct PhotoMetadata: Equatable {
    var make: String?
    var model: String?
    var lensModel: String?
    var aperture: Double?
    var exposureTime: Double?
    var iso: Int?
    var focalLength: Double?
    var captureDate: Date?
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var placeName: String?

    static let empty = PhotoMetadata()

    var hasLocation: Bool { latitude != nil && longitude != nil }

    var displayTitle: String {
        if let placeName, !placeName.isEmpty { return placeName }
        guard let latitude, let longitude else { return "此刻 · 光影留痕" }
        return String(format: "%.4f°, %.4f°", latitude, longitude)
    }

    var captureTimeText: String {
        guard let captureDate else { return "拍摄时间未记录" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: captureDate
        )
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute else {
            return "拍摄时间未记录"
        }
        return String(format: "%04d/%02d/%02d, %02d:%02d", year, month, day, hour, minute)
    }

    var deviceLine: String? {
        let device = [make, model]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { values, value in
                if !values.contains(where: { value.localizedCaseInsensitiveContains($0) }) {
                    values.append(value)
                }
            }
            .joined(separator: " ")
        guard !device.isEmpty else { return nil }
        return " 由 \(device) 记录这一瞬"
    }

    var cameraLine: String? {
        var values: [String] = []
        if let aperture, aperture > 0 {
            values.append("ƒ/\(Self.compactDecimal(aperture))")
        }
        if let exposureTime, exposureTime > 0 {
            if exposureTime < 1 {
                values.append("1/\(max(1, Int((1 / exposureTime).rounded())))s")
            } else {
                values.append("\(Self.compactDecimal(exposureTime))s")
            }
        }
        if let iso, iso > 0 { values.append("ISO \(iso)") }
        if let focalLength, focalLength > 0 {
            values.append("\(Self.compactDecimal(focalLength))mm")
        }

        let lens = Self.cleanedLensModel(
            lensModel,
            removingAperture: aperture.map { $0 > 0 } == true,
            removingFocalLength: focalLength.map { $0 > 0 } == true
        )
        let components = [lens].compactMap { $0 } + values
        guard !components.isEmpty else { return nil }
        return components.joined(separator: " · ")
    }

    private static func compactDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func cleanedLensModel(
        _ lensModel: String?,
        removingAperture: Bool,
        removingFocalLength: Bool
    ) -> String? {
        guard var value = lensModel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }

        if removingFocalLength {
            value = value.replacingOccurrences(
                of: #"(?i)\b\d+(?:\.\d+)?\s*mm\b"#,
                with: "",
                options: .regularExpression
            )
        }
        if removingAperture {
            value = value.replacingOccurrences(
                of: #"(?i)(?:ƒ|f)\s*/?\s*\d+(?:\.\d+)?"#,
                with: "",
                options: .regularExpression
            )
        }

        value = value
            .replacingOccurrences(of: #"\(\s*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(
                CharacterSet(charactersIn: "·,;/()-")
            ))
        return value.isEmpty ? nil : value
    }

    static func read(from data: Data) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return .empty
        }

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        let latitudeValue = number(gps?[kCGImagePropertyGPSLatitude])
        let longitudeValue = number(gps?[kCGImagePropertyGPSLongitude])
        let latitude = signedCoordinate(latitudeValue, reference: gps?[kCGImagePropertyGPSLatitudeRef] as? String)
        let longitude = signedCoordinate(longitudeValue, reference: gps?[kCGImagePropertyGPSLongitudeRef] as? String)
        let altitudeSign = number(gps?[kCGImagePropertyGPSAltitudeRef]) == 1 ? -1.0 : 1.0
        let isoValues = exif?[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber]

        return PhotoMetadata(
            make: tiff?[kCGImagePropertyTIFFMake] as? String,
            model: tiff?[kCGImagePropertyTIFFModel] as? String,
            lensModel: exif?[kCGImagePropertyExifLensModel] as? String,
            aperture: number(exif?[kCGImagePropertyExifFNumber]),
            exposureTime: number(exif?[kCGImagePropertyExifExposureTime]),
            iso: isoValues?.first?.intValue,
            focalLength: number(exif?[kCGImagePropertyExifFocalLength]),
            captureDate: parseDate(
                exif?[kCGImagePropertyExifDateTimeOriginal] as? String
                    ?? tiff?[kCGImagePropertyTIFFDateTime] as? String
            ),
            latitude: latitude,
            longitude: longitude,
            altitude: number(gps?[kCGImagePropertyGPSAltitude]).map { $0 * altitudeSign },
            placeName: nil
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func signedCoordinate(_ value: Double?, reference: String?) -> Double? {
        guard let value else { return nil }
        let isNegative = reference?.uppercased() == "S" || reference?.uppercased() == "W"
        return isNegative ? -value : value
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value)
    }
}

struct SelectedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let originalData: Data
    var metadata: PhotoMetadata
    let semantic: PhotoSemantic
    let pairedVideoURL: URL?
    let isLivePhoto: Bool
}

enum PhotoImportError: LocalizedError {
    case unreadableImage
    case unreadableLivePhoto
    case missingLivePhotoVideo

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "无法读取所选照片，请换一张照片后重试。"
        case .unreadableLivePhoto:
            "无法读取所选实况照片的动态内容，请确认原片已从 iCloud 下载后重试。"
        case .missingLivePhotoVideo:
            "所选实况照片没有提供可用的配对视频，请在系统照片中确认它仍可播放后重试。"
        }
    }
}

enum PhotoAssetLoader {
    private struct LivePhotoResourceInfo {
        let isLivePhoto: Bool
        let imageData: Data?
        let pairedVideoURL: URL?

        static let unavailable = LivePhotoResourceInfo(
            isLivePhoto: false,
            imageData: nil,
            pairedVideoURL: nil
        )
    }

    static func removeTemporaryResources(for photos: [SelectedPhoto]) {
        for url in photos.compactMap(\.pairedVideoURL) where url.lastPathComponent.hasPrefix("lingdong-live-") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func cleanupStaleTemporaryResources() {
        let directory = FileManager.default.temporaryDirectory
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let expiration = Date.now.addingTimeInterval(-24 * 60 * 60)
        for url in urls where url.lastPathComponent.hasPrefix("lingdong-live-") {
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if (modified ?? .distantPast) < expiration {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    static func load(_ selection: PhotoPickerSelection, includeLiveResource: Bool) async throws -> SelectedPhoto {
        let provider = selection.itemProvider
        let isLivePhoto = provider.canLoadObject(ofClass: PHLivePhoto.self)
        let resourceInfo: LivePhotoResourceInfo
        if isLivePhoto {
            guard let livePhoto = try await loadLivePhoto(from: provider) else {
                throw PhotoImportError.unreadableLivePhoto
            }
            resourceInfo = try await livePhotoResourceInfo(
                livePhoto: livePhoto,
                copyPairedVideo: includeLiveResource
            )
        } else {
            resourceInfo = .unavailable
        }

        let data: Data
        if let livePhotoImageData = resourceInfo.imageData {
            data = livePhotoImageData
        } else {
            data = try await loadImageData(from: provider)
        }
        guard let decodedImage = UIImage(data: data) else {
            throw PhotoImportError.unreadableImage
        }
        let image = DisplayImageNormalizer.standardDynamicRange(decodedImage)

        async let semanticAnalysis = PhotoContentAnalyzer.analyze(data)
        var metadata = PhotoMetadata.read(from: data)
        if let coordinate = metadataCoordinate(metadata) {
            metadata.placeName = await reverseGeocode(coordinate)
        }

        return SelectedPhoto(
            image: image,
            originalData: data,
            metadata: metadata,
            semantic: await semanticAnalysis,
            pairedVideoURL: resourceInfo.pairedVideoURL,
            isLivePhoto: isLivePhoto
        )
    }

    private static func loadLivePhoto(from provider: NSItemProvider) async throws -> PHLivePhoto? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: PHLivePhoto.self) { object, error in
                if let livePhoto = object as? PHLivePhoto {
                    continuation.resume(returning: livePhoto)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadImageData(from provider: NSItemProvider) async throws -> Data {
        let typeIdentifier = provider.registeredTypeIdentifiers.first { identifier in
            guard !identifier.localizedCaseInsensitiveContains("live-photo"),
                  let type = UTType(identifier) else { return false }
            return type.conforms(to: .image)
        }
        guard let typeIdentifier else {
            throw PhotoImportError.unreadableImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: PhotoImportError.unreadableImage)
                }
            }
        }
    }

    private static func metadataCoordinate(_ metadata: PhotoMetadata) -> CLLocation? {
        guard let latitude = metadata.latitude, let longitude = metadata.longitude else { return nil }
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: metadata.altitude ?? 0,
            horizontalAccuracy: 50,
            verticalAccuracy: 50,
            timestamp: metadata.captureDate ?? .now
        )
    }

    private static func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN"))
            guard let place = placemarks.first else { return nil }
            return [place.locality, place.subLocality, place.name]
                .compactMap { $0 }
                .reduce(into: [String]()) { result, component in
                    if !result.contains(component) { result.append(component) }
                }
                .prefix(2)
                .joined(separator: " · ")
        } catch {
            return nil
        }
    }

    private static func livePhotoResourceInfo(
        livePhoto: PHLivePhoto,
        copyPairedVideo: Bool
    ) async throws -> LivePhotoResourceInfo {
        guard copyPairedVideo else {
            return LivePhotoResourceInfo(
                isLivePhoto: true,
                imageData: nil,
                pairedVideoURL: nil
            )
        }

        // PHLivePhoto is loaded from the system picker's item provider. Its
        // resources therefore represent the item the user explicitly selected
        // and don't require direct PhotoKit library access.
        let resources = PHAssetResource.assetResources(for: livePhoto)
        let imageResource = resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo })
        let imageData: Data?
        if let imageResource {
            imageData = try await resourceData(imageResource)
        } else {
            imageData = nil
        }
        guard let resource = resources.first(where: { $0.type == .fullSizePairedVideo })
                ?? resources.first(where: { $0.type == .pairedVideo }) else {
            throw PhotoImportError.missingLivePhotoVideo
        }

        let extensionName = URL(fileURLWithPath: resource.originalFilename).pathExtension
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-live-\(UUID().uuidString)")
            .appendingPathExtension(extensionName.isEmpty ? "mov" : extensionName)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        do {
            try await write(resource, to: url, options: options)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        return LivePhotoResourceInfo(
            isLivePhoto: true,
            imageData: imageData,
            pairedVideoURL: url
        )
    }

    private static func resourceData(_ resource: PHAssetResource) async throws -> Data {
        let extensionName = URL(fileURLWithPath: resource.originalFilename).pathExtension
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-live-still-\(UUID().uuidString)")
            .appendingPathExtension(extensionName.isEmpty ? "heic" : extensionName)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        defer { try? FileManager.default.removeItem(at: url) }
        try await write(resource, to: url, options: options)
        return try Data(contentsOf: url)
    }

    private static func write(
        _ resource: PHAssetResource,
        to url: URL,
        options: PHAssetResourceRequestOptions
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
