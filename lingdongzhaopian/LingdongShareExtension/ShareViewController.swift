// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let model = ShareImportModel(
            extensionContext: extensionContext,
            presentingViewController: self
        )
        let hosting = UIHostingController(rootView: ShareImportView(model: model))
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .systemBackground
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        model.load()
    }

    fileprivate func openContainingApp(
        _ url: URL,
        completion: @escaping (Bool) -> Void
    ) -> Bool {
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication {
                application.open(url, options: [:], completionHandler: completion)
                return true
            }
            responder = currentResponder.next
        }
        return false
    }
}

@MainActor
private final class ShareImportModel: ObservableObject {
    @Published var images: [UIImage] = []
    @Published var livePhotoFlags: [Bool] = []
    @Published var isLoading = true
    @Published var isOpening = false
    @Published var errorMessage: String?
    @Published var selectedMode: ShareCreationMode = .motionCard

    private weak var extensionContext: NSExtensionContext?
    private weak var presentingViewController: ShareViewController?
    private var assets: [ShareIncomingAsset] = []

    init(
        extensionContext: NSExtensionContext?,
        presentingViewController: ShareViewController
    ) {
        self.extensionContext = extensionContext
        self.presentingViewController = presentingViewController
    }

    func load() {
        Task {
            let providers = extensionContext?.inputItems
                .compactMap { $0 as? NSExtensionItem }
                .flatMap { $0.attachments ?? [] } ?? []
            var values: [ShareIncomingAsset] = []
            var firstError: Error?
            for provider in providers.prefix(5) {
                let advertisesLivePhoto = Self.hasLivePhotoRepresentation(provider)
                do {
                    let value = try await Self.loadAsset(
                        provider: provider,
                        advertisesLivePhoto: advertisesLivePhoto
                    )
                    values.append(value)
                } catch {
                    firstError = firstError ?? error
                }
            }
            assets = values
            images = values.compactMap { UIImage(data: $0.imageData) }
            livePhotoFlags = values.map(\.isLivePhoto)
            isLoading = false
            if values.isEmpty {
                errorMessage = firstError?.localizedDescription
                    ?? "没有读取到可用照片，请返回系统照片后重试。"
            }
        }
    }

    nonisolated private static func loadAsset(
        provider: NSItemProvider,
        advertisesLivePhoto: Bool
    ) async throws -> ShareIncomingAsset {
        let imageIdentifier = provider.registeredTypeIdentifiers.first(where: {
            guard !Self.isLivePhotoIdentifier($0),
                  let type = UTType($0) else { return false }
            return type.conforms(to: .image)
        })

        // Photos currently advertises `com.apple.live-photo` to action
        // extensions but often vends only the still-image representation. Read
        // that cheap, local representation first, then recover the selected
        // asset's paired video through PhotoKit. This avoids waiting for two
        // Live Photo item-provider requests that the host will reject.
        if let imageIdentifier {
            let payload = try await loadImagePayload(
                provider: provider,
                identifier: imageIdentifier
            )
            guard UIImage(data: payload.data) != nil else {
                throw ShareImportError.unreadableImage
            }
            guard advertisesLivePhoto else {
                return ShareIncomingAsset(
                    imageData: payload.data,
                    pairedVideoURL: nil,
                    isLivePhoto: false,
                    assetLocalIdentifier: nil
                )
            }
            let suggestedName = provider.suggestedName
            let recovered = try? await Task.detached(priority: .userInitiated) {
                try await recoverLiveAssetFromPhotoLibrary(
                    payload: payload,
                    providerSuggestedName: suggestedName
                )
            }.value
            if let recovered {
                return recovered
            }
        }

        // Keep one provider-based fallback for hosts that really do vend a
        // complete PHLivePhoto instead of Photos' flattened JPEG.
        if advertisesLivePhoto,
           provider.canLoadObject(ofClass: PHLivePhoto.self) {
            let livePhoto = try await loadLivePhoto(provider: provider)
            return try await loadLiveAsset(livePhoto: livePhoto)
        }

        throw advertisesLivePhoto
            ? ShareImportError.incompleteLivePhoto
            : ShareImportError.unreadableImage
    }

