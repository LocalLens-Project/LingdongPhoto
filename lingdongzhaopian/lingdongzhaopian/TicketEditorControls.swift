// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct TicketEditorControls: View {
    @Binding var layout: TicketLayoutStyle
    @Binding var codeStyle: TicketCodeStyle
    var isLandscape = false
    let onOpenStudio: () -> Void

    @ViewBuilder
    var body: some View {
        if isLandscape {
            VStack(spacing: 8) {
                layoutPicker
                    .frame(maxWidth: .infinity)

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
            portraitControls
        }
    }

    private var portraitControls: some View {
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
        .padding(8)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            interactive: true,
            variant: .clear
        )
    }

    private var layoutPicker: some View {
        Menu {
            ForEach(TicketLayoutStyle.allCases) { item in
                Button {
                    layout = item
                } label: {
                    Label(item.rawValue, systemImage: item.symbol)
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
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
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
    @Binding var message: String
    @Binding var headerMode: TicketHeaderMode
    @Binding var customHeader: String
    @Binding var cityNameStyle: TicketCityNameStyle

    let detectedCityName: String?
    let payload: TicketPayload
    let baseURLString: String
    let onSaveToPhotos: (TicketCodeStyle) -> Void
    let onSaveToFiles: (TicketCodeStyle) -> Void
    let onShare: (TicketCodeStyle) -> Void

    @State private var verificationPreviewPresented = false

    private var codeImage: UIImage? {
        try? TicketCodeRenderer.image(
            for: codeStyle,
            payload: payload,
            baseURLString: baseURLString,
            pixelSize: codeStyle == .barcode
                ? CGSize(width: 1_200, height: 300)
                : CGSize(width: 900, height: 900),
            foregroundColor: colorScheme == .dark ? .white : .black,
            backgroundColor: nil
        )
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
                                headerOptions
                                messageOptions
                                privacyOptions
                                exportActions
                            }
                            .frame(maxWidth: 480)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 26)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ScrollView {
                        VStack(spacing: 22) {
                            codePicker
                            codePreview
                            explanation
                            headerOptions
                            messageOptions
                            privacyOptions
                            exportActions
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 34)
                    }
                    .scrollIndicators(.hidden)
                }
            }
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
        .tint(Color(uiColor: .systemBlue))
        .sheet(isPresented: $verificationPreviewPresented) {
            TicketVerificationView(
                payload: payload,
                onClose: { verificationPreviewPresented = false }
            )
            .presentationDragIndicator(.hidden)
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
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                            Text(
                                item == .barcode
                                    ? "保存与分享"
                                    : "扫码验证"
                            )
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
                    Text(codeStyle.title)
                        .font(.headline)
                    Text(payload.ticketID)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.green)
                    .accessibilityLabel("编码生成成功")
            }

            if let codeImage {
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
            } else {
                ContentUnavailableView(
                    "无法生成编码",
                    systemImage: "exclamationmark.triangle",
                    description: Text("请减少公开字段后重试。")
                )
            }

            if codeStyle == .verificationQR {
                Button {
                    verificationPreviewPresented = true
                } label: {
                    Label("预览扫描后的验证界面", systemImage: "appclip")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
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
                Text(codeStyle.explanation)
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

    private var privacyOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("票根公开信息")
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

    private var messageOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("票根寄语")
                    .font(.headline)
                Spacer()
                Text("\(message.count)/\(TicketPayload.messageCharacterLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text("写下一句想和这张照片一起留下的话")
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
            }
            .padding(8)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )

            Text("寄语属于公开信息，使用验证二维码时，任何扫描者都可以看到。最多 80 个字符。")
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
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if headerMode == .custom {
                TextField("可输入标题，也可以留空", text: $customHeader)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
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
                Picker("城市显示", selection: $cityNameStyle) {
                    ForEach(TicketCityNameStyle.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Image(systemName: detectedCityName == nil
                        ? "location.slash"
                        : "location.fill")
                    Text(
                        detectedCityName.map { "已识别城市：\($0)" }
                            ?? "照片没有可用定位，将显示 LINGDONG"
                    )
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
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
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

    init(message: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _draft = State(
            initialValue: String(
                message.prefix(TicketPayload.messageCharacterLimit)
            )
        )
    }

    private var normalizedDraft: String? {
        TicketPayload.normalizedMessage(draft)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("寄语会写入票根的公开信息，使用验证二维码时，任何扫描者都可以看到。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("写下一句想和这张照片一起留下的话")
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
            .navigationTitle("补充寄语")
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
