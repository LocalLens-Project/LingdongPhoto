// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum ArtworkExportQuality: String, CaseIterable, Identifiable {
    case highDefinition
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highDefinition: "高清"
        case .original: "原图级"
        }
    }

    var detail: String {
        switch self {
        case .highDefinition: "画布宽度最高 2400 px，适合日常保存与分享"
        case .original: "按静态原图像素生成，画布最长边最高 8192 px"
        }
    }
}

struct ColorRelationshipFeatureView: View {
    let onOpenModeSelection: () -> Void
    var showsModeSelectionButton = true
    var showsAmbientBackground = true
    var onPaletteChange: (([PaletteColor]) -> Void)? = nil
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("comparisonExportShowsPhotoLabels") private var comparisonExportShowsPhotoLabels = true
    @AppStorage("colorRelationshipExportQuality") private var exportQuality: ArtworkExportQuality = .highDefinition
    @AppStorage("emptyCanvasTheme") private var emptyCanvasThemeRaw = EmptyCanvasTheme.sky.rawValue
    @State private var photos: [RelationshipPhoto] = []
    @State private var relationship: ColorRelationship?
    @State private var lens: RelationshipLens = .resonance
    @State private var pickerSelections: [PhotoPickerSelection] = []
    @State private var pickerPurpose: PickerPurpose = .both
    @State private var pickerPresented = false
    @State private var settingsPresented = false
    @State private var exportOptionsPresented = false
    @State private var isLoading = false
    @State private var saveState: SaveState = .idle
    @State private var shareImage: UIImage?
    @State private var sharePresented = false
    @State private var toast: String?
    @State private var toastVisible = false
    @State private var toastTask: Task<Void, Never>?
    @State private var leftSamplingRect: CGRect?
    @State private var rightSamplingRect: CGRect?
    @State private var samplingSide: RelationshipPhotoSide = .left
    @State private var samplingSidePickerPresented = false
    @State private var colorSamplerPresented = false

    private enum PickerPurpose {
        case both
        case replace(RelationshipPhotoSide)
    }

    private enum SaveState {
        case idle
        case saving
        case success
    }

    private enum ArtworkExportKind: Equatable {
        case comparison
        case full
    }

    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if showsAmbientBackground {
                    PrototypeAmbientBackground(colors: ambientPalette)
                        .allowsHitTesting(false)
                }
                if photos.count == 2, let relationship {
                    editorView(size: proxy.size, relationship: relationship)
                } else {
                    introView
                }

                if let toast {
                    Text(LocalizedStringKey(toast))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .foregroundStyle(.primary)
                        .prototypeGlass(in: Capsule(), variant: .clear)
                        .opacity(toastVisible ? 1 : 0)
                        .scaleEffect(toastVisible ? 1 : 0.88)
                        .offset(y: toastVisible ? 0 : -8)
                }

