import SwiftUI
import UIKit

private struct PhotoBackDraft: Identifiable {
    let id = UUID()
    let photo: SelectedPhoto
    let ink: RGBColor
}

struct PhotoBackCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var store = PhotoBackStore.shared
    @State private var pickerPresented = false
    @State private var pickerSelections: [PhotoPickerSelection] = []
    @State private var draft: PhotoBackDraft?
    @State private var focusedID: UUID?
    @State private var showsBack = false
    @State private var drawerPresented = false
    @State private var laterComposerID: UUID?
    @State private var message: String?
    @State private var isLoading = false
    @State private var didLoadPrefilledPhoto = false
    private let prefilledPhoto: SelectedPhoto?

    init(prefilledPhoto: SelectedPhoto? = nil) {
        self.prefilledPhoto = prefilledPhoto
    }

    private var ordered: [PhotoBackRecord] { store.orderedRecords }
    private var focused: PhotoBackRecord? {
        if let focusedID, let record = ordered.first(where: { $0.id == focusedID }) { return record }
        return ordered.first
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    background(for: focused)
                    if let record = focused, let image = store.image(for: record) {
                        memoryStage(record: record, image: image, size: proxy.size)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭".appLocalized) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let record = focused {
                        Menu {
                            Button {
                                beginLaterEcho(for: record)
                            } label: {
                                Label("补一句“后来”".appLocalized, systemImage: "text.badge.plus")
                            }
                            Divider()
                            Button(role: .destructive) { delete(record) } label: {
                                Label("移出照片抽屉".appLocalized, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("照片背面操作".appLocalized)
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        drawerPresented = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .disabled(ordered.isEmpty)
                    .accessibilityLabel("打开照片抽屉".appLocalized)
                    Spacer()
                    Button(action: openPicker) {
                        if isLoading {
                            ProgressView().tint(.primary)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .disabled(isLoading)
                    .accessibilityLabel("收进一张照片".appLocalized)
                    .accessibilityIdentifier("photoBack.addPhoto")
                    Spacer()
                    if let record = focused {
                        Button {
                            beginLaterEcho(for: record)
                        } label: {
                            Image(systemName: "text.badge.plus")
                        }
                        .accessibilityLabel("补一句后来".appLocalized)
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
            }
        }
        .environment(\.colorScheme, colorScheme)
        .tint(colorScheme == .dark ? Color.white : Color.black)
        .sheet(isPresented: $pickerPresented, onDismiss: finishPhotoPicker) {
            PrivacyPreservingPhotoPicker(
                isPresented: $pickerPresented,
                selectionLimit: 1,
                colorScheme: colorScheme,
                deliversSelectionBeforeDismissal: true
            ) { pickerSelections = $0 }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $draft) { draft in
            PhotoBackComposerView(draft: draft, store: store) { id in
                focusedID = id
                showsBack = false
                laterComposerID = nil
            }
            .environment(\.colorScheme, colorScheme)
            .tint(colorScheme == .dark ? Color.white : Color.black)
        }
        .sheet(isPresented: $drawerPresented) {
            PhotoBackDrawerView(store: store, selection: focused?.id) { id in
                focusedID = id
                showsBack = false
                laterComposerID = nil
                drawerPresented = false
            }
            .environment(\.colorScheme, colorScheme)
            .tint(colorScheme == .dark ? Color.white : Color.black)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(nil)
        }
        .alert("照片背面".appLocalized, isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("好".appLocalized, role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
        .task {
            guard !didLoadPrefilledPhoto, let prefilledPhoto else { return }
            didLoadPrefilledPhoto = true
            draft = makeDraft(prefilledPhoto)
        }
    }

    private func memoryStage(record: PhotoBackRecord, image: UIImage, size: CGSize) -> some View {
        let cardSize = PhotoBackCardSizing.fitted(
            imageSize: image.size,
            maximumWidth: min(size.width - 38, 410),
            maximumHeight: min(size.height * 0.68, 570)
        )
        return PhotoBackMemoryStage(
            record: record,
            image: image,
            cardSize: cardSize,
            availableHeight: size.height,
            pageText: pageText(record),
            subtitle: stageSubtitle(record),
            canMoveBetweenPhotos: ordered.count > 1,
            showsBack: $showsBack,
            composeLater: Binding(
                get: { laterComposerID == record.id },
                set: { requested in
                    if requested {
                        laterComposerID = record.id
                    } else if laterComposerID == record.id {
                        laterComposerID = nil
                    }
                }
            ),
            store: store,
            onMove: move
        )
        .id(record.id)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 116, height: 146)
                    .rotationEffect(.degrees(-5))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.thinMaterial)
                    .frame(width: 116, height: 146)
                    .overlay {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 30, weight: .light))
                    }
                    .rotationEffect(.degrees(5))
            }
            Text("照片的正面，留住看见的。\n照片的背面，留住没有拍下的。".appLocalized)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            Text("点击底部＋收进第一张照片".appLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(30)
    }

    private func background(for record: PhotoBackRecord?) -> some View {
        let ink = record.map { Color(red: $0.ink.red, green: $0.ink.green, blue: $0.ink.blue) }
            ?? Color(red: 0.42, green: 0.48, blue: 0.45)
        return ZStack {
            Color(uiColor: .systemBackground)
            LinearGradient(
                colors: [ink.opacity(colorScheme == .dark ? 0.28 : 0.17), .clear, ink.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(ink.opacity(colorScheme == .dark ? 0.16 : 0.10))
                .frame(width: 360)
                .blur(radius: 80)
                .offset(x: 150, y: 250)
        }
        .ignoresSafeArea()
    }

    private func openPicker() { pickerPresented = true }

    private func finishPhotoPicker() {
        guard let selection = pickerSelections.first else { return }
        pickerSelections = []
        load(selection)
    }

    private func load(_ selection: PhotoPickerSelection) {
        isLoading = true
        Task {
            do {
                let photo = try await PhotoAssetLoader.load(selection, includeLiveResource: false)
                await MainActor.run {
                    isLoading = false
                    draft = makeDraft(photo)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    message = error.localizedDescription
                }
            }
        }
    }

    private func makeDraft(_ photo: SelectedPhoto) -> PhotoBackDraft {
        PhotoBackDraft(
            photo: photo,
            ink: PaletteExtractor.extract(from: photo.image, colorCount: 3).colors.first
                ?? RGBColor.fallback[0]
        )
    }

    private func move(_ offset: Int) {
        guard let record = focused, let index = ordered.firstIndex(where: { $0.id == record.id }), !ordered.isEmpty else { return }
        let next = (index + offset + ordered.count) % ordered.count
        withAnimation(.snappy) {
            focusedID = ordered[next].id
            showsBack = false
            laterComposerID = nil
        }
    }

    private func beginLaterEcho(for record: PhotoBackRecord) {
        withAnimation(.spring(response: 0.58, dampingFraction: 0.88)) {
            showsBack = true
            laterComposerID = record.id
        }
    }

    private func pageText(_ record: PhotoBackRecord) -> String {
        guard let index = ordered.firstIndex(where: { $0.id == record.id }) else { return "" }
        return "\(index + 1) / \(ordered.count)"
    }

    private func stageSubtitle(_ record: PhotoBackRecord) -> String {
        if record.isDue { return "它曾经请你在今天回来".appLocalized }
        if let revisitAt = record.revisitAt {
            return String(format: "%@ 再见".appLocalized, Self.dayFormatter.string(from: revisitAt))
        }
        return "每一次翻转，都是一次回望".appLocalized
    }

    private func delete(_ record: PhotoBackRecord) {
        do {
            try store.delete(record)
            focusedID = store.orderedRecords.first?.id
            showsBack = false
            laterComposerID = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct PhotoBackComposerView: View {
    private enum ScrollTarget: Hashable {
        case top
        case card
        case writer
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let draft: PhotoBackDraft
    let store: PhotoBackStore
    let onSaved: (UUID) -> Void
    @State private var perspective: PhotoBackPerspective = .inside
    @State private var text = ""
    @State private var font: PostalFont = .wenkai
    @State private var revisit: PhotoBackRevisitOption = .nextSolarTerm
    @State private var showsBack = false
    @State private var isWriting = false
    @State private var message: String?
    @State private var appeared = false
    @State private var isSaving = false
    @State private var revealsEchoEntry = false
    @State private var revealTask: Task<Void, Never>?
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var writerFocused: Bool

    private var previewEcho: PhotoBackEcho {
        PhotoBackEcho(
            id: UUID(), createdAt: .now, perspective: perspective,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            fontRawValue: font.rawValue
        )
    }

    private var isPortraitPhoto: Bool {
        draft.photo.image.size.height > draft.photo.image.size.width
    }

    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let cardSize = PhotoBackCardSizing.fitted(
                    imageSize: draft.photo.image.size,
                    maximumWidth: min(proxy.size.width - 40, 410),
                    maximumHeight: min(proxy.size.height * 0.61, 560)
                )
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(spacing: 5) {
                                Text("显影".appLocalized)
                                    .font(.caption.weight(.semibold))
                                    .tracking(3)
                                    .foregroundStyle(.secondary)
                                Text(showsBack ? "照片背面".appLocalized : "轻扫或点击照片，翻到背面".appLocalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 18)
                            .id(ScrollTarget.top)

                            PhotoBackFlipCard(
                                image: draft.photo.image,
                                record: nil,
                                draftEcho: previewEcho,
                                captureDate: draft.photo.metadata.captureDate,
                                placeName: draft.photo.metadata.placeName,
                                ink: draft.ink,
                                showsBack: $showsBack
                            )
                            .frame(width: cardSize.width, height: cardSize.height)
                            .scaleEffect(appeared ? 1 : 0.88)
                            .opacity(appeared ? 1 : 0)
                            .blur(radius: appeared ? 0 : 12)
                            .id(ScrollTarget.card)

                            if revealsEchoEntry {
                                echoEntry
                                    .frame(maxWidth: 560)
                                    .padding(.top, 20)
                                    .id(ScrollTarget.writer)
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                                        )
                                    )
                            } else {
                                Text("正面只留给照片".appLocalized)
                                    .font(.caption2)
                                    .tracking(1.2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 18)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 34 + keyboardHeight)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: isWriting) { _, writing in
                        guard isPortraitPhoto else { return }
                        Task { @MainActor in
                            if !reduceMotion {
                                try? await Task.sleep(for: .milliseconds(writing ? 140 : 60))
                            }
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: writing ? 0.54 : 0.38)) {
                                reader.scrollTo(writing ? ScrollTarget.card : ScrollTarget.top, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: writerFocused) { _, focused in
                        guard !usesWideLayout else { return }
                        Task { @MainActor in
                            if !reduceMotion {
                                try? await Task.sleep(for: .milliseconds(focused ? 90 : 45))
                            }
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: focused ? 0.48 : 0.40)) {
                                reader.scrollTo(
                                    focused ? ScrollTarget.writer : ScrollTarget.top,
                                    anchor: .top
                                )
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .background(composerBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消".appLocalized) { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if writerFocused {
                HStack {
                    Spacer()
                    Button("收起键盘".appLocalized) {
                        writerFocused = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .alert("照片背面".appLocalized, isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("好".appLocalized, role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
        .task {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.9)) {
                appeared = true
            }
        }
        .onChange(of: showsBack) { _, isBack in
            revealTask?.cancel()
            if isBack {
                revealTask = Task { @MainActor in
                    if !reduceMotion {
                        try? await Task.sleep(for: .milliseconds(280))
                    }
                    guard !Task.isCancelled, showsBack else { return }
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.46)) {
                        revealsEchoEntry = true
                    }
                }
            } else {
                writerFocused = false
                withAnimation(reduceMotion ? .easeOut(duration: 0.10) : .easeInOut(duration: 0.22)) {
                    revealsEchoEntry = false
                    isWriting = false
                }
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
        .onDisappear { revealTask?.cancel() }
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.58, dampingFraction: 0.90),
            value: showsBack
        )
        .tint(colorScheme == .dark ? Color.white : Color.black)
    }

    private var echoEntry: some View {
        ZStack(alignment: .top) {
            if isWriting {
                inlineWriter
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                echoChoice
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .clipped()
    }

    private var echoChoice: some View {
        VStack(spacing: 14) {
            Text("这张照片之外，你想留下什么？".appLocalized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(PhotoBackPerspective.allCases.filter { $0 != .later }) { item in
                    Button {
                        withAnimation(.snappy) {
                            perspective = item
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 15, weight: .medium))
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(perspective == item ? Color.white : Color.primary)
                    .background {
                        Capsule().fill(perspective == item ? inkColor : Color.primary.opacity(0.06))
                    }
                }
            }

            Text(perspective.prompt)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.48, dampingFraction: 0.88)) {
                    showsBack = false
                }
            } label: {
                Text("（你仍可以随时轻点这里，再看一眼照片）".appLocalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新查看照片".appLocalized)
            .accessibilityIdentifier("photoBack.reviewPhotoHint")

            Button {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.90)) {
                    isWriting = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: text.isEmpty ? "square.and.pencil" : "pencil.line")
                    Text(text.isEmpty ? "写下照片背面".appLocalized : "继续书写".appLocalized)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
            .accessibilityIdentifier("photoBack.openWriter")
        }
        .padding(.horizontal, 4)
    }

    private var inlineWriter: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(Font(font.uiFont(size: 22)))
                    .focused($writerFocused)
                    .foregroundStyle(Color.black.opacity(0.82))
                    .tint(inkColor)
                    .frame(minHeight: 154)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.top, 42)
                    .padding(.bottom, 10)

                if text.isEmpty {
                    Text(perspective.prompt)
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.46))
                        .padding(.leading, 19)
                        .padding(.top, 55)
                        .allowsHitTesting(false)
                }

                Button {
                    writerFocused = false
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.90)) {
                        isWriting = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(inkColor)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回选择".appLocalized)
                .padding(.leading, 4)
                .padding(.top, 2)
            }
            .background(
                Color(red: 0.98, green: 0.965, blue: 0.91),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(inkColor.opacity(0.16), lineWidth: 0.8)
            }

            Button {
                withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.48, dampingFraction: 0.88)) {
                    showsBack = false
                }
            } label: {
                Text("（你仍可以随时轻点这里，再看一眼照片）".appLocalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新查看照片".appLocalized)
            .accessibilityIdentifier("photoBack.writerReviewPhotoHint")

            HStack(spacing: 10) {
                Menu {
                    Picker("字体".appLocalized, selection: $font) {
                        ForEach(PostalFont.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                } label: {
                    Label(font.title, systemImage: "textformat")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)

                Menu {
                    Picker("再看一眼".appLocalized, selection: $revisit) {
                        ForEach(PhotoBackRevisitOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label(revisit.title, systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
            }

            Button(action: save) {
                HStack(spacing: 8) {
                    if isSaving { ProgressView().tint(.white) }
                    Text("收进照片抽屉".appLocalized)
                    Image(systemName: "arrow.down.to.line.compact")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(inkColor.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.40 : 1)
            .accessibilityIdentifier("photoBack.save")
        }
        .padding(.horizontal, 4)
    }

    private var inkColor: Color {
        Color(red: draft.ink.red, green: draft.ink.green, blue: draft.ink.blue)
    }

    private var composerBackground: some View {
        LinearGradient(
            colors: [inkColor.opacity(0.20), Color(uiColor: .systemBackground), inkColor.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func save() {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        isSaving = true
        do {
            let record = try store.add(
                photo: draft.photo,
                perspective: perspective,
                text: cleaned,
                font: font,
                revisitAt: revisit.date(),
                ink: draft.ink
            )
            onSaved(record.id)
            dismiss()
        } catch {
            isSaving = false
            message = error.localizedDescription
        }
    }
}

private enum PhotoBackCardSizing {
    static func fitted(imageSize: CGSize, maximumWidth: CGFloat, maximumHeight: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: maximumWidth, height: maximumHeight)
        }
        let scale = min(maximumWidth / imageSize.width, maximumHeight / imageSize.height)
        return CGSize(
            width: max(1, imageSize.width * scale),
            height: max(1, imageSize.height * scale)
        )
    }
}

private struct PhotoBackMemoryStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: PhotoBackRecord
    let image: UIImage
    let cardSize: CGSize
    let availableHeight: CGFloat
    let pageText: String
    let subtitle: String
    let canMoveBetweenPhotos: Bool
    @Binding var showsBack: Bool
    @Binding var composeLater: Bool
    let store: PhotoBackStore
    let onMove: (Int) -> Void

    @State private var historyExpanded = false
    @State private var selectedEchoIndex = 0
    @State private var laterText = ""
    @State private var laterFont: PostalFont = .wenkai
    @State private var laterRevisit: PhotoBackRevisitOption = .none
    @State private var message: String?
    @State private var isSaving = false

    private var echoes: [PhotoBackEcho] {
        record.echoes.sorted { $0.createdAt < $1.createdAt }
    }

    private var safeEchoIndex: Int {
        min(max(selectedEchoIndex, 0), max(0, echoes.count - 1))
    }

    private var echoCount: Int { echoes.count }

    private var displayedEcho: PhotoBackEcho? {
        guard echoes.indices.contains(safeEchoIndex) else { return record.latestEcho }
        return echoes[safeEchoIndex]
    }

    private var historyToggleAction: (() -> Void)? {
        guard echoCount > 1 else { return nil }
        return { toggleHistory() }
    }

    private var verticalSwipeAction: ((CGFloat) -> Void)? {
        guard echoCount > 1 else { return nil }
        return { distance in handleVerticalSwipe(distance) }
    }

    private var inkColor: Color {
        Color(red: record.ink.red, green: record.ink.green, blue: record.ink.blue)
    }

    var body: some View {
        stageScroll
            .onAppear { selectedEchoIndex = max(0, echoCount - 1) }
            .onChange(of: record.id) { _, _ in resetForRecord() }
            .onChange(of: echoCount) { _, count in
                selectedEchoIndex = max(0, count - 1)
            }
            .onChange(of: composeLater) { _, requested in
                guard requested else { return }
                showsBack = true
                historyExpanded = false
                selectedEchoIndex = max(0, echoCount - 1)
                laterFont = record.latestEcho?.font ?? .wenkai
            }
            .onChange(of: showsBack) { _, isBack in
                guard !isBack else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                    historyExpanded = false
                    composeLater = false
                }
            }
            .alert("照片背面".appLocalized, isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("好".appLocalized, role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
    }

    private var stageScroll: some View {
        ScrollViewReader { reader in
            ScrollView {
                stageContent
                    .frame(minHeight: availableHeight)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: composeLater) { _, writing in
                guard writing else { return }
                Task { @MainActor in
                    if !reduceMotion {
                        try? await Task.sleep(for: .milliseconds(120))
                    }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.42)) {
                        reader.scrollTo("photoBack.memory.card", anchor: .top)
                    }
                }
            }
        }
    }

    private var stageContent: some View {
        VStack(spacing: 0) {
            stageHeader

            Spacer(minLength: 14)

            cardArea

            Spacer(minLength: 14)

            stageControls
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 18)
    }

    private var stageHeader: some View {
        VStack(spacing: 5) {
            Text(stageTitle)
                .font(.caption.weight(.semibold))
                .tracking(2.2)
                .foregroundStyle(.secondary)
            Text(historyExpanded ? historySubtitle : subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var stageTitle: String {
        if historyExpanded { return "回声叠页".appLocalized }
        return record.isDue ? "今日浮现".appLocalized : "照片背面".appLocalized
    }

    private var cardArea: some View {
        return ZStack {
            if showsBack, historyExpanded, echoCount > 1, !composeLater {
                echoPaperLayers
            }

            if composeLater {
                PhotoBackLaterWritingCard(
                    text: $laterText,
                    font: $laterFont,
                    revisit: $laterRevisit,
                    inkColor: inkColor,
                    captureDate: record.captureDate,
                    isSaving: isSaving,
                    onCancel: closeWriter,
                    onSave: saveLaterEcho
                )
                .frame(width: cardSize.width, height: max(cardSize.height, 430))
                .accessibilityIdentifier("photoBack.later.writer")
            } else {
                PhotoBackFlipCard(
                    image: image,
                    record: record,
                    draftEcho: nil,
                    displayedEcho: displayedEcho,
                    echoOrdinal: historyExpanded ? safeEchoIndex + 1 : nil,
                    historyExpanded: historyExpanded,
                    onToggleHistory: historyToggleAction,
                    onVerticalSwipe: verticalSwipeAction,
                    showsBack: $showsBack
                )
                .frame(width: cardSize.width, height: cardSize.height)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.56, dampingFraction: 0.88), value: composeLater)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.52, dampingFraction: 0.86), value: historyExpanded)
        .id("photoBack.memory.card")
    }

    private var echoPaperLayers: some View {
        ZStack {
            ForEach((1...min(3, echoes.count - 1)).reversed(), id: \.self) { layer in
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.965, blue: 0.91),
                                inkColor.opacity(0.10 + Double(layer) * 0.018),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(inkColor.opacity(0.12), lineWidth: 0.8)
                    }
                    .frame(width: cardSize.width, height: cardSize.height)
                    .scaleEffect(1 - CGFloat(layer) * (historyExpanded ? 0.018 : 0.010))
                    .rotationEffect(.degrees(historyExpanded ? Double(layer) * (layer.isMultiple(of: 2) ? -0.42 : 0.42) : 0))
                    .offset(y: CGFloat(layer) * (historyExpanded ? 9 : 5))
                    .shadow(color: .black.opacity(0.035), radius: 8, y: 5)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var stageControls: some View {
        if composeLater {
            VStack(spacing: 3) {
                Text("新的一层，正在照片背后显影".appLocalized)
                    .font(.caption)
                Text("收下后，以前的话仍会留在下面".appLocalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else if historyExpanded {
            Button(action: collapseHistory) {
                VStack(spacing: 5) {
                    Text("上下轻扫切换层数".appLocalized)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Label("收拢回声".appLocalized, systemImage: "chevron.down")
                        .font(.caption.weight(.semibold))
                    Text("第 \(safeEchoIndex + 1) 次，共 \(echoes.count) 次".appLocalized)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .frame(minWidth: 160, minHeight: 48)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("photoBack.echoHistory.collapse")
        } else {
            HStack(spacing: 18) {
                Button { onMove(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveBetweenPhotos)
                .liquidGlass(in: Circle(), interactive: true, variant: .clear)

                VStack(spacing: 3) {
                    if showsBack && echoCount > 1 {
                        Text("上下轻扫切换层数".appLocalized)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(showsBack ? "轻扫翻回照片".appLocalized : "点击或轻扫，翻到背面".appLocalized)
                        .font(.caption)
                    Text(pageText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .frame(minWidth: 132)

                Button { onMove(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveBetweenPhotos)
                .liquidGlass(in: Circle(), interactive: true, variant: .clear)
            }
            .foregroundStyle(.primary)
        }
    }

    private var historySubtitle: String {
        guard let echo = displayedEcho else { return "" }
        let term = SolarTermCalendar.occurrence(containing: echo.createdAt)?.term.localizedName
        let date = Self.echoDay.string(from: echo.createdAt)
        return [date, term].compactMap { $0 }.joined(separator: " · ")
    }

    private func toggleHistory() {
        guard echoes.count > 1 else { return }
        if historyExpanded {
            collapseHistory()
        } else {
            selectedEchoIndex = echoes.count - 1
            withAnimation(reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.86)) {
                historyExpanded = true
            }
            softImpact()
        }
    }

    private func collapseHistory() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.50, dampingFraction: 0.90)) {
            selectedEchoIndex = max(0, echoes.count - 1)
            historyExpanded = false
        }
        softImpact()
    }

    private func handleVerticalSwipe(_ distance: CGFloat) {
        guard abs(distance) > 42, echoes.count > 1 else { return }
        if distance < 0 {
            if !historyExpanded {
                historyExpanded = true
                selectedEchoIndex = max(0, echoes.count - 2)
            } else if selectedEchoIndex > 0 {
                selectedEchoIndex -= 1
            }
        } else if historyExpanded {
            if selectedEchoIndex < echoes.count - 1 {
                selectedEchoIndex += 1
            } else {
                collapseHistory()
                return
            }
        }
        softImpact()
    }

    private func closeWriter() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.90)) {
            composeLater = false
            laterText = ""
        }
    }

    private func saveLaterEcho() {
        let cleaned = laterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !isSaving else { return }
        isSaving = true
        do {
            try store.append(text: cleaned, font: laterFont, revisitAt: laterRevisit.date(), to: record)
            let updatedCount = store.records.first(where: { $0.id == record.id })?.echoes.count ?? echoes.count + 1
            selectedEchoIndex = max(0, updatedCount - 1)
            historyExpanded = true
            composeLater = false
            laterText = ""
            isSaving = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            isSaving = false
            message = error.localizedDescription
        }
    }

    private func resetForRecord() {
        historyExpanded = false
        composeLater = false
        selectedEchoIndex = max(0, echoes.count - 1)
        laterText = ""
        isSaving = false
    }

    private func softImpact() {
        guard !reduceMotion else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private static let echoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct PhotoBackLaterWritingCard: View {
    @Binding var text: String
    @Binding var font: PostalFont
    @Binding var revisit: PhotoBackRevisitOption
    let inkColor: Color
    let captureDate: Date?
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    @FocusState private var writerFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 470
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.98, green: 0.965, blue: 0.91), inkColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Canvas { context, size in
                    var y: CGFloat = compact ? 64 : 82
                    while y < size.height - 30 {
                        var path = Path()
                        path.move(to: CGPoint(x: 24, y: y))
                        path.addLine(to: CGPoint(x: size.width - 24, y: y))
                        context.stroke(path, with: .color(inkColor.opacity(0.09)), lineWidth: 0.7)
                        y += compact ? 27 : 32
                    }
                }

                VStack(alignment: .leading, spacing: compact ? 8 : 13) {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("收起空白回声".appLocalized)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("新的一层".appLocalized)
                                .font(.caption.weight(.bold))
                                .tracking(2)
                            if !compact {
                        Text(captureDate.map { Self.captureDay.string(from: $0) } ?? "照片背后".appLocalized)
                                    .font(.caption2)
                                    .foregroundStyle(Color.black.opacity(0.52))
                            }
                        }
                        Spacer()
                        ZStack {
                            Circle().stroke(inkColor.opacity(0.55), lineWidth: 1)
                            Text("待\n印")
                                .font(.system(size: 10, weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(inkColor)
                        }
                        .frame(width: compact ? 36 : 42, height: compact ? 36 : 42)
                        .rotationEffect(.degrees(-6))
                    }

                    if !compact {
                        Text(PhotoBackPerspective.later.prompt)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.black.opacity(0.62))
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .font(Font(font.uiFont(size: compact ? 18 : 22)))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(Color.black.opacity(0.82))
                            .tint(inkColor)
                            .focused($writerFocused)
                            .padding(.horizontal, 4)

                        if text.isEmpty {
                            Text("过了一段时间，你又想起了什么？".appLocalized)
                                .font(.subheadline)
                                .foregroundStyle(Color.black.opacity(0.38))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 9)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    HStack(spacing: 8) {
                        Menu {
                            Picker("字体".appLocalized, selection: $font) {
                                ForEach(PostalFont.allCases) { item in
                                    Text(item.title).tag(item)
                                }
                            }
                        } label: {
                            Label(font.title, systemImage: "textformat")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                        .background(.white.opacity(0.30), in: Capsule())

                        Menu {
                            Picker("下次再看".appLocalized, selection: $revisit) {
                                ForEach(PhotoBackRevisitOption.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                        } label: {
                            Label(revisit.title, systemImage: "clock")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                        .background(.white.opacity(0.30), in: Capsule())
                    }
                    .font(.caption.weight(.medium))

                    Button(action: onSave) {
                        HStack(spacing: 7) {
                            if isSaving { ProgressView().tint(.white) }
                            Text("收下这次回声".appLocalized)
                            Image(systemName: "seal")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: compact ? 40 : 46)
                        .background(inkColor.gradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.38 : 1)
                    .accessibilityIdentifier("photoBack.later.save")
                }
                .padding(compact ? 16 : 22)
                .foregroundStyle(Color.black.opacity(0.80))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(inkColor.opacity(0.18), lineWidth: 0.9)
            }
            .shadow(color: .black.opacity(0.14), radius: 26, y: 16)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘".appLocalized) {
                    writerFocused = false
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private static let captureDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct PhotoBackFlipCard: View {
    private enum DragAxis {
        case horizontal
        case vertical
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let image: UIImage
    let record: PhotoBackRecord?
    let draftEcho: PhotoBackEcho?
    var captureDate: Date? = nil
    var placeName: String? = nil
    var ink: RGBColor? = nil
    var displayedEcho: PhotoBackEcho? = nil
    var echoOrdinal: Int? = nil
    var historyExpanded = false
    var onToggleHistory: (() -> Void)? = nil
    var onVerticalSwipe: ((CGFloat) -> Void)? = nil
    @Binding var showsBack: Bool
    @State private var dragStart: Double?
    @State private var dragAxis: DragAxis?
    @State private var verticalDrag: CGFloat = 0

    private var rotation: Double { showsBack ? 180 : 0 }
    private var echo: PhotoBackEcho? { displayedEcho ?? draftEcho ?? record?.latestEcho }
    private var resolvedCaptureDate: Date? { record?.captureDate ?? captureDate }
    private var resolvedPlaceName: String? { record?.placeName ?? placeName }
    private var inkColor: Color {
        if let record { return Color(red: record.ink.red, green: record.ink.green, blue: record.ink.blue) }
        if let ink { return ink.color }
        return Color(red: 0.38, green: 0.43, blue: 0.41)
    }

    var body: some View {
        GeometryReader { proxy in
            let current = dragStart ?? rotation
            ZStack {
                front
                    .opacity(normalized(current) < 90 ? 1 : 0)
                back(size: proxy.size)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(normalized(current) >= 90 ? 1 : 0)
            }
            .rotation3DEffect(
                .degrees(current),
                axis: (x: 0, y: 1, z: 0),
                perspective: reduceMotion ? 0 : 0.72
            )
            .rotationEffect(.degrees(Double(verticalDrag / 70)))
            .offset(y: verticalDrag * 0.14)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if dragAxis == nil {
                            let vertical = abs(value.translation.height) > abs(value.translation.width)
                            dragAxis = vertical && showsBack && onVerticalSwipe != nil ? .vertical : .horizontal
                        }
                        if dragAxis == .vertical {
                            verticalDrag = min(72, max(-72, value.translation.height))
                        } else {
                            let base = showsBack ? 180.0 : 0.0
                            dragStart = min(180, max(0, base + Double(value.translation.width) * 0.58))
                        }
                    }
                    .onEnded { value in
                        if dragAxis == .vertical {
                            let projected = abs(value.predictedEndTranslation.height) > abs(value.translation.height)
                                ? value.predictedEndTranslation.height
                                : value.translation.height
                            withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
                                verticalDrag = 0
                            }
                            onVerticalSwipe?(projected)
                        } else {
                            let projected = (dragStart ?? rotation) + Double(value.predictedEndTranslation.width - value.translation.width) * 0.18
                            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.48, dampingFraction: 0.84)) {
                                showsBack = projected >= 90
                                dragStart = nil
                            }
                        }
                        dragAxis = nil
                    }
            )
            .onTapGesture {
                withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.52, dampingFraction: 0.86)) {
                    showsBack.toggle()
                    dragStart = nil
                    verticalDrag = 0
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(showsBack ? "照片背面".appLocalized : "照片正面".appLocalized)
            .accessibilityHint("轻点翻转".appLocalized)
            .accessibilityAddTraits(.isButton)
            .accessibilityActions {
                if let onVerticalSwipe, showsBack {
                    Button("更早一层".appLocalized) { onVerticalSwipe(-100) }
                    Button("更新一层".appLocalized) { onVerticalSwipe(100) }
                }
            }
        }
    }

    private var front: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.34), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.17), radius: 26, y: 16)
    }

    private func back(size: CGSize) -> some View {
        let ruleSpacing: CGFloat = 32
        let firstRuleY: CGFloat = 82
        let writingFont = (echo?.font ?? .wenkai).uiFont(size: min(max(size.width * 0.062, 19), 27))
        let writingTop = firstRuleY + max(0, ruleSpacing - writingFont.lineHeight)
        let writingBottom = max(writingTop, size.height - 62)
        let writingHeight = writingBottom - writingTop
        let fittedLines = 1 + Int(max(0, writingHeight - writingFont.lineHeight) / ruleSpacing)
        let maximumLines = max(1, min(8, fittedLines))

        return ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.965, blue: 0.91), inkColor.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Canvas { context, canvasSize in
                var y = firstRuleY
                while y < canvasSize.height - 46 {
                    var path = Path()
                    path.move(to: CGPoint(x: 28, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - 28, y: y))
                    context.stroke(path, with: .color(inkColor.opacity(0.10)), lineWidth: 0.7)
                    y += ruleSpacing
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(backTitle)
                            .font(.caption.weight(.bold))
                            .tracking(2)
                        Text(metadataLine)
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.52))
                            .lineLimit(1)
                    }
                    Spacer()
                    seal
                }

                Spacer(minLength: 0)

                HStack {
                    if let count = record?.echoes.count, count > 1, let onToggleHistory {
                        Button(action: onToggleHistory) {
                            Label(historyExpanded ? "第 \(echoOrdinal ?? count) 次，共 \(count) 次" : "\(count) 次回声", systemImage: "quote.bubble")
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(historyExpanded ? "收拢回声".appLocalized : "共 \(count) 次回声，轻点查看历史".appLocalized)
                        .accessibilityIdentifier("photoBack.echoHistory")
                    } else {
                        Text("此刻写于照片之后".appLocalized)
                    }
                    Spacer()
                    Text(echoDateLine)
                }
                .font(.caption2)
                .foregroundStyle(Color.black.opacity(0.54))
            }
            .padding(26)
            .foregroundStyle(Color.black.opacity(0.80))

            Text(displayText)
                .font(Font(writingFont))
                .lineSpacing(max(0, ruleSpacing - writingFont.lineHeight))
                .foregroundStyle(Color.black.opacity(0.79))
                .multilineTextAlignment(.leading)
                .lineLimit(maximumLines)
                .truncationMode(.tail)
                .frame(
                    width: max(0, size.width - 56),
                    height: writingHeight,
                    alignment: .topLeading
                )
                .position(
                    x: size.width / 2,
                    y: writingTop + writingHeight / 2
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(inkColor.opacity(0.18), lineWidth: 0.9)
        }
        .shadow(color: .black.opacity(0.14), radius: 26, y: 16)
    }

    private var seal: some View {
        ZStack {
            Circle().stroke(inkColor.opacity(0.72), lineWidth: 1.2)
            Circle().stroke(inkColor.opacity(0.40), lineWidth: 0.8).padding(4)
            Text("影\n后")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(inkColor)
        }
        .frame(width: 46, height: 46)
        .rotationEffect(.degrees(-7))
    }

    private var displayText: String {
        let value = echo?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? (echo?.perspective.prompt ?? "这张照片，还有什么没有说完？".appLocalized) : value
    }

    private var backTitle: String {
        let title = echo?.perspective.title ?? "照片背面".appLocalized
        guard historyExpanded, let echoOrdinal else { return title }
        return "第 \(echoOrdinal) 次回声 · \(title)".appLocalized
    }

    private var echoDateLine: String {
        let date = echo?.createdAt ?? .now
        let term = SolarTermCalendar.occurrence(containing: date)?.term.localizedName
        return [Self.shortDate.string(from: date), term].compactMap { $0 }.joined(separator: " · ")
    }

    private var metadataLine: String {
        let date = resolvedCaptureDate.map { Self.longDate.string(from: $0) }
        let term = resolvedCaptureDate.flatMap { SolarTermCalendar.occurrence(containing: $0)?.term.localizedName }
        return [date, term, resolvedPlaceName].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
    }

    private func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    private static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

private struct PhotoBackDrawerView: View {
    @Environment(\.dismiss) private var dismiss
    let store: PhotoBackStore
    let selection: UUID?
    let onSelect: (UUID) -> Void
    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.orderedRecords.isEmpty {
                    ContentUnavailableView("照片抽屉还是空的".appLocalized, systemImage: "photo.stack")
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.orderedRecords) { record in
                            Button { onSelect(record.id) } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    if let image = store.image(for: record, thumbnail: true) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 146)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    Text(record.latestEcho?.text ?? "")
                                        .font(Font((record.latestEcho?.font ?? .wenkai).uiFont(size: 16)))
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)
                                    HStack {
                                        Text(record.captureDate.map { Self.day.string(from: $0) } ?? "无日期".appLocalized)
                                        Spacer()
                                        if record.isDue {
                                            Image(systemName: "sparkles")
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(9)
                                .background(
                                    Color.primary.opacity(record.id == selection ? 0.10 : 0.045),
                                    in: RoundedRectangle(cornerRadius: 21, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(store.dueCount > 0 ? "照片抽屉 · \(store.dueCount) 张待回看" : "照片抽屉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成".appLocalized) { dismiss() }
                }
            }
        }
    }

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
