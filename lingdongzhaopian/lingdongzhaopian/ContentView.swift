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

private enum Version210Audience: String {
    case upgradedFromPreviousVersion
    case installed210
}

struct ContentView: View {
    private static let ticketScannerIntroID = "ticketScanner"
    private static let albumIntroID = "photoAlbum"
    private static let colorRelationshipIntroID = "colorRelationship"
    private static let videoToLivePhotoIntroID = "videoToLivePhoto"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didAcknowledgeFreeNotice") private var didAcknowledgeFreeNotice = false
    @AppStorage("didShowPublicGoodsCommitment") private var didShowPublicGoodsCommitment = false
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
    @AppStorage("useCustomCameraWatermarks") private var useCustomCameraWatermarks = false
    @AppStorage("gentleBackground") private var gentleBackground = true
    @AppStorage("privacyMosaicStrength") private var privacyMosaicStrength = 0.62
    @AppStorage("showAppTitle") private var showAppTitle = true
    @AppStorage("showMissingCaptureTime") private var showMissingCaptureTime = true
    @AppStorage("artworkTemplateStyle") private var templateStyleRaw = ArtworkTemplateStyle.classic.rawValue
    @AppStorage("motionCardHeaderStyle") private var motionCardHeaderStyleRaw = MotionCardHeaderStyle.solid.rawValue
    @AppStorage("journalLayout") private var journalLayoutRaw = JournalLayoutMode.automatic.rawValue
    @AppStorage("exportFormat") private var exportFormatRaw = ArtworkExportFormat.jpeg.rawValue
    @AppStorage("exportResolution") private var exportResolutionRaw = ArtworkExportResolution.standard.rawValue
    @AppStorage("exportMetadataPolicy") private var exportMetadataPolicyRaw = ArtworkMetadataPolicy.removeLocation.rawValue
    @AppStorage("exportDestination") private var exportDestinationRaw = ArtworkExportDestination.photoLibrary.rawValue
    @AppStorage("ticketCodeStyle") private var ticketCodeStyleRaw = TicketCodeStyle.barcode.rawValue
    @AppStorage("ticketLayoutStyle") private var ticketLayoutRaw = TicketLayoutStyle.classic.rawValue
    @AppStorage("ticketCanvasWidthMode") private var ticketCanvasWidthModeRaw = TicketCanvasWidthMode.compact.rawValue
    @AppStorage("ticketShowCopy") private var ticketShowCopy = true
    @AppStorage("ticketShowDate") private var ticketShowDate = true
    @AppStorage("ticketShowPlace") private var ticketShowPlace = false
    @AppStorage("ticketShowDevice") private var ticketShowDevice = true
    @AppStorage("ticketShowParameters") private var ticketShowParameters = true
    @AppStorage("ticketShowPalette") private var ticketShowPalette = true
    @AppStorage("ticketDeviceSealEnabled") private var ticketDeviceSealEnabled = true
    @AppStorage("ticketHeaderMode") private var ticketHeaderModeRaw = TicketHeaderMode.custom.rawValue
    @AppStorage("ticketCustomHeader") private var ticketCustomHeader = "LINGDONG"
    @AppStorage("ticketCityNameStyle") private var ticketCityNameStyleRaw = TicketCityNameStyle.pinyin.rawValue
    @AppStorage("ticketNarrativeStyle") private var ticketNarrativeStyleRaw = TicketNarrativeStyle.standard.rawValue
    @AppStorage("ticketNarrativePerspective") private var ticketNarrativePerspectiveRaw = TicketNarrativePerspective.defaultRawValue
    // This key is intentionally independent of the build number. Do not rename it
    // for future releases, otherwise users would see the one-time hint again.
    @AppStorage("didShowLivePhotoPlaybackHint") private var didShowLivePhotoPlaybackHint = false
    @AppStorage("didShowLivePhotoPlaybackHintBuild1060") private var didShowLivePhotoPlaybackHintBuild1060 = false
    @AppStorage("version210Audience") private var version210AudienceRaw = ""
    @AppStorage("didShowVersion210Update") private var didShowVersion210Update = false
    @AppStorage("didShowModeSelectionHint101") private var didShowModeSelectionHint101 = false
    @AppStorage("didShowTicketLandscapeHint") private var didShowTicketLandscapeHint = false
    @AppStorage("didShowTicketNarrativePrompt") private var didShowTicketNarrativePrompt = false

    @State private var mode: CreationMode = .motionCard
    @State private var introPageID = CreationMode.motionCard.rawValue
    @State private var pickerSelections: [PhotoPickerSelection] = []
    @State private var isPickerPresented = false
    @State private var selectedPhotos: [SelectedPhoto] = []
    @State private var images: [UIImage] = []
    @State private var palette = RGBColor.fallback
    @State private var palettePercentages = [Double](repeating: 0, count: 6)
    @State private var colorInsightPage: ColorInsightPage = .palette
    @State private var lightAnalysis: PhotoLightAnalysis?
    @State private var activeLightToneRange: LightToneRange?
    @State private var lightAnalysisTask: Task<Void, Never>?
    @State private var motionCardSamplingRect: CGRect?
    @State private var motionCardLocalPalette: [RGBColor]?
    @State private var motionCardLocalPercentages: [Double]?
    @State private var ratio: ArtworkRatio = .threeFour

    @State private var isLoading = false
    @State private var isEditorVisible = false
    @State private var canvasRevealed = false
    @State private var paletteRevealStage = 0
    @State private var generationProgress: CGFloat = 0
    @State private var canSave = false
    @State private var saveState: SaveVisualState = .idle
    @State private var settingsPresented = false
    @State private var motionCardColorSamplerPresented = false
    @State private var modeSelectionPresented = false
    @State private var ticketScannerPresented = false
    @State private var albumPresented = false
    @State private var colorRelationshipPresented = false
    @State private var videoToLivePhotoPresented = false
    @State private var toastMessage: String?
    @State private var errorTitle = "无法保存"
    @State private var saveErrorMessage = ""
    @State private var saveErrorPresented = false
    @State private var editCopyPresented = false
    @State private var photoSelectionOperation: PhotoSelectionOperation = .replaceAll
    @State private var importStatus = ""
    @State private var isImportingSharedPhoto = false
    @State private var exportCenterPresented = false
    @State private var ticketStudioPresented = false
    @State private var ticketNarrativePromptPresented = false
    @State private var ticketMessage = ""
    @State private var ticketSealedAtText = TicketTimeCalculator.nowFormatted()
    @State private var ticketMessagePromptPresented = false
    @State private var ticketMessageEditorPresented = false
    @State private var shouldExportAfterTicketMessageEditor = false
    @State private var skippedTicketMessageForCurrentPhoto = false
    @State private var verifiedTicket: VerifiedTicket?
    @State private var ticketVerificationErrorMessage = ""
    @State private var ticketVerificationErrorPresented = false
    @State private var isTicketLandscape = false
    @State private var sharedExportFile: ExportedArtworkFile?
    @State private var documentExportFile: ExportedArtworkFile?
    @State private var ticketPrintPhase: TicketPrintPhase = .idle
    @State private var ticketPrintImage: UIImage?
    @State private var ticketPrintProgress: CGFloat = 0
    @State private var ticketPrintHapticTask: Task<Void, Never>?
    @State private var ticketPrintAnimationDeadline: Date?

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

    @State private var sketchParameters = SketchParameters.defaultPencil
    @State private var sketchImage: UIImage?
    @State private var isSketchRendering = false
    @State private var sketchRenderTask: Task<Void, Never>?
    @State private var sketchRenderRevision = 0
    @State private var renderedSketchParameters: SketchParameters?

    @State private var revealTask: Task<Void, Never>?
    @State private var toastTask: Task<Void, Never>?
    @State private var livePlaybackTask: Task<Void, Never>?
    @State private var livePlaybackSessionID: UUID?
    @State private var livePhotoHintTask: Task<Void, Never>?
    @State private var modeSelectionHintTask: Task<Void, Never>?
    @State private var ticketLandscapeHintTask: Task<Void, Never>?
    @State private var livePreviewFrames: [Int: UIImage] = [:]
    @State private var isLivePhotoPlaying = false
    @State private var isLivePhotoHintPresented = false
    @State private var isModeSelectionHintPresented = false
    @State private var isTicketLandscapeHintPresented = false
    @State private var publicGoodsCommitmentPresented = false
    @State private var version210UpdatePresented = false
    @StateObject private var cameraWatermarkLibrary = CameraWatermarkLibrary()

    private var pickerLimit: Int {
        if mode == .journal, photoSelectionOperation == .append {
            return max(1, 5 - selectedPhotos.count)
        }
        if case .replace = photoSelectionOperation { return 1 }
        return mode == .journal ? 5 : 1
    }

    private var hasCurrentSketchRender: Bool {
        !isSketchRendering
            && sketchImage != nil
            && renderedSketchParameters == sketchParameters
    }

