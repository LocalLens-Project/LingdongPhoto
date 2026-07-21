// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

private enum PhotoSelectionOperation: Equatable {
    case replaceAll
    case append
    case replace(index: Int)
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didAcknowledgeFreeNotice") private var didAcknowledgeFreeNotice = false
    @AppStorage("supportsLivePhotos") private var supportsLivePhotos = true
    @AppStorage("useLiteraryColorNames") private var useLiteraryColorNames = false
    @AppStorage("preservePaletteBackground") private var preservePaletteBackground = true
    @AppStorage("showMoodCopy") private var showMoodCopy = false
    @AppStorage("paletteLayout") private var paletteLayoutRaw = PaletteLayoutMode.floating.rawValue
    @AppStorage("applyLiquidGlassOnExport") private var applyLiquidGlassOnExport = true
    @AppStorage("showHexValues") private var showHexValues = true
    @AppStorage("showPalettePercentages") private var showPalettePercentages = true
    @AppStorage("showDeviceInfo") private var showDeviceInfo = true
    @AppStorage("showBubbles") private var showBubbles = true
    @AppStorage("gentleBackground") private var gentleBackground = true
    @AppStorage("privacyMosaicStrength") private var privacyMosaicStrength = 0.62
    @AppStorage("showAppTitle") private var showAppTitle = true
    @AppStorage("artworkTemplateStyle") private var templateStyleRaw = ArtworkTemplateStyle.classic.rawValue
    @AppStorage("journalLayout") private var journalLayoutRaw = JournalLayoutMode.automatic.rawValue
    @AppStorage("exportFormat") private var exportFormatRaw = ArtworkExportFormat.jpeg.rawValue
    @AppStorage("exportResolution") private var exportResolutionRaw = ArtworkExportResolution.standard.rawValue
    @AppStorage("exportMetadataPolicy") private var exportMetadataPolicyRaw = ArtworkMetadataPolicy.removeLocation.rawValue
    @AppStorage("exportDestination") private var exportDestinationRaw = ArtworkExportDestination.photoLibrary.rawValue
    // This key is intentionally independent of the build number. Do not rename it
    // for future releases, otherwise users would see the one-time hint again.
    @AppStorage("didShowLivePhotoPlaybackHint") private var didShowLivePhotoPlaybackHint = false
    @AppStorage("didShowLivePhotoPlaybackHintBuild1060") private var didShowLivePhotoPlaybackHintBuild1060 = false

    @State private var mode: CreationMode = .motionCard
    @State private var pickerSelections: [PhotoPickerSelection] = []
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
    @State private var photoSelectionOperation: PhotoSelectionOperation = .replaceAll
    @State private var importStatus = ""
    @State private var isImportingSharedPhoto = false
    @State private var exportCenterPresented = false
    @State private var sharedExportFile: ExportedArtworkFile?
    @State private var documentExportFile: ExportedArtworkFile?

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
    @State private var journalTransforms: [JournalPhotoTransform] = []
    @State private var selectedJournalIndex: Int?
    @State private var storedJournalTransform = JournalPhotoTransform()

    @State private var privacyMasks: [PrivacyMask] = []
    @State private var privacyStrokes: [PrivacyStroke] = []
    @State private var privacyHistory: [PrivacyEditSnapshot] = []
    @State private var privacyBrushMode: PrivacyBrushMode = .paint
    @State private var isPrivacyPainting = false
    @State private var isPrivacyDetecting = false
    @State private var privacyPixelatedImage: UIImage?
    @State private var activePrivacyStrokeID: UUID?
    @State private var privacyGestureHasSnapshot = false
    @State private var lastPrivacyGesturePoint: CGPoint?
    @State private var privacyPreviewTask: Task<Void, Never>?

    @State private var revealTask: Task<Void, Never>?
    @State private var toastTask: Task<Void, Never>?
    @State private var livePlaybackTask: Task<Void, Never>?
    @State private var livePhotoHintTask: Task<Void, Never>?
    @State private var livePreviewFrames: [Int: UIImage] = [:]
    @State private var isLivePhotoPlaying = false
    @State private var isLivePhotoHintPresented = false

