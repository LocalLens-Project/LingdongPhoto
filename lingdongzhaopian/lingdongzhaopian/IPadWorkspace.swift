import SwiftUI
import UIKit


enum IPadWorkspaceEntry: Hashable, Identifiable {
    case creation(CreationMode), fanGallery
    case album, colorRelationship, scanner, video, developing, collection, stamp, postcard, postalCollection, solarColors, photoBacks

    static var all: [Self] {
        CreationMode.allCases.map(Self.creation)
            + [.fanGallery, .album, .colorRelationship, .scanner, .video, .developing, .stamp, .postcard, .collection, .postalCollection, .solarColors, .photoBacks]
    }

    var id: String {
        switch self {
        case .creation(let mode): mode.rawValue
        case .fanGallery: "fanGallery"
        case .album: "album"
        case .colorRelationship: "colorRelationship"
        case .scanner: "scanner"
        case .video: "video"
        case .developing: "developing"
        case .collection: "collection"
        case .stamp: "stamp"
        case .postcard: "postcard"
        case .postalCollection: "postalCollection"
        case .solarColors: "solarColors"
        case .photoBacks: "photoBacks"
        }
    }

    var title: String {
        switch self {
        case .creation(let mode): mode.title
        case .fanGallery: "流光折扇".appLocalized
        case .album: "影像相簿".appLocalized
        case .colorRelationship: "色彩关系".appLocalized
        case .scanner: "扫描验证票根".appLocalized
        case .video: "视频转实况".appLocalized
        case .developing: "票根显影".appLocalized
        case .collection: "票根集".appLocalized
        case .stamp: "邮票制作".appLocalized
        case .postcard: "明信片".appLocalized
        case .postalCollection: "邮集".appLocalized
        case .solarColors: "节气寻色".appLocalized
        case .photoBacks: "照片背面".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .creation(let mode): mode.symbol
        case .fanGallery: "fan"
        case .album: "book.pages"
        case .colorRelationship: "point.3.connected.trianglepath.dotted"
        case .scanner: "qrcode.viewfinder"
        case .video: "video"
        case .developing: "viewfinder"
        case .collection: "ticket.fill"
        case .stamp: "photo.artframe"
        case .postcard: "envelope"
        case .postalCollection: "book.closed"
        case .solarColors: "camera.macro.circle"
        case .photoBacks: "arrow.triangle.2.circlepath.camera"
        }
    }
}

struct IPadModeButtons: View {
    let selection: IPadWorkspaceEntry
    let compact: Bool
    let width: CGFloat
    let disabled: Bool
    let onSelect: (IPadWorkspaceEntry) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var buttonHeight: CGFloat = 48
    @State private var labelPresented: IPadWorkspaceEntry?
    @AppStorage("didShowIPadSidebarCollapseHint") private var didShowCollapseHint = false

    @State private var collapsed = false
    @State private var contentMinY: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var scrollRequest: ScrollRequest?
    @State private var isPreparingCollapse = false
    @State private var showCollapseHint = false
    @State private var lastInteraction = Date()
    @State private var collapseWorkItem: DispatchWorkItem?

    private let idleDelay: TimeInterval = 5
    private let baseSpacing: CGFloat = 9
    private let minSpacing: CGFloat = 4
    private let minButtonHeight: CGFloat = 40