    nonisolated private static func isLivePhotoIdentifier(_ identifier: String) -> Bool {
        guard let type = UTType(identifier) else { return false }
        return type == .livePhoto || type.conforms(to: .livePhoto)
    }

    func open(mode: ShareCreationMode) {
        guard !assets.isEmpty, !isOpening, let extensionContext else { return }
        isOpening = true
        let selectedAssets = Array(assets.prefix(mode == .journal ? 5 : 1))
        do {
            try ShareInbox.store(assets: selectedAssets, mode: mode)
        } catch {
            errorMessage = "无法准备共享照片，请稍后重试。"
            isOpening = false
            return
        }
        removeTemporaryLiveResources()

        guard let url = Self.importURL(mode: mode) else {
            errorMessage = "无法生成应用启动链接，请稍后重试。"
            isOpening = false
            return
        }

        let requested = presentingViewController?.openContainingApp(url) { [weak self] success in
            guard let self else { return }
            if success {
                extensionContext.completeRequest(returningItems: nil)
            } else {
                self.openThroughExtensionContext(url, extensionContext: extensionContext)
            }
        } ?? false

        if !requested {
            openThroughExtensionContext(url, extensionContext: extensionContext)
        }
    }

    func cancel() {
        removeTemporaryLiveResources()
        extensionContext?.cancelRequest(withError: ShareImportError.cancelled)
    }

    private func removeTemporaryLiveResources() {
        for url in assets.compactMap(\.pairedVideoURL) {
            try? FileManager.default.removeItem(at: url)
        }
        assets = assets.map {
            ShareIncomingAsset(
                imageData: $0.imageData,
                pairedVideoURL: nil,
                isLivePhoto: $0.isLivePhoto,
                assetLocalIdentifier: $0.assetLocalIdentifier
            )
        }
    }

    nonisolated private static func loadImagePayload(
        provider: NSItemProvider,
        identifier: String
    ) async throws -> ShareImagePayload {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, error in
                    guard let url else {
                        continuation.resume(
                            throwing: error ?? ShareImportError.unreadableImage
                        )
                        return
                    }
                    do {
                        let values = try? url.resourceValues(forKeys: [
                            .creationDateKey,
                            .contentModificationDateKey
                        ])
                        continuation.resume(returning: ShareImagePayload(
                            data: try Data(contentsOf: url),
                            sourceFilename: url.lastPathComponent,
                            sourceDate: values?.creationDate
                                ?? values?.contentModificationDate
                        ))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            return ShareImagePayload(
                data: try await loadData(provider: provider, identifier: identifier),
                sourceFilename: provider.suggestedName,
                sourceDate: nil
            )
        }
    }