    private var canSaveCurrentArtwork: Bool {
        canSave && (mode != .sketch || hasCurrentSketchRender)
    }
    private var controlsAreDimmed: Bool { saveState == .saving }
    private var paletteLayout: PaletteLayoutMode {
        PaletteLayoutMode(rawValue: paletteLayoutRaw) ?? .floating
    }
    private var templateStyle: ArtworkTemplateStyle {
        ArtworkTemplateStyle(rawValue: templateStyleRaw) ?? .classic
    }
    private var motionCardHeaderStyle: MotionCardHeaderStyle {
        MotionCardHeaderStyle(rawValue: motionCardHeaderStyleRaw) ?? .solid
    }
    private var effectiveMotionCardPalette: [RGBColor] {
        motionCardLocalPalette ?? palette
    }
    private var effectiveMotionCardPercentages: [Double] {
        motionCardLocalPercentages ?? palettePercentages
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
    private var ticketCodeStyle: TicketCodeStyle {
        get { TicketCodeStyle(rawValue: ticketCodeStyleRaw) ?? .barcode }
        nonmutating set { ticketCodeStyleRaw = newValue.rawValue }
    }
    private var ticketLayout: TicketLayoutStyle {
        get { TicketLayoutStyle(rawValue: ticketLayoutRaw) ?? .classic }
        nonmutating set {
            ticketLayoutRaw = newValue.rawValue
            if newValue == .vertical {
                ratio = .threeFour
            } else if newValue == .classic {
                switch ticketCanvasWidthMode {
                case .compact: ratio = .twentyOneNine
                case .standard: ratio = .sixteenNine
                case .poster: ratio = .fourThree
                }
            } else {
                ratio = .twentyOneNine
            }
        }
    }
    private var ticketCanvasWidthMode: TicketCanvasWidthMode {
        get { TicketCanvasWidthMode(rawValue: ticketCanvasWidthModeRaw) ?? .compact }
        nonmutating set {
            ticketCanvasWidthModeRaw = newValue.rawValue
            if mode == .travelTicket && ticketLayout == .classic {
                switch newValue {
                case .compact: ratio = .twentyOneNine
                case .standard: ratio = .sixteenNine
                case .poster: ratio = .fourThree
                }
            }
        }
    }
    private var ticketHeaderMode: TicketHeaderMode {
        get { TicketHeaderMode(rawValue: ticketHeaderModeRaw) ?? .custom }
        nonmutating set { ticketHeaderModeRaw = newValue.rawValue }
    }
    private var ticketCityNameStyle: TicketCityNameStyle {
        get { TicketCityNameStyle(rawValue: ticketCityNameStyleRaw) ?? .pinyin }
        nonmutating set { ticketCityNameStyleRaw = newValue.rawValue }
    }
    private var ticketNarrativeStyle: TicketNarrativeStyle {
        get { TicketNarrativeStyle(rawValue: ticketNarrativeStyleRaw) ?? .standard }
        nonmutating set { ticketNarrativeStyleRaw = newValue.rawValue }
    }
    private var ticketNarrativePerspective: TicketNarrativePerspective {
        get { TicketNarrativePerspective(rawValue: ticketNarrativePerspectiveRaw) ?? .self }
        nonmutating set { ticketNarrativePerspectiveRaw = newValue.rawValue }
    }
    private var ticketIsEmotional: Bool { ticketNarrativeStyle == .emotional }
    private var ticketIsSelfPerspective: Bool { ticketNarrativePerspective == .self }
    private var ticketMessagePromptTitle: String {
        if ticketIsEmotional {
            return (ticketIsSelfPerspective ? "还没有写下这次的备忘" : "还没有写下这次的寄语").appLocalized
        }
        return "还没有写下这次的寄语".appLocalized
    }
    private var ticketMessagePromptActionTitle: String {
        if ticketIsEmotional {
            return (ticketIsSelfPerspective ? "补充备忘" : "补充寄语").appLocalized
        }
        return "补充寄语".appLocalized
    }
    private var ticketMessagePromptMessage: String {
        if ticketIsEmotional {
            return ticketIsSelfPerspective
                ? "这段备忘会随票根一起封存，扫描时可以看到。要在导出前补充吗？".appLocalized
                : "这段寄语会随票根一起封存，扫描时可以看到。要在导出前补充吗？".appLocalized
        }
        return "寄语会显示在影像票根的公开信息中。要在导出前补充吗？".appLocalized
    }
    private var primaryMetadata: PhotoMetadata { selectedPhotos.first?.metadata ?? .empty }
    private var activeCameraWatermark: UIImage? {
        guard useCustomCameraWatermarks else { return nil }
        return cameraWatermarkLibrary.image(for: primaryMetadata.captureDevice)
    }
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
        mode != .privacyMosaic
            && mode != .travelTicket
            && mode != .sketch
            && selectedPhotos.contains(where: \.isLivePhoto)
    }
    private var canPresentLivePhotoHint: Bool {
        isEditorVisible
            && showsLivePlaybackControl
            && !liveSourceVideoURLs.isEmpty
            && didShowModeSelectionHint101
            && !isModeSelectionHintPresented
            && modeSelectionHintTask == nil
            && !publicGoodsCommitmentPresented
            && !version210UpdatePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !isPickerPresented
    }
    private var canPresentModeSelectionHint: Bool {
        isEditorVisible
            && !didShowModeSelectionHint101
            && !publicGoodsCommitmentPresented
            && !version210UpdatePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !isPickerPresented
    }
    private var canPresentTicketLandscapeHint: Bool {
        isEditorVisible
            && mode == .travelTicket
            && !isTicketLandscape
            && !didShowTicketLandscapeHint
            && didShowModeSelectionHint101
            && !isModeSelectionHintPresented
            && modeSelectionHintTask == nil
            && !publicGoodsCommitmentPresented
            && !version210UpdatePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !exportCenterPresented
            && !ticketStudioPresented
            && !ticketNarrativePromptPresented
            && !isPickerPresented
    }
    private var canPresentNarrativePrompt: Bool {
        isEditorVisible
            && mode == .travelTicket
            && !didShowTicketNarrativePrompt
            && !publicGoodsCommitmentPresented
            && !version210UpdatePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !exportCenterPresented
            && !ticketStudioPresented
            && !ticketMessageEditorPresented
            && !ticketMessagePromptPresented
            && !ticketVerificationErrorPresented
            && !isPickerPresented
            && !albumPresented
            && !isTicketLandscape
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
    private var ticketPayload: TicketPayload {
        let signature = TicketPayload.contentSignature(
            for: selectedPhotos.first?.originalData ?? Data(),
            fallback: combinedSemantic.signature
        )
        let paletteEntries = ticketShowPalette
            ? zip(palette.prefix(6), palettePercentages.prefix(6)).map { color, percentage in
                TicketPaletteEntry(hex: color.hex, percentage: percentage)
            }
            : []
        let captureTime: String?
        if ticketShowDate,
           primaryMetadata.captureDate != nil || showMissingCaptureTime {
            captureTime = primaryMetadata.captureTimeText
        } else {
            captureTime = nil
        }
        let place: String?
        if ticketShowPlace,
           primaryMetadata.placeName != nil || primaryMetadata.hasLocation {
            place = primaryMetadata.displayTitle
        } else {
            place = nil
        }
        let device = ticketShowDevice
            ? primaryMetadata.captureDevice.displayName
            : nil
        let headerTitle: String?
        switch ticketHeaderMode {
        case .custom:
            let value = ticketCustomHeader
                .trimmingCharacters(in: .whitespacesAndNewlines)
            headerTitle = value.isEmpty ? nil : value
        case .city:
            headerTitle = primaryMetadata.ticketCityLabel(style: ticketCityNameStyle)
                ?? "LINGDONG"
        }
        return TicketPayload(
            ticketID: TicketPayload.ticketIdentifier(from: signature),
            fingerprint: TicketPayload.fingerprintText(from: signature),
            headerTitle: headerTitle,
            title: ticketShowCopy ? artworkCopy.title : "一张影像票根",
            subtitle: ticketShowCopy ? artworkCopy.subtitle : nil,
            message: ticketMessage,
            captureTime: captureTime,
            place: place,
            device: device,
            lens: ticketShowDevice ? primaryMetadata.cameraLensLine : nil,
            captureSettings: ticketShowParameters
                ? primaryMetadata.captureSettingsLine
                : nil,
            palette: paletteEntries,
            revealLayout: ticketLayout.revealLayout,
            revealWidthMode: ticketLayout == .classic
                ? ticketCanvasWidthMode.revealWidthMode
                : nil,
            style: ticketNarrativeStyle == .emotional ? ticketNarrativeStyle.rawValue : nil,
            narrative: ticketNarrativeStyle == .emotional ? ticketNarrativePerspective.rawValue : nil,
            sealedAt: ticketSealedAtText
        )
    }

    private var ticketEnvelopeSigner: TicketEnvelopeSigning? {
        ticketDeviceSealEnabled ? TicketDeviceSealService.shared : nil
    }

    private var usesInAppTicketLandscape: Bool {
        if #available(iOS 18.0, *) { return false }
        return true
    }

    var body: some View {
        let presentedContent = AnyView(GeometryReader { proxy in
            ZStack {
                AmbientBackground(palette: isEditorVisible ? palette : RGBColor.intro)

                if isEditorVisible {
                    Group {
                        if mode == .travelTicket, isTicketLandscape {
                            if usesInAppTicketLandscape {
                                legacyTicketLandscapeEditorView(in: proxy.size)
                            } else {
                                ticketLandscapeEditorView(in: proxy.size)
                            }
                        } else {
                            editorView(in: proxy.size)
                        }
                    }
                    .transition(.opacity)
                } else {
                    introView
                        .transition(.opacity)
                }

                if let toastMessage {
                    toast(text: toastMessage)
                }

                if ticketPrintPhase.isPresented {
                    TicketPrintExperienceView(
                        phase: ticketPrintPhase,
                        ticketImage: ticketPrintImage,
                        feedProgress: ticketPrintProgress,
                        reduceMotion: reduceMotion,
                        supportsIsland: TicketIslandAvailability.isSupported(
                            screenSize: proxy.size,
                            safeAreaTop: proxy.safeAreaInsets.top
                        ),
                        backgroundPalette: palette
                    )
                    .zIndex(90)
                }

                ShakeDetector(
                    isEnabled: !editCopyPresented
                        && !settingsPresented
                        && !modeSelectionPresented
                        && !albumPresented
                        && !publicGoodsCommitmentPresented
                        && !version210UpdatePresented
                        && !isPickerPresented
                ) {
                    resetComposition()
                }
                    .frame(width: 0, height: 0)

            }
        }
        // Keep the established editor appearance light without overriding the
        // window's actual system appearance. Selected sheets can then opt back
        // into the user's system setting independently.
        .environment(\.colorScheme, .light)
        .statusBarHidden(true)
        .sheet(isPresented: $publicGoodsCommitmentPresented) {
            PublicGoodsCommitmentView(
                showsUpdateNext: shouldPresentVersion210Update,
                onNext: completePublicGoodsCommitment
            )
                .environment(\.colorScheme, .dark)
                .presentationDetents([.fraction(0.94)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(38)
                .presentationBackground(.black)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $version210UpdatePresented) {
            Version210UpdateView(onNext: completeVersion210Update)
                .environment(\.colorScheme, .dark)
                .presentationDetents([.fraction(0.94)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(38)
                .presentationBackground(.black)
                .interactiveDismissDisabled()
        }
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
        .sheet(isPresented: $motionCardColorSamplerPresented) {
            if let image = images.first {
                MotionCardColorSamplerView(
                    image: image,
                    initialSelection: motionCardSamplingRect,
                    headerStyle: motionCardHeaderStyle,
                    onApply: { selection, result in
                        motionCardSamplingRect = selection
                        motionCardLocalPalette = result.colors
                        motionCardLocalPercentages = result.percentages
                        motionCardColorSamplerPresented = false
                    },
                    onReset: {
                        resetMotionCardSampling()
                        motionCardColorSamplerPresented = false
                    }
                )
                .environment(\.colorScheme, systemColorScheme)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(34)
            }
        }
        .onChange(of: mode) { _, newMode in
            if introPageID != newMode.rawValue {
                introPageID = newMode.rawValue
            }
            stopLivePhotoPlayback()
            dismissLivePhotoHint()
            dismissTicketLandscapeHint()
            if newMode != .travelTicket, isTicketLandscape {
                setTicketLandscape(false)
            }
            ratio = newMode == .travelTicket && ticketLayout == .vertical
                ? .threeFour
                : (newMode == .travelTicket && ticketLayout == .classic
                    ? (ticketCanvasWidthMode == .compact ? .twentyOneNine
                        : ticketCanvasWidthMode == .standard ? .sixteenNine
                        : .fourThree)
                    : newMode.defaultRatio)
            if newMode == .privacyMosaic {
                refreshPrivacyPreview()
            } else {
                finishPrivacyPainting()
            }
            if newMode == .sketch {
                scheduleSketchPreviewRefresh()
            }
            if newMode != .colorPalette {
                activeLightToneRange = nil
            }
        }
        .onChange(of: colorInsightPage) { _, page in
            if page != .light { activeLightToneRange = nil }
        }
        .onChange(of: privacyMosaicStrength) { _, _ in
            schedulePrivacyPreviewRefresh()
        }
        .onChange(of: sketchParameters) { _, _ in
            scheduleSketchPreviewRefresh()
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
        .sheet(isPresented: $settingsPresented) {
            SettingsView(
                ratio: $ratio,
                showHexValues: $showHexValues,
                showDeviceInfo: $showDeviceInfo,
                showBubbles: $showBubbles,
                useCustomCameraWatermarks: $useCustomCameraWatermarks,
                gentleBackground: $gentleBackground,
                templateStyle: Binding(
                    get: { templateStyle },
                    set: { templateStyleRaw = $0.rawValue }
                ),
                motionCardHeaderStyle: Binding(
                    get: { motionCardHeaderStyle },
                    set: { motionCardHeaderStyleRaw = $0.rawValue }
                ),
                journalLayout: Binding(
                    get: { journalLayout },
                    set: { journalLayoutRaw = $0.rawValue }
                ),
                cameraWatermarkLibrary: cameraWatermarkLibrary
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents(isTicketLandscape ? [.large] : [.fraction(0.94)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $modeSelectionPresented) {
            CreationModeSelectionView(
                selectedMode: mode,
                onSelect: selectCreationMode,
                onOpenAlbum: openAlbum,
                onOpenColorRelationship: openColorRelationship,
                onScanTicket: openTicketScanner,
                onConvertVideo: openVideoToLivePhoto
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents(isTicketLandscape ? [.large] : [.fraction(0.84)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $ticketScannerPresented) {
            TicketQRScannerScreen(
                onCancel: { ticketScannerPresented = false }
            )
        }
        .fullScreenCover(isPresented: $albumPresented) {
            AlbumRootView()
                .background(Color.black.ignoresSafeArea())
                .presentationBackground(.black)
        }
        .fullScreenCover(isPresented: $colorRelationshipPresented) {
            ColorRelationshipFeatureView(
                onOpenModeSelection: returnFromColorRelationshipToModeSelection
            )
        }
        .fullScreenCover(isPresented: $videoToLivePhotoPresented) {
            VideoToLivePhotoScreen()
                .environment(\.colorScheme, systemColorScheme)
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
        .sheet(
            isPresented: $ticketMessageEditorPresented,
            onDismiss: {
                guard shouldExportAfterTicketMessageEditor else { return }
                shouldExportAfterTicketMessageEditor = false
                presentExportCenter()
            }
        ) {
            TicketMessageEditorSheet(
                message: ticketMessage,
                narrativeStyle: ticketNarrativeStyle,
                narrativePerspective: ticketNarrativePerspective
            ) { value in
                ticketMessage = value
                skippedTicketMessageForCurrentPhoto = false
                shouldExportAfterTicketMessageEditor = true
            }
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents(isTicketLandscape ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(34)
        }
        .sheet(isPresented: $exportCenterPresented) {
            ExportCenterView(
                format: Binding(
                    get: {
                        mode == .travelTicket ? .png : exportFormat
                    },
                    set: {
                        guard mode != .travelTicket else { return }
                        exportFormat = $0
                    }
                ),
                resolution: Binding(get: { exportResolution }, set: { exportResolution = $0 }),
                metadataPolicy: Binding(get: { exportMetadataPolicy }, set: { exportMetadataPolicy = $0 }),
                destination: Binding(get: { exportDestination }, set: { exportDestination = $0 }),
                sourcePixelWidth: images.first?.cgImage.map { CGFloat($0.width) } ?? 1080,
                supportsLiveExport: supportsLivePhotos
                    && mode != .privacyMosaic
                    && mode != .travelTicket
                    && !liveSourceVideoURLs.isEmpty,
                requiresTransparency: mode == .travelTicket,
                onExport: performConfiguredExport
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents(isTicketLandscape ? [.large] : [.fraction(0.94)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $ticketStudioPresented) {
            TicketCodeStudioView(
                codeStyle: Binding(
                    get: { ticketCodeStyle },
                    set: { ticketCodeStyle = $0 }
                ),
                showCopy: $ticketShowCopy,
                showDate: $ticketShowDate,
                showPlace: $ticketShowPlace,
                showDevice: $ticketShowDevice,
                showParameters: $ticketShowParameters,
                showPalette: $ticketShowPalette,
                deviceSealEnabled: $ticketDeviceSealEnabled,
                message: Binding(
                    get: { ticketMessage },
                    set: {
                        ticketMessage = String(
                            $0.prefix(TicketPayload.messageCharacterLimit)
                        )
                    }
                ),
                headerMode: Binding(
                    get: { ticketHeaderMode },
                    set: { ticketHeaderMode = $0 }
                ),
                customHeader: $ticketCustomHeader,
                cityNameStyle: Binding(
                    get: { ticketCityNameStyle },
                    set: { ticketCityNameStyle = $0 }
                ),
                narrativeStyle: Binding(
                    get: { ticketNarrativeStyle },
                    set: { ticketNarrativeStyle = $0 }
                ),
                narrativePerspective: Binding(
                    get: { ticketNarrativePerspective },
                    set: { ticketNarrativePerspective = $0 }
                ),
                detectedCityName: primaryMetadata.ticketCityName,
                payload: ticketPayload,
                baseURLString: TicketEnvelope.configuredBaseURLString,
                onSaveToPhotos: saveTicketCodeToPhotos,
                onSaveToFiles: saveTicketCodeToFiles,
                onShare: shareTicketCode
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents(isTicketLandscape ? [.large] : [.fraction(0.94)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.ultraThinMaterial)
        }
        .fullScreenCover(item: $verifiedTicket) { ticket in
            TicketVerificationView(
                ticket: ticket,
                onClose: { verifiedTicket = nil }
            )
        }
        .sheet(isPresented: $ticketVerificationErrorPresented) {
            TicketVerificationErrorView(message: ticketVerificationErrorMessage)
                .presentationDragIndicator(.visible)
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
        .alert(
            ticketMessagePromptTitle,
            isPresented: $ticketMessagePromptPresented
        ) {
            Button(LocalizedStringKey(ticketMessagePromptActionTitle)) {
                Task { @MainActor in
                    await Task.yield()
                    ticketMessageEditorPresented = true
                }
            }
            Button("直接导出") {
                skippedTicketMessageForCurrentPhoto = true
                Task { @MainActor in
                    await Task.yield()
                    presentExportCenter()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(ticketMessagePromptMessage))
        }
        .alert(errorTitle, isPresented: $saveErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(saveErrorMessage))
        })
        .sheet(isPresented: $ticketNarrativePromptPresented) {
            TicketNarrativePromptView(
                onSelect: { style, perspective in
                    ticketNarrativeStyle = style
                    ticketNarrativePerspective = perspective
                    dismissNarrativePrompt()
                },
                onDismiss: {
                    dismissNarrativePrompt()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(34)
        }

        return presentedContent
        .task {
            configureLaunchExperience()
            if didShowLivePhotoPlaybackHintBuild1060 {
                didShowLivePhotoPlaybackHint = true
            }
            PhotoAssetLoader.cleanupStaleTemporaryResources()
            importSharedPhotoIfAvailable()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            importSharedPhotoIfAvailable()
        }
        .onChange(of: canPresentModeSelectionHint) { _, canPresent in
            if canPresent {
                presentModeSelectionHintIfNeeded()
            }
        }
        .onChange(of: canPresentLivePhotoHint) { _, canPresent in
            if canPresent {
                presentLivePhotoHintIfNeeded()
            } else {
                dismissLivePhotoHint()
            }
        }
        .onChange(of: canPresentTicketLandscapeHint) { _, canPresent in
            if canPresent {
                presentTicketLandscapeHintIfNeeded()
            } else if mode != .travelTicket || isTicketLandscape {
                dismissTicketLandscapeHint()
            }
        }
        .onChange(of: canPresentNarrativePrompt) { _, canPresent in
            if canPresent {
                presentNarrativePromptIfNeeded()
            }
        }
        .onDisappear {
            stopLivePhotoPlayback()
            lightAnalysisTask?.cancel()
            dismissTicketPrintExperience()
            dismissModeSelectionHint(animated: false)
            dismissLivePhotoHint(animated: false)
            dismissTicketLandscapeHint(animated: false)
            if isTicketLandscape {
                setTicketLandscape(false)
            }
        }
        .onOpenURL(perform: handleIncomingURL)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        let queryItems = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems ?? []
        let isTicketURL = queryItems.contains { $0.name == TicketEnvelope.payloadKey }
            || queryItems.contains { $0.name == TicketEnvelope.checksumKey }
        if isTicketURL {
            do {
                verifiedTicket = try TicketEnvelope.decodeVerified(from: url)
            } catch {
                ticketVerificationErrorMessage = (error as? LocalizedError)?
                    .errorDescription
                    ?? "票根内容无法读取，请让发送者重新生成二维码。"
                ticketVerificationErrorPresented = true
            }
            return
        }
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
        TabView(selection: $introPageID) {
            ForEach(CreationMode.allCases) { item in
                modeIntro(item)
                    .tag(item.rawValue)
            }

            albumIntro
                .tag(Self.albumIntroID)

            colorRelationshipIntro
                .tag(Self.colorRelationshipIntroID)

            ticketScannerIntro
                .tag(Self.ticketScannerIntroID)

            videoToLivePhotoIntro
                .tag(Self.videoToLivePhotoIntroID)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: introPageID) { _, pageID in
            guard let selectedMode = CreationMode(rawValue: pageID),
                  selectedMode != mode else { return }
            mode = selectedMode
        }
    }

    private func modeIntro(_ item: CreationMode) -> some View {
        introPage(
            title: item.title,
            subtitle: item.introSubtitle,
            symbol: item.symbol,
            accent: item.accent,
            showsJournalBadge: item == .journal,
            actionSymbol: "plus",
            actionAccessibilityLabel: "为\(item.title)选择照片",
            isBusy: isLoading && item == mode,
            isActionDisabled: isLoading,
            showsImportStatus: true,
            action: { openPicker() }
        )
    }

    private var ticketScannerIntro: some View {
        introPage(
            title: "扫描验证票根",
            subtitle: "打开相机扫描影像票根上的验证二维码\n无需先添加照片",
            symbol: "qrcode.viewfinder",
            accent: Color(red: 0.67, green: 0.88, blue: 1.00),
            showsJournalBadge: false,
            actionSymbol: "qrcode.viewfinder",
            actionAccessibilityLabel: "扫描验证票根",
            actionAccessibilityHint: "打开相机扫描灵动照片票根二维码",
            isBusy: false,
            isActionDisabled: false,
            showsImportStatus: false,
            action: openTicketScanner
        )
    }

    private var videoToLivePhotoIntro: some View {
        introPage(
            title: "视频转实况",
            subtitle: "截取 3 秒相机视频并选择实况封面\n兼容视频优先保留原始动态画质",
            symbol: "video.fill",
            accent: Color(red: 0.72, green: 0.88, blue: 1.00),
            showsJournalBadge: false,
            showsVideoToLiveGlyph: true,
            actionSymbol: "arrow.up.right",
            actionAccessibilityLabel: "打开视频转实况",
            actionAccessibilityHint: "选择视频并生成实况照片",
            isBusy: false,
            isActionDisabled: false,
            showsImportStatus: false,
            action: openVideoToLivePhoto
        )
    }

    private var albumIntro: some View {
        introPage(
            title: "影像相簿",
            subtitle: "把照片与灵动作品装订成书\n横屏翻阅，并导出打印级 PDF",
            symbol: "book.pages",
            accent: Color(red: 0.73, green: 0.89, blue: 0.74),
            showsJournalBadge: false,
            actionSymbol: "book.closed",
            actionAccessibilityLabel: "打开影像相簿",
            actionAccessibilityHint: "创建、编辑、预览或打印多页影像相簿",
            isBusy: false,
            isActionDisabled: false,
            showsImportStatus: false,
            action: openAlbum
        )
    }

    private var colorRelationshipIntro: some View {
        introPage(
            title: "色彩关系",
            subtitle: "选择两张照片\n看看它们如何共鸣、对照与过渡",
            symbol: "point.3.connected.trianglepath.dotted",
            accent: Color(red: 0.74, green: 0.86, blue: 0.98),
            showsJournalBadge: false,
            actionSymbol: "arrow.up.right",
            actionAccessibilityLabel: "打开色彩关系",
            actionAccessibilityHint: "选择两张照片并分析它们的色彩关系",
            isBusy: false,
            isActionDisabled: false,
            showsImportStatus: false,
            action: openColorRelationship
        )
    }

    private func introPage(
        title: String,
        subtitle: String,
        symbol: String,
        accent: Color,
        showsJournalBadge: Bool,
        showsVideoToLiveGlyph: Bool = false,
        actionSymbol: String,
        actionAccessibilityLabel: String,
        actionAccessibilityHint: String? = nil,
        isBusy: Bool,
        isActionDisabled: Bool,
        showsImportStatus: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                if showsVideoToLiveGlyph {
                    VideoToLivePhotoGlyph(color: accent.opacity(0.94))
                        .scaleEffect(1.4)
                        .frame(width: 98, height: 98)
                } else {
                    ModeGlyph(symbol: symbol, accent: accent)
                }
            }
            .id(symbol)
            .padding(.bottom, 55)

            HStack(spacing: 7) {
                Text(LocalizedStringKey(title))
                    .font(.custom("Songti SC", size: 24).weight(.medium))
                if showsJournalBadge {
                    Circle()
                        .fill(.pink)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
            }
            .foregroundStyle(.white.opacity(0.94))

            Text(LocalizedStringKey(subtitle))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.32))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 300)
                .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(introPageIDs, id: \.self) { pageID in
                    Circle()
                        .fill(pageID == introPageID ? .white : .white.opacity(0.25))
                        .frame(
                            width: pageID == introPageID ? 6 : 5,
                            height: pageID == introPageID ? 6 : 5
                        )
                }
            }
            .padding(.top, 19)

            Button(action: action) {
                ZStack {
                    if isBusy {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.white.opacity(0.88))
                    } else {
                        Image(systemName: actionSymbol)
                            .font(.system(size: 32, weight: .light))
                    }
                }
                .frame(width: 112, height: 112)
                .contentShape(Circle())
            }
            .buttonStyle(LiquidPressButtonStyle())
            .foregroundStyle(.white.opacity(0.92))
            .liquidGlass(in: Circle(), interactive: true, variant: .clear)
            .disabled(isActionDisabled)
            .padding(.top, 31)
            .accessibilityLabel(actionAccessibilityLabel)
            .accessibilityHint(actionAccessibilityHint ?? "")

            if showsImportStatus && isBusy && !importStatus.isEmpty {
                Text(LocalizedStringKey(importStatus))
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

    private var introPageIDs: [String] {
        CreationMode.allCases.map(\.rawValue) + [
            Self.albumIntroID,
            Self.colorRelationshipIntroID,
            Self.ticketScannerIntroID,
            Self.videoToLivePhotoIntroID
        ]
    }

    private func editorView(in size: CGSize) -> AnyView {
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
        } else if mode == .travelTicket {
            let editorReserve: CGFloat = size.height < 760 ? 250 : 215
            canvasWidth = min(availableWidth, max(280, size.height - editorReserve) * ratioValue)
        } else if mode == .motionCard && templateStyle != .immersive {
            // Leave room for the editor-only local color sampling controls below the artwork.
            let editorReserve: CGFloat = size.height < 760 ? 205 : 175
            canvasWidth = min(availableWidth, max(300, size.height - editorReserve) * ratioValue)
        } else if mode == .colorPalette {
            let editorReserve: CGFloat = colorInsightPage == .light
                ? (size.height < 760 ? 470 : 430)
                : 195
            canvasWidth = min(availableWidth, max(248, size.height - editorReserve) * ratioValue)
        } else {
            // Extra-tall ratios must remain fully reachable on compact iPhones.
            canvasWidth = min(availableWidth, max(320, size.height - 130) * ratioValue)
        }
        let canvasHeight = canvasWidth / ratioValue

        let content = VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("灵动照片")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.50)
                    .opacity(showAppTitle ? 1 : 0)
                    .accessibilityHidden(!showAppTitle)

                Spacer()

                LiquidCircleButton(
                    symbol: "square.grid.2x2",
                    isEnabled: !controlsAreDimmed,
                    action: openModeSelection
                )
                .overlay(alignment: .top) {
                    if isModeSelectionHintPresented {
                        ModeSelectionHint(
                            tint: livePhotoHintTint,
                            foreground: livePhotoHintForeground,
                            action: openModeSelection
                        )
                        .offset(y: 49)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.72, anchor: .top)
                                    .combined(with: .opacity)
                                    .combined(with: .move(edge: .top)),
                                removal: .scale(scale: 0.80, anchor: .top)
                                    .combined(with: .opacity)
                            )
                        )
                    }
                }
                .zIndex(50)

                if mode == .travelTicket {
                    LiquidCircleButton(
                        symbol: "rectangle.landscape.rotate",
                        isEnabled: !controlsAreDimmed,
                        action: enterTicketLandscape
                    )
                    .overlay(alignment: .top) {
                        if isTicketLandscapeHintPresented {
                            TicketLandscapeHint(
                                tint: livePhotoHintTint,
                                foreground: livePhotoHintForeground,
                                action: enterTicketLandscape
                            )
                            .offset(y: 49)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.72, anchor: .top)
                                        .combined(with: .opacity)
                                        .combined(with: .move(edge: .top)),
                                    removal: .scale(scale: 0.80, anchor: .top)
                                        .combined(with: .opacity)
                                )
                            )
                        }
                    }
                    .zIndex(49)
                    .accessibilityLabel("翻转为横屏票根预览")
                }

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
                    isEnabled: canSaveCurrentArtwork,
                    isBusy: saveState == .saving,
                    action: saveArtwork
                )
                .opacity(canSaveCurrentArtwork || saveState != .idle ? 1 : 0)

                LiquidCircleButton(
                    symbol: "gearshape",
                    isEnabled: !controlsAreDimmed
                ) {
                    dismissModeSelectionHint()
                    dismissLivePhotoHint()
                    settingsPresented = true
                }
            }
            .animation(.easeInOut(duration: 0.22), value: controlsAreDimmed)
            .animation(.easeInOut(duration: 0.20), value: canSaveCurrentArtwork)
            .animation(.easeInOut(duration: 0.18), value: showAppTitle)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .zIndex(40)

            if mode == .colorPalette {
                ColorInsightSwitcher(
                    selection: $colorInsightPage,
                    reduceMotion: reduceMotion
                )
                .padding(.top, 10)
                .zIndex(25)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

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

            if mode == .travelTicket {
                Spacer(minLength: 24)
            }

            artworkPreview(width: canvasWidth, height: canvasHeight)
            .padding(.top, mode == .travelTicket
                ? 0
                : (mode == .colorPalette ? 10 : (showsLivePlaybackControl ? 8 : 20)))

            if mode == .colorPalette, colorInsightPage == .light {
                Group {
                    if let lightAnalysis {
                        LightAnalysisPanel(
                            analysis: lightAnalysis,
                            semantic: combinedSemantic,
                            activeRange: $activeLightToneRange
                        )
                    } else {
                        LightAnalysisLoadingPanel()
                    }
                }
                .frame(width: min(canvasWidth, size.width - 36))
                .padding(.top, 10)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                )
            }

            if mode == .motionCard, templateStyle != .immersive {
                motionCardSamplingControls
                    .frame(width: canvasWidth)
                    .padding(.top, 12)
            }

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

            if mode == .sketch {
                ScrollView(.vertical) {
                    SketchEditorControls(
                        parameters: $sketchParameters,
                        isRendering: isSketchRendering,
                        onStyleChange: { style in
                            sketchParameters = style.defaultParameters
                        }
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .frame(height: size.height < 760 ? 190 : 230)
                .scrollIndicators(.visible)
                .scrollBounceBehavior(.basedOnSize)
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

            if mode == .travelTicket {
                TicketEditorControls(
                    layout: Binding(
                        get: { ticketLayout },
                        set: { ticketLayout = $0 }
                    ),
                    codeStyle: Binding(
                        get: { ticketCodeStyle },
                        set: { ticketCodeStyle = $0 }
                    ),
                    widthMode: Binding(
                        get: { ticketCanvasWidthMode },
                        set: { ticketCanvasWidthMode = $0 }
                    ),
                    onOpenStudio: openTicketStudio
                )
                .padding(.horizontal, 18)
                .padding(.top, 12)

                if !isTicketLandscape {
                    motionCardSamplingControls
                        .frame(width: canvasWidth)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                }
            }

            Spacer(minLength: mode == .travelTicket
                ? 24
                : (mode == .privacyMosaic ? 8 : 18))
        }
        .safeAreaPadding(.top)
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.42, extraBounce: 0.04),
            value: colorInsightPage
        )

        if mode == .colorPalette, colorInsightPage == .light {
            return AnyView(
                ScrollView(.vertical) {
                    content
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
            )
        }
        return AnyView(content)
    }

    private var motionCardSamplingControls: some View {
        HStack(spacing: 10) {
            Button {
                motionCardColorSamplerPresented = true
            } label: {
                Label(
                    motionCardSamplingRect == nil ? "局部取色" : "调整取色范围",
                    systemImage: "viewfinder"
                )
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
            }
            .buttonStyle(LiquidPressButtonStyle())
            .foregroundStyle(.primary.opacity(0.82))
            .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
            .accessibilityHint(mode == .travelTicket
                ? "选择照片中的区域，只改变影像票根背景的取色"
                : "选择照片中的区域，只改变灵动卡片顶部背景的取色")

            if motionCardSamplingRect != nil {
                Button(action: resetMotionCardSampling) {
                    Label("恢复整图", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 15)
                        .frame(height: 42)
                }
                .buttonStyle(LiquidPressButtonStyle())
                .foregroundStyle(.primary.opacity(0.72))
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
            }
        }
        .animation(.snappy, value: motionCardSamplingRect != nil)
    }

    private func resetMotionCardSampling() {
        withAnimation(.easeInOut(duration: 0.22)) {
            motionCardSamplingRect = nil
            motionCardLocalPalette = nil
            motionCardLocalPercentages = nil
        }
    }

    private func legacyTicketLandscapeEditorView(in size: CGSize) -> AnyView {
        let landscapeSize = CGSize(
            width: max(size.width, size.height),
            height: min(size.width, size.height)
        )
        return AnyView(
            ticketLandscapeEditorView(in: landscapeSize)
                .frame(width: landscapeSize.width, height: landscapeSize.height)
                .rotationEffect(.degrees(90))
                .frame(width: size.width, height: size.height)
                .clipped()
        )
    }

    private func ticketLandscapeEditorView(in size: CGSize) -> AnyView {
        let ratioValue = editorRatio(in: size)
        let controlsWidth = min(270, max(220, size.width * 0.27))
        let previewAreaWidth = max(360, size.width - controlsWidth - 62)
        let previewAreaHeight = max(190, size.height - 82)
        let canvasWidth = min(previewAreaWidth, previewAreaHeight * ratioValue)
        let canvasHeight = canvasWidth / ratioValue

        return AnyView(VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: exitTicketLandscape) {
                    Label("返回竖屏", systemImage: "rectangle.portrait.rotate")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 13)
                        .frame(height: 42)
                }
                .buttonStyle(LiquidPressButtonStyle())
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                .accessibilityLabel("返回竖屏预览")

                VStack(alignment: .leading, spacing: 1) {
                    Text("影像票根")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("手动横屏预览")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                LiquidCircleButton(
                    symbol: "square.grid.2x2",
                    isEnabled: !controlsAreDimmed,
                    action: openModeSelection
                )

                LiquidCircleButton(
                    symbol: "plus",
                    isEnabled: !controlsAreDimmed,
                    action: { openPicker(append: false) }
                )

                LiquidCircleButton(
                    symbol: saveState == .success ? "checkmark" : "arrow.down",
                    isEnabled: canSaveCurrentArtwork,
                    isBusy: saveState == .saving,
                    action: saveArtwork
                )

                LiquidCircleButton(
                    symbol: "gearshape",
                    isEnabled: !controlsAreDimmed,
                    action: { settingsPresented = true }
                )
            }
            .frame(height: 48)

            HStack(spacing: 14) {
                artworkPreview(width: canvasWidth, height: canvasHeight)
                    .frame(
                        maxWidth: previewAreaWidth,
                        maxHeight: previewAreaHeight,
                        alignment: .center
                    )

                TicketEditorControls(
                    layout: Binding(
                        get: { ticketLayout },
                        set: { ticketLayout = $0 }
                    ),
                    codeStyle: Binding(
                        get: { ticketCodeStyle },
                        set: { ticketCodeStyle = $0 }
                    ),
                    widthMode: Binding(
                        get: { ticketCanvasWidthMode },
                        set: { ticketCanvasWidthMode = $0 }
                    ),
                    isLandscape: true,
                    onOpenStudio: openTicketStudio
                )
                .frame(width: controlsWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .safeAreaPadding(.horizontal)
        )
    }

    private func artworkPreview(width: CGFloat, height: CGFloat) -> AnyView {
        AnyView(ArtworkCanvas(
            mode: mode,
            images: displayedImages,
            palette: palette,
            palettePercentages: palettePercentages,
            ratio: ratio,
            showHexValues: showHexValues,
            showPalettePercentages: showPalettePercentages,
            showDeviceInfo: showDeviceInfo,
            showBubbles: showBubbles,
            cameraWatermarkImage: activeCameraWatermark,
            gentleBackground: gentleBackground,
            imageScale: imageScale,
            imageOffset: imageOffset,
            metadata: primaryMetadata,
            showMissingCaptureTime: showMissingCaptureTime,
            copy: artworkCopy,
            fontStyle: fontStyle,
            templateStyle: templateStyle,
            motionCardHeaderStyle: motionCardHeaderStyle,
            motionCardHeaderPalette: effectiveMotionCardPalette,
            motionCardHeaderPercentages: effectiveMotionCardPercentages,
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
            selectedJournalIndex: selectedJournalIndex,
            ticketPayload: ticketPayload,
            ticketCodeStyle: ticketCodeStyle,
            ticketLayout: ticketLayout,
            ticketAppClipBaseURL: TicketEnvelope.configuredBaseURLString,
            ticketDeviceSealEnabled: ticketDeviceSealEnabled,
            sketchImage: mode == .sketch ? sketchImage : nil,
            showsColorPaletteOverlay: colorInsightPage == .palette,
            lightToneOverlay: mode == .colorPalette && colorInsightPage == .light
                ? lightAnalysis?.overlay(for: activeLightToneRange)
                : nil
        )
        .frame(width: width, height: height)
        .scaleEffect(canvasRevealed ? 1 : 0.78)
        .opacity(canvasRevealed ? 1 : 0.18)
        .shadow(
            color: .black.opacity(
                mode == .travelTicket || !canvasRevealed ? 0 : 0.12
            ),
            radius: 22,
            y: 12
        )
        .contentShape(RoundedRectangle(
            cornerRadius: mode == .travelTicket ? 0 : 26,
            style: .continuous
        ))
        .gesture(activeCanvasGesture(canvasSize: CGSize(width: width, height: height)))
        .accessibilityLabel(
            mode == .privacyMosaic && isPrivacyPainting
                ? String(
                    format: "隐私马赛克预览，单指：%@".appLocalized,
                    privacyBrushMode.rawValue.appLocalized
                )
                : (mode == .sketch
                    ? "\(mode.title)预览，按照片实际比例预览"
                    : (mode == .colorPalette && colorInsightPage == .light
                        ? "光影解析预览，按照片实际比例完整显示"
                        : "\(mode.title)预览，可拖拽或双指缩放"))
        )
        .accessibilityAction(named: "编辑作品文字") {
            if mode == .motionCard
                || mode == .bubbleStamp
                || mode == .journal
                || mode == .travelTicket {
                editCopyPresented = true
            }
        }
        .accessibilityAction(named: "恢复默认构图") { resetComposition() }
        )
    }

    private func activeCanvasGesture(canvasSize: CGSize) -> AnyGesture<Void> {
        if mode == .privacyMosaic && isPrivacyPainting {
            return AnyGesture(privacyPaintGesture(canvasSize: canvasSize).map { _ in () })
        }

        if mode == .privacyMosaic {
            return AnyGesture(compositionGesture(canvasSize: canvasSize).map { _ in () })
        }

        if mode == .sketch {
            // Sketch is aspect-fit at the photo's native ratio — the preview
            // already matches the actual image, so pan/zoom is disabled.
            return AnyGesture(DragGesture(minimumDistance: 100_000).map { _ in () })
        }

        if mode == .colorPalette, colorInsightPage == .light {
            // The light-analysis page deliberately shows the complete source;
            // disabling composition gestures prevents an old zoom/offset from
            // making the preview appear cropped again.
            return AnyGesture(DragGesture(minimumDistance: 100_000).map { _ in () })
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
        case .travelTicket:
            return .image
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
        case .travelTicket:
            switch ticketLayout {
            case .classic:
                shouldEdit = point.x < canvasSize.width * 0.44
            case .vertical:
                shouldEdit = point.y > canvasSize.height * 0.50
            case .minimal:
                shouldEdit = point.y > canvasSize.height * 0.58
            }
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
            Text(LocalizedStringKey(text))
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
                String(
                    format: "发现 %lld 处隐私内容，点击马赛克区域可取消".appLocalized,
                    Int64(detected.count)
                ),
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

    private func scheduleSketchPreviewRefresh() {
        sketchRenderTask?.cancel()
        sketchRenderRevision += 1
        let revision = sketchRenderRevision
        renderedSketchParameters = nil
        guard let snapshot = images.first else {
            sketchImage = nil
            isSketchRendering = false
            sketchRenderTask = nil
            return
        }
        let parameters = sketchParameters
        isSketchRendering = true
        sketchRenderTask = Task {
            try? await Task.sleep(for: .milliseconds(110))
            guard !Task.isCancelled, revision == sketchRenderRevision else { return }
            let rendered = await Task.detached(priority: .userInitiated) {
                SketchFilterEngine.render(snapshot, parameters: parameters)
            }.value
            guard !Task.isCancelled, revision == sketchRenderRevision else { return }
            sketchImage = rendered
            renderedSketchParameters = rendered == nil ? nil : parameters
            isSketchRendering = false
            sketchRenderTask = nil
        }
    }

    private func openPicker(append: Bool = false, replacing index: Int? = nil) {
        guard !isLoading, saveState == .idle else { return }
        stopLivePhotoPlayback()
        dismissModeSelectionHint()
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
            importStatus = "正在读取照片与拍摄信息…".appLocalized
        }

        var imported: [SelectedPhoto] = []
        var firstImportError: Error?
        for (index, selection) in pickerSelections.prefix(pickerLimit).enumerated() {
            importStatus = String(
                format: "正在识别第 %lld 张，共 %lld 张的画面内容…".appLocalized,
                locale: .current,
                Int64(index + 1),
                Int64(min(pickerSelections.count, pickerLimit))
            )
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
            motionCardSamplingRect = nil
            motionCardLocalPalette = nil
            motionCardLocalPercentages = nil
            ticketMessage = ""
            ticketSealedAtText = TicketTimeCalculator.nowFormatted()
            skippedTicketMessageForCurrentPhoto = false
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
        importStatus = "正在分析整张照片的感知色彩…".appLocalized
        let paletteResult = combinedPaletteResult(from: combined.map(\.image))
        selectedPhotos = combined
        images = combined.map(\.image)
        scheduleLightAnalysis(for: combined.first?.image)
        if operation == .replaceAll {
            resetPrivacyEdits(for: images.first)
            if mode == .sketch {
                sketchImage = nil
                scheduleSketchPreviewRefresh()
            }
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

    private func scheduleLightAnalysis(for image: UIImage?) {
        lightAnalysisTask?.cancel()
        lightAnalysis = nil
        activeLightToneRange = nil
        guard let image else { return }
        lightAnalysisTask = Task {
            let result = await PhotoLightAnalyzer.analyze(image)
            guard !Task.isCancelled else { return }
            lightAnalysis = result
            lightAnalysisTask = nil
        }
    }

    private func editorRatio(in screenSize: CGSize) -> CGFloat {
        if mode == .spectrumWallpaper {
            let bounds = UIScreen.main.bounds
            return min(max(bounds.width / bounds.height, 0.43), 0.50)
        }
        if mode == .colorPalette,
           colorInsightPage == .light,
           let image = images.first,
           image.size.height > 0 {
            // Light analysis is about reading the whole photograph. Match the
            // preview canvas to the source image so a landscape photo can use
            // the full available width without being cropped into the artwork
            // ratio selected for the palette/export view.
            return min(max(image.size.width / image.size.height, 0.25), 6.00)
        }
        if mode == .privacyMosaic, let image = images.first, image.size.height > 0 {
            return min(max(image.size.width / image.size.height, 0.35), 2.40)
        }
        if mode == .sketch, let image = images.first, image.size.height > 0 {
            return min(max(image.size.width / image.size.height, 0.35), 2.40)
        }
        return ratio.value(for: images.first)
    }

    private func selectCreationMode(_ selectedMode: CreationMode) {
        guard mode != selectedMode else {
            modeSelectionPresented = false
            return
        }

        modeSelectionPresented = false
        withAnimation(.snappy) {
            mode = selectedMode
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            finishModeChange()
        }
    }

    private func openTicketScanner() {
        modeSelectionPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            ticketScannerPresented = true
        }
    }

    private func openVideoToLivePhoto() {
        modeSelectionPresented = false
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        dismissTicketLandscapeHint()
        if isTicketLandscape {
            setTicketLandscape(false)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            videoToLivePhotoPresented = true
        }
    }

    private func openAlbum() {
        modeSelectionPresented = false
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        dismissTicketLandscapeHint()
        if isTicketLandscape {
            setTicketLandscape(false)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            albumPresented = true
        }
    }

    private func openColorRelationship() {
        modeSelectionPresented = false
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        dismissTicketLandscapeHint()
        if isTicketLandscape {
            setTicketLandscape(false)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            colorRelationshipPresented = true
        }
    }

    private func returnFromColorRelationshipToModeSelection() {
        colorRelationshipPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            modeSelectionPresented = true
        }
    }

    private func finishModeChange() {
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
        if mode == .sketch {
            scheduleSketchPreviewRefresh()
        }
        startRevealSequence()
        presentLivePhotoHintIfNeeded()
        if mode == .privacyMosaic, selectedPhotos.contains(where: \.isLivePhoto) {
            showToast("隐私遮挡后仅支持静态导出，避免动态帧泄露隐私", duration: 3.6)
        } else if mode == .travelTicket, selectedPhotos.contains(where: \.isLivePhoto) {
            showToast("影像票根使用实况照片的关键帧生成静态凭证", duration: 3.0)
        } else if mode == .sketch, selectedPhotos.contains(where: \.isLivePhoto) {
            showToast("素描基于实况照片的关键帧生成静态作品", duration: 3.0)
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
        guard mode != .sketch || hasCurrentSketchRender else {
            showToast("正在生成当前素描效果，请稍候…", duration: 2.2)
            return
        }
        dismissModeSelectionHint()
        if mode == .travelTicket,
           TicketPayload.normalizedMessage(ticketMessage) == nil,
           !skippedTicketMessageForCurrentPhoto {
            ticketMessagePromptPresented = true
            return
        }
        presentExportCenter()
    }

    private func validateTicketCodeForExport() -> Bool {
        guard ticketCodeStyle == .verificationQR else { return true }
        do {
            _ = try TicketEnvelope.invocationURL(
                for: ticketPayload,
                baseURLString: TicketEnvelope.configuredBaseURLString,
                signer: ticketEnvelopeSigner
            )
            return true
        } catch {
            presentSaveError(
                error.localizedDescription,
                title: "无法生成验证二维码"
            )
            return false
        }
    }

    private func presentExportCenter() {
        if mode == .travelTicket,
           ticketCodeStyle == .verificationQR,
           #unavailable(iOS 18.0) {
            Task {
                guard await validateTicketCodeForIOS17Export() else { return }
                presentExportCenterAfterTicketValidation()
            }
            return
        }
        if mode == .travelTicket, !validateTicketCodeForExport() { return }
        presentExportCenterAfterTicketValidation()
    }

    private func presentExportCenterAfterTicketValidation() {
        if mode == .privacyMosaic {
            finishPrivacyPainting()
            if exportMetadataPolicy == .preserve {
                exportMetadataPolicy = .removeLocation
            }
        }
        exportCenterPresented = true
    }

    private func validateTicketCodeForIOS17Export() async -> Bool {
        let payload = ticketPayload
        let baseURLString = TicketEnvelope.configuredBaseURLString
        let deviceSealEnabled = ticketDeviceSealEnabled
        let result = await Task.detached(priority: .userInitiated) {
            () -> Result<Void, Error> in
            do {
                _ = try TicketEnvelope.invocationURL(
                    for: payload,
                    baseURLString: baseURLString,
                    signer: deviceSealEnabled ? TicketDeviceSealService.shared : nil
                )
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value
        switch result {
        case .success:
            return true
        case let .failure(error):
            presentSaveError(
                error.localizedDescription,
                title: "无法生成验证二维码"
            )
            return false
        }
    }

    private func performConfiguredExport() {
        if mode == .travelTicket, exportDestination == .photoLibrary {
            let needsPortraitTransition = isTicketLandscape
            if needsPortraitTransition {
                setTicketLandscape(false)
            }
            Task { @MainActor in
                if needsPortraitTransition {
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(220))
                }
                do {
                    try await ArtworkExporter.preparePhotoLibraryAccess()
                } catch {
                    presentSaveError(error.localizedDescription)
                    return
                }
                performSaveArtwork(
                    format: .png,
                    resolution: exportResolution,
                    metadataPolicy: exportMetadataPolicy,
                    destination: .photoLibrary,
                    presentsTicketPrinter: true
                )
            }
            return
        }

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
        destination: ArtworkExportDestination,
        presentsTicketPrinter: Bool = false
    ) {
        guard canSave, saveState == .idle else { return }
        guard mode != .sketch || hasCurrentSketchRender else {
            exportCenterPresented = false
            showToast("正在生成当前素描效果，请稍候…", duration: 2.2)
            return
        }
        let effectiveFormat: ArtworkExportFormat = mode == .travelTicket
            ? .png
            : format
        let ticketLayoutAtExport = ticketLayout
        let validatesTicketAlpha = mode == .travelTicket
        stopLivePhotoPlayback()
        dismissLivePhotoHint()
        withAnimation(.easeOut(duration: 0.16)) { saveState = .saving }
        if presentsTicketPrinter {
            beginTicketPrintExperience()
        } else {
            showToast(
                mode == .privacyMosaic ? "正在渲染隐私静态作品…" : "正在渲染高清作品…",
                duration: 30
            )
        }

        Task {
            if presentsTicketPrinter {
                _ = await TicketPrintLiveActivityController.shared.start(
                    title: TicketPayload.normalizedMessage(ticketPayload.title) ?? "影像票根"
                )
            }
            let sourceWidth = images.first?.cgImage.map { CGFloat($0.width) } ?? 1080
            let pixelWidth = resolution.pixelWidth(sourceWidth: sourceWidth)
            let exportSketchImage: UIImage?
            if mode == .sketch {
                guard let sourceImage = images.first else {
                    saveState = .idle
                    presentSaveError("未找到可用于高清素描的原图。")
                    return
                }
                let parameters = sketchParameters
                let targetLongEdge = sketchExportLongEdge(
                    for: sourceImage,
                    pixelWidth: pixelWidth
                )
                showToast("正在进行高清分块推理…", duration: 60)
                exportSketchImage = await Task.detached(priority: .userInitiated) {
                    SketchFilterEngine.renderForExport(
                        sourceImage,
                        parameters: parameters,
                        targetLongEdge: targetLongEdge
                    )
                }.value
                guard exportSketchImage != nil else {
                    saveState = .idle
                    presentSaveError("高清素描渲染失败，请稍后重试。")
                    return
                }
            } else {
                exportSketchImage = nil
            }
            let ticketCodeImageOverride = await ios17TicketCodeImageForArtwork()
            if mode == .travelTicket,
               usesInAppTicketLandscape,
               ticketCodeImageOverride == nil {
                if presentsTicketPrinter {
                    await failTicketPrintExperience("票根编码生成失败，请稍后重试。")
                } else {
                    saveState = .idle
                    presentSaveError("票根编码生成失败，请稍后重试。")
                }
                return
            }
            guard let renderedImage = renderArtwork(
                pixelWidth: pixelWidth,
                sketchImageOverride: exportSketchImage,
                ticketCodeImageOverride: ticketCodeImageOverride
            ) else {
                if presentsTicketPrinter {
                    await failTicketPrintExperience("作品渲染失败，请稍后重试。")
                } else {
                    saveState = .idle
                    presentSaveError("作品渲染失败，请稍后重试。")
                }
                return
            }

            let image = renderedImage
            if presentsTicketPrinter {
                let displayImage = TicketPrintImage.rotatedClockwise(renderedImage)
                    ?? renderedImage
                await startTicketFeed(with: displayImage)
            }

            do {
                let metadata = selectedPhotos.first?.metadata ?? .empty
                let originalData = selectedPhotos.first?.originalData
                let pairedVideoURLs: [Int: URL] = supportsLivePhotos
                    && mode != .privacyMosaic
                    && mode != .travelTicket
                    && destination == .photoLibrary
                    ? liveSourceVideoURLs
                    : [:]
                let hasMissingLiveResource = supportsLivePhotos
                    && mode != .privacyMosaic
                    && mode != .travelTicket
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
                        renderFrame: { frames, videoPixelWidth in
                            renderArtwork(
                                replacingImages: frames,
                                pixelWidth: videoPixelWidth,
                                sketchImageOverride: exportSketchImage,
                                ticketCodeImageOverride: ticketCodeImageOverride
                            )
                        },
                        progress: { progress in
                            toastMessage = String(
                                format: "正在生成 Live Photo… %lld%%".appLocalized,
                                locale: .current,
                                Int64((progress * 100).rounded())
                            )
                        }
                    )
                } else if destination == .photoLibrary {
                    if !presentsTicketPrinter {
                        showToast(
                            metadataPolicy == .preserve
                                ? "正在写入相册并保留拍摄信息…"
                                : "正在写入相册并清理敏感元数据…",
                            duration: 30
                        )
                    } else {
                        await markTicketWritingToPhotos()
                    }
                    try await ArtworkExporter.saveStill(
                        image,
                        metadata: metadata,
                        originalImageData: originalData,
                        format: effectiveFormat,
                        metadataPolicy: metadataPolicy,
                        encodedDataValidator: validatesTicketAlpha
                            ? {
                                TicketArtworkAlphaMask.hasExpectedTransparency(
                                    pngData: $0,
                                    layout: ticketLayoutAtExport
                                )
                            }
                            : nil
                    )
                } else {
                    showToast("正在编码 \(effectiveFormat.rawValue) 静态作品…", duration: 30)
                    let data = try await Task.detached(priority: .userInitiated) {
                        try ArtworkExporter.encodedStillData(
                            image,
                            metadata: metadata,
                            originalImageData: originalData,
                            format: effectiveFormat,
                            metadataPolicy: metadataPolicy
                        )
                    }.value
                    if validatesTicketAlpha,
                       !TicketArtworkAlphaMask.hasExpectedTransparency(
                            pngData: data,
                            layout: ticketLayoutAtExport
                       ) {
                        throw ArtworkExportError.transparencyValidationFailed
                    }
                    let url = try ExportTemporaryFile.make(
                        data: data,
                        format: effectiveFormat
                    )
                    let item = ExportedArtworkFile(url: url)
                    if destination == .files {
                        documentExportFile = item
                    } else {
                        sharedExportFile = item
                    }
                }
                // Archiving re-encodes the artwork twice and writes to disk; it
                // must never delay the save confirmation on the main actor.
                let archiveMode = mode
                Task.detached(priority: .utility) {
                    LingdongWorkArchive.record(image: image, mode: archiveMode)
                }
                toastTask?.cancel()
                withAnimation(.easeOut(duration: 0.2)) { toastMessage = nil }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    saveState = .success
                }
                if presentsTicketPrinter {
                    await completeTicketPrintExperience()
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(for: .milliseconds(1_250))
                if presentsTicketPrinter {
                    await TicketPrintLiveActivityController.shared.end(
                        phase: .completed,
                        progress: 1
                    )
                    dismissTicketPrintExperience(endsLiveActivity: false)
                }
                withAnimation(.easeInOut(duration: 0.24)) {
                    saveState = .idle
                }
            } catch {
                if presentsTicketPrinter {
                    await failTicketPrintExperience(error.localizedDescription)
                } else {
                    saveState = .idle
                    presentSaveError(error.localizedDescription)
                }
            }
        }
    }

    private func beginTicketPrintExperience() {
        ticketPrintHapticTask?.cancel()
        ticketPrintImage = nil
        ticketPrintProgress = 0
        ticketPrintAnimationDeadline = nil
        ticketPrintPhase = .preparing
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred(intensity: 0.82)
    }

    private func startTicketFeed(with image: UIImage) async {
        ticketPrintImage = image
        ticketPrintPhase = .feeding
        await TicketPrintLiveActivityController.shared.update(
            phase: .printing,
            progress: 0.58
        )
        let openingDelay = reduceMotion ? 0.04 : 0.24
        let duration = reduceMotion ? 0.18 : 2.2
        try? await Task.sleep(for: .seconds(openingDelay))
        ticketPrintAnimationDeadline = Date.now.addingTimeInterval(duration)
        withAnimation(.linear(duration: duration)) {
            ticketPrintProgress = 1
        }
        await Task.yield()

        ticketPrintHapticTask?.cancel()
        ticketPrintHapticTask = Task { @MainActor in
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            for index in 0..<13 {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                impact.impactOccurred(intensity: index.isMultiple(of: 3) ? 0.54 : 0.34)
                impact.prepare()
            }
        }
    }

    private func markTicketWritingToPhotos() async {
        ticketPrintPhase = .finishing
        await TicketPrintLiveActivityController.shared.update(
            phase: .saving,
            progress: 0.92
        )
    }

    private func completeTicketPrintExperience() async {
        ticketPrintHapticTask?.cancel()
        if let deadline = ticketPrintAnimationDeadline {
            let remaining = deadline.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
        }
        ticketPrintAnimationDeadline = nil
        await TicketPrintLiveActivityController.shared.update(
            phase: .completed,
            progress: 1
        )
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(response: 0.36, dampingFraction: 0.78)
        ) {
            ticketPrintPhase = .success
            ticketPrintProgress = 1
        }
    }

    private func failTicketPrintExperience(_ message: String) async {
        ticketPrintHapticTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            ticketPrintPhase = .failed
        }
        await TicketPrintLiveActivityController.shared.update(
            phase: .failed,
            progress: Double(ticketPrintProgress)
        )
        try? await Task.sleep(for: .milliseconds(420))
        await TicketPrintLiveActivityController.shared.end(
            phase: .failed,
            progress: Double(ticketPrintProgress)
        )
        dismissTicketPrintExperience(endsLiveActivity: false)
        saveState = .idle
        presentSaveError(message)
    }

    private func dismissTicketPrintExperience(endsLiveActivity: Bool = true) {
        ticketPrintHapticTask?.cancel()
        ticketPrintHapticTask = nil
        if endsLiveActivity {
            Task {
                await TicketPrintLiveActivityController.shared.cancel()
            }
        }
        ticketPrintPhase = .idle
        ticketPrintImage = nil
        ticketPrintProgress = 0
        ticketPrintAnimationDeadline = nil
    }

    private var shouldPresentVersion210Update: Bool {
        version210AudienceRaw == Version210Audience.upgradedFromPreviousVersion.rawValue
            && !didShowVersion210Update
    }

    private func configureLaunchExperience() {
        if version210AudienceRaw.isEmpty {
            version210AudienceRaw = hasPreviousVersionInstallEvidence()
                ? Version210Audience.upgradedFromPreviousVersion.rawValue
                : Version210Audience.installed210.rawValue
        }

        if !didShowPublicGoodsCommitment {
            publicGoodsCommitmentPresented = true
        } else if shouldPresentVersion210Update {
            version210UpdatePresented = true
        }
    }

    private func hasPreviousVersionInstallEvidence() -> Bool {
        let defaults = UserDefaults.standard
        let legacyKeys = [
            "didAcknowledgeFreeNotice",
            "supportsLivePhotos",
            "useLiteraryColorNames",
            "preservePaletteBackground",
            "showMoodCopy",
            "paletteLayout",
            "showAppTitle",
            "didShowLivePhotoPlaybackHint",
            "didShowLivePhotoPlaybackHintBuild1060",
            "version101Audience",
            "didShowVersion101Update",
            "version102Audience",
            "didShowVersion102Update",
            "version200Audience",
            "didShowVersion200Update"
        ]
        if legacyKeys.contains(where: { defaults.object(forKey: $0) != nil }) {
            return true
        }

        // App data containers survive an update, while the installed app bundle
        // is replaced. This catches an earlier installation even when the user had
        // not changed any setting yet.
        let fileManager = FileManager.default
        let containerAttributes = try? fileManager.attributesOfItem(atPath: NSHomeDirectory())
        let bundleAttributes = try? fileManager.attributesOfItem(atPath: Bundle.main.bundleURL.path)
        guard let containerDate = containerAttributes?[.creationDate] as? Date,
              let bundleDate = bundleAttributes?[.creationDate] as? Date else {
            return false
        }
        return bundleDate.timeIntervalSince(containerDate) > 300
    }

    private func completeVersion210Update() {
        didShowVersion210Update = true
        version210UpdatePresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 460))
            presentModeSelectionHintIfNeeded()
        }
    }

    private func completePublicGoodsCommitment() {
        didShowPublicGoodsCommitment = true
        // Keep the legacy key as installation evidence and for compatibility
        // with older builds that used the compact free-notice overlay.
        didAcknowledgeFreeNotice = true
        publicGoodsCommitmentPresented = false

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 360))
            if shouldPresentVersion210Update {
                version210UpdatePresented = true
            } else {
                presentModeSelectionHintIfNeeded()
            }
        }
    }

    private func openModeSelection() {
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        dismissTicketLandscapeHint()
        modeSelectionPresented = true
    }

    private func enterTicketLandscape() {
        guard mode == .travelTicket else { return }
        didShowTicketLandscapeHint = true
        dismissTicketLandscapeHint()
        InterfaceOrientationController.shared.request(
            usesInAppTicketLandscape ? .portrait : .landscapeRight
        )
        withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.28)) {
            isTicketLandscape = true
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func exitTicketLandscape() {
        setTicketLandscape(false)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func setTicketLandscape(_ enabled: Bool) {
        dismissTicketLandscapeHint(animated: false)
        withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.28)) {
            isTicketLandscape = enabled
        }
        InterfaceOrientationController.shared.request(
            enabled && !usesInAppTicketLandscape ? .landscapeRight : .portrait
        )
    }

    private func openTicketStudio() {
        if isTicketLandscape, usesInAppTicketLandscape {
            setTicketLandscape(false)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                ticketStudioPresented = true
            }
        } else {
            ticketStudioPresented = true
        }
    }

    private var guidanceHintAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.40, dampingFraction: 0.78)
    }

    private func presentModeSelectionHintIfNeeded() {
        guard canPresentModeSelectionHint,
              !isModeSelectionHintPresented,
              modeSelectionHintTask == nil else { return }

        modeSelectionHintTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 360))
            } catch {
                return
            }
            guard !Task.isCancelled, canPresentModeSelectionHint else {
                modeSelectionHintTask = nil
                return
            }

            didShowModeSelectionHint101 = true
            withAnimation(guidanceHintAnimation) {
                isModeSelectionHintPresented = true
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: "模式选择已独立到主界面顶部"
            )

            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(guidanceHintAnimation) {
                isModeSelectionHintPresented = false
            }
            modeSelectionHintTask = nil
        }
    }

    private func dismissModeSelectionHint(animated: Bool = true) {
        modeSelectionHintTask?.cancel()
        modeSelectionHintTask = nil
        guard isModeSelectionHintPresented else { return }
        if animated {
            withAnimation(guidanceHintAnimation) {
                isModeSelectionHintPresented = false
            }
        } else {
            isModeSelectionHintPresented = false
        }
    }

    private func presentTicketLandscapeHintIfNeeded() {
        guard canPresentTicketLandscapeHint,
              !isTicketLandscapeHintPresented,
              ticketLandscapeHintTask == nil else { return }

        ticketLandscapeHintTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 380))
            } catch {
                return
            }
            guard !Task.isCancelled, canPresentTicketLandscapeHint else {
                ticketLandscapeHintTask = nil
                return
            }

            didShowTicketLandscapeHint = true
            withAnimation(guidanceHintAnimation) {
                isTicketLandscapeHintPresented = true
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: "点击翻转，横屏预览票根效果更佳"
            )

            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(guidanceHintAnimation) {
                isTicketLandscapeHintPresented = false
            }
            ticketLandscapeHintTask = nil
        }
    }

    private func dismissTicketLandscapeHint(animated: Bool = true) {
        ticketLandscapeHintTask?.cancel()
        ticketLandscapeHintTask = nil
        guard isTicketLandscapeHintPresented else { return }
        if animated {
            withAnimation(guidanceHintAnimation) {
                isTicketLandscapeHintPresented = false
            }
        } else {
            isTicketLandscapeHintPresented = false
        }
    }

    private func presentNarrativePromptIfNeeded() {
        guard !didShowTicketNarrativePrompt else { return }
        ticketNarrativePromptPresented = true
    }

    private func dismissNarrativePrompt() {
        ticketNarrativePromptPresented = false
        didShowTicketNarrativePrompt = true
    }

    private var livePhotoHintAnimation: Animation {
        guidanceHintAnimation
    }

    private func presentLivePhotoHintIfNeeded() {
        guard canPresentLivePhotoHint,
              !hasShownLivePhotoPlaybackHint,
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
        let sessionID = UUID()
        livePlaybackSessionID = sessionID
        isLivePhotoPlaying = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        livePlaybackTask = Task {
            var failureDescription: String?
            do {
                try await LivePhotoPreview.playOnce(sourceVideoURLs: sourceURLs) { frames in
                    guard livePlaybackSessionID == sessionID else { return }
                    livePreviewFrames = frames
                }
            } catch {
                if !Task.isCancelled {
                    failureDescription = error.localizedDescription
                }
            }

            // A cancelled older task must never clear the frames or enabled
            // state belonging to a newer playback attempt.
            guard livePlaybackSessionID == sessionID else { return }
            livePlaybackSessionID = nil
            livePreviewFrames = [:]
            isLivePhotoPlaying = false
            livePlaybackTask = nil
            if let failureDescription {
                presentSaveError(failureDescription, title: "无法播放实况照片")
            }
        }
    }

    private func stopLivePhotoPlayback() {
        livePlaybackSessionID = nil
        let task = livePlaybackTask
        livePlaybackTask = nil
        task?.cancel()
        livePreviewFrames = [:]
        isLivePhotoPlaying = false
    }

    private func renderArtwork(
        replacingImages replacements: [Int: UIImage] = [:],
        pixelWidth: CGFloat = 1080,
        sketchImageOverride: UIImage? = nil,
        ticketCodeImageOverride: UIImage? = nil
    ) -> UIImage? {
        guard mode != .sketch
                || sketchImageOverride != nil
                || hasCurrentSketchRender else { return nil }
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
        } else if mode == .sketch,
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
                cameraWatermarkImage: activeCameraWatermark,
                gentleBackground: gentleBackground,
                imageScale: imageScale,
                imageOffset: imageOffset,
                metadata: primaryMetadata,
                showMissingCaptureTime: showMissingCaptureTime,
                copy: artworkCopy,
                fontStyle: fontStyle,
                templateStyle: templateStyle,
                motionCardHeaderStyle: motionCardHeaderStyle,
                motionCardHeaderPalette: effectiveMotionCardPalette,
                motionCardHeaderPercentages: effectiveMotionCardPercentages,
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
                selectedJournalIndex: nil,
                ticketPayload: ticketPayload,
                ticketCodeStyle: ticketCodeStyle,
                ticketLayout: ticketLayout,
                ticketAppClipBaseURL: TicketEnvelope.configuredBaseURLString,
                ticketDeviceSealEnabled: ticketDeviceSealEnabled,
                ticketCodeImageOverride: ticketCodeImageOverride,
                sketchImage: mode == .sketch
                    ? (sketchImageOverride ?? sketchImage)
                    : nil
            )
            .frame(width: renderWidth, height: renderHeight)
        )
        renderer.scale = renderScale
        guard let rendered = renderer.uiImage else { return nil }
        guard mode == .travelTicket,
              ticketLayout != .minimal else {
            return rendered
        }
        guard let masked = TicketArtworkAlphaMask.applying(
            to: rendered,
            layout: ticketLayout
        ),
        TicketArtworkAlphaMask.hasExpectedTransparency(
            masked,
            layout: ticketLayout
        ) else {
            return nil
        }
        return masked
    }

    private func ios17TicketCodeImageForArtwork() async -> UIImage? {
        guard mode == .travelTicket else { return nil }
        if #available(iOS 18.0, *) { return nil }

        let style = ticketCodeStyle
        let payload = ticketPayload
        let baseURLString = TicketEnvelope.configuredBaseURLString
        let deviceSealEnabled = ticketDeviceSealEnabled
        let foreground = ArtworkCanvas.ticketCodeForeground(
            palette: palette,
            motionCardHeaderPalette: effectiveMotionCardPalette,
            layout: ticketLayout
        )
        let pixelSize = style == .barcode
            ? CGSize(width: 1_200, height: 400)
            : CGSize(width: 900, height: 900)

        return await Task.detached(priority: .userInitiated) {
            try? TicketCodeRenderer.image(
                for: style,
                payload: payload,
                baseURLString: baseURLString,
                signer: deviceSealEnabled ? TicketDeviceSealService.shared : nil,
                pixelSize: pixelSize,
                foregroundColor: UIColor(
                    red: foreground.red,
                    green: foreground.green,
                    blue: foreground.blue,
                    alpha: 1
                ),
                backgroundColor: nil
            )
        }.value
    }

    private func sketchExportLongEdge(
        for image: UIImage,
        pixelWidth: CGFloat
    ) -> CGFloat {
        guard let cgImage = image.cgImage,
              cgImage.width > 0,
              cgImage.height > 0 else { return 1024 }
        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        let sourceLongEdge = max(sourceWidth, sourceHeight)
        let outputHeight = pixelWidth * sourceHeight / sourceWidth
        let requestedLongEdge = max(pixelWidth, outputHeight)
        return min(sourceLongEdge, min(max(requestedLongEdge, 1024), 1536))
    }

    private func showToast(_ message: String, duration: Double) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
            toastMessage = message.appLocalized
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
        errorTitle = title.appLocalized
        saveErrorMessage = message.appLocalized
        saveErrorPresented = true
    }

    private func ticketCodeExportImage(
        _ style: TicketCodeStyle
    ) throws -> UIImage {
        try TicketCodeRenderer.exportCard(
            for: style,
            payload: ticketPayload,
            baseURLString: TicketEnvelope.configuredBaseURLString,
            signer: ticketEnvelopeSigner
        )
    }

    private func ticketCodeExportImageForCurrentSystem(
        _ style: TicketCodeStyle
    ) async throws -> UIImage {
        if #available(iOS 18.0, *) {
            return try ticketCodeExportImage(style)
        }

        let payload = ticketPayload
        let baseURLString = TicketEnvelope.configuredBaseURLString
        let deviceSealEnabled = ticketDeviceSealEnabled
        return try await Task.detached(priority: .userInitiated) {
            try TicketCodeRenderer.exportCard(
                for: style,
                payload: payload,
                baseURLString: baseURLString,
                signer: deviceSealEnabled ? TicketDeviceSealService.shared : nil
            )
        }.value
    }

    private func saveTicketCodeToPhotos(_ style: TicketCodeStyle) {
        Task {
            do {
                let image = try await ticketCodeExportImageForCurrentSystem(style)
                try await ArtworkExporter.saveStill(
                    image,
                    metadata: .empty,
                    originalImageData: nil,
                    format: .png,
                    metadataPolicy: .removeAll
                )
                showToast("\(style.title)已保存到系统相册", duration: 2.2)
            } catch {
                presentSaveError(
                    error.localizedDescription,
                    title: "无法保存票根编码"
                )
            }
        }
    }

    private func saveTicketCodeToFiles(_ style: TicketCodeStyle) {
        if #unavailable(iOS 18.0) {
            Task {
                do {
                    let image = try await ticketCodeExportImageForCurrentSystem(style)
                    guard let data = image.pngData() else {
                        throw ArtworkExportError.encodingFailed
                    }
                    let url = try ExportTemporaryFile.make(data: data, format: .png)
                    documentExportFile = ExportedArtworkFile(url: url)
                } catch {
                    presentSaveError(
                        error.localizedDescription,
                        title: "无法导出票根编码"
                    )
                }
            }
            return
        }

        do {
            let image = try ticketCodeExportImage(style)
            guard let data = image.pngData() else {
                throw ArtworkExportError.encodingFailed
            }
            let url = try ExportTemporaryFile.make(data: data, format: .png)
            documentExportFile = ExportedArtworkFile(url: url)
        } catch {
            presentSaveError(
                error.localizedDescription,
                title: "无法导出票根编码"
            )
        }
    }

    private func shareTicketCode(_ style: TicketCodeStyle) {
        if #unavailable(iOS 18.0) {
            Task {
                do {
                    let image = try await ticketCodeExportImageForCurrentSystem(style)
                    guard let data = image.pngData() else {
                        throw ArtworkExportError.encodingFailed
                    }
                    let url = try ExportTemporaryFile.make(data: data, format: .png)
                    sharedExportFile = ExportedArtworkFile(url: url)
                } catch {
                    presentSaveError(
                        error.localizedDescription,
                        title: "无法分享票根编码"
                    )
                }
            }
            return
        }

        do {
            let image = try ticketCodeExportImage(style)
            guard let data = image.pngData() else {
                throw ArtworkExportError.encodingFailed
            }
            let url = try ExportTemporaryFile.make(data: data, format: .png)
            sharedExportFile = ExportedArtworkFile(url: url)
        } catch {
            presentSaveError(
                error.localizedDescription,
                title: "无法分享票根编码"
            )
        }
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
}

