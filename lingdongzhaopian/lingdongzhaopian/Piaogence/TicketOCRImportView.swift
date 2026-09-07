import PhotosUI
import SwiftUI
import UIKit

private enum TicketDevelopPreviewMode: String, CaseIterable, Identifiable {
    case original
    case reborn

    var id: String { rawValue }
    var title: String { (self == .original ? "原票档案" : "记忆重制").appLocalized }
    var symbol: String { self == .original ? "doc.viewfinder" : "sparkles.rectangle.stack" }
}

struct TicketOCRImportView: View {

    let source: CollectionTimelineView.Source?
    var onImport: ([TicketStub]) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("ticketDevelopAwarenessSeen") private var awarenessSeen = false
    @State private var selections: [PhotosPickerItem] = []
    @State private var drafts: [TicketImportDraft] = []
    @State private var isRecognizing = false
    @State private var statusText = ""
    @State private var errorMessage: String?
    @State private var previewMode: TicketDevelopPreviewMode = .reborn
    @State private var editionStudioDraftID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                background
                if awarenessSeen {
                    importContent
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    awarenessPage
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .navigationTitle(awarenessSeen ? "票根显影".appLocalized : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if awarenessSeen {
                        PhotosPicker(selection: $selections, maxSelectionCount: 12, matching: .images) {
                            Image(systemName: drafts.isEmpty ? "photo.badge.plus" : "plus")
                        }
                        .disabled(isRecognizing)
                    }
                }
            }
            .onChange(of: selections) { _, items in
                guard !items.isEmpty else { return }
                Task { await load(items) }
            }
            .alert("无法识别", isPresented: errorPresented) {
                Button("好", role: .cancel) {}
            } message: {
                Text((errorMessage ?? "请稍后重试。").appLocalized)
            }
            .fullScreenCover(isPresented: editionStudioPresented) {
                editionStudio
            }
        }
    }

    private var importContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if isRecognizing { recognitionStatus }
                if drafts.isEmpty { emptyGuide }
                if !drafts.isEmpty { previewModePicker }
                ForEach($drafts) { $draft in
                    draftEditor($draft)
                }
                if !drafts.isEmpty { confirmButton }
            }
            .padding(.horizontal, 16)
            .padding(.top, drafts.isEmpty ? 26 : 10)
            .padding(.bottom, 36)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.94, blue: 0.91),
                Color(red: 0.89, green: 0.92, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color(red: 0.48, green: 0.70, blue: 0.72).opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 90, y: -110)
        }
        .ignoresSafeArea()
    }

    private var awarenessPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 46)

            ticketSampleArtwork(symbol: "viewfinder", width: 218)
            .accessibilityHidden(true)

            Text("从旧票里，显出当天")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .padding(.top, 34)

            Text("选择一张纸票照片或电子凭证\n把当时的颜色留成一张记忆票")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 11)

            VStack(alignment: .leading, spacing: 17) {
                awarenessRow("lock.fill", "原票只留在本机")
                awarenessRow("sparkles.rectangle.stack", "生成原创记忆票面")
                awarenessRow("checkmark.shield.fill", "分享不包含原票与入场码")
            }
            .padding(.top, 38)

            Spacer(minLength: 36)

            Button {
                withAnimation(.snappy(duration: 0.42)) {
                    awarenessSeen = true
                }
            } label: {
                HStack(spacing: 8) {
                    Text("下一步")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(red: 0.25, green: 0.50, blue: 0.54), in: Capsule())
            }
            .buttonStyle(.plain)

            Text("仅在首次使用时显示")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 28)
    }

    private func awarenessRow(_ symbol: String, _ title: String) -> some View {
        Label {
            Text(title.appLocalized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.78))
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.50, blue: 0.54))
                .frame(width: 24)
        }
    }

    private func ticketSampleArtwork(symbol: String, width: CGFloat) -> some View {
        let height = width / (21.0 / 9.0)
        return ZStack {
            ticketSampleLayer(
                imageName: "TicketDevelopFlightSample",
                width: width,
                height: height
            )
            .rotationEffect(.degrees(-4))
            .offset(x: -8, y: 6)

            ticketSampleLayer(
                imageName: "TicketDevelopRailwaySample",
                width: width,
                height: height
            )

            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.50, blue: 0.54))
                .frame(width: 54, height: 54)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 0.8))
        }
        .frame(width: width + 16, height: height + 18)
    }

    private func ticketSampleLayer(
        imageName: String,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .saturation(0.76)
            .contrast(0.94)
            .overlay(.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.white.opacity(0.78), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.13), radius: 17, y: 10)
    }

    private var recognitionStatus: some View {
        HStack(spacing: 9) {
            ProgressView().controlSize(.small)
            Text(statusText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var emptyGuide: some View {
        PhotosPicker(selection: $selections, maxSelectionCount: 12, matching: .images) {
            VStack(spacing: 0) {
                ticketSampleArtwork(symbol: "plus", width: 210)
                .padding(.top, 46)

                Text("选择一张旧票")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .padding(.top, 34)

                Text("纸票照片或电子凭证截图")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 7)

                Label("从照片中选择", systemImage: "photo.badge.plus")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color(red: 0.25, green: 0.47, blue: 0.51)))
                    .padding(.top, 28)

                Text("最多 12 张 · 识别在本机完成")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 15)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 54)
        }
        .buttonStyle(.plain)
    }

    private var previewModePicker: some View {
        Picker("显影预览", selection: $previewMode) {
            ForEach(TicketDevelopPreviewMode.allCases) { mode in
                Label(mode.title, systemImage: mode.symbol).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("切换原票档案与记忆重制")
    }

    private func draftEditor(_ draft: Binding<TicketImportDraft>) -> some View {
        let value = draft.wrappedValue
        return VStack(spacing: 15) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if previewMode == .original {
                        originalArchivePreview(value.image)
                    } else {
                        TicketArtworkView(ticket: value.ticketPreview())
                    }
                }
                .frame(maxWidth: 420)
                .compositingGroup()
                .shadow(color: .black.opacity(0.18), radius: 16, y: 9)

                if previewMode == .original {
                    Label("私藏原貌 · 不参与分享", systemImage: "lock.fill")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.52), in: Capsule())
                        .padding(11)
                } else {
                    TicketEditionEntryButton(edition: value.edition) {
                        editionStudioDraftID = value.id
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 9) {
                    Label(value.result.platform.localizedTitle, systemImage: value.result.platform.symbol)
                    Spacer()
                    Text("转为原创·\(value.result.type.localizedMemoryTemplateName)")
                }
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                DisclosureGroup {
                    VStack(spacing: 0) {
                        Picker("票型", selection: draft.result.type) {
                            ForEach(PhysicalTicketType.allCases, id: \.self) { type in
                                Label(type.localizedTitle, systemImage: type.symbol).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        Divider().padding(.leading, 14)
                        ticketField("主标题", text: draft.result.title)
                        Divider().padding(.leading, 14)
                        ticketField("副标题", text: draft.result.subtitle)
                        Divider().padding(.leading, 14)
                        ticketField("地点", text: draft.result.place)
                        Divider().padding(.leading, 14)
                        ticketField("座位", text: draft.result.seat)
                        Divider().padding(.leading, 14)
                        ticketField("票价", text: draft.result.price)
                    }
                    .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.25, green: 0.52, blue: 0.55))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(value.result.title)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text("轻点检查类型、地点、时间与座位")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
                .padding(14)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }

            HStack {
                Label("记忆指纹 \(value.fingerprint)", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    drafts.removeAll { $0.id == value.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.64)))
    }

    private func originalArchivePreview(_ image: UIImage) -> some View {
        ZStack {
            Color(red: 0.12, green: 0.13, blue: 0.14)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(12)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.30), lineWidth: 0.8)
        }
        .overlay(alignment: .topTrailing) {
            Label("仅本机私藏", systemImage: "lock.fill")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.58), in: Capsule())
                .padding(12)
        }
    }

    private func ticketField(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(title.appLocalized)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            TextField(title.appLocalized, text: text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
    }

    private var confirmButton: some View {
        Button {
            let tickets = drafts.map { $0.ticket(source: source) }
            onImport(tickets)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                Text("封存 \(drafts.count) 张记忆票")
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.25, green: 0.50, blue: 0.54), Color(red: 0.73, green: 0.43, blue: 0.32)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isRecognizing)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var editionStudioPresented: Binding<Bool> {
        Binding(
            get: { editionStudioDraftID != nil },
            set: { if !$0 { editionStudioDraftID = nil } }
        )
    }

    @ViewBuilder
    private var editionStudio: some View {
        if let id = editionStudioDraftID,
           let index = drafts.firstIndex(where: { $0.id == id }) {
            TicketEditionStudio(
                ticket: drafts[index].ticketPreview(),
                currentEdition: drafts[index].edition
            ) { edition in
                drafts[index].edition = edition
            }
        } else {
            Color.clear
        }
    }

    @MainActor
    private func load(_ items: [PhotosPickerItem]) async {
        isRecognizing = true
        defer {
            isRecognizing = false
            selections = []
            statusText = ""
        }
        var failures = 0
        for (index, item) in items.enumerated() {
            statusText = String(format: "正在重读第 %lld / %lld 张票…".appLocalized, index + 1, items.count)
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    failures += 1
                    continue
                }
                async let recognized = TicketOCRService.recognize(image)
                let paletteResult = PaletteExtractor.extract(from: image)
                let result = try await recognized
                let draft = TicketImportDraft(
                    image: image,
                    imageData: data,
                    result: result,
                    palette: paletteResult.colors,
                    fingerprint: TicketOCRService.fingerprint(for: data)
                )
                drafts.append(draft)
            } catch {
                failures += 1
            }
        }
        if drafts.isEmpty {
            errorMessage = "所选照片都没有识别到足够清晰的票面文字。请让票面铺平、占满画面并避开反光。".appLocalized
        } else if failures > 0 {
            errorMessage = String(format: "其中 %lld 张没有识别到清晰文字，其余票面已准备好。".appLocalized, failures)
        }
    }
}