                if isLoading {
                    VStack(spacing: 11) {
                        ProgressView().tint(.white)
                        Text("正在寻找两张照片的共同色…")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                    .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .statusBarHidden(!usesWideLayout)

        .onChange(of: ambientPalette.map { [$0.red, $0.green, $0.blue, $0.weight] }, initial: true) { _, _ in
            onPaletteChange?(ambientPalette)
        }
        .sheet(isPresented: $pickerPresented, onDismiss: loadPickerSelections) {
            PrivacyPreservingPhotoPicker(
                isPresented: $pickerPresented,
                selectionLimit: pickerLimit,
                colorScheme: systemColorScheme,
                assetRepresentationMode: .compatible,
                usesOrderedSelection: true
            ) { selections in
                pickerSelections = selections
            }
            .environment(\.colorScheme, systemColorScheme)
            .ignoresSafeArea()
        }
        .confirmationDialog(
            "选择局部取色照片",
            isPresented: $samplingSidePickerPresented,
            titleVisibility: .visible
        ) {
            Button("照片 01") { openColorSampler(for: .left) }
            Button("照片 02") { openColorSampler(for: .right) }
            if leftSamplingRect != nil || rightSamplingRect != nil {
                Button("恢复两张照片整图取色") {
                    leftSamplingRect = nil
                    rightSamplingRect = nil
                    analyzeCurrentPair()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("分别选择照片 01 或照片 02 中参与色彩关系分析的区域。")
        }
        .sheet(isPresented: $colorSamplerPresented) {
            if photos.count == 2 {
                let index = samplingSide == .left ? 0 : 1
                MotionCardColorSamplerView(
                    image: photos[index].image,
                    initialSelection: samplingSide == .left ? leftSamplingRect : rightSamplingRect,
                    headerStyle: .sampledGradient,
                    instruction: "拖动选框选择取色范围，拖动四角可调整大小。此范围只影响当前照片参与色彩关系分析的颜色。",
                    onApply: { selection, _ in
                        setSamplingRect(selection, for: samplingSide)
                        analyzeCurrentPair()
                        colorSamplerPresented = false
                    },
                    onReset: {
                        setSamplingRect(nil, for: samplingSide)
                        analyzeCurrentPair()
                        colorSamplerPresented = false
                    }
                )
                .environment(\.colorScheme, systemColorScheme)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(nil)
            }
        }
        .sheet(isPresented: $settingsPresented) {
            if let relationship, photos.count == 2 {
                RelationshipSettingsSheet(
                    lens: $lens,
                    relationship: relationship,
                    onReplaceLeft: {
                        settingsPresented = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(320))
                            openPicker(for: .replace(.left))
                        }
                    },
                    onReplaceRight: {
                        settingsPresented = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(320))
                            openPicker(for: .replace(.right))
                        }
                    },
                    onSwap: {
                        swapPhotos()
                        settingsPresented = false
                    },
                    onShare: {
                        settingsPresented = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(320))
                            await prepareShare()
                        }
                    },
                    onDismiss: { settingsPresented = false }
                )
                .environment(\.colorScheme, systemColorScheme)
                .presentationDetents([.fraction(0.86)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(nil)
                .presentationBackground { readableSheetBackground }
            } else {
                ColorRelationshipWelcomeSheet(
                    onChoosePhotos: {
                        settingsPresented = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(280))
                            openPicker(for: .both)
                        }
                    },
                    onDismiss: { settingsPresented = false }
                )
                .environment(\.colorScheme, systemColorScheme)
                .presentationDetents([.height(410)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(nil)
                .presentationBackground { readableSheetBackground }
            }
        }
        .sheet(isPresented: $exportOptionsPresented) {
            ExportOptionsSheet(
                includesLabels: $comparisonExportShowsPhotoLabels,
                quality: $exportQuality,
                onComparison: {
                    let quality = exportQuality
                    exportOptionsPresented = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(240))
                        await saveArtwork(kind: .comparison, quality: quality)
                    }
                },
                onFull: {
                    let quality = exportQuality
                    exportOptionsPresented = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(240))
                        await saveArtwork(kind: .full, quality: quality)
                    }
                },
                onDismiss: { exportOptionsPresented = false }
            )
            .presentationDetents([.height(485)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(nil)
            .presentationBackground { readableSheetBackground }
        }
        .sheet(isPresented: $sharePresented, onDismiss: { shareImage = nil }) {
            if let shareImage {
                ActivityView(items: [shareImage])
                    .presentationDetents([.medium, .large])
            }
        }
        .onDisappear {


            if showsModeSelectionButton {
                StaticRelationshipPhotoImporter.removeTemporarySources(for: photos)
            }
        }
    }


    private var readableSheetBackground: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .opacity(systemColorScheme == .dark ? 0.94 : 0.97)
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }

    private var ambientPalette: [PaletteColor] {
        if let relationship {
            return relationship.bridge
        }

        let theme = EmptyCanvasTheme(rawValue: emptyCanvasThemeRaw) ?? .sky
        return theme.palette.map {
            PaletteColor(red: $0.red, green: $0.green, blue: $0.blue, weight: 1)
        }
    }

    private var pickerLimit: Int {
        switch pickerPurpose {
        case .both: 2
        case .replace: 1
        }
    }

    private var introView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("灵动照片")
                    .opacity(showsModeSelectionButton ? 1 : 0)
                    .accessibilityHidden(!showsModeSelectionButton)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)

                Spacer()

                if showsModeSelectionButton {
                    PrototypeCircleButton(symbol: "square.grid.2x2", action: onOpenModeSelection)
                        .foregroundStyle(.white.opacity(0.92))
                        .accessibilityLabel("选择创作模式")
                }

                PrototypeCircleButton(symbol: "gearshape") {
                    settingsPresented = true
                }
                .foregroundStyle(.white.opacity(0.92))
                .accessibilityLabel("色彩关系设置")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer()

            PrototypeModeGlyph()
                .padding(.bottom, 48)

            Text("色彩关系")
                .font(.custom("Songti SC", size: 24).weight(.medium))
                .foregroundStyle(.white.opacity(0.94))

            Text("选择两张照片\n看看色彩如何在它们之间相遇")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.36))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
                .padding(.top, 19)

            Button {
                openPicker(for: .both)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .light))
                    .frame(width: 112, height: 112)
                    .contentShape(Circle())
            }
            .buttonStyle(PrototypePressButtonStyle())
            .foregroundStyle(.white.opacity(0.92))
            .prototypeGlass(in: Circle(), interactive: true, variant: .clear)
            .padding(.top, 31)

            Spacer()
            Spacer()
        }
        .safeAreaPadding(.top)
    }

    private func editorView(size: CGSize, relationship: ColorRelationship) -> some View {
        let availableWidth = size.width - 32
        let canvasRatio = ColorRelationshipCanvas.preferredAspectRatio(
            left: photos[0].image,
            right: photos[1].image
        )
        let availableHeight = size.width >= 700 && size.height >= 700
            ? max(1, size.height - 244) : max(320, size.height - 204)
        let canvasWidth = min(availableWidth, availableHeight * canvasRatio)
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("灵动照片")
                    .opacity(showsModeSelectionButton ? 1 : 0)
                    .accessibilityHidden(!showsModeSelectionButton)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)

                Spacer()

                if showsModeSelectionButton {
                    PrototypeCircleButton(symbol: "square.grid.2x2", action: onOpenModeSelection)
                        .accessibilityLabel("选择创作模式")
                }

                PrototypeCircleButton(symbol: "plus") {
                    openPicker(for: .both)
                }
                .accessibilityLabel("重新选择两张照片")

                PrototypeCircleButton(
                    symbol: saveState == .success ? "checkmark" : "arrow.down",
                    isBusy: saveState == .saving
                ) {
                    exportOptionsPresented = true
                }
                .accessibilityLabel("选择作品保存方式")

                PrototypeCircleButton(symbol: "gearshape") {
                    settingsPresented = true
                }
                .accessibilityLabel("色彩关系设置")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            ColorRelationshipCanvas(
                leftPhoto: photos[0],
                rightPhoto: photos[1],
                relationship: relationship,
                lens: lens
            )
            .frame(width: canvasWidth)
            .padding(.top, 20)
            .offset(y: 8)

            Button {
                settingsPresented = true
            } label: {
                Label(
                    String(
                        format: "观察方式：%@".appLocalized,
                        lens.rawValue.appLocalized
                    ),
                    systemImage: lens.symbol
                )
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(PrototypePressButtonStyle())
            .foregroundStyle(.primary.opacity(0.82))
            .prototypeGlass(in: Capsule(), interactive: true, variant: .clear)
            .frame(width: canvasWidth)
            .padding(.top, 12)

            Button {
                samplingSidePickerPresented = true
            } label: {
                Label(
                    (leftSamplingRect == nil && rightSamplingRect == nil
                        ? "局部取色"
                        : "调整局部取色").appLocalized,
                    systemImage: "viewfinder"
                )
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
            }
            .buttonStyle(PrototypePressButtonStyle())
            .foregroundStyle(.primary.opacity(0.82))
            .prototypeGlass(in: Capsule(), interactive: true, variant: .clear)
            .frame(width: canvasWidth)
            .padding(.top, 10)
            .accessibilityHint("分别选择两张照片中参与色彩关系分析的区域")

            Spacer(minLength: 18)
        }
        .safeAreaPadding(.top)
    }

    private func openPicker(for purpose: PickerPurpose) {
        pickerSelections = []
        pickerPurpose = purpose
        pickerPresented = true
    }

    private func openColorSampler(for side: RelationshipPhotoSide) {
        samplingSide = side
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            colorSamplerPresented = true
        }
    }

    private func setSamplingRect(_ selection: CGRect?, for side: RelationshipPhotoSide) {
        switch side {
        case .left: leftSamplingRect = selection
        case .right: rightSamplingRect = selection
        }
    }

    private func loadPickerSelections() {
        guard !pickerSelections.isEmpty else { return }
        let selections = pickerSelections
        let purpose = pickerPurpose
        pickerSelections = []
        Task { await load(selections: selections, for: purpose) }
    }

    private func swapPhotos() {
        guard photos.count == 2 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            photos.swapAt(0, 1)
            let previousLeftSelection = leftSamplingRect
            leftSamplingRect = rightSamplingRect
            rightSamplingRect = previousLeftSelection
            analyzeCurrentPair()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func load(selections: [PhotoPickerSelection], for purpose: PickerPurpose) async {
        isLoading = true
        defer { isLoading = false }

        var loaded: [RelationshipPhoto] = []
        for (index, selection) in selections.enumerated() {
            do {
                let imported = try await StaticRelationshipPhotoImporter.load(selection)
                loaded.append(RelationshipPhoto(
                    image: imported.image,
                    title: "照片 \(index + 1)",
                    detail: metadataDetail(from: imported.captureDate),
                    sourceImageURL: imported.sourceURL,
                    originalPixelSize: imported.pixelSize
                ))
            } catch {
                showToast("有一张照片无法读取")
            }
        }

        switch purpose {
        case .both:
            guard loaded.count == 2 else {
                StaticRelationshipPhotoImporter.removeTemporarySources(for: loaded)
                showToast("请选择两张照片")
                return
            }
            StaticRelationshipPhotoImporter.removeTemporarySources(for: photos)
            photos = loaded
            leftSamplingRect = nil
            rightSamplingRect = nil
        case .replace(let side):
            guard let photo = loaded.first, photos.count == 2 else {
                StaticRelationshipPhotoImporter.removeTemporarySources(for: loaded)
                return
            }
            switch side {
            case .left:
                StaticRelationshipPhotoImporter.removeTemporarySources(for: [photos[0]])
                photos[0] = photo
                leftSamplingRect = nil
            case .right:
                StaticRelationshipPhotoImporter.removeTemporarySources(for: [photos[1]])
                photos[1] = photo
                rightSamplingRect = nil
            }
        }
        analyzeCurrentPair()
    }

    private func analyzeCurrentPair() {
        guard photos.count == 2 else { return }
        let leftImage = leftSamplingRect.map {
            MotionCardColorSamplerView.croppedImage(from: photos[0].image, selection: $0)
        } ?? photos[0].image
        let rightImage = rightSamplingRect.map {
            MotionCardColorSamplerView.croppedImage(from: photos[1].image, selection: $0)
        } ?? photos[1].image
        relationship = ColorRelationshipAnalyzer.analyze(left: leftImage, right: rightImage)
    }

    private func metadataDetail(from date: Date?) -> String {
        guard let date else { return "来自照片图库" }
        let output = DateFormatter()
        output.locale = Locale(identifier: "zh_CN")
        output.dateFormat = "yyyy.MM.dd · HH:mm"
        return output.string(from: date)
    }

    @MainActor
    private func renderedArtwork(
        kind: ArtworkExportKind = .full,
        comparisonShowsLabels: Bool? = nil,
        canvasWidth: CGFloat = 900,
        renderPhotos: [RelationshipPhoto]? = nil
    ) -> UIImage? {
        guard photos.count == 2, let relationship else { return nil }
        let sourcePhotos = renderPhotos ?? photos
        guard sourcePhotos.count == 2 else { return nil }
        let ratio = kind == .comparison
            ? ColorRelationshipCanvas.preferredComparisonAspectRatio(
                left: sourcePhotos[0].image,
                right: sourcePhotos[1].image
            )
            : ColorRelationshipCanvas.preferredAspectRatio(
                left: sourcePhotos[0].image,
                right: sourcePhotos[1].image
            )
        let renderer = ImageRenderer(content: ColorRelationshipCanvas(
            leftPhoto: sourcePhotos[0],
            rightPhoto: sourcePhotos[1],
            relationship: relationship,
            lens: lens,
            isExporting: true,
            comparisonOnly: kind == .comparison,
            showsPhotoLabels: kind == .full
                || (comparisonShowsLabels ?? comparisonExportShowsPhotoLabels)
        ).frame(width: canvasWidth, height: canvasWidth / ratio))
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func exportCanvasWidth(
        kind: ArtworkExportKind,
        quality: ArtworkExportQuality
    ) -> CGFloat {
        let ratio = kind == .comparison
            ? ColorRelationshipCanvas.preferredComparisonAspectRatio(
                left: photos[0].image,
                right: photos[1].image
            )
            : ColorRelationshipCanvas.preferredAspectRatio(
                left: photos[0].image,
                right: photos[1].image
            )
        let requestedWidth: CGFloat
        let maximumLongEdge: CGFloat
        switch quality {
        case .highDefinition:
            requestedWidth = 2_400
            maximumLongEdge = 4_096
        case .original:
            requestedWidth = ColorRelationshipCanvas.nativeExportCanvasWidth(
                left: photos[0],
                right: photos[1],
                comparisonOnly: kind == .comparison
            )
            maximumLongEdge = 8_192
        }
        let maximumWidth = ratio >= 1 ? maximumLongEdge : maximumLongEdge * ratio
        return max(1, floor(min(requestedWidth, maximumWidth)))
    }

    private func sourcePhotosForExport(
        kind: ArtworkExportKind,
        quality: ArtworkExportQuality,
        canvasWidth: CGFloat
    ) async -> [RelationshipPhoto]? {
        guard quality == .original else { return photos }
        let required = ColorRelationshipCanvas.requiredSourceMaximumDimensions(
            canvasWidth: canvasWidth,
            left: photos[0],
            right: photos[1],
            comparisonOnly: kind == .comparison
        )
        let dimensions = [required.left, required.right]
        let basePhotos = photos
        // Decoding two camera originals from disk is pure ImageIO work; keep it
        // off the main actor so the export sheet stays responsive.
        return await Task.detached(priority: .userInitiated) {
            var result = basePhotos
            for index in result.indices {
                guard let url = result[index].sourceImageURL,
                      FileManager.default.fileExists(atPath: url.path),
                      let sourceImage = StaticRelationshipPhotoImporter.exportImage(
                        from: url,
                        maximumDimension: dimensions[index]
                      ) else {
                    return nil
                }
                result[index].image = sourceImage
            }
            return result
        }.value
    }

    @MainActor
    private func renderedJPEGData(
        kind: ArtworkExportKind,
        quality: ArtworkExportQuality
    ) async -> Data? {
        let width = exportCanvasWidth(kind: kind, quality: quality)
        guard let renderPhotos = await sourcePhotosForExport(
            kind: kind,
            quality: quality,
            canvasWidth: width
        ),
        let image = renderedArtwork(
            kind: kind,
            canvasWidth: width,
            renderPhotos: renderPhotos
        ) else { return nil }
        // Encoding an up-to-8K canvas takes seconds on older devices; the
        // renderer itself must stay on the main actor, the JPEG encode must not.
        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                image.jpegData(compressionQuality: 0.95)
            }
        }.value
    }

    private func prepareShare() async {
        let width = exportCanvasWidth(kind: .full, quality: .highDefinition)
        guard let image = renderedArtwork(kind: .full, canvasWidth: width) else {
            showToast("作品还没有准备好")
            return
        }
        shareImage = image
        sharePresented = true
    }

    private func saveArtwork(
        kind: ArtworkExportKind,
        quality: ArtworkExportQuality
    ) async {
        guard saveState == .idle else { return }
        saveState = .saving
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveState = .idle
            showToast("请允许添加照片后再保存")
            return
        }
        guard let data = await renderedJPEGData(kind: kind, quality: quality) else {
            saveState = .idle
            showToast(quality == .original ? "无法读取静态原图，请重新选择照片" : "作品生成失败")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = UTType.jpeg.identifier
                options.originalFilename = "LingdongColorRelationship-\(UUID().uuidString).jpg"
                request.addResource(with: .photo, data: data, options: options)
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                saveState = .success
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let savedMessage: String
            switch (quality, kind) {
            case (.original, .comparison): savedMessage = "原图级对比图已保存到照片"
            case (.original, _): savedMessage = "原图级完整分析已保存到照片"
            case (_, .comparison): savedMessage = "高清对比图已保存到照片"
            case (_, _): savedMessage = "高清完整分析已保存到照片"
            }
            showToast(savedMessage)
            try? await Task.sleep(for: .seconds(1.25))
            withAnimation(.easeInOut(duration: 0.24)) { saveState = .idle }
        } catch {
            saveState = .idle
            showToast("保存失败，请稍后再试")
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message.appLocalized
        toastVisible = false
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            toastVisible = true
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.75))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.42)) {
                toastVisible = false
            }
            try? await Task.sleep(for: .milliseconds(460))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}

