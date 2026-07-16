// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Photos
import PhotosUI
import SwiftUI
import UIKit

private enum SaveVisualState {
    case idle
    case saving
    case success
}

private enum CanvasDragRole {
    case image
    case palette
    case bubble
    case font
    case textSize
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("didAcknowledgeFreeNotice") private var didAcknowledgeFreeNotice = false
    @AppStorage("supportsLivePhotos") private var supportsLivePhotos = true
    @AppStorage("useLiteraryColorNames") private var useLiteraryColorNames = false
    @AppStorage("preservePaletteBackground") private var preservePaletteBackground = true
    @AppStorage("showMoodCopy") private var showMoodCopy = false
    @AppStorage("paletteLayout") private var paletteLayoutRaw = PaletteLayoutMode.floating.rawValue
    @AppStorage("applyLiquidGlassOnExport") private var applyLiquidGlassOnExport = true
    @AppStorage("showHexValues") private var showHexValues = true
    @AppStorage("showDeviceInfo") private var showDeviceInfo = true
    @AppStorage("showBubbles") private var showBubbles = true
    @AppStorage("gentleBackground") private var gentleBackground = true

    @State private var mode: CreationMode = .motionCard
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isPickerPresented = false
    @State private var selectedPhotos: [SelectedPhoto] = []
    @State private var images: [UIImage] = []
    @State private var palette = RGBColor.fallback
    @State private var palettePercentages = [Double](repeating: 0, count: 6)
    @State private var ratio: ArtworkRatio = .threeFour

    @State private var isLoading = false
    @State private var isEditorVisible = false
    @State private var canvasRevealed = false
    @State private var paletteRevealStage = 0
    @State private var generationProgress: CGFloat = 0
    @State private var canSave = false
    @State private var saveState: SaveVisualState = .idle
    @State private var settingsPresented = false
    @State private var modeChangedInSettings = false
    @State private var toastMessage: String?
    @State private var errorTitle = "无法保存"
    @State private var saveErrorMessage = ""
    @State private var saveErrorPresented = false
    @State private var editCopyPresented = false
    @State private var shouldAppendSelection = false
    @State private var importStatus = ""

    @State private var imageScale: CGFloat = 1
    @State private var storedScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var storedOffset: CGSize = .zero
    @State private var paletteOffset: CGFloat = 0
    @State private var storedPaletteOffset: CGFloat = 0
    @State private var bubbleScale: CGFloat = 1
    @State private var storedBubbleScale: CGFloat = 1
    @State private var textScale: CGFloat = 1
    @State private var fontStyle: ArtworkFontStyle = .rounded
    @State private var artworkCopy = ArtworkCopy()
    @State private var copyVariant = 0
    @State private var copyWasEdited = false
    @State private var activeDragRole: CanvasDragRole?

    @State private var revealTask: Task<Void, Never>?
    @State private var toastTask: Task<Void, Never>?

