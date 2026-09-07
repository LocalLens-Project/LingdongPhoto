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

private struct OverflowContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct OverflowOnlyVerticalScroll<Content: View>: View {
    @State private var contentHeight: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    content()
                    Color.clear.frame(height: 18)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .background {
                    GeometryReader { contentProxy in
                        Color.clear.preference(
                            key: OverflowContentHeightKey.self,
                            value: contentProxy.size.height
                        )
                    }
                }
            }
            .scrollDisabled(contentHeight <= proxy.size.height + 1)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .onPreferenceChange(OverflowContentHeightKey.self) { newHeight in
                contentHeight = newHeight
            }
        }
    }
}

struct ContentView: View {
    private static let ticketScannerIntroID = "ticketScanner"
    private static let albumIntroID = "photoAlbum"
    private static let colorRelationshipIntroID = "colorRelationship"
    private static let videoToLivePhotoIntroID = "videoToLivePhoto"
    private static let ticketDevelopingIntroID = "ticketDeveloping"
    private static let ticketCollectionIntroID = "ticketCollection"
    private static let stampIntroID = "postalStamp"
    private static let postcardIntroID = "postalPostcard"
    private static let postalCollectionIntroID = "postalCollection"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didChooseModeLauncherStyle") private var didChooseModeLauncherStyle = false
    @AppStorage("modeLauncherStyle") private var modeLauncherStyleRaw = ModeLauncherStyle.floatingMenu.rawValue
    @AppStorage("supportsLivePhotos") private var supportsLivePhotos = true
    @AppStorage("useLiteraryColorNames") private var useLiteraryColorNames = false
    @AppStorage("poeticNamesEnabled") private var poeticNamesEnabled = false
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @AppStorage("colorInsightUsageCount") private var colorInsightUsageCount = 0
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
    @AppStorage("showSupporterBadge") private var showSupporterBadge = false
    @AppStorage("showMissingCaptureTime") private var showMissingCaptureTime = true
    @AppStorage("emptyCanvasTheme") private var emptyCanvasThemeRaw = EmptyCanvasTheme.sky.rawValue
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

    @AppStorage("didShowLivePhotoPlaybackHint") private var didShowLivePhotoPlaybackHint = false
    @AppStorage("didShowLivePhotoPlaybackHintBuild1060") private var didShowLivePhotoPlaybackHintBuild1060 = false
    @AppStorage("didShowOnboardingExperience") private var didShowOnboardingExperience = false
    @AppStorage("didShowModeSelectionHint101") private var didShowModeSelectionHint101 = false
    @AppStorage("didShowTicketLandscapeHint") private var didShowTicketLandscapeHint = false
    // The previous `didShowPaletteSwapHint300` flag could be consumed while the
    // spotlight still had no measured palette-band frame and was therefore
    // invisible. This acknowledgement-only key gives affected installs one
    // correct opportunity to see the repaired hint.
    @AppStorage("didAcknowledgePaletteSwapHint301") private var didAcknowledgePaletteSwapHint = false
    @AppStorage("didShowTicketNarrativePrompt") private var didShowTicketNarrativePrompt = false

    @State private var mode: CreationMode = .motionCard
    @State private var ipadDestination: IPadWorkspaceEntry = .creation(.motionCard)
    @State private var ipadVisitedDestinations: Set<IPadWorkspaceEntry> = []
    @State private var ipadControlsHeight: CGFloat = 100
    @State private var ipadRelationshipPalette: [PaletteColor] = []
    @State private var ipadDrafts: [CreationMode: IPadCompositionDraft] = [:]
    @State private var modeChangeTask: Task<Void, Never>?
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    @State private var resolvedIslandLauncherSupport: Bool?
    @State private var didConfigureLaunchExperience = false
    private var modeLauncherStyle: ModeLauncherStyle {
        ModeLauncherStyle(rawValue: modeLauncherStyleRaw) ?? .floatingMenu
    }
    private var supportsIslandLauncher: Bool {
        if let resolvedIslandLauncherSupport { return resolvedIslandLauncherSupport }
        return TicketIslandAvailability.isSupported(
            screenSize: UIScreen.main.bounds.size,
            safeAreaTop: UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?.safeAreaInsets.top ?? 0
        )
    }
    private var usesIslandLauncher: Bool {
        !isIPad && supportsIslandLauncher && modeLauncherStyle == .islandReveal
    }
    private var usesFloatingMenuLauncher: Bool { !usesIslandLauncher }
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

    @AppStorage("featurePaletteSide") private var featurePaletteSideRaw = FeaturePaletteSide.bottom.rawValue
    @AppStorage("featurePaletteBandRatio") private var featurePaletteBandRatio = 0.295
    @AppStorage("monthlyCalendarHidesLocation") private var monthlyCalendarHidesLocation = false
    @State private var monthlyCalendarSettingsPresented = false
    @State private var featureCalendarCity: String?
    @State private var featureCalendarLocationMessage: String?
    @State private var featureCityRequest = UUID()
    @State private var featureCityTask: Task<Void, Never>?
    @State private var isResolvingFeatureCity = false
    private var featurePaletteSide: FeaturePaletteSide {
        FeaturePaletteSide(rawValue: featurePaletteSideRaw) ?? .bottom
    }
    private var isFeatureMode: Bool {
        mode == .paletteCard || mode == .monthlyCalendar
    }

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
    @State private var fanGalleryPresented = false
    @State private var videoToLivePhotoPresented = false
    @State private var ticketDevelopingPresented = false
    @State private var ticketCollectionPresented = false
    @State private var postalDestination: PostalDestination?
    @State private var queuedPostalDestination: PostalDestination?
    @State private var toastMessage: String?
    @State private var poeticSourcePromptPresented = false
    @State private var poeticSourcePromptDismissTask: Task<Void, Never>?
    @State private var errorTitle = "无法保存"
    @State private var saveErrorMessage = ""
    @State private var saveErrorPresented = false
    @State private var editCopyPresented = false
    @State private var photoSelectionOperation: PhotoSelectionOperation = .replaceAll
    @State private var importStatus = ""
    @State private var isImportingSharedPhoto = false
    @State private var exportCenterPresented = false
    @State private var exportIncludesPoeticDetails = true
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

    @State private var glassArchiveMarkChoiceRaw: String = ""
    @State private var glassArchiveSettingsPresented = false
    @State private var motionCardSettingsPresented = false
    @State private var bubbleStampSettingsPresented = false
    @State private var paletteCardSettingsPresented = false
    @State private var paletteCardSwatchOrder: [Int] = []
    @State private var isPaletteSwapHintPresented = false
    @State private var paletteBandRect: CGRect? = nil
    @State private var paletteSwapHintTask: Task<Void, Never>?

    @State private var glassArchiveHidesMissingTime = false

    @State private var glassArchiveShowsLocation = true
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
    @State private var onboardingPresented = false
    @State private var modeLauncherChoicePresented = false
    @State private var modeLauncherDraft: ModeLauncherStyle?
    @State private var supportUsPresented = false
    @StateObject private var cameraWatermarkLibrary = CameraWatermarkLibrary()

    private var pickerLimit: Int {
        if mode == .journal, photoSelectionOperation == .append {
            return max(1, 5 - selectedPhotos.count)
        }
        if case .replace = photoSelectionOperation { return 1 }
        if mode == .journal { return 5 }
        return 1
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
        get {
            return TicketCodeStyle(rawValue: ticketCodeStyleRaw) ?? .barcode
        }
        nonmutating set {
            ticketCodeStyleRaw = newValue.rawValue
        }
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
    private var activeGlassArchiveMark: GlassArchiveMark {
        if let choice = GlassArchiveMark(rawValue: glassArchiveMarkChoiceRaw),
           GlassArchiveMarkResolver.availableMarks(
               for: primaryMetadata,
               cameraWatermarkImage: activeCameraWatermark
           ).contains(choice) {
            return choice
        }
        return GlassArchiveMarkResolver.automaticMark(
            for: primaryMetadata,
            cameraWatermarkImage: activeCameraWatermark
        )
    }

    private var glassArchiveSettingsSheetHeight: CGFloat {
        primaryMetadata.archiveTimeText == nil ? 250 : 190
    }

    private func movePaletteCardSwatch(from source: Int, to destination: Int) {
        acknowledgePaletteSwapHint()
        guard source != destination else { return }
        let count = (palette.isEmpty ? RGBColor.fallback : palette).prefix(5).count
        guard count > 1 else { return }
        var order = paletteCardSwatchOrder
        if order.count != count { order = Array(0..<count) }
        guard order.indices.contains(source), order.indices.contains(destination) else { return }
        let item = order.remove(at: source)
        order.insert(item, at: destination)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            paletteCardSwatchOrder = order
        }
    }

