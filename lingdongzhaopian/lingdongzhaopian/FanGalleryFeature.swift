import CoreImage
import Combine
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit

private enum FanGalleryMode: String, CaseIterable, Identifiable {
    case automatic
    case manual
    case single

    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "自动寻色".appLocalized
        case .manual: "自由编排".appLocalized
        case .single: "单张成扇".appLocalized
        }
    }
}

private struct FanCrop: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero
}

private struct FanPhoto: Identifiable {
    let id: UUID
    var image: UIImage
    var crop = FanCrop()
    var revision = UUID()

    init(image: UIImage) {
        id = UUID()
        self.image = image
    }
}

private struct FanSelectionResult {
    let indices: [Int]
    let title: String
}

@MainActor
private final class FanGalleryModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case requestingPermission
        case readingLibrary
        case readingSelection
        case arranging
        case cycling
        case finished
        case failed(String)
    }

    @Published var slots: [FanPhoto?] = Array(repeating: nil, count: 6)
    @Published var phase: Phase = .idle
    @Published var resultTitle = "点击“开始寻找”后，才会请求相册权限并开始取样。".appLocalized
    @Published var countdown = 10
    @Published var singleImage: UIImage?

    private var candidates: [UIImage] = []
    private var finalImages: [UIImage] = []
    private var runTask: Task<Void, Never>?
    private var slotTasks: [Task<Void, Never>] = []

    var hasCandidateSample: Bool { candidates.count >= 6 }

    var isBusy: Bool {
        switch phase {
        case .requestingPermission, .readingLibrary, .readingSelection, .arranging, .cycling: true
        default: false
        }
    }

    func beginAutomatic() {
        cancel()
        clearSlots()
        runTask = Task { [weak self] in
            guard let self else { return }
            phase = .requestingPermission
            let status = await FanPhotoLibrary.requestReadAccess()
            guard !Task.isCancelled else { return }
            guard status == .authorized || status == .limited else {
                phase = .failed("需要相册读取权限，才能随机寻找六张照片。".appLocalized)
                return
            }

            phase = .readingLibrary
            let loaded = await FanPhotoLibrary.loadRandomThumbnails(limit: 120)
            guard !Task.isCancelled else { return }
            guard loaded.count >= 6 else {
                phase = .failed("当前授权范围内不足六张照片。请在系统设置中允许更多照片。".appLocalized)
                return
            }
            candidates = loaded

            phase = .arranging
            let selection = await FanPhotoMatcher.chooseSix(from: loaded)
            guard !Task.isCancelled else { return }
            guard selection.indices.count == 6 else {
                finalImages = []
                phase = .failed(selection.title)
                return
            }
            finalImages = selection.indices.map { loaded[$0] }
            resultTitle = selection.title
            await runShuffleSequence()
        }
    }

    func restartAutomatic() {
        if candidates.count >= 6 {
            cancelTasksOnly()
            runTask = Task { [weak self] in
                guard let self else { return }
                phase = .arranging
                let shuffledCandidates = candidates.shuffled()
                let stableSelection = await FanPhotoMatcher.chooseSix(from: shuffledCandidates)
                guard !Task.isCancelled else { return }
                guard stableSelection.indices.count == 6 else {
                    finalImages = []
                    phase = .failed(stableSelection.title)
                    return
                }
                finalImages = stableSelection.indices.map { shuffledCandidates[$0] }
                resultTitle = stableSelection.title
                await runShuffleSequence()
            }
        } else {
            beginAutomatic()
        }
    }

    func loadManualSelections(_ items: [PhotosPickerItem]) {
        cancelTasksOnly()
        clearSlots()
        let selections = Array(items.prefix(6))
        guard !selections.isEmpty else {
            phase = .idle
            return
        }
        phase = .readingSelection
        resultTitle = "正在读取所选照片…".appLocalized
        runTask = Task { [weak self] in
            guard let self else { return }
            var slotIndex = 0
            for item in selections {
                guard !Task.isCancelled else { return }
                guard let image = await FanPhotoLibrary.loadPickerItem(item) else { continue }
                guard !Task.isCancelled else { return }
                slots[slotIndex] = FanPhoto(image: image)
                slotIndex += 1
                await Task.yield()
            }
            guard !Task.isCancelled else { return }
            if slotIndex == 0 {
                phase = .failed("无法读取所选照片，请确认原片已下载后重试。".appLocalized)
            } else {
                phase = .finished
                resultTitle = "轻点任一扇面，可放大并调整取景。".appLocalized
            }
        }
    }

    func loadSingleSelection(_ item: PhotosPickerItem) {
        cancelTasksOnly()
        clearSlots()
        phase = .readingSelection
        resultTitle = "正在读取所选照片…".appLocalized
        runTask = Task { [weak self] in
            guard let self else { return }
            guard let image = await FanPhotoLibrary.loadPickerItem(item) else {
                guard !Task.isCancelled else { return }
                phase = .failed("无法读取所选照片，请确认原片已下载后重试。".appLocalized)
                return
            }
            guard !Task.isCancelled else { return }
            singleImage = image
            for index in 0..<6 {
                slots[index] = FanPhoto(image: image)
            }
            phase = .finished
            resultTitle = "双指缩放预览，细看扇面上的连续画面。".appLocalized
        }
    }

    func prepareForSingle() {
        cancelTasksOnly()
        finalImages = []
        clearSlots()
        phase = .idle
        resultTitle = "选择一张照片，自动铺满六瓣扇面。".appLocalized
    }

    func prepareForAutomatic() {
        cancelTasksOnly()
        finalImages = []
        clearSlots()
        phase = .idle
        resultTitle = hasCandidateSample
            ? "可以从本次样本继续寻找，也可主动再次遍历相册。".appLocalized
            : "点击“开始寻找”后，才会请求相册权限并开始取样。".appLocalized
    }

    func prepareForManual() {
        cancelTasksOnly()
        finalImages = []
        clearSlots()
        phase = .idle
        resultTitle = "请选择至多六张照片，自由编排你的折扇。".appLocalized
    }

    func replace(image: UIImage, at index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index] = FanPhoto(image: image)
    }

    func updateCrop(_ crop: FanCrop, at index: Int) {
        guard slots.indices.contains(index), slots[index] != nil else { return }
        slots[index]?.crop = crop
    }

    func cancel() {
        cancelTasksOnly()
        candidates = []
        finalImages = []
        singleImage = nil
    }

    private func cancelTasksOnly() {
        runTask?.cancel()
        runTask = nil
        slotTasks.forEach { $0.cancel() }
        slotTasks.removeAll()
    }

    private func clearSlots() {
        slots = Array(repeating: nil, count: 6)
        singleImage = nil
    }

    private func runShuffleSequence() async {
        phase = .cycling
        countdown = 10
        for index in 0..<6 {
            if let image = candidates.randomElement() {
                slots[index] = FanPhoto(image: image)
            }
            let task = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    let delay = UInt64.random(in: 180_000_000...720_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    guard !Task.isCancelled, phase == .cycling,
                          let image = candidates.randomElement() else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if self.slots[index] != nil && Int.random(in: 0..<4) == 0 {
                            self.slots[index] = nil
                        } else if self.slots[index] == nil {
                            self.slots[index] = FanPhoto(image: image)
                        } else {
                            self.slots[index]?.image = image
                            self.slots[index]?.revision = UUID()
                        }
                    }
                }
            }
            slotTasks.append(task)
        }

        for remaining in stride(from: 10, through: 1, by: -1) {
            countdown = remaining
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
        }
        slotTasks.forEach { $0.cancel() }
        slotTasks.removeAll()
        withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
            for index in 0..<6 where finalImages.indices.contains(index) {
                slots[index] = FanPhoto(image: finalImages[index])
            }
            phase = .finished
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct FanGalleryFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = FanGalleryModel()
    @State private var mode = FanGalleryMode.automatic
    @State private var focusedIndex: Int?
    @State private var manualSelections: [PhotosPickerItem] = []
    @State private var singleSelection: PhotosPickerItem?
    @State private var previewScale: CGFloat = 1
    @State private var storedPreviewScale: CGFloat = 1
    @State private var isExporting = false
    @State private var exportNotice: String?

    var body: some View {
        NavigationStack {
            ZStack {
                fanBackground

                VStack(spacing: 0) {
                    header
                    statusLine
                        .padding(.top, 8)
                    Spacer(minLength: 8)

                    FanStage(
                        slots: model.slots,
                        singleImage: model.singleImage,
                        onSelect: { index in
                            guard mode == .manual, model.slots[index] != nil else { return }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                                focusedIndex = index
                            }
                        }
                    )
                    .blur(radius: focusedIndex == nil ? 0 : 12)
                    .scaleEffect((focusedIndex == nil ? 1 : 0.96) * previewScale)
                    .allowsHitTesting(focusedIndex == nil)
                    .frame(maxHeight: 520)
                    .gesture(singlePreviewZoomGesture)

                    Spacer(minLength: 10)
                    bottomControls
                        .padding(.bottom, 34)
                }
                .padding(.horizontal, 16)

                if let focusedIndex, let photo = model.slots[focusedIndex] {
                    FanFocusEditor(
                        photo: photo,
                        index: focusedIndex,
                        onCropChange: { model.updateCrop($0, at: focusedIndex) },
                        onReplace: { model.replace(image: $0, at: focusedIndex) },
                        onClose: {
                            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                                self.focusedIndex = nil
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .onDisappear { model.cancel() }
            .onChange(of: manualSelections) { _, items in
                guard !items.isEmpty else { return }
                guard mode == .manual else { return }
                model.loadManualSelections(items)
            }
            .onChange(of: singleSelection) { _, item in
                guard let item, mode == .single else { return }
                model.loadSingleSelection(item)
                singleSelection = nil
            }
            .onChange(of: mode) { _, newMode in
                focusedIndex = nil
                manualSelections = []
                singleSelection = nil
                previewScale = 1
                storedPreviewScale = 1
                switch newMode {
                case .automatic: model.prepareForAutomatic()
                case .manual: model.prepareForManual()
                case .single: model.prepareForSingle()
                }
            }
        }
    }

    private var singlePreviewZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard mode == .single, model.singleImage != nil else { return }
                previewScale = min(max(storedPreviewScale * value, 1), 3.2)
            }
            .onEnded { _ in
                guard mode == .single else { return }
                storedPreviewScale = previewScale
            }
    }

    private var fanBackground: some View {
        FanWarmBackground().ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭".appLocalized)

            VStack(alignment: .leading, spacing: 2) {
                Text("流光折扇".appLocalized)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                Text("六帧一境".appLocalized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Picker("模式".appLocalized, selection: $mode) {
                ForEach(FanGalleryMode.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white.opacity(0.84))
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 8) {
            if model.isBusy { ProgressView().controlSize(.small).tint(.white.opacity(0.76)) }
            Text(statusText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if mode == .automatic, model.hasCandidateSample, !model.isBusy {
                Button("再次遍历".appLocalized) {
                    model.beginAutomatic()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .buttonStyle(.plain)
                .disabled(isExporting)
                .accessibilityHint("重新随机抽取相册样本".appLocalized)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .accessibilityIdentifier("fanGallery.status")
    }

    private var statusText: String {
        if let exportNotice { return exportNotice }
        switch model.phase {
        case .idle: return model.resultTitle
        case .requestingPermission: return "正在请求相册授权…".appLocalized
        case .readingLibrary: return "正在从授权照片中随机取样…".appLocalized
        case .readingSelection: return "正在读取所选照片…".appLocalized
        case .arranging: return "正在本机寻找同一色系的照片…".appLocalized
        case .cycling: return String(format: "%@ · %d", "照片正在流转".appLocalized, model.countdown)
        case .finished: return model.resultTitle
        case .failed(let message): return message
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        HStack(spacing: 12) {
            if mode == .automatic {
                Button {
                    if model.hasCandidateSample {
                        model.restartAutomatic()
                    } else {
                        model.beginAutomatic()
                    }
                } label: {
                    Label(
                        model.hasCandidateSample ? "再寻一组".appLocalized : "开始寻找".appLocalized,
                        systemImage: model.hasCandidateSample ? "shuffle" : "sparkle.magnifyingglass"
                    )
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .disabled(model.isBusy)
            } else if mode == .single {
                PhotosPicker(
                    selection: $singleSelection,
                    matching: .images
                ) {
                    Label("选择一张照片".appLocalized, systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .disabled(model.isBusy)
            } else {
                PhotosPicker(
                    selection: $manualSelections,
                    maxSelectionCount: 6,
                    matching: .images
                ) {
                    Label("选择至多六张".appLocalized, systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }

            Divider()
                .overlay(.white.opacity(0.16))
                .frame(height: 24)

            Button {
                Task { await exportArtwork() }
            } label: {
                Group {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Label("保存成品".appLocalized, systemImage: "square.and.arrow.down")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .disabled(isExporting || model.isBusy || model.slots.contains(where: { $0 == nil }))
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    @MainActor
    private func exportArtwork() async {
        guard !isExporting, model.slots.allSatisfy({ $0 != nil }) else { return }
        isExporting = true
        exportNotice = "正在制作高清折扇…".appLocalized

        let renderer = ImageRenderer(content: FanExportArtwork(slots: model.slots, singleImage: model.singleImage))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 2400, height: 1800)
        renderer.isOpaque = false

        guard let image = renderer.uiImage else {
            isExporting = false
            showExportNotice("成品渲染失败，请稍后重试。".appLocalized)
            return
        }

        do {
            try await FanPhotoLibrary.saveToPhotos(image)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showExportNotice("透明 PNG 已保存到系统照片 · 2400 × 1800".appLocalized)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showExportNotice(error.localizedDescription)
        }
        isExporting = false
    }

    private func showExportNotice(_ notice: String) {
        exportNotice = notice
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            if exportNotice == notice { exportNotice = nil }
        }
    }
}

private struct FanWarmBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.095, blue: 0.07),
                    Color(red: 0.48, green: 0.245, blue: 0.15),
                    Color(red: 0.31, green: 0.12, blue: 0.075),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Color(red: 0.88, green: 0.56, blue: 0.31).opacity(0.74),
                    Color(red: 0.66, green: 0.34, blue: 0.19).opacity(0.32),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.53),
                startRadius: 24,
                endRadius: 560
            )
            LinearGradient(
                colors: [.black.opacity(0.24), .clear, .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct FanExportArtwork: View {
    let slots: [FanPhoto?]
    var singleImage: UIImage? = nil

    var body: some View {
        ZStack {
            Color.clear
            FanStage(
                slots: slots,
                singleImage: singleImage,
                onSelect: { _ in }
            )
            .frame(width: 2180, height: 1540)
        }
        .frame(width: 2400, height: 1800)
    }
}

private struct FanStage: View {
    let slots: [FanPhoto?]
    var singleImage: UIImage? = nil
    let onSelect: (Int) -> Void

    private let artworkRatio: CGFloat = 1178 / 912

    var body: some View {
        GeometryReader { proxy in
            let artSize = fittedArtworkSize(in: proxy.size)
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.12, blue: 0.10).opacity(0.16))
                    .frame(width: artSize.width * 0.72, height: artSize.height * 0.28)
                    .blur(radius: 34)
                    .offset(y: artSize.height * 0.13)

                ForEach(0..<6, id: \.self) { index in
                    ReferenceFanLeaf(
                        slot: slots.indices.contains(index) ? slots[index] : nil,
                        index: index,
                        singleImage: singleImage
                    )
                    .frame(width: artSize.width, height: artSize.height)
                    .zIndex(Double(index))
                    .onTapGesture { onSelect(index) }
                    .accessibilityLabel(String(format: "第 %d 个扇面".appLocalized, index + 1))
                    .accessibilityHint("轻点放大并编辑照片".appLocalized)
                }

                FanReferenceCenter()
                    .frame(width: artSize.width, height: artSize.height)
                    .zIndex(20)
            }
            .frame(width: artSize.width, height: artSize.height)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fanGallery.stage")
    }

    private func fittedArtworkSize(in available: CGSize) -> CGSize {
        let maximumWidth = max(220, available.width - 2)
        let maximumHeight = max(180, available.height - 8)
        let width = min(maximumWidth, maximumHeight * artworkRatio)
        return CGSize(width: width, height: width / artworkRatio)
    }
}

private struct ReferenceFanLeaf: View {
    let slot: FanPhoto?
    let index: Int
    var singleImage: UIImage? = nil

    var body: some View {
        GeometryReader { proxy in
            let photoShape = ReferenceFanSectorShape(index: index, innerRadiusRatio: 0.173)
            let wholeLeafShape = ReferenceFanSectorShape(index: index, innerRadiusRatio: 0)
            ZStack {
                photoShape.fill(Color(white: 0.12))

                if let singleImage {
                    FanSliceImage(image: singleImage)
                        .mask(photoShape)
                } else if let slot {
                    FanCroppedImage(image: slot.image, crop: slot.crop)
                        .id(slot.revision)
                        .transition(.opacity.combined(with: .scale(scale: 1.025)))
                        .mask(photoShape)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: max(22, proxy.size.width * 0.055), weight: .light))
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .mask(photoShape)
                }

                if let artwork = FanReferenceArtwork.image {
                    Image(uiImage: artwork)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .mask(wholeLeafShape)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(photoShape)
            .drawingGroup()
        }
    }
}

private struct FanSliceImage: View {
    let image: UIImage

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

private struct ReferenceFanSectorShape: Shape {
    let index: Int
    let innerRadiusRatio: CGFloat

    private let boundaries: [Double] = [-165, -140, -115, -90, -65, -40, -15]

    func path(in rect: CGRect) -> Path {
        guard boundaries.indices.contains(index), boundaries.indices.contains(index + 1) else { return Path() }
        let pivot = CGPoint(x: rect.width * 0.5, y: rect.height * 0.678)
        let outerRadius = rect.width * 0.486
        let innerRadius = rect.width * innerRadiusRatio
        let start = Angle.degrees(boundaries[index])
        let end = Angle.degrees(boundaries[index + 1])
        let outerStart = point(center: pivot, radius: outerRadius, angle: start)
        let innerEnd = point(center: pivot, radius: innerRadius, angle: end)
        var path = Path()
        path.move(to: outerStart)
        path.addArc(
            center: pivot,
            radius: outerRadius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        path.addLine(to: innerEnd)
        if innerRadius > 0 {
            path.addArc(
                center: pivot,
                radius: innerRadius,
                startAngle: end,
                endAngle: start,
                clockwise: true
            )
        } else {
            path.addLine(to: pivot)
        }
        path.closeSubpath()
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle.radians) * radius,
            y: center.y + sin(angle.radians) * radius
        )
    }
}

private struct FanReferenceCenter: View {
    var body: some View {
        GeometryReader { proxy in
            if let artwork = FanReferenceArtwork.image {
                Image(uiImage: artwork)
                    .resizable()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .mask(ReferenceFanCenterMask())
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ReferenceFanCenterMask: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.width * 0.31,
            y: rect.height * 0.43,
            width: rect.width * 0.38,
            height: rect.height * 0.57
        ))
    }
}

private enum FanReferenceArtwork {
    static let image: UIImage? = UIImage(named: "FanReference")?.removingWhiteBackgroundForFan()
}

private struct FanCroppedImage: View {
    let image: UIImage
    let crop: FanCrop

    var body: some View {
        GeometryReader { proxy in
            let imageSize = FanCropLayout.renderedImageSize(
                imageSize: image.size,
                canvasSize: proxy.size,
                scale: crop.scale
            )
            let maximumOffset = FanCropLayout.maximumOffset(
                imageSize: image.size,
                canvasSize: proxy.size,
                scale: crop.scale
            )
            Image(uiImage: image)
                .resizable()
                .frame(width: imageSize.width, height: imageSize.height)
                .offset(
                    x: crop.offset.width * maximumOffset.width,
                    y: crop.offset.height * maximumOffset.height
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

private enum FanCropLayout {
    static func renderedImageSize(imageSize: CGSize, canvasSize: CGSize, scale: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              canvasSize.width > 0, canvasSize.height > 0 else { return canvasSize }
        let imageRatio = imageSize.width / imageSize.height
        let canvasRatio = canvasSize.width / canvasSize.height
        let baseSize: CGSize
        if imageRatio > canvasRatio {
            baseSize = CGSize(width: canvasSize.height * imageRatio, height: canvasSize.height)
        } else {
            baseSize = CGSize(width: canvasSize.width, height: canvasSize.width / imageRatio)
        }
        return CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
    }

    static func maximumOffset(imageSize: CGSize, canvasSize: CGSize, scale: CGFloat) -> CGSize {
        let rendered = renderedImageSize(imageSize: imageSize, canvasSize: canvasSize, scale: scale)
        return CGSize(
            width: max(0, (rendered.width - canvasSize.width) / 2),
            height: max(0, (rendered.height - canvasSize.height) / 2)
        )
    }
}

private struct FanFocusEditor: View {
    let photo: FanPhoto
    let index: Int
    let onCropChange: (FanCrop) -> Void
    let onReplace: (UIImage) -> Void
    let onClose: () -> Void

    @State private var crop: FanCrop
    @State private var storedCrop: FanCrop
    @State private var replacement: PhotosPickerItem?

    init(
        photo: FanPhoto,
        index: Int,
        onCropChange: @escaping (FanCrop) -> Void,
        onReplace: @escaping (UIImage) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.photo = photo
        self.index = index
        self.onCropChange = onCropChange
        self.onReplace = onReplace
        self.onClose = onClose
        _crop = State(initialValue: photo.crop)
        _storedCrop = State(initialValue: photo.crop)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(format: "扇面 %d · 调整取景".appLocalized, index + 1))
                            .font(.headline)
                        Text("拖动照片移动取景，双指缩放；亮起的扇形就是最终保留区域。".appLocalized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: 38, height: 38)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                FanCropEditorCanvas(
                    image: photo.image,
                    index: index,
                    crop: $crop,
                    storedCrop: $storedCrop,
                    onCropChange: onCropChange
                )
                    .frame(maxWidth: 480)
                    .aspectRatio(1178 / 912, contentMode: .fit)
                    .accessibilityLabel("可拖动、缩放的照片取景区域".appLocalized)

                HStack(spacing: 12) {
                    PhotosPicker(selection: $replacement, matching: .images) {
                        Label("替换照片".appLocalized, systemImage: "photo.badge.arrow.down")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    Button {
                        crop = FanCrop()
                        storedCrop = crop
                        onCropChange(crop)
                    } label: {
                        Label("复位取景".appLocalized, systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .background(.thinMaterial, in: Capsule())
            }
            .padding(22)
            .frame(maxWidth: 520)
        }
        .onChange(of: replacement) { _, item in
            guard let item else { return }
            Task {
                if let image = await FanPhotoLibrary.loadPickerItem(item) {
                    onReplace(image)
                    crop = FanCrop()
                    storedCrop = crop
                    replacement = nil
                }
            }
        }
    }
}

private struct FanCropEditorCanvas: View {
    let image: UIImage
    let index: Int
    @Binding var crop: FanCrop
    @Binding var storedCrop: FanCrop
    let onCropChange: (FanCrop) -> Void

    var body: some View {
        GeometryReader { proxy in
            let photoShape = ReferenceFanSectorShape(index: index, innerRadiusRatio: 0.173)
            let wholeLeafShape = ReferenceFanSectorShape(index: index, innerRadiusRatio: 0)
            ZStack {
                FanCroppedImage(image: image, crop: crop)

                FanCropDimmingShape(index: index)
                    .fill(.black.opacity(0.72), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                if let artwork = FanReferenceArtwork.image {
                    Image(uiImage: artwork)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .mask(wholeLeafShape)
                        .allowsHitTesting(false)
                }

                photoShape
                    .stroke(.white.opacity(0.92), lineWidth: 2)
                    .shadow(color: .black.opacity(0.55), radius: 5)
                    .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(cropGesture(in: proxy.size))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private func cropGesture(in canvasSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let limit = FanCropLayout.maximumOffset(
                        imageSize: image.size,
                        canvasSize: canvasSize,
                        scale: crop.scale
                    )
                    crop.offset = CGSize(
                        width: clampedOffset(
                            storedCrop.offset.width,
                            translation: value.translation.width,
                            limit: limit.width
                        ),
                        height: clampedOffset(
                            storedCrop.offset.height,
                            translation: value.translation.height,
                            limit: limit.height
                        )
                    )
                    onCropChange(crop)
                }
                .onEnded { _ in storedCrop = crop },
            MagnificationGesture()
                .onChanged { value in
                    crop.scale = min(max(storedCrop.scale * value, 1), 5)
                    onCropChange(crop)
                }
                .onEnded { _ in storedCrop = crop }
        )
    }

    private func clampedOffset(_ original: CGFloat, translation: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit > 0.5 else { return 0 }
        return min(max(original + translation / limit, -1), 1)
    }
}

private struct FanCropDimmingShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(ReferenceFanSectorShape(index: index, innerRadiusRatio: 0.173).path(in: rect))
        return path
    }
}

private enum FanPhotoLibrary {
    enum ExportError: LocalizedError {
        case permissionDenied
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "需要允许添加照片，才能把折扇成品保存到系统照片。".appLocalized
            case .pngEncodingFailed:
                "透明 PNG 制作失败，请稍后重试。".appLocalized
            }
        }
    }

    static func requestReadAccess() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { continuation.resume(returning: $0) }
        }
    }

    static func loadRandomThumbnails(limit: Int) async -> [UIImage] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        guard result.count > 0 else { return [] }

        let sampleCount = min(result.count, max(6, limit))
        var sampledIndices = Set<Int>()
        sampledIndices.reserveCapacity(sampleCount)
        while sampledIndices.count < sampleCount {
            sampledIndices.insert(Int.random(in: 0..<result.count))
        }
        let chosen = sampledIndices.map { result.object(at: $0) }
        let manager = PHCachingImageManager()
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.version = .current

        var images: [UIImage] = []
        let batchSize = 8
        for start in stride(from: 0, to: chosen.count, by: batchSize) {
            guard !Task.isCancelled else { return images }
            let end = min(start + batchSize, chosen.count)
            let batch = Array(chosen[start..<end])
            let loaded = await withTaskGroup(of: UIImage?.self) { group in
                for asset in batch {
                    group.addTask {
                        await requestImage(
                            asset: asset,
                            manager: manager,
                            options: requestOptions,
                            targetSize: CGSize(width: 320, height: 320)
                        )
                    }
                }
                var batchImages: [UIImage] = []
                for await image in group {
                    if let image { batchImages.append(image) }
                }
                return batchImages
            }
            images.append(contentsOf: loaded)
        }
        return images
    }

    static func loadPickerItem(_ item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        let decoded = await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                FanDecodedImage(image: downsampledImage(from: data, maxPixelSize: 1600))
            }
        }.value
        return decoded.image
    }

    private struct FanDecodedImage: @unchecked Sendable {
        let image: UIImage?
    }

    nonisolated private static func downsampledImage(from data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    static func saveToPhotos(_ image: UIImage) async throws {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let status: PHAuthorizationStatus
        if current == .notDetermined {
            status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) {
                    continuation.resume(returning: $0)
                }
            }
        } else {
            status = current
        }
        guard status == .authorized || status == .limited else {
            throw ExportError.permissionDenied
        }
        guard let data = image.pngData() else { throw ExportError.pngEncodingFailed }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-fan-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try data.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = "LingdongFan-\(Int(Date.now.timeIntervalSince1970)).png"
            request.addResource(with: .photo, fileURL: fileURL, options: options)
        }
    }

    private static func requestImage(
        asset: PHAsset,
        manager: PHImageManager,
        options: PHImageRequestOptions,
        targetSize: CGSize
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let gate = FanContinuationGate()
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true || info?[PHImageErrorKey] != nil {
                    gate.resumeOnce { continuation.resume(returning: nil) }
                    return
                }
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if !degraded {
                    gate.resumeOnce { continuation.resume(returning: image?.fanNormalized()) }
                }
            }
        }
    }
}

private final class FanContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func resumeOnce(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        action()
    }
}

private struct FanAnalyzedPhoto {
    let index: Int
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
}

private enum FanPhotoMatcher {
    nonisolated static func chooseSix(from images: [UIImage]) async -> FanSelectionResult {
        await Task.detached(priority: .userInitiated) {
            let context = CIContext(options: [.workingColorSpace: NSNull()])
            let analyzed = images.enumerated().compactMap { index, image in
                analyze(image: image, index: index, context: context)
            }
            context.clearCaches()
            guard analyzed.count >= 6 else {
                return FanSelectionResult(
                    indices: [],
                    title: "本次样本中没有足够的同色系照片，请再次遍历。".appLocalized
                )
            }

            let families = Dictionary(grouping: analyzed, by: colorFamily)
                .values
                .filter { $0.count >= 6 }
            guard let family = families.randomElement() else {
                return FanSelectionResult(
                    indices: [],
                    title: "本次样本中没有足够的同色系照片，请再次遍历。".appLocalized
                )
            }

            let coherent = tightestSix(in: family)
            return FanSelectionResult(
                indices: coherent.map(\.index),
                title: "同色系光影 · 六帧成境".appLocalized
            )
        }.value
    }

    private nonisolated static func analyze(
        image: UIImage,
        index: Int,
        context: CIContext
    ) -> FanAnalyzedPhoto? {
        let color = dominantColor(in: image, context: context)
        return FanAnalyzedPhoto(
            index: index,
            hue: color.hue,
            saturation: color.saturation,
            brightness: color.brightness,
        )
    }

    private nonisolated static func colorFamily(_ photo: FanAnalyzedPhoto) -> Int {
        if photo.saturation < 0.16 {
            return 100 + min(2, max(0, Int(photo.brightness * 3)))
        }
        let centeredHue = (photo.hue + 1 / 24).truncatingRemainder(dividingBy: 1)
        return min(11, max(0, Int(centeredHue * 12)))
    }

    private nonisolated static func tightestSix(in photos: [FanAnalyzedPhoto]) -> [FanAnalyzedPhoto] {
        guard photos.count > 6 else { return Array(photos.prefix(6)) }
        var best: (score: CGFloat, values: [FanAnalyzedPhoto])?
        for pivot in photos {
            let nearest = photos.sorted {
                colorDistance($0, pivot) < colorDistance($1, pivot)
            }.prefix(6)
            let values = Array(nearest)
            let score = values.reduce(CGFloat.zero) { $0 + colorDistance($1, pivot) }
            if best == nil || score < best!.score { best = (score, values) }
        }
        return best?.values ?? Array(photos.prefix(6))
    }

    private nonisolated static func colorDistance(_ lhs: FanAnalyzedPhoto, _ rhs: FanAnalyzedPhoto) -> CGFloat {
        if lhs.saturation < 0.16, rhs.saturation < 0.16 {
            return abs(lhs.brightness - rhs.brightness)
        }
        let hueDelta = abs(lhs.hue - rhs.hue)
        let circularHue = min(hueDelta, 1 - hueDelta)
        return circularHue * 2.2
            + abs(lhs.saturation - rhs.saturation) * 0.45
            + abs(lhs.brightness - rhs.brightness) * 0.35
    }

    private nonisolated static func dominantColor(
        in image: UIImage,
        context: CIContext
    ) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        guard let input = CIImage(image: image) else { return (0, 0, 0.5) }
        let extent = input.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: extent),
        ])
        guard let output = filter?.outputImage else { return (0, 0, 0.5) }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        let color = UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        return (hue, saturation, brightness)
    }
}

private extension UIImage {
    func removingWhiteBackgroundForFan() -> UIImage? {
        guard let input = CIImage(image: self) else { return nil }
        let dimension = 32
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    let r = Float(red) / Float(dimension - 1)
                    let g = Float(green) / Float(dimension - 1)
                    let b = Float(blue) / Float(dimension - 1)
                    let white = min(r, min(g, b))
                    let alpha = 1 - white
                    if alpha < 0.018 {
                        cube.append(contentsOf: [0, 0, 0, 0])
                    } else {
                        cube.append((r - white) / alpha)
                        cube.append((g - white) / alpha)
                        cube.append((b - white) / alpha)
                        cube.append(alpha)
                    }
                }
            }
        }
        let data = cube.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let filter = CIFilter(name: "CIColorCube", parameters: [
            "inputCubeDimension": dimension,
            "inputCubeData": data,
            kCIInputImageKey: input,
        ]), let output = filter.outputImage,
              let cgImage = CIContext(options: nil).createCGImage(output, from: input.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    func fanNormalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

#Preview {
    FanGalleryFeatureView()
}
