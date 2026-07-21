// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

enum SharedPhotoHandoff {
    static let urlScheme = "lingdongphoto"

    struct Item {
        let imageData: Data
        let pairedVideoURL: URL?
        let isLivePhoto: Bool
        let assetLocalIdentifier: String?
    }

    struct Import {
        let items: [Item]
        let modeRawValue: String?
    }

    static func receiveImport() -> Import? {
        receiveSharedContainerImport()
    }

    private static func receiveSharedContainerImport() -> Import? {
        guard let appGroupIdentifier = Bundle.main.object(
            forInfoDictionaryKey: "LingdongAppGroupIdentifier"
        ) as? String,
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        let inboxURL = containerURL.appendingPathComponent("PendingShareImport", isDirectory: true)
        let manifestURL = inboxURL.appendingPathComponent("manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: manifestData) else {
            return nil
        }

        defer { try? FileManager.default.removeItem(at: inboxURL) }
        guard Date.now.timeIntervalSince(manifest.createdAt) < 600 else { return nil }
        let records = manifest.assets ?? manifest.filenames?.map {
            Manifest.Asset(
                imageFilename: $0,
                pairedVideoFilename: nil,
                isLivePhoto: false,
                assetLocalIdentifier: nil
            )
        } ?? []
        let items = records.prefix(5).compactMap { record -> Item? in
            guard let imageData = try? Data(
                contentsOf: inboxURL.appendingPathComponent(record.imageFilename)
            ) else { return nil }
            let pairedVideoURL = record.pairedVideoFilename.flatMap { filename in
                copyPairedVideoToTemporaryDirectory(
                    from: inboxURL.appendingPathComponent(filename)
                )
            }
            return Item(
                imageData: imageData,
                pairedVideoURL: pairedVideoURL,
                isLivePhoto: record.isLivePhoto,
                assetLocalIdentifier: record.assetLocalIdentifier
            )
        }
        guard !items.isEmpty else { return nil }
        return Import(items: items, modeRawValue: manifest.modeRawValue)
    }

    private static func copyPairedVideoToTemporaryDirectory(from sourceURL: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-live-shared-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            guard fileSize(at: destinationURL) > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return destinationURL
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            return nil
        }
    }

    private static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private struct Manifest: Codable {
        struct Asset: Codable {
            let imageFilename: String
            let pairedVideoFilename: String?
            let isLivePhoto: Bool
            let assetLocalIdentifier: String?
        }

        let modeRawValue: String
        let assets: [Asset]?
        let filenames: [String]?
        let createdAt: Date
    }
}