/// The color-relationship workflow deliberately treats every selection as a
/// still image. In particular, it never asks an item provider for PHLivePhoto
/// or its paired movie. The still is also downsampled before UIKit decodes it,
/// keeping two large camera originals from producing a memory-pressure spike.
private enum StaticRelationshipPhotoImporter: Sendable {
    struct Result {
        let image: UIImage
        let sourceURL: URL
        let pixelSize: CGSize
        let captureDate: Date?
    }

    enum ImportError: Error {
        case unavailable
        case unreadable
    }

    private static let maximumPixelDimension = 2_400
    private static let sourceDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("color-relationship-static-sources", isDirectory: true)

    static func load(_ selection: PhotoPickerSelection) async throws -> Result {
        try prepareSourceDirectory()
        cleanupStaleSources()

        let sourceURL: URL
        if let sharedItem = selection.sharedItem {
            sourceURL = try temporarySourceURL(fileExtension: "jpg")
            try sharedItem.imageData.write(to: sourceURL, options: .atomic)
        } else {
            guard let provider = selection.itemProvider,
                  let typeIdentifier = staticImageTypeIdentifier(from: provider) else {
                throw ImportError.unavailable
            }
            sourceURL = try await copyStaticRepresentation(
                from: provider,
                typeIdentifier: typeIdentifier
            )
        }

        guard let source = CGImageSourceCreateWithURL(
            sourceURL as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            try? FileManager.default.removeItem(at: sourceURL)
            throw ImportError.unreadable
        }
        guard let image = decodedImage(source: source, maximumDimension: maximumPixelDimension),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            try? FileManager.default.removeItem(at: sourceURL)
            throw ImportError.unreadable
        }