    private var pickerLimit: Int {
        if mode == .journal, photoSelectionOperation == .append {
            return max(1, 5 - selectedPhotos.count)
        }
        if case .replace = photoSelectionOperation { return 1 }
        return mode == .journal ? 5 : 1
    }
    private var controlsAreDimmed: Bool { saveState == .saving }
    private var paletteLayout: PaletteLayoutMode {
        PaletteLayoutMode(rawValue: paletteLayoutRaw) ?? .floating
    }
    private var templateStyle: ArtworkTemplateStyle {
        ArtworkTemplateStyle(rawValue: templateStyleRaw) ?? .classic
    }
    private var journalLayout: JournalLayoutMode {
        JournalLayoutMode(rawValue: journalLayoutRaw) ?? .automatic
    }
    private var exportFormat: ArtworkExportFormat {
        get { ArtworkExportFormat(rawValue: exportFormatRaw) ?? .jpeg }
        nonmutating set { exportFormatRaw = newValue.rawValue }
    }
    private var exportResolution: ArtworkExportResolution {
        get { ArtworkExportResolution(rawValue: exportResolutionRaw) ?? .standard }
        nonmutating set { exportResolutionRaw = newValue.rawValue }
    }
    private var exportMetadataPolicy: ArtworkMetadataPolicy {
        get { ArtworkMetadataPolicy(rawValue: exportMetadataPolicyRaw) ?? .removeLocation }
        nonmutating set { exportMetadataPolicyRaw = newValue.rawValue }
    }
    private var exportDestination: ArtworkExportDestination {
        get { ArtworkExportDestination(rawValue: exportDestinationRaw) ?? .photoLibrary }
        nonmutating set { exportDestinationRaw = newValue.rawValue }
    }
    private var primaryMetadata: PhotoMetadata { selectedPhotos.first?.metadata ?? .empty }
    private var combinedSemantic: PhotoSemantic {
        PhotoSemantic.combined(selectedPhotos.map(\.semantic))
    }
    private var enabledPrivacyMaskCount: Int { privacyMasks.filter(\.isEnabled).count }
    private var disabledPrivacyMaskCount: Int { privacyMasks.count - enabledPrivacyMaskCount }
    private var liveSourceVideoURLs: [Int: URL] {
        Dictionary(uniqueKeysWithValues: selectedPhotos.enumerated().compactMap { index, photo in
            photo.pairedVideoURL.map { (index, $0) }
        })
    }
    private var showsLivePlaybackControl: Bool {
        mode != .privacyMosaic && selectedPhotos.contains(where: \.isLivePhoto)
    }
    private var canPresentLivePhotoHint: Bool {
        isEditorVisible && showsLivePlaybackControl && !liveSourceVideoURLs.isEmpty
    }
    private var hasShownLivePhotoPlaybackHint: Bool {
        didShowLivePhotoPlaybackHint || didShowLivePhotoPlaybackHintBuild1060
    }
    private var livePhotoHintBaseColor: RGBColor {
        palette.first ?? RGBColor.fallback[0]
    }
    private var livePhotoHintTint: Color {
        livePhotoHintBaseColor.adjusted(
            brightness: livePhotoHintBaseColor.relativeLuminance < 0.26 ? 0.16 : -0.04,
            saturation: -0.04
        ).color
    }
    private var livePhotoHintForeground: Color {
        let estimatedBackground = livePhotoHintBaseColor.adjusted(
            brightness: 0.18,
            saturation: 0.08
        )
        let black = RGBColor(red: 0.035, green: 0.035, blue: 0.035)
        let white = RGBColor(red: 0.965, green: 0.965, blue: 0.965)
        return black.contrastRatio(with: estimatedBackground)
            >= white.contrastRatio(with: estimatedBackground)
            ? black.color.opacity(0.84)
            : white.color.opacity(0.96)
    }
    private var displayedImages: [UIImage] {
        var result = images
        for (index, frame) in livePreviewFrames where result.indices.contains(index) {
            result[index] = frame
        }
        return result
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

                ShakeDetector(
                    isEnabled: !editCopyPresented && !settingsPresented && !isPickerPresented
                ) {
                    resetComposition()
                }
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
        // Keep the established editor appearance light without overriding the
        // window's actual system appearance. Selected sheets can then opt back
        // into the user's system setting independently.
        .environment(\.colorScheme, .light)
        .statusBarHidden(true)
        .sheet(isPresented: $isPickerPresented) {
            PrivacyPreservingPhotoPicker(
                isPresented: $isPickerPresented,
                selectionLimit: pickerLimit,
                colorScheme: systemColorScheme
            ) { selections in
                pickerSelections = selections
            }
            .environment(\.colorScheme, systemColorScheme)
            .ignoresSafeArea()
        }
        .onChange(of: isPickerPresented) { _, isPresented in
            guard !isPresented, !pickerSelections.isEmpty else { return }
            Task { await loadSelectedPhotos() }
        }
        .onChange(of: mode) { _, newMode in
            stopLivePhotoPlayback()
            dismissLivePhotoHint()
            ratio = newMode.defaultRatio
            if newMode == .privacyMosaic {
                refreshPrivacyPreview()
            } else {
                finishPrivacyPainting()
            }
            if settingsPresented {
                modeChangedInSettings = true
            }
        }
        .onChange(of: privacyMosaicStrength) { _, _ in
            schedulePrivacyPreviewRefresh()
        }
        .onChange(of: paletteLayoutRaw) { _, _ in
            paletteOffset = 0
            storedPaletteOffset = 0
            activeDragRole = nil
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
                gentleBackground: $gentleBackground,
                templateStyle: Binding(
                    get: { templateStyle },
                    set: { templateStyleRaw = $0.rawValue }
                ),
                journalLayout: Binding(
                    get: { journalLayout },
                    set: { journalLayoutRaw = $0.rawValue }
                )
            )
            .environment(\.colorScheme, systemColorScheme)
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
                .preferredColorScheme(.light)
                .presentationDetents([.large])
                .presentationContentInteraction(.scrolls)
                .presentationCornerRadius(34)
        }
        .sheet(isPresented: $exportCenterPresented) {
            ExportCenterView(
                format: Binding(get: { exportFormat }, set: { exportFormat = $0 }),
                resolution: Binding(get: { exportResolution }, set: { exportResolution = $0 }),
                metadataPolicy: Binding(get: { exportMetadataPolicy }, set: { exportMetadataPolicy = $0 }),
                destination: Binding(get: { exportDestination }, set: { exportDestination = $0 }),
                sourcePixelWidth: images.first?.cgImage.map { CGFloat($0.width) } ?? 1080,
                supportsLiveExport: supportsLivePhotos && mode != .privacyMosaic && !liveSourceVideoURLs.isEmpty,
                onExport: performConfiguredExport
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents([.fraction(0.94)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $sharedExportFile) { item in
            SystemShareSheet(url: item.url)
                .preferredColorScheme(.light)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $documentExportFile) { item in
            FileExportPicker(url: item.url)
                .preferredColorScheme(.light)
        }
        .alert(errorTitle, isPresented: $saveErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .task {
            if didShowLivePhotoPlaybackHintBuild1060 {
                didShowLivePhotoPlaybackHint = true
            }
            PhotoAssetLoader.cleanupStaleTemporaryResources()
            importSharedPhotoIfAvailable()
#if DEBUG
            await loadDebugPreviewIfNeeded()
#endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            importSharedPhotoIfAvailable()
        }
        .task(id: canPresentLivePhotoHint) {
            if canPresentLivePhotoHint {
                presentLivePhotoHintIfNeeded()
            } else {
                dismissLivePhotoHint()
            }
        }
        .onDisappear {
            stopLivePhotoPlayback()
            dismissLivePhotoHint(animated: false)
        }
        .onOpenURL(perform: handleSharedPhotoURL)
    }

    private func handleSharedPhotoURL(_ url: URL) {
        guard url.scheme == SharedPhotoHandoff.urlScheme,
              url.host == "import" else { return }
        let modeValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "mode" })?
            .value
        importSharedPhotoIfAvailable(preferredModeRawValue: modeValue)
    }

    private func importSharedPhotoIfAvailable(
        preferredModeRawValue: String? = nil,
        reportMissing: Bool = false
    ) {
        // App launch can deliver the same handoff through `.task`, scene
        // activation and `onOpenURL` almost simultaneously. Only one callback
        // should consume the App Group inbox and begin an import.
        guard !isImportingSharedPhoto else { return }
        guard let sharedImport = SharedPhotoHandoff.receiveImport() else {
            if reportMissing {
                presentSaveError("共享照片已失效，请从系统照片中重新分享。", title: "无法导入共享照片")
            }
            return
        }
        if let modeValue = preferredModeRawValue ?? sharedImport.modeRawValue,
           let sharedMode = CreationMode(rawValue: modeValue) {
            mode = sharedMode
            ratio = sharedMode.defaultRatio
        }
        var sharedSelections: [PhotoPickerSelection] = []
        for item in sharedImport.items {
            sharedSelections.append(PhotoPickerSelection(sharedItem: item))
        }
        pickerSelections = sharedSelections
        photoSelectionOperation = .replaceAll
        isImportingSharedPhoto = true
        Task {
            await loadSelectedPhotos()
            isImportingSharedPhoto = false
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
        let availableWidth = size.width - 32
        let canvasWidth: CGFloat
        if mode == .spectrumWallpaper {
            canvasWidth = min(size.width - 96, UIScreen.main.bounds.width * 0.686)
        } else if mode == .privacyMosaic {
            canvasWidth = min(availableWidth, max(280, size.height - 340) * ratioValue)
        } else if mode == .journal {
            // Reserve room for the liquid-glass thumbnail editor on compact phones.
            let editorReserve: CGFloat = size.height < 760 ? 285 : 230
            canvasWidth = min(availableWidth, max(280, size.height - editorReserve) * ratioValue)
        } else {
            // Extra-tall ratios must remain fully reachable on compact iPhones.
            canvasWidth = min(availableWidth, max(320, size.height - 130) * ratioValue)
        }
        let canvasHeight = canvasWidth / ratioValue

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("灵动照片")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .opacity(showAppTitle ? 1 : 0)
                    .accessibilityHidden(!showAppTitle)

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
                    dismissLivePhotoHint()
                    settingsPresented = true
                }
            }
            .animation(.easeInOut(duration: 0.22), value: controlsAreDimmed)
            .animation(.easeInOut(duration: 0.20), value: canSave)
            .animation(.easeInOut(duration: 0.18), value: showAppTitle)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if showsLivePlaybackControl {
                HStack(spacing: 8) {
                    LivePhotoPlaybackButton(
                        isAvailable: !liveSourceVideoURLs.isEmpty,
                        isPlaying: isLivePhotoPlaying,
                        action: playLivePhotoOnce
                    )

                    if isLivePhotoHintPresented {
                        LivePhotoPlaybackHint(
                            tint: livePhotoHintTint,
                            foreground: livePhotoHintForeground,
                            action: playLivePhotoOnce
                        )
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.68, anchor: .leading)
                                    .combined(with: .opacity)
                                    .combined(with: .move(edge: .leading)),
                                removal: .scale(scale: 0.76, anchor: .leading)
                                    .combined(with: .opacity)
                            )
                        )
                    }

