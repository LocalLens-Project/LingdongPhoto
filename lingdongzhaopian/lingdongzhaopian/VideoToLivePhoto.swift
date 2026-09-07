// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

@preconcurrency import AVFoundation
import CoreMedia
import Combine
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum VideoToLivePhotoError: LocalizedError {
    case unreadableVideo
    case videoTooShort
    case frameUnavailable
    case unsupportedPassthrough
    case writeFailed(String)
    case permissionDenied
    case photoLibraryFailed

    var errorDescription: String? {
        switch self {
        case .unreadableVideo:
            "无法读取这个视频，请重新选择原始视频。".appLocalized
        case .videoTooShort:
            "视频至少需要 3 秒。".appLocalized
        case .frameUnavailable:
            "无法读取所选实况封面，请尝试选择附近的画面。".appLocalized
        case .unsupportedPassthrough:
            "这个视频的编码暂不支持原画质封装，请选择 iPhone 相机拍摄的 H.264 或 HEVC 视频。".appLocalized
        case .writeFailed(let reason):
            String(format: "实况照片生成失败：%@".appLocalized, reason)
        case .permissionDenied:
            "没有相册写入权限。请在系统设置中允许“灵动照片”添加照片。".appLocalized
        case .photoLibraryFailed:
            "无法保存到系统相册，请确认设备存储空间后重试。".appLocalized
        }
    }
}

struct VideoToLivePhotoGlyph: View {
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "video.fill")
                .font(.system(size: 25, weight: .medium))
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .bold))
            Image(systemName: "livephoto")
                .font(.system(size: 24, weight: .medium))
        }
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }
}

struct PrivacyPreservingVideoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let colorScheme: ColorScheme
    let onSelection: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        picker.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        uiViewController.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PrivacyPreservingVideoPicker

        init(parent: PrivacyPreservingVideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                parent.isPresented = false
                return
            }
            let typeIdentifier = provider.registeredTypeIdentifiers.first { identifier in
                UTType(identifier)?.conforms(to: .movie) == true
            } ?? UTType.movie.identifier
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let url else {
                    DispatchQueue.main.async {
                        self.parent.onSelection(.failure(error ?? VideoToLivePhotoError.unreadableVideo))
                        self.parent.isPresented = false
                    }
                    return
                }
                let fileExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("lingdong-video-source-\(UUID().uuidString)")
                    .appendingPathExtension(fileExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: destination)
                    DispatchQueue.main.async {
                        self.parent.onSelection(.success(destination))
                        self.parent.isPresented = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.onSelection(.failure(error))
                        self.parent.isPresented = false
                    }
                }
            }
        }
    }
}

@MainActor
final class VideoToLivePhotoModel: ObservableObject {
    static let standardDuration = 3.0

