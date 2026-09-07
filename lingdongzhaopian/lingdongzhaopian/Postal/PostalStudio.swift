import SwiftUI
import CoreLocation
import AVFoundation

struct PostalSource {
    let image: UIImage
    var metadata: PhotoMetadata
    var city: PostalCity?
}

@MainActor @Observable
final class PostalEditorModel {
    var source: PostalSource?
    var tint = PostalTint()
    var isLoading = false
    var isResolvingCity = false
    var locationMessage = ""
    var error: String?
    private var importID = UUID()

    init(photo: SelectedPhoto? = nil, source: PostalSource? = nil) {
        self.source = source ?? photo.map { PostalSource(image: $0.image, metadata: $0.metadata) }
        if let image = self.source?.image { tint = .extract(image) }
    }
    func load(_ selection: PhotoPickerSelection) async {
        let id = UUID(); importID = id; isLoading = true; isResolvingCity = false
        defer { if id == importID { isLoading = false } }
        do {
            let photo = try await PhotoAssetLoader.load(selection, includeLiveResource: false)
            defer { PhotoAssetLoader.removeTemporaryResources(for: [photo]) }
            guard id == importID, !Task.isCancelled else { return }
            source = PostalSource(image: photo.image, metadata: photo.metadata)
            tint = .extract(photo.image)
            await resolveCity()
        } catch { if id == importID { self.error = error.localizedDescription } }
    }
    func resolveCity() async {
        guard var current = source else { return }
        guard current.metadata.hasLocation else {
            locationMessage = "未记录定位 · 可制作普通邮票".appLocalized; return
        }
        if let city = current.city {
            current.city = PostalCityResolver.collectionCity(for: city)
            source = current
            locationMessage = current.city.map {
                String(format: "%@ · 可加入邮集".appLocalized, $0.name)
            }
                ?? PostalError.cityNotCollected.localizedDescription
            return
        }
        let id = importID
        isResolvingCity = true
        defer { if id == importID { isResolvingCity = false } }
        locationMessage = "正在确定照片所在城市…".appLocalized
        do {
            current.city = try await PostalCity.resolve(current.metadata)
            guard id == importID, !Task.isCancelled else { return }
            source = current
            locationMessage = String(
                format: "%@ · 可加入邮集".appLocalized,
                current.city?.name ?? ""
            )
        } catch {
            guard id == importID else { return }
            locationMessage = (error as? PostalError)?.errorDescription
                ?? "城市识别失败 · 可重试或保存普通邮票".appLocalized
        }
    }
    func acceptSource(_ incoming: PostalSource) async {
        let id = UUID(); importID = id; isLoading = true; isResolvingCity = false
        defer { if id == importID { isLoading = false } }
        source = incoming; tint = .extract(incoming.image)
        await resolveCity()
    }
    func acceptCamera(image: UIImage, location: CLLocation?, capturedAt: Date) async {
        let metadata = PhotoMetadata(captureDate: capturedAt, latitude: location?.coordinate.latitude,
                                     longitude: location?.coordinate.longitude)
        await acceptSource(PostalSource(image: image, metadata: metadata))
    }
}

enum PostalDestination: String, Identifiable {
    case stamp, postcard, collection
    var id: String { rawValue }
}

struct PostalBackground: View {
    var tint: PostalTint
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            RadialGradient(colors: [tint.color.opacity(0.28), .clear], center: .topLeading,
                           startRadius: 10, endRadius: 650)
        }.ignoresSafeArea()
    }
}

struct PostalPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 15) { content }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 26), variant: .clear)
    }
}

struct StampStudio: View {
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = PostalEditorModel()
    let store: PostalStore
    let targetCity: PostalCity?
    private let pendingSource: PostalSource?
    var onSaved: ((PostalStamp) -> Void)?
    @State private var step: PostalCreationStep = .template
    @State private var format: StampFormat = .classic
    @State private var transform = StampTransform()
    @State private var lettering = StampLettering()
    @State private var editTab = 0
    @State private var largePreview: PostalArtworkPreviewItem?
    @State private var preview: UIImage?
    @State private var savedStamp: PostalStamp?
    @State private var busy = false
    @State private var notice: String?
    @State private var library = false
    @State private var postcard = false
    @State private var adjustments = false
    @State private var picker = false
    @State private var camera = false
    @State private var reusePhoto = false