    private var pickerLimit: Int {
        if mode == .journal, shouldAppendSelection {
            return max(1, 5 - selectedPhotos.count)
        }
        return mode == .journal ? 5 : 1
    }
    private var controlsAreDimmed: Bool { saveState == .saving }
    private var paletteLayout: PaletteLayoutMode {
        PaletteLayoutMode(rawValue: paletteLayoutRaw) ?? .floating
    }
    private var primaryMetadata: PhotoMetadata { selectedPhotos.first?.metadata ?? .empty }
    private var combinedSemantic: PhotoSemantic {
        PhotoSemantic.combined(selectedPhotos.map(\.semantic))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AmbientBackground(palette: isEditorVisible ? palette : RGBColor.intro)

                if isEditorVisible {
                    editorView(in: proxy.size)
                        .transition(.opacity)
                } else {
                    introView
                        .transition(.opacity)
                }

                if let toastMessage {
                    toast(text: toastMessage)
                }

                ShakeDetector { resetComposition() }
                    .frame(width: 0, height: 0)

                if !didAcknowledgeFreeNotice {
                    FreeNoticeOverlay {
                        withAnimation(.snappy) {
                            didAcknowledgeFreeNotice = true
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .photosPicker(
            isPresented: $isPickerPresented,
            selection: $pickerItems,
            maxSelectionCount: pickerLimit,
            matching: .any(of: [.images, .livePhotos])
        )
        .onChange(of: isPickerPresented) { _, isPresented in
            guard !isPresented, !pickerItems.isEmpty else { return }
            Task { await loadSelectedPhotos() }
        }
        .onChange(of: mode) { _, newMode in
            ratio = newMode.defaultRatio
            if settingsPresented {
                modeChangedInSettings = true
            }
        }
        .onChange(of: showMoodCopy) { _, _ in
            guard let photo = selectedPhotos.first else { return }
            copyVariant = 0
            copyWasEdited = false
            artworkCopy = defaultCopy(
                metadata: photo.metadata,
                palette: palette,
                semantic: combinedSemantic
            )
        }
        .sheet(isPresented: $settingsPresented, onDismiss: finishSettings) {
            SettingsView(
                mode: $mode,
                ratio: $ratio,
                showHexValues: $showHexValues,
                showDeviceInfo: $showDeviceInfo,
                showBubbles: $showBubbles,
                gentleBackground: $gentleBackground
            )
            .presentationDetents([.fraction(0.94)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $editCopyPresented) {
            ArtworkCopyEditor(
                mode: mode,
                semantic: combinedSemantic,
                copy: $artworkCopy,
                copyWasEdited: $copyWasEdited,
                onRegenerate: regenerateCopy
            )
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(34)
        }
        .alert(errorTitle, isPresented: $saveErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .task {
            PhotoAssetLoader.cleanupStaleTemporaryResources()
#if DEBUG
            await loadDebugPreviewIfNeeded()
#endif
        }
    }

    private var introView: some View {
        TabView(selection: $mode) {
            ForEach(CreationMode.allCases) { item in
                modeIntro(item)
                    .tag(item)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
    }

    private func modeIntro(_ item: CreationMode) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ModeGlyph(mode: item)
                .id(item)
                .padding(.bottom, 55)

            HStack(spacing: 7) {
                Text(item.title)
                    .font(.custom("Songti SC", size: 24).weight(.medium))
                if item == .journal {
                    Circle()
                        .fill(.pink)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
            }
            .foregroundStyle(.white.opacity(0.94))

            Text(item.introSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.32))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 300)
                .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(CreationMode.allCases) { dotMode in
                    Circle()
                        .fill(dotMode == mode ? .white : .white.opacity(0.25))
                        .frame(width: dotMode == mode ? 6 : 5, height: dotMode == mode ? 6 : 5)
                }
            }
            .padding(.top, 19)

            Button(action: { openPicker() }) {
                ZStack {
                    if isLoading && item == mode {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.white.opacity(0.88))
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .light))
                    }
                }
                .frame(width: 112, height: 112)
                .contentShape(Circle())
            }
            .buttonStyle(LiquidPressButtonStyle())
            .foregroundStyle(.white.opacity(0.92))
            .liquidGlass(in: Circle(), interactive: true, variant: .clear)
            .disabled(isLoading)
            .padding(.top, 31)
            .accessibilityLabel("为\(item.title)选择照片")

            if isLoading && item == mode && !importStatus.isEmpty {
                Text(importStatus)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            Spacer()
            Spacer()
        }
        .offset(y: 35)
    }

    private func editorView(in size: CGSize) -> some View {
        let ratioValue = editorRatio(in: size)
        let canvasWidth = mode == .spectrumWallpaper
            ? min(size.width - 96, UIScreen.main.bounds.width * 0.686)
            : size.width - 32
        let canvasHeight = canvasWidth / ratioValue

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("灵动照片")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                if selectedPhotos.contains(where: \.isLivePhoto) {
                    let hasDynamicResource = selectedPhotos.contains { $0.pairedVideoURL != nil }
                    Image(systemName: hasDynamicResource ? "livephoto" : "livephoto.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hasDynamicResource ? Color.primary.opacity(0.72) : Color.orange)
                        .accessibilityLabel(
                            hasDynamicResource
                                ? "Live Photo 动态导出已启用"
                                : "Live Photo 动态资源不可用，将保存静态作品"
                        )
                }

                Spacer()

                LiquidCircleButton(
                    symbol: "plus",
                    isEnabled: !controlsAreDimmed && (mode != .journal || selectedPhotos.count < 5)
                ) {
                    openPicker(append: mode == .journal)
                }

                if mode == .journal && selectedPhotos.count > 1 {
                    LiquidCircleButton(
                        symbol: "minus",
                        isEnabled: !controlsAreDimmed,
                        action: removeLastJournalPhoto
                    )
                    .transition(.scale.combined(with: .opacity))
                }

                LiquidCircleButton(
                    symbol: saveState == .success ? "checkmark" : "arrow.down",
                    isEnabled: canSave,
                    isBusy: saveState == .saving,
                    action: saveArtwork
                )
                .opacity(canSave || saveState != .idle ? 1 : 0)

                LiquidCircleButton(
                    symbol: "gearshape",
                    isEnabled: !controlsAreDimmed
                ) {
                    settingsPresented = true
                }
            }
            .animation(.easeInOut(duration: 0.22), value: controlsAreDimmed)
            .animation(.easeInOut(duration: 0.20), value: canSave)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            ArtworkCanvas(
                mode: mode,
                images: images,
                palette: palette,
                palettePercentages: palettePercentages,
                ratio: ratio,
                showHexValues: showHexValues,
                showDeviceInfo: showDeviceInfo,
                showBubbles: showBubbles,
                gentleBackground: gentleBackground,
                imageScale: imageScale,
                imageOffset: imageOffset,
                metadata: primaryMetadata,
                copy: artworkCopy,
                fontStyle: fontStyle,
                textScale: textScale,
                bubbleScale: bubbleScale,
                paletteOffset: paletteOffset,
                paletteLayout: paletteLayout,
                useLiteraryColorNames: useLiteraryColorNames,
                preservePaletteBackground: preservePaletteBackground,
                applyLiquidGlassOnExport: applyLiquidGlassOnExport,
                paletteRevealStage: paletteRevealStage,
                generationProgress: generationProgress
            )
            .frame(width: canvasWidth, height: canvasHeight)
            .scaleEffect(canvasRevealed ? 1 : 0.78)
            .opacity(canvasRevealed ? 1 : 0.18)
            .shadow(color: .black.opacity(canvasRevealed ? 0.12 : 0), radius: 22, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .gesture(compositionGesture(canvasSize: CGSize(width: canvasWidth, height: canvasHeight)))
            .simultaneousGesture(
                SpatialTapGesture(count: 1)
                    .onEnded { value in
                        handleCanvasTap(at: value.location, canvasSize: CGSize(width: canvasWidth, height: canvasHeight))
                    }
            )
            .onTapGesture(count: 2) { resetComposition() }
            .accessibilityLabel("\(mode.title)预览，可拖拽或双指缩放")
            .accessibilityAction(named: "编辑作品文字") {
                if mode == .motionCard || mode == .bubbleStamp || mode == .journal {
                    editCopyPresented = true
                }
            }
            .accessibilityAction(named: "恢复默认构图") { resetComposition() }
            .padding(.top, 20)

            Spacer(minLength: 18)
        }
        .safeAreaPadding(.top)
    }

    private func compositionGesture(canvasSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if activeDragRole == nil {
                        activeDragRole = dragRole(
                            at: value.startLocation,
                            translation: value.translation,
                            canvasSize: canvasSize
                        )
                    }
                    switch activeDragRole ?? .image {
                    case .image:
                        imageOffset = CGSize(
                            width: storedOffset.width + value.translation.width,
                            height: storedOffset.height + value.translation.height
                        )
                    case .palette:
                        paletteOffset = min(max(storedPaletteOffset + value.translation.height, -canvasSize.height * 0.44), canvasSize.height * 0.44)
                    case .bubble:
                        bubbleScale = min(max(storedBubbleScale - value.translation.height / 150, 0.45), 2.1)
                    case .font, .textSize:
                        break
                    }
                }
                .onEnded { value in
                    switch activeDragRole ?? .image {
                    case .image:
                        storedOffset = imageOffset
                    case .palette:
                        storedPaletteOffset = paletteOffset
                    case .bubble:
                        storedBubbleScale = bubbleScale
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    case .font:
                        if abs(value.translation.width) > 28 {
                            fontStyle = fontStyle.advanced(by: value.translation.width > 0 ? 1 : -1)
                            UISelectionFeedbackGenerator().selectionChanged()
                            showToast("字体：\(fontStyle.rawValue)", duration: 1.2)
                        }
                    case .textSize:
                        if abs(value.translation.width) > 20 {
                            textScale = min(max(textScale + (value.translation.width > 0 ? 0.12 : -0.12), 0.65), 1.75)
                            UISelectionFeedbackGenerator().selectionChanged()
                            showToast("文字大小：\(Int((textScale * 100).rounded()))%", duration: 1.2)
                        }
                    }
                    activeDragRole = nil
                },
            MagnifyGesture()
                .onChanged { value in
                    imageScale = min(max(storedScale * value.magnification, 1), 4)
                }
                .onEnded { _ in storedScale = imageScale }
        )
    }

