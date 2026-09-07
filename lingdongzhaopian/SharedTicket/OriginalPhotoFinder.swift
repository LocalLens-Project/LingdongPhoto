import Combine
import Photos
import SwiftUI
import UIKit

@MainActor
final class OriginalPhotoFinder: ObservableObject {

    enum Stage: Equatable {
        case idle
        case requestingPermission

        case scanning(window: TimeInterval?, checked: Int, total: Int)
        case found(FoundPhoto)
        case notFound
        case permissionDenied
        case cancelled
    }

    struct FoundPhoto: Equatable {
        let assetIdentifier: String
        let thumbnail: UIImage
        let creationDate: Date?
        let pixelWidth: Int
        let pixelHeight: Int
        let isLivePhoto: Bool

        static func == (lhs: FoundPhoto, rhs: FoundPhoto) -> Bool {
            lhs.assetIdentifier == rhs.assetIdentifier
        }
    }

    @Published private(set) var stage: Stage = .idle
    private var searchTask: Task<Void, Never>?

    func start(payload: TicketPayload) {
        guard searchTask == nil else { return }
        searchTask = Task { await run(payload: payload) }
    }

    func cancel() {
        searchTask?.cancel()
    }

    private func run(payload: TicketPayload) async {

        guard let target = OriginalPhotoFinderCore.signatureValue(fromHex: payload.fingerprint) else {
            stage = .notFound
            return
        }

        stage = .requestingPermission

        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                continuation.resume(returning: newStatus)
            }
        }
        guard status == .authorized || status == .limited else {
            stage = .permissionDenied
            return
        }

        let captureDate = OriginalPhotoFinderCore.parseCaptureDate(from: payload.captureTime)
        let windows: [TimeInterval?] = captureDate == nil
            ? [nil]
            : OriginalPhotoFinderCore.prefilterWindows.map { Optional($0) } + [nil]

        for window in windows {
            guard !Task.isCancelled else {
                stage = .cancelled
                return
            }
            let assets = Self.fetchImageAssets(around: captureDate, window: window)
            guard assets.count > 0 else { continue }
            for index in 0..<assets.count {
                guard !Task.isCancelled else {
                    stage = .cancelled
                    return
                }
                stage = .scanning(window: window, checked: index + 1, total: assets.count)
                let asset = assets.object(at: index)
                if let found = await match(asset: asset, target: target) {
                    stage = .found(found)
                    return
                }
            }
        }
        stage = Task.isCancelled ? .cancelled : .notFound
    }

    private static func fetchImageAssets(
        around date: Date?,
        window: TimeInterval?
    ) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        ]
        if let date, let window {
            predicates.append(NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                date.addingTimeInterval(-window) as NSDate,
                date.addingTimeInterval(window) as NSDate
            ))
        }
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return PHAsset.fetchAssets(with: options)
    }

    private func match(asset: PHAsset, target: UInt64) async -> FoundPhoto? {
        let resources = PHAssetResource.assetResources(for: asset)

        guard let resource = resources.first(where: { $0.type == .photo })
            ?? resources.first(where: { $0.type == .fullSizePhoto }) else {
            return nil
        }

        let accumulator = OriginalPhotoFinderCore.StreamingSignature()
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let requestError: Error? = await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options
            ) { chunk in
                accumulator.update(chunk)
            } completionHandler: { error in

                Task.detached { continuation.resume(returning: error) }
            }
        }
        guard requestError == nil,
              accumulator.finalize() == target else {
            return nil
        }

        let thumbnail = await loadThumbnail(for: asset)
        return FoundPhoto(
            assetIdentifier: asset.localIdentifier,
            thumbnail: thumbnail,
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            isLivePhoto: asset.mediaSubtypes.contains(.photoLive)
        )
    }

    private func loadThumbnail(for asset: PHAsset) async -> UIImage {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 720, height: 720),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image ?? UIImage())
            }
        }
    }
}

struct OriginalPhotoSearchSheet: View {
    let payload: TicketPayload

    @StateObject private var finder = OriginalPhotoFinder()
    @Environment(\.dismiss) private var dismiss
    @State private var showFullScreenPhoto = false