private struct CreationModeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let selectedMode: CreationMode
    let onSelect: (CreationMode) -> Void
    let onOpenAlbum: () -> Void
    let onOpenColorRelationship: () -> Void
    let onScanTicket: () -> Void
    let onConvertVideo: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择模式")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("保留当前照片，直接切换创作方式")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                }
                .buttonStyle(LiquidPressButtonStyle())
                .liquidGlass(in: Circle(), interactive: true, variant: .clear)
                .accessibilityLabel("关闭模式选择")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 12) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CreationMode.allCases) { item in
                            modeCard(item)
                        }

                        albumCard
                        colorRelationshipCard
                    }

                    scanTicketCard
                    videoToLivePhotoCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.88)

                Color(uiColor: .systemBackground)
                    .opacity(colorScheme == .dark ? 0.12 : 0.06)
            }
            .ignoresSafeArea()
        }
    }

    private var scanTicketCard: some View {
        Button(action: onScanTicket) {
            HStack(spacing: 14) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("扫描验证票根")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("打开相机扫描二维码，在本机查看验证结果")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: true,
            variant: .clear
        )
        .accessibilityLabel("扫描验证票根")
        .accessibilityHint("打开相机扫描灵动照片票根二维码")
    }

    private var videoToLivePhotoCard: some View {
        Button(action: onConvertVideo) {
            HStack(spacing: 14) {
                VideoToLivePhotoGlyph()
                    .scaleEffect(0.72)
                    .frame(width: 44, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text("视频转实况")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("截取 3 秒视频、选择实况封面，并优先保留原始动态画质")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: true,
            variant: .clear
        )
        .accessibilityLabel("视频转实况")
        .accessibilityHint("选择视频并生成实况照片")
    }

    private var albumCard: some View {
        Button(action: onOpenAlbum) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "book.pages")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text("影像相簿")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text("把照片与灵动作品装订成书，横屏翻阅并输出打印 PDF")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: true,
            variant: .clear
        )
        .accessibilityHint("打开本地多页相簿项目")
    }

    private var colorRelationshipCard: some View {
        Button(action: onOpenColorRelationship) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text("色彩关系")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text("比较两张照片的共鸣、对照与过渡，并导出关系作品")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: true,
            variant: .clear
        )
        .accessibilityLabel("色彩关系")
        .accessibilityHint("选择两张照片并分析它们的色彩关系")
    }

    private func modeCard(_ item: CreationMode) -> some View {
        let isSelected = item == selectedMode
        return Button {
            onSelect(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: item.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)

                    Spacer(minLength: 8)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }

                Text(LocalizedStringKey(item.title))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey(item.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 146, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(item.accent.opacity(0.13))
            }
        }
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: true,
            variant: .clear
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(item.accent.opacity(0.88), lineWidth: 1.4)
            }
        }
        .accessibilityLabel("\(item.title)\(isSelected ? "，当前模式" : "")")
        .accessibilityHint("保留当前照片并切换到\(item.title)")
    }
}