    @Published private(set) var sourceURL: URL?
    @Published private(set) var duration = 0.0
    @Published private(set) var clipDuration = standardDuration
    @Published var clipStart = 0.0
    @Published var coverOffset = standardDuration / 2
    @Published private(set) var coverImage: UIImage?
    @Published private(set) var thumbnails: [UIImage] = []
    @Published private(set) var timelineThumbnails: [UIImage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var progress = 0.0
    @Published private(set) var saved = false
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?

    let player = AVPlayer()
    private var thumbnailRevision = 0
    private var timelineRevision = 0
    private var playbackTask: Task<Void, Never>?
    private var coverTask: Task<Void, Never>?

    var clipStartRange: ClosedRange<Double> {
        0...max(0, duration - clipDuration)
    }

    var absoluteCoverTime: Double {
        clipStart + min(max(coverOffset, 0), clipDuration)
    }

    func loadVideo(at url: URL) async {
        stopPlayback()
        cleanupSource()
        isLoading = true
        saved = false
        thumbnails = []
        timelineThumbnails = []
        coverImage = nil
        errorMessage = nil
        do {
            let asset = AVURLAsset(url: url)
            let loadedDuration = try await asset.load(.duration)
            guard loadedDuration.isValid, loadedDuration.seconds >= Self.standardDuration else {
                throw VideoToLivePhotoError.videoTooShort
            }
            guard try await asset.loadTracks(withMediaType: .video).first != nil else {
                throw VideoToLivePhotoError.unreadableVideo
            }
            sourceURL = url
            duration = loadedDuration.seconds
            clipDuration = min(Self.standardDuration, duration)
            clipStart = 0
            coverOffset = clipDuration / 2
            player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            await refreshTimelineThumbnails()
            await refreshThumbnails()
            await refreshCoverImage()
            seekToCover()
        } catch {
            try? FileManager.default.removeItem(at: url)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func clipStartChanged() {
        saved = false
        coverOffset = min(coverOffset, clipDuration)
        seekToCover()
    }

    func selectClip(normalizedProgress: Double) {
        let normalized = min(max(normalizedProgress, 0), 1)
        clipStart = clipStartRange.upperBound * normalized
        clipStartChanged()
    }

    func finishChangingClipStart() {
        Task { await refreshThumbnails() }
        scheduleCoverRefresh()
    }

    func selectCover(normalizedProgress: Double) {
        saved = false
        let normalized = min(max(normalizedProgress, 0), 1)
        coverOffset = clipDuration * normalized
        if !thumbnails.isEmpty {
            let index = min(
                thumbnails.count - 1,
                max(0, Int((normalized * Double(thumbnails.count - 1)).rounded()))
            )
            coverImage = thumbnails[index]
        }
        seekToCover()
        scheduleCoverRefresh()
    }

    func playSelectedClip() {
        guard sourceURL != nil else { return }
        stopPlayback()
        player.seek(
            to: CMTime(seconds: clipStart, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        isPlaying = true
        player.play()
        playbackTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(clipDuration))
            guard !Task.isCancelled else { return }
            player.pause()
            isPlaying = false
            seekToCover()
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        player.pause()
        isPlaying = false
    }

    func save() async {
        guard let sourceURL, !isSaving else { return }
        isSaving = true
        saved = false
        errorMessage = nil
        progress = 0.05
        do {
            try await VideoToLivePhotoExporter.save(
                sourceURL: sourceURL,
                clipStart: clipStart,
                duration: clipDuration,
                coverOffset: coverOffset
            ) { [weak self] value in
                self?.progress = value
            }
            progress = 1
            saved = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isSaving = false
    }

    func cleanup() {
        stopPlayback()
        coverTask?.cancel()
        player.replaceCurrentItem(with: nil)
        cleanupSource()
    }

    private func refreshThumbnails() async {
        guard let sourceURL else { return }
        thumbnailRevision += 1
        let revision = thumbnailRevision
        let asset = AVURLAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 360)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
        var loaded: [UIImage] = []
        let count = 9
        for index in 0..<count {
            let progress = count == 1 ? 0 : Double(index) / Double(count - 1)
            let second = min(duration - 1.0 / 600.0, clipStart + clipDuration * progress)
            if let image = try? await generator.image(
                at: CMTime(seconds: max(0, second), preferredTimescale: 600)
            ).image {
                loaded.append(UIImage(cgImage: image))
            }
        }
        guard revision == thumbnailRevision, !loaded.isEmpty else { return }
        thumbnails = loaded
    }

    private func refreshTimelineThumbnails() async {
        guard let sourceURL else { return }
        timelineRevision += 1
        let revision = timelineRevision
        let asset = AVURLAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 15)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 15)
        var loaded: [UIImage] = []
        let count = 12
        for index in 0..<count {
            let progress = count == 1 ? 0 : Double(index) / Double(count - 1)
            let second = min(duration - 1.0 / 600.0, duration * progress)
            if let image = try? await generator.image(
                at: CMTime(seconds: max(0, second), preferredTimescale: 600)
            ).image {
                loaded.append(UIImage(cgImage: image))
            }
        }
        guard revision == timelineRevision, !loaded.isEmpty else { return }
        timelineThumbnails = loaded
    }

    private func scheduleCoverRefresh() {
        coverTask?.cancel()
        coverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await self?.refreshCoverImage()
        }
    }

    private func refreshCoverImage() async {
        guard let sourceURL else { return }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: sourceURL))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let time = CMTime(seconds: absoluteCoverTime, preferredTimescale: 600)
        if let image = try? await generator.image(at: time).image {
            coverImage = UIImage(cgImage: image)
        }
    }

    private func seekToCover() {
        player.seek(
            to: CMTime(seconds: absoluteCoverTime, preferredTimescale: 600),
            toleranceBefore: CMTime(value: 1, timescale: 60),
            toleranceAfter: CMTime(value: 1, timescale: 60)
        )
    }

    private func cleanupSource() {
        if let sourceURL,
           sourceURL.lastPathComponent.hasPrefix("lingdong-video-source-") {
            try? FileManager.default.removeItem(at: sourceURL)
        }
        sourceURL = nil
    }
}