    private func dragRole(at point: CGPoint, translation: CGSize, canvasSize: CGSize) -> CanvasDragRole {
        if mode == .colorPalette {
            let isOnPanel = paletteLayout == .bottom
                ? point.y > canvasSize.height * 0.55
                : point.y < canvasSize.height * 0.46
            if isOnPanel { return .palette }
        }

        if mode == .bubbleStamp,
           point.x < canvasSize.width * 0.34,
           point.y > canvasSize.width * 0.91,
           abs(translation.height) > abs(translation.width) {
            return .bubble
        }

        guard abs(translation.width) > abs(translation.height) else { return .image }
        switch mode {
        case .motionCard where point.y < canvasSize.height * 0.43:
            return point.y < canvasSize.height * 0.22 ? .font : .textSize
        case .bubbleStamp where point.y > canvasSize.width * 0.91:
            return point.y < canvasSize.height * 0.82 ? .font : .textSize
        case .journal where point.y < canvasSize.height * 0.28 || point.y > canvasSize.height * 0.68:
            return point.y < canvasSize.height * 0.28 ? .font : .textSize
        default:
            return .image
        }
    }

    private func handleCanvasTap(at point: CGPoint, canvasSize: CGSize) {
        let shouldEdit: Bool
        switch mode {
        case .motionCard:
            shouldEdit = point.y < canvasSize.height * 0.43
        case .bubbleStamp:
            shouldEdit = point.y > canvasSize.width * 0.91
        case .journal:
            shouldEdit = point.y < canvasSize.height * 0.28 || point.y > canvasSize.height * 0.68
        default:
            shouldEdit = false
        }
        if shouldEdit { editCopyPresented = true }
    }