    init(photo: SelectedPhoto? = nil, source: PostalSource? = nil, store: PostalStore? = nil,
         targetCity: PostalCity? = nil, onSaved: ((PostalStamp) -> Void)? = nil) {
        pendingSource = source ?? photo.map { PostalSource(image: $0.image, metadata: $0.metadata) }
        self.store = store ?? .shared; self.targetCity = targetCity; self.onSaved = onSaved
    }
    private var selection: Binding<Int> {
        Binding(get: { StampFormat.allCases.firstIndex(of: format) ?? 0 },
                set: { format = StampFormat.allCases[$0] })
    }
    private var canSave: Bool {
        templateAvailable && step.canSave(hasPhoto: model.source != nil, busy: busy || model.isLoading, resolving: model.isResolvingCity)
    }
    private var templateAvailable: Bool { PostalTemplate.stamp(format).isAvailable(hasPro: supporterUnlocked) }
    var body: some View {
        NavigationStack {
            creationScreen
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $adjustments) { adjustmentPage }
        }
    }
    private var creationScreen: some View {
        PostalFlowPage(title: "邮票制作", step: step, templates: StampFormat.allCases.map(PostalTemplate.stamp),
                       selection: selection, model: model, preview: preview, busy: busy || model.isLoading,
                       onBack: goBack, onPhoto: requestPhoto, onPreview: showLargePreview, onNext: next,
                       onLibrary: { library = true }, onCamera: { if templateAvailable { camera = true } }) {
            VStack(spacing: 2) {
                if model.source != nil {
                    PostalFlowAction(
                        title: "调整构图与文字",
                        symbol: "crop",
                        enabled: !busy && !model.isLoading
                    ) { adjustments = true }
                    .padding(.bottom, 10)
                    .accessibilityIdentifier("postal.adjustPhoto")
                }
                PostalFlowAction(title: targetCity == nil ? "收藏邮票" : "收藏并设为默认邮票",
                                 symbol: "square.and.arrow.down", enabled: canSave) {
                    Task { await save(toPhotos: false) }
                }.accessibilityIdentifier("postal.saveStamp")
                PostalFlowAction(title: "保存 PNG 到相册", symbol: "photo.badge.arrow.down", enabled: canSave) {
                    Task { await save(toPhotos: true) }
                }.accessibilityIdentifier("postal.exportStamp")
                PostalFlowAction(title: "用这枚邮票制作明信片", symbol: "envelope", enabled: canSave) {
                    Task {
                        guard canSave else { return }
                        busy = true; defer { busy = false }
                        if await collect() != nil { postcard = true }
                    }
                }.accessibilityIdentifier("postal.usePostcard")
                if busy { ProgressView("正在保存…").font(.caption) }
            }
        }
        .modifier(PostalPhotoImport(model: model, picker: $picker, camera: $camera))
        .confirmationDialog("放入照片", isPresented: $reusePhoto, titleVisibility: .visible) {
            Button("使用已选照片") { if let pendingSource { Task { await model.acceptSource(pendingSource) } } }
            Button("从相册选择") { picker = true }
            Button("取消", role: .cancel) {}
        }
        .onChange(of: format) { _, _ in savedStamp = nil; updatePreview() }
        .onChange(of: transform) { _, _ in savedStamp = nil; updatePreview() }
        .onChange(of: lettering) { _, _ in savedStamp = nil; updatePreview() }
        .onChange(of: model.source?.image) { _, _ in savedStamp = nil; transform = .init()
            if lettering.date.isEmpty { lettering.date = model.source?.metadata.captureDate.map(PostalDate.short) ?? "" }
            updatePreview() }
        .onChange(of: model.source?.city) { _, _ in savedStamp = nil }
        .alert("邮票", isPresented: Binding(get: { notice != nil || model.error != nil }, set: { if !$0 { notice = nil; model.error = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(notice ?? model.error ?? "") }
        .sheet(isPresented: $library) { PostalStampLibrary(store: store) }
        .fullScreenCover(isPresented: $postcard) { PostcardStudio(source: model.source, stamp: savedStamp, store: store) }

        .fullScreenCover(item: $largePreview) { item in
            PostalArtworkPreview(item: item).ignoresSafeArea()
        }
        .interactiveDismissDisabled(busy || model.isLoading)
    }
    private var adjustmentPage: some View {
        PostalEditingPage(title: "调整邮票", preview: preview, tint: model.tint,
                          tabs: ["构图", "文字", "字体"], selection: $editTab,
                          onPreview: showLargePreview, onDone: { adjustments = false }) {
            VStack(alignment: .leading, spacing: 22) {
                if editTab == 0 {
                    postalSlider("缩放", value: $transform.scale, range: 1...4)
                    postalSlider("水平位置", value: $transform.x, range: -1...1)
                    postalSlider("垂直位置", value: $transform.y, range: -1...1)
                    resetCompositionButton
                } else if editTab == 1 {
                    Toggle("显示标题", isOn: $lettering.showsTitle).accessibilityIdentifier("postal.showTitle")
                    if lettering.showsTitle { letteringField("邮票标题", text: $lettering.title, limit: 20) }
                    Toggle("显示日期", isOn: $lettering.showsDate).accessibilityIdentifier("postal.showDate")
                    if lettering.showsDate { letteringField("邮票日期", text: $lettering.date, limit: 24) }
                    if lettering.isEnabled {
                        postalSlider("文字大小", value: $lettering.size, range: 0.6...1.5)
                        Picker("文字位置", selection: $lettering.atTop) {
                            Text("上方").tag(true); Text("下方").tag(false)
                        }.pickerStyle(.segmented)
                        postalSlider("边缘留白", value: $lettering.inset, range: 0.03...0.35)
                        Picker("文字颜色", selection: $lettering.darkInk) {
                            Text("白色").tag(false); Text("黑色").tag(true)
                        }.pickerStyle(.segmented)
                    }
                    Text("文字默认关闭，开启后只用于作品装饰。修改日期不会改变照片的拍摄信息或城市归属。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    if !lettering.isEnabled { Text("在「文字」中开启标题或日期，即可在邮票上看到字体效果。")
                        .font(.caption).foregroundStyle(.secondary) }
                    PostalFontPicker(selection: $lettering.font)
                }
            }
        }
    }
    private func letteringField(_ title: String, text: Binding<String>, limit: Int) -> some View {
        TextField(title.appLocalized, text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(limit)) }))
            .textFieldStyle(.plain).padding(12)
            .background(.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("postal.field.\(title)")
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
            let image = try StampRenderer.render(photo: source.image, format: format, transform: transform, lettering: lettering)
            largePreview = try PostalArtworkPreviewItem(image: image, title: "邮票")
        } catch { model.error = error.localizedDescription }
    }
    private func requestPhoto() {
        guard templateAvailable, step == .photo, !busy, !model.isLoading else { return }
        if pendingSource != nil && model.source == nil { reusePhoto = true } else { picker = true }
    }
    private func postalSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack { Text(LocalizedStringKey(title)).font(.caption).frame(width: 62, alignment: .leading)
            Slider(value: value, in: range)
                .accessibilityLabel(Text(LocalizedStringKey(title)))
                .accessibilityIdentifier("postal.\(title)")
        }
    }
    @ViewBuilder
    private var resetCompositionButton: some View {
        // 居中放置，避免被误认为属于“垂直位置”滑块
        if #available(iOS 26.0, *) {
            Button("重置构图") { transform = .init() }
                .font(.subheadline)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("postal.resetComposition")
        } else {
            Button {
                transform = .init()
            } label: {
                Text("重置构图")
                    .font(.subheadline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background {
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(.black.opacity(0.06), lineWidth: 0.5))
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("postal.resetComposition")
        }
    }
    private func updatePreview() {
        guard let source = model.source else { preview = nil; return }
        do { preview = try StampRenderer.render(photo: source.image, format: format, transform: transform, lettering: lettering, maxDimension: 1000) }
        catch { model.error = error.localizedDescription }
    }
    private func collect() async -> PostalStamp? {
        guard templateAvailable else { return nil }
        if let savedStamp, store.stamps.contains(where: { $0.id == savedStamp.id }) { return savedStamp }
        guard let source = model.source else { return nil }
        do {
            let image = try StampRenderer.render(photo: source.image, format: format, transform: transform, lettering: lettering)
            let stamp = try store.add(image: image, format: format, metadata: source.metadata,
                                     city: source.city, tint: model.tint, targetCity: targetCity)
            savedStamp = stamp
            return stamp
        } catch { model.error = error.localizedDescription; return nil }
    }
    private func save(toPhotos: Bool) async {
        guard canSave else { return }
        busy = true; defer { busy = false }
        guard let stamp = await collect() else { return }
        do {
            if toPhotos {
                guard let image = store.image(stamp, fullSize: true) else { throw PostalError.image }
                try await PostalPhotoWriter.save(image)
            }
            if let onSaved { onSaved(stamp); dismiss() }
            else if toPhotos {
                notice = "已保存 PNG 到相册，并保留在我的邮票中。".appLocalized
            } else if let city = stamp.city {
                notice = String(format: "已收藏，%@已点亮。".appLocalized, city.name)
            } else {
                notice = "已收藏为普通邮票，可在明信片中使用。".appLocalized
            }
        } catch { model.error = error.localizedDescription }
    }
}

@MainActor
final class PostalCaptureLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorization: CheckedContinuation<Void, Never>?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    var recentLocation: CLLocation? {
        guard let location = manager.location, location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 3000, abs(location.timestamp.timeIntervalSinceNow) < 120 else { return nil }
        return location
    }
    func prepare() async {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { authorization = $0; manager.requestWhenInUseAuthorization() }
        }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    func stop() { manager.stopUpdatingLocation() }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        authorization?.resume(); authorization = nil
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { stop() }
}

struct PostalCamera: UIViewControllerRepresentable {
    let completion: (UIImage?, Date) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?, Date) -> Void
        init(completion: @escaping (UIImage?, Date) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil, .now) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion(info[.originalImage] as? UIImage, .now)
        }
    }
}
