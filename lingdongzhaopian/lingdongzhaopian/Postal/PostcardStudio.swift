import SwiftUI

struct PostcardStudio: View {
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var model = PostalEditorModel()
    let store: PostalStore
    private let pendingSource: PostalSource?
    @State private var step: PostalCreationStep = .template
    @State private var draft = PostcardDraft()
    @State private var selectedStamp: PostalStamp?
    @State private var includesStamp = true
    @State private var largePreview: PostalArtworkPreviewItem?
    @State private var preview: UIImage?
    @State private var library = false
    @State private var stampPicker = false
    @State private var stampEditor = false
    @State private var editing = false
    @State private var editTab = 0
    @State private var fontTarget = 0
    @State private var picker = false
    @State private var camera = false
    @State private var reusePhoto = false
    @State private var busy = false
    @State private var notice: String?
    @State private var renderTask: Task<Void, Never>?

    init(photo: SelectedPhoto? = nil, source: PostalSource? = nil, stamp: PostalStamp? = nil, store: PostalStore? = nil) {
        pendingSource = source ?? photo.map {
            PostalSource(
                image: $0.image,
                metadata: $0.metadata,
                liveVideoURL: nil
            )
        }
        _selectedStamp = State(initialValue: stamp); self.store = store ?? .shared
    }
    private var selection: Binding<Int> {
        Binding(get: { PostcardStyle.allCases.firstIndex(of: draft.style) ?? 0 },
                set: { draft.style = PostcardStyle.allCases[$0] })
    }
    private var canSave: Bool {
        templateAvailable && step.canSave(hasPhoto: model.source != nil, busy: busy || model.isLoading, resolving: model.isResolvingCity)
    }
    private var templateAvailable: Bool { PostalTemplate.postcard(draft.style).isAvailable(hasPro: supporterUnlocked) }
    private var roomy: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    var body: some View {
        NavigationStack {
            creationScreen
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $editing) { editingPage }
        }
    }
    private var creationScreen: some View {
        observedScreen
            .modifier(PostalPhotoImport(model: model, picker: $picker, camera: $camera))
            .confirmationDialog("放入照片", isPresented: $reusePhoto, titleVisibility: .visible) {
                Button("使用已选照片") { if let pendingSource { Task { await model.acceptSource(pendingSource) } } }
                Button("从相册选择") { picker = true }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $library) { PostalStampLibrary(store: store) }

            .alert("明信片", isPresented: Binding(get: { notice != nil || model.error != nil }, set: { if !$0 { notice = nil; model.error = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(notice ?? model.error ?? "") }
            .fullScreenCover(item: $largePreview) { item in
                PostalArtworkPreview(item: item).ignoresSafeArea()
            }
            .interactiveDismissDisabled(busy || model.isLoading)
    }
    private var screen: some View {
        PostalFlowPage(title: "明信片", step: step, templates: PostcardStyle.allCases.map(PostalTemplate.postcard),
                       selection: selection, model: model, preview: preview, busy: busy || model.isLoading,
                       onBack: goBack, onPhoto: requestPhoto, onPreview: showLargePreview, onNext: next,
                       onLibrary: { library = true }, onCamera: { if templateAvailable { camera = true } }) {
            VStack(spacing: roomy ? 14 : 6) {
                PostalFlowAction(title: "调整文字与邮戳", symbol: "pencil.line", enabled: model.source != nil && !busy && !model.isLoading) {
                    editing = true
                }.accessibilityIdentifier("postal.editPostcard")
                PostalFlowAction(title: "保存明信片到相册", symbol: "square.and.arrow.down", enabled: canSave) {
                    Task { await export() }
                }.accessibilityIdentifier("postal.exportPostcard")
                if busy { ProgressView("正在保存…").font(.caption) }
            }
        }
    }
    private var editingPage: some View {
        PostalEditingPage(title: "调整明信片", preview: preview, tint: model.tint,
                          tabs: ["内容", "字体", "邮戳"], selection: $editTab,
                          onPreview: showLargePreview, onDone: { editing = false }) {
            VStack(alignment: .leading, spacing: 18) {
                if editTab == 0 {
                    field("寄语", text: $draft.message, limit: 100, lines: 2...4)
                    field("日期", text: $draft.date, limit: 24)
                    field("地址", text: $draft.address, limit: 100, lines: 1...3)
                    if draft.style == .seasonal {
                        field("书法标题", text: $draft.title, limit: 8)
                        Text("节气按拍摄日期与内置日期表推导；交节日期每年略有差异，可自行修改。")
                            .font(roomy ? .subheadline : .caption2)
                            .foregroundStyle(.secondary)
                        field("诗意文案", text: $draft.poem, limit: 64, lines: 2...3)
                        field("竖排文字", text: $draft.verticalText, limit: 20)
                        Toggle("雪点装饰", isOn: $draft.snow)
                    }
                } else if editTab == 1 {
                    Picker("字体用途", selection: $fontTarget) {
                        Text("卡片文字").tag(0); Text("邮戳文字").tag(1)
                    }.pickerStyle(.segmented)
                    PostalFontPicker(selection: fontTarget == 0 ? $draft.font : $draft.postmarkFont)
                } else {
                    Toggle("贴上邮票", isOn: $includesStamp)
                    Text(verbatim: selectedStamp.map {
                        String(
                            format: "使用已收藏邮票 · %@".appLocalized,
                            $0.city?.name ?? "普通邮票".appLocalized
                        )
                    } ?? "默认用当前照片制作一枚 3:4 邮票".appLocalized)
                        .font(roomy ? .body : .caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("已有邮票") { stampPicker = true }
                        Spacer()
                        Button("制作新邮票") { stampEditor = true }
                    }
                    if selectedStamp != nil { Button("改用当前照片邮票") { selectedStamp = nil } }
                    Text("邮戳地名来自背景照片；没有定位时显示「旅途留念」。日期可在「内容」中修改，不影响照片原始信息。")
                        .font(roomy ? .subheadline : .caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $stampPicker) {
            PostalStampLibrary(store: store, onSelect: { selectedStamp = $0; stampPicker = false })
        }
        .fullScreenCover(isPresented: $stampEditor) {
            StampStudio(source: model.source, store: store, onSaved: { selectedStamp = $0; stampEditor = false })
        }
    }
    private func next() {
        guard templateAvailable else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { step = .photo }
    }
    private func goBack() {
        if step == .photo { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { step = .template } }
        else { dismiss() }
    }
    private func showLargePreview() {
        guard step == .photo, !busy, !model.isLoading, let source = model.source else { return }
        do {
            let image = PostcardRenderer.render(photo: source.image, stamp: try stampImage(), draft: draft, tint: model.tint)
            largePreview = try PostalArtworkPreviewItem(image: image, title: "明信片")
        } catch { model.error = error.localizedDescription }
    }
    private func requestPhoto() {
        guard templateAvailable, step == .photo, !busy, !model.isLoading else { return }
        if pendingSource != nil && model.source == nil { reusePhoto = true } else { picker = true }
    }
    private var observedScreen: some View {
        screen
            .onChange(of: model.source?.image) { _, _ in
                if let source = model.source { draft.useMetadata(source.metadata, city: source.city) }
                updatePreview()
            }
            .onChange(of: model.source?.city) { _, _ in
                draft.city = model.source?.city?.name ?? "旅途留念".appLocalized
                updatePreview()
            }
            .onChange(of: draft) { _, _ in updatePreview() }
            .onChange(of: selectedStamp) { _, _ in updatePreview() }
            .onChange(of: includesStamp) { _, _ in updatePreview() }
            .onChange(of: store.stamps) { _, stamps in
                if let selectedStamp, !stamps.contains(where: { $0.id == selectedStamp.id }) { self.selectedStamp = nil }
            }
            .onDisappear { renderTask?.cancel() }
    }
    private func field(_ label: String, text: Binding<String>, limit: Int, lines: ClosedRange<Int> = 1...1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(label))
                .font(roomy ? .body : .caption)
                .foregroundStyle(.secondary)
            TextField(label.appLocalized, text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(limit)) }), axis: .vertical)
                .lineLimit(lines).textFieldStyle(.plain)
                .padding(roomy ? 16 : 12)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("postal.field.\(label)")
        }
    }
    private func stampImage() throws -> UIImage? {
        guard includesStamp else { return nil }
        if let selectedStamp {
            guard let image = store.image(selectedStamp, fullSize: true) else { throw PostalError.image }
            return image
        }
        guard let source = model.source else { return nil }
        return try StampRenderer.render(photo: source.image, format: .classic)
    }
    private func updatePreview() {
        renderTask?.cancel()
        renderTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled, let source = model.source else { return }
                preview = PostcardRenderer.render(photo: source.image, stamp: try stampImage(), draft: draft, tint: model.tint, preview: true)
            } catch is CancellationError {} catch { model.error = error.localizedDescription }
        }
    }
    private func export() async {
        guard canSave, let source = model.source else { return }
        busy = true; defer { busy = false }
        do {
            let image = PostcardRenderer.render(photo: source.image, stamp: try stampImage(), draft: draft, tint: model.tint)
            try await PostalPhotoWriter.save(image)
            notice = String(
                format: "已保存 %lld × %lld PNG 明信片。".appLocalized,
                Int64(image.size.width),
                Int64(image.size.height)
            )
        } catch { model.error = error.localizedDescription }
    }
}
