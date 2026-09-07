


import SwiftUI
import UIKit

enum LocalizedVisualPolicy {
    static func showsOnboardingFeatureImage(languageCode: String, imageName: String) -> Bool {
        if languageCode == "en" { return false }
        if languageCode == "zh-Hant", imageName == "postalcollection" { return false }
        return true
    }

    static func showsOnboardingModeImage(languageCode: String) -> Bool {
        languageCode != "en"
    }

    static func showsModeLauncherScreenshots(languageCode: String) -> Bool {
        languageCode.hasPrefix("zh")
    }
}

enum ModeLauncherStyle: String, CaseIterable, Identifiable {
    case floatingMenu
    case islandReveal

    var id: String { rawValue }
    var title: String {
        switch self {
        case .floatingMenu: "浮光菜单".appLocalized
        case .islandReveal: "灵屿展开".appLocalized
        }
    }
    var detail: String {
        switch self {
        case .floatingMenu: "轻点右上角按钮，在完整菜单中选择功能。".appLocalized
        case .islandReveal: "从灵动岛自然展开，在屏幕顶部直接选择功能。".appLocalized
        }
    }
    var screenshotName: String {
        switch self {
        case .floatingMenu: "launcher_floating_zh-Hans"
        case .islandReveal: "launcher_island_zh-Hans"
        }
    }
}

enum ModeLauncherDestination: Identifiable {
    case creation(CreationMode)
    case fanGallery
    case album
    case colorRelationship
    case ticketDeveloping
    case stamp
    case postcard
    case scanner
    case video
    case ticketCollection
    case postalCollection

    var id: String {
        switch self {
        case .creation(let mode): "creation.\(mode.rawValue)"
        case .fanGallery: "fanGallery"
        case .album: "album"
        case .colorRelationship: "colorRelationship"
        case .ticketDeveloping: "ticketDeveloping"
        case .stamp: "stamp"
        case .postcard: "postcard"
        case .scanner: "scanner"
        case .video: "video"
        case .ticketCollection: "ticketCollection"
        case .postalCollection: "postalCollection"
        }
    }

    var title: String {
        switch self {
        case .creation(let mode): mode.title
        case .fanGallery: "流光折扇".appLocalized
        case .album: "影像相簿".appLocalized
        case .colorRelationship: "色彩关系".appLocalized
        case .ticketDeveloping: "票根显影".appLocalized
        case .stamp: "邮票制作".appLocalized
        case .postcard: "明信片".appLocalized
        case .scanner: "扫描验证票根".appLocalized
        case .video: "视频转实况".appLocalized
        case .ticketCollection: "票根集".appLocalized
        case .postalCollection: "邮集".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .creation(let mode): mode.symbol
        case .fanGallery: "fan"
        case .album: "book.pages"
        case .colorRelationship: "point.3.connected.trianglepath.dotted"
        case .ticketDeveloping: "doc.text.viewfinder"
        case .stamp: "seal"
        case .postcard: "envelope"
        case .scanner: "qrcode.viewfinder"
        case .video: "livephoto"
        case .ticketCollection: "ticket.fill"
        case .postalCollection: "rectangle.portrait.on.rectangle.portrait"
        }
    }

    var accent: Color {
        if case .creation(let mode) = self { return mode.accent }
        return Color(red: 0.76, green: 0.92, blue: 0.67)
    }

    static var all: [Self] {
        CreationMode.allCases.map(Self.creation) + [
            .fanGallery, .album, .colorRelationship, .ticketDeveloping,
            .stamp, .postcard, .scanner, .video, .ticketCollection, .postalCollection,
        ]
    }
}

struct IslandModeLauncher: View {
    let safeAreaTop: CGFloat
    let selectedMode: CreationMode
    let isEnabled: Bool
    let onChoose: (ModeLauncherDestination) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var expansionProgress: CGFloat = 0
    @State private var transitionTask: Task<Void, Never>?
    @State private var settleOffset: CGFloat = 0
    @State private var page = 0

    private let options = ModeLauncherDestination.all
    private var pages: [[ModeLauncherDestination]] {
        stride(from: 0, to: options.count, by: 8).map {
            Array(options[$0..<min($0 + 8, options.count)])
        }
    }



