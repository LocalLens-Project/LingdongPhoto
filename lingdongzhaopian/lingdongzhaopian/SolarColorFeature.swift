import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct SolarColorShareURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SolarColorTermRoute: Identifiable {
    let term: SolarTerm
    let seasonYear: Int
    var id: String { "\(seasonYear).\(term.rawValue)" }
}

private struct SolarColorImportDraft: Identifiable {
    let id = UUID()
    let photo: SelectedPhoto
    let capture: SolarColorCaptureDate?
    let palette: PaletteResult
}

private enum SolarColorText {
    static func seasonYear(_ year: Int) -> String {
        String(format: "%lld 节气年".appLocalized, Int64(year))
    }

    static func termAndSeasonYear(_ term: SolarTerm, year: Int) -> String {
        String(format: "%@ · %lld 节气年".appLocalized, term.localizedName, Int64(year))
    }
}

struct SolarColorFeatureRootView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var store = SolarColorStore.shared
    @State private var selectedYear: Int
    @State private var pickerPresented = false
    @State private var pickerSelections: [PhotoPickerSelection] = []
    @State private var importDraft: SolarColorImportDraft?
    @State private var selectedTerm: SolarColorTermRoute?
    @State private var shareItem: SolarColorShareURL?
    @State private var restorePresented = false
    @State private var isLoading = false
    @State private var message: String?
    @State private var didLoadPrefilledPhoto = false
    private let prefilledPhoto: SelectedPhoto?

    init(prefilledPhoto: SelectedPhoto? = nil) {
        self.prefilledPhoto = prefilledPhoto
        _selectedYear = State(initialValue: SolarTermCalendar.seasonYear(containing: .now)
            ?? Calendar.current.component(.year, from: .now))
    }

    private var completion: Int { store.completionCount(seasonYear: selectedYear) }
    private var isCurrentYear: Bool {
        selectedYear == SolarTermCalendar.seasonYear(containing: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    collectionHeader
                    yearControls
                    if let loadError = store.loadError {
                        warningCard(loadError)
                    }
                    seasons
                    outputCard
                    privacyNote
                }
                .padding(24)
                .padding(.bottom, 18)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭".appLocalized) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            exportBackup()
                        } label: {
                            Label("导出收藏备份".appLocalized, systemImage: "archivebox")
                        }
                        Button {
                            restorePresented = true
                        } label: {
                            Label("从备份恢复".appLocalized, systemImage: "arrow.down.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("收藏与备份".appLocalized)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button(action: openPicker) {
                        if isLoading {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .disabled(isLoading)
                    .accessibilityLabel(isLoading ? "正在读取照片…".appLocalized : "选择一张照片寻色".appLocalized)
                    .accessibilityHint("打开照片选择器".appLocalized)
                    .accessibilityIdentifier("solarColor.addPhoto")
                    Spacer()
                }
            }
        }
        .environment(\.colorScheme, colorScheme)
        .tint(colorScheme == .dark ? Color.white : Color.black)
        .sheet(isPresented: $pickerPresented) {
            PrivacyPreservingPhotoPicker(
                isPresented: $pickerPresented,
                selectionLimit: 1,
                colorScheme: colorScheme
            ) { pickerSelections = $0 }
            .ignoresSafeArea()
        }
        .onChange(of: pickerPresented) { _, presented in
            guard !presented, let selection = pickerSelections.first else { return }
            pickerSelections = []
            load(selection)
        }
        .sheet(item: $importDraft) { draft in
            SolarColorImportReviewView(draft: draft) { request in
                save(draft: draft, request: request)
            }
            .environment(\.colorScheme, colorScheme)
            .tint(colorScheme == .dark ? Color.white : Color.black)
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedTerm) { route in
            SolarColorTermDetailView(store: store, route: route)
                .environment(\.colorScheme, colorScheme)
                .tint(colorScheme == .dark ? Color.white : Color.black)
        }
        .sheet(item: $shareItem) { item in
            SystemShareSheet(url: item.url)
        }
        .fileImporter(
            isPresented: $restorePresented,
            allowedContentTypes: [UTType(filenameExtension: "lingdongseasons") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let count = try store.restore(from: url)
                    message = count == 0
                        ? "没有发现需要导入的新收藏。".appLocalized
                        : String(format: "已恢复 %d 条节气收藏。".appLocalized, count)
                } catch {
                    message = error.localizedDescription
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .alert("节气寻色".appLocalized, isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("好".appLocalized, role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
        .task {
            guard !didLoadPrefilledPhoto, let prefilledPhoto else { return }
            didLoadPrefilledPhoto = true
            importDraft = SolarColorImportDraft(
                photo: prefilledPhoto,
                capture: SolarColorCaptureDateReader.read(from: prefilledPhoto.originalData)
                    ?? prefilledPhoto.metadata.captureDate.map {
                        SolarColorCaptureDate(
                            date: $0,
                            source: .tiff,
                            timeZoneIdentifier: TimeZone.current.identifier,
                            usedFallbackTimeZone: true
                        )
                    },
                palette: PaletteExtractor.extract(from: prefilledPhoto.image)
            )
        }
    }

    private var background: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.055, green: 0.065, blue: 0.07), Color(red: 0.10, green: 0.12, blue: 0.11)]
                : [Color(red: 0.96, green: 0.955, blue: 0.92), Color(red: 0.91, green: 0.95, blue: 0.91)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var collectionHeader: some View {
        let current = SolarTermCalendar.occurrence(containing: .now)
        let currentRecord = current.flatMap {
            store.representative(seasonYear: $0.seasonYear, term: $0.term)
        }
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("二十四节气寻色".appLocalized)
                        .font(.largeTitle.bold())
                    Text("用自己的照片，收集一年二十四种传统色。".appLocalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "已寻得 %d / 24".appLocalized, completion))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .liquidGlass(in: Capsule(), variant: .clear)
                .accessibilityLabel(String(format: "已收集 %d 个，共 24 个节气".appLocalized, completion))
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if isCurrentYear, let current {
                        Text(String(format: "此刻 · %@".appLocalized, current.term.localizedName))
                            .font(.headline)
                        Text(SolarTermCalendar.dateRangeText(current))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(SolarColorText.seasonYear(selectedYear))
                            .font(.headline)
                        Text("立春至次年大寒".appLocalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let currentRecord, isCurrentYear,
                   let entry = TraditionalColorLexicon.entry(named: currentRecord.selectedColorName) {
                    HStack(spacing: 7) {
                        Circle().fill(entry.displayColor).frame(width: 22, height: 22)
                        Text(entry.localizedName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .accessibilityLabel(String(format: "本节气已寻得：%@".appLocalized, entry.localizedName))
                }
            }
        }
        .padding(.top, 8)
    }

    private var yearControls: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.65)
            HStack {
                Button { selectedYear -= 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 40, height: 40)
                }
                .disabled(selectedYear <= SolarTermCalendar.supportedYears.lowerBound)
                Spacer()
                VStack(spacing: 2) {
                    Text(SolarColorText.seasonYear(selectedYear))
                        .font(.headline)
                    if !isCurrentYear {
                        Button("回到今年".appLocalized) {
                            selectedYear = SolarTermCalendar.seasonYear(containing: .now) ?? selectedYear
                        }
                        .font(.caption)
                    }
                }
                Spacer()
                Button { selectedYear += 1 } label: {
                    Image(systemName: "chevron.right").frame(width: 40, height: 40)
                }
                .disabled(selectedYear >= SolarTermCalendar.supportedYears.upperBound - 1)
            }
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
    }

    private var seasons: some View {
        VStack(spacing: 22) {
            ForEach(0..<4, id: \.self) { season in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(["春", "夏", "秋", "冬"][season].appLocalized)
                            .font(.title3.weight(.semibold))
                        Rectangle().fill(.primary.opacity(0.10)).frame(height: 1)
                    }
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ], spacing: 10) {
                        ForEach(Array(SolarTermCalendar.seasonOrder[(season * 6)..<(season * 6 + 6)])) { term in
                            let record = store.representative(seasonYear: selectedYear, term: term)
                            SolarColorTermCell(
                                term: term,
                                occurrence: SolarTermCalendar.occurrence(term: term, seasonYear: selectedYear),
                                record: record,
                                image: record.flatMap { store.image(for: $0, thumbnail: true) }
                            ) {
                                selectedTerm = SolarColorTermRoute(term: term, seasonYear: selectedYear)
                            }
                        }
                    }
                }
            }
        }
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("我的一年二十四颜色".appLocalized, systemImage: "rectangle.grid.3x2.fill")
                .font(.headline)
            Text(completion == 24
                 ? "二十四种颜色已经完整，可以生成你的年度色谱。".appLocalized
                 : String(format: "现在也可以生成阶段色谱；尚未寻得的 %d 个节气会保留留白。".appLocalized, 24 - completion))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                exportYearArtwork()
            } label: {
                Label("生成年度色谱".appLocalized, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var privacyNote: some View {
        Label(
            "日期读取、照片取色与传统色匹配全部在本机完成。收藏仅保存去除位置等元数据的压缩副本。".appLocalized,
            systemImage: "lock.shield"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
    }

    private func warningCard(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private func openPicker() {
        guard !isLoading else { return }
        pickerPresented = true
    }

    private func load(_ selection: PhotoPickerSelection) {
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            do {
                let photo = try await PhotoAssetLoader.load(selection, includeLiveResource: false)
                let capture = SolarColorCaptureDateReader.read(from: photo.originalData)
                    ?? photo.metadata.captureDate.map {
                        SolarColorCaptureDate(
                            date: $0,
                            source: .tiff,
                            timeZoneIdentifier: TimeZone.current.identifier,
                            usedFallbackTimeZone: true
                        )
                    }
                importDraft = SolarColorImportDraft(
                    photo: photo,
                    capture: capture,
                    palette: PaletteExtractor.extract(from: photo.image)
                )
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func save(draft: SolarColorImportDraft, request: SolarColorCommitRequest) {
        do {
            let record = try store.add(
                photo: draft.photo,
                captureDate: request.captureDate,
                dateSource: request.dateSource,
                captureTimeZoneIdentifier: request.timeZoneIdentifier,
                usedFallbackTimeZone: request.usedFallbackTimeZone,
                occurrence: request.occurrence,
                palette: draft.palette,
                suggestedColorNames: request.suggestedColorNames,
                selectedColorName: request.selectedColorName
            )
            selectedYear = record.seasonYear
            importDraft = nil
            selectedTerm = SolarColorTermRoute(term: record.term, seasonYear: record.seasonYear)
        } catch {
            message = error.localizedDescription
        }
    }

    private func exportBackup() {
        do { shareItem = SolarColorShareURL(url: try store.makeBackupURL()) }
        catch { message = error.localizedDescription }
    }

    @MainActor private func exportYearArtwork() {
        let items = SolarTermCalendar.seasonOrder.map { term -> SolarColorArtworkItem in
            let record = store.representative(seasonYear: selectedYear, term: term)
            let entry = record.flatMap { TraditionalColorLexicon.entry(named: $0.selectedColorName) }
            return SolarColorArtworkItem(
                term: term,
                colorName: entry?.name,
                displayName: entry?.localizedName,
                displayColor: entry?.displayColor,
                image: record.flatMap { store.image(for: $0, thumbnail: true) }
            )
        }
        let view = SolarColorYearArtwork(seasonYear: selectedYear, items: items)
            .frame(width: 540, height: 960)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            message = "年度色谱生成失败，请重试。".appLocalized
            return
        }
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(String(
                    format: "我的 %lld 节气颜色.png".appLocalized,
                    Int64(selectedYear)
                ))
            try data.write(to: url, options: .atomic)
            shareItem = SolarColorShareURL(url: url)
        } catch { message = error.localizedDescription }
    }
}

private struct SolarColorTermCell: View {
    let term: SolarTerm
    let occurrence: SolarTermOccurrence?
    let record: SolarColorRecord?
    let image: UIImage?
    let action: () -> Void

    private var entry: TraditionalColorEntry? {
        record.flatMap { TraditionalColorLexicon.entry(named: $0.selectedColorName) }
    }

    private var status: String {
        if let record { return record.wasDateManuallyProvided ? "手动补录".appLocalized : "已寻得".appLocalized }
        guard let occurrence else { return "不可用".appLocalized }
        if Date.now < occurrence.instant { return "未到".appLocalized }
        if Date.now < occurrence.nextInstant { return "当令".appLocalized }
        return "待寻".appLocalized
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(entry?.displayColor ?? Color.primary.opacity(0.055))
                    if let image {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .overlay((entry?.displayColor ?? .clear).opacity(0.28))
                    } else {
                        Image(systemName: record == nil ? "circle.dotted" : "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 54, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(term.localizedName).font(.headline)
                        if record?.isNearOccurrence == true {
                            Image(systemName: "seal.fill").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    Text(entry?.localizedName ?? status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let occurrence {
                        Text(SolarTermCalendar.dateRangeText(occurrence))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(term.localizedName)，\(status)\(entry.map { "，\($0.localizedName)" } ?? "")")
    }
}

private struct SolarColorCommitRequest {
    let captureDate: Date
    let dateSource: SolarColorCaptureDateSource
    let timeZoneIdentifier: String?
    let usedFallbackTimeZone: Bool
    let occurrence: SolarTermOccurrence
    let suggestedColorNames: [String]
    let selectedColorName: String
}

private struct SolarColorImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let draft: SolarColorImportDraft
    let onSave: (SolarColorCommitRequest) -> Void
    private let saveActionPanelHeight: CGFloat = 112

    @State private var captureDate: Date
    @State private var dateSource: SolarColorCaptureDateSource
    @State private var selectedColorName: String
    @State private var showsAllColors = false

    init(draft: SolarColorImportDraft, onSave: @escaping (SolarColorCommitRequest) -> Void) {
        self.draft = draft
        self.onSave = onSave
        let date = draft.capture?.date ?? .now
        let source = draft.capture?.source ?? .manuallyProvided
        let occurrence = SolarTermCalendar.occurrence(containing: date)
        let first = occurrence.flatMap {
            SolarColorMatcher.candidates(palette: draft.palette, term: $0.term).first?.entry.name
        } ?? ""
        _captureDate = State(initialValue: date)
        _dateSource = State(initialValue: source)
        _selectedColorName = State(initialValue: first)
    }

    private var occurrence: SolarTermOccurrence? {
        SolarTermCalendar.occurrence(containing: captureDate)
    }

    private var candidates: [SolarColorMatchCandidate] {
        occurrence.map { SolarColorMatcher.candidates(palette: draft.palette, term: $0.term) } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: draft.photo.image)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    dateCard
                    paletteCard
                    matchesCard
                }
                .padding(18)
                .padding(.bottom, saveActionPanelHeight + 16)
            }
            .navigationTitle("确认节气与颜色".appLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消".appLocalized) { dismiss() }
                }
            }
        }
        .overlay(alignment: .bottom) {
            saveActionPanel
        }
        .onChange(of: captureDate) { old, new in
            if abs(new.timeIntervalSince(old)) > 1 { dateSource = .manuallyProvided }
            if let term = occurrence?.term,
               !TraditionalColorLexicon.entries(for: term).contains(where: { $0.name == selectedColorName }) {
                selectedColorName = candidates.first?.entry.name ?? ""
            }
        }
    }

    private var saveActionPanel: some View {
        Button {
            guard let occurrence, !selectedColorName.isEmpty else { return }
            onSave(SolarColorCommitRequest(
                captureDate: captureDate,
                dateSource: dateSource,
                timeZoneIdentifier: dateSource == .manuallyProvided
                    ? TimeZone.current.identifier : draft.capture?.timeZoneIdentifier,
                usedFallbackTimeZone: dateSource == .manuallyProvided
                    ? true : draft.capture?.usedFallbackTimeZone ?? true,
                occurrence: occurrence,
                suggestedColorNames: candidates.map(\.entry.name),
                selectedColorName: selectedColorName
            ))
        } label: {
            Text(saveTitle)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Color(red: 0.20, green: 0.38, blue: 0.27))
        .disabled(occurrence == nil || selectedColorName.isEmpty || captureDate > Date.now.addingTimeInterval(86_400))
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                colors: [
                    .clear,
                    Color(uiColor: .systemBackground).opacity(0.86),
                    Color(uiColor: .systemBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("照片日期".appLocalized, systemImage: "calendar")
                .font(.headline)
            if draft.capture == nil {
                Label(
                    "照片没有可读取的拍摄日期。请补录日期后再收藏；卡片会保留“手动补录”标识。".appLocalized,
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
            DatePicker(
                "拍摄日期".appLocalized,
                selection: $captureDate,
                in: SolarTermCalendar.minimumSupportedDate...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
            if let occurrence {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(SolarColorText.termAndSeasonYear(
                            occurrence.term,
                            year: occurrence.seasonYear
                        ))
                            .font(.headline)
                        Text("\(SolarTermCalendar.dateRangeText(occurrence)) · \(dateSource.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if SolarTermCalendar.isNearBoundary(captureDate, occurrence: occurrence) {
                        Label("当令".appLocalized, systemImage: "seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text("当前日期超出支持范围。".appLocalized).foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var paletteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("照片中的六种主色".appLocalized).font(.headline)
            HStack(spacing: 6) {
                ForEach(Array(zip(draft.palette.colors, draft.palette.percentages).enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10).fill(item.0.color).frame(height: 52)
                        Text("\(item.1, specifier: "%.0f")%")
                            .font(.caption2.monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var matchesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(occurrence.map { String(format: "%@十六色中的推荐".appLocalized, $0.term.localizedName) }
                 ?? "传统色推荐".appLocalized)
                .font(.headline)
            ForEach(candidates) { candidate in
                colorChoice(candidate.entry, sampledColor: candidate.sampledColor,
                            percentage: candidate.sampledPercentage, recommended: true)
            }
            Button(showsAllColors ? "收起完整色组".appLocalized : "查看完整十六色".appLocalized) {
                withAnimation(.easeInOut(duration: 0.2)) { showsAllColors.toggle() }
            }
            .font(.subheadline.weight(.semibold))
            if showsAllColors, let term = occurrence?.term {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(TraditionalColorLexicon.entries(for: term), id: \.name) { entry in
                        colorChoice(entry, sampledColor: nil, percentage: nil, recommended: false)
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func colorChoice(
        _ entry: TraditionalColorEntry,
        sampledColor: RGBColor?,
        percentage: Double?,
        recommended: Bool
    ) -> some View {
        let selected = selectedColorName == entry.name
        return Button { selectedColorName = entry.name } label: {
            HStack(spacing: 10) {
                Circle().fill(entry.displayColor).frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.localizedName).font(.subheadline.weight(.semibold))
                    if recommended, let sampledColor, let percentage {
                        HStack(spacing: 4) {
                            Circle().fill(sampledColor.color).frame(width: 10, height: 10)
                            Text(String(format: "来自照片主色 · %.0f%%".appLocalized, percentage))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("\(entry.localizedPentad) · \(entry.localizedRole)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.green : Color.secondary)
            }
            .padding(recommended ? 12 : 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.green.opacity(0.10) : Color.primary.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    private var saveTitle: String {
        let name = TraditionalColorLexicon.entry(named: selectedColorName)?.localizedName ?? selectedColorName
        return occurrence.map {
            String(format: "以“%@”收藏%@".appLocalized, name, $0.term.localizedName)
        } ?? "保存".appLocalized
    }
}

private struct SolarColorTermDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    let store: SolarColorStore
    let route: SolarColorTermRoute
    @State private var shareItem: SolarColorShareURL?
    @State private var errorMessage: String?
    @State private var deleteTarget: SolarColorRecord?
    @State private var poeticSourcePromptPresented = false
    @State private var poeticSourcePromptDismissTask: Task<Void, Never>?
    @State private var supportUsPresented = false

    private var records: [SolarColorRecord] {
        store.records(seasonYear: route.seasonYear, term: route.term)
    }
    private var representative: SolarColorRecord? {
        store.representative(seasonYear: route.seasonYear, term: route.term)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let representative { representativeCard(representative) }
                    else { emptyCard }
                    if representative != nil { colorGroup }
                    else { lockedColorGroup }
                    if !records.isEmpty { recordsSection }
                }
                .padding(18)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("\(route.term.localizedName) · \(route.seasonYear)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成".appLocalized) { dismiss() }
                }
                if representative != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { shareArtwork() } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
        }
        .sheet(item: $shareItem) { item in SystemShareSheet(url: item.url) }
        .fullScreenCover(isPresented: $supportUsPresented) {
            SupportUsView()
        }
        .overlay(alignment: .bottom) {
            if poeticSourcePromptPresented && !supporterUnlocked {
                SupporterProUnlockPrompt(
                    message: "支持我们，即可查看节气寻色中传统色的诗词与可考出处。".appLocalized
                ) {
                    poeticSourcePromptDismissTask?.cancel()
                    withAnimation(.easeOut(duration: 0.18)) {
                        poeticSourcePromptPresented = false
                    }
                    supportUsPresented = true
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: poeticSourcePromptPresented)
        .onChange(of: supporterUnlocked) { _, unlocked in
            guard unlocked else { return }
            poeticSourcePromptDismissTask?.cancel()
            poeticSourcePromptPresented = false
            supportUsPresented = false
        }
        .onDisappear {
            poeticSourcePromptDismissTask?.cancel()
        }
        .alert("删除这条收藏？".appLocalized, isPresented: Binding(
            get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("删除".appLocalized, role: .destructive) {
                if let record = deleteTarget { perform { try store.delete(record) } }
                deleteTarget = nil
            }
            Button("取消".appLocalized, role: .cancel) { deleteTarget = nil }
        } message: {
            Text("已生成并保存到系统中的图片不会受到影响。".appLocalized)
        }
        .alert("节气寻色".appLocalized, isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好".appLocalized, role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.term.localizedName)
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                if let occurrence = SolarTermCalendar.occurrence(term: route.term, seasonYear: route.seasonYear) {
                    Text("\(SolarTermCalendar.dateRangeText(occurrence)) · \(route.term.seasonName)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(String(format: "%lld 张".appLocalized, Int64(records.count)))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
        }
    }

    private func representativeCard(_ record: SolarColorRecord) -> some View {
        let entry = TraditionalColorLexicon.entry(named: record.selectedColorName)
        return VStack(alignment: .leading, spacing: 12) {
            if let image = store.image(for: record) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            HStack {
                Circle().fill(entry?.displayColor ?? .gray).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry?.localizedName ?? record.selectedColorName).font(.title3.weight(.semibold))
                    Text("\(SolarTermCalendar.dateTimeText(record.captureDate)) · \(record.captureDateSource.title)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if record.isNearOccurrence {
                    Label("当令".appLocalized, systemImage: "seal.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }
            if let entry, !entry.localizedQuote.isEmpty {
                poeticSourceBlock(entry)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func poeticSourceBlock(_ entry: TraditionalColorEntry) -> some View {
        let byline = [entry.localizedAuthor, entry.localizedSource]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 7) {
            Text("“\(entry.localizedQuote)”")
                .font(.callout)
                .italic()
                .foregroundStyle(.secondary)
            if !byline.isEmpty {
                Text(byline)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, supporterUnlocked ? 0 : 30)
        .blur(radius: supporterUnlocked ? 0 : 11)
        .overlay {
            if !supporterUnlocked {
                LinearGradient(
                    colors: [.clear, Color.primary.opacity(0.13), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .overlay(alignment: .trailing) {
            if !supporterUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.76))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !supporterUnlocked else { return }
            presentPoeticSourcePrompt()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            supporterUnlocked
                ? "\(entry.localizedQuote)，\(byline)"
                : "诗词与出处，PRO 内容".appLocalized
        )
        .accessibilityHint(supporterUnlocked ? "" : "轻点了解支持者权益".appLocalized)
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

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.macro.circle").font(.system(size: 42)).foregroundStyle(.secondary)
            Text("还没有找到这一节气的颜色".appLocalized).font(.headline)
            Text("回到年度页面，选择这个日期范围内拍摄的照片。".appLocalized)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var lockedColorGroup: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color.primary.opacity(0.045 + Double(index % 3) * 0.025))
                        .frame(width: 24, height: 24)
                }
            }
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
            Text(String(
                format: "寻得一种颜色后，解锁%@完整十六色。".appLocalized,
                route.term.localizedName
            ))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var colorGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: "%@十六色".appLocalized, route.term.localizedName))
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(TraditionalColorLexicon.entries(for: route.term), id: \.name) { entry in
                    let selected = representative?.selectedColorName == entry.name
                    Button {
                        if let record = representative {
                            perform { try store.changeSelectedColor(entry.name, for: record) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(entry.displayColor).frame(width: 25, height: 25)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.localizedName).font(.caption.weight(.semibold)).lineLimit(1)
                                Text("\(entry.localizedPentad) · \(entry.localizedRole)")
                                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if selected { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.green) }
                        }
                        .padding(9)
                        .background(selected ? Color.green.opacity(0.11) : Color.primary.opacity(0.035),
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(representative == nil)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这一节气的照片".appLocalized).font(.headline)
            ForEach(records) { record in
                HStack(spacing: 12) {
                    if let image = store.image(for: record, thumbnail: true) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 66, height: 66).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TraditionalColorLexicon.entry(named: record.selectedColorName)?.localizedName
                             ?? record.selectedColorName)
                            .font(.subheadline.weight(.semibold))
                        Text(SolarTermCalendar.dateTimeText(record.captureDate))
                            .font(.caption).foregroundStyle(.secondary)
                        if representative?.id == record.id {
                            Text("年度代表作".appLocalized).font(.caption2.weight(.semibold)).foregroundStyle(.green)
                        }
                    }
                    Spacer()
                    Menu {
                        if representative?.id != record.id {
                            Button("设为代表作".appLocalized) { perform { try store.chooseRepresentative(record) } }
                        }
                        Button("删除".appLocalized, role: .destructive) { deleteTarget = record }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 40, height: 40) }
                }
                .padding(10)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    @MainActor private func shareArtwork() {
        guard let record = representative,
              let entry = TraditionalColorLexicon.entry(named: record.selectedColorName) else { return }
        let view = SolarColorTermArtwork(
            record: record,
            entry: entry,
            image: store.image(for: record)
        ).frame(width: 540, height: 720)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            errorMessage = "色卡生成失败，请重试。".appLocalized
            return
        }
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "\(route.seasonYear)-\(route.term.localizedName)-\(entry.localizedName).png"
                )
            try data.write(to: url, options: .atomic)
            shareItem = SolarColorShareURL(url: url)
        } catch { errorMessage = error.localizedDescription }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { errorMessage = error.localizedDescription }
    }
}

private struct SolarColorArtworkItem {
    let term: SolarTerm
    let colorName: String?
    let displayName: String?
    let displayColor: Color?
    let image: UIImage?
}

private struct SolarColorYearArtwork: View {
    let seasonYear: Int
    let items: [SolarColorArtworkItem]

    var body: some View {
        ZStack {
            Color(red: 0.955, green: 0.94, blue: 0.88)
            VStack(spacing: 22) {
                VStack(spacing: 5) {
                    Text("我的一年二十四颜色".appLocalized)
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                    Text(String(
                        format: "%lld 节气年 · %@".appLocalized,
                        Int64(seasonYear),
                        "立春至次年大寒".appLocalized
                    ))
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                VStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { season in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(["春", "夏", "秋", "冬"][season].appLocalized)
                                .font(.system(size: 12, weight: .bold, design: .serif))
                            HStack(spacing: 7) {
                                ForEach(Array(items[(season * 6)..<(season * 6 + 6)]), id: \.term) { item in
                                    VStack(spacing: 5) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 11)
                                                .fill(item.displayColor ?? Color.black.opacity(0.055))
                                            if let image = item.image {
                                                Image(uiImage: image).resizable().scaledToFill().opacity(0.55)
                                                    .overlay((item.displayColor ?? .clear).opacity(0.30))
                                            }
                                        }
                                        .frame(height: 104)
                                        .clipShape(RoundedRectangle(cornerRadius: 11))
                                        Text(item.term.localizedName).font(.system(size: 9, weight: .semibold))
                                        Text(item.displayName ?? "未寻".appLocalized)
                                            .font(.system(size: 7)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Text("LINGDONG PHOTO · LOCAL COLOR ARCHIVE")
                    Spacer()
                    Text("\(items.filter { $0.colorName != nil }.count) / 24")
                }
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 30).padding(.vertical, 32)
        }
        .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.11))
    }
}

private struct SolarColorTermArtwork: View {
    let record: SolarColorRecord
    let entry: TraditionalColorEntry
    let image: UIImage?

    var body: some View {
        ZStack {
            entry.displayColor
            VStack(spacing: 0) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(height: 455).clipped()
                } else {
                    entry.displayColor.frame(height: 455)
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(record.term.localizedName)
                            .font(.system(size: 37, weight: .semibold, design: .serif))
                        Text(entry.localizedName)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                        Text(String(
                            format: "%lld 节气年 · %@".appLocalized,
                            Int64(record.seasonYear),
                            SolarTermCalendar.dateTimeText(record.captureDate)
                        ))
                            .font(.system(size: 9, weight: .medium))
                            .opacity(0.68)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(.primary.opacity(0.65), lineWidth: 1.5)
                        Text(record.isNearOccurrence ? "当令".appLocalized : "寻\n色".appLocalized)
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 55, height: 55)
                }
                .padding(28)
                .frame(maxHeight: .infinity)
                .background(.white.opacity(0.82))
            }
        }
        .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.10))
    }
}

private extension TraditionalColorEntry {
    var displayColor: Color {
        Color(
            red: Double(rgb.0) / 255,
            green: Double(rgb.1) / 255,
            blue: Double(rgb.2) / 255
        )
    }

    var localizedPentad: String {
        pentad.appLocalized
    }
}

private extension SolarTermCalendar {
    static var minimumSupportedDate: Date {
        cycle(forSeasonYear: supportedYears.lowerBound).first?.instant ?? .distantPast
    }
}
