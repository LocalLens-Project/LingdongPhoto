import ImageIO
import Combine
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum SignatureStampPage: String, CaseIterable, Identifiable {
    case bubble
    case signature

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bubble: "气泡印章".appLocalized
        case .signature: "自定义签章".appLocalized
        }
    }
}

enum SignatureStampSource: String, CaseIterable, Identifiable {
    case text
    case image

    var id: String { rawValue }
}

@MainActor
final class SignatureStampLibrary: ObservableObject {
    @Published private(set) var image: UIImage?

    init() {
        reload()
    }

    func importPNG(from sourceURL: URL) throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        guard sourceURL.pathExtension.lowercased() == "png",
              let data = try? Data(contentsOf: sourceURL),
              Self.isPNG(data) else {
            throw CameraWatermarkImportError.notPNG
        }
        guard let source = UIImage(data: data) else {
            throw CameraWatermarkImportError.unreadable
        }
        guard let normalized = Self.normalized(source),
              let output = normalized.pngData() else {
            throw CameraWatermarkImportError.emptyImage
        }
        do {
            try FileManager.default.createDirectory(at: Self.directoryURL, withIntermediateDirectories: true)
            try output.write(to: Self.fileURL, options: .atomic)
            image = normalized
        } catch {
            throw CameraWatermarkImportError.unableToSave
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        image = nil
    }