                    Spacer(minLength: 0)
                }
                .frame(width: canvasWidth)
                .padding(.top, 12)
                .zIndex(20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ArtworkCanvas(
                mode: mode,
                images: displayedImages,
                palette: palette,
                palettePercentages: palettePercentages,
                ratio: ratio,
                showHexValues: showHexValues,
                showPalettePercentages: showPalettePercentages,
                showDeviceInfo: showDeviceInfo,
                showBubbles: showBubbles,
                gentleBackground: gentleBackground,
                imageScale: imageScale,
                imageOffset: imageOffset,
                metadata: primaryMetadata,
                copy: artworkCopy,
                fontStyle: fontStyle,
                templateStyle: templateStyle,
                textScale: textScale,
                bubbleScale: bubbleScale,
                paletteOffset: paletteOffset,
                paletteLayout: paletteLayout,
                useLiteraryColorNames: useLiteraryColorNames,
                preservePaletteBackground: preservePaletteBackground,
                applyLiquidGlassOnExport: applyLiquidGlassOnExport,
                paletteRevealStage: paletteRevealStage,
                generationProgress: generationProgress,
                privacyMasks: privacyMasks,
                privacyStrokes: privacyStrokes,
                privacyPixelatedImage: privacyPixelatedImage,
                journalLayout: journalLayout,
                journalTransforms: journalTransforms,
                selectedJournalIndex: selectedJournalIndex
            )
            .frame(width: canvasWidth, height: canvasHeight)
            .scaleEffect(canvasRevealed ? 1 : 0.78)
            .opacity(canvasRevealed ? 1 : 0.18)
            .shadow(color: .black.opacity(canvasRevealed ? 0.12 : 0), radius: 22, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .gesture(activeCanvasGesture(canvasSize: CGSize(width: canvasWidth, height: canvasHeight)))
            .accessibilityLabel(
                mode == .privacyMosaic && isPrivacyPainting
                    ? "隐私马赛克预览，单指\(privacyBrushMode.rawValue)"
                    : "\(mode.title)预览，可拖拽或双指缩放"
            )
            .accessibilityAction(named: "编辑作品文字") {
                if mode == .motionCard || mode == .bubbleStamp || mode == .journal {
                    editCopyPresented = true
                }
            }
            .accessibilityAction(named: "恢复默认构图") { resetComposition() }
            .padding(.top, showsLivePlaybackControl ? 8 : 20)

            if mode == .privacyMosaic {
                PrivacyMosaicControls(
                    brushMode: $privacyBrushMode,
                    strength: $privacyMosaicStrength,
                    isPainting: isPrivacyPainting,
                    isDetecting: isPrivacyDetecting,
                    canUndo: !privacyHistory.isEmpty,
                    detectedCount: privacyMasks.count,
                    disabledCount: disabledPrivacyMaskCount,
                    hasLivePhoto: selectedPhotos.contains(where: \.isLivePhoto),
                    onTogglePainting: togglePrivacyPainting,
                    onDetect: detectPrivacyContent,
                    onUndo: undoPrivacyEdit
                )
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }

            if mode == .journal {
                JournalEditorControls(
                    images: images,
                    selectedIndex: $selectedJournalIndex,
                    layout: Binding(
                        get: { journalLayout },
                        set: { journalLayoutRaw = $0.rawValue }
                    ),
                    onReplace: { openPicker(replacing: $0) },
                    onDelete: removeJournalPhoto,
                    onMove: moveJournalPhoto,
                    onReset: resetJournalComposition
                )
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }

            Spacer(minLength: mode == .privacyMosaic ? 8 : 18)
        }
        .safeAreaPadding(.top)
    }

    private func activeCanvasGesture(canvasSize: CGSize) -> AnyGesture<Void> {
        if mode == .privacyMosaic && isPrivacyPainting {
            return AnyGesture(privacyPaintGesture(canvasSize: canvasSize).map { _ in () })
        }

        if mode == .privacyMosaic {
            return AnyGesture(compositionGesture(canvasSize: canvasSize).map { _ in () })
        }

        let canvasTapGesture = SpatialTapGesture(count: 2)
            .exclusively(before: SpatialTapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    resetComposition()
                case let .second(tap):
                    handleCanvasTap(at: tap.location, canvasSize: canvasSize)
                }
            }

        return AnyGesture(
            SimultaneousGesture(
                compositionGesture(canvasSize: canvasSize),
                canvasTapGesture
            )
            .map { _ in () }
        )
    }

    private func privacyPaintGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let point = normalizedPrivacyPoint(
                    from: value.location,
                    canvasSize: canvasSize
                ) else { return }

                if !privacyGestureHasSnapshot {
                    pushPrivacySnapshot()
                    privacyGestureHasSnapshot = true
                }

                switch privacyBrushMode {
                case .paint:
                    if activePrivacyStrokeID == nil {
                        let stroke = PrivacyStroke(
                            points: [point],
                            normalizedWidth: privacyBrushWidth
                        )
                        activePrivacyStrokeID = stroke.id
                        privacyStrokes.append(stroke)
                    } else if let id = activePrivacyStrokeID,
                              let index = privacyStrokes.firstIndex(where: { $0.id == id }) {
                        appendInterpolatedPrivacyPoints(point, to: &privacyStrokes[index])
                    }
                case .erase:
                    erasePrivacyStrokes(from: lastPrivacyGesturePoint, to: point)
                }
                lastPrivacyGesturePoint = point
            }
            .onEnded { _ in
                activePrivacyStrokeID = nil
                lastPrivacyGesturePoint = nil
                privacyGestureHasSnapshot = false
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
    }

    private var privacyBrushWidth: CGFloat { 0.085 }
    private var privacyEraserRadius: CGFloat { 0.072 }

    private func appendInterpolatedPrivacyPoints(_ point: CGPoint, to stroke: inout PrivacyStroke) {
        guard let previous = stroke.points.last else {
            stroke.points.append(point)
            return
        }
        let distance = hypot(point.x - previous.x, point.y - previous.y)
        let step = max(0.008, stroke.normalizedWidth * 0.26)
        let segments = max(1, Int(ceil(distance / step)))
        for index in 1...segments {
            let progress = CGFloat(index) / CGFloat(segments)
            stroke.points.append(CGPoint(
                x: previous.x + (point.x - previous.x) * progress,
                y: previous.y + (point.y - previous.y) * progress
            ))
        }
    }

    private func erasePrivacyStrokes(from start: CGPoint?, to end: CGPoint) {
        let start = start ?? end
        let distance = hypot(end.x - start.x, end.y - start.y)
        let segments = max(1, Int(ceil(distance / max(0.01, privacyEraserRadius * 0.45))))
        for index in 0...segments {
            let progress = CGFloat(index) / CGFloat(segments)
            erasePrivacyStrokes(at: CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            ))
        }
    }

    private func erasePrivacyStrokes(at center: CGPoint) {
        var rebuilt: [PrivacyStroke] = []
        for stroke in privacyStrokes {
            var segment: [CGPoint] = []
            var segmentIndex = 0
            func finishSegment() {
                guard !segment.isEmpty else { return }
                rebuilt.append(PrivacyStroke(
                    id: segmentIndex == 0 ? stroke.id : UUID(),
                    points: segment,
                    normalizedWidth: stroke.normalizedWidth
                ))
                segmentIndex += 1
                segment.removeAll(keepingCapacity: true)
            }

            for point in stroke.points {
                let radius = privacyEraserRadius + stroke.normalizedWidth * 0.46
                if hypot(point.x - center.x, point.y - center.y) <= radius {
                    finishSegment()
                } else {
                    segment.append(point)
                }
            }
            finishSegment()
        }
        privacyStrokes = rebuilt
    }

    private func compositionGesture(canvasSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            DragGesture(minimumDistance: mode == .privacyMosaic ? 0 : 10)
                .onChanged { value in
                    if mode == .privacyMosaic,
                       hypot(value.translation.width, value.translation.height) < 8 {
                        return
                    }
                    if activeDragRole == nil {
                        let role = dragRole(
                            at: value.startLocation,
                            translation: value.translation,
                            canvasSize: canvasSize
                        )
                        activeDragRole = role
                        if case .palette = role {
                            let normalizedOffset = PalettePanelGeometry.clampedOffset(
                                paletteOffset,
                                in: canvasSize,
                                layout: paletteLayout
                            )
                            paletteOffset = normalizedOffset
                            storedPaletteOffset = normalizedOffset
                        }
                    }
                    switch activeDragRole ?? .image {
                    case .image:
                        if mode == .journal,
                           let index = selectedJournalIndex,
                           journalTransforms.indices.contains(index),
                           let cellFrame = journalCellFrame(at: index, canvasSize: canvasSize) {
                            let proposed = CGSize(
                                width: storedJournalTransform.normalizedOffset.width + value.translation.width / max(cellFrame.width, 1),
                                height: storedJournalTransform.normalizedOffset.height + value.translation.height / max(cellFrame.height, 1)
                            )
                            let limit = max(0.08, (journalTransforms[index].scale - 1) * 0.52 + 0.08)
                            journalTransforms[index].normalizedOffset = CGSize(
                                width: min(max(proposed.width, -limit), limit),
                                height: min(max(proposed.height, -limit), limit)
                            )
                        } else {
                            let proposedOffset = CGSize(
                                width: storedOffset.width + value.translation.width,
                                height: storedOffset.height + value.translation.height
                            )
                            imageOffset = mode == .privacyMosaic
                                ? clampedPrivacyOffset(proposedOffset, canvasSize: canvasSize, scale: imageScale)
                                : proposedOffset
                        }
                    case .palette:
                        paletteOffset = PalettePanelGeometry.clampedOffset(
                            storedPaletteOffset + value.translation.height,
                            in: canvasSize,
                            layout: paletteLayout
                        )
                    case .bubble:
                        bubbleScale = min(max(storedBubbleScale - value.translation.height / 150, 0.45), 2.1)
                    case .font, .textSize:
                        break
                    }
                }
                .onEnded { value in
                    if mode == .privacyMosaic,
                       hypot(value.translation.width, value.translation.height) < 8 {
                        activeDragRole = nil
                        handleCanvasTap(at: value.location, canvasSize: canvasSize)
                        return
                    }
                    switch activeDragRole ?? .image {
                    case .image:
                        if mode == .journal,
                           let index = selectedJournalIndex,
                           journalTransforms.indices.contains(index) {
                            storedJournalTransform = journalTransforms[index]
                        } else {
                            storedOffset = imageOffset
                        }
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
                    if mode == .journal,
                       let index = selectedJournalIndex,
                       journalTransforms.indices.contains(index) {
                        journalTransforms[index].scale = min(
                            max(storedJournalTransform.scale * value.magnification, 1),
                            4
                        )
                    } else {
                        imageScale = min(max(storedScale * value.magnification, 1), 4)
                        if mode == .privacyMosaic {
                            imageOffset = clampedPrivacyOffset(imageOffset, canvasSize: canvasSize, scale: imageScale)
                        }
                    }
                }
                .onEnded { _ in
                    if mode == .journal,
                       let index = selectedJournalIndex,
                       journalTransforms.indices.contains(index) {
                        storedJournalTransform = journalTransforms[index]
                    } else {
                        storedScale = imageScale
                        if mode == .privacyMosaic { storedOffset = imageOffset }
                    }
                }
        )
    }

    private func clampedPrivacyOffset(_ offset: CGSize, canvasSize: CGSize, scale: CGFloat) -> CGSize {
        let horizontalLimit = max(0, canvasSize.width * (scale - 1) / 2)
        let verticalLimit = max(0, canvasSize.height * (scale - 1) / 2)
        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, -verticalLimit), verticalLimit)
        )
    }

    private func dragRole(at point: CGPoint, translation: CGSize, canvasSize: CGSize) -> CanvasDragRole {
        if mode == .colorPalette,
           PalettePanelGeometry.hitFrame(
               in: canvasSize,
               layout: paletteLayout,
               offset: paletteOffset
           ).contains(point) {
            return .palette
        }

        if mode == .bubbleStamp,
           point.x < canvasSize.width * 0.34,
           point.y > canvasSize.width * 0.91,
           abs(translation.height) > abs(translation.width) {
            return .bubble
        }

        if mode == .journal,
           let index = journalIndex(at: point, canvasSize: canvasSize) {
            if selectedJournalIndex != index {
                selectedJournalIndex = index
                while journalTransforms.count < images.count {
                    journalTransforms.append(JournalPhotoTransform())
                }
                storedJournalTransform = journalTransforms.indices.contains(index)
                    ? journalTransforms[index]
                    : JournalPhotoTransform()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            return .image
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
        if mode == .privacyMosaic {
            guard !isPrivacyPainting,
                  let normalizedPoint = normalizedPrivacyPoint(from: point, canvasSize: canvasSize),
                  let index = privacyMaskIndex(at: normalizedPoint, canvasSize: canvasSize) else { return }
            pushPrivacySnapshot()
            privacyMasks[index].isEnabled.toggle()
            UISelectionFeedbackGenerator().selectionChanged()
            showToast(
                privacyMasks[index].isEnabled
                    ? "已恢复\(privacyMasks[index].kind.title)遮挡"
                    : "已关闭\(privacyMasks[index].kind.title)遮挡，再次点击可恢复",
                duration: 1.8
            )
            return
        }

        if mode == .journal,
           let index = journalIndex(at: point, canvasSize: canvasSize) {
            selectedJournalIndex = index
            while journalTransforms.count < images.count {
                journalTransforms.append(JournalPhotoTransform())
            }
            storedJournalTransform = journalTransforms[index]
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

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

    private func journalIndex(at point: CGPoint, canvasSize: CGSize) -> Int? {
        let container = JournalGridGeometry.containerFrame(in: canvasSize)
        guard container.contains(point) else { return nil }
        let localPoint = CGPoint(x: point.x - container.minX, y: point.y - container.minY)
        return JournalGridGeometry.frames(
            count: images.count,
            in: container.size,
            layout: journalLayout
        ).firstIndex(where: { $0.contains(localPoint) })
    }

    private func journalCellFrame(at index: Int, canvasSize: CGSize) -> CGRect? {
        let container = JournalGridGeometry.containerFrame(in: canvasSize)
        let frames = JournalGridGeometry.frames(
            count: images.count,
            in: container.size,
            layout: journalLayout
        )
        guard frames.indices.contains(index) else { return nil }
        return frames[index].offsetBy(dx: container.minX, dy: container.minY)
    }

    private func normalizedPrivacyPoint(from point: CGPoint, canvasSize: CGSize) -> CGPoint? {
        guard let image = images.first, image.size.width > 0, image.size.height > 0 else { return nil }
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let scale = max(imageScale, 0.001)
        let untransformed = CGPoint(
            x: (point.x - center.x - imageOffset.width) / scale + center.x,
            y: (point.y - center.y - imageOffset.height) / scale + center.y
        )
        let fitted = aspectFitSize(imageSize: image.size, canvasSize: canvasSize)
        let rect = CGRect(
            x: (canvasSize.width - fitted.width) / 2,
            y: (canvasSize.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
        guard rect.contains(untransformed) else { return nil }
        return CGPoint(
            x: min(max((untransformed.x - rect.minX) / rect.width, 0), 1),
            y: min(max((untransformed.y - rect.minY) / rect.height, 0), 1)
        )
    }

    private func privacyMaskIndex(at point: CGPoint, canvasSize: CGSize) -> Int? {
        privacyMasks.indices
            .filter { index in
                var hitRect = privacyMasks[index].normalizedRect
                let minimumWidth = min(0.18, 46 / max(canvasSize.width * imageScale, 1))
                let minimumHeight = min(0.18, 46 / max(canvasSize.height * imageScale, 1))
                hitRect = hitRect.insetBy(
                    dx: -max(0, (minimumWidth - hitRect.width) / 2),
                    dy: -max(0, (minimumHeight - hitRect.height) / 2)
                )
                return hitRect.contains(point)
            }
            .min {
                let lhs = privacyMasks[$0].normalizedRect
                let rhs = privacyMasks[$1].normalizedRect
                return lhs.width * lhs.height < rhs.width * rhs.height
            }
    }

    private func aspectFitSize(imageSize: CGSize, canvasSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return canvasSize }
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
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

    private func togglePrivacyPainting() {
        guard mode == .privacyMosaic else { return }
        if isPrivacyPainting {
            finishPrivacyPainting()
            showToast("已退出隐私遮挡模式，可继续拖动或缩放照片", duration: 2.2)
        } else {
            isPrivacyPainting = true
            privacyBrushMode = .paint
            activeDragRole = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showToast("隐私遮挡模式：单指涂抹，完成后恢复构图手势", duration: 2.6)
        }
    }

    private func finishPrivacyPainting() {
        isPrivacyPainting = false
        activePrivacyStrokeID = nil
        privacyGestureHasSnapshot = false
        lastPrivacyGesturePoint = nil
    }

    private func detectPrivacyContent() {
        guard mode == .privacyMosaic,
              !isPrivacyDetecting,
              let data = selectedPhotos.first?.originalData else { return }
        finishPrivacyPainting()
        isPrivacyDetecting = true
        showToast("正在本机识别人脸、车牌、二维码与敏感文字…", duration: 30)

        Task {
            let detected = await PrivacyContentDetector.detect(data)
            isPrivacyDetecting = false
            guard !detected.isEmpty else {
                showToast("未发现明确的隐私内容，仍可使用手动涂抹", duration: 2.8)
                return
            }
            pushPrivacySnapshot()
            privacyMasks = detected
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(
                "发现 \(detected.count) 处隐私内容，点击马赛克区域可取消",
                duration: 3.6
            )
        }
    }

    private func pushPrivacySnapshot() {
        privacyHistory.append(PrivacyEditSnapshot(masks: privacyMasks, strokes: privacyStrokes))
        if privacyHistory.count > 40 {
            privacyHistory.removeFirst(privacyHistory.count - 40)
        }
    }

    private func undoPrivacyEdit() {
        guard let snapshot = privacyHistory.popLast() else { return }
        activePrivacyStrokeID = nil
        privacyGestureHasSnapshot = false
        lastPrivacyGesturePoint = nil
        privacyMasks = snapshot.masks
        privacyStrokes = snapshot.strokes
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        showToast("已撤销上一步隐私遮挡", duration: 1.5)
    }

    private func resetPrivacyEdits(for image: UIImage?) {
        privacyMasks = []
        privacyStrokes = []
        privacyHistory = []
        privacyBrushMode = .paint
        finishPrivacyPainting()
        privacyPixelatedImage = image.flatMap {
            PrivacyMosaicRenderer.makePixelatedImage(from: $0, strength: privacyMosaicStrength)
        }
    }

    private func refreshPrivacyPreview() {
        guard let image = images.first else {
            privacyPixelatedImage = nil
            return
        }
        privacyPixelatedImage = PrivacyMosaicRenderer.makePixelatedImage(
            from: image,
            strength: privacyMosaicStrength
        )
    }

    private func schedulePrivacyPreviewRefresh() {
        privacyPreviewTask?.cancel()
        privacyPreviewTask = Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            refreshPrivacyPreview()
        }
    }

    private func openPicker(append: Bool = false, replacing index: Int? = nil) {
        guard !isLoading, saveState == .idle else { return }
        stopLivePhotoPlayback()
        dismissLivePhotoHint()
        finishPrivacyPainting()
        if let index, mode == .journal, selectedPhotos.indices.contains(index) {
            photoSelectionOperation = .replace(index: index)
        } else if append && mode == .journal && !selectedPhotos.isEmpty {
            photoSelectionOperation = .append
        } else {
            photoSelectionOperation = .replaceAll
        }
        pickerSelections = []
        isPickerPresented = true
    }

    private func removeLastJournalPhoto() {
        guard !selectedPhotos.isEmpty else { return }
        removeJournalPhoto(at: selectedJournalIndex ?? selectedPhotos.index(before: selectedPhotos.endIndex))
    }

    private func removeJournalPhoto(at index: Int) {
        guard mode == .journal,
              selectedPhotos.count > 1,
              selectedPhotos.indices.contains(index) else { return }
        stopLivePhotoPlayback()
        dismissLivePhotoHint()
        let removed = [selectedPhotos[index]]
        withAnimation(.snappy) {
            selectedPhotos.remove(at: index)
            images.remove(at: index)
            if journalTransforms.indices.contains(index) { journalTransforms.remove(at: index) }
            selectedJournalIndex = min(index, selectedPhotos.count - 1)
        }
        PhotoAssetLoader.removeTemporaryResources(for: removed)
        refreshCombinedPalette()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func moveJournalPhoto(from source: Int, to destination: Int) {
        guard source != destination,
              selectedPhotos.indices.contains(source),
              selectedPhotos.indices.contains(destination) else { return }
        let photo = selectedPhotos.remove(at: source)
        let image = images.remove(at: source)
        let transform = journalTransforms.indices.contains(source)
            ? journalTransforms.remove(at: source)
            : JournalPhotoTransform()
        selectedPhotos.insert(photo, at: destination)
        images.insert(image, at: destination)
        journalTransforms.insert(transform, at: destination)
        selectedJournalIndex = destination
        refreshCombinedPalette()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func resetJournalComposition(at index: Int) {
        guard journalTransforms.indices.contains(index) else { return }
        withAnimation(.snappy) { journalTransforms[index] = JournalPhotoTransform() }
        storedJournalTransform = JournalPhotoTransform()
    }

    private func refreshCombinedPalette() {
        guard !images.isEmpty else { return }
        let result = combinedPaletteResult(from: images)
        withAnimation(.easeInOut(duration: 0.24)) {
            palette = result.colors
            palettePercentages = result.percentages
        }
    }

    private func combinedPaletteResult(from sourceImages: [UIImage]) -> PaletteResult {
        guard let first = sourceImages.first else {
            return PaletteResult(colors: RGBColor.fallback, percentages: [Double](repeating: 100.0 / 6.0, count: 6))
        }
        guard sourceImages.count > 1 else { return PaletteExtractor.extract(from: first) }

        let canvasSize = CGSize(width: 480, height: 480)
        let columns = sourceImages.count <= 2 ? sourceImages.count : 2
        let rows = Int(ceil(Double(sourceImages.count) / Double(columns)))
        let cellSize = CGSize(
            width: canvasSize.width / CGFloat(columns),
            height: canvasSize.height / CGFloat(rows)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let montage = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            for (index, image) in sourceImages.prefix(5).enumerated() {
                let cell = CGRect(
                    x: CGFloat(index % columns) * cellSize.width,
                    y: CGFloat(index / columns) * cellSize.height,
                    width: cellSize.width,
                    height: cellSize.height
                )
                let scale = max(cell.width / image.size.width, cell.height / image.size.height)
                let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let drawRect = CGRect(
                    x: cell.midX - drawSize.width / 2,
                    y: cell.midY - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
                context.cgContext.saveGState()
                context.cgContext.clip(to: cell)
                image.draw(in: drawRect)
                context.cgContext.restoreGState()
            }
        }
        return PaletteExtractor.extract(from: montage)
    }

    private func loadSelectedPhotos() async {
        guard !isLoading else { return }
        stopLivePhotoPlayback()
        dismissLivePhotoHint()

        let operation = photoSelectionOperation
        let incremental = mode == .journal && operation != .replaceAll && !selectedPhotos.isEmpty
        withAnimation(.easeOut(duration: 0.18)) {
            if !incremental { isEditorVisible = false }
            isLoading = true
            canSave = false
            canvasRevealed = false
            paletteRevealStage = 0
            generationProgress = 0
            importStatus = "正在读取照片与拍摄信息…"
        }

        var imported: [SelectedPhoto] = []
        var firstImportError: Error?
        for (index, selection) in pickerSelections.prefix(pickerLimit).enumerated() {
            importStatus = "正在识别第 \(index + 1) 张，共 \(min(pickerSelections.count, pickerLimit)) 张的画面内容…"
            // Always retain the paired resource while this photo is selected.
            // The Live export setting can then be changed without reselecting it.
            do {
                let photo = try await PhotoAssetLoader.load(selection, includeLiveResource: true)
                imported.append(photo)
            } catch {
                firstImportError = firstImportError ?? error
            }
        }

        guard !imported.isEmpty else {
            isLoading = false
            importStatus = ""
            photoSelectionOperation = .replaceAll
            if incremental { isEditorVisible = true; canSave = true; canvasRevealed = true }
            presentSaveError(
                firstImportError?.localizedDescription
                    ?? "未能读取所选照片，请确认照片已下载到本机后重试。",
                title: "无法读取照片"
            )
            return
        }

        var combined: [SelectedPhoto]
        switch operation {
        case .replaceAll:
            combined = Array(imported.prefix(mode == .journal ? 5 : 1))
            PhotoAssetLoader.removeTemporaryResources(for: selectedPhotos)
            journalTransforms = Array(repeating: JournalPhotoTransform(), count: combined.count)
            selectedJournalIndex = mode == .journal ? 0 : nil
        case .append:
            let previousCount = selectedPhotos.count
            combined = Array((selectedPhotos + imported).prefix(5))
            journalTransforms += Array(
                repeating: JournalPhotoTransform(),
                count: max(0, combined.count - journalTransforms.count)
            )
            selectedJournalIndex = min(previousCount, combined.count - 1)
        case .replace(let index):
            combined = selectedPhotos
            if combined.indices.contains(index), let replacement = imported.first {
                PhotoAssetLoader.removeTemporaryResources(for: [combined[index]])
                combined[index] = replacement
                while journalTransforms.count < combined.count {
                    journalTransforms.append(JournalPhotoTransform())
                }
                journalTransforms[index] = JournalPhotoTransform()
                selectedJournalIndex = index
            }
        }
        importStatus = "正在分析整张照片的感知色彩…"
        let paletteResult = combinedPaletteResult(from: combined.map(\.image))
        selectedPhotos = combined
        images = combined.map(\.image)
        if operation == .replaceAll {
            resetPrivacyEdits(for: images.first)
        }
        let semantic = PhotoSemantic.combined(combined.map(\.semantic))
        if operation == .replaceAll {
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
        if operation == .replaceAll { resetComposition(animated: false) }

        withAnimation(.easeInOut(duration: 0.36)) {
            palette = paletteResult.colors
            palettePercentages = paletteResult.percentages
            isLoading = false
            isEditorVisible = true
            importStatus = ""
        }
        photoSelectionOperation = .replaceAll
        startRevealSequence()
        presentLivePhotoHintIfNeeded()
        if mode == .privacyMosaic, combined.contains(where: \.isLivePhoto) {
            showToast("隐私遮挡后仅支持静态导出，动态帧不会写入成品", duration: 3.6)
        } else if supportsLivePhotos,
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
        if mode == .privacyMosaic, let image = images.first, image.size.height > 0 {
            return min(max(image.size.width / image.size.height, 0.35), 2.40)
        }
        return ratio.value(for: images.first)
    }

    private func finishSettings() {
        guard modeChangedInSettings else { return }
        modeChangedInSettings = false

        // Switching creation modes changes only the presentation. The selected
        // photo, its metadata/semantic analysis, palette and Live Photo resource
        // remain the source material until the user explicitly picks a new photo.
        guard !selectedPhotos.isEmpty, !images.isEmpty else { return }
        toastTask?.cancel()
        toastMessage = nil
        resetComposition(animated: false)
        isEditorVisible = true
        isLoading = false
        if mode == .privacyMosaic {
            refreshPrivacyPreview()
        }
        startRevealSequence()
        presentLivePhotoHintIfNeeded()
        if mode == .privacyMosaic, selectedPhotos.contains(where: \.isLivePhoto) {
            showToast("隐私遮挡后仅支持静态导出，避免动态帧泄露隐私", duration: 3.6)
        }
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
            journalTransforms = Array(repeating: JournalPhotoTransform(), count: images.count)
            storedJournalTransform = JournalPhotoTransform()
            selectedJournalIndex = mode == .journal && !images.isEmpty ? 0 : nil
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
        if mode == .privacyMosaic {
            finishPrivacyPainting()
            if exportMetadataPolicy == .preserve {
                exportMetadataPolicy = .removeLocation
            }
        }
        exportCenterPresented = true
    }

    private func performConfiguredExport() {
        performSaveArtwork(
            format: exportFormat,
            resolution: exportResolution,
            metadataPolicy: exportMetadataPolicy,
            destination: exportDestination
        )
    }

    private func performSaveArtwork(
        format: ArtworkExportFormat,
        resolution: ArtworkExportResolution,
        metadataPolicy: ArtworkMetadataPolicy,
        destination: ArtworkExportDestination
    ) {
        guard canSave, saveState == .idle else { return }
        stopLivePhotoPlayback()
        dismissLivePhotoHint()
        withAnimation(.easeOut(duration: 0.16)) { saveState = .saving }
        showToast(
            mode == .privacyMosaic ? "正在渲染隐私静态作品…" : "正在渲染高清作品…",
            duration: 30
        )

        Task {
            let sourceWidth = images.first?.cgImage.map { CGFloat($0.width) } ?? 1080
            let pixelWidth = resolution.pixelWidth(sourceWidth: sourceWidth)
            guard let image = renderArtwork(pixelWidth: pixelWidth) else {
                saveState = .idle
                presentSaveError("作品渲染失败，请稍后重试。")
                return
            }

            do {
                let metadata = selectedPhotos.first?.metadata ?? .empty
                let originalData = selectedPhotos.first?.originalData
                let pairedVideoURLs: [Int: URL] = supportsLivePhotos
                    && mode != .privacyMosaic
                    && destination == .photoLibrary
                    ? liveSourceVideoURLs
                    : [:]
                let hasMissingLiveResource = supportsLivePhotos
                    && mode != .privacyMosaic
                    && destination == .photoLibrary
                    && selectedPhotos.contains { $0.isLivePhoto && $0.pairedVideoURL == nil }
                if hasMissingLiveResource {
                    throw ArtworkExportError.missingVideo
                }
                if !pairedVideoURLs.isEmpty {
                    showToast("正在生成 Live Photo 动态资源…", duration: 30)
                    try await ArtworkExporter.saveLivePhoto(
                        renderedStill: image,
                        sourceVideoURLs: pairedVideoURLs,
                        metadata: metadata,
                        originalImageData: originalData,
                        metadataPolicy: metadataPolicy,
                        renderFrame: { frames in
                            renderArtwork(replacingImages: frames, pixelWidth: pixelWidth)
                        },
                        progress: { progress in
                            toastMessage = "正在生成 Live Photo… \(Int((progress * 100).rounded()))%"
                        }
                    )
                } else if destination == .photoLibrary {
                    showToast(
                        metadataPolicy == .preserve
                            ? "正在写入相册并保留拍摄信息…"
                            : "正在写入相册并清理敏感元数据…",
                        duration: 30
                    )
                    try await ArtworkExporter.saveStill(
                        image,
                        metadata: metadata,
                        originalImageData: originalData,
                        format: format,
                        metadataPolicy: metadataPolicy
                    )
                } else {
                    showToast("正在编码 \(format.rawValue) 静态作品…", duration: 30)
                    let data = try ArtworkExporter.encodedStillData(
                        image,
                        metadata: metadata,
                        originalImageData: originalData,
                        format: format,
                        metadataPolicy: metadataPolicy
                    )
                    let url = try ExportTemporaryFile.make(data: data, format: format)
                    let item = ExportedArtworkFile(url: url)
                    if destination == .files {
                        documentExportFile = item
                    } else {
                        sharedExportFile = item
                    }
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

    private var livePhotoHintAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.40, dampingFraction: 0.78)
    }

    private func presentLivePhotoHintIfNeeded() {
        guard !hasShownLivePhotoPlaybackHint,
              !isLivePhotoHintPresented,
              livePhotoHintTask == nil,
              showsLivePlaybackControl,
              !liveSourceVideoURLs.isEmpty else { return }

        livePhotoHintTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 420))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  showsLivePlaybackControl,
                  !liveSourceVideoURLs.isEmpty else {
                livePhotoHintTask = nil
                return
            }

            didShowLivePhotoPlaybackHint = true
            didShowLivePhotoPlaybackHintBuild1060 = true
            withAnimation(livePhotoHintAnimation) {
                isLivePhotoHintPresented = true
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: "点击即可预览实况照片"
            )

            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            livePhotoHintTask = nil
            withAnimation(livePhotoHintAnimation) {
                isLivePhotoHintPresented = false
            }
        }
    }

    private func dismissLivePhotoHint(animated: Bool = true) {
        livePhotoHintTask?.cancel()
        livePhotoHintTask = nil
        guard isLivePhotoHintPresented else { return }
        if animated {
            withAnimation(livePhotoHintAnimation) {
                isLivePhotoHintPresented = false
            }
        } else {
            isLivePhotoHintPresented = false
        }
    }

    private func playLivePhotoOnce() {
        dismissLivePhotoHint()
        guard showsLivePlaybackControl, !isLivePhotoPlaying else { return }
        let sourceURLs = liveSourceVideoURLs
        guard !sourceURLs.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showToast("未取得实况照片动态片段，请确认原片已从 iCloud 下载后重新选择", duration: 3.4)
            return
        }

        stopLivePhotoPlayback()
        isLivePhotoPlaying = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        livePlaybackTask = Task {
            do {
                try await LivePhotoPreview.playOnce(sourceVideoURLs: sourceURLs) { frames in
                    livePreviewFrames = frames
                }
            } catch is CancellationError {
                // Cancellation is expected when switching modes, selecting a new
                // photo, saving, or leaving the editor.
            } catch {
                presentSaveError(error.localizedDescription, title: "无法播放实况照片")
            }

            livePreviewFrames = [:]
            isLivePhotoPlaying = false
            livePlaybackTask = nil
        }
    }

    private func stopLivePhotoPlayback() {
        livePlaybackTask?.cancel()
        livePlaybackTask = nil
        livePreviewFrames = [:]
        isLivePhotoPlaying = false
    }

    private func renderArtwork(
        replacingImages replacements: [Int: UIImage] = [:],
        pixelWidth: CGFloat = 1080
    ) -> UIImage? {
        let renderWidth: CGFloat = 360
        let renderScale = min(max(pixelWidth / renderWidth, 1), 16.67)
        var renderImages = images
        for (index, frame) in replacements where renderImages.indices.contains(index) {
            renderImages[index] = frame
        }
        let outputRatio: CGFloat
        if mode == .spectrumWallpaper {
            outputRatio = min(max(UIScreen.main.bounds.width / UIScreen.main.bounds.height, 0.43), 0.50)
        } else if mode == .privacyMosaic,
                  let image = renderImages.first,
                  image.size.height > 0 {
            outputRatio = min(max(image.size.width / image.size.height, 0.35), 2.40)
        } else {
            outputRatio = ratio.value(for: renderImages.first)
        }
        // Keep the SwiftUI canvas edge on a physical output-pixel boundary.
        // A fractional final row is transparent and turns black when encoded as JPEG.
        let renderHeight = ((renderWidth / outputRatio) * renderScale).rounded(.up) / renderScale
        let renderer = ImageRenderer(
            content: ArtworkCanvas(
                mode: mode,
                images: renderImages,
                palette: palette,
                palettePercentages: palettePercentages,
                ratio: ratio,
                showHexValues: showHexValues,
                showPalettePercentages: showPalettePercentages,
                showDeviceInfo: showDeviceInfo,
                showBubbles: showBubbles,
                gentleBackground: gentleBackground,
                imageScale: imageScale,
                imageOffset: imageOffset,
                    metadata: primaryMetadata,
                    copy: artworkCopy,
                    fontStyle: fontStyle,
                    templateStyle: templateStyle,
                    textScale: textScale,
                bubbleScale: bubbleScale,
                paletteOffset: paletteOffset,
                paletteLayout: paletteLayout,
                useLiteraryColorNames: useLiteraryColorNames,
                preservePaletteBackground: preservePaletteBackground,
                applyLiquidGlassOnExport: applyLiquidGlassOnExport,
                isExporting: true,
                paletteRevealStage: 4,
                generationProgress: 1,
                    privacyMasks: privacyMasks,
                    privacyStrokes: privacyStrokes,
                    privacyPixelatedImage: privacyPixelatedImage,
                    journalLayout: journalLayout,
                    journalTransforms: journalTransforms,
                    selectedJournalIndex: nil
            )
            .frame(width: renderWidth, height: renderHeight)
        )
        renderer.scale = renderScale
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

    private func regenerateCopy() -> ArtworkCopy {
        guard !selectedPhotos.isEmpty else { return artworkCopy }
        copyVariant += 1
        artworkCopy = defaultCopy(
            metadata: primaryMetadata,
            palette: palette,
            semantic: combinedSemantic
        )
        copyWasEdited = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        return artworkCopy
    }

#if DEBUG
    private func loadDebugPreviewIfNeeded() async {
        guard ProcessInfo.processInfo.arguments.contains("--demo"), images.isEmpty else { return }
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--reset-live-hint") {
            dismissLivePhotoHint(animated: false)
            didShowLivePhotoPlaybackHint = false
            didShowLivePhotoPlaybackHintBuild1060 = false
        }
        if arguments.contains("--palette") { mode = .colorPalette }
        if arguments.contains("--journal") { mode = .journal }
        if arguments.contains("--stamp") { mode = .bubbleStamp }
        if arguments.contains("--wallpaper") { mode = .spectrumWallpaper }
        if arguments.contains("--privacy") { mode = .privacyMosaic }
        ratio = mode.defaultRatio
        if arguments.contains("--ratio-square") { ratio = .oneOne }
        if arguments.contains("--ratio-four-five") { ratio = .fourFive }
        if arguments.contains("--ratio-nine-sixteen") { ratio = .nineSixteen }
        if arguments.contains("--ratio-sixteen-nine") { ratio = .sixteenNine }
        if arguments.contains("--template-airy") { templateStyleRaw = ArtworkTemplateStyle.airy.rawValue }
        if arguments.contains("--template-immersive") { templateStyleRaw = ArtworkTemplateStyle.immersive.rawValue }
        if arguments.contains("--journal-magazine") { journalLayoutRaw = JournalLayoutMode.magazine.rawValue }
        if arguments.contains("--journal-filmstrip") { journalLayoutRaw = JournalLayoutMode.filmstrip.rawValue }
        let fixturePath = arguments
            .first(where: { $0.hasPrefix("--fixture-path=") })
            .map { String($0.dropFirst("--fixture-path=".count)) }
        let liveFixturePath = arguments
            .first(where: { $0.hasPrefix("--live-fixture-path=") })
            .map { String($0.dropFirst("--live-fixture-path=".count)) }
        let liveFixtureURL = liveFixturePath.map { URL(fileURLWithPath: $0) }
            .flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        let fixtureData = arguments.contains("--fixture")
            ? fixturePath.flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
                ?? Bundle.main.url(forResource: "Fixture", withExtension: "jpeg").flatMap { try? Data(contentsOf: $0) }
            : nil
        let fallbackImage = arguments.contains("--literary-colors")
            ? Self.debugLiteraryColorPreviewImage()
            : Self.debugPreviewImage()
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
        let debugImages = mode == .journal && fixtureData == nil
            ? (0..<5).map { Self.debugPreviewImage(variant: $0) }
            : [image]
        selectedPhotos = debugImages.map { debugImage in
            SelectedPhoto(
                image: debugImage,
                originalData: fixtureData == nil
                    ? (debugImage.jpegData(compressionQuality: 0.94) ?? data)
                    : data,
                metadata: debugMetadata,
                semantic: semantic,
                pairedVideoURL: liveFixtureURL,
                isLivePhoto: liveFixtureURL != nil
            )
        }
        images = selectedPhotos.map(\.image)
        journalTransforms = Array(repeating: JournalPhotoTransform(), count: images.count)
        selectedJournalIndex = mode == .journal ? 0 : nil
        resetPrivacyEdits(for: image)
        if mode == .privacyMosaic, arguments.contains("--privacy-mask") {
            privacyMasks = [
                PrivacyMask(
                    kind: .face,
                    normalizedRect: CGRect(x: 0.32, y: 0.26, width: 0.24, height: 0.18)
                ),
                PrivacyMask(
                    kind: .sensitiveText,
                    normalizedRect: CGRect(x: 0.12, y: 0.72, width: 0.46, height: 0.08)
                )
            ]
            privacyStrokes = [PrivacyStroke(
                points: [
                    CGPoint(x: 0.62, y: 0.62),
                    CGPoint(x: 0.68, y: 0.66),
                    CGPoint(x: 0.75, y: 0.63)
                ],
                normalizedWidth: privacyBrushWidth
            )]
        }
        let result: PaletteResult
        if arguments.contains("--literary-colors") {
            result = PaletteResult(
                colors: Self.debugLiteraryPalette,
                percentages: Array(
                    repeating: 100 / Double(Self.debugLiteraryPalette.count),
                    count: Self.debugLiteraryPalette.count
                )
            )
        } else if mode == .journal {
            result = combinedPaletteResult(from: images)
        } else {
            result = PaletteExtractor.extract(from: image)
        }
        palette = result.colors
        palettePercentages = result.percentages
        artworkCopy = defaultCopy(metadata: debugMetadata, palette: result.colors, semantic: semantic)
        isEditorVisible = true
        canvasRevealed = true
        paletteRevealStage = 4
        generationProgress = 1
        canSave = true
        didAcknowledgeFreeNotice = true
        // Mode changes reset the ratio through the normal settings observer.
        // Reapply debug-only overrides after asynchronous fixture analysis so
        // screenshot and export verification exercise the requested canvas.
        if arguments.contains("--ratio-square") { ratio = .oneOne }
        if arguments.contains("--ratio-four-five") { ratio = .fourFive }
        if arguments.contains("--ratio-nine-sixteen") { ratio = .nineSixteen }
        if arguments.contains("--ratio-sixteen-nine") { ratio = .sixteenNine }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            if arguments.contains("--ratio-square") { ratio = .oneOne }
            if arguments.contains("--ratio-four-five") { ratio = .fourFive }
            if arguments.contains("--ratio-nine-sixteen") { ratio = .nineSixteen }
            if arguments.contains("--ratio-sixteen-nine") { ratio = .sixteenNine }
        }
        if arguments.contains("--animate-later") {
            Task {
                try? await Task.sleep(for: .seconds(3))
                startRevealSequence()
            }
        } else if arguments.contains("--animate") {
            startRevealSequence()
        }
        presentLivePhotoHintIfNeeded()
        if arguments.contains("--settings") { settingsPresented = true }
        if arguments.contains("--export-center") { exportCenterPresented = true }
        if mode == .privacyMosaic, arguments.contains("--privacy-paint") {
            isPrivacyPainting = true
            privacyBrushMode = .paint
        }
        if arguments.contains("--debug-render") {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard let rendered = renderArtwork(),
                      let pngData = rendered.pngData(),
                      let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                let baseName = "debug-render-\(mode.rawValue)"
                try? pngData.write(
                    to: directory.appendingPathComponent(baseName).appendingPathExtension("png"),
                    options: .atomic
                )
                if let jpegData = try? ArtworkExporter.debugJPEGData(
                    rendered,
                    metadata: primaryMetadata,
                    originalImageData: selectedPhotos.first?.originalData,
                    preserveLocation: false
                ) {
                    try? jpegData.write(
                        to: directory.appendingPathComponent(baseName).appendingPathExtension("jpg"),
                        options: .atomic
                    )
                }
            }
        }
        if arguments.contains("--debug-export-suite") {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard let rendered = renderArtwork(pixelWidth: 2160),
                      let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

                var verificationMetadata = primaryMetadata
                verificationMetadata.make = "LocalLens"
                verificationMetadata.model = "Verification Camera"
                verificationMetadata.captureDate = Date(timeIntervalSince1970: 1_700_000_000)
                verificationMetadata.latitude = 31.2304
                verificationMetadata.longitude = 121.4737
                var report: [String] = []

                for format in ArtworkExportFormat.allCases {
                    for policy in ArtworkMetadataPolicy.allCases {
                        do {
                            let data = try ArtworkExporter.encodedStillData(
                                rendered,
                                metadata: verificationMetadata,
                                originalImageData: nil,
                                format: format,
                                metadataPolicy: policy
                            )
                            let fileName = "export-\(format.fileExtension)-\(policy.id)"
                            let url = directory
                                .appendingPathComponent(fileName)
                                .appendingPathExtension(format.fileExtension)
                            try data.write(to: url, options: .atomic)

                            let source = CGImageSourceCreateWithData(data as CFData, nil)
                            let properties = source.flatMap {
                                CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
                            } ?? [:]
                            let hasGPS = properties[kCGImagePropertyGPSDictionary] != nil
                            let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
                            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
                            let hasCamera = tiff?[kCGImagePropertyTIFFMake] != nil
                                || tiff?[kCGImagePropertyTIFFModel] != nil
                            let hasCaptureDate = exif?[kCGImagePropertyExifDateTimeOriginal] != nil
                            let metadataPass: Bool
                            switch policy {
                            case .preserve:
                                metadataPass = hasGPS && hasCamera && hasCaptureDate
                            case .removeLocation:
                                metadataPass = !hasGPS && hasCamera && hasCaptureDate
                            case .removeAll:
                                metadataPass = !hasGPS && !hasCamera && !hasCaptureDate
                            }
                            let dimensionsPass = rendered.cgImage?.width == 2160
                            report.append(
                                "\(metadataPass && dimensionsPass ? "PASS" : "FAIL") \(format.rawValue) \(policy.rawValue) \(rendered.cgImage?.width ?? 0)x\(rendered.cgImage?.height ?? 0) gps=\(hasGPS) camera=\(hasCamera) date=\(hasCaptureDate)"
                            )
                        } catch {
                            report.append("FAIL \(format.rawValue) \(policy.rawValue): \(error.localizedDescription)")
                        }
                    }
                }

                try? report.joined(separator: "\n")
                    .write(
                        to: directory.appendingPathComponent("export-suite.txt"),
                        atomically: true,
                        encoding: .utf8
                    )
            }
        }
        if mode == .privacyMosaic, arguments.contains("--privacy-render") {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard let rendered = renderArtwork(),
                      let data = rendered.pngData(),
                      let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                try? data.write(to: directory.appendingPathComponent("privacy-render.png"), options: .atomic)
                var debugMetadataWithLocation = primaryMetadata
                debugMetadataWithLocation.latitude = 31.2304
                debugMetadataWithLocation.longitude = 121.4737
                if let jpeg = try? ArtworkExporter.debugJPEGData(
                    rendered,
                    metadata: debugMetadataWithLocation,
                    originalImageData: selectedPhotos.first?.originalData,
                    preserveLocation: false
                ) {
                    try? jpeg.write(
                        to: directory.appendingPathComponent("privacy-render-no-location.jpg"),
                        options: .atomic
                    )
                }
            }
        }
    }

    private static func debugPreviewImage(variant: Int = 0) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            let hues: [CGFloat] = [0.26, 0.06, 0.56, 0.78, 0.96]
            let hue = hues[variant % hues.count]
            let colors = [
                UIColor(hue: hue, saturation: 0.30, brightness: 0.98, alpha: 1).cgColor,
                UIColor(hue: hue, saturation: 0.62, brightness: 0.56, alpha: 1).cgColor
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
                    let tone = CGFloat((row + column) % 4) * 0.045
                    UIColor(
                        hue: (hue + tone * 0.12).truncatingRemainder(dividingBy: 1),
                        saturation: 0.72 - tone,
                        brightness: 0.54 + tone,
                        alpha: 0.94
                    ).setFill()
                    context.fillEllipse(in: rect)
                    UIColor.white.withAlphaComponent(0.16).setStroke()
                    context.setLineWidth(8)
                    context.strokeEllipse(in: rect.insetBy(dx: 18, dy: 18))
                }
            }
        }
    }

    /// A deterministic six-stripe fixture for visually verifying literary
    /// color names without depending on Photos, image compression or Vision.
    private static let debugLiteraryPalette: [RGBColor] = [
        RGBColor(red: 0x31 / 255, green: 0x35 / 255, blue: 0x41 / 255),
        RGBColor(red: 0x60 / 255, green: 0x54 / 255, blue: 0x55 / 255),
        RGBColor(red: 0x4A / 255, green: 0x52 / 255, blue: 0x57 / 255),
        RGBColor(red: 0xA8 / 255, green: 0xC9 / 255, blue: 0x28 / 255),
        RGBColor(red: 0x35 / 255, green: 0x59 / 255, blue: 0x9A / 255),
        RGBColor(red: 0xDB / 255, green: 0x6B / 255, blue: 0x73 / 255)
    ]

    private static func debugLiteraryColorPreviewImage() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let stripeWidth = size.width / CGFloat(debugLiteraryPalette.count)
            for index in debugLiteraryPalette.indices {
                let color = debugLiteraryPalette[index]
                renderer.cgContext.setFillColor(UIColor(
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: 1
                ).cgColor)
                renderer.cgContext.fill(CGRect(
                    x: CGFloat(index) * stripeWidth,
                    y: 0,
                    width: stripeWidth,
                    height: size.height
                ))
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
    private enum Field: Hashable {
        case title
        case subtitle
        case emojis
        case journalCaption
    }

    @Environment(\.dismiss) private var dismiss
    let mode: CreationMode
    let semantic: PhotoSemantic
    @Binding var copy: ArtworkCopy
    @Binding var copyWasEdited: Bool
    let onRegenerate: () -> ArtworkCopy
    @State private var draft: ArtworkCopy
    @FocusState private var focusedField: Field?

    init(
        mode: CreationMode,
        semantic: PhotoSemantic,
        copy: Binding<ArtworkCopy>,
        copyWasEdited: Binding<Bool>,
        onRegenerate: @escaping () -> ArtworkCopy
    ) {
        self.mode = mode
        self.semantic = semantic
        _copy = copy
        _copyWasEdited = copyWasEdited
        self.onRegenerate = onRegenerate
        _draft = State(initialValue: copy.wrappedValue)
    }

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
                    Button {
                        draft = onRegenerate()
                    } label: {
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
                            .focused($focusedField, equals: .title)
                            .submitLabel(.done)
                    }
                }
                if mode == .bubbleStamp {
                    Section("英文副标题") {
                        TextField("输入副标题", text: tracked(\.subtitle), axis: .vertical)
                            .lineLimit(1...3)
                            .focused($focusedField, equals: .subtitle)
                            .submitLabel(.done)
                    }
                }
                if mode == .journal {
                    Section("Emoji") {
                        TextField("输入 Emoji", text: tracked(\.emojis), axis: .vertical)
                            .lineLimit(1...4)
                            .focused($focusedField, equals: .emojis)
                            .submitLabel(.done)
                    }
                    Section("手帐文案") {
                        TextField("输入文案", text: tracked(\.journalCaption), axis: .vertical)
                            .lineLimit(1...4)
                            .focused($focusedField, equals: .journalCaption)
                            .submitLabel(.done)
                    }
                }

                Section {
                    Text("所有文字只用于本次作品，不会上传到网络。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("编辑作品文字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        focusedField = nil
                        commitDraft()
                        dismiss()
                    }
                        .fontWeight(.semibold)
                }
            }
        }
        .onDisappear(perform: commitDraft)
    }

    private func tracked(_ keyPath: WritableKeyPath<ArtworkCopy, String>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { newValue in
                draft[keyPath: keyPath] = newValue
            }
        )
    }

    private func commitDraft() {
        guard draft != copy else { return }
        copy = draft
        copyWasEdited = true
    }
}

private struct ShakeDetector: UIViewControllerRepresentable {
    let isEnabled: Bool
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller(isEnabled: isEnabled, onShake: onShake)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.onShake = onShake
        uiViewController.setEnabled(isEnabled)
    }

    final class Controller: UIViewController {
        private var isEnabled: Bool
        var onShake: () -> Void

        init(isEnabled: Bool, onShake: @escaping () -> Void) {
            self.isEnabled = isEnabled
            self.onShake = onShake
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if isEnabled { becomeFirstResponder() }
        }

        func setEnabled(_ enabled: Bool) {
            guard enabled != isEnabled else { return }
            isEnabled = enabled
            if enabled {
                guard viewIfLoaded?.window != nil else { return }
                becomeFirstResponder()
            } else if isFirstResponder {
                resignFirstResponder()
            }
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard isEnabled, motion == .motionShake else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onShake()
        }
    }
}
