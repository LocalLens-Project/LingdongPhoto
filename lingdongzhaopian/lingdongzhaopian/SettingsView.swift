import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private static let maintenanceStatementText =
        "本开源代码项目由 Wenzhou Dulan Network Technology Co., Ltd. 倾力维护与托管。"

    private static let sourceRepositoryURL = URL(
        string: "https://github.com/LocalLens-Project/LingdongPhoto"
    )!
    private static let appStoreReviewURL = URL(
        string: "https://apps.apple.com/app/id6791514422?action=write-review"
    )!

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var ratio: ArtworkRatio
    @Binding var showHexValues: Bool
    @Binding var useCustomCameraWatermarks: Bool
    @Binding var gentleBackground: Bool
    @ObservedObject var cameraWatermarkLibrary: CameraWatermarkLibrary

    @AppStorage("supportsLivePhotos") private var supportsLivePhotos = true
    @AppStorage("useLiteraryColorNames") private var useLiteraryColorNames = false
    @AppStorage("poeticNamesEnabled") private var poeticNamesEnabled = false
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @AppStorage("preservePaletteBackground") private var preservePaletteBackground = true
    @AppStorage("paletteLayout") private var paletteLayoutRaw = PaletteLayoutMode.floating.rawValue
    @AppStorage("applyLiquidGlassOnExport") private var applyLiquidGlassOnExport = true
    @AppStorage("showAppTitle") private var showAppTitle = true
    @AppStorage("showSupporterBadge") private var showSupporterBadge = false
    @AppStorage("showPalettePercentages") private var showPalettePercentages = true
    @AppStorage("emptyCanvasTheme") private var emptyCanvasThemeRaw = EmptyCanvasTheme.sky.rawValue
    @AppStorage("modeLauncherStyle") private var modeLauncherStyleRaw = ModeLauncherStyle.floatingMenu.rawValue
    @State private var cameraWatermarkManagerPresented = false
    @State private var workManagerPresented = false
    @State private var sourceRepositoryConfirmationPresented = false
    @State private var legalPage: URL?
    @State private var qqGroupCopied = false
    @State private var emailCopied = false
    @State private var savedWorkCount = 0
    @State private var savedWorkByteCount: Int64 = 0
    @State private var supportUsPresented = false
    @State private var poeticNamesNoticePresented = false
    @State private var emptyCanvasThemePickerPresented = false
    @State private var applicationIconPickerPresented = false
    @State private var modeLauncherPickerPresented = false
    @State private var supporterBadgePromptPresented = false
    @State private var supporterBadgePromptDismissTask: Task<Void, Never>?

    private var isSimplifiedChineseLocalization: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh-Hans") == true
    }
    private var currentModeLauncherStyle: ModeLauncherStyle {
        ModeLauncherStyle(rawValue: modeLauncherStyleRaw) ?? .floatingMenu
    }
    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    private var activeWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
    private var supportsIslandLauncher: Bool {
        TicketIslandAvailability.isSupported(
            screenSize: activeWindow?.windowScene?.screen.bounds.size ?? .zero,
            safeAreaTop: activeWindow?.safeAreaInsets.top ?? 0
        )
    }

    var body: some View {
        NavigationStack {
            settingsScrollContent
            .background(settingsOuterBackground.ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if usesWideLayout {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                            .font(.body.weight(.semibold))
                            .accessibilityIdentifier("ipad.settings.done")
                    }
                }
            }
            .navigationDestination(isPresented: $cameraWatermarkManagerPresented) {
                CameraWatermarkManagerView(
                    isEnabled: $useCustomCameraWatermarks,
                    library: cameraWatermarkLibrary
                )
            }
            .navigationDestination(isPresented: $workManagerPresented) {
                LingdongWorkManagerView(onLibraryChanged: refreshWorkArchiveSummary)
            }
            .navigationDestination(isPresented: $applicationIconPickerPresented) {
                ApplicationIconPicker()
            }
            .navigationDestination(isPresented: $modeLauncherPickerPresented) {
                ModeLauncherSettingsView(supportsIsland: supportsIslandLauncher)
            }
            .onAppear(perform: refreshWorkArchiveSummary)
            .alert("将在默认浏览器中打开", isPresented: $sourceRepositoryConfirmationPresented) {
                Button("取消", role: .cancel) {}
                Button("确认打开") {
                    openURL(legalPage ?? Self.sourceRepositoryURL)
                }
            } message: {
                Text("网页将由系统默认浏览器联网加载。此公开版本包含本机照片创作；来信服务的隐私与加密边界见公开版本说明。")
            }
            .alert("二十四节气色名已开启", isPresented: $poeticNamesNoticePresented) {
                Button("知道了", role: .cancel) {}
                if !supporterUnlocked {
                    Button("了解支持我们") {
                        supportUsPresented = true
                    }
                }
            } message: {
                Text((supporterUnlocked
                     ? "节气匹配色名与可考出处均可直接查看。"
                     : "节气匹配色名可直接查看；可考出处需在“支持我们”后解锁。").appLocalized)
            }
            .fullScreenCover(isPresented: $supportUsPresented) {
                SupportUsView {
                    poeticNamesEnabled = true
                }
            }
            .sheet(isPresented: $emptyCanvasThemePickerPresented) {
                EmptyCanvasThemePicker(selection: emptyCanvasThemeBinding)
                    .presentationDetents([.height(560)])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(nil)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
        .onChange(of: supporterUnlocked) { _, unlocked in
            if unlocked {
                supporterBadgePromptDismissTask?.cancel()
                withAnimation(.easeOut(duration: 0.18)) {
                    supporterBadgePromptPresented = false
                }
            }
        }
        .onDisappear {
            supporterBadgePromptDismissTask?.cancel()
        }
        .overlay(alignment: .bottom) {
            if supporterBadgePromptPresented && !supporterUnlocked {
                SupporterProUnlockPrompt(
                    message: showAppTitle
                        ? "支持我们，即可在“灵动照片”标题旁显示 PRO 标志。"
                        : "支持我们即可在标题处显示 PRO 标志。"
                ) {
                    supporterBadgePromptDismissTask?.cancel()
                    withAnimation(.easeOut(duration: 0.18)) {
                        supporterBadgePromptPresented = false
                    }
                    supportUsPresented = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .tint(.blue)
    }

    @ViewBuilder
    private var settingsScrollContent: some View {
        let content = ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                projectSupportSection
                PublicEditionInfoCard()
                legalLinks
                interfaceOptions
                storageAndWorks
                paletteOptions
                motionTips
                stampTips
                journalOptions
                wallpaperOptions
                privacyOptions
                supportAndContactSection

                VStack(spacing: 10) {
                    Text("版本 4.0.0 (Build 202649)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("灵动照片 · 开源代码项目")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if isSimplifiedChineseLocalization {
                        Text("浙ICP备2026035179号-6A")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityLabel("ICP备案号：浙ICP备2026035179号-6A")
                    }
                }
                .frame(maxWidth: .infinity)

                maintenanceStatement
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }

        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }

    private var maintenanceStatement: some View {
        Text(LocalizedStringKey(Self.maintenanceStatementText))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.maintenanceStatementText)
    }

    private var projectSupportSection: some View {
        VStack(spacing: 0) {
            supportCraftButton
                .padding(8)

            Divider()
                .padding(.horizontal, 18)

            Button {
                legalPage = nil; sourceRepositoryConfirmationPresented = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("开源代码地址")
                            .font(.subheadline.weight(.semibold))
                        Text("github.com/LocalLens-Project/LingdongPhoto")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开灵动照片 GitHub 开源代码地址")
            .accessibilityHint("确认后将在系统默认浏览器中打开；普通创作照片仅在本机处理")
        }
        .background(settingsCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var legalLinks: some View {
        VStack(spacing: 0) {
            legalLink(String(localized: "隐私政策"), symbol: "hand.raised", page: .privacy)
            Divider().padding(.horizontal, 18)
            legalLink(String(localized: "用户协议"), symbol: "doc.text", page: .terms)
        }.background(settingsCardBackground, in: RoundedRectangle(cornerRadius: 28))
    }
    private func legalLink(_ title: String, symbol: String, page: PublicEditionLegal.Page) -> some View {
        Button { legalPage = PublicEditionLegal.url(page); sourceRepositoryConfirmationPresented = true } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).frame(width: 30)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
            }.foregroundStyle(.primary).padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 62).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(page == .privacy ? "settings.privacy" : "settings.terms")
    }

    private var supportCraftButton: some View {
        Button {
            supportUsPresented = true
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text((supporterUnlocked ? "感谢支持" : "支持我们").appLocalized)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        ProBadge(compact: true)
                    }

                    Text((supporterUnlocked
                         ? "所有PRO功能都已解锁"
                         : "开源代码项目 · 持续维护").appLocalized)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer(minLength: 4)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.22, blue: 0.25),
                            Color(red: 0.20, green: 0.38, blue: 0.41),
                            Color(red: 0.38, green: 0.24, blue: 0.27)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    SupportCraftSheen(reduceMotion: reduceMotion)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 0.8)
            }
            .shadow(color: Color(red: 0.12, green: 0.35, blue: 0.38).opacity(0.18), radius: 16, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel((supporterUnlocked ? "感谢支持，支持者礼物已解锁" : "支持我们，了解支持者礼物").appLocalized)
    }

    private var supportAndContactSection: some View {
        VStack(spacing: 0) {
            Button {
                openURL(Self.appStoreReviewURL)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 30)
                        .foregroundStyle(Color.primary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("评分")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text("前往 App Store 为灵动照片评分")
                            .font(.caption)
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("在 App Store 为灵动照片评分")
            .accessibilityHint("将打开 App Store 的评分与评论页面")

            sectionDivider

            if isSimplifiedChineseLocalization {
                Button {
                    UIPasteboard.general.string = "1050047342"
                    withAnimation(.snappy) {
                        qqGroupCopied = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(.snappy) {
                            qqGroupCopied = false
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 30)
                            .foregroundStyle(Color.primary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("用户交流群")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Text(qqGroupCopied ? "群号已复制，请在 QQ 中搜索添加" : "QQ 群：1050047342")
                                .font(.caption)
                                .foregroundStyle(qqGroupCopied ? .green : Color(UIColor.secondaryLabel))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: qqGroupCopied ? "checkmark.circle.fill" : "doc.on.clipboard")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(qqGroupCopied ? .green : Color(UIColor.tertiaryLabel))
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("复制 QQ 用户交流群号")
                .accessibilityHint("群号 1050047342 将被复制到剪贴板")

                sectionDivider
            }

            Button {
                UIPasteboard.general.string = "help@moerzhi.com"
                withAnimation(.snappy) {
                    emailCopied = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.snappy) {
                        emailCopied = false
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 30)
                        .foregroundStyle(Color.primary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("客服邮箱")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text(emailCopied ? "邮箱已复制" : "help@moerzhi.com")
                            .font(.caption)
                            .foregroundStyle(emailCopied ? .green : Color(UIColor.secondaryLabel))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: emailCopied ? "checkmark.circle.fill" : "doc.on.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(emailCopied ? .green : Color(UIColor.tertiaryLabel))
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("复制客服邮箱地址")
            .accessibilityHint("邮箱 help@moerzhi.com 将被复制到剪贴板")

            sectionDivider
            tipRow(symbol: "c.circle", text: "项目源代码公开；请通过官方渠道获取应用")
        }
        .background(settingsCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var paletteOptions: some View {
        settingsSection("琉璃色盘选项") {
            VStack(spacing: 0) {
                SettingRow(symbol: "rectangle.3.group", title: "排版模式") {
                    Picker("排版模式", selection: paletteLayoutBinding) {
                        ForEach(PaletteLayoutMode.allCases) { layout in
                            Text(LocalizedStringKey(layout.rawValue)).tag(layout)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .tint(.blue)
                }
                sectionDivider
                tipRow(symbol: "info.circle", text: "iOS 26+ 使用系统液态玻璃；旧系统自动使用兼容磨砂效果。导出时也会按下方开关生成玻璃质感。")
                sectionDivider
                tipRow(symbol: "hand.draw", text: "拖动色盘可调整其上下位置")
                sectionDivider
                ratioRow
                sectionDivider
                toggleRow(symbol: "livephoto", title: "支持 Live 图", value: $supportsLivePhotos)
                sectionDivider
                toggleRow(symbol: "number.square", title: "显示颜色值", value: $showHexValues)
                sectionDivider
                toggleRow(
                    symbol: "percent",
                    title: "显示颜色占比",
                    subtitle: "关闭后，琉璃色盘将不再显示各颜色所占百分比。",
                    value: $showPalettePercentages
                )
                sectionDivider
                toggleRow(
                    symbol: "leaf",
                    title: "用颜色名称替换颜色码",
                    subtitle: "将颜色代码替换为极具文学气息的自然命名。",
                    value: $useLiteraryColorNames
                )
                sectionDivider
                toggleRow(
                    symbol: "text.book.closed",
                    title: "以二十四节气替换",
                    subtitle: "节气匹配色名可直接使用；\n可考出处需",
                    showsProBadge: true,
                    value: poeticNamesBinding
                )
                sectionDivider
                toggleRow(symbol: "square", title: "导出图保留色盘背景", value: $preservePaletteBackground)
                sectionDivider
                SettingRow(
                    symbol: "rainbow",
                    title: "保存的图片应用液态玻璃质感",
                    subtitle: "关闭后导出为更轻量的经典磨砂面板。"
                ) {
                    Toggle("", isOn: $applyLiquidGlassOnExport)
                        .labelsHidden()
                }
            }
        }
    }

    private var interfaceOptions: some View {
        VStack(spacing: 10) {
            settingsSection("界面选项") {
                VStack(spacing: 0) {
                    Button { applicationIconPickerPresented = true } label: {
                        SettingRow(symbol: "app.badge", title: "更换应用图标", showsProBadge: true) {
                            HStack(spacing: 9) {
                                CurrentApplicationIcon()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.appIcon")
                    sectionDivider

                    if !ModeLauncherDevice.isDuo {
                        Button { modeLauncherPickerPresented = true } label: {
                            SettingRow(
                                symbol: "rectangle.topthird.inset.filled",
                                title: "模式入口方式",
                                subtitle: "在浮光菜单与灵屿展开之间切换。"
                            ) {
                                HStack(spacing: 7) {
                                    Text(currentModeLauncherStyle.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.modeLauncher")
                        sectionDivider
                    }

                    Button {
                        emptyCanvasThemePickerPresented = true
                    } label: {
                        SettingRow(
                            symbol: "paintpalette",
                            title: "空白主界面配色",
                            subtitle: "调整尚未选择照片时所有功能主页的背景。"
                        ) {
                            HStack(spacing: 9) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(emptyCanvasTheme.gradient)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(.primary.opacity(0.12), lineWidth: 0.7)
                                    }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    sectionDivider

                    toggleRow(
                        symbol: "textformat",
                        title: "显示应用标题",
                        subtitle: "控制编辑界面左上角是否显示“灵动照片”，不影响导出作品。",
                        value: $showAppTitle
                    )

                    sectionDivider

                    Button(action: handleSupporterBadgeSettingTap) {
                        SettingRow(
                            symbol: "checkmark.seal",
                            title: "显示支持者 PRO 标志",
                            subtitle: "控制 PRO 标志在编辑页标题区域的显示。",
                            usesProBadgeAsSymbol: true
                        ) {
                            SupporterLockedSwitch(
                                isOn: supporterUnlocked && showSupporterBadge,
                                isLocked: !supporterUnlocked
                            )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("显示支持者 Pro 标志")
                    .accessibilityValue((supporterUnlocked ? (showSupporterBadge ? "已开启" : "已关闭") : "需支持我们后开启").appLocalized)
                }
            }

        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: supporterBadgePromptPresented)
    }

    private func handleSupporterBadgeSettingTap() {
        if supporterUnlocked {
            withAnimation(.snappy(duration: 0.24)) {
                showSupporterBadge.toggle()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            supporterBadgePromptDismissTask?.cancel()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                supporterBadgePromptPresented = true
            }
            supporterBadgePromptDismissTask = Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.24)) {
                    supporterBadgePromptPresented = false
                }
            }
        }
    }

    private var storageAndWorks: some View {
        settingsSection("存储与作品") {
            Button {
                workManagerPresented = true
            } label: {
                SettingRow(
                    symbol: "photo.stack",
                    title: "管理已保存的作品",
                    subtitle: savedWorkSummary
                ) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("查看、选择或删除应用内保存的作品")
        }
    }

    private var savedWorkSummary: String {
        guard savedWorkCount > 0 else { return "暂无应用内保存的作品" }
        return String(
            format: "共 %lld 件 · %@".appLocalized,
            Int64(savedWorkCount),
            Self.formattedByteCount(savedWorkByteCount)
        )
    }

    private func refreshWorkArchiveSummary() {
        savedWorkCount = LingdongWorkArchive.records().count
        savedWorkByteCount = LingdongWorkArchive.storageByteCount()
    }

    private static func formattedByteCount(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    private var motionTips: some View {
        settingsSection("灵动卡片操作技巧") {
            VStack(spacing: 0) {
                tipRow(symbol: "arrow.up.and.down.and.arrow.left.and.right", text: "拖拽图片调整构图，双指捏合缩放")
                sectionDivider
                tipRow(symbol: "keyboard", text: "点击文字即可直接编辑")
                sectionDivider
                tipRow(symbol: "textformat", text: "自定义字体：在“灵动卡片设定”中选择")
                sectionDivider
                tipRow(symbol: "textformat.size", text: "调节大小：在文字下方空白处左右滑动")
                sectionDivider
                tipRow(symbol: "iphone.radiowaves.left.and.right", text: "晃动手机以恢复卡片初始视图")
            }
        }
    }

    private var stampTips: some View {
        settingsSection("光影签章操作技巧") {
            VStack(spacing: 0) {
                cameraWatermarkNavigationRow
                sectionDivider
                tipRow(symbol: "arrow.up.and.down.and.arrow.left.and.right", text: "拖拽图片调整构图，双指捏合缩放")
                sectionDivider
                tipRow(symbol: "keyboard", text: "点击标题即可编辑（拍摄参数不可编辑）")
                sectionDivider
                tipRow(symbol: "textformat", text: "自定义字体：在“气泡印章设定”中选择")
                sectionDivider
                tipRow(symbol: "textformat.size", text: "调节大小：在文字下方空白处左右滑动")
                sectionDivider
                tipRow(symbol: "bubbles.and.sparkles", text: "调节气泡大小：在气泡左侧空白区域上下滑动")
            }
        }
    }

    private var cameraWatermarkNavigationRow: some View {
        Button {
            cameraWatermarkManagerPresented = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("相机图标水印")
                        .font(.headline)

                    Text(
                        cameraWatermarkLibrary.importedBrandCount == 0
                            ? "从“文件”App 为相机品牌添加本地 PNG"
                            : "已添加 \(cameraWatermarkLibrary.importedBrandCount) 个品牌"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(useCustomCameraWatermarks ? "已启用" : "未启用")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(useCustomCameraWatermarks ? .blue : .secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开相机图标水印管理界面")
    }

    private var journalOptions: some View {
        settingsSection("一键手帐选项") {
            VStack(spacing: 0) {
                tipRow(symbol: "info.circle", text: "使用顶部加号继续添加，选中缩略图后可替换、重排或删除；点击 Emoji 或文案可直接编辑")
                sectionDivider
                ratioRow
                sectionDivider
                toggleRow(symbol: "livephoto", title: "支持 Live 图", value: $supportsLivePhotos)
                sectionDivider
                toggleRow(symbol: "square", title: "淡雅背景色", value: $gentleBackground)
            }
        }
    }

    private var wallpaperOptions: some View {
        settingsSection("色谱壁纸选项") {
            tipRow(symbol: "info.circle", text: "生成的壁纸仅适配当前设备尺寸")
        }
    }

    private var privacyOptions: some View {
        settingsSection("隐私马赛克选项") {
            VStack(spacing: 0) {
                tipRow(symbol: "hand.draw", text: "进入“手动涂抹”后，单指用于添加或擦除马赛克；完成后恢复拖动照片")
                sectionDivider
                tipRow(symbol: "viewfinder", text: "智能识别会在本机检测人脸、车牌、二维码及手机号、地址、证件号等敏感文字")
                sectionDivider
                tipRow(symbol: "eye.slash", text: "点击自动识别区域可关闭遮挡，再次点击即可恢复；手动画笔可切换为橡皮擦")
                sectionDivider
                tipRow(symbol: "circle.grid.3x3.fill", text: "导出使用明确的强模糊像素马赛克，不使用可能看清原内容的透明玻璃遮挡")
                sectionDivider
                tipRow(symbol: "livephoto.slash", text: "为避免后续动态帧泄露隐私，隐私马赛克仅支持静态导出")
                sectionDivider
                tipRow(symbol: "location.slash", text: "保存前可选择移除 GPS 位置信息，形成完整的隐私导出")
            }
        }
    }

    private var ratioRow: some View {
        SettingRow(symbol: "rectangle.split.2x1", title: "图片比例") {
            Picker("图片比例", selection: $ratio) {
                ForEach(ArtworkRatio.allCases) { item in
                    Text(LocalizedStringKey(item.rawValue)).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.blue)
        }
    }

    private var paletteLayoutBinding: Binding<PaletteLayoutMode> {
        Binding(
            get: { PaletteLayoutMode(rawValue: paletteLayoutRaw) ?? .floating },
            set: { paletteLayoutRaw = $0.rawValue }
        )
    }

    private var poeticNamesBinding: Binding<Bool> {
        Binding(
            get: { poeticNamesEnabled },
            set: { newValue in
                poeticNamesEnabled = newValue
                if newValue {
                    poeticNamesNoticePresented = true
                }
            }
        )
    }

    private var emptyCanvasTheme: EmptyCanvasTheme {
        EmptyCanvasTheme(rawValue: emptyCanvasThemeRaw) ?? .sky
    }

    private var emptyCanvasThemeBinding: Binding<EmptyCanvasTheme> {
        Binding(
            get: { emptyCanvasTheme },
            set: { emptyCanvasThemeRaw = $0.rawValue }
        )
    }

    private var sectionDivider: some View {
        Divider().padding(.leading, 68)
    }

    private func toggleRow(
        symbol: String,
        title: String,
        subtitle: String? = nil,
        showsProBadge: Bool = false,
        showsNewBadge: Bool = false,
        value: Binding<Bool>
    ) -> some View {
        SettingRow(
            symbol: symbol,
            title: title,
            subtitle: subtitle,
            showsProBadge: showsProBadge,
            showsNewBadge: showsNewBadge
        ) {
            Toggle(title, isOn: value)
                .labelsHidden()
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)

            content()
                .frame(maxWidth: .infinity)
                .background(settingsCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var settingsOuterBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.12)
            : Color(uiColor: .systemGroupedBackground)
    }

    private var settingsCardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.17, green: 0.17, blue: 0.18)
            : Color.white
    }

    private func tipRow(symbol: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 34)
            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

struct SupporterLockedSwitch: View {
    let isOn: Bool
    let isLocked: Bool

    var body: some View {
        Toggle("", isOn: .constant(isOn))
            .labelsHidden()
            .tint(Color(red: 0.34, green: 0.72, blue: 0.70))
            .allowsHitTesting(false)
            .overlay {
                if isLocked {
                    GeometryReader { geometry in
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .position(
                                x: isOn ? geometry.size.width - 20 : 20,
                                y: geometry.size.height / 2
                            )
                    }
                    .allowsHitTesting(false)
                }
            }
        .accessibilityHidden(true)
    }
}

struct SupporterProUnlockPrompt: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            AnimatedSupporterProBadge()
                .frame(width: 44, height: 44)

            Text(LocalizedStringKey(message))
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("打开", action: onOpen)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.55, green: 0.88, blue: 0.92))
                .buttonStyle(.plain)
                .padding(.leading, 2)
        }
        .padding(.leading, 10)
        .padding(.trailing, 17)
        .padding(.vertical, 10)
        .background(
            colorScheme == .dark
                ? Color(red: 0.10, green: 0.11, blue: 0.12)
                : Color(red: 0.33, green: 0.34, blue: 0.36),
            in: RoundedRectangle(cornerRadius: 27, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.16), Color(red: 0.48, green: 0.80, blue: 0.82).opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.18), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }
}

struct AnimatedSupporterProBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    private let letters = Array("PRO")
    private let cycleDuration = 1.55

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            let time = elapsed.truncatingRemainder(dividingBy: cycleDuration)

            HStack(spacing: 0.8) {
                ForEach(letters.indices, id: \.self) { index in
                    Text(String(letters[index]))
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .scaleEffect(reduceMotion ? 1 : letterScale(index: index, time: time))
                }
            }
            .tracking(0.15)
            .foregroundStyle(Color(red: 0.08, green: 0.16, blue: 0.20))
            .frame(width: 37, height: 21)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.67, green: 0.90, blue: 0.92),
                        Color(red: 0.95, green: 0.78, blue: 0.66)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.68), lineWidth: 0.65))
            .shadow(color: Color(red: 0.48, green: 0.78, blue: 0.82).opacity(0.24), radius: 6, y: 2)
        }
        .frame(width: 42, height: 42)
        .onAppear { startedAt = Date() }
        .accessibilityHidden(true)
    }

    private func letterScale(index: Int, time: TimeInterval) -> CGFloat {
        let centers = [0.22, 0.52, 0.82]
        let distance = abs(time - centers[index])
        let wrappedDistance = min(distance, cycleDuration - distance)
        let linearPulse = max(0, 1 - wrappedDistance / 0.31)
        let easedPulse = 0.5 - 0.5 * cos(.pi * linearPulse)
        return 1 + 0.20 * easedPulse
    }
}

private struct EmptyCanvasThemePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var selection: EmptyCanvasTheme
    @State private var draft: EmptyCanvasTheme

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 11),
        count: 3
    )

    init(selection: Binding<EmptyCanvasTheme>) {
        _selection = selection
        _draft = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("主界面调色盘")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    Text("选择尚未添加照片时的主页釉彩")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消选择主界面配色")
            }

            LazyVGrid(columns: columns, spacing: 11) {
                ForEach(EmptyCanvasTheme.allCases) { theme in
                    Button {
                        withAnimation(.snappy(duration: 0.24)) {
                            draft = theme
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(theme.gradient)

                            LinearGradient(
                                colors: [.clear, .black.opacity(0.34)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            Text(LocalizedStringKey(theme.rawValue))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(10)

                            if draft == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.38))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(8)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    draft == theme ? .white.opacity(0.88) : .white.opacity(0.15),
                                    lineWidth: draft == theme ? 2 : 0.7
                                )
                        }
                        .scaleEffect(draft == theme ? 0.96 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.rawValue)主界面配色")
                    .accessibilityAddTraits(draft == theme ? .isSelected : [])
                }
            }

            Button {
                selection = draft
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } label: {
                Text("确认应用 · \(draft.rawValue)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(draft.gradient, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }
}

private struct SupportCraftSheen: View {
    let reduceMotion: Bool

    @State private var startedAt = Date()

    private let cycleDuration = 2.8
    private let activeStart = 0.65
    private let activeDuration = 1.25

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration)
                let isActive = phase >= activeStart && phase <= activeStart + activeDuration
                let progress = min(max((phase - activeStart) / activeDuration, 0), 1)
                let bandWidth = geometry.size.width * 0.32
                let travelStart = -bandWidth * 0.45
                let travelEnd = geometry.size.width + bandWidth * 0.45
                let centerX = travelStart + (travelEnd - travelStart) * progress
                let fadeIn = min(progress / 0.14, 1)
                let fadeOut = min((1 - progress) / 0.18, 1)
                let envelope = isActive ? min(fadeIn, fadeOut) : 0

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.02), location: 0.15),
                        .init(color: .white.opacity(0.10), location: 0.34),
                        .init(color: .white.opacity(0.32), location: 0.50),
                        .init(color: .white.opacity(0.10), location: 0.66),
                        .init(color: .white.opacity(0.02), location: 0.85),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: bandWidth, height: geometry.size.height * 2.6)
                .blur(radius: 12)
                .rotationEffect(.degrees(8))
                .position(x: centerX, y: geometry.size.height / 2)
                .opacity(reduceMotion ? 0 : envelope)
                .drawingGroup()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SettingRow<Trailing: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    var showsProBadge = false
    var showsNewBadge = false
    var usesProBadgeAsSymbol = false
    @ViewBuilder let trailing: () -> Trailing

    init(
        symbol: String,
        title: String,
        subtitle: String? = nil,
        showsProBadge: Bool = false,
        showsNewBadge: Bool = false,
        usesProBadgeAsSymbol: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.showsProBadge = showsProBadge
        self.showsNewBadge = showsNewBadge
        self.usesProBadgeAsSymbol = usesProBadgeAsSymbol
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if usesProBadgeAsSymbol {
                    ProBadge()
                        .fixedSize()
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(LocalizedStringKey(title))
                        .font(.subheadline)
                    if showsNewBadge {
                        NewBadge()
                            .fixedSize()
                    }
                }
                if let subtitle {
                    let lines = subtitle.split(separator: "\n", omittingEmptySubsequences: false)
                    if showsProBadge, lines.count > 1 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(String(lines[0])))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .center, spacing: 6) {
                                Text(LocalizedStringKey(lines.dropFirst().map(String.init).joined(separator: "\n")))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProBadge(compact: true)
                                    .fixedSize()
                            }
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(LocalizedStringKey(subtitle))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if showsProBadge {
                                ProBadge(compact: true)
                                    .fixedSize()
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 10)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}

private struct LingdongWorkManagerView: View {
    let onLibraryChanged: () -> Void

    @State private var records: [LingdongWorkRecord] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var isSelecting = false
    @State private var previewRecord: LingdongWorkRecord?
    @State private var deleteConfirmationPresented = false
    @State private var deleteErrorMessage: String?
    @State private var storageByteCount: Int64 = 0

    var body: some View {
        Group {
            if records.isEmpty {
                emptyState
            } else {
                workLibrary
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("已保存的作品")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !records.isEmpty {
                    Button(isSelecting ? "完成" : "选择") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isSelecting.toggle()
                            if !isSelecting {
                                selectedIDs.removeAll()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting, !records.isEmpty {
                selectionBar
            }
        }
        .task { reload() }
        .sheet(item: $previewRecord) { record in
            LingdongWorkPreviewView(record: record)
        }
        .alert(
            "删除选中的 \(selectedIDs.count) 件作品？",
            isPresented: $deleteConfirmationPresented
        ) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive, action: deleteSelection)
        } message: {
            Text("只会删除灵动照片应用内保存的作品，不会删除系统相册中的图片，也不会影响已经加入影像相簿的副本。")
        }
        .alert("无法删除作品", isPresented: deleteErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "作品库暂时无法更新，请稍后重试。")
        }
    }

    private var workLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(records.count) 件作品")
                        .font(.headline)
                    Spacer()
                    Text(Self.formattedByteCount(storageByteCount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                LingdongWorkGrid(
                    records: records,
                    selectedIDs: selectedIDs,
                    showsSelection: isSelecting,
                    onSelect: handleSelection
                )

                Text("这里保存的是应用内作品副本。删除不会影响系统相册，也不会影响已经复制到影像相簿中的内容。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, isSelecting ? 20 : 34)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无已保存的作品", systemImage: "photo.stack")
        } description: {
            Text("从创作页面成功保存作品后，它会自动出现在这里。")
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 14) {
            Button(allRecordsAreSelected ? "取消全选" : "全选") {
                withAnimation(.easeInOut(duration: 0.16)) {
                    if allRecordsAreSelected {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(records.map(\.id))
                    }
                }
            }
            .font(.subheadline.weight(.semibold))

            Spacer()

            Button(role: .destructive) {
                deleteConfirmationPresented = true
            } label: {
                Label(
                    selectedIDs.isEmpty ? "删除" : "删除 \(selectedIDs.count) 件",
                    systemImage: "trash"
                )
                .font(.subheadline.weight(.bold))
            }
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .frame(height: 62)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var allRecordsAreSelected: Bool {
        !records.isEmpty && selectedIDs.count == records.count
    }

    private var deleteErrorPresented: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )
    }

    private func handleSelection(_ record: LingdongWorkRecord) {
        if isSelecting {
            withAnimation(.easeInOut(duration: 0.14)) {
                if selectedIDs.contains(record.id) {
                    selectedIDs.remove(record.id)
                } else {
                    selectedIDs.insert(record.id)
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } else {
            previewRecord = record
        }
    }

    private func deleteSelection() {
        do {
            let deletedCount = try LingdongWorkArchive.delete(ids: selectedIDs)
            selectedIDs.removeAll()
            reload()
            if records.isEmpty {
                isSelecting = false
            }
            onLibraryChanged()
            if deletedCount > 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            deleteErrorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func reload() {
        records = LingdongWorkArchive.records()
        storageByteCount = LingdongWorkArchive.storageByteCount()
        selectedIDs.formIntersection(records.map(\.id))
    }

    private static func formattedByteCount(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

private struct LingdongWorkPreviewView: View {
    let record: LingdongWorkRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        if let image = LingdongWorkArchive.image(for: record, thumbnail: false) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ContentUnavailableView(
                                "作品文件不可用",
                                systemImage: "photo.badge.exclamationmark",
                                description: Text("原始作品可能已被系统或其他操作移除。")
                            )
                            .frame(minHeight: 320)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey(record.kindTitle))
                            .font(.headline)
                        Text(
                            record.createdAt,
                            format: .dateTime
                                .locale(Locale(identifier: "zh_Hans_CN"))
                                .year()
                                .month(.wide)
                                .day()
                                .hour()
                                .minute()
                        )
                        Text("\(record.pixelWidth) × \(record.pixelHeight) 像素")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("作品预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