struct VideoToLivePhotoScreen: View {
    private enum EditorStep {
        case clip
        case cover
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = VideoToLivePhotoModel()
    @State private var pickerPresented = false
    @State private var editorStep: EditorStep = .clip

    var body: some View {
        NavigationStack {
            Group {
                if model.sourceURL == nil {
                    emptyState
                } else {
                    editor
                }
            }
            .navigationTitle("视频转实况")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭", systemImage: "xmark", action: dismiss.callAsFunction)
                }
                if model.sourceURL != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("重新选择", systemImage: "arrow.triangle.2.circlepath") {
                            pickerPresented = true
                        }
                            .labelStyle(.iconOnly)
                            .disabled(model.isSaving)
                    }
                }
            }
            .sheet(isPresented: $pickerPresented) {
                PrivacyPreservingVideoPicker(
                    isPresented: $pickerPresented,
                    colorScheme: colorScheme
                ) { result in
                    switch result {
                    case .success(let url):
                        editorStep = .clip
                        Task { await model.loadVideo(at: url) }
                    case .failure(let error):
                        model.errorMessage = error.localizedDescription
                    }
                }
                .ignoresSafeArea()
            }
            .alert("无法完成转换", isPresented: errorPresented) {
                Button("好", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
        .onDisappear { model.cleanup() }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()
            VideoToLivePhotoGlyph(color: .primary)
                .scaleEffect(1.9)
                .frame(width: 110, height: 130)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: 9) {
                Text("把相机视频变成实况照片")
                    .font(.title2.bold())
                Text("选择视频后截取 3 秒片段，再挑选长按前显示的实况封面。兼容的视频不会重新压缩动态画面。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 330)
            }

            Button {
                pickerPresented = true
            } label: {
                Label("选择视频", systemImage: "video.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: 280, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Text("所有处理均在设备本机完成")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(24)
    }

    private var editor: some View {
        ScrollView {
            VStack(spacing: 24) {
                preview

                Group {
                    switch editorStep {
                    case .clip:
                        clipSelectionStep
                    case .cover:
                        coverSelectionStep
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .scrollIndicators(.hidden)
        .overlay {
            if model.isLoading {
                ProgressView("正在读取视频…")
                    .padding(22)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private var clipSelectionStep: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("选择 3 秒片段")
                        .font(.headline)
                    Spacer()
                    Text("\(timeText(model.clipStart)) – \(timeText(model.clipStart + model.clipDuration))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text("拖动白框选择片段，框内固定为 3 秒")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VideoClipSelectionStrip(
                    thumbnails: model.timelineThumbnails,
                    duration: model.duration,
                    clipDuration: model.clipDuration,
                    clipStart: model.clipStart,
                    onSelect: model.selectClip,
                    onSelectionEnded: model.finishChangingClipStart
                )

                HStack {
                    Text("00:00.0")
                    Spacer()
                    Text(timeText(model.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            }

            Button {
                model.finishChangingClipStart()
                withAnimation(.snappy(duration: 0.32)) {
                    editorStep = .cover
                }
            } label: {
                Label("下一步：选择实况封面", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(model.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private var coverSelectionStep: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Button("重新选择视频片段", systemImage: "chevron.left") {
                    withAnimation(.snappy(duration: 0.32)) {
                        editorStep = .clip
                    }
                }
                .font(.caption.weight(.semibold))

                Text("选择实况封面")
                    .font(.headline)

                Text("拖动白框，选择长按前显示的照片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LivePhotoCoverStrip(
                    thumbnails: model.thumbnails,
                    progress: model.clipDuration > 0
                        ? model.coverOffset / model.clipDuration
                        : 0.5,
                    onSelect: model.selectCover
                )
            }

            VStack(spacing: 10) {
                Button {
                    Task { await model.save() }
                } label: {
                    HStack(spacing: 9) {
                        if model.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: model.saved ? "checkmark.circle.fill" : "livephoto")
                        }
                        Text(model.saved ? "已保存到照片" : "生成实况照片")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(model.isSaving || model.isLoading)

                if model.isSaving {
                    ProgressView(value: model.progress)
                        .tint(.primary)
                }

                Text("动态画面优先采用原画质封装；封面从原视频完整尺寸画面生成。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private var preview: some View {
        ZStack {
            Color.black
            if model.player.currentItem != nil {
                VideoPlayerSurface(player: model.player)
            } else if let image = model.coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            if !model.isPlaying {
                Button(action: model.playSelectedClip) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(.black.opacity(0.42), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.42), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("播放所选片段")
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func timeText(_ seconds: Double) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%04.1f", Int(value) / 60, value.truncatingRemainder(dividingBy: 60))
    }
}

private struct VideoPlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspect
            backgroundColor = .black
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

private struct VideoClipSelectionStrip: View {
    let thumbnails: [UIImage]
    let duration: Double
    let clipDuration: Double
    let clipStart: Double
    let onSelect: (Double) -> Void
    let onSelectionEnded: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let exactWindowWidth = duration > 0
                ? width * CGFloat(min(clipDuration / duration, 1))
                : width
            let windowWidth = min(width, max(6, exactWindowWidth))
            let travel = max(0, width - windowWidth)
            let startRange = max(0, duration - clipDuration)
            let progress = startRange > 0
                ? min(max(clipStart / startRange, 0), 1)
                : 0
            let windowX = travel * CGFloat(progress)
            let imageWidth = width / CGFloat(max(thumbnails.count, 1))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .systemGray3))

                HStack(spacing: 0) {
                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageWidth, height: 84)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 0) {
                    Color.black.opacity(0.46)
                        .frame(width: windowX)
                    Color.clear
                        .frame(width: windowWidth)
                    Color.black.opacity(0.46)
                        .frame(maxWidth: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white, lineWidth: 5)
                    .frame(width: windowWidth, height: 84)
                    .shadow(color: .black.opacity(0.34), radius: 4, y: 2)
                    .offset(x: windowX)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard travel > 0 else { return }
                        let location = min(
                            max(value.location.x - windowWidth / 2, 0),
                            travel
                        )
                        onSelect(Double(location / travel))
                    }
                    .onEnded { _ in
                        onSelectionEnded()
                    }
            )
        }
        .frame(height: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("视频片段位置")
        .accessibilityValue("\(Int(clipStart.rounded())) s")
        .accessibilityAdjustableAction { direction in
            let startRange = max(0, duration - clipDuration)
            let progress = startRange > 0 ? clipStart / startRange : 0
            let step = startRange > 0 ? min(1, 0.5 / startRange) : 0
            switch direction {
            case .increment: onSelect(min(1, progress + step))
            case .decrement: onSelect(max(0, progress - step))
            @unknown default: break
            }
            onSelectionEnded()
        }
    }
}

private struct LivePhotoCoverStrip: View {
    let thumbnails: [UIImage]
    let progress: Double
    let onSelect: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let stripWidth = max(1, proxy.size.width)
            let selectorWidth: CGFloat = 58
            let horizontalInset: CGFloat = 8
            let thumbnailHeight: CGFloat = 72
            let thumbnailCount = max(thumbnails.count, 1)
            let thumbnailContentWidth = max(0, stripWidth - horizontalInset * 2)
            let thumbnailWidth = thumbnailContentWidth / CGFloat(thumbnailCount)
            let usableWidth = max(1, stripWidth - selectorWidth)
            let selectorX = usableWidth * CGFloat(min(max(progress, 0), 1))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .systemGray3))

                HStack(spacing: 0) {
                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: thumbnailWidth, height: thumbnailHeight)
                            .clipped()
                    }
                }
                .frame(width: thumbnailContentWidth, height: thumbnailHeight, alignment: .leading)
                .padding(horizontalInset)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white, lineWidth: 5)
                    .frame(width: selectorWidth, height: 76)
                    .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
                    .offset(x: selectorX)

                Circle()
                    .fill(.white)
                    .frame(width: 9, height: 9)
                    .offset(x: selectorX + selectorWidth / 2 - 4.5, y: -13)
            }
            .frame(width: stripWidth, height: 88)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = min(
                            max(value.location.x - selectorWidth / 2, 0),
                            usableWidth
                        )
                        onSelect(Double(location / usableWidth))
                    }
            )
        }
        .frame(height: 88)
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("实况封面位置")
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            let step = 1.0 / 30.0
            switch direction {
            case .increment: onSelect(min(1, progress + step))
            case .decrement: onSelect(max(0, progress - step))
            @unknown default: break
            }
        }
    }
}

