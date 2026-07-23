// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct SettingsView: View {
    @Binding var ratio: ArtworkRatio
    @Binding var showHexValues: Bool
    @Binding var showDeviceInfo: Bool
    @Binding var showBubbles: Bool
    @Binding var useCustomCameraWatermarks: Bool
    @Binding var gentleBackground: Bool
    @Binding var templateStyle: ArtworkTemplateStyle
    @Binding var journalLayout: JournalLayoutMode
    @ObservedObject var cameraWatermarkLibrary: CameraWatermarkLibrary

    @AppStorage("supportsLivePhotos") private var supportsLivePhotos = true
    @AppStorage("useLiteraryColorNames") private var useLiteraryColorNames = false
    @AppStorage("preservePaletteBackground") private var preservePaletteBackground = true
    @AppStorage("showMoodCopy") private var showMoodCopy = false
    @AppStorage("paletteLayout") private var paletteLayoutRaw = PaletteLayoutMode.floating.rawValue
    @AppStorage("applyLiquidGlassOnExport") private var applyLiquidGlassOnExport = true
    @AppStorage("showAppTitle") private var showAppTitle = true
    @AppStorage("showPalettePercentages") private var showPalettePercentages = true
    @State private var cameraWatermarkManagerPresented = false

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
                        freeSection
                        interfaceOptions
                        paletteOptions
                        motionTips
                        stampTips
                        journalOptions
                        wallpaperOptions
                        privacyOptions

                        VStack(spacing: 10) {
                            Text("版本 1.0.1 (Build 1017)")
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var freeSection: some View {
        settingsSection("免费承诺") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text("灵动照片")
                        .font(.title3.bold())
                    Text("完全免费")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(.primary.opacity(0.65), lineWidth: 1))
                }

                Text("无试用期、无订阅、无内购、无隐藏收费")
                    .font(.subheadline)

                Text("永久免费 · 谨防被骗")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.black, in: Capsule())
                    .accessibilityLabel("本应用完全免费，谨防被骗")
            }
            .padding(18)
        }
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

    private var motionTips: some View {
        settingsSection("灵动卡片操作技巧") {
            VStack(spacing: 0) {
                templateRow
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
