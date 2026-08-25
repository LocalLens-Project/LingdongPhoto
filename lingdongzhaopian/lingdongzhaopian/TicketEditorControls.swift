// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct TicketEditorControls: View {
    @Binding var layout: TicketLayoutStyle
    @Binding var codeStyle: TicketCodeStyle
    @Binding var widthMode: TicketCanvasWidthMode
    var isLandscape = false
    let onOpenStudio: () -> Void

    private var showWidthPicker: Bool {
        layout == .classic
    }

    @ViewBuilder
    var body: some View {
        if isLandscape {
            VStack(spacing: 8) {
                layoutPicker
                    .frame(maxWidth: .infinity)

                if showWidthPicker {
                    widthPicker
                }

                HStack(spacing: 8) {
                    ForEach(TicketCodeStyle.allCases) { item in
                        codeButton(item, expanded: true)
                    }
                }

                Button(action: onOpenStudio) {
                    controlLabel(
                        symbol: "eye",
                        title: "预览与公开信息",
                        expanded: true
                    )
                }
                .buttonStyle(LiquidPressButtonStyle())
                .accessibilityLabel("预览编码并设置公开信息")
            }
            .padding(8)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                interactive: true,
                variant: .clear
            )
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    layoutPicker

                    ForEach(TicketCodeStyle.allCases) { item in
                        codeButton(item)
                    }

                    Button(action: onOpenStudio) {
                        controlLabel(
                            symbol: "eye",
                            title: "预览与公开信息"
                        )
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .accessibilityLabel("预览编码并设置公开信息")
                }

                if showWidthPicker {
                    widthPicker
                }
            }
            .padding(8)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                interactive: true,
                variant: .clear
            )
        }
    }

    private var widthPicker: some View {
        HStack(spacing: 8) {
            ForEach(TicketCanvasWidthMode.allCases) { item in
                widthButton(item)
            }
        }
    }

    private func widthButton(_ item: TicketCanvasWidthMode) -> some View {
        Button {
            withAnimation(.snappy) {
                widthMode = item
            }
        } label: {
            Text(LocalizedStringKey(item.rawValue))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 43)
                .background {
                    if item == widthMode {
                        Capsule()
                            .fill(.primary.opacity(0.12))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .accessibilityLabel(
            "\(item.rawValue)\(item == widthMode ? "，当前选择" : "")"
        )
    }

    private var layoutPicker: some View {
        Menu {
            ForEach(TicketLayoutStyle.allCases) { item in
                Button {
                    layout = item
                } label: {
                    Label(LocalizedStringKey(item.rawValue), systemImage: item.symbol)
                }
            }
        } label: {
            controlLabel(
                symbol: layout.symbol,
                title: layout.rawValue,
                expanded: isLandscape
            )
        }
        .accessibilityLabel("票根版式，当前为\(layout.rawValue)")
    }

    private func codeButton(
        _ item: TicketCodeStyle,
        expanded: Bool = false
    ) -> some View {
        Button {
            withAnimation(.snappy) {
                codeStyle = item
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: item.symbol)
                    .font(.system(size: 16, weight: .semibold))
                if expanded {
                    Text(item == .barcode ? "一维码" : "二维码")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: expanded ? .infinity : nil)
            .frame(width: expanded ? nil : 43, height: 43)
            .background {
                if item == codeStyle {
                    Capsule()
                        .fill(.primary.opacity(0.12))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .accessibilityLabel(
            "\(item.title)\(item == codeStyle ? "，当前选择" : "")"
        )
    }

    private func controlLabel(
        symbol: String,
        title: String,
        expanded: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .frame(maxWidth: expanded ? .infinity : nil)
        .frame(height: 43)
        .contentShape(Capsule())
    }
}

struct TicketCodeStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var codeStyle: TicketCodeStyle
    @Binding var showCopy: Bool
    @Binding var showDate: Bool
    @Binding var showPlace: Bool
    @Binding var showDevice: Bool
    @Binding var showParameters: Bool
    @Binding var showPalette: Bool
    @Binding var deviceSealEnabled: Bool
    @Binding var message: String
    @Binding var headerMode: TicketHeaderMode
    @Binding var customHeader: String
    @Binding var cityNameStyle: TicketCityNameStyle
    @Binding var narrativeStyle: TicketNarrativeStyle
    @Binding var narrativePerspective: TicketNarrativePerspective

    let detectedCityName: String?
    let payload: TicketPayload
    let baseURLString: String
    let onSaveToPhotos: (TicketCodeStyle) -> Void
    let onSaveToFiles: (TicketCodeStyle) -> Void
    let onShare: (TicketCodeStyle) -> Void

    @State private var verificationPreviewPresented = false
    @State private var verificationPreviewTicket: VerifiedTicket?
    @State private var sealErrorMessage = ""
    @State private var sealErrorPresented = false
    @State private var ios17CodeImage: UIImage?
    @State private var ios17PreviewTicket: VerifiedTicket?
    @State private var ios17CodeErrorMessage: String?
    @State private var ios17CodeIsLoading = false
    @FocusState private var focusedField: TicketEditorFocus?
    @State private var keyboardHeight: CGFloat = 0

    private var isEnglishLocalization: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("en") == true
    }

    private enum TicketEditorFocus { case message, header }

    private struct CodeGenerationRequest: Equatable {
        let style: TicketCodeStyle
        let payload: TicketPayload
        let baseURLString: String
        let deviceSealEnabled: Bool
        let usesDarkForeground: Bool
    }

    private var signer: TicketEnvelopeSigning? {
        deviceSealEnabled ? TicketDeviceSealService.shared : nil
    }

    private var isEmotional: Bool { narrativeStyle == .emotional }
    private var isSelfPerspective: Bool { narrativePerspective == .self }

    private var publicInfoTitle: String {
        isEmotional ? "时光胶囊信息" : "票根公开信息"
    }

    private var messageSectionTitle: String {
        if isEmotional {
            return isSelfPerspective ? "写给过去的备忘" : "创作者留下的寄语"
        }
        return "票根寄语"
    }

    private var messagePlaceholder: String {
        if isEmotional {
            return isSelfPerspective
                ? "给未来的自己留一句话…"
                : "写一句想让扫描者看到的话…"
        }
        return "写下一句想和这张照片一起留下的话"
    }

    private var messageHint: String {
        if isEmotional {
            return isSelfPerspective
                ? "这段备忘会随票根一起封存，扫描时可以看到。最多 80 个字符。"
                : "这段寄语会随票根一起封存，扫描时可以看到。最多 80 个字符。"
        }
        return "寄语属于公开信息，使用验证二维码时，任何扫描者都可以看到。最多 80 个字符。"
    }

    private var verificationPreviewLabel: String {
        isEmotional ? "预览时光胶囊效果" : "预览扫描后的验证界面"
    }

    private var codeStyleSubtitle: String {
        if isEmotional {
            return codeStyle == .barcode ? "保存与分享" : "扫码回忆"
        }
        return codeStyle == .barcode ? "保存与分享" : "扫码验证"
    }

    private var sealToggleTitle: String {
        isEmotional ? "给时光胶囊加上设备封印" : "给票根加上设备封印"
    }

    private var sealToggleSubtitle: String {
        isEmotional
            ? "防止胶囊里的信息在生成后被悄悄改写"
            : "防止二维码里的公开信息在生成后被悄悄改写"
    }

    private var sealClosedExplanation: String {
        if isEmotional {
            return "已关闭。胶囊仍可查看，但扫描者无法确认信息生成后有没有被改动。"
        }
        return "已关闭。票根仍可查看，但扫描者无法确认公开信息生成后有没有被改动。"
    }

    private var sealOpenExplanation: String {
        if isEmotional {
            return "开启后，这台 iPhone 会用安全隔区里的专属密钥给胶囊信息盖章。照片不会写入二维码，也不会上传。"
        }
        return "开启后，这台 iPhone 会用安全隔区里的专属密钥给公开信息盖章。照片不会写入二维码，也不会上传。"
    }

    private var usesIOS17BackgroundGeneration: Bool {
        if #available(iOS 18.0, *) { return false }
        return true
    }

    private var codeGenerationRequest: CodeGenerationRequest {
        CodeGenerationRequest(
            style: codeStyle,
            payload: payload,
            baseURLString: baseURLString,
            deviceSealEnabled: deviceSealEnabled,
            usesDarkForeground: colorScheme == .dark
        )
    }

    private var synchronousCodeImage: UIImage? {
        try? TicketCodeRenderer.image(
            for: codeStyle,
            payload: payload,
            baseURLString: baseURLString,
            signer: signer,
            pixelSize: codeStyle == .barcode
                ? CGSize(width: 1_200, height: 300)
                : CGSize(width: 900, height: 900),
            foregroundColor: colorScheme == .dark ? .white : .black,
            backgroundColor: nil
        )
    }

    private var displayedCodeImage: UIImage? {
        usesIOS17BackgroundGeneration ? ios17CodeImage : synchronousCodeImage
    }

    private var isCodeLoading: Bool {
        usesIOS17BackgroundGeneration && ios17CodeIsLoading
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                if proxy.size.width > proxy.size.height {
                    ScrollView {
                        HStack(alignment: .top, spacing: 18) {
                            VStack(spacing: 18) {
                                codePicker
                                codePreview
                            }
                            .frame(maxWidth: 440)

                            VStack(spacing: 18) {
                                explanation
                                narrativeOptions
                                headerOptions
                                messageOptions
                                deviceSealOptions
                                privacyOptions
                                exportActions
                            }
                            .frame(maxWidth: 480)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 26 + keyboardHeight)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    ScrollView {
                        VStack(spacing: 22) {
                            codePicker
                            codePreview
                            explanation
                            narrativeOptions
                            headerOptions
                            messageOptions
                            deviceSealOptions
                            privacyOptions
                            exportActions
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 34 + keyboardHeight)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .ignoresSafeArea(.keyboard)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("影像票根编码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: dismiss.callAsFunction)
                        .fontWeight(.semibold)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if focusedField != nil {
                HStack {
                    Spacer()
                    Button("收起键盘") {
                        focusedField = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .tint(Color(uiColor: .systemBlue))
        .sheet(isPresented: $verificationPreviewPresented) {
            TicketVerificationView(
                ticket: verificationPreviewTicket ?? .unsigned(payload),
                onClose: { verificationPreviewPresented = false }
            )
            .presentationDragIndicator(.hidden)
        }
        .alert("无法生成设备封印", isPresented: $sealErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(sealErrorMessage))
        }
        .task(id: codeGenerationRequest) {
            await generateCodeForIOS17IfNeeded(request: codeGenerationRequest)
        }
    }

    private var codePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择票根凭证")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(TicketCodeStyle.allCases) { item in
                    Button {
                        withAnimation(.snappy) {
                            codeStyle = item
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 20, weight: .semibold))
                                Spacer()
                                if item == codeStyle {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            Text(LocalizedStringKey(item.title))
                                .font(.subheadline.weight(.bold))
                            Text(LocalizedStringKey(codeStyleSubtitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(15)
                        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    item == codeStyle
                                        ? Color.accentColor.opacity(0.12)
                                        : Color(uiColor: .secondarySystemGroupedBackground)
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    item == codeStyle
                                        ? Color.accentColor.opacity(0.72)
                                        : .primary.opacity(0.07),
                                    lineWidth: item == codeStyle ? 1.4 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var codePreview: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(codeStyle.title))
                        .font(.headline)
                    Text(LocalizedStringKey(payload.ticketID))
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCodeLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("正在生成票根编码…")
                } else if displayedCodeImage != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.green)
                        .accessibilityLabel("编码生成成功")
                }
            }

            if let codeImage = displayedCodeImage {
                Image(uiImage: codeImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(
                        codeStyle == .barcode
                            ? codeImage.size.width / codeImage.size.height
                            : 1,
                        contentMode: .fit
                    )
                    .frame(
                        maxWidth: codeStyle == .barcode ? .infinity : 250,
                        maxHeight: codeStyle == .barcode ? 118 : 250
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
            } else if isCodeLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在生成票根编码…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: codeStyle == .barcode ? 118 : 250)
                .accessibilityElement(children: .combine)
            } else {
                ContentUnavailableView(
                    "无法生成编码",
                    systemImage: "exclamationmark.triangle",
                    description: Text(
                        LocalizedStringKey(
                            ios17CodeErrorMessage ?? "请减少公开字段后重试。"
                        )
                    )
                )
            }

            if codeStyle == .verificationQR {
                Button {
                    openVerificationPreview()
                } label: {
                    Label(LocalizedStringKey(verificationPreviewLabel), systemImage: "appclip")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .disabled(
                    usesIOS17BackgroundGeneration
                        && (isCodeLoading || ios17PreviewTicket == nil)
                )
            }
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var explanation: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: codeStyle == .barcode ? "barcode.viewfinder" : "appclip")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(codeStyle == .barcode ? "真实可扫描的一维码" : "无需安装完整应用")
                    .font(.subheadline.weight(.bold))
                Text(LocalizedStringKey(codeStyle.explanation))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if codeStyle == .verificationQR {
                    Text("首次打开 App Clip 需要使用 Apple 提供的系统服务联网获取。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var narrativeOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("扫码后的叙事风格")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(TicketNarrativeStyle.allCases) { style in
                    Button {
                        withAnimation(.snappy) {
                            narrativeStyle = style
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: style.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    narrativeStyle == style
                                        ? Color.accentColor
                                        : Color.secondary
                                )
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(style.title))
                                    .font(.subheadline.weight(.bold))
                                Text(LocalizedStringKey(style.description))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            if narrativeStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    narrativeStyle == style
                                        ? Color.accentColor.opacity(0.10)
                                        : Color(uiColor: .tertiarySystemGroupedBackground)
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    narrativeStyle == style
                                        ? Color.accentColor.opacity(0.6)
                                        : Color.primary.opacity(0.06),
                                    lineWidth: narrativeStyle == style ? 1.4 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if narrativeStyle == .emotional {
                VStack(alignment: .leading, spacing: 10) {
                    Text("叙事视角")
                        .font(.subheadline.weight(.semibold))

                    ForEach(TicketNarrativePerspective.allCases) { perspective in
                        Button {
                            withAnimation(.snappy) {
                                narrativePerspective = perspective
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: perspective.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(
                                        narrativePerspective == perspective
                                            ? Color.accentColor
                                            : Color.secondary
                                    )
                                    .frame(width: 26)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(LocalizedStringKey(perspective.title))
                                        .font(.subheadline.weight(.semibold))
                                    Text(LocalizedStringKey(perspective.description))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                if narrativePerspective == perspective {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        narrativePerspective == perspective
                                            ? Color.accentColor.opacity(0.08)
                                            : Color(uiColor: .tertiarySystemGroupedBackground)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .animation(.snappy, value: narrativeStyle)
    }

    private var privacyOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(publicInfoTitle))
                .font(.headline)
                .padding(.bottom, 12)

            privacyToggle("公开文案", symbol: "quote.opening", value: $showCopy)
            Divider()
            privacyToggle("公开拍摄时间", symbol: "calendar", value: $showDate)
            Divider()
            privacyToggle(
                "公开地点",
                subtitle: "默认关闭；开启后任何扫描者都可以看到票根中的地点。",
                symbol: "location",
                value: $showPlace
            )
            Divider()
            privacyToggle("公开设备与镜头", symbol: "camera", value: $showDevice)
            Divider()
            privacyToggle("公开拍摄参数", symbol: "dial.medium", value: $showParameters)
            Divider()
            privacyToggle("公开照片色盘", symbol: "paintpalette", value: $showPalette)

            Text("二维码内容可以被任何扫描者读取，不包含原始照片、相册标识、文件路径或设备序列号。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var deviceSealOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(sealToggleTitle))
                        .font(.subheadline.weight(.bold))
                    Text(LocalizedStringKey(sealToggleSubtitle))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: $deviceSealEnabled)
                    .labelsHidden()
                    .accessibilityLabel("设备封印")
            }

            Text(LocalizedStringKey(deviceSealExplanation))
                .font(.caption)
                .foregroundStyle(
                    TicketDeviceSealService.shared.capability == .unavailable
                        ? .orange
                        : .secondary
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var deviceSealExplanation: String {
        let capability = TicketDeviceSealService.shared.capability
        if !deviceSealEnabled {
            return sealClosedExplanation
        }
        switch capability {
        case .secureEnclave:
            return sealOpenExplanation
        case .simulatorTest:
            return "模拟器没有安全隔区；这里会显示“模拟器测试签名”，只用于确认 iOS、Android 与 App Clip 的验真流程。iPhone 真机会改用安全隔区。"
        case .unavailable:
            return "这台设备当前无法使用安全隔区。请关闭设备封印后再生成二维码。"
        }
    }

    private func openVerificationPreview() {
        if usesIOS17BackgroundGeneration {
            guard !ios17CodeIsLoading else { return }
            if let ticket = ios17PreviewTicket {
                verificationPreviewTicket = ticket
                verificationPreviewPresented = true
            } else {
                sealErrorMessage = ios17CodeErrorMessage
                    ?? "请减少公开字段后重试。".appLocalized
                sealErrorPresented = true
            }
            return
        }

        do {
            let url = try TicketEnvelope.invocationURL(
                for: payload,
                baseURLString: baseURLString,
                signer: signer
            )
            verificationPreviewTicket = try TicketEnvelope.decodeVerified(from: url)
            verificationPreviewPresented = true
        } catch {
            sealErrorMessage = error.localizedDescription
            sealErrorPresented = true
        }
    }

    @MainActor
    private func generateCodeForIOS17IfNeeded(
        request: CodeGenerationRequest
    ) async {
        guard usesIOS17BackgroundGeneration else { return }

        ios17CodeImage = nil
        ios17PreviewTicket = nil
        ios17CodeErrorMessage = nil
        ios17CodeIsLoading = true

        let result = await Task.detached(priority: .userInitiated) {
            () -> Result<(UIImage, VerifiedTicket?), Error> in
            do {
                let signer: TicketEnvelopeSigning? = request.deviceSealEnabled
                    ? TicketDeviceSealService.shared
                    : nil
                let previewTicket: VerifiedTicket?
                if request.style == .verificationQR {
                    let url = try TicketEnvelope.invocationURL(
                        for: request.payload,
                        baseURLString: request.baseURLString,
                        signer: signer
                    )
                    previewTicket = try TicketEnvelope.decodeVerified(from: url)
                } else {
                    previewTicket = nil
                }
                let image = try TicketCodeRenderer.image(
                    for: request.style,
                    payload: request.payload,
                    baseURLString: request.baseURLString,
                    signer: signer,
                    pixelSize: request.style == .barcode
                        ? CGSize(width: 1_200, height: 300)
                        : CGSize(width: 900, height: 900),
                    foregroundColor: request.usesDarkForeground ? .white : .black,
                    backgroundColor: nil
                )
                return .success((image, previewTicket))
            } catch {
                return .failure(error)
            }
        }.value

        guard !Task.isCancelled, codeGenerationRequest == request else { return }
        ios17CodeIsLoading = false
        switch result {
        case let .success((image, ticket)):
            ios17CodeImage = image
            ios17PreviewTicket = ticket
        case let .failure(error):
            ios17CodeErrorMessage = error.localizedDescription
        }
    }

    private var messageOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(messageSectionTitle))
                    .font(.headline)
                Spacer()
                Text("\(message.count)/\(TicketPayload.messageCharacterLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(LocalizedStringKey(messagePlaceholder))
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }

                TextEditor(text: Binding(
                    get: { message },
                    set: {
                        message = String(
                            $0.prefix(TicketPayload.messageCharacterLimit)
                        )
                    }
                ))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 92)
                .focused($focusedField, equals: .message)
            }
            .padding(8)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )

            Text(LocalizedStringKey(messageHint))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var headerOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("票面主标题")
                .font(.headline)

            Picker("标题来源", selection: $headerMode) {
                ForEach(TicketHeaderMode.allCases) { item in
                    Text(LocalizedStringKey(item.rawValue)).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if headerMode == .custom {
                TextField("可输入标题，也可以留空", text: $customHeader)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .header)
                    .padding(.horizontal, 13)
                    .frame(height: 44)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                Text("留空后，票根左上方不显示主标题。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if !isEnglishLocalization {
                    Picker("城市显示", selection: $cityNameStyle) {
                        ForEach(TicketCityNameStyle.allCases) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 8) {
                    Image(systemName: detectedCityName == nil
                        ? "location.slash"
                        : "location.fill")
                    if let detectedCityName {
                        Text(
                            String(
                                format: "已识别城市：%@".appLocalized,
                                detectedCityName
                            )
                        )
                    } else {
                        Text("照片没有可用定位，将显示 LINGDONG")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var exportActions: some View {
        VStack(spacing: 10) {
            Button {
                onSaveToPhotos(codeStyle)
            } label: {
                Label("保存编码到系统相册", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            HStack(spacing: 10) {
                Button {
                    onSaveToFiles(codeStyle)
                } label: {
                    Label("存到文件", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Button {
                    onShare(codeStyle)
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
    }

    private func privacyToggle(
        _ title: String,
        subtitle: String? = nil,
        symbol: String,
        value: Binding<Bool>
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: value)
                .labelsHidden()
        }
        .padding(.vertical, 12)
    }
}

struct TicketMessageEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String) -> Void
    @State private var draft: String
    let narrativeStyle: TicketNarrativeStyle
    let narrativePerspective: TicketNarrativePerspective

    init(
        message: String,
        narrativeStyle: TicketNarrativeStyle,
        narrativePerspective: TicketNarrativePerspective,
        onSave: @escaping (String) -> Void
    ) {
        self.onSave = onSave
        self.narrativeStyle = narrativeStyle
        self.narrativePerspective = narrativePerspective
        _draft = State(
            initialValue: String(
                message.prefix(TicketPayload.messageCharacterLimit)
            )
        )
    }

    private var normalizedDraft: String? {
        TicketPayload.normalizedMessage(draft)
    }

    private var isEmotional: Bool { narrativeStyle == .emotional }
    private var isSelfPerspective: Bool { narrativePerspective == .self }

    private var editorHint: String {
        if isEmotional {
            return isSelfPerspective
                ? "这段备忘会随票根一起封存，扫描时可以看到。"
                : "这段寄语会随票根一起封存，扫描时可以看到。"
        }
        return "寄语会写入票根的公开信息，使用验证二维码时，任何扫描者都可以看到。"
    }

    private var editorPlaceholder: String {
        if isEmotional {
            return isSelfPerspective
                ? "给未来的自己留一句话…"
                : "写一句想让扫描者看到的话…"
        }
        return "写下一句想和这张照片一起留下的话"
    }

    private var editorTitle: String {
        if isEmotional {
            return isSelfPerspective ? "写给过去的备忘" : "创作者留下的寄语"
        }
        return "补充寄语"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(LocalizedStringKey(editorHint))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text(LocalizedStringKey(editorPlaceholder))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $draft)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                }
                .padding(10)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

                Text("\(draft.count)/\(TicketPayload.messageCharacterLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(LocalizedStringKey(editorTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        guard let normalizedDraft else { return }
                        onSave(normalizedDraft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(normalizedDraft == nil)
                }
            }
            .onChange(of: draft) { _, value in
                guard value.count > TicketPayload.messageCharacterLimit else {
                    return
                }
                draft = String(value.prefix(TicketPayload.messageCharacterLimit))
            }
        }
    }
}

struct TicketNarrativePromptView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (TicketNarrativeStyle, TicketNarrativePerspective) -> Void
    let onDismiss: () -> Void

    @State private var selectedStyle: TicketNarrativeStyle = .emotional
    @State private var selectedPerspective: TicketNarrativePerspective = .self

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("选择风格")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    onDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择扫码后的叙事风格")
                            .font(.title3.weight(.semibold))
                        Text("这将决定他人扫描票根后看到的呈现方式")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(TicketNarrativeStyle.allCases) { style in
                            Button {
                                withAnimation(.snappy) {
                                    selectedStyle = style
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: style.symbol)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(
                                            selectedStyle == style
                                                ? Color.accentColor
                                                : Color.secondary
                                        )
                                        .frame(width: 36, height: 36)
                                        .background(
                                            selectedStyle == style
                                                ? Color.accentColor.opacity(0.12)
                                                : Color.secondary.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(LocalizedStringKey(style.title))
                                            .font(.headline)
                                        Text(LocalizedStringKey(style.description))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    if selectedStyle == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(
                                            selectedStyle == style
                                                ? Color.accentColor.opacity(0.06)
                                                : Color(uiColor: .tertiarySystemGroupedBackground)
                                        )
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            selectedStyle == style
                                                ? Color.accentColor.opacity(0.5)
                                                : Color.primary.opacity(0.05),
                                            lineWidth: selectedStyle == style ? 1.4 : 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if selectedStyle == .emotional {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("选择叙事视角")
                                .font(.headline)

                            ForEach(TicketNarrativePerspective.allCases) { perspective in
                                Button {
                                    withAnimation(.snappy) {
                                        selectedPerspective = perspective
                                    }
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: perspective.symbol)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(
                                                selectedPerspective == perspective
                                                    ? Color.accentColor
                                                    : Color.secondary
                                            )
                                            .frame(width: 30)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizedStringKey(perspective.title))
                                                .font(.subheadline.weight(.semibold))
                                            Text(LocalizedStringKey(perspective.description))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        Spacer()

                                        if selectedPerspective == perspective {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(
                                                selectedPerspective == perspective
                                                    ? Color.accentColor.opacity(0.06)
                                                    : Color(uiColor: .tertiarySystemGroupedBackground)
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            Divider()
                .padding(.horizontal, 24)

            Button {
                onSelect(selectedStyle, selectedPerspective)
                dismiss()
            } label: {
                Text("使用此风格")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
