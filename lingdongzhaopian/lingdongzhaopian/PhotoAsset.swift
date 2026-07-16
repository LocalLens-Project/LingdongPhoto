// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreLocation
import ImageIO
import Photos
import PhotosUI
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
        return captureDate.formatted(
            .dateTime
                .year().month(.twoDigits).day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        )
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
        if let aperture, aperture > 0 { values.append(String(format: "ƒ/%.1f", aperture)) }
        if let exposureTime, exposureTime > 0 {
            if exposureTime < 1 {
                values.append("1/\(max(1, Int((1 / exposureTime).rounded())))s")
            } else {
                values.append(String(format: "%.1fs", exposureTime))
            }
        }
        if let iso, iso > 0 { values.append("ISO \(iso)") }
        if let focalLength, focalLength > 0 { values.append(String(format: "%.0fmm", focalLength)) }
        guard !values.isEmpty else { return nil }
        let lens = lensModel.map { "\($0) · " } ?? ""
        return "\(lens)\(values.joined(separator: " · "))"
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
    let assetLocalIdentifier: String?
    let pairedVideoURL: URL?
    let isLivePhoto: Bool
}

enum PhotoImportError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "无法读取所选照片，请换一张照片后重试。"
        }
    }
}

enum PhotoAssetLoader {
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

    static func load(_ item: PhotosPickerItem, includeLiveResource: Bool) async throws -> SelectedPhoto {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw PhotoImportError.unreadableImage
        }

        async let semanticAnalysis = PhotoContentAnalyzer.analyze(data)
        var metadata = PhotoMetadata.read(from: data)
        if let coordinate = metadataCoordinate(metadata) {
            metadata.placeName = await reverseGeocode(coordinate)
        }

        let isLivePhoto = item.supportedContentTypes.contains { type in
            type.conforms(to: .livePhoto)
        }
        var pairedVideoURL: URL?
        if includeLiveResource, isLivePhoto, let identifier = item.itemIdentifier {
            pairedVideoURL = try? await copyPairedVideo(assetIdentifier: identifier)
        }

        return SelectedPhoto(
            image: image,
            originalData: data,
            metadata: metadata,
            semantic: await semanticAnalysis,
            assetLocalIdentifier: item.itemIdentifier,
            pairedVideoURL: pairedVideoURL,
            isLivePhoto: isLivePhoto
        )
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

    private static func copyPairedVideo(assetIdentifier: String) async throws -> URL? {
        let authorization = await photoLibraryAuthorization()
        guard authorization == .authorized || authorization == .limited else { return nil }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .fullSizePairedVideo })
                ?? resources.first(where: { $0.type == .pairedVideo }) else { return nil }

        let extensionName = URL(fileURLWithPath: resource.originalFilename).pathExtension
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-live-\(UUID().uuidString)")
            .appendingPathExtension(extensionName.isEmpty ? "mov" : extensionName)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        return url
    }

    private static func photoLibraryAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