private struct TicketImportDraft: Identifiable {
    let id = UUID()
    let image: UIImage
    let imageData: Data
    var result: TicketOCRResult
    let palette: [RGBColor]
    let fingerprint: String
    var edition: TicketEdition = .standard

    var colorName: String {
        (palette.first ?? RGBColor.fallback[0]).poeticEntry().localizedName
    }

    func ticketPreview() -> TicketStub {
        makeTicket(city: nil, createsDeviceSeal: false)
    }

    func ticket(source: CollectionTimelineView.Source?) -> TicketStub {
        let city: String?
        if case let .city(name) = source { city = name } else { city = nil }
        return makeTicket(city: city, createsDeviceSeal: true)
    }

    private func makeTicket(
        city: String?,
        createsDeviceSeal: Bool
    ) -> TicketStub {
        let colors = palette.prefix(6).map {
            PiaogenceRGBColor(red: $0.red, green: $0.green, blue: $0.blue)
        }
        let dominant = palette.first ?? RGBColor.fallback[0]
        let theme: SceneTheme
        if dominant.relativeLuminance < 0.16 { theme = .nightCity }
        else if dominant.blue > dominant.red * 1.18 { theme = .sea }
        else if dominant.green > dominant.red * 1.12 { theme = .forest }
        else if dominant.red > dominant.blue * 1.22 { theme = .sunset }
        else { theme = .snowMountain }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        let serial = fingerprint.prefix(8)
        let ticketID = "PHY-\(serial)"
        let captureTime = result.dateText == "时间待确认"
            ? formatter.string(from: result.date)
            : result.dateText
        let message = result.detailLine.isEmpty
            ? "原票在本机被重新读懂，并以票面颜色完成记忆重制。".appLocalized
            : result.detailLine
        let paletteEntries = palette.prefix(6).enumerated().map { index, color in
            TicketPaletteEntry(
                hex: color.hex,
                percentage: index == 0 ? 0.30 : 0.14
            )
        }
        let sealedAt = createsDeviceSeal ? formatter.string(from: .now) : nil
        let payload = TicketPayload(
            ticketID: ticketID,
            fingerprint: fingerprint,
            headerTitle: edition == .collector
                ? String(format: "COLLECTOR · %@".appLocalized, result.type.localizedMemoryTemplateName)
                : String(format: "记忆重制 · %@".appLocalized, result.type.localizedMemoryTemplateName),
            title: result.title,
            subtitle: result.subtitle,
            message: message,
            captureTime: captureTime,
            place: result.place.isEmpty ? nil : result.place,
            device: "Apple Vision · 本机识别".appLocalized,
            lens: nil,
            captureSettings: nil,
            palette: paletteEntries,
            revealLayout: preferredLayout == .classic ? .classic : .vertical,
            revealWidthMode: .standard,
            style: "physical-rebirth",
            narrative: result.type.rawValue,
            sealedAt: sealedAt
        )
        let qrPayload: String?
        if createsDeviceSeal {
            qrPayload = try? TicketEnvelope.invocationURL(
                for: payload,
                baseURLString: TicketEnvelope.configuredBaseURLString,
                signer: TicketDeviceSealService.shared
            ).absoluteString
        } else {
            qrPayload = nil
        }
        return TicketStub(
            ticketID: ticketID,
            fingerprint: fingerprint,
            headerTitle: edition == .collector ? String(format: "COLLECTOR · %@".appLocalized, result.type.localizedMemoryTemplateName) : String(format: "记忆重制 · %@".appLocalized, result.type.localizedMemoryTemplateName),
            title: result.title,
            subtitle: result.subtitle,
            message: message,
            city: city,
            place: result.place.isEmpty ? nil : result.place,
            device: "Apple Vision · 本机识别".appLocalized,
            captureDate: result.date,
            captureTimeText: captureTime,
            layout: preferredLayout,
            theme: theme,
            palette: colors,
            isSealed: qrPayload != nil,
            isCapsule: false,
            artworkImageData: scaledImageData(),
            codeStyle: .verificationQR,
            qrPayload: qrPayload,
            barcodeValue: TicketEnvelope.barcodeValue(for: payload),
            isArchivedWork: false,
            physicalTicketType: result.type,
            isPhysicalImport: true,
            ticketColorName: colorName,
            ticketEdition: edition
        )
    }

    private var preferredLayout: PiaogenceLayoutStyle {
        switch result.type {
        case .performance, .musicFestival, .exhibition, .attraction:
            return .vertical
        case .movie, .train, .flight:
            return .classic
        case .other:
            return image.size.width >= image.size.height * 0.86 ? .classic : .vertical
        }
    }

    private func scaledImageData() -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return imageData }
        let scale = min(1, 1800 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.88)
    }
}