    nonisolated private static func loadData(
        provider: NSItemProvider,
        identifier: String
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? ShareImportError.unreadableImage)
                }
            }
        }
    }

    nonisolated private static func hasLivePhotoRepresentation(
        _ provider: NSItemProvider
    ) -> Bool {
        provider.canLoadObject(ofClass: PHLivePhoto.self)
            || provider.hasItemConformingToTypeIdentifier(UTType.livePhoto.identifier)
            || provider.registeredTypeIdentifiers.contains { identifier in
                guard let type = UTType(identifier) else { return false }
                return type == .livePhoto || type.conforms(to: .livePhoto)
            }
    }

    nonisolated private static func loadLivePhoto(
        provider: NSItemProvider
    ) async throws -> PHLivePhoto {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: PHLivePhoto.self) { object, error in
                if let livePhoto = object as? PHLivePhoto {
                    continuation.resume(returning: livePhoto)
                } else {
                    continuation.resume(throwing: error ?? ShareImportError.unreadableLivePhoto)
                }
            }
        }
    }

    nonisolated private static func loadLiveAsset(
        livePhoto: PHLivePhoto
    ) async throws -> ShareIncomingAsset {
        let resources = PHAssetResource.assetResources(for: livePhoto)
        guard let imageResource = resources.first(where: { $0.type == .fullSizePhoto })
                ?? resources.first(where: { $0.type == .photo }),
              let videoResource = resources.first(where: { $0.type == .fullSizePairedVideo })
                ?? resources.first(where: { $0.type == .pairedVideo }) else {
            throw ShareImportError.incompleteLivePhoto
        }

        async let imageData = resourceData(imageResource)
        let videoExtension = URL(fileURLWithPath: videoResource.originalFilename).pathExtension
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-share-live-\(UUID().uuidString)")
            .appendingPathExtension(videoExtension.isEmpty ? "mov" : videoExtension)
        do {
            try await write(videoResource, to: videoURL)
            guard fileSize(at: videoURL) > 0 else {
                throw ShareImportError.incompleteLivePhoto
            }
            let data = try await imageData
            guard UIImage(data: data) != nil else {
                throw ShareImportError.unreadableImage
            }
            return ShareIncomingAsset(
                imageData: data,
                pairedVideoURL: videoURL,
                isLivePhoto: true,
                assetLocalIdentifier: videoResource.assetLocalIdentifier
            )
        } catch {
            try? FileManager.default.removeItem(at: videoURL)
            throw error
        }
    }

    nonisolated private static func resourceData(
        _ resource: PHAssetResource
    ) async throws -> Data {
        let fileExtension = URL(fileURLWithPath: resource.originalFilename).pathExtension
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-share-still-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension.isEmpty ? "heic" : fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }
        try await write(resource, to: url)
        return try Data(contentsOf: url)
    }

    nonisolated private static func recoverLiveAssetFromPhotoLibrary(
        payload: ShareImagePayload,
        providerSuggestedName: String?
    ) async throws -> ShareIncomingAsset? {
        guard await photoLibraryReadStatus() else { return nil }

        let signature = imageSignature(for: payload)
        let candidates = livePhotoCandidates(matching: signature)
        guard !candidates.isEmpty else { return nil }

        let expectedNames = Set([
            normalizedFilename(payload.sourceFilename),
            normalizedFilename(providerSuggestedName)
        ].compactMap { $0 })
        let namedCandidates = expectedNames.isEmpty ? [] : candidates.filter { asset in
            PHAssetResource.assetResources(for: asset).contains { resource in
                guard let name = normalizedFilename(resource.originalFilename) else {
                    return false
                }
                return expectedNames.contains(name)
            }
        }

        if namedCandidates.count == 1,
           let asset = namedCandidates.first {
            return try await incomingAsset(from: asset, imageData: payload.data)
        }
        if candidates.count == 1,
           let asset = candidates.first {
            return try await incomingAsset(from: asset, imageData: payload.data)
        }

        // Only ambiguous, already database-filtered candidates require reading
        // their still resource. This loop is deliberately capped so its cost is
        // independent of a user's total library size.
        guard let sharedIdentifier = livePhotoAssetIdentifier(in: payload.data) else {
            return nil
        }
        let verificationCandidates = namedCandidates.isEmpty
            ? candidates
            : namedCandidates
        for asset in verificationCandidates.prefix(16) {
            let resources = PHAssetResource.assetResources(for: asset)
            guard let imageResource = resources.first(where: { $0.type == .fullSizePhoto })
                    ?? resources.first(where: { $0.type == .photo }),
                  let candidateImageData = try? await resourceData(imageResource),
                  livePhotoAssetIdentifier(in: candidateImageData) == sharedIdentifier else {
                continue
            }
            return try await incomingAsset(from: asset, imageData: payload.data)
        }
        return nil
    }

    nonisolated private static func incomingAsset(
        from asset: PHAsset,
        imageData: Data
    ) async throws -> ShareIncomingAsset? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let videoResource = resources.first(where: { $0.type == .fullSizePairedVideo })
                ?? resources.first(where: { $0.type == .pairedVideo }) else {
            return nil
        }

        let videoExtension = URL(fileURLWithPath: videoResource.originalFilename).pathExtension
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-share-live-\(UUID().uuidString)")
            .appendingPathExtension(videoExtension.isEmpty ? "mov" : videoExtension)
        do {
            try await write(videoResource, to: videoURL)
            guard fileSize(at: videoURL) > 0 else {
                throw ShareImportError.incompleteLivePhoto
            }
            return ShareIncomingAsset(
                imageData: imageData,
                pairedVideoURL: videoURL,
                isLivePhoto: true,
                assetLocalIdentifier: asset.localIdentifier
            )
        } catch {
            try? FileManager.default.removeItem(at: videoURL)
            throw error
        }
    }

    nonisolated private static func livePhotoCandidates(
        matching signature: ShareImageSignature
    ) -> [PHAsset] {
        if let sourceDate = signature.sourceDate {
            let precise = fetchLivePhotos(
                sourceDate: sourceDate,
                pixelWidth: signature.pixelWidth,
                pixelHeight: signature.pixelHeight
            )
            if !precise.isEmpty { return precise }

            // Edited photos can have a shared rendition whose dimensions no
            // longer equal PHAsset's original dimensions. Creation time still
            // identifies a very small, bounded candidate set.
            let byDate = fetchLivePhotos(
                sourceDate: sourceDate,
                pixelWidth: nil,
                pixelHeight: nil
            )
            if !byDate.isEmpty { return byDate }
        }

        guard signature.pixelWidth != nil,
              signature.pixelHeight != nil else { return [] }
        return fetchLivePhotos(
            sourceDate: nil,
            pixelWidth: signature.pixelWidth,
            pixelHeight: signature.pixelHeight
        )
    }

    nonisolated private static func fetchLivePhotos(
        sourceDate: Date?,
        pixelWidth: Int?,
        pixelHeight: Int?
    ) -> [PHAsset] {
        var predicates = [NSPredicate(
            format: "(mediaSubtypes & %d) != 0",
            PHAssetMediaSubtype.photoLive.rawValue
        )]
        if let sourceDate {
            predicates.append(NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                sourceDate.addingTimeInterval(-2) as NSDate,
                sourceDate.addingTimeInterval(2) as NSDate
            ))
        }
        if let pixelWidth, let pixelHeight {
            predicates.append(NSPredicate(
                format: "(pixelWidth == %d AND pixelHeight == %d) OR (pixelWidth == %d AND pixelHeight == %d)",
                pixelWidth,
                pixelHeight,
                pixelHeight,
                pixelWidth
            ))
        }

        let options = PHFetchOptions()
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        options.includeHiddenAssets = true
        options.fetchLimit = 64
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    nonisolated private static func imageSignature(
        for payload: ShareImagePayload
    ) -> ShareImageSignature {
        guard let source = CGImageSourceCreateWithData(payload.data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any] else {
            return ShareImageSignature(
                pixelWidth: nil,
                pixelHeight: nil,
                sourceDate: payload.sourceDate
            )
        }
        return ShareImageSignature(
            pixelWidth: (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            pixelHeight: (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
            sourceDate: payload.sourceDate ?? embeddedCaptureDate(in: properties)
        )
    }

    nonisolated private static func embeddedCaptureDate(
        in properties: [CFString: Any]
    ) -> Date? {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let value = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
            ?? exif?[kCGImagePropertyExifDateTimeDigitized] as? String
            ?? tiff?[kCGImagePropertyTIFFDateTime] as? String
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value)
    }

    nonisolated private static func normalizedFilename(_ filename: String?) -> String? {
        guard let filename, !filename.isEmpty else { return nil }
        return URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .lowercased()
    }

    nonisolated private static func livePhotoAssetIdentifier(in data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let makerApple = properties[kCGImagePropertyMakerAppleDictionary]
                as? [String: Any] else { return nil }
        return makerApple["17"] as? String
    }

    nonisolated private static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    nonisolated private static func photoLibraryReadStatus() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let status: PHAuthorizationStatus
        if current == .notDetermined {
            status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { value in
                    continuation.resume(returning: value)
                }
            }
        } else {
            status = current
        }
        return status == .authorized || status == .limited
    }

    nonisolated private static func write(
        _ resource: PHAssetResource,
        to url: URL
    ) async throws {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: url,
                options: options
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func importURL(mode: ShareCreationMode) -> URL? {
        var components = URLComponents()
        components.scheme = "lingdongphoto"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "mode", value: mode.rawValue)]
        return components.url
    }

    private func openThroughExtensionContext(
        _ url: URL,
        extensionContext: NSExtensionContext
    ) {
        extensionContext.open(url) { [weak self] success in
            Task { @MainActor [weak self] in
                self?.finishOpeningThroughExtensionContext(succeeded: success)
            }
        }
    }

    private func finishOpeningThroughExtensionContext(succeeded: Bool) {
        if succeeded {
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            errorMessage = "系统未能直接打开“灵动照片”，照片已经安全保留，可手动打开应用继续。"
            isOpening = false
        }
    }
}