        return Result(
            image: image,
            sourceURL: sourceURL,
            pixelSize: orientedPixelSize(from: properties),
            captureDate: captureDate(from: properties)
        )
    }

    // Pure ImageIO downsampling: safe to run off the main actor.
    nonisolated static func exportImage(from url: URL, maximumDimension: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        return decodedImage(source: source, maximumDimension: maximumDimension)
    }

    static func removeTemporarySources(for photos: [RelationshipPhoto]) {
        for url in photos.compactMap(\.sourceImageURL)
        where url.deletingLastPathComponent().standardizedFileURL == sourceDirectory.standardizedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func staticImageTypeIdentifier(from provider: NSItemProvider) -> String? {
        let candidates = provider.registeredTypeIdentifiers.filter { identifier in
            guard !identifier.localizedCaseInsensitiveContains("live-photo"),
                  let type = UTType(identifier) else { return false }
            return type.conforms(to: .image)
        }
        return candidates.first(where: { $0 != UTType.image.identifier }) ?? candidates.first
    }

    private static func copyStaticRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> URL {
        let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "jpg"
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { sourceURL, error in
                do {
                    guard let sourceURL else {
                        if let error { throw error }
                        throw ImportError.unavailable
                    }
                    let destination = try temporarySourceURL(fileExtension: fileExtension)
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func decodedImage(
        source: CGImageSource,
        maximumDimension: Int
    ) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maximumDimension),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: thumbnail, scale: 1, orientation: .up)
    }

    private static func orientedPixelSize(from properties: [CFString: Any]) -> CGSize {
        var width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        var height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if (5...8).contains(orientation) {
            swap(&width, &height)
        }
        return CGSize(width: width, height: height)
    }

    private static func captureDate(from properties: [CFString: Any]) -> Date? {
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let rawDate = exif[kCGImagePropertyExifDateTimeOriginal] as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: rawDate)
    }

    private static func prepareSourceDirectory() throws {
        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func temporarySourceURL(fileExtension: String) throws -> URL {
        try prepareSourceDirectory()
        let cleanedExtension = fileExtension
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return sourceDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(cleanedExtension.isEmpty ? "jpg" : cleanedExtension)
    }

    private static func cleanupStaleSources() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let expiration = Date.now.addingTimeInterval(-24 * 60 * 60)
        for url in urls {
            let modified = try? url.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
            if (modified ?? .distantPast) < expiration {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

private struct ExportOptionsSheet: View {
    @Binding var includesLabels: Bool
    @Binding var quality: ArtworkExportQuality
    let onComparison: () -> Void
    let onFull: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("保存作品")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("选择这次需要的内容")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(PrototypePressButtonStyle())
                .prototypeGlass(in: Circle(), interactive: true, variant: .clear)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("导出尺寸")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Picker("导出尺寸", selection: $quality) {
                    ForEach(ArtworkExportQuality.allCases) { item in
                        Text(LocalizedStringKey(item.title)).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Text(LocalizedStringKey(quality.detail))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            exportButton(
                title: "保存对比图",
                detail: "仅包含两张照片与液态玻璃色带",
                symbol: "photo.stack",
                action: onComparison
            )

            VStack(alignment: .leading, spacing: 7) {
                Toggle(isOn: $includesLabels) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示 01 / 02")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("仅影响对比图")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)

                Text("液态玻璃色带会收在图片边界内，避免分享到其他平台时被裁切。")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)

            exportButton(
                title: "保存完整分析",
                detail: "包含关系文案与三个色彩指标",
                symbol: "doc.text.image",
                action: onFull
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private func exportButton(
        title: String,
        detail: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(.primary.opacity(0.07), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(LocalizedStringKey(detail))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(height: 68)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ColorRelationshipWelcomeSheet: View {
    let onChoosePhotos: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("色彩关系")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("两张照片，一段可见的色彩联系")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(PrototypePressButtonStyle())
                .prototypeGlass(in: Circle(), interactive: true, variant: .clear)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("共鸣：寻找两张照片里互相认出的颜色", systemImage: RelationshipLens.resonance.symbol)
                Label("对照：观察差异最大的三组配色", systemImage: RelationshipLens.contrast.symbol)
                Label("过渡：生成从图 1 走向图 2 的连续色阶", systemImage: RelationshipLens.bridge.symbol)
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))

            Text("颜色提取、关系文案与作品渲染均在设备本机完成。Live Photo 在此功能中只读取系统提供的静态照片。液态玻璃色带中，每组左侧颜色来自图 1，右侧颜色来自图 2。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onChoosePhotos) {
                Label("选择两张照片", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(PrototypePressButtonStyle())
            .foregroundStyle(.primary)
            .prototypeGlass(in: Capsule(), interactive: true, variant: .clear)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 22)
    }
}

private struct RelationshipSettingsSheet: View {
    @Binding var lens: RelationshipLens
    let relationship: ColorRelationship
    let onReplaceLeft: () -> Void
    let onReplaceRight: () -> Void
    let onSwap: () -> Void
    let onShare: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("色彩关系")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("调整作品呈现，不改变原始照片")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(PrototypePressButtonStyle())
                    .prototypeGlass(in: Circle(), interactive: true, variant: .clear)
                }

                HStack(spacing: 14) {
                    HStack(spacing: -8) {
                        Circle()
                            .fill((relationship.leftPalette.first ?? relationship.signatureColor).color)
                            .frame(width: 36, height: 36)
                        Circle()
                            .fill((relationship.rightPalette.first ?? relationship.signatureColor).color)
                            .frame(width: 36, height: 36)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("颜色方向")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("液态玻璃色带中，左边颜色来自图 1，右边颜色来自图 2。")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("观察方式")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    ForEach(RelationshipLens.allCases) { item in
                        Button {
                            withAnimation(.snappy) { lens = item }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(LocalizedStringKey(item.rawValue))
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Text(LocalizedStringKey(item.caption))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if lens == item {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(16)
                            .background(.primary.opacity(lens == item ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.primary.opacity(lens == item ? 0.16 : 0.05), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("照片")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    HStack(spacing: 10) {
                        toolButton("替换 01", symbol: "photo.badge.plus", action: onReplaceLeft)
                        toolButton("交换", symbol: "arrow.left.arrow.right", action: onSwap)
                        toolButton("替换 02", symbol: "photo.badge.plus", action: onReplaceRight)
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    Text("关系依据")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    HStack(spacing: 0) {
                        sheetMetric("色彩亲近", relationship.affinity)
                        sheetMetric("明暗距离", relationship.lightDifference)
                        sheetMetric("冷暖距离", relationship.temperatureDifference)
                    }
                    Text("数值仅描述两组 OKLab 色彩之间的距离，不代表照片好坏。")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(17)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button(action: onShare) {
                    Label("分享作品", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(PrototypePressButtonStyle())
                .foregroundStyle(.primary)
                .prototypeGlass(in: Capsule(), interactive: true, variant: .clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func toolButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                Text(LocalizedStringKey(title)).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func sheetMetric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(String(format: "%02d", value))
                .font(.system(size: 19, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ColorRelationshipFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        ColorRelationshipFeatureView(onOpenModeSelection: {})
    }
}
