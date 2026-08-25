// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct AlbumImportedPayload {
    let data: Data
    let fileExtension: String
    let image: UIImage
    let captureDate: Date?
}

enum AlbumImportError: LocalizedError {
    case unavailable
    case unreadable
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: "没有读取到可用图片，请重新选择。".appLocalized
        case .unreadable: "图片无法解码，请换一张后重试。".appLocalized
        case .writeFailed: "无法把图片保存到本地相簿项目。".appLocalized
        }
    }
}

enum AlbumImageImporter {
    static func load(_ selection: PhotoPickerSelection) async throws -> AlbumImportedPayload {
        if let sharedItem = selection.sharedItem {
            return try makePayload(data: sharedItem.imageData, suggestedExtension: "jpg")
        }
        guard let provider = selection.itemProvider else {
            throw AlbumImportError.unavailable
        }
        guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: { identifier in
            guard !identifier.localizedCaseInsensitiveContains("live-photo"),
                  let type = UTType(identifier) else { return false }
            return type.conforms(to: .image)
        }) else {
            throw AlbumImportError.unavailable
        }
        let data = try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: AlbumImportError.unavailable)
                }
            }
        }
        let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "jpg"
        return try makePayload(data: data, suggestedExtension: fileExtension)
    }

    static func load(url: URL) throws -> AlbumImportedPayload {
        try makePayload(
            data: Data(contentsOf: url),
            suggestedExtension: url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        )
    }

    private static func makePayload(
        data: Data,
        suggestedExtension: String
    ) throws -> AlbumImportedPayload {
        guard let decoded = UIImage(data: data) else { throw AlbumImportError.unreadable }
        let image = DisplayImageNormalizer.standardDynamicRange(decoded)
        return AlbumImportedPayload(
            data: data,
            fileExtension: sanitizedExtension(suggestedExtension),
            image: image,
            captureDate: PhotoMetadata.read(from: data).captureDate
        )
    }

    private static func sanitizedExtension(_ value: String) -> String {
        let cleaned = value.lowercased().filter { $0.isLetter || $0.isNumber }
        return cleaned.isEmpty ? "jpg" : String(cleaned.prefix(8))
    }
}

@MainActor
final class AlbumProjectStore: ObservableObject {
    @Published private(set) var projects: [AlbumProject] = []

    private let fileManager = FileManager.default
    private let rootURL: URL
    private let imageCache = NSCache<NSString, UIImage>()

    init(rootURL: URL? = nil) {
        self.rootURL = rootURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LingdongAlbums", isDirectory: true)
        try? fileManager.createDirectory(
            at: self.rootURL,
            withIntermediateDirectories: true
        )
        loadProjects()
    }

    func project(id: UUID) -> AlbumProject? {
        projects.first { $0.id == id }
    }

    @discardableResult
    func createProject(
        template: AlbumTemplateDescriptor,
        format: AlbumBookFormat
    ) -> UUID {
        let project = AlbumTemplateCatalog.makeProject(from: template, format: format)
        projects.insert(project, at: 0)
        save(project)
        return project.id
    }