    private func cycleGlassArchiveMark() {
        let next = GlassArchiveMarkResolver.nextMark(
            after: activeGlassArchiveMark,
            for: primaryMetadata,
            cameraWatermarkImage: activeCameraWatermark
        )
        guard next != activeGlassArchiveMark else { return }
        withAnimation(.snappy(duration: 0.24)) {
            glassArchiveMarkChoiceRaw = next.rawValue
        }
        UISelectionFeedbackGenerator().selectionChanged()
        showToast(
            next == .camera ? "已切换为相机标志" : "已切换为苹果标志",
            duration: 1.4
        )
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
            && (!isIPad || ipadDestination == .creation(mode))
            && showsLivePlaybackControl
            && !liveSourceVideoURLs.isEmpty
            && (isIPad || didShowModeSelectionHint101)
            && !isModeSelectionHintPresented
            && modeSelectionHintTask == nil
            && !modeLauncherChoicePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !isPickerPresented
    }
    private var canPresentModeSelectionHint: Bool {
        !isIPad && isEditorVisible
            && !didShowModeSelectionHint101
            && usesFloatingMenuLauncher
            && !modeLauncherChoicePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !isPickerPresented
    }
    private var canPresentTicketLandscapeHint: Bool {
        !isIPad && isEditorVisible
            && mode == .travelTicket
            && !isTicketLandscape
            && !didShowTicketLandscapeHint
            && didShowModeSelectionHint101
            && !isModeSelectionHintPresented
            && modeSelectionHintTask == nil
            && !modeLauncherChoicePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !exportCenterPresented
            && !ticketStudioPresented
            && !ticketNarrativePromptPresented
            && !isPickerPresented
    }
    private var canPresentPaletteSwapHint: Bool {
        isEditorVisible
            && (!isIPad || ipadDestination == .creation(mode))
            && mode == .paletteCard
            && !images.isEmpty
            && hasValidPaletteBandRect
            && !didAcknowledgePaletteSwapHint
            && !isModeSelectionHintPresented
            && !isLivePhotoHintPresented
            && !modeLauncherChoicePresented
            && !modeSelectionPresented
            && !settingsPresented
            && !exportCenterPresented
            && !paletteCardSettingsPresented
            && !onboardingPresented
            && !isPickerPresented
    }
    private var canPresentNarrativePrompt: Bool {
        isEditorVisible
            && (!isIPad || ipadDestination == .creation(mode))
            && mode == .travelTicket
            && !didShowTicketNarrativePrompt
            && !modeLauncherChoicePresented
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
    private var emptyCanvasTheme: EmptyCanvasTheme {
        EmptyCanvasTheme(rawValue: emptyCanvasThemeRaw) ?? .sky
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
                if isIPad && ipadDestination == .colorRelationship {
                    PrototypeAmbientBackground(colors: ipadRelationshipPalette.isEmpty
                        ? emptyCanvasTheme.palette.map { PaletteColor(red: $0.red, green: $0.green, blue: $0.blue, weight: 1) }
                        : ipadRelationshipPalette)
                } else {
                    AmbientBackground(palette: isEditorVisible ? palette : emptyCanvasTheme.palette)
                }

                if isIPad {
                    ipadWorkspace(in: proxy.size)
                } else if isEditorVisible {
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

                if poeticSourcePromptPresented && !supporterUnlocked {
                    VStack {
                        Spacer()
                        SupporterProUnlockPrompt(
                            message: "支持我们，即可查看琉璃色盘中六种节气色名的可考出处。"
                        ) {
                            poeticSourcePromptDismissTask?.cancel()
                            withAnimation(.easeOut(duration: 0.18)) {
                                poeticSourcePromptPresented = false
                            }
                            supportUsPresented = true
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 30)
                    }
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .zIndex(70)
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
                    isEnabled: (!isIPad || ipadDestination == .creation(mode))
                        && !editCopyPresented
                        && !settingsPresented
                        && !modeSelectionPresented
                        && !albumPresented
                        && !modeLauncherChoicePresented
                        && !onboardingPresented
                        && !isPickerPresented
                ) {
                    resetComposition()
                }
                    .frame(width: 0, height: 0)

                if !isIPad,
                   !isEditorVisible,
                   usesFloatingMenuLauncher,
                   didChooseModeLauncherStyle,
                   !onboardingPresented,
                   !modeLauncherChoicePresented {
                    VStack {
                        HStack {
                            Spacer()
                            LiquidCircleButton(
                                symbol: "square.grid.2x2",
                                isEnabled: !controlsAreDimmed,
                                action: openModeSelection
                            )
                            .accessibilityIdentifier("modeLauncher.floatingButton")
                        }
                        Spacer()
                    }
                    .padding(.top, max(proxy.safeAreaInsets.top, 18) + 8)
                    .padding(.trailing, 16)
                    .zIndex(70)
                }

                if usesIslandLauncher,
                   didChooseModeLauncherStyle,
                   proxy.size.height >= proxy.size.width,
                   !ticketPrintPhase.isPresented,
                   !onboardingPresented,
                   !modeLauncherChoicePresented {
                    IslandModeLauncher(
                        safeAreaTop: max(proxy.safeAreaInsets.top, 51),
                        selectedMode: mode,
                        isEnabled: !controlsAreDimmed,
                        onChoose: openModeLauncherDestination
                    )
                    .zIndex(80)
                }

                if modeLauncherChoicePresented {
                    ModeLauncherChoiceOverlay(
                        selection: $modeLauncherDraft,
                        onConfirm: completeModeLauncherChoice
                    )
                    .zIndex(120)
                    .transition(.opacity)
                }

                paletteSwapHintOverlay
                    .zIndex(200)
            }
            .onChange(of: canPresentPaletteSwapHint) { _, canPresent in
                if canPresent {
                    presentPaletteSwapHintIfNeeded()
                } else {
                    hidePaletteSwapHint()
                }
            }
            .onAppear {
                let supportsIsland = TicketIslandAvailability.isSupported(
                    screenSize: proxy.size,
                    safeAreaTop: proxy.safeAreaInsets.top
                )
                resolvedIslandLauncherSupport = supportsIsland
                configureLaunchExperience(supportsIsland: supportsIsland)
                if canPresentPaletteSwapHint {
                    presentPaletteSwapHintIfNeeded()
                }
            }
            .onChange(of: proxy.size) { _, newSize in
                resolvedIslandLauncherSupport = TicketIslandAvailability.isSupported(
                    screenSize: newSize,
                    safeAreaTop: proxy.safeAreaInsets.top
                )
            }
        }

        .environment(\.colorScheme, .light)
        .statusBarHidden(!isIPad)
        .preferredColorScheme(isIPad && ipadDestination == .colorRelationship ? .dark : nil)
        .fullScreenCover(isPresented: $onboardingPresented) {
            OnboardingExperienceView(
                supportsIslandLauncher: supportsIslandLauncher,
                onFinish: completeOnboardingExperience
            )
                .environment(\.colorScheme, .dark)
        }
        .fullScreenCover(isPresented: $supportUsPresented) {
            SupportUsView {
                poeticNamesEnabled = true
            }
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
            if isIPad { ipadDestination = .creation(newMode) }
            if introPageID != newMode.rawValue {
                introPageID = newMode.rawValue
            }
            stopLivePhotoPlayback()
            dismissLivePhotoHint()
            dismissTicketLandscapeHint()
            if newMode != .travelTicket, isTicketLandscape {
                setTicketLandscape(false)
            }
            if !isIPad {
                ratio = newMode == .travelTicket && ticketLayout == .vertical
                    ? .threeFour
                    : (newMode == .travelTicket && ticketLayout == .classic
                        ? (ticketCanvasWidthMode == .compact ? .twentyOneNine
                            : ticketCanvasWidthMode == .standard ? .sixteenNine
                            : .fourThree)
                        : newMode.defaultRatio)
            }
            if newMode == .privacyMosaic {
                refreshPrivacyPreview()
            } else {
                finishPrivacyPainting()
            }
            if newMode == .sketch {
                scheduleSketchPreviewRefresh()
            }
            if newMode == .colorPalette && !isIPad {

                imageScale = 1
                storedScale = 1
                imageOffset = .zero
                storedOffset = .zero
                activeDragRole = nil
            }
            if newMode != .colorPalette {
                activeLightToneRange = nil
            }
            if newMode != .paletteCard {
                paletteBandRect = nil
                hidePaletteSwapHint()
            }
        }
        .onChange(of: colorInsightPage) { _, page in
            if page != .light { activeLightToneRange = nil }
        }
        .onChange(of: supporterUnlocked) { _, unlocked in
            guard unlocked else { return }
            poeticSourcePromptDismissTask?.cancel()
            withAnimation(.easeOut(duration: 0.18)) {
                poeticSourcePromptPresented = false
            }
        }
        .onChange(of: palette) { _, _ in
            paletteCardSwatchOrder = []
        }
        .onChange(of: privacyMosaicStrength) { _, _ in
            schedulePrivacyPreviewRefresh()
        }
        .onChange(of: sketchParameters) { _, _ in
            scheduleSketchPreviewRefresh()
        }
        .onChange(of: selectedPhotos.map(\.id)) { _, _ in
            ipadDrafts.removeAll()
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
                useCustomCameraWatermarks: $useCustomCameraWatermarks,
                gentleBackground: $gentleBackground,
                cameraWatermarkLibrary: cameraWatermarkLibrary
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents(isTicketLandscape ? [.large] : [.fraction(0.94)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $modeSelectionPresented, onDismiss: presentQueuedPostalDestination) {
            CreationModeSelectionView(
                selectedMode: mode,
                onSelect: selectCreationMode,
                onOpenFanGallery: openFanGallery,
                onOpenAlbum: openAlbum,
                onOpenColorRelationship: openColorRelationship,
                onScanTicket: openTicketScanner,
                onConvertVideo: openVideoToLivePhoto,
                onOpenTicketDeveloping: openTicketDeveloping,
                onOpenTicketCollection: openTicketCollection,
                onOpenPostal: openPostal
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents(isTicketLandscape ? [.large] : [.fraction(0.84)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(38)
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $monthlyCalendarSettingsPresented) {
            MonthlyCalendarSettingsSheet(hidesLocation: $monthlyCalendarHidesLocation)
                .environment(\.colorScheme, systemColorScheme)
                .presentationDetents([.height(190)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $glassArchiveSettingsPresented) {
            GlassArchiveSettingsSheet(
                showsMissingTimeToggle: primaryMetadata.archiveTimeText == nil,
                hidesMissingTime: $glassArchiveHidesMissingTime,
                showsLocation: $glassArchiveShowsLocation
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents([.height(glassArchiveSettingsSheetHeight)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $paletteCardSettingsPresented) {
            PaletteCardSettingsSheet(
                usePoeticColorNames: $poeticNamesEnabled,
                useLiteraryColorNames: $useLiteraryColorNames,
                showPalettePercentages: $showPalettePercentages
            )
            .environment(\.colorScheme, systemColorScheme)
            .presentationDetents([.height(470)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $motionCardSettingsPresented) {
            MotionCardSettingsSheet(
                templateStyle: Binding(
                    get: { templateStyle },
                    set: { templateStyleRaw = $0.rawValue }
                ),
                headerStyle: Binding(
                    get: { motionCardHeaderStyle },
                    set: { motionCardHeaderStyleRaw = $0.rawValue }
                ),
                ratio: $ratio,
                showMoodCopy: $showMoodCopy,
                showMissingCaptureTime: $showMissingCaptureTime
            )
            .environment(\.colorScheme, systemColorScheme)
            .featureSettingsSheetChrome()
        }
        .sheet(isPresented: $bubbleStampSettingsPresented) {
            BubbleStampSettingsSheet(
                templateStyle: Binding(
                    get: { templateStyle },
                    set: { templateStyleRaw = $0.rawValue }
                ),
                ratio: $ratio,
                showDeviceInfo: $showDeviceInfo,
                showBubbles: $showBubbles
            )
            .environment(\.colorScheme, systemColorScheme)
            .featureSettingsSheetChrome()
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
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    ColorRelationshipFeatureView(
                        onOpenModeSelection: returnFromColorRelationshipToModeSelection,
                        showsModeSelectionButton: usesFloatingMenuLauncher
                    )

                    if usesIslandLauncher, proxy.size.height >= proxy.size.width {
                        IslandModeLauncher(
                            safeAreaTop: max(proxy.safeAreaInsets.top, 51),
                            selectedMode: mode,
                            isEnabled: true,
                            onChoose: openModeLauncherDestinationFromColorRelationship
                        )
                        .zIndex(80)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $fanGalleryPresented) {
            FanGalleryFeatureView()
        }
        .fullScreenCover(isPresented: $videoToLivePhotoPresented) {
            VideoToLivePhotoScreen()
                .environment(\.colorScheme, systemColorScheme)
        }
        .fullScreenCover(isPresented: $ticketDevelopingPresented) {
            TicketOCRImportView(source: nil) { tickets in
                TicketStore.shared.addDevelopedTickets(tickets)
            }
            .preferredColorScheme(.light)
        }
        .fullScreenCover(isPresented: $ticketCollectionPresented) {
            PiaogenceRootView(onCreateTicket: beginTicketCreationFromCollection)
        }
        .fullScreenCover(item: $postalDestination) { destination in
            switch destination {
            case .stamp: StampStudio(photo: selectedPhotos.first)
            case .postcard: PostcardStudio(photo: selectedPhotos.first)
            case .collection: PostalCollectionView()
            }
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
                includesPoeticDetails: $exportIncludesPoeticDetails,
                sourcePixelWidth: images.first?.cgImage.map { CGFloat($0.width) } ?? 1080,
                supportsLiveExport: supportsLivePhotos
                    && mode != .privacyMosaic
                    && mode != .travelTicket
                    && !liveSourceVideoURLs.isEmpty,
                requiresTransparency: mode == .travelTicket,
                showsPoeticDetailsOption: mode == .colorPalette && poeticNamesEnabled,
                canIncludePoeticDetails: supporterUnlocked,
                onRequestSupport: {
                    exportCenterPresented = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(220))
                        supportUsPresented = true
                    }
                },
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
            modeChangeTask?.cancel()
            paletteSwapHintTask?.cancel()
            paletteSwapHintTask = nil
            stopLivePhotoPlayback()
            lightAnalysisTask?.cancel()
            poeticSourcePromptDismissTask?.cancel()
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
        if isIPad { returnToIPadCreation() }
        photoSelectionOperation = .replaceAll
        isImportingSharedPhoto = true
        Task {
            await loadSelectedPhotos()
            isImportingSharedPhoto = false
        }
    }



    private func ipadWorkspace(in size: CGSize) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                ipadWorkspaceTitle(compact: size.width < 600)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 56, alignment: .leading)
                IPadModeButtons(
                    selection: ipadDestination,
                    compact: size.width < 600,
                    disabled: controlsAreDimmed || isLoading || ticketPrintPhase.isPresented,
                    onSelect: selectIPadEntry
                )
                .padding(.bottom, 8)
            }
            .frame(width: size.width < 600 ? 64 : 174)
            .environment(\.colorScheme,
                ipadDestination == .colorRelationship ? .dark : .light)


            ZStack {
                VStack(spacing: 8) {
                    ipadToolbar
                    if isEditorVisible {
                        GeometryReader { proxy in
                            ipadEditor(in: proxy.size)
                        }
                    } else {
                        ipadWelcome
                    }
                }
                .opacity(ipadDestination == .creation(mode) ? 1 : 0)
                .allowsHitTesting(ipadDestination == .creation(mode))
                .accessibilityHidden(ipadDestination != .creation(mode))

                if ipadVisitedDestinations.contains(.colorRelationship) {
                    ColorRelationshipFeatureView(
                        onOpenModeSelection: returnToIPadCreation,
                        showsModeSelectionButton: false,
                        onPaletteChange: { ipadRelationshipPalette = $0 }
                    )
                    .opacity(ipadDestination == .colorRelationship ? 1 : 0)
                    .allowsHitTesting(ipadDestination == .colorRelationship)
                    .accessibilityHidden(ipadDestination != .colorRelationship)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ipad.workspace")
    }

    private func ipadWorkspaceTitle(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if showAppTitle {
                HStack(spacing: 4) {
                    Text("灵动照片").font(compact ? .caption : .headline)
                    if supporterUnlocked && showSupporterBadge && !compact { ProBadge(compact: true) }
                }
            }
            Text(ipadDestination.title)
                .font(compact ? .caption2 : (showAppTitle ? .subheadline : .headline))
                .foregroundStyle(showAppTitle ? .secondary : .primary)
                .lineLimit(compact ? 2 : 1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("ipad.currentMode")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ipadToolbar: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            LiquidCircleButton(
                symbol: "plus",
                isEnabled: !controlsAreDimmed && !isLoading && (mode != .journal || selectedPhotos.count < 5)
            ) { openPicker(append: mode == .journal && isEditorVisible) }
            .accessibilityIdentifier("ipad.addPhoto")

            if mode == .journal && selectedPhotos.count > 1 {
                LiquidCircleButton(symbol: "minus", isEnabled: !controlsAreDimmed, action: removeLastJournalPhoto)
            }
            LiquidCircleButton(
                symbol: saveState == .success ? "checkmark" : "arrow.down",
                isEnabled: canSaveCurrentArtwork && isEditorVisible,
                isBusy: saveState == .saving,
                action: saveArtwork
            )
            .accessibilityLabel("导出作品")
            .accessibilityValue(saveState == .saving ? "正在导出" : saveState == .success ? "保存成功" : "")
            .accessibilityIdentifier("ipad.export")
            LiquidCircleButton(symbol: "gearshape", isEnabled: !controlsAreDimmed) {
                dismissLivePhotoHint()
                settingsPresented = true
            }
            .accessibilityIdentifier("ipad.settings")
        }
        .frame(minHeight: 56)
    }

    private var ipadWelcome: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(emptyCanvasTheme.accent)
                        .accessibilityHidden(true)
                    Text(mode.title)
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(mode.introSubtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { openPicker() } label: {
                        Label(isLoading ? "正在读取照片…" : "添加照片", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 28)
                            .frame(minHeight: 54)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                    .disabled(isLoading)
                    .accessibilityIdentifier("ipad.startCreation")
                    if isLoading {
                        ProgressView()
                        Text(importStatus).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func ipadEditor(in size: CGSize) -> some View {
        let controlsHeight = min(ipadControlsHeight, max(96, size.height * 0.40))
        return VStack(spacing: 12) {
            GeometryReader { proxy in
                let ratioValue = editorRatio(in: proxy.size)
                let width = max(1, min(proxy.size.width - 16, max(1, proxy.size.height - 12) * ratioValue))
                artworkPreview(width: width, height: width / ratioValue)
                    .accessibilityElement(children: .contain)
                    .accessibilityValue("\(Int(imageScale * 100))%")
                    .accessibilityIdentifier("ipad.artwork")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            ScrollView(.vertical) {
                ipadEditorControls
                    .frame(maxWidth: 700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        if height > 0 { ipadControlsHeight = height }
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: max(16, controlsHeight))
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("ipad.editorControls")
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder private var ipadEditorControls: some View {
        VStack(spacing: 12) {
            if showsLivePlaybackControl {
                LivePhotoPlaybackButton(
                    isAvailable: !liveSourceVideoURLs.isEmpty,
                    isPlaying: isLivePhotoPlaying,
                    action: playLivePhotoOnce
                )
            }
            switch mode {
            case .motionCard:
                if templateStyle != .immersive { motionCardSamplingControls }
            case .colorPalette:
                ColorInsightSwitcher(selection: $colorInsightPage, reduceMotion: reduceMotion)
                if colorInsightPage == .light {
                    if let lightAnalysis {
                        LightAnalysisPanel(analysis: lightAnalysis, semantic: combinedSemantic, activeRange: $activeLightToneRange)
                    } else { LightAnalysisLoadingPanel() }
                } else if poeticNamesEnabled {
                    PoeticPaletteCard(palette: palette, isUnlocked: supporterUnlocked,
                        percentages: palettePercentages, onLockedTap: presentPoeticSourcePrompt)
                } else if !supporterUnlocked { PoeticColorInvitation(action: presentPoeticSourcePrompt) }
            case .glassArchive:
                ipadFeatureButton("琉璃档案功能设定") { glassArchiveSettingsPresented = true }
            case .bubbleStamp:
                ipadFeatureButton("气泡印章设定") { bubbleStampSettingsPresented = true }
            case .privacyMosaic:
                PrivacyMosaicControls(
                    brushMode: $privacyBrushMode, strength: $privacyMosaicStrength,
                    isPainting: isPrivacyPainting, isDetecting: isPrivacyDetecting,
                    canUndo: !privacyHistory.isEmpty, detectedCount: privacyMasks.count,
                    disabledCount: disabledPrivacyMaskCount,
                    hasLivePhoto: selectedPhotos.contains(where: \.isLivePhoto),
                    onTogglePainting: togglePrivacyPainting, onDetect: detectPrivacyContent, onUndo: undoPrivacyEdit
                )
            case .sketch:
                SketchEditorControls(parameters: $sketchParameters, isRendering: isSketchRendering,
                    onStyleChange: { sketchParameters = $0.defaultParameters })
            case .journal:
                JournalEditorControls(
                    images: images, selectedIndex: $selectedJournalIndex,
                    layout: Binding(get: { journalLayout }, set: { journalLayoutRaw = $0.rawValue }),
                    onReplace: { openPicker(replacing: $0) }, onDelete: removeJournalPhoto,
                    onMove: moveJournalPhoto, onReset: resetJournalComposition
                )
            case .travelTicket:
                TicketEditorControls(
                    layout: Binding(get: { ticketLayout }, set: { ticketLayout = $0 }),
                    codeStyle: Binding(get: { ticketCodeStyle }, set: { ticketCodeStyle = $0 }),
                    widthMode: Binding(get: { ticketCanvasWidthMode }, set: { ticketCanvasWidthMode = $0 }),
                    onOpenStudio: openTicketStudio
                )
                motionCardSamplingControls
            case .spectrumWallpaper:
                EmptyView()
            case .paletteCard, .monthlyCalendar:
                FeatureModeControls(
                    mode: mode,
                    paletteSide: Binding(
                        get: { featurePaletteSide },
                        set: { featurePaletteSideRaw = $0.rawValue }
                    ),
                    paletteBandRatio: $featurePaletteBandRatio,
                    calendarCity: featureCalendarCity,
                    isResolvingCity: isResolvingFeatureCity,
                    locationMessage: featureCalendarLocationMessage,
                    hidesCalendarLocation: monthlyCalendarHidesLocation,
                    onCalendarSettings: { monthlyCalendarSettingsPresented = true },
                    onPaletteCardSettings: { paletteCardSettingsPresented = true }
                )
            }
        }
    }

    private func ipadFeatureButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
    }

    private func selectIPadEntry(_ entry: IPadWorkspaceEntry) {
        guard !controlsAreDimmed, !isLoading else { return }
        stopLivePhotoPlayback()
        dismissLivePhotoHint()
        switch entry {
        case .creation(let selected):
            ipadDestination = entry
            selectCreationMode(selected)
        case .fanGallery: openFanGallery()
        case .colorRelationship:
            ipadVisitedDestinations.insert(entry)
            ipadDestination = entry
        case .album: openAlbum()
        case .collection: openTicketCollection()
        case .scanner: openTicketScanner()
        case .video: openVideoToLivePhoto()
        case .developing: openTicketDeveloping()
        case .stamp: openPostal(.stamp)
        case .postcard: openPostal(.postcard)
        case .postalCollection: openPostal(.collection)
        }
    }

    private func returnToIPadCreation() { ipadDestination = .creation(mode) }


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

            ticketDevelopingIntro
                .tag(Self.ticketDevelopingIntroID)

            ticketCollectionIntro
                .tag(Self.ticketCollectionIntroID)

            postalIntro(.stamp)
                .tag(Self.stampIntroID)

            postalIntro(.postcard)
                .tag(Self.postcardIntroID)

            postalIntro(.collection)
                .tag(Self.postalCollectionIntroID)
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
            accent: emptyCanvasTheme.accent,
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
            accent: emptyCanvasTheme.accent,
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
            accent: emptyCanvasTheme.accent,
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

    private var ticketCollectionIntro: some View {
        introPage(
            title: "票根集",
            subtitle: "把影像票根按城市与分集收藏\n沿时间轴翻阅每一张",
            symbol: "ticket",
            accent: emptyCanvasTheme.accent,
            showsJournalBadge: false,
            showsNewBadge: true,
            actionSymbol: "ticket",
            actionAccessibilityLabel: "打开票根集",
            actionAccessibilityHint: "按城市与分集浏览收藏的影像票根",
            isBusy: false,
            isActionDisabled: false,
            showsImportStatus: false,
            action: openTicketCollection
        )
    }

    private var ticketDevelopingIntro: some View {
        introPage(
            title: "票根显影",
            subtitle: "读懂纸票与电子凭证\n用原票六色重制一张记忆票",
            symbol: "viewfinder",
            accent: emptyCanvasTheme.accent,
            showsJournalBadge: false,
            showsNewBadge: true,
            actionSymbol: "viewfinder",
            actionAccessibilityLabel: "打开票根显影",
            actionAccessibilityHint: "选择纸票照片或电子凭证截图",
            isBusy: false,
            isActionDisabled: false,
            showsImportStatus: false,
            action: openTicketDeveloping
        )
    }

    private var albumIntro: some View {
        introPage(
            title: "影像相簿",
            subtitle: "把照片与灵动作品装订成书\n横屏翻阅，并导出打印级 PDF",
            symbol: "book.pages",
            accent: emptyCanvasTheme.accent,
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
            accent: emptyCanvasTheme.accent,
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

    private func postalIntro(_ destination: PostalDestination) -> some View {
        let title: String
        let subtitle: String
        let symbol: String
        switch destination {
        case .stamp:
            title = "邮票制作"
            subtitle = "五种齿孔，收藏一瞬风景\n制作自己的邮票，寄出独一份心意"
            symbol = "photo.artframe"
        case .postcard:
            title = "明信片"
            subtitle = "把照片、文字与邮戳排成一封问候\n四种版式，留住有温度的时光"
            symbol = "envelope"
        case .collection:
            title = "邮集"
            subtitle = "把走过的城市，收进一枚枚邮票\n点亮足迹，转动查看每次抵达的纪念"
            symbol = "book.closed"
        }
        return introPage(
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            accent: emptyCanvasTheme.accent,
            showsJournalBadge: false,
            showsNewBadge: true,
            actionSymbol: "arrow.up.right",
            actionAccessibilityLabel: "打开\(title)",
            actionAccessibilityHint: "无需先选择照片，即可进入\(title)",
            isBusy: false,
            isActionDisabled: isLoading,
            showsImportStatus: false,
            action: { openPostal(destination) }
        )
    }

    private func introPage(
        title: String,
        subtitle: String,
        symbol: String,
        accent: Color,
        showsJournalBadge: Bool,
        showsNewBadge: Bool = false,
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
                if showsNewBadge {
                    NewBadge()
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
            .accessibilityLabel(actionAccessibilityLabel.appLocalized)
            .accessibilityHint((actionAccessibilityHint ?? "").appLocalized)

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
            Self.videoToLivePhotoIntroID,
            Self.ticketDevelopingIntroID,
            Self.ticketCollectionIntroID,
            Self.stampIntroID,
            Self.postcardIntroID,
            Self.postalCollectionIntroID
        ]
    }

    private func editorView(in size: CGSize) -> AnyView {
        let ratioValue = editorRatio(in: size)
        let availableWidth = size.width - 32
        let canvasWidth: CGFloat
        if mode == .spectrumWallpaper {
            canvasWidth = min(size.width - 96, UIScreen.main.bounds.width * 0.686)
        } else if isFeatureMode {
            let reserve: CGFloat = mode == .paletteCard ? 250 : 200
            canvasWidth = min(availableWidth, max(160, size.height - reserve) * ratioValue)
        } else if mode == .privacyMosaic {
            canvasWidth = min(availableWidth, max(280, size.height - 340) * ratioValue)
        } else if mode == .journal {

            let editorReserve: CGFloat = size.height < 760 ? 285 : 230
            canvasWidth = min(availableWidth, max(280, size.height - editorReserve) * ratioValue)
        } else if mode == .travelTicket {
            let editorReserve: CGFloat = size.height < 760 ? 250 : 215
            canvasWidth = min(availableWidth, max(280, size.height - editorReserve) * ratioValue)
        } else if mode == .motionCard && templateStyle != .immersive {

            let editorReserve: CGFloat = size.height < 760 ? 205 : 175
            canvasWidth = min(availableWidth, max(300, size.height - editorReserve) * ratioValue)
        } else if mode == .colorPalette {
            let editorReserve: CGFloat = colorInsightPage == .light
                ? (size.height < 760 ? 470 : 430)
                : 205
            canvasWidth = min(availableWidth, max(248, size.height - editorReserve) * ratioValue)
        } else {

            canvasWidth = min(availableWidth, max(320, size.height - 130) * ratioValue)
        }
        let canvasHeight = canvasWidth / ratioValue
        let colorDetailUnderlap: CGFloat = 18
        let colorDetailRestingGap: CGFloat = colorInsightPage == .palette ? 11 : 10

        let content = VStack(spacing: 0) {
            HStack(spacing: 6) {
                if showAppTitle {
                    Text("灵动照片")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)

                    if supporterUnlocked && showSupporterBadge {
                        ProBadge(compact: true)
                            .fixedSize()
                            .transition(.scale(scale: 0.72).combined(with: .opacity))
                    }
                } else if supporterUnlocked && showSupporterBadge {
                    ProBadge()
                        .fixedSize()
                        .transition(.scale(scale: 0.72).combined(with: .opacity))
                }

                Spacer()

                if usesFloatingMenuLauncher {
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
                }

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
            .animation(.easeInOut(duration: 0.18), value: showSupporterBadge)
            .animation(.easeInOut(duration: 0.18), value: supporterUnlocked)
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
            .zIndex(mode == .colorPalette ? 2 : 0)

            if mode == .colorPalette {
                OverflowOnlyVerticalScroll {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: colorDetailUnderlap + colorDetailRestingGap)

                        if colorInsightPage == .palette {
                            if poeticNamesEnabled {
                                PoeticPaletteCard(
                                    palette: palette,
                                    isUnlocked: supporterUnlocked,
                                    percentages: palettePercentages,
                                    onLockedTap: presentPoeticSourcePrompt
                                )
                                .frame(width: min(canvasWidth, size.width - 36))
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else if !supporterUnlocked {
                                PoeticColorInvitation(action: presentPoeticSourcePrompt)
                                    .frame(width: min(canvasWidth, size.width - 36))
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }

                        if colorInsightPage == .light {
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
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    )
                            )
                        }
                    }
                }
                .padding(.top, -colorDetailUnderlap)
                .zIndex(1)
            }

            if mode == .motionCard, templateStyle != .immersive {
                motionCardSamplingControls
                    .frame(width: canvasWidth)
                    .padding(.top, 12)
            }

            if mode == .glassArchive {
                Button {
                    glassArchiveSettingsPresented = true
                } label: {
                    Label("琉璃档案功能设定", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(LiquidPressButtonStyle())
                .foregroundStyle(.primary.opacity(0.82))
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                .frame(width: canvasWidth)
                .padding(.top, 12)
                .accessibilityHint("调整琉璃档案栏的时间与位置信息显示")
            }

            if mode == .bubbleStamp {
                Button {
                    bubbleStampSettingsPresented = true
                } label: {
                    Label("气泡印章设定", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(LiquidPressButtonStyle())
                .foregroundStyle(.primary.opacity(0.82))
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                .frame(width: canvasWidth)
                .padding(.top, 12)
                .accessibilityHint("调整气泡印章的作品模板、图片比例与信息显示")
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

            if isFeatureMode {
                FeatureModeControls(
                    mode: mode,
                    paletteSide: Binding(
                        get: { featurePaletteSide },
                        set: { featurePaletteSideRaw = $0.rawValue }
                    ),
                    paletteBandRatio: $featurePaletteBandRatio,
                    calendarCity: featureCalendarCity,
                    isResolvingCity: isResolvingFeatureCity,
                    locationMessage: featureCalendarLocationMessage,
                    hidesCalendarLocation: monthlyCalendarHidesLocation,
                    onCalendarSettings: { monthlyCalendarSettingsPresented = true },
                    onPaletteCardSettings: { paletteCardSettingsPresented = true }
                )
                .frame(width: canvasWidth)
                .padding(.top, 12)
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

            if mode != .colorPalette {
                Spacer(minLength: mode == .travelTicket
                    ? 24
                    : (mode == .privacyMosaic ? 8 : 18))
            }
        }
        .safeAreaPadding(.top)
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.42, extraBounce: 0.04),
            value: colorInsightPage
        )

        if mode == .colorPalette {
            return AnyView(
                content
                    .frame(width: size.width, height: size.height, alignment: .top)
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
                .padding(.horizontal, mode == .motionCard ? 15 : 0)
                .frame(maxWidth: mode == .motionCard ? nil : .infinity)
                .frame(height: 42)
            }
            .buttonStyle(LiquidPressButtonStyle())
            .foregroundStyle(.primary.opacity(0.82))
            .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
            .accessibilityHint(mode == .travelTicket
                ? "选择照片中的区域，只改变影像票根背景的取色"
                : "选择照片中的区域，只改变灵动卡片顶部背景的取色")

            if mode == .motionCard {
                Button {
                    motionCardSettingsPresented = true
                } label: {
                    Label("灵动卡片设定", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(LiquidPressButtonStyle())
                .foregroundStyle(.primary.opacity(0.82))
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                .accessibilityHint("调整灵动卡片的顶部背景、图片比例与文案显示")
            }

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
            usePoeticColorNames: poeticNamesEnabled,
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
                : nil,
            glassArchiveMark: activeGlassArchiveMark,
            glassArchiveHidesMissingTime: glassArchiveHidesMissingTime,
            glassArchiveShowsLocation: glassArchiveShowsLocation,
            featurePaletteSide: featurePaletteSide,
            featurePaletteBandRatio: featurePaletteBandRatio,
            featurePaletteSwatchOrder: paletteCardSwatchOrder,
            featurePaletteSwatchMove: movePaletteCardSwatch,
            featurePaletteBandRectChange: { rect in
                if paletteBandRect != rect {
                    paletteBandRect = rect
                }
            },
            featureCalendarCity: featureCalendarCity,
            featureCalendarShowsLocation: !monthlyCalendarHidesLocation
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
                : (mode == .sketch || isFeatureMode
                    ? "\(mode.title)预览，按照片实际比例预览"
                    : (mode == .colorPalette
                        ? (colorInsightPage == .light
                            ? "光影解析预览，按照片实际比例完整显示".appLocalized
                            : "琉璃色盘预览，图片完整固定显示，可拖动色盘调整位置".appLocalized)
                        : (mode == .glassArchive
                            ? "琉璃档案预览，按照片实际比例完整显示，双击中间标志可更换标志"
                            : "\(mode.title)预览，可拖拽或双指缩放")))
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

            return AnyGesture(DragGesture(minimumDistance: 100_000).map { _ in () })
        }

        if mode == .colorPalette {
            if colorInsightPage == .light {

                return AnyGesture(DragGesture(minimumDistance: 100_000).map { _ in () })
            }
            return AnyGesture(colorPaletteGesture(canvasSize: canvasSize).map { _ in () })
        }

        if mode == .glassArchive {

            let glassArchiveTapGesture = SpatialTapGesture(count: 2)
                .onEnded { tap in
                    if GlassArchiveBarGeometry.markFrame(in: canvasSize)
                        .contains(tap.location) {
                        cycleGlassArchiveMark()
                    }
                }
            return AnyGesture(glassArchiveTapGesture.map { _ in () })
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

    private func colorPaletteGesture(canvasSize: CGSize) -> some Gesture {
        let paletteDrag = DragGesture(minimumDistance: 10)
            .onChanged { value in
                let hitFrame = PalettePanelGeometry.hitFrame(
                    in: canvasSize,
                    layout: paletteLayout,
                    offset: paletteOffset
                )
                guard activeDragRole != nil || hitFrame.contains(value.startLocation) else {
                    return
                }

                if activeDragRole == nil {
                    activeDragRole = .palette
                    let normalizedOffset = PalettePanelGeometry.clampedOffset(
                        paletteOffset,
                        in: canvasSize,
                        layout: paletteLayout
                    )
                    paletteOffset = normalizedOffset
                    storedPaletteOffset = normalizedOffset
                }
                paletteOffset = PalettePanelGeometry.clampedOffset(
                    storedPaletteOffset + value.translation.height,
                    in: canvasSize,
                    layout: paletteLayout
                )
            }
            .onEnded { _ in
                if let role = activeDragRole, case .palette = role {
                    storedPaletteOffset = paletteOffset
                }
                activeDragRole = nil
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

        return SimultaneousGesture(paletteDrag, canvasTapGesture)
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
        if mode == .colorPalette {
            colorInsightUsageCount = min(colorInsightUsageCount + 1, 10_000)
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
            if incremental || (isIPad && !images.isEmpty) {
                isEditorVisible = true; canSave = true; canvasRevealed = true
            }
            presentSaveError(
                firstImportError?.localizedDescription
                    ?? "未能读取所选照片，请确认照片已下载到本机后重试。",
                title: "无法读取照片"
            )
            return
        }

        ipadDrafts.removeAll()
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
            glassArchiveMarkChoiceRaw = ""
            glassArchiveHidesMissingTime = false
            glassArchiveShowsLocation = true
            resetPrivacyEdits(for: images.first)
            if mode == .sketch {
                sketchImage = nil
                scheduleSketchPreviewRefresh()
            }
        }
        let semantic = PhotoSemantic.combined(combined.map(\.semantic))
        if operation == .replaceAll {
            featureCityTask?.cancel(); featureCityRequest = UUID()
            featureCalendarCity = nil; featureCalendarLocationMessage = nil; isResolvingFeatureCity = false
        }
        resolveFeatureCityIfNeeded()
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
        if isFeatureMode {
            return FeatureArtworkLayout.aspectRatio(mode: mode, imageSize: images.first?.size,
                                                     side: featurePaletteSide, bandRatio: featurePaletteBandRatio)
        }
        if mode == .spectrumWallpaper {
            if isIPad { return 9.0 / 16.0 }
            let bounds = UIScreen.main.bounds
            return min(max(bounds.width / bounds.height, 0.43), 0.50)
        }
        if mode == .colorPalette,
           let image = images.first,
           image.size.height > 0 {

            return min(max(image.size.width / image.size.height, 0.25), 6.00)
        }
        if mode == .privacyMosaic, let image = images.first, image.size.height > 0 {
            return min(max(image.size.width / image.size.height, 0.35), 2.40)
        }
        if mode == .sketch, let image = images.first, image.size.height > 0 {
            return min(max(image.size.width / image.size.height, 0.35), 2.40)
        }
        if mode == .glassArchive, let image = images.first, image.size.height > 0 {

            return min(max(image.size.width / image.size.height, 0.35), 2.40)
        }
        return ratio.value(for: images.first)
    }

    private func selectCreationMode(_ selectedMode: CreationMode) {
        guard mode != selectedMode else {
            modeSelectionPresented = false
            return
        }

        modeChangeTask?.cancel()
        if isIPad {
            ipadDrafts[mode] = IPadCompositionDraft(
                ratio: ratio, imageScale: imageScale, imageOffset: imageOffset,
                paletteOffset: paletteOffset, bubbleScale: bubbleScale, textScale: textScale,
                fontStyle: fontStyle, journalTransforms: journalTransforms,
                selectedJournalIndex: selectedJournalIndex
            )
            modeSelectionPresented = false
            mode = selectedMode
            ratio = selectedMode == .travelTicket
                ? (ticketLayout == .vertical ? .threeFour
                    : ticketLayout == .classic
                        ? (ticketCanvasWidthMode == .compact ? .twentyOneNine
                            : ticketCanvasWidthMode == .standard ? .sixteenNine : .fourThree)
                        : .twentyOneNine)
                : selectedMode.defaultRatio
            finishModeChange()
            return
        }
        modeSelectionPresented = false
        withAnimation(.snappy) {
            mode = selectedMode
        }
        modeChangeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, mode == selectedMode else { return }
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

    private func openPostal(_ destination: PostalDestination) {
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        stopLivePhotoPlayback()
        if isTicketLandscape { setTicketLandscape(false) }

        if modeSelectionPresented {
            queuedPostalDestination = destination
            modeSelectionPresented = false
        } else {
            postalDestination = destination
        }
    }

    private func presentQueuedPostalDestination() {
        guard let destination = queuedPostalDestination else { return }
        queuedPostalDestination = nil
        postalDestination = destination
    }

    private func openTicketCollection() {
        modeSelectionPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            ticketCollectionPresented = true
        }
    }

    private func beginTicketCreationFromCollection() {
        ticketCollectionPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            if isIPad {
                selectIPadEntry(.creation(.travelTicket))
            } else {
                withAnimation(.snappy) { mode = .travelTicket }
                finishModeChange()
            }
            if selectedPhotos.isEmpty {
                openPicker()
            }
        }
    }

    private func openTicketDeveloping() {
        modeSelectionPresented = false
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        dismissTicketLandscapeHint()
        if isTicketLandscape {
            setTicketLandscape(false)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            ticketDevelopingPresented = true
        }
    }

    private func openFanGallery() {
        modeSelectionPresented = false
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        dismissTicketLandscapeHint()
        if isTicketLandscape {
            setTicketLandscape(false)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            fanGalleryPresented = true
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
        if isIPad { selectIPadEntry(.colorRelationship); return }
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
        if isIPad { returnToIPadCreation(); return }
        colorRelationshipPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            modeSelectionPresented = true
        }
    }

    private func openModeLauncherDestinationFromColorRelationship(
        _ destination: ModeLauncherDestination
    ) {
        if case .colorRelationship = destination { return }
        colorRelationshipPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            openModeLauncherDestination(destination)
        }
    }

    private func finishModeChange() {

        guard !selectedPhotos.isEmpty, !images.isEmpty else { return }
        toastTask?.cancel()
        toastMessage = nil
        if mode == .monthlyCalendar {
            resolveFeatureCityIfNeeded()
        }
        if isIPad, let draft = ipadDrafts[mode] {
            ratio = draft.ratio
            imageScale = draft.imageScale
            storedScale = draft.imageScale
            imageOffset = draft.imageOffset
            storedOffset = draft.imageOffset
            paletteOffset = draft.paletteOffset
            storedPaletteOffset = draft.paletteOffset
            bubbleScale = draft.bubbleScale
            storedBubbleScale = draft.bubbleScale
            textScale = draft.textScale
            fontStyle = draft.fontStyle
            journalTransforms = draft.journalTransforms
            selectedJournalIndex = draft.selectedJournalIndex
            activeDragRole = nil
        } else {
            resetComposition(animated: false)
        }
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

    private func resolveFeatureCityIfNeeded() {
        guard mode == .monthlyCalendar,
              featureCalendarCity == nil,
              let metadata = selectedPhotos.first?.metadata else { return }
        featureCityTask?.cancel()
        let request = UUID(); featureCityRequest = request
        guard metadata.hasLocation else {
            featureCalendarLocationMessage = "无定位，仅显示日期".appLocalized
            isResolvingFeatureCity = false
            return
        }
        isResolvingFeatureCity = true; featureCalendarLocationMessage = nil
        featureCityTask = Task { @MainActor in
            defer { if featureCityRequest == request { isResolvingFeatureCity = false } }
            do {
                let city = try await PostalCity.resolve(metadata)
                guard !Task.isCancelled, featureCityRequest == request else { return }
                featureCalendarCity = city.name
            } catch {
                guard !Task.isCancelled, featureCityRequest == request else { return }
                featureCalendarLocationMessage = "城市暂无法确认，仅显示日期".appLocalized
            }
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
        exportIncludesPoeticDetails = mode == .colorPalette
            && poeticNamesEnabled
            && supporterUnlocked
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
        let includesPoeticDetailsAtExport = mode == .colorPalette
            && poeticNamesEnabled
            && supporterUnlocked
            && exportIncludesPoeticDetails
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
                ticketCodeImageOverride: ticketCodeImageOverride,
                includesPoeticDetails: includesPoeticDetailsAtExport
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
                                ticketCodeImageOverride: ticketCodeImageOverride,
                                includesPoeticDetails: includesPoeticDetailsAtExport
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
                let archiveMode = mode
                Task.detached(priority: .utility) {
                    LingdongWorkArchive.record(image: image, mode: archiveMode)
                }

                if mode == .travelTicket {
                    let collectedPayload = ticketPayload
                    let collectedMetadata = primaryMetadata
                    let collectedLayout = ticketLayout
                    let collectedCodeStyle = ticketCodeStyle
                    let collectedSealEnabled = ticketDeviceSealEnabled
                    let collectedPhotoData = selectedPhotos.first?.originalData
                    Task {
                        await PiaogenceCollector.collect(
                            payload: collectedPayload,
                            metadata: collectedMetadata,
                            layout: collectedLayout,
                            codeStyle: collectedCodeStyle,
                            deviceSealEnabled: collectedSealEnabled,
                            photoData: collectedPhotoData)
                    }
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

    private func configureLaunchExperience(supportsIsland: Bool) {
        guard !didConfigureLaunchExperience else { return }
        didConfigureLaunchExperience = true
        if !didShowOnboardingExperience {
            onboardingPresented = true
        } else if supportsIsland && !didChooseModeLauncherStyle {
            modeLauncherDraft = nil
            modeLauncherChoicePresented = true
        } else if !supportsIsland && !didChooseModeLauncherStyle {
            modeLauncherStyleRaw = ModeLauncherStyle.floatingMenu.rawValue
            didChooseModeLauncherStyle = true
        }
    }

    private func completeOnboardingExperience() {
        didShowOnboardingExperience = true
        if supportsIslandLauncher {
            modeLauncherDraft = nil
            modeLauncherChoicePresented = true
        } else {
            modeLauncherStyleRaw = ModeLauncherStyle.floatingMenu.rawValue
            didChooseModeLauncherStyle = true
        }



        onboardingPresented = false
        if !supportsIslandLauncher {
            presentModeSelectionHintIfNeeded()
        }
    }

    private func completeModeLauncherChoice() {
        guard let modeLauncherDraft else { return }
        modeLauncherStyleRaw = modeLauncherDraft.rawValue
        didChooseModeLauncherStyle = true
        withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.24)) {
            modeLauncherChoicePresented = false
        }
        if modeLauncherDraft == .floatingMenu {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 320))
                presentModeSelectionHintIfNeeded()
            }
        }
    }

    private func openModeLauncherDestination(_ destination: ModeLauncherDestination) {
        dismissModeSelectionHint()
        dismissLivePhotoHint()
        dismissTicketLandscapeHint()
        switch destination {
        case .creation(let selected): selectCreationMode(selected)
        case .fanGallery: openFanGallery()
        case .album: openAlbum()
        case .colorRelationship: openColorRelationship()
        case .ticketDeveloping: openTicketDeveloping()
        case .stamp: openPostal(.stamp)
        case .postcard: openPostal(.postcard)
        case .scanner: openTicketScanner()
        case .video: openVideoToLivePhoto()
        case .ticketCollection: openTicketCollection()
        case .postalCollection: openPostal(.collection)
        }
    }

    private func openModeSelection() {
        if isIPad { returnToIPadCreation(); return }
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

    @ViewBuilder
    private var paletteSwapHintOverlay: some View {
        if isPaletteSwapHintPresented, let globalBandRect = paletteBandRect {
            GeometryReader { hintProxy in
                let localOrigin = hintProxy.frame(in: .global).origin
                let localBandRect = CGRect(
                    x: globalBandRect.minX - localOrigin.x,
                    y: globalBandRect.minY - localOrigin.y,
                    width: globalBandRect.width,
                    height: globalBandRect.height
                )
                PaletteSwapSpotlight(
                    bandRect: localBandRect,
                    side: featurePaletteSide,
                    tint: livePhotoHintTint,
                    foreground: livePhotoHintForeground,
                    action: acknowledgePaletteSwapHint
                )
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    private func presentPaletteSwapHintIfNeeded() {
        guard canPresentPaletteSwapHint,
              !isPaletteSwapHintPresented,
              paletteSwapHintTask == nil else { return }

        // Geometry reporting and the eligibility change happen in the same
        // AttributeGraph update. Inserting the overlay synchronously here can
        // create a graph cycle, leaving `isPaletteSwapHintPresented` true while
        // SwiftUI never mounts the spotlight. Defer to a clean render pass.
        paletteSwapHintTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 140))
            } catch {
                return
            }
            guard !Task.isCancelled, canPresentPaletteSwapHint else {
                paletteSwapHintTask = nil
                return
            }
            withAnimation(guidanceHintAnimation) {
                isPaletteSwapHintPresented = true
            }
            paletteSwapHintTask = nil
            UIAccessibility.post(
                notification: .announcement,
                argument: "长按色块可交替位置".appLocalized
            )
        }
    }

    private var hasValidPaletteBandRect: Bool {
        guard let rect = paletteBandRect else { return false }
        return !rect.isNull
            && !rect.isInfinite
            && rect.width > 1
            && rect.height > 1
            && rect.minX.isFinite
            && rect.minY.isFinite
    }

    private func hidePaletteSwapHint() {
        paletteSwapHintTask?.cancel()
        paletteSwapHintTask = nil
        guard isPaletteSwapHintPresented else { return }
        withAnimation(guidanceHintAnimation) {
            isPaletteSwapHintPresented = false
        }
    }

    private func acknowledgePaletteSwapHint() {
        didAcknowledgePaletteSwapHint = true
        hidePaletteSwapHint()
    }

    private func playLivePhotoOnce() {
        dismissLivePhotoHint()
        guard showsLivePlaybackControl else { return }
        let sourceURLs = liveSourceVideoURLs
        guard !sourceURLs.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showToast("未取得实况照片动态片段，请确认原片已从 iCloud 下载后重新选择", duration: 3.4)
            return
        }

        // A second tap is an explicit restart. It must never be ignored while a
        // previous decoder task is winding down or waiting on a slow frame.
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
        ticketCodeImageOverride: UIImage? = nil,
        includesPoeticDetails: Bool = false
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
        if isFeatureMode {
            outputRatio = FeatureArtworkLayout.aspectRatio(mode: mode, imageSize: renderImages.first?.size,
                                                           side: featurePaletteSide, bandRatio: featurePaletteBandRatio)
        } else if mode == .spectrumWallpaper {
            outputRatio = editorRatio(in: .zero)
        } else if mode == .privacyMosaic,
                  let image = renderImages.first,
                  image.size.height > 0 {
            outputRatio = min(max(image.size.width / image.size.height, 0.35), 2.40)
        } else if mode == .sketch,
                  let image = renderImages.first,
                  image.size.height > 0 {
            outputRatio = min(max(image.size.width / image.size.height, 0.35), 2.40)
        } else if mode == .colorPalette,
                  let image = renderImages.first,
                  image.size.height > 0 {
            outputRatio = min(max(image.size.width / image.size.height, 0.25), 6.00)
        } else if mode == .glassArchive,
                  let image = renderImages.first,
                  image.size.height > 0 {
            outputRatio = min(max(image.size.width / image.size.height, 0.35), 2.40)
        } else {
            outputRatio = ratio.value(for: renderImages.first)
        }

        let canvasRenderHeight = ((renderWidth / outputRatio) * renderScale).rounded(.up) / renderScale
        let includesPoeticCard = mode == .colorPalette
            && poeticNamesEnabled
            && supporterUnlocked
            && includesPoeticDetails
        let poeticCardHeight: CGFloat = includesPoeticCard
            ? PoeticPaletteCard.exportHeight(
                for: palette,
                percentages: palettePercentages,
                width: renderWidth
            )
            : 0
        let renderHeight = canvasRenderHeight + poeticCardHeight
        let artwork = ArtworkCanvas(
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
                usePoeticColorNames: poeticNamesEnabled,
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
                    : nil,
                glassArchiveMark: activeGlassArchiveMark,
                glassArchiveHidesMissingTime: glassArchiveHidesMissingTime,
                glassArchiveShowsLocation: glassArchiveShowsLocation,
                featurePaletteSide: featurePaletteSide,
                featurePaletteBandRatio: featurePaletteBandRatio,
                featurePaletteSwatchOrder: paletteCardSwatchOrder,
                featureCalendarCity: featureCalendarCity,
                featureCalendarShowsLocation: !monthlyCalendarHidesLocation
            )
            .frame(width: renderWidth, height: canvasRenderHeight)
        let renderer = ImageRenderer(
            content: Group {
                if includesPoeticCard {
                    VStack(spacing: 12) {
                        artwork
                        PoeticPaletteCard(
                            palette: palette,
                            isUnlocked: true,
                            isExporting: true,
                            percentages: palettePercentages
                        )
                        .frame(height: poeticCardHeight - 24)
                    }
                    .padding(.bottom, 12)
                    .frame(width: renderWidth, height: renderHeight)
                    .background {
                        AmbientBackground(palette: palette)
                            .frame(width: renderWidth, height: renderHeight)
                            .clipped()
                    }
                } else {
                    artwork
                        .frame(width: renderWidth, height: renderHeight, alignment: .top)
                }
            }
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

    private func presentPoeticSourcePrompt() {
        guard !supporterUnlocked else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        poeticSourcePromptDismissTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            poeticSourcePromptPresented = true
        }
        poeticSourcePromptDismissTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                poeticSourcePromptPresented = false
            }
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

private struct GlassArchiveSettingsSheet: View {
    let showsMissingTimeToggle: Bool
    @Binding var hidesMissingTime: Bool
    @Binding var showsLocation: Bool

    var body: some View {
        Form {
            if showsMissingTimeToggle {
                Section {
                    Toggle("隐藏“时间未记录”", isOn: $hidesMissingTime)
                }
            }
            Section {
                Toggle("显示位置信息", isOn: $showsLocation)
            }
        }
        .formStyle(.grouped)
    }
}

private struct MotionCardSettingsSheet: View {
    @Binding var templateStyle: ArtworkTemplateStyle
    @Binding var headerStyle: MotionCardHeaderStyle
    @Binding var ratio: ArtworkRatio
    @Binding var showMoodCopy: Bool
    @Binding var showMissingCaptureTime: Bool

    private var isImmersiveTemplate: Bool { templateStyle == .immersive }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("作品模板", selection: $templateStyle) {
                        ForEach(ArtworkTemplateStyle.allCases) { style in
                            Label(LocalizedStringKey(style.rawValue), systemImage: style.symbol).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Picker("顶部背景", selection: $headerStyle) {
                        ForEach(MotionCardHeaderStyle.allCases) { style in
                            Text(LocalizedStringKey(style.rawValue)).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isImmersiveTemplate)
                } footer: {
                    Text(isImmersiveTemplate
                        ? "沉浸模板没有独立顶部区域；切换为经典或留白模板后生效。"
                        : "取色渐变会从照片代表色生成平滑过渡，并自动选择清晰的文字颜色。")
                }

                Section {
                    Picker("图片比例", selection: $ratio) {
                        ForEach(ArtworkRatio.allCases) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle("总是显示意境文案", isOn: $showMoodCopy)
                } footer: {
                    Text("即使图片存在位置信息，也优先显示根据画面内容与色彩生成的意境文案。")
                }

                Section {
                    Toggle("显示缺失拍摄时间提示", isOn: $showMissingCaptureTime)
                } footer: {
                    Text("关闭后，照片没有日期信息时不显示“拍摄时间未记录”。")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("灵动卡片设定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct BubbleStampSettingsSheet: View {
    @Binding var templateStyle: ArtworkTemplateStyle
    @Binding var ratio: ArtworkRatio
    @Binding var showDeviceInfo: Bool
    @Binding var showBubbles: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("作品模板", selection: $templateStyle) {
                        ForEach(ArtworkTemplateStyle.allCases) { style in
                            Label(LocalizedStringKey(style.rawValue), systemImage: style.symbol).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Picker("图片比例", selection: $ratio) {
                        ForEach(ArtworkRatio.allCases) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle("显示手机和相机信息", isOn: $showDeviceInfo)
                } footer: {
                    Text("根据照片 EXIF 自动识别设备类别、厂商与型号")
                }

                Section {
                    Toggle("显示气泡", isOn: $showBubbles)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("气泡印章设定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension View {

    @ViewBuilder
    func featureSettingsSheetChrome() -> some View {
        if #available(iOS 26.0, *) {
            self
                .presentationSizing(.form)
                .presentationCornerRadius(32)
        } else {
            self
                .presentationDetents([.height(480), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
    }
}

private struct CreationModeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let selectedMode: CreationMode
    let onSelect: (CreationMode) -> Void
    let onOpenFanGallery: () -> Void
    let onOpenAlbum: () -> Void
    let onOpenColorRelationship: () -> Void
    let onScanTicket: () -> Void
    let onConvertVideo: () -> Void
    let onOpenTicketDeveloping: () -> Void
    let onOpenTicketCollection: () -> Void
    let onOpenPostal: (PostalDestination) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择模式")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: 44)
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
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CreationMode.allCases) { item in
                        modeButton(item.title, selected: item == selectedMode, accent: item.accent) {
                            onSelect(item)
                        }
                        .accessibilityHint("保留当前照片并切换到\(item.title)")
                    }
                    modeButton("流光折扇", action: onOpenFanGallery)
                    modeButton("影像相簿", action: onOpenAlbum)
                    modeButton("色彩关系", action: onOpenColorRelationship)
                    modeButton("票根显影", action: onOpenTicketDeveloping)
                    postalButton(.stamp, title: "邮票制作")
                    postalButton(.postcard, title: "明信片")
                    modeButton("扫描验证票根", action: onScanTicket)
                    modeButton("视频转实况", action: onConvertVideo)
                    modeButton("票根集", action: onOpenTicketCollection)
                    postalButton(.collection, title: "邮集")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial).opacity(0.88)
                Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.12 : 0.06)
            }
            .ignoresSafeArea()
        }
    }

    private func postalButton(_ destination: PostalDestination, title: String) -> some View {
        modeButton(title) { onOpenPostal(destination) }
            .accessibilityIdentifier("postal.entry.\(destination.rawValue)")
    }

    private func modeButton(_ title: String, selected: Bool = false, accent: Color = .primary,
                            action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.headline).foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12).padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(shape)
        }
        .buttonStyle(LiquidPressButtonStyle())
        .background { if selected { shape.fill(accent.opacity(0.13)) } }
        .liquidGlass(in: shape, interactive: true, variant: .clear)
        .overlay { if selected { shape.stroke(accent.opacity(0.88), lineWidth: 1.4) } }
        .accessibilityAddTraits(selected ? .isSelected : [])
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
