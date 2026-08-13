// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct SettingsView: View {
    private static let maintenanceStatementText =
        "💖 本开源项目由 Wenzhou Dulan Network Technology Co., Ltd. 倾力维护与托管。"
    private static let maintenanceStatementFirstLine =
        "💖 本开源项目由 Wenzhou Dulan Network Technology"
    private static let maintenanceStatementContinuation =
        "Co., Ltd. 倾力维护与托管。"

    private static let sourceRepositoryURL = URL(
        string: "https://github.com/LocalLens-Project/LingdongPhoto"
    )!

    @Environment(\.openURL) private var openURL
    @Binding var ratio: ArtworkRatio
    @Binding var showHexValues: Bool
    @Binding var showDeviceInfo: Bool
    @Binding var showBubbles: Bool
    @Binding var useCustomCameraWatermarks: Bool
    @Binding var gentleBackground: Bool
    @Binding var templateStyle: ArtworkTemplateStyle
    @Binding var motionCardHeaderStyle: MotionCardHeaderStyle
    @Binding var journalLayout: JournalLayoutMode
    @ObservedObject var cameraWatermarkLibrary: CameraWatermarkLibrary

    @AppStorage("supportsLivePhotos") private var supportsLivePhotos = true
    @AppStorage("useLiteraryColorNames") private var useLiteraryColorNames = false
    @AppStorage("preservePaletteBackground") private var preservePaletteBackground = true
    @AppStorage("showMoodCopy") private var showMoodCopy = false
    @AppStorage("paletteLayout") private var paletteLayoutRaw = PaletteLayoutMode.floating.rawValue
    @AppStorage("applyLiquidGlassOnExport") private var applyLiquidGlassOnExport = true
    @AppStorage("showAppTitle") private var showAppTitle = true
    @AppStorage("showMissingCaptureTime") private var showMissingCaptureTime = true
    @AppStorage("showPalettePercentages") private var showPalettePercentages = true
    @State private var cameraWatermarkManagerPresented = false
    @State private var workManagerPresented = false
    @State private var sourceRepositoryConfirmationPresented = false
    @State private var qqGroupCopied = false
    @State private var emailCopied = false
    @State private var savedWorkCount = 0
    @State private var savedWorkByteCount: Int64 = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("设置")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                    .background(.ultraThinMaterial)
                    .zIndex(5)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        maintenanceStatement
                        qqGroupSection
                        interfaceOptions
                        storageAndWorks
                        paletteOptions
                        motionTips
                        stampTips
                        journalOptions
                        wallpaperOptions
                        privacyOptions

                        VStack(spacing: 10) {
                            Text("版本 2.0.0 (Build 202601)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("灵动照片 · 完全免费")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("浙ICP备2026035179号-6A")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .accessibilityLabel("ICP备案号：浙ICP备2026035179号-6A")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationDestination(isPresented: $cameraWatermarkManagerPresented) {
                CameraWatermarkManagerView(
                    isEnabled: $useCustomCameraWatermarks,
                    library: cameraWatermarkLibrary
                )
                .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(isPresented: $workManagerPresented) {
                LingdongWorkManagerView(onLibraryChanged: refreshWorkArchiveSummary)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: refreshWorkArchiveSummary)
            .alert("将在默认浏览器中打开", isPresented: $sourceRepositoryConfirmationPresented) {
                Button("取消", role: .cancel) {}
                Button("确认打开") {
                    openURL(Self.sourceRepositoryURL)
                }
            } message: {
                Text("即将前往灵动照片的 GitHub 开源地址。本应用不会进行任何联网，网页内容将由系统默认浏览器加载。")
            }
        }
    }

    private var maintenanceStatement: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                Text(Self.maintenanceStatementText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                VStack(spacing: 2) {
                    Text(Self.maintenanceStatementFirstLine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(Self.maintenanceStatementContinuation)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.maintenanceStatementText)

            Button {
                sourceRepositoryConfirmationPresented = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("开源地址")
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
                .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开灵动照片 GitHub 开源地址")
            .accessibilityHint("确认后将在系统默认浏览器中打开；本应用不会联网")
        }
    }

    private var qqGroupSection: some View {
        VStack(spacing: 0) {
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

            Button {
                UIPasteboard.general.string = "help@locallens.cn"
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
                        Text(emailCopied ? "邮箱已复制" : "help@locallens.cn")
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
            .accessibilityHint("邮箱 help@locallens.cn 将被复制到剪贴板")
        }
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var paletteOptions: some View {
        settingsSection("琉璃色盘选项") {
            VStack(spacing: 0) {
                SettingRow(symbol: "rectangle.3.group", title: "排版模式") {
                    Picker("排版模式", selection: paletteLayoutBinding) {
                        ForEach(PaletteLayoutMode.allCases) { layout in
                            Text(layout.rawValue).tag(layout)
                        }
                    }
                    .labelsHidden()
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
        settingsSection("界面选项") {
            toggleRow(
                symbol: "textformat",
                title: "显示应用标题",
                subtitle: "控制编辑界面左上角是否显示“灵动照片”，不影响导出作品。",
                value: $showAppTitle
            )
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
        return "共 \(savedWorkCount) 件 · \(Self.formattedByteCount(savedWorkByteCount))"
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
                templateRow
                sectionDivider
                SettingRow(
                    symbol: motionCardHeaderStyle.symbol,
                    title: "顶部背景",
                    subtitle: templateStyle == .immersive
                        ? "沉浸模板没有独立顶部区域；切换为经典或留白模板后生效。"
                        : "取色渐变会从照片代表色生成平滑过渡，并自动选择清晰的文字颜色。"
                ) {
                    Picker("顶部背景", selection: $motionCardHeaderStyle) {
                        ForEach(MotionCardHeaderStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.blue)
                    .disabled(templateStyle == .immersive)
                }
                sectionDivider
                ratioRow
                sectionDivider
                tipRow(symbol: "arrow.up.and.down.and.arrow.left.and.right", text: "拖拽图片调整构图，双指捏合缩放")
                sectionDivider
                tipRow(symbol: "keyboard", text: "点击文字即可直接编辑")
                sectionDivider
                tipRow(symbol: "textformat", text: "切换字体：在文字上方空白处左右滑动")
                sectionDivider
                tipRow(symbol: "textformat.size", text: "调节大小：在文字下方空白处左右滑动")
                sectionDivider
                tipRow(symbol: "iphone.radiowaves.left.and.right", text: "晃动手机以恢复卡片初始视图")
                sectionDivider
                toggleRow(
                    symbol: "quote.opening",
                    title: "总是显示意境文案",
                    subtitle: "即使图片存在位置信息，也优先显示根据画面内容与色彩生成的意境文案。",
                    value: $showMoodCopy
                )
                sectionDivider
                toggleRow(
                    symbol: "calendar",
                    title: "显示缺失拍摄时间提示",
                    subtitle: "关闭后，照片没有日期信息时不显示“拍摄时间未记录”。",
                    value: $showMissingCaptureTime
                )
            }
        }
    }

    private var stampTips: some View {
        settingsSection("气泡印章操作技巧") {
            VStack(spacing: 0) {
                cameraWatermarkNavigationRow
                sectionDivider
                templateRow
                sectionDivider
                ratioRow
                sectionDivider
                tipRow(symbol: "arrow.up.and.down.and.arrow.left.and.right", text: "拖拽图片调整构图，双指捏合缩放")
                sectionDivider
                tipRow(symbol: "keyboard", text: "点击标题即可编辑（拍摄参数不可编辑）")
                sectionDivider
                tipRow(symbol: "textformat", text: "切换字体：在文字上方空白处左右滑动")
                sectionDivider
                tipRow(symbol: "textformat.size", text: "调节大小：在文字下方空白处左右滑动")
                sectionDivider
                tipRow(symbol: "bubbles.and.sparkles", text: "调节气泡大小：在气泡左侧空白区域上下滑动")
                sectionDivider
                toggleRow(
                    symbol: "iphone",
                    title: "显示手机和相机信息",
                    subtitle: "根据照片 EXIF 自动识别设备类别、厂商与型号",
                    value: $showDeviceInfo
                )
                sectionDivider
                toggleRow(symbol: "seal", title: "显示气泡", value: $showBubbles)
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
                SettingRow(symbol: "square.grid.2x2", title: "拼图模板") {
                    Picker("拼图模板", selection: $journalLayout) {
                        ForEach(JournalLayoutMode.allCases) { layout in
                            Text(layout.rawValue).tag(layout)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.blue)
                }
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
            VStack(spacing: 0) {
                tipRow(symbol: "info.circle", text: "生成的壁纸仅适配当前设备尺寸")
                sectionDivider
                tipRow(symbol: "c.circle", text: "本应用完全免费；版权所有，禁止商业转售")
            }
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
                    Text(item.rawValue).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.blue)
        }
    }

    private var templateRow: some View {
        SettingRow(symbol: templateStyle.symbol, title: "作品模板") {
            Picker("作品模板", selection: $templateStyle) {
                ForEach(ArtworkTemplateStyle.allCases) { style in
                    Label(style.rawValue, systemImage: style.symbol).tag(style)
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

    private var sectionDivider: some View {
        Divider().padding(.leading, 68)
    }

    private func toggleRow(
        symbol: String,
        title: String,
        subtitle: String? = nil,
        value: Binding<Bool>
    ) -> some View {
        SettingRow(symbol: symbol, title: title, subtitle: subtitle) {
            Toggle(title, isOn: value)
                .labelsHidden()
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)

            content()
                .frame(maxWidth: .infinity)
                .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private func tipRow(symbol: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 34)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

struct SettingRow<Trailing: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        symbol: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        Text(record.kindTitle)
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