    func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
        imageCache.removeAllObjects()
        try? fileManager.removeItem(at: projectDirectory(id))
    }

    func renameProject(id: UUID, title: String, subtitle: String) {
        mutate(id) { project in
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty { project.title = String(cleanTitle.prefix(40)) }
            project.subtitle = String(cleanSubtitle.prefix(80))
            if let coverIndex = project.pages.firstIndex(where: { $0.role == .cover }) {
                let editable = project.pages[coverIndex].textBlocks.indices.filter {
                    project.pages[coverIndex].textBlocks[$0].isEditable
                }
                if let first = editable.first {
                    project.pages[coverIndex].textBlocks[first].text = project.title
                }
                if editable.count > 1 {
                    project.pages[coverIndex].textBlocks[editable[1]].text = project.subtitle
                }
            }
        }
    }

    func updateText(projectID: UUID, pageID: UUID, textID: UUID, value: String) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }),
                  let textIndex = project.pages[pageIndex].textBlocks.firstIndex(where: { $0.id == textID }) else {
                return
            }
            project.pages[pageIndex].textBlocks[textIndex].text = String(value.prefix(240))
        }
    }

    func updatePageFont(
        projectID: UUID,
        pageID: UUID,
        fontStyle: AlbumPageFontStyle
    ) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }) else { return }
            project.pages[pageIndex].fontStyle = fontStyle == .template ? nil : fontStyle
        }
    }

    func updateSlotContentTransform(
        projectID: UUID,
        pageID: UUID,
        slotID: UUID,
        scale: Double,
        offsetX: Double,
        offsetY: Double
    ) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }),
                  let slotIndex = project.pages[pageIndex].slots.firstIndex(where: { $0.id == slotID }),
                  let assetID = project.pages[pageIndex].slots[slotIndex].assetID,
                  let asset = project.assets.first(where: { $0.id == assetID }),
                  !asset.locksContentTransform else { return }
            project.pages[pageIndex].slots[slotIndex].contentScale = max(1, min(6, scale))
            project.pages[pageIndex].slots[slotIndex].contentOffsetX = max(-1, min(1, offsetX))
            project.pages[pageIndex].slots[slotIndex].contentOffsetY = max(-1, min(1, offsetY))
        }
    }

    func resetSlotContentTransform(projectID: UUID, pageID: UUID, slotID: UUID) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }),
                  let slotIndex = project.pages[pageIndex].slots.firstIndex(where: { $0.id == slotID }) else { return }
            project.pages[pageIndex].slots[slotIndex].contentScale = nil
            project.pages[pageIndex].slots[slotIndex].contentOffsetX = nil
            project.pages[pageIndex].slots[slotIndex].contentOffsetY = nil
        }
    }

    @discardableResult
    func importAsset(
        _ payload: AlbumImportedPayload,
        kind: AlbumAssetKind,
        workKind: String?,
        projectID: UUID
    ) throws -> UUID {
        guard let project = project(id: projectID) else { throw AlbumImportError.writeFailed }
        let id = UUID()
        let directory = projectDirectory(projectID)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "asset-\(id.uuidString).\(payload.fileExtension)"
        let thumbnailFileName = "thumb-\(id.uuidString).jpg"
        do {
            try payload.data.write(
                to: directory.appendingPathComponent(fileName),
                options: .atomic
            )
            guard let thumbnail = payload.image.albumScaled(maxDimension: 720),
                  let thumbnailData = thumbnail.jpegData(compressionQuality: 0.86) else {
                throw AlbumImportError.writeFailed
            }
            try thumbnailData.write(
                to: directory.appendingPathComponent(thumbnailFileName),
                options: .atomic
            )
        } catch {
            try? fileManager.removeItem(at: directory.appendingPathComponent(fileName))
            throw AlbumImportError.writeFailed
        }

        let pixelSize = payload.image.albumPixelSize
        let palette = PaletteExtractor.extract(from: payload.image, colorCount: 4)
            .colors
            .map(AlbumColor.init)
        let asset = AlbumAsset(
            id: id,
            kind: kind,
            workKind: workKind,
            fileName: fileName,
            thumbnailFileName: thumbnailFileName,
            pixelWidth: max(1, Int(pixelSize.width.rounded())),
            pixelHeight: max(1, Int(pixelSize.height.rounded())),
            importedAt: .now,
            captureDate: payload.captureDate,
            colors: palette
        )
        var updated = project
        updated.assets.append(asset)
        updated.modifiedAt = .now
        replace(updated)
        imageCache.setObject(payload.image, forKey: cacheKey(projectID, id, false))
        if let thumbnail = payload.image.albumScaled(maxDimension: 720) {
            imageCache.setObject(thumbnail, forKey: cacheKey(projectID, id, true))
        }
        return id
    }

    func placeAsset(
        _ assetID: UUID,
        projectID: UUID,
        pageID: UUID,
        slotID: UUID?
    ) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }),
                  let asset = project.assets.first(where: { $0.id == assetID }) else { return }
            if let slotID,
               let slotIndex = project.pages[pageIndex].slots.firstIndex(where: { $0.id == slotID }) {
                project.pages[pageIndex].slots[slotIndex].assetID = assetID
                project.pages[pageIndex].slots[slotIndex].contentScale = nil
                project.pages[pageIndex].slots[slotIndex].contentOffsetX = nil
                project.pages[pageIndex].slots[slotIndex].contentOffsetY = nil
                if asset.kind == .work {
                    project.pages[pageIndex].slots[slotIndex].fit = .fit
                }
            } else {
                let count = project.pages[pageIndex].slots.count
                let offset = min(Double(count) * 0.035, 0.14)
                project.pages[pageIndex].slots.append(AlbumSlot(
                    frame: AlbumNormalizedRect(0.14 + offset, 0.17 + offset, 0.68, 0.56),
                    expectation: asset.kind == .work ? .work : .any,
                    assetID: assetID,
                    fit: asset.kind == .work ? .fit : .fill,
                    cornerRadius: 0.008,
                    rotation: count.isMultiple(of: 2) ? -1.5 : 1.5,
                    zIndex: count
                ))
            }
            recalculatePalette(&project)
        }
    }

    func batchPlaceAssets(_ assetIDs: [UUID], projectID: UUID) {
        mutate(projectID) { project in
            var pending = assetIDs.compactMap { id in project.assets.first { $0.id == id } }
            guard !pending.isEmpty else { return }
            for pageIndex in project.pages.indices {
                for slotIndex in project.pages[pageIndex].slots.indices where !pending.isEmpty {
                    guard project.pages[pageIndex].slots[slotIndex].assetID == nil else { continue }
                    let expectation = project.pages[pageIndex].slots[slotIndex].expectation
                    let compatibleIndex = pending.indices.min { left, right in
                        compatibilityScore(
                            pending[left],
                            slot: project.pages[pageIndex].slots[slotIndex],
                            expectation: expectation,
                            format: project.format
                        ) < compatibilityScore(
                            pending[right],
                            slot: project.pages[pageIndex].slots[slotIndex],
                            expectation: expectation,
                            format: project.format
                        )
                    }
                    guard let compatibleIndex,
                          isCompatible(pending[compatibleIndex].kind, expectation: expectation) else { continue }
                    let asset = pending.remove(at: compatibleIndex)
                    project.pages[pageIndex].slots[slotIndex].assetID = asset.id
                    if asset.kind == .work {
                        project.pages[pageIndex].slots[slotIndex].fit = .fit
                    }
                }
            }
            recalculatePalette(&project)
        }
    }

    func removeAssetFromSlot(projectID: UUID, pageID: UUID, slotID: UUID) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }),
                  let slotIndex = project.pages[pageIndex].slots.firstIndex(where: { $0.id == slotID }) else {
                return
            }
            if project.pages[pageIndex].layout == .freeform {
                project.pages[pageIndex].slots.remove(at: slotIndex)
            } else {
                project.pages[pageIndex].slots[slotIndex].assetID = nil
            }
            recalculatePalette(&project)
        }
    }

    func toggleFit(projectID: UUID, pageID: UUID, slotID: UUID) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }),
                  let slotIndex = project.pages[pageIndex].slots.firstIndex(where: { $0.id == slotID }) else {
                return
            }
            let current = project.pages[pageIndex].slots[slotIndex].fit
            project.pages[pageIndex].slots[slotIndex].fit = current == .fill ? .fit : .fill
            project.pages[pageIndex].slots[slotIndex].contentScale = nil
            project.pages[pageIndex].slots[slotIndex].contentOffsetX = nil
            project.pages[pageIndex].slots[slotIndex].contentOffsetY = nil
        }
    }

    func adjustFreeformSlot(
        projectID: UUID,
        pageID: UUID,
        slotID: UUID,
        scale: Double = 1,
        rotation: Double = 0,
        x: Double = 0,
        y: Double = 0
    ) {
        mutate(projectID) { project in
            guard let pageIndex = project.pages.firstIndex(where: { $0.id == pageID }),
                  project.pages[pageIndex].layout == .freeform,
                  let slotIndex = project.pages[pageIndex].slots.firstIndex(where: { $0.id == slotID }) else {
                return
            }
            var frame = project.pages[pageIndex].slots[slotIndex].frame
            let newWidth = (frame.width * scale).clamped(to: 0.15...0.94)
            let newHeight = (frame.height * scale).clamped(to: 0.12...0.94)
            frame.x = (frame.x + x - (newWidth - frame.width) / 2).clamped(to: 0...(1 - newWidth))
            frame.y = (frame.y + y - (newHeight - frame.height) / 2).clamped(to: 0...(1 - newHeight))
            frame.width = newWidth
            frame.height = newHeight
            project.pages[pageIndex].slots[slotIndex].frame = frame
            project.pages[pageIndex].slots[slotIndex].rotation = (
                project.pages[pageIndex].slots[slotIndex].rotation + rotation
            ).clamped(to: -18...18)
        }
    }

    func addPage(projectID: UUID, layout: AlbumPageLayout) {
        mutate(projectID) { project in
            let insertion = project.pages.lastIndex(where: { $0.role != .backCover })
                .map { $0 + 1 } ?? project.pages.count
            let page = AlbumTemplateCatalog.makePage(
                layout: layout,
                theme: project.theme,
                pageNumber: insertion + 1
            )
            project.pages.insert(page, at: insertion)
            renumberPages(&project)
        }
    }

    func duplicatePage(projectID: UUID, pageID: UUID) {
        mutate(projectID) { project in
            guard let index = project.pages.firstIndex(where: { $0.id == pageID }),
                  project.pages[index].role == .content else { return }
            var page = project.pages[index]
            page.id = UUID()
            page.slots = page.slots.map { slot in
                var copy = slot
                copy.id = UUID()
                return copy
            }
            page.textBlocks = page.textBlocks.map { block in
                var copy = block
                copy.id = UUID()
                return copy
            }
            project.pages.insert(page, at: index + 1)
            renumberPages(&project)
        }
    }

    func deletePage(projectID: UUID, pageID: UUID) {
        mutate(projectID) { project in
            guard project.pages.count > 3,
                  let index = project.pages.firstIndex(where: { $0.id == pageID }),
                  project.pages[index].role == .content else { return }
            project.pages.remove(at: index)
            renumberPages(&project)
            recalculatePalette(&project)
        }
    }

    func movePage(projectID: UUID, pageID: UUID, direction: Int) {
        mutate(projectID) { project in
            guard let index = project.pages.firstIndex(where: { $0.id == pageID }),
                  project.pages[index].role == .content else { return }
            let destination = index + direction
            guard project.pages.indices.contains(destination),
                  project.pages[destination].role == .content else { return }
            let page = project.pages.remove(at: index)
            project.pages.insert(page, at: destination)
            renumberPages(&project)
        }
    }

    func image(projectID: UUID, assetID: UUID, thumbnail: Bool = false) -> UIImage? {
        let key = cacheKey(projectID, assetID, thumbnail)
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let project = project(id: projectID),
              let asset = project.assets.first(where: { $0.id == assetID }) else { return nil }
        let fileName = thumbnail ? asset.thumbnailFileName : asset.fileName
        guard let image = UIImage(contentsOfFile: projectDirectory(projectID)
            .appendingPathComponent(fileName).path) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    func pageImages(projectID: UUID) -> [UUID: UIImage] {
        guard let project = project(id: projectID) else { return [:] }
        return Dictionary(uniqueKeysWithValues: project.assets.compactMap { asset in
            image(projectID: projectID, assetID: asset.id).map { (asset.id, $0) }
        })
    }

    private func loadProjects() {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        projects = directories.compactMap { directory in
            let url = directory.appendingPathComponent("project.json")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(AlbumProject.self, from: data)
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func mutate(_ id: UUID, update: (inout AlbumProject) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        var project = projects[index]
        update(&project)
        project.modifiedAt = .now
        projects[index] = project
        projects.sort { $0.modifiedAt > $1.modifiedAt }
        save(project)
    }

    private func replace(_ project: AlbumProject) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        projects.sort { $0.modifiedAt > $1.modifiedAt }
        save(project)
    }

    private func save(_ project: AlbumProject) {
        let directory = projectDirectory(project.id)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(project) else { return }
        try? data.write(to: directory.appendingPathComponent("project.json"), options: .atomic)
    }

    private func projectDirectory(_ id: UUID) -> URL {
        rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func cacheKey(_ projectID: UUID, _ assetID: UUID, _ thumbnail: Bool) -> NSString {
        "\(projectID.uuidString)-\(assetID.uuidString)-\(thumbnail ? "thumb" : "full")" as NSString
    }

    private func recalculatePalette(_ project: inout AlbumProject) {
        let usedIDs = Set(project.pages.flatMap(\.slots).compactMap(\.assetID))
        let candidates = project.assets
            .filter { usedIDs.contains($0.id) }
            .flatMap { $0.colors.prefix(2) }
        guard !candidates.isEmpty else { return }
        var selected: [AlbumColor] = [candidates[0]]
        while selected.count < min(3, candidates.count) {
            guard let next = candidates.max(by: { left, right in
                minimumColorDistance(left, selected) < minimumColorDistance(right, selected)
            }) else { break }
            if selected.contains(next) { break }
            selected.append(next)
        }
        project.palette = selected
    }

    private func minimumColorDistance(_ color: AlbumColor, _ selected: [AlbumColor]) -> Double {
        selected.map { other in
            let red = color.red - other.red
            let green = color.green - other.green
            let blue = color.blue - other.blue
            return red * red + green * green + blue * blue
        }.min() ?? 0
    }

    private func renumberPages(_ project: inout AlbumProject) {
        for index in project.pages.indices {
            guard let numberIndex = project.pages[index].textBlocks.firstIndex(where: { $0.style == .pageNumber }) else {
                continue
            }
            project.pages[index].textBlocks[numberIndex].text = String(format: "%02d", index + 1)
        }
    }

    private func isCompatible(_ kind: AlbumAssetKind, expectation: AlbumSlotExpectation) -> Bool {
        expectation == .any
            || (expectation == .photo && kind == .photo)
            || (expectation == .work && kind == .work)
    }

    private func compatibilityScore(
        _ asset: AlbumAsset,
        slot: AlbumSlot,
        expectation: AlbumSlotExpectation,
        format: AlbumBookFormat
    ) -> Double {
        guard isCompatible(asset.kind, expectation: expectation) else { return 10_000 }
        let slotAspect = CGFloat(slot.frame.width / slot.frame.height) * format.aspectRatio
        return abs(log(max(asset.aspectRatio, 0.01) / max(slotAspect, 0.01)))
    }
}

struct LingdongWorkRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let kind: String
    let createdAt: Date
    let fileName: String
    let thumbnailFileName: String
    let pixelWidth: Int
    let pixelHeight: Int

    var kindTitle: String {
        CreationMode(rawValue: kind)?.title ?? "灵动作品"
    }
}

@MainActor
enum LingdongWorkArchive {
    nonisolated private static var rootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LingdongWorks", isDirectory: true)
    }
    nonisolated private static var indexURL: URL { rootURL.appendingPathComponent("works.json") }

    nonisolated static func records() -> [LingdongWorkRecord] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([LingdongWorkRecord].self, from: data))?
            .sorted { $0.createdAt > $1.createdAt } ?? []
    }

    static func storageByteCount() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    @discardableResult
    static func delete(ids: Set<UUID>) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let currentRecords = records()
        let deletedRecords = currentRecords.filter { ids.contains($0.id) }
        guard !deletedRecords.isEmpty else { return 0 }

        let remainingRecords = currentRecords.filter { !ids.contains($0.id) }
        try writeIndex(remainingRecords)

        for record in deletedRecords {
            try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(record.fileName))
            try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(record.thumbnailFileName))
        }
        return deletedRecords.count
    }

    // Runs off the main actor: encoding a 3600 px copy plus a thumbnail and
    // writing both to disk would otherwise freeze the UI right after a save.
    nonisolated static func record(image: UIImage, mode: CreationMode) {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        guard let normalized = image.albumScaled(maxDimension: 3_600),
              let thumbnail = image.albumScaled(maxDimension: 640) else { return }
        let id = UUID()
        let preservesTransparency = mode == .travelTicket
        let fileExtension = preservesTransparency ? "png" : "jpg"
        let fileName = "work-\(id.uuidString).\(fileExtension)"
        let thumbnailFileName = "work-thumb-\(id.uuidString).jpg"
        let data = preservesTransparency
            ? normalized.pngData()
            : normalized.jpegData(compressionQuality: 0.94)
        guard let data,
              let thumbnailData = thumbnail.jpegData(compressionQuality: 0.84) else { return }
        do {
            try data.write(to: rootURL.appendingPathComponent(fileName), options: .atomic)
            try thumbnailData.write(to: rootURL.appendingPathComponent(thumbnailFileName), options: .atomic)
            let pixelSize = normalized.albumPixelSize
            var values = records()
            values.insert(LingdongWorkRecord(
                id: id,
                title: mode.title,
                kind: mode.rawValue,
                createdAt: .now,
                fileName: fileName,
                thumbnailFileName: thumbnailFileName,
                pixelWidth: Int(pixelSize.width.rounded()),
                pixelHeight: Int(pixelSize.height.rounded())
            ), at: 0)
            try writeIndex(values)
        } catch {
            try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(fileName))
            try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(thumbnailFileName))
        }
    }

    static func image(for record: LingdongWorkRecord, thumbnail: Bool) -> UIImage? {
        UIImage(contentsOfFile: rootURL
            .appendingPathComponent(thumbnail ? record.thumbnailFileName : record.fileName).path)
    }

    static func payload(for record: LingdongWorkRecord) throws -> AlbumImportedPayload {
        try AlbumImageImporter.load(url: rootURL.appendingPathComponent(record.fileName))
    }

    nonisolated private static func writeIndex(_ records: [LingdongWorkRecord]) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: indexURL, options: .atomic)
    }
}

extension UIImage {
    nonisolated var albumPixelSize: CGSize {
        if let cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    nonisolated func albumScaled(maxDimension: CGFloat) -> UIImage? {
        let pixels = albumPixelSize
        let largest = max(pixels.width, pixels.height)
        guard largest > 0 else { return nil }
        let ratio = min(1, maxDimension / largest)
        let target = CGSize(
            width: max(1, (pixels.width * ratio).rounded()),
            height: max(1, (pixels.height * ratio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