    private var ticketColors: [Color] {
        let values = payload.palette.map(\.color)
        return values.isEmpty
            ? [Color(red: 0.20, green: 0.45, blue: 0.37), .indigo, .mint]
            : values
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TicketAmbientBackground(colors: ticketColors)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("寻找本机原图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        finder.cancel()
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task { finder.start(payload: payload) }
    }

    @ViewBuilder
    private var content: some View {
        switch finder.stage {
        case .idle, .requestingPermission:
            progressCard(icon: "photo.stack", title: "正在请求访问相册…",
                         detail: "仅读取权限，只在本机比对，不会上传任何照片。")
        case .scanning(let window, let checked, let total):
            progressCard(
                icon: "magnifyingglass",
                title: "正在比对 \(checked) / \(total)",
                detail: "搜索范围：\(Self.windowDescription(window))。逐张读取原始字节并计算指纹，命中即停。"
            )
        case .found(let photo):
            foundCard(photo)
                .fullScreenCover(isPresented: $showFullScreenPhoto) {
                    FoundPhotoFullScreenView(photo: photo)
                }
        case .notFound:
            resultCard(
                icon: "questionmark.folder",
                title: "未找到与指纹完全一致的原图",
                detail: "原图可能已被压缩、转码、转发改写，或尚未从 iCloud 下载。若这张票根的指纹不是由原图哈希生成（创建时未读取到原图），也无法通过此方式寻回。"
            )
        case .permissionDenied:
            resultCard(
                icon: "lock.shield",
                title: "没有相册访问权限",
                detail: "寻回原图需要读取相册。请在系统设置中允许本应用访问照片后重试。照片仅在本机比对，不会上传。"
            )
        case .cancelled:
            resultCard(icon: "xmark.circle", title: "搜索已取消", detail: "你可以随时重新开始搜索。")
        }
    }

    private static func windowDescription(_ window: TimeInterval?) -> String {
        switch window {
        case .some(let value) where value <= 3_600: "拍摄时间 ±1 小时"
        case .some(let value) where value <= 86_400: "拍摄时间 ±1 天"
        default: "全部照片"
        }
    }

    private func progressCard(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            ProgressView()
                .controlSize(.large)
                .tint(.white.opacity(0.8))
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func resultCard(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func foundCard(_ photo: OriginalPhotoFinder.FoundPhoto) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("已找到与指纹一致的原图", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.green)

            Button {
                showFullScreenPhoto = true
            } label: {
                Image(uiImage: photo.thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Label("轻点查看原图", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(10)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                if let date = photo.creationDate {
                    infoRow(icon: "calendar", text: "拍摄于 \(Self.resultDateText(date))")
                }
                if photo.pixelWidth > 0, photo.pixelHeight > 0 {
                    infoRow(icon: "rectangle.split.3x3",
                            text: "分辨率 \(photo.pixelWidth) × \(photo.pixelHeight)")
                }
                if photo.isLivePhoto {
                    infoRow(icon: "livephoto", text: "这是一张实况照片的原图")
                }
                infoRow(icon: "number", text: "指纹 \(payload.fingerprint) 完全一致")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.62))
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private static let resultDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    private static func resultDateText(_ date: Date) -> String {
        resultDateFormatter.string(from: date)
    }
}

struct FoundPhotoFullScreenView: View {
    let photo: OriginalPhotoFinder.FoundPhoto
    @Environment(\.dismiss) private var dismiss

    @State private var fullImage: UIImage?
    @State private var loadFailed = false
    @State private var scale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let fullImage {
                Image(uiImage: fullImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale * gestureScale)
                    .offset(x: offset.width + gestureOffset.width,
                            y: offset.height + gestureOffset.height)
                    .gesture(zoomAndPan)
                    .onTapGesture(count: 2) { resetTransform() }
            } else if loadFailed {

                Image(uiImage: photo.thumbnail)
                    .resizable()
                    .scaledToFit()
                Text("原图加载失败，展示的是寻回时的缩略图")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 130)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white.opacity(0.8))
                    Text("正在加载原图质量大图…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.16), in: Circle())
            }
            .padding(20)
        }
        .overlay(alignment: .bottom) {
            if fullImage != nil {
                Text("双指缩放 · 拖拽平移 · 双击还原")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 26)
            }
        }
        .task { await loadFullImage() }
    }

    private var zoomAndPan: some Gesture {
        MagnificationGesture()
            .onChanged { value in gestureScale = value }
            .onEnded { value in
                scale = min(max(scale * value, 1), 6)
                gestureScale = 1
                if scale <= 1.01 { resetTransform() }
            }
            .simultaneously(with: DragGesture()
                .onChanged { value in gestureOffset = value.translation }
                .onEnded { value in
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                    gestureOffset = .zero
                })
    }

    private func resetTransform() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 1
            gestureScale = 1
            offset = .zero
            gestureOffset = .zero
        }
    }

    private func loadFullImage() async {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetIdentifier], options: nil)
        guard let asset = fetch.firstObject else {
            loadFailed = true
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true
        let image: UIImage? = await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in

                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !degraded, !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
        if let image {
            fullImage = image
        } else {
            loadFailed = true
        }
    }
}