private struct ModeGlyph: View {
    let symbol: String
    let accent: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 62, weight: .light))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accent.opacity(0.94))
            .frame(width: 98, height: 98)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 7)
        .transaction { transaction in
            transaction.animation = nil
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
                    Label(LocalizedStringKey(semantic.summary), systemImage: "viewfinder")
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
                if mode == .motionCard
                    || mode == .bubbleStamp
                    || mode == .travelTicket {
                    Section("标题") {
                        TextField("输入标题", text: tracked(\.title), axis: .vertical)
                            .lineLimit(1...3)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.done)
                    }
                }
                if mode == .bubbleStamp || mode == .travelTicket {
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

private struct MotionCardColorSamplerView: View {
    private enum Corner: CaseIterable, Hashable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let initialSelection: CGRect?
    let headerStyle: MotionCardHeaderStyle
    let onApply: (CGRect, PaletteResult) -> Void
    let onReset: () -> Void

    @State private var selection: CGRect
    @State private var gestureStart: CGRect?
    @State private var previewResult: PaletteResult?

    init(
        image: UIImage,
        initialSelection: CGRect?,
        headerStyle: MotionCardHeaderStyle,
        onApply: @escaping (CGRect, PaletteResult) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.image = image
        self.initialSelection = initialSelection
        self.headerStyle = headerStyle
        self.onApply = onApply
        self.onReset = onReset
        _selection = State(initialValue: initialSelection ?? CGRect(x: 0.15, y: 0.20, width: 0.70, height: 0.60))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("拖动选框选择取色范围，拖动四角可调整大小。此范围只影响灵动卡片顶部背景。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)

                GeometryReader { proxy in
                    let imageRect = aspectFitRect(in: proxy.size)
                    let selectedRect = displayRect(in: imageRect)
                    ZStack {
                        Color.black.opacity(0.94)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)

                        Path { path in
                            path.addRect(imageRect)
                            path.addRect(selectedRect)
                        }
                        .fill(.black.opacity(0.52), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)

                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(.white, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                            )
                            .frame(width: selectedRect.width, height: selectedRect.height)
                            .position(x: selectedRect.midX, y: selectedRect.midY)
                            .gesture(moveGesture(imageRect: imageRect))

                        ForEach(Corner.allCases, id: \.self) { corner in
                            Circle()
                                .fill(.white)
                                .overlay(Circle().stroke(.black.opacity(0.24), lineWidth: 1))
                                .frame(width: 24, height: 24)
                                .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                                .position(handlePoint(corner, in: selectedRect))
                                .gesture(resizeGesture(corner: corner, imageRect: imageRect))
                                .accessibilityLabel("调整取色范围")
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 18)

                samplingPreview
                    .padding(.horizontal, 18)

                Button(role: .none, action: onReset) {
                    Label("恢复整张照片取色", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
            }
            .padding(.top, 12)
            .navigationTitle("局部取色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        let result = previewResult ?? Self.extractPalette(from: image, selection: selection)
                        onApply(selection, result)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task(id: selection) {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            previewResult = Self.extractPalette(from: image, selection: selection)
        }
    }

    @ViewBuilder
    private var samplingPreview: some View {
        if let previewResult {
            let colors = previewResult.colors.isEmpty ? RGBColor.fallback : previewResult.colors
            let percentages = previewResult.percentages
            let solid = MotionCardColorTheme.resolve(
                palette: colors.map {
                    MotionCardColor(red: Double($0.red), green: Double($0.green), blue: Double($0.blue))
                },
                percentages: percentages
            )
            let gradient = MotionCardGradientTheme.resolve(
                palette: colors.map {
                    MotionCardColor(red: Double($0.red), green: Double($0.green), blue: Double($0.blue))
                },
                percentages: percentages
            )
            let previewColors = gradient.colors.map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
            HStack(spacing: 12) {
                Group {
                    if headerStyle == .sampledGradient {
                        LinearGradient(colors: previewColors, startPoint: .leading, endPoint: .trailing)
                    } else {
                        Color(red: solid.background.red, green: solid.background.green, blue: solid.background.blue)
                    }
                }
                .frame(height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 4) {
                    ForEach(Array(colors.prefix(4).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color.color).frame(width: 15, height: 15)
                    }
                }
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("当前局部取色预览")
        } else {
            ProgressView("正在分析选区…")
                .font(.footnote)
                .frame(height: 62)
        }
    }

    private func aspectFitRect(in available: CGSize) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else {
            return CGRect(origin: .zero, size: available)
        }
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: (available.width - size.width) / 2,
            y: (available.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func displayRect(in imageRect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.minX + selection.minX * imageRect.width,
            y: imageRect.minY + selection.minY * imageRect.height,
            width: selection.width * imageRect.width,
            height: selection.height * imageRect.height
        )
    }

    private func handlePoint(_ corner: Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func moveGesture(imageRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = gestureStart ?? selection
                if gestureStart == nil { gestureStart = selection }
                let dx = value.translation.width / max(imageRect.width, 1)
                let dy = value.translation.height / max(imageRect.height, 1)
                selection.origin.x = min(max(start.minX + dx, 0), 1 - start.width)
                selection.origin.y = min(max(start.minY + dy, 0), 1 - start.height)
            }
            .onEnded { _ in gestureStart = nil }
    }

    private func resizeGesture(corner: Corner, imageRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = gestureStart ?? selection
                if gestureStart == nil { gestureStart = selection }
                let dx = value.translation.width / max(imageRect.width, 1)
                let dy = value.translation.height / max(imageRect.height, 1)
                selection = resized(start, corner: corner, dx: dx, dy: dy)
            }
            .onEnded { _ in gestureStart = nil }
    }

    private func resized(_ rect: CGRect, corner: Corner, dx: CGFloat, dy: CGFloat) -> CGRect {
        let minimum: CGFloat = 0.12
        var minX = rect.minX
        var minY = rect.minY
        var maxX = rect.maxX
        var maxY = rect.maxY
        switch corner {
        case .topLeft:
            minX = min(max(rect.minX + dx, 0), rect.maxX - minimum)
            minY = min(max(rect.minY + dy, 0), rect.maxY - minimum)
        case .topRight:
            maxX = max(min(rect.maxX + dx, 1), rect.minX + minimum)
            minY = min(max(rect.minY + dy, 0), rect.maxY - minimum)
        case .bottomLeft:
            minX = min(max(rect.minX + dx, 0), rect.maxX - minimum)
            maxY = max(min(rect.maxY + dy, 1), rect.minY + minimum)
        case .bottomRight:
            maxX = max(min(rect.maxX + dx, 1), rect.minX + minimum)
            maxY = max(min(rect.maxY + dy, 1), rect.minY + minimum)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func extractPalette(from image: UIImage, selection: CGRect) -> PaletteResult {
        let normalized = CGRect(
            x: min(max(selection.minX, 0), 1),
            y: min(max(selection.minY, 0), 1),
            width: min(max(selection.width, 0.01), 1 - min(max(selection.minX, 0), 1)),
            height: min(max(selection.height, 0.01), 1 - min(max(selection.minY, 0), 1))
        )
        let sourceRect = CGRect(
            x: normalized.minX * image.size.width,
            y: normalized.minY * image.size.height,
            width: normalized.width * image.size.width,
            height: normalized.height * image.size.height
        )
        let maximumDimension: CGFloat = 512
        let scale = min(1, maximumDimension / max(max(sourceRect.width, sourceRect.height), 1))
        let outputSize = CGSize(
            width: max(1, sourceRect.width * scale),
            height: max(1, sourceRect.height * scale)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let crop = UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            image.draw(in: CGRect(
                x: -sourceRect.minX * scale,
                y: -sourceRect.minY * scale,
                width: image.size.width * scale,
                height: image.size.height * scale
            ))
        }
        return PaletteExtractor.extract(from: crop)
    }
}