    private enum ScrollRequest: Equatable {
        case revealSelection
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = fittedMetrics(for: proxy.size.height)
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    column(metrics: metrics)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(
                            key: ContentMinYKey.self,
                            value: geometry.frame(in: .named("ipadModes")).minY
                        )
                    })
                }
                .scrollDisabled(collapsed)
                .scrollBounceBehavior(.basedOnSize)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .coordinateSpace(name: "ipadModes")
                .onPreferenceChange(ContentMinYKey.self) { minY in
                    contentMinY = minY
                }
                .accessibilityIdentifier("ipad.modeButtons")
                .onAppear { viewportHeight = proxy.size.height }
                .onChange(of: selection) { _, entry in
                    if collapsed {
                        expand()
                    }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        reader.scrollTo(entry.id, anchor: nil)
                    }
                }
                .onChange(of: scrollRequest) { _, request in
                    guard request == .revealSelection else { return }
                    // Reveal immediately so scrolling cannot restart or cancel
                    // the collapse, and the remaining button stays reachable.
                    reader.scrollTo(selection.id, anchor: .center)
                    scrollRequest = nil
                }
                .onChange(of: disabled) { _, isDisabled in
                    if isDisabled { cancelIdleTimer() } else { scheduleIdleTimer() }
                }
                .onChange(of: labelPresented) { _, _ in
                    scheduleIdleTimer()
                }
                .onChange(of: proxy.size.height) { _, height in
                    viewportHeight = height
                }
            }
        }
        .frame(width: width)
        .onAppear { bumpIdle() }
        .onDisappear { cancelIdleTimer() }
        .task(id: collapsed) {
            if collapsed {
                if !didShowCollapseHint {
                    didShowCollapseHint = true
                    withAnimation(.easeOut(duration: 0.3)) { showCollapseHint = true }
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    withAnimation(.easeIn(duration: 0.3)) { showCollapseHint = false }
                }
            }
        }
    }



    private var canAutoCollapse: Bool {
        !collapsed
            && !disabled
            && labelPresented == nil
            && !UIAccessibility.isVoiceOverRunning
    }

    private func bumpIdle() {
        // Only a mode button click (or the initial appearance) starts a new
        // five-second idle period. Hovering and scrolling do not extend it.
        lastInteraction = Date()
        isPreparingCollapse = false
        scheduleIdleTimer()
    }

    private func scheduleIdleTimer() {
        cancelIdleTimer()
        guard canAutoCollapse else { return }
        let remaining = max(0, idleDelay - Date().timeIntervalSince(lastInteraction))
        let item = DispatchWorkItem { attemptCollapse() }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: item)
    }

    private func cancelIdleTimer() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    private func attemptCollapse() {
        collapseWorkItem = nil
        guard canAutoCollapse, Date().timeIntervalSince(lastInteraction) >= idleDelay - 0.05 else { return }
        if isSelectedVisibleInViewport() {
            performCollapse()
        } else {
            isPreparingCollapse = true
            scrollRequest = .revealSelection
            let item = DispatchWorkItem { performCollapse() }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
        }
    }

    private func performCollapse() {
        collapseWorkItem = nil
        guard canAutoCollapse else { return }
        // A new button click must win over a pending collapse. Do not restart
        // the idle period for geometry changes after revealing the selection.
        if Date().timeIntervalSince(lastInteraction) < idleDelay - 0.05 {
            scheduleIdleTimer()
            return
        }
        isPreparingCollapse = false
        withAnimation(baseCollapseAnimation) {
            collapsed = true
        }
    }

    private func expand() {
        isPreparingCollapse = false
        withAnimation(baseCollapseAnimation) {
            collapsed = false
        }
        bumpIdle()
    }

    private func column(metrics: (buttonHeight: CGFloat, spacing: CGFloat)) -> some View {
        let selectedIndex = max(0, IPadWorkspaceEntry.all.firstIndex(of: selection) ?? 0)
        return VStack(spacing: 0) {
            ForEach(Array(IPadWorkspaceEntry.all.enumerated()), id: \.element.id) { index, entry in
                let isSelected = index == selectedIndex
                modeButton(
                    entry,
                    height: metrics.buttonHeight,
                    isSelectedCollapsed: collapsed && isSelected
                ) {
                    if collapsed {
                        expand()
                    } else {
                        bumpIdle()
                        onSelect(entry)
                    }
                }
                .id(entry.id)
                .frame(height: metrics.buttonHeight)
                .background {
                    if collapsed && isSelected {
                        deckShadow
                    }
                }
                .scaleEffect(
                    collapsed && !isSelected ? 0.3 : 1,
                    anchor: index < selectedIndex ? .bottom : .top
                )
                .offset(
                    y: collapsed && !isSelected
                        ? CGFloat(selectedIndex - index) * (metrics.buttonHeight + metrics.spacing)
                        : 0
                )
                .padding(.bottom, metrics.spacing)
                .opacity(collapsed && !isSelected ? 0 : 1)
                .allowsHitTesting(!collapsed || isSelected)
                .accessibilityHidden(collapsed && !isSelected)
                .animation(collapseAnimation(index: index, selectedIndex: selectedIndex), value: collapsed)
                .overlay {
                    if collapsed && isSelected && showCollapseHint {
                        collapseHint
                            .offset(y: metrics.buttonHeight + 22)
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    private func isSelectedVisibleInViewport() -> Bool {
        guard viewportHeight > 0 else { return true }
        let metrics = fittedMetrics(for: viewportHeight)
        let index = max(0, IPadWorkspaceEntry.all.firstIndex(of: selection) ?? 0)
        let top = contentMinY + 8 + CGFloat(index) * (metrics.buttonHeight + metrics.spacing)
        let bottom = top + metrics.buttonHeight
        return top >= 0 && bottom <= viewportHeight
    }

    private var baseCollapseAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.86)
    }

    private func collapseAnimation(index: Int, selectedIndex: Int) -> Animation {
        baseCollapseAnimation.delay(Double(abs(index - selectedIndex)) * 0.028)
    }

    private var collapseHint: some View {
        Text("轻点展开切换模式")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .fixedSize()
            .zIndex(1)
            .allowsHitTesting(false)
    }


    private func fittedMetrics(for availableHeight: CGFloat) -> (buttonHeight: CGFloat, spacing: CGFloat) {
        let base = max(48, buttonHeight)
        guard !dynamicTypeSize.isAccessibilitySize else { return (base, baseSpacing) }
        let count = CGFloat(IPadWorkspaceEntry.all.count)
        let content = availableHeight - 16
        guard content > 0, count * base + (count - 1) * baseSpacing > content else {
            return (base, baseSpacing)
        }


        let ratio = baseSpacing / base
        var height = content / (count + (count - 1) * ratio)
        var spacing = height * ratio
        if height < minButtonHeight {
            height = minButtonHeight
            spacing = (content - count * height) / (count - 1)
        }
        if spacing < minSpacing {
            spacing = minSpacing
            height = max(minButtonHeight, (content - (count - 1) * spacing) / count)
        }
        return (height, spacing)
    }


    private var deckShadow: some View {
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(0.10))
                .padding(.horizontal, 10)
                .offset(y: 7)
            Capsule()
                .fill(Color.primary.opacity(0.05))
                .padding(.horizontal, 20)
                .offset(y: 13)
        }
    }

    private func modeButton(
        _ entry: IPadWorkspaceEntry,
        height: CGFloat,
        isSelectedCollapsed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let selected = selection == entry
        return Button(action: action, label: {
            HStack(spacing: 8) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 18, weight: selected ? .semibold : .medium))
                    .frame(width: 20, height: 20)
                if !compact {
                    Text(entry.title)
                        .font(.subheadline.weight(selected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 10)
                        .opacity(selected ? 1 : 0)
                        .accessibilityHidden(true)
                    if isSelectedCollapsed {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.7)
                            .accessibilityHidden(true)
                    }
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.horizontal, compact ? 0 : 10)
            .padding(.vertical, 8)
            .frame(width: compact ? 48 : width - 16, height: height)
            .contentShape(Capsule())
        })
        .buttonStyle(.plain)
        .modifier(IPadModeGlass(selected: selected, reduceTransparency: reduceTransparency))
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityLabel(entry.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("ipad.mode.\(entry.id)")
        .help(entry.title)
        .onLongPressGesture { if compact { labelPresented = entry } }
        .popover(isPresented: Binding(
            get: { labelPresented == entry },
            set: { if !$0 { labelPresented = nil } }
        )) {
            Text(entry.title).font(.headline).padding(20)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct ContentMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct IPadModeGlass: ViewModifier {
    let selected: Bool
    let reduceTransparency: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(selected ? Color.black : Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else if #available(iOS 26.0, *) {
            if selected {
                content.glassEffect(.clear.tint(.black.opacity(0.85)).interactive(), in: Capsule())
            } else {
                content.glassEffect(.clear.interactive(), in: Capsule())
            }
        } else {
            content
                .background { if selected { Capsule().fill(.black.opacity(0.85)) } }
                .liquidGlass(in: Capsule(), interactive: true)
        }
    }
}


struct IPadCompositionDraft {
    var ratio: ArtworkRatio
    var imageScale: CGFloat
    var imageOffset: CGSize
    var paletteOffset: CGFloat
    var glassArchiveBarPosition: CGFloat
    var bubbleScale: CGFloat
    var textScale: CGFloat
    var fontStyle: ArtworkFontStyle
    var journalTransforms: [JournalPhotoTransform]
    var selectedJournalIndex: Int?
}