enum VideoToLivePhotoExporter {
    static func save(
        sourceURL: URL,
        clipStart: Double,
        duration: Double,
        coverOffset: Double,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoToLivePhotoError.unreadableVideo
        }
        let assetDuration = try await asset.load(.duration).seconds
        let safeStart = min(max(0, clipStart), max(0, assetDuration - 0.1))
        let safeDuration = min(max(0.1, duration), assetDuration - safeStart)
        let safeCoverOffset = min(max(coverOffset, 0), safeDuration)
        let identifier = UUID().uuidString
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-live-conversion-\(identifier)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        progress(0.12)
        let photoURL = temporaryDirectory.appendingPathComponent("cover.heic")
        let videoURL = temporaryDirectory.appendingPathComponent("paired.mov")
        try await makeCoverPhoto(
            asset: asset,
            at: safeStart + safeCoverOffset,
            identifier: identifier,
            destinationURL: photoURL
        )

        progress(0.28)
        try await makePairedVideo(
            asset: asset,
            videoTrack: videoTrack,
            start: safeStart,
            duration: safeDuration,
            coverOffset: safeCoverOffset,
            identifier: identifier,
            destinationURL: videoURL,
            progress: progress
        )

        progress(0.90)
        try await saveToPhotoLibrary(photoURL: photoURL, videoURL: videoURL)
        progress(1)
    }

    private static func makeCoverPhoto(
        asset: AVURLAsset,
        at seconds: Double,
        identifier: String,
        destinationURL: URL
    ) async throws {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image: CGImage
        do {
            image = try await generator.image(
                at: CMTime(seconds: seconds, preferredTimescale: 600)
            ).image
        } catch {
            throw VideoToLivePhotoError.frameUnavailable
        }
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw VideoToLivePhotoError.frameUnavailable
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 1,
            kCGImageDestinationLossyCompressionQuality: 1.0,
            kCGImagePropertyMakerAppleDictionary: ["17": identifier]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw VideoToLivePhotoError.frameUnavailable
        }
    }

    private static func makePairedVideo(
        asset: AVURLAsset,
        videoTrack: AVAssetTrack,
        start: Double,
        duration: Double,
        coverOffset: Double,
        identifier: String,
        destinationURL: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mov)
        guard let videoDescription = try await videoTrack.load(.formatDescriptions).first else {
            throw VideoToLivePhotoError.unsupportedPassthrough
        }
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: nil,
            sourceFormatHint: videoDescription
        )
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = try await videoTrack.load(.preferredTransform)
        guard writer.canAdd(videoInput) else {
            throw VideoToLivePhotoError.unsupportedPassthrough
        }
        writer.add(videoInput)

        let videoReader = try AVAssetReader(asset: asset)
        videoReader.timeRange = timeRange
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        videoOutput.alwaysCopiesSampleData = false
        guard videoReader.canAdd(videoOutput) else {
            throw VideoToLivePhotoError.unsupportedPassthrough
        }
        videoReader.add(videoOutput)

        var audioTransfer: (
            reader: AVAssetReader,
            output: AVAssetReaderTrackOutput,
            input: AVAssetWriterInput
        )?
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let audioDescription = try await audioTrack.load(.formatDescriptions).first {
            let audioInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: nil,
                sourceFormatHint: audioDescription
            )
            let audioReader = try AVAssetReader(asset: asset)
            audioReader.timeRange = timeRange
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            audioOutput.alwaysCopiesSampleData = false
            if writer.canAdd(audioInput), audioReader.canAdd(audioOutput) {
                writer.add(audioInput)
                audioReader.add(audioOutput)
                audioTransfer = (audioReader, audioOutput, audioInput)
            }
        }

        let identifierItem = AVMutableMetadataItem()
        identifierItem.key = "com.apple.quicktime.content.identifier" as NSString
        identifierItem.keySpace = .quickTimeMetadata
        identifierItem.value = identifier as NSString
        writer.metadata = [identifierItem]

        let stillTimeItem = AVMutableMetadataItem()
        stillTimeItem.key = "com.apple.quicktime.still-image-time" as NSString
        stillTimeItem.keySpace = .quickTimeMetadata
        stillTimeItem.value = 0 as NSNumber
        stillTimeItem.dataType = kCMMetadataBaseDataType_SInt8 as String
        let specification: [CFString: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier:
                "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType:
                kCMMetadataBaseDataType_SInt8
        ]
        var metadataDescription: CMFormatDescription?
        let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [specification] as CFArray,
            formatDescriptionOut: &metadataDescription
        )
        guard status == noErr, let metadataDescription else {
            throw VideoToLivePhotoError.writeFailed("无法创建实况封面时间标记。".appLocalized)
        }
        let metadataInput = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: metadataDescription
        )
        guard writer.canAdd(metadataInput) else {
            throw VideoToLivePhotoError.unsupportedPassthrough
        }
        writer.add(metadataInput)
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)

        guard writer.startWriting() else {
            throw VideoToLivePhotoError.writeFailed(
                writer.error?.localizedDescription ?? "视频写入器无法启动。".appLocalized
            )
        }
        writer.startSession(atSourceTime: timeRange.start)
        let coverTime = CMTimeAdd(
            timeRange.start,
            CMTime(seconds: coverOffset, preferredTimescale: 600)
        )
        let group = AVTimedMetadataGroup(
            items: [stillTimeItem],
            timeRange: CMTimeRange(
                start: coverTime,
                duration: CMTime(value: 1, timescale: 30)
            )
        )
        guard metadataAdaptor.append(group) else {
            writer.cancelWriting()
            throw VideoToLivePhotoError.writeFailed("无法写入实况封面时间标记。".appLocalized)
        }
        metadataInput.markAsFinished()

        guard videoReader.startReading() else {
            writer.cancelWriting()
            throw VideoToLivePhotoError.unsupportedPassthrough
        }
        if let audioTransfer, !audioTransfer.reader.startReading() {
            writer.cancelWriting()
            throw VideoToLivePhotoError.unsupportedPassthrough
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await transferSamples(
                        reader: videoReader,
                        output: videoOutput,
                        input: videoInput,
                        writer: writer,
                        timeRange: timeRange,
                        reportsProgress: true,
                        progress: progress
                    )
                }
                if let audioTransfer {
                    group.addTask {
                        try await transferSamples(
                            reader: audioTransfer.reader,
                            output: audioTransfer.output,
                            input: audioTransfer.input,
                            writer: writer,
                            timeRange: timeRange,
                            reportsProgress: false,
                            progress: progress
                        )
                    }
                }
                try await group.waitForAll()
            }
        } catch {
            writer.cancelWriting()
            throw error
        }

        await writer.finishWriting()
        guard writer.status == .completed else {
            throw VideoToLivePhotoError.writeFailed(
                writer.error?.localizedDescription ?? "动态视频未完成。".appLocalized
            )
        }
    }

    private static func transferSamples(
        reader: AVAssetReader,
        output: AVAssetReaderTrackOutput,
        input: AVAssetWriterInput,
        writer: AVAssetWriter,
        timeRange: CMTimeRange,
        reportsProgress: Bool,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed {
                    throw VideoToLivePhotoError.writeFailed(
                        writer.error?.localizedDescription ?? "视频写入中断。".appLocalized
                    )
                }
                try await Task.sleep(for: .milliseconds(3))
            }
            guard input.append(sample) else {
                throw VideoToLivePhotoError.writeFailed(
                    writer.error?.localizedDescription ?? "视频帧写入失败。".appLocalized
                )
            }
            if reportsProgress {
                let elapsed = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                    - timeRange.start.seconds
                let fraction = min(max(elapsed / timeRange.duration.seconds, 0), 1)
                progress(0.30 + fraction * 0.55)
            }
        }
        input.markAsFinished()
        if reader.status == .failed {
            throw VideoToLivePhotoError.writeFailed(
                reader.error?.localizedDescription ?? "无法读取原始视频数据。".appLocalized
            )
        }
    }

    private static func saveToPhotoLibrary(photoURL: URL, videoURL: URL) async throws {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let authorization: PHAuthorizationStatus
        if current == .notDetermined {
            authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            authorization = current
        }
        guard authorization == .authorized || authorization == .limited else {
            throw VideoToLivePhotoError.permissionDenied
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = .now
                let photoOptions = PHAssetResourceCreationOptions()
                photoOptions.originalFilename = "\("灵动照片".appLocalized)-Live.heic"
                photoOptions.uniformTypeIdentifier = UTType.heic.identifier
                request.addResource(with: .photo, fileURL: photoURL, options: photoOptions)
                let videoOptions = PHAssetResourceCreationOptions()
                videoOptions.originalFilename = "\("灵动照片".appLocalized)-Live.mov"
                videoOptions.uniformTypeIdentifier = UTType.quickTimeMovie.identifier
                request.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? VideoToLivePhotoError.photoLibraryFailed)
                }
            }
        }
    }
}