    private var transitionAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.14)
            : .spring(response: 0.45, dampingFraction: 0.92)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.black.opacity(0.10 * expansionProgress)
                    .contentShape(Rectangle())
                    .allowsHitTesting(isExpanded)
                    .onTapGesture { setExpanded(false) }

                islandSurface(screenWidth: proxy.size.width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
        }
        .allowsHitTesting(isEnabled)
        .opacity(isEnabled ? 1 : 0)
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
        }
    }

    private func islandSurface(screenWidth: CGFloat) -> some View {
        let progress = min(max(expansionProgress, 0), 1)
        let expandedWidth = min(max(320, screenWidth - 16), 408)
        let islandWidth: CGFloat = 126
        let width = islandWidth + (expandedWidth - islandWidth) * progress
        let islandHeight: CGFloat = 37
        let expandedHeight = max(340, safeAreaTop + 289)
        let height = islandHeight + (expandedHeight - islandHeight) * progress




        let topInset = max(8, safeAreaTop - 49)
        let contentProgress = min(max((progress - 0.30) / 0.52, 0), 1)



        let cornerRadius = islandHeight / 2 + (38 - islandHeight / 2) * progress

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black)
            .overlay(alignment: .top) {
                contentColumn(width: width, topInset: topInset, progress: contentProgress)
            }
            .overlay(alignment: .bottom) {



                tailButton
                    .offset(y: 16 + settleOffset)
            }
            .frame(width: width, height: height)
            .compositingGroup()
            .shadow(
                color: .black.opacity(0.22 * progress),
                radius: 16 * progress,
                y: 7 * progress
            )
            .offset(y: topInset)
            .accessibilityIdentifier("modeLauncher.expandingSurface")
    }

    private var tailButton: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.84))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .frame(width: 56, height: 28)
                .background(Color.black)
                .clipShape(IslandTailShape())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(transitionAnimation, value: isExpanded)
        .accessibilityLabel((isExpanded ? "收起灵屿展开" : "展开灵屿模式入口").appLocalized)
        .accessibilityIdentifier("modeLauncher.handle")
    }

    private func contentColumn(
        width: CGFloat,
        topInset: CGFloat,
        progress: CGFloat
    ) -> some View {
        VStack(spacing: 0) {


            Color.clear.frame(height: max(44, safeAreaTop - topInset + 1))

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, entries in
                    modePage(entries)
                        .tag(pageIndex)
                        .padding(.horizontal, 13)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: width, height: 240)
            .accessibilityIdentifier("modeLauncher.pages")

            HStack(spacing: 10) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.white : Color.white.opacity(0.34))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(height: 18)

            Spacer(minLength: 8)
        }
        .frame(width: width)
        .opacity(progress)
        .scaleEffect(
            x: 0.82 + 0.18 * progress,
            y: 0.42 + 0.58 * progress,
            anchor: .top
        )
    }

    private func modePage(_ entries: [ModeLauncherDestination]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(entries) { entry in
                Button {
                    setExpanded(false) {
                        onChoose(entry)
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: entry.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isSelected(entry) ? entry.accent : .white.opacity(0.76))
                        Text(entry.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        .white.opacity(isSelected(entry) ? 0.13 : 0.065),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                    .overlay {
                        if isSelected(entry) {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(entry.accent.opacity(0.72), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.title)
                .accessibilityAddTraits(isSelected(entry) ? .isSelected : [])
                .accessibilityIdentifier("modeLauncher.item.\(entry.id)")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func isSelected(_ entry: ModeLauncherDestination) -> Bool {
        if case .creation(let mode) = entry { return mode == selectedMode }
        return false
    }

    private func setExpanded(_ expanded: Bool, completion: (() -> Void)? = nil) {
        transitionTask?.cancel()
        transitionTask = nil
        isExpanded = expanded
        settleOffset = 0

        withAnimation(transitionAnimation) {
            expansionProgress = expanded ? 1 : 0
        }



        if !expanded {
            let duration = reduceMotion ? 0.14 : 0.45
            transitionTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                if !reduceMotion {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.42)) {
                        settleOffset = 5
                    }
                    try? await Task.sleep(for: .seconds(0.16))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) {
                        settleOffset = 0
                    }
                    try? await Task.sleep(for: .seconds(0.4))
                    guard !Task.isCancelled else { return }
                }
                completion?()
                transitionTask = nil
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

private struct IslandTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(14, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ModeLauncherChoiceOverlay: View {
    @Binding var selection: ModeLauncherStyle?
    let onConfirm: () -> Void

    private var showsScreenshots: Bool {
        let language = Locale.preferredLanguages.first ?? "en"
        return LocalizedVisualPolicy.showsModeLauncherScreenshots(languageCode: language)
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.13).ignoresSafeArea()

            VStack(spacing: showsScreenshots ? 18 : 28) {
                VStack(spacing: 7) {
                    Text("选择模式入口")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("选择你更顺手的方式")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: showsScreenshots ? 20 : 34) {
                    ForEach(ModeLauncherStyle.allCases) { style in
                        choice(style)
                    }
                }
                .frame(maxWidth: 440)

                Text("之后可在“设置－模式入口方式”中重新选择。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: onConfirm) {
                    Text("开始使用")
                        .font(.headline)
                        .foregroundStyle(selection == nil ? Color.secondary : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(selection == nil ? Color.gray.opacity(0.24) : Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selection == nil)
                .frame(maxWidth: 430)
                .accessibilityIdentifier("modeLauncherChoice.confirm")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, showsScreenshots ? 18 : 52)
        }
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
    }

    private func choice(_ style: ModeLauncherStyle) -> some View {
        Button { selection = style } label: {
            VStack(spacing: showsScreenshots ? 12 : 16) {
                if showsScreenshots {
                    ModeLauncherScreenshot(name: style.screenshotName)
                        .aspectRatio(0.75, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !showsScreenshots {
                    Text(style.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 58, alignment: .top)
                }

                ZStack {
                    Circle().stroke(.primary.opacity(0.28), lineWidth: 1.5)
                    if selection == style { Circle().fill(.black).padding(5) }
                }
                .frame(width: 27, height: 27)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityValue((selection == style ? "已选择" : "未选择").appLocalized)
        .accessibilityIdentifier("modeLauncherChoice.\(style.rawValue)")
    }
}

struct ModeLauncherSettingsView: View {
    @AppStorage("modeLauncherStyle") private var styleRaw = ModeLauncherStyle.floatingMenu.rawValue
    let supportsIsland: Bool

    private var showsScreenshots: Bool {
        let language = Locale.preferredLanguages.first ?? "en"
        return LocalizedVisualPolicy.showsModeLauncherScreenshots(languageCode: language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("选择模式入口方式")
                    .font(.system(size: 25, weight: .bold, design: .rounded))

                ForEach(ModeLauncherStyle.allCases) { style in
                    Button {
                        guard style != .islandReveal || supportsIsland else { return }
                        styleRaw = style.rawValue
                    } label: {
                        HStack(spacing: 16) {
                            if showsScreenshots {
                                ModeLauncherScreenshot(name: style.screenshotName)
                                    .frame(width: 92, height: 122)
                                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                            }
                            VStack(alignment: .leading, spacing: 7) {
                                Text(style.title).font(.headline).foregroundStyle(.primary)
                                Text(style.detail).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: styleRaw == style.rawValue ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(styleRaw == style.rawValue ? .primary : .tertiary)
                        }
                        .padding(14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .opacity(style == .islandReveal && !supportsIsland ? 0.46 : 1)
                }

                Text((supportsIsland
                      ? "切换后会立即应用。灵屿展开仅在竖屏的灵动岛机型上显示。"
                      : "当前设备不支持灵屿展开，将继续使用浮光菜单。").appLocalized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(22)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("模式入口方式")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct ModeLauncherScreenshot: View {
    let name: String

    var body: some View {
        Group {
            if let image = bundledImage {
                if image.images != nil {

                    AnimatedImageRepresentable(image: image)
                } else {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.title2)
                        Text("待添加截图")
                            .font(.subheadline.weight(.semibold))
                        Text("\(name).gif")
                            .font(.caption2.monospaced())
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
    }

    private var bundledImage: UIImage? {

        for ext in ["png", "gif"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}

struct AnimatedImageRepresentable: UIViewRepresentable {
    let image: UIImage
    var contentMode: UIView.ContentMode = .scaleAspectFill

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = contentMode
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = image
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.image !== image {
            uiView.image = image
        }
        if uiView.contentMode != contentMode {
            uiView.contentMode = contentMode
        }
    }
}