    private func toast(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 18)
                .frame(height: 43)
                .liquidGlass(in: Capsule())
                .padding(.bottom, 30)
        }
        .transition(.scale(scale: 0.72).combined(with: .opacity))
        .allowsHitTesting(false)
        .zIndex(60)
    }

    private func openPicker(append: Bool = false) {
        guard !isLoading, saveState == .idle else { return }
        shouldAppendSelection = append && mode == .journal && !selectedPhotos.isEmpty
        pickerItems = []
        isPickerPresented = true
    }

    private func removeLastJournalPhoto() {
        guard mode == .journal, selectedPhotos.count > 1 else { return }
        let removed = selectedPhotos.last.map { [$0] } ?? []
        withAnimation(.snappy) {
            selectedPhotos.removeLast()
            images.removeLast()
        }
        PhotoAssetLoader.removeTemporaryResources(for: removed)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func loadSelectedPhotos() async {
        guard !isLoading else { return }

        let appending = shouldAppendSelection && mode == .journal && !selectedPhotos.isEmpty
        withAnimation(.easeOut(duration: 0.18)) {
            if !appending { isEditorVisible = false }
            isLoading = true
            canSave = false
            canvasRevealed = false
            paletteRevealStage = 0
            generationProgress = 0
            importStatus = "正在读取照片与拍摄信息…"
        }

        var imported: [SelectedPhoto] = []
        for (index, item) in pickerItems.prefix(pickerLimit).enumerated() {
            importStatus = "正在识别第 \(index + 1) 张，共 \(min(pickerItems.count, pickerLimit)) 张的画面内容…"
            if let photo = try? await PhotoAssetLoader.load(item, includeLiveResource: supportsLivePhotos) {
                imported.append(photo)
            }
        }

        guard !imported.isEmpty else {
            isLoading = false
            importStatus = ""
            shouldAppendSelection = false
            if appending { isEditorVisible = true; canSave = true; canvasRevealed = true }
            presentSaveError(
                "未能读取所选照片，请确认照片已下载到本机后重试。",
                title: "无法读取照片"
            )
            return
        }

        let combined = appending
            ? Array((selectedPhotos + imported).prefix(5))
            : Array(imported.prefix(mode == .journal ? 5 : 1))
        importStatus = "正在分析整张照片的感知色彩…"
        let paletteResult = PaletteExtractor.extract(from: combined[0].image)
        if !appending { PhotoAssetLoader.removeTemporaryResources(for: selectedPhotos) }
        selectedPhotos = combined
        images = combined.map(\.image)
        let semantic = PhotoSemantic.combined(combined.map(\.semantic))
        if !appending {
            copyVariant = 0
            copyWasEdited = false
            artworkCopy = defaultCopy(
                metadata: combined[0].metadata,
                palette: paletteResult.colors,
                semantic: semantic
            )
        } else if !copyWasEdited {
            artworkCopy = defaultCopy(
                metadata: combined[0].metadata,
                palette: paletteResult.colors,
                semantic: semantic
            )
        }
        resetComposition(animated: false)

        withAnimation(.easeInOut(duration: 0.36)) {
            palette = paletteResult.colors
            palettePercentages = paletteResult.percentages
            isLoading = false
            isEditorVisible = true
            importStatus = ""
        }
        shouldAppendSelection = false
        startRevealSequence()
        if supportsLivePhotos,
           combined.contains(where: \.isLivePhoto),
           !combined.contains(where: { $0.pairedVideoURL != nil }) {
            showToast("未取得 Live 动态资源，本次将按静态作品保存", duration: 3.2)
        }
    }

    private func startRevealSequence() {
        revealTask?.cancel()
        paletteRevealStage = 0
        generationProgress = mode == .spectrumWallpaper ? 0 : 1
        canSave = true
        canvasRevealed = false

        if reduceMotion {
            canvasRevealed = true
            paletteRevealStage = 4
            generationProgress = 1
            return
        }

        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(45))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                canvasRevealed = true
            }

            switch mode {
            case .colorPalette:
                for (stage, delay) in [(1, 205), (2, 150), (3, 180), (4, 160)] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                        paletteRevealStage = stage
                    }
                }
            case .spectrumWallpaper:
                try? await Task.sleep(for: .milliseconds(170))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.88)) {
                    generationProgress = 1
                }
                showToast("渐变壁纸已生成", duration: 2.1)

            default:
                paletteRevealStage = 4
            }
        }
    }

    private func editorRatio(in screenSize: CGSize) -> CGFloat {
        if mode == .spectrumWallpaper {
            let bounds = UIScreen.main.bounds
            return min(max(bounds.width / bounds.height, 0.43), 0.50)
        }
        return ratio.value
    }

    private func finishSettings() {
        guard modeChangedInSettings else { return }
        modeChangedInSettings = false
        resetToIntro()
    }

    private func resetToIntro() {
        revealTask?.cancel()
        toastTask?.cancel()
        PhotoAssetLoader.removeTemporaryResources(for: selectedPhotos)
        withAnimation(.easeInOut(duration: 0.35)) {
            selectedPhotos = []
            images = []
            pickerItems = []
            palette = RGBColor.fallback
            palettePercentages = [Double](repeating: 0, count: 6)
            isEditorVisible = false
            isLoading = false
            canSave = false
            canvasRevealed = false
            paletteRevealStage = 0
            generationProgress = 0
            saveState = .idle
            toastMessage = nil
            importStatus = ""
        }
        resetComposition(animated: false)
    }

    private func resetComposition(animated: Bool = true) {
        let update = {
            imageScale = 1
            storedScale = 1
            imageOffset = .zero
            storedOffset = .zero
            paletteOffset = 0
            storedPaletteOffset = 0
            bubbleScale = 1
            storedBubbleScale = 1
            textScale = 1
            fontStyle = .rounded
            activeDragRole = nil
        }
        if animated {
            withAnimation(.snappy, update)
        } else {
            update()
        }
    }

    private func saveArtwork() {
        guard canSave, saveState == .idle else { return }
        withAnimation(.easeOut(duration: 0.16)) { saveState = .saving }
        showToast("正在渲染高清作品…", duration: 30)

        Task {
            guard let image = renderArtwork() else {
                saveState = .idle
                presentSaveError("作品渲染失败，请稍后重试。")
                return
            }

            do {
                let metadata = selectedPhotos.first?.metadata ?? .empty
                let originalData = selectedPhotos.first?.originalData
                let pairedVideoURLs: [Int: URL] = supportsLivePhotos
                    ? Dictionary(uniqueKeysWithValues: selectedPhotos.enumerated().compactMap { index, photo in
                        photo.pairedVideoURL.map { (index, $0) }
                    })
                    : [:]
                if !pairedVideoURLs.isEmpty {
                    showToast("正在生成 Live Photo 动态资源…", duration: 30)
                    try await ArtworkExporter.saveLivePhoto(
                        renderedStill: image,
                        sourceVideoURLs: pairedVideoURLs,
                        metadata: metadata,
                        originalImageData: originalData,
                        renderFrame: { frames in
                            renderArtwork(replacingImages: frames)
                        },
                        progress: { progress in
                            toastMessage = "正在生成 Live Photo… \(Int((progress * 100).rounded()))%"
                        }
                    )
                } else {
                    showToast("正在写入相册并保留拍摄信息…", duration: 30)
                    try await ArtworkExporter.saveStill(
                        image,
                        metadata: metadata,
                        originalImageData: originalData
                    )
                }
                toastTask?.cancel()
                withAnimation(.easeOut(duration: 0.2)) { toastMessage = nil }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    saveState = .success
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(for: .milliseconds(1_250))
                withAnimation(.easeInOut(duration: 0.24)) {
                    saveState = .idle
                }
            } catch {
                saveState = .idle
                presentSaveError(error.localizedDescription)
            }
        }
    }

    private func renderArtwork(replacingImages replacements: [Int: UIImage] = [:]) -> UIImage? {
        let renderWidth: CGFloat = 360
        let outputRatio = mode == .spectrumWallpaper
            ? min(max(UIScreen.main.bounds.width / UIScreen.main.bounds.height, 0.43), 0.50)
            : ratio.value
        let renderHeight = renderWidth / outputRatio
        var renderImages = images
        for (index, frame) in replacements where renderImages.indices.contains(index) {
            renderImages[index] = frame
        }
        let renderer = ImageRenderer(
            content: ArtworkCanvas(
                mode: mode,
                images: renderImages,
                palette: palette,
                palettePercentages: palettePercentages,
                ratio: ratio,
                showHexValues: showHexValues,
                showDeviceInfo: showDeviceInfo,
                showBubbles: showBubbles,
                gentleBackground: gentleBackground,
                imageScale: imageScale,
                imageOffset: imageOffset,
                metadata: primaryMetadata,
                copy: artworkCopy,
                fontStyle: fontStyle,
                textScale: textScale,
                bubbleScale: bubbleScale,
                paletteOffset: paletteOffset,
                paletteLayout: paletteLayout,
                useLiteraryColorNames: useLiteraryColorNames,
                preservePaletteBackground: preservePaletteBackground,
                applyLiquidGlassOnExport: applyLiquidGlassOnExport,
                isExporting: true,
                paletteRevealStage: 4,
                generationProgress: 1
            )
            .frame(width: renderWidth, height: renderHeight)
        )
        renderer.scale = 3
        return renderer.uiImage
    }

    private func showToast(_ message: String, duration: Double) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { toastMessage = nil }
        }
    }

    private func presentSaveError(_ message: String, title: String = "无法保存") {
        toastTask?.cancel()
        toastMessage = nil
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        errorTitle = title
        saveErrorMessage = message
        saveErrorPresented = true
    }

    private func defaultCopy(
        metadata: PhotoMetadata,
        palette: [RGBColor],
        semantic: PhotoSemantic
    ) -> ArtworkCopy {
        PhotoCopywriter.makeCopy(
            semantic: semantic,
            metadata: metadata,
            palette: palette,
            preferMoodCopy: showMoodCopy,
            variant: copyVariant
        )
    }

    private func regenerateCopy() {
        guard !selectedPhotos.isEmpty else { return }
        copyVariant += 1
        artworkCopy = defaultCopy(
            metadata: primaryMetadata,
            palette: palette,
            semantic: combinedSemantic
        )
        copyWasEdited = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

#if DEBUG
    private func loadDebugPreviewIfNeeded() async {
        guard ProcessInfo.processInfo.arguments.contains("--demo"), images.isEmpty else { return }
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--palette") { mode = .colorPalette }
        if arguments.contains("--journal") { mode = .journal }
        if arguments.contains("--stamp") { mode = .bubbleStamp }
        if arguments.contains("--wallpaper") { mode = .spectrumWallpaper }
        ratio = mode.defaultRatio
        let fixtureData = arguments.contains("--fixture")
            ? Bundle.main.url(forResource: "Fixture", withExtension: "jpeg").flatMap { try? Data(contentsOf: $0) }
            : nil
        let fallbackImage = Self.debugPreviewImage()
        let data = fixtureData ?? fallbackImage.jpegData(compressionQuality: 0.94) ?? Data()
        let image = UIImage(data: data) ?? fallbackImage
        let fallbackMetadata = PhotoMetadata(
            make: nil,
            model: UIDevice.current.model,
            lensModel: nil,
            aperture: nil,
            exposureTime: nil,
            iso: nil,
            focalLength: nil,
            captureDate: .now,
            latitude: nil,
            longitude: nil,
            altitude: nil,
            placeName: "示例地点"
        )
        let debugMetadata = fixtureData.map(PhotoMetadata.read(from:)) ?? fallbackMetadata
        let semantic = fixtureData == nil ? PhotoSemantic.generic : await PhotoContentAnalyzer.analyze(data)
        print("VISION_RESULT: \(semantic.summary) | \(semantic.classificationLabels.joined(separator: ", "))")
        selectedPhotos = [SelectedPhoto(
            image: image,
            originalData: data,
            metadata: debugMetadata,
            semantic: semantic,
            assetLocalIdentifier: nil,
            pairedVideoURL: nil,
            isLivePhoto: false
        )]
        images = [image]
        let result = PaletteExtractor.extract(from: image)
        palette = result.colors
        palettePercentages = result.percentages
        artworkCopy = defaultCopy(metadata: debugMetadata, palette: result.colors, semantic: semantic)
        isEditorVisible = true
        canvasRevealed = true
        paletteRevealStage = 4
        generationProgress = 1
        canSave = true
        didAcknowledgeFreeNotice = true
        if arguments.contains("--animate-later") {
            Task {
                try? await Task.sleep(for: .seconds(3))
                startRevealSequence()
            }
        } else if arguments.contains("--animate") {
            startRevealSequence()
        }
        if arguments.contains("--settings") { settingsPresented = true }
    }

    private static func debugPreviewImage() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            let colors = [
                UIColor(red: 0.87, green: 0.95, blue: 0.58, alpha: 1).cgColor,
                UIColor(red: 0.28, green: 0.55, blue: 0.28, alpha: 1).cgColor
            ] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            )!
            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            for row in 0..<5 {
                for column in 0..<4 {
                    let rect = CGRect(
                        x: 70 + CGFloat(column) * 205,
                        y: 130 + CGFloat(row) * 190,
                        width: 150,
                        height: 150
                    )
                    let tone = CGFloat((row + column) % 4) * 0.05
                    UIColor(red: 0.20 + tone, green: 0.52 + tone, blue: 0.18, alpha: 0.94).setFill()
                    context.fillEllipse(in: rect)
                    UIColor.white.withAlphaComponent(0.16).setStroke()
                    context.setLineWidth(8)
                    context.strokeEllipse(in: rect.insetBy(dx: 18, dy: 18))
                }
            }
        }
    }