    private func reload() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              Self.isPNG(data),
              let loaded = UIImage(data: data) else { return }
        image = loaded
    }

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("LingdongPhoto/SignatureStamp", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("signature.png")
    }

    private static func isPNG(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count >= signature.count,
              Array(data.prefix(signature.count)) == signature,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return false }
        return UTType(type as String)?.conforms(to: .png) == true
    }

    private static func normalized(_ source: UIImage) -> UIImage? {
        guard source.size.width > 0, source.size.height > 0 else { return nil }
        let scale = min(1, 2048 / max(source.size.width, source.size.height))
        let target = CGSize(
            width: max(1, (source.size.width * scale).rounded()),
            height: max(1, (source.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

struct SignatureStampSwitcher: View {
    @Binding var selection: SignatureStampPage
    let reduceMotion: Bool

    var body: some View {
        Picker("光影签章视图", selection: Binding(
            get: { selection },
            set: { page in
                guard page != selection else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.38)) {
                    selection = page
                }
            }
        )) {
            ForEach(SignatureStampPage.allCases) { page in
                Text(LocalizedStringKey(page.title)).tag(page)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .labelsHidden()
        .frame(width: 244)
        .accessibilityLabel("光影签章视图")
    }
}

struct CustomSignatureSettingsSheet: View {
    @Binding var signatureText: String
    @Binding var source: SignatureStampSource
    @Binding var font: PostalFont
    @Binding var textScale: Double
    @Binding var imageScale: Double
    @Binding var showsDate: Bool
    @Binding var showsTime: Bool
    @Binding var dateTimeScale: Double
    @Binding var usesEnglishDateTime: Bool
    let isSupporter: Bool
    @ObservedObject var library: SignatureStampLibrary
    let onOpenSupport: () -> Void

    @State private var importerPresented = false
    @State private var errorMessage = ""
    @State private var errorPresented = false
    @State private var proPromptMessage: String?
    @State private var promptTask: Task<Void, Never>?

    var body: some View {
        Form {
            signatureSections
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $importerPresented, allowedContentTypes: [.png]) { result in
            guard case let .success(url) = result else { return }
            do {
                try library.importPNG(from: url)
                source = .image
            } catch {
                errorMessage = error.localizedDescription
                errorPresented = true
            }
        }
        .alert("无法导入签章", isPresented: $errorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .overlay(alignment: .bottom) {
            if let proPromptMessage {
                SupporterProUnlockPrompt(message: proPromptMessage) {
                    promptTask?.cancel()
                    self.proPromptMessage = nil
                    onOpenSupport()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .onDisappear { promptTask?.cancel() }
    }

    @ViewBuilder
    private var signatureSections: some View {
        Section("签章文字") {
            Button {
                source = .text
            } label: {
                HStack {
                    Label("文字签名", systemImage: "signature")
                    Spacer()
                    Image(systemName: source == .text ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(source == .text ? Color.accentColor : Color.secondary.opacity(0.45))
                }
            }
            TextField("输入签名", text: $signatureText)
                .textInputAutocapitalization(.never)
                .onChange(of: signatureText) { _, _ in source = .text }
            Slider(value: $textScale, in: 0.5...2.5, step: 0.05) {
                Text("文字大小")
            } minimumValueLabel: {
                Image(systemName: "textformat.size.smaller")
            } maximumValueLabel: {
                Image(systemName: "textformat.size.larger")
            }
        }

        Section("签章字体") {
            PostalFontSelectionGrid(
                selection: $font,
                locksPremiumFonts: !isSupporter,
                onLockedTap: { showProPrompt("支持我们 PRO，即可使用全部签章字体。") }
            )
        }

        Section {
            Toggle("显示日期", isOn: $showsDate)
            Toggle("显示时间", isOn: $showsTime)

            if showsDate || showsTime {
                if LexiconLanguage.current != .english {
                    Picker("日期时间语言", selection: $usesEnglishDateTime) {
                        Text("中文").tag(false)
                        Text(verbatim: "English").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Slider(value: $dateTimeScale, in: 0.5...2.5, step: 0.05) {
                    Text("日期时间大小")
                } minimumValueLabel: {
                    Image(systemName: "textformat.size.smaller")
                } maximumValueLabel: {
                    Image(systemName: "textformat.size.larger")
                }
            }
        } header: {
            Text("日期与时间")
        } footer: {
            Text("日期与时间使用所选签章字体，可在画面中单独拖动，并用滑块调整大小。")
        }

        Section {
            Button {
                guard isSupporter else {
                    showProPrompt("支持我们 PRO，即可导入自己的 PNG 签章。")
                    return
                }
                source = .image
            } label: {
                HStack {
                    Label("自定义 PNG", systemImage: "photo.badge.plus")
                    Spacer()
                    if !isSupporter {
                        Image(systemName: "lock.fill").foregroundStyle(.secondary)
                    } else if source == .image {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                    }
                }
            }

            if isSupporter && source == .image {
                if let image = library.image {
                    HStack(spacing: 14) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 54)
                        Button("替换") { importerPresented = true }
                        Spacer()
                        Button("删除", role: .destructive) {
                            library.remove()
                            source = .text
                        }
                    }
                } else {
                    Button {
                        importerPresented = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .light))
                            Text("导入 PNG")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 92)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                Slider(value: $imageScale, in: 0.35...3, step: 0.05) {
                    Text("PNG 大小")
                } minimumValueLabel: {
                    Image(systemName: "photo.fill")
                        .font(.caption2)
                } maximumValueLabel: {
                    Image(systemName: "photo.fill")
                        .font(.body)
                }
            }
        } header: {
            Text("图片签章")
        } footer: {
            Text("仅接受 PNG 文件。导入后可在画面中拖动签章，并用滑块调整大小。")
        }
    }

    private func showProPrompt(_ message: String) {
        promptTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) { proPromptMessage = message }
        promptTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) { proPromptMessage = nil }
        }
    }
}

struct PostalFontSelectionGrid: View {
    @Binding var selection: PostalFont
    var locksPremiumFonts = false
    var onLockedTap: () -> Void = {}

    private let columnCount = 4
    private let spacing: CGFloat = 8
    private let rowHeight: CGFloat = 60

    private var rows: [[PostalFont]] {
        stride(from: 0, to: PostalFont.allCases.count, by: columnCount).map { start in
            Array(PostalFont.allCases[start..<min(start + columnCount, PostalFont.allCases.count)])
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = max(48, (proxy.size.width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount))
            VStack(spacing: 12) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(rows[rowIndex]) { item in
                            fontButton(item)
                                .frame(width: itemWidth)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(height: CGFloat(rows.count) * rowHeight + CGFloat(max(rows.count - 1, 0)) * 12)
        .padding(.vertical, 4)
    }

    private func fontButton(_ item: PostalFont) -> some View {
        let locked = locksPremiumFonts && item != .original
        return Button {
            if locked {
                onLockedTap()
            } else {
                selection = item
            }
        } label: {
            VStack(spacing: 8) {
                Text(verbatim: item.compactPickerTitle)
                    .font(Font(item.uiFont(size: 13)))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 34)
                Image(systemName: locked ? "lock.fill" : (selection == item ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 14))
                    .foregroundStyle(locked ? Color.secondary : (selection == item ? Color.accentColor : Color.secondary.opacity(0.45)))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: item.title))
        .accessibilityValue(locked ? "需支持我们后开启".appLocalized : (selection == item ? "已选择".appLocalized : "未选择".appLocalized))
    }
}