private struct ShareImportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: ShareImportModel

    private var mode: ShareCreationMode { model.selectedMode }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button("取消", action: model.cancel)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("灵动照片")
                        .font(.headline)
                    Spacer()
                    Color.clear.frame(width: 36, height: 1)
                }

                if model.isLoading {
                    Spacer()
                    ProgressView("正在本机读取照片…")
                    Spacer()
                } else {
                    thumbnailStrip

                    VStack(alignment: .leading, spacing: 10) {
                        Text("选择创作模式")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(ShareCreationMode.allCases) { item in
                                    HStack(spacing: 13) {
                                        Image(systemName: item.symbol).frame(width: 28)
                                        Text(item.title).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Image(systemName: mode == item ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(mode == item ? .blue : .secondary)
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 14)
                                    .frame(height: 46)
                                    .background(
                                        mode == item
                                            ? Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07)
                                            : .clear,
                                        in: RoundedRectangle(cornerRadius: 15)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        model.selectedMode = item
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(item.title)
                                    .accessibilityIdentifier("share-mode-\(item.rawValue)")
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAddTraits(mode == item ? .isSelected : [])
                                }
                            }
                        }
                        .frame(maxHeight: 314)
                    }
                    .padding(14)
                    .shareGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("选择模式后将直接打开“灵动照片”。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button { model.open(mode: mode) } label: {
                        Group {
                            if model.isOpening {
                                ProgressView()
                            } else {
                                Label("在灵动照片中继续", systemImage: "arrow.up.forward.app")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(SharePressStyle())
                    .shareGlass(in: Capsule())
                    .overlay {
                        if colorScheme == .light {
                            Capsule()
                                .strokeBorder(Color.black.opacity(0.20), lineWidth: 1.2)
                        }
                    }
                    .disabled(model.images.isEmpty || model.isOpening)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private var thumbnailStrip: some View {
        let visibleCount = min(model.images.count, mode == .journal ? 5 : 1)
        let previewHeight: CGFloat = visibleCount > 1 ? 112 : 180
        return HStack(spacing: 8) {
            ForEach(Array(model.images.prefix(mode == .journal ? 5 : 1).enumerated()), id: \.offset) { index, image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        let isLivePhoto = model.livePhotoFlags.indices.contains(index)
                            && model.livePhotoFlags[index]
                        Label(
                            isLivePhoto ? "实况" : "静态",
                            systemImage: isLivePhoto ? "livephoto" : "photo"
                        )
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 9)
                                .frame(height: 27)
                                .shareGlass(in: Capsule())
                                .padding(7)
                                .accessibilityIdentifier(
                                    isLivePhoto ? "share-live-photo-badge" : "share-still-photo-badge"
                                )
                    }
            }
        }
        .padding(8)
        .shareGlass(in: RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

private enum ShareCreationMode: String, CaseIterable, Identifiable {
    case motionCard
    case colorPalette
    case journal
    case bubbleStamp
    case spectrumWallpaper
    case privacyMosaic

    var id: String { rawValue }
    var title: String {
        switch self {
        case .motionCard: "灵动卡片"
        case .colorPalette: "琉璃色盘"
        case .journal: "一键手帐"
        case .bubbleStamp: "气泡印章"
        case .spectrumWallpaper: "色谱壁纸"
        case .privacyMosaic: "隐私马赛克"
        }
    }
    var symbol: String {
        switch self {
        case .motionCard: "livephoto"
        case .colorPalette: "paintpalette"
        case .journal: "bookmark"
        case .bubbleStamp: "seal"
        case .spectrumWallpaper: "rectangle.on.rectangle"
        case .privacyMosaic: "eye.slash"
        }
    }
}

private struct ShareImagePayload: Sendable {
    let data: Data
    let sourceFilename: String?
    let sourceDate: Date?
}

private struct ShareImageSignature: Sendable {
    let pixelWidth: Int?
    let pixelHeight: Int?
    let sourceDate: Date?
}

private struct ShareIncomingAsset: Sendable {
    let imageData: Data
    let pairedVideoURL: URL?
    let isLivePhoto: Bool
    let assetLocalIdentifier: String?
}

private enum ShareInbox {
    private static let directoryName = "PendingShareImport"

    static func store(assets: [ShareIncomingAsset], mode: ShareCreationMode) throws {
        guard let appGroupIdentifier = Bundle.main.object(
            forInfoDictionaryKey: "LingdongAppGroupIdentifier"
        ) as? String,
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { throw ShareInboxError.sharedContainerUnavailable }

        let fileManager = FileManager.default
        let inboxURL = containerURL.appendingPathComponent(directoryName, isDirectory: true)
        let stagingURL = containerURL.appendingPathComponent(
            "\(directoryName)-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        do {
            var records: [Manifest.Asset] = []
            for (index, asset) in assets.enumerated() {
                let imageFilename = "image-\(index).data"
                try asset.imageData.write(
                    to: stagingURL.appendingPathComponent(imageFilename),
                    options: .atomic
                )

                let pairedVideoFilename: String?
                if let sourceURL = asset.pairedVideoURL {
                    let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
                    let filename = "paired-video-\(index).\(fileExtension)"
                    try fileManager.copyItem(
                        at: sourceURL,
                        to: stagingURL.appendingPathComponent(filename)
                    )
                    let copiedURL = stagingURL.appendingPathComponent(filename)
                    let copiedSize = try copiedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard copiedSize > 0 else {
                        throw ShareImportError.incompleteLivePhoto
                    }
                    pairedVideoFilename = filename
                } else {
                    pairedVideoFilename = nil
                }
                records.append(Manifest.Asset(
                    imageFilename: imageFilename,
                    pairedVideoFilename: pairedVideoFilename,
                    isLivePhoto: asset.isLivePhoto,
                    assetLocalIdentifier: asset.assetLocalIdentifier
                ))
            }
            let manifest = Manifest(
                modeRawValue: mode.rawValue,
                assets: records,
                filenames: records.map(\.imageFilename),
                createdAt: .now
            )
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(
                to: stagingURL.appendingPathComponent("manifest.json"),
                options: .atomic
            )
            if fileManager.fileExists(atPath: inboxURL.path) {
                try fileManager.removeItem(at: inboxURL)
            }
            try fileManager.moveItem(at: stagingURL, to: inboxURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    private struct Manifest: Codable {
        struct Asset: Codable {
            let imageFilename: String
            let pairedVideoFilename: String?
            let isLivePhoto: Bool
            let assetLocalIdentifier: String?
        }

        let modeRawValue: String
        let assets: [Asset]
        let filenames: [String]
        let createdAt: Date
    }
}

private enum ShareInboxError: Error {
    case sharedContainerUnavailable
}

private enum ShareImportError: LocalizedError {
    case cancelled
    case unreadableImage
    case unreadableLivePhoto
    case incompleteLivePhoto
    var errorDescription: String? {
        switch self {
        case .cancelled: "用户取消共享导入。"
        case .unreadableImage: "无法读取共享照片。"
        case .unreadableLivePhoto: "无法读取共享的实况照片。"
        case .incompleteLivePhoto: "共享的实况照片缺少关键帧或动态片段。"
        }
    }
}

private extension View {
    @ViewBuilder
    func shareGlass<S: InsettableShape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.clear, in: shape)
        } else {
            background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.stroke(Color.primary.opacity(0.14), lineWidth: 1))
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.10), radius: 15, y: 8)
        }
    }
}

private struct SharePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.70), value: configuration.isPressed)
    }
}