#endif
}

private struct ModeGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mode: CreationMode
    @State private var assembled = false

    var body: some View {
        ZStack {
            Circle()
                .fill(mode.accent.opacity(0.72))
                .frame(width: 66, height: 66)
                .offset(y: assembled ? -16 : 0)
            Circle()
                .fill(.white.opacity(0.30))
                .frame(width: 66, height: 66)
            Circle()
                .fill(.black.opacity(0.46))
                .frame(width: 66, height: 66)
                .offset(y: assembled ? 16 : 0)
        }
        .scaleEffect(assembled ? 1 : 1.7)
        .offset(x: assembled ? 0 : 65, y: assembled ? 0 : 55)
        .opacity(assembled ? 1 : 0.25)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 7)
        .onAppear {
            if reduceMotion {
                assembled = true
            } else {
                withAnimation(.spring(response: 0.95, dampingFraction: 0.78)) {
                    assembled = true
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private struct ArtworkCopyEditor: View {
    @Environment(\.dismiss) private var dismiss
    let mode: CreationMode
    let semantic: PhotoSemantic
    @Binding var copy: ArtworkCopy
    @Binding var copyWasEdited: Bool
    let onRegenerate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("系统识别") {
                    Label(semantic.summary, systemImage: "viewfinder")
                        .font(.subheadline.weight(.semibold))
                    if !semantic.recognizedText.isEmpty {
                        Text("画面文字：\(semantic.recognizedText.prefix(2).joined(separator: " · "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Button(action: onRegenerate) {
                        Label("换一组智能文案与 Emoji", systemImage: "sparkles")
                    }
                    Text("由 Apple Vision 在本机识别画面，不会上传照片。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if mode == .motionCard || mode == .bubbleStamp {
                    Section("标题") {
                        TextField("输入标题", text: tracked(\.title), axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
                if mode == .bubbleStamp {
                    Section("英文副标题") {
                        TextField("输入副标题", text: tracked(\.subtitle), axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
                if mode == .journal {
                    Section("Emoji") {
                        TextField("输入 Emoji", text: tracked(\.emojis), axis: .vertical)
                            .lineLimit(1...4)
                    }
                    Section("手帐文案") {
                        TextField("输入文案", text: tracked(\.journalCaption), axis: .vertical)
                            .lineLimit(1...4)
                    }
                }

                Section {
                    Text("所有文字只用于本次作品，不会上传到网络。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("编辑作品文字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func tracked(_ keyPath: WritableKeyPath<ArtworkCopy, String>) -> Binding<String> {
        Binding(
            get: { copy[keyPath: keyPath] },
            set: { newValue in
                copy[keyPath: keyPath] = newValue
                copyWasEdited = true
            }
        )
    }
}

private struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller(onShake: onShake)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.onShake = onShake
        uiViewController.becomeFirstResponder()
    }

    final class Controller: UIViewController {
        var onShake: () -> Void

        init(onShake: @escaping () -> Void) {
            self.onShake = onShake
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onShake()
        }
    }
}
