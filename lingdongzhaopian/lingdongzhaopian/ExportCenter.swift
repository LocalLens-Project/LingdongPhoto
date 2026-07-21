// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum ArtworkExportFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"

    var id: String { rawValue }

    var type: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: .heic
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        }
    }

    var detail: String {
        switch self {
        case .jpeg: "兼容性最佳，适合社交平台"
        case .png: "无损画质，文件较大"
        case .heic: "高画质且更节省空间"
        }
    }
}

enum ArtworkExportResolution: String, CaseIterable, Identifiable {
    case standard = "1080P"
    case high = "2K"
    case original = "原图级"

    var id: String { rawValue }

    func pixelWidth(sourceWidth: CGFloat) -> CGFloat {
        switch self {
        case .standard: 1080
        case .high: 2160
        case .original: min(max(sourceWidth, 1080), 6000)
        }
    }

    var detail: String {
        switch self {
        case .standard: "快速导出，适合日常分享"
        case .high: "细节更清晰，适合收藏"
        case .original: "跟随原片宽度，最高 6000 像素"
        }
    }
}

enum ArtworkMetadataPolicy: String, CaseIterable, Identifiable {
    case preserve = "完整保留"
    case removeLocation = "移除位置"
    case removeAll = "隐私净化"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .preserve: "info.circle"
        case .removeLocation: "location.slash"
        case .removeAll: "shield.lefthalf.filled"
        }
    }

    var detail: String {
        switch self {
        case .preserve: "保留拍摄时间、设备、镜头和 GPS"
        case .removeLocation: "保留拍摄信息，但删除 GPS 坐标"
        case .removeAll: "删除 GPS、设备、镜头和原始拍摄时间"
        }
    }

    var preservesLocation: Bool { self == .preserve }
    var preservesMetadata: Bool { self != .removeAll }
}

enum ArtworkExportDestination: String, CaseIterable, Identifiable {
    case photoLibrary = "相册"
    case files = "文件"
    case share = "分享"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .photoLibrary: "photo.on.rectangle"
        case .files: "folder"
        case .share: "square.and.arrow.up"
        }
    }
}

struct ExportedArtworkFile: Identifiable {
    let id = UUID()
    let url: URL
}

enum ExportTemporaryFile {
    static func make(data: Data, format: ArtworkExportFormat) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-share", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory
            .appendingPathComponent("灵动照片-\(Int(Date.now.timeIntervalSince1970))")
            .appendingPathExtension(format.fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }
}

struct ExportCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var format: ArtworkExportFormat
    @Binding var resolution: ArtworkExportResolution
    @Binding var metadataPolicy: ArtworkMetadataPolicy
    @Binding var destination: ArtworkExportDestination
    let sourcePixelWidth: CGFloat
    let supportsLiveExport: Bool
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    exportSection("保存位置") {
                        HStack(spacing: 9) {
                            ForEach(ArtworkExportDestination.allCases) { item in
                                selectionButton(
                                    title: item.rawValue,
                                    symbol: item.symbol,
                                    isSelected: destination == item
                                ) {
                                    destination = item
                                }
                            }
                        }
                    }

                    exportSection("画质与格式") {
                        VStack(spacing: 12) {
                            optionPicker(
                                title: "输出尺寸",
                                symbol: "arrow.up.left.and.arrow.down.right",
                                selection: $resolution,
                                values: ArtworkExportResolution.allCases
                            )
                            Divider().opacity(0.42)
                            optionPicker(
                                title: "图片格式",
                                symbol: "doc.richtext",
                                selection: $format,
                                values: ArtworkExportFormat.allCases
                            )
                            Text("\(resolution.detail) · \(format.detail)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    exportSection("元数据隐私") {
                        VStack(spacing: 9) {
                            ForEach(ArtworkMetadataPolicy.allCases) { policy in
                                Button {
                                    metadataPolicy = policy
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: policy.symbol)
                                            .font(.system(size: 17, weight: .semibold))
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(policy.rawValue).font(.subheadline.weight(.semibold))
                                            Text(policy.detail)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: metadataPolicy == policy ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(metadataPolicy == policy ? .blue : .secondary)
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 58)
                                    .background(
                                        metadataPolicy == policy
                                            ? Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.08)
                                            : .clear,
                                        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if supportsLiveExport {
                        Label(
                            destination == .photoLibrary
                                ? "保存到相册时将保留 Live Photo；动态作品使用 JPEG 封面。"
                                : "文件与系统分享导出静态成品；保存到相册可保留 Live Photo。",
                            systemImage: "livephoto"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                    }

                    Button {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(180))
                            onExport()
                        }
                    } label: {
                        Label(exportTitle, systemImage: destination.symbol)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .background(Color.clear)
            .navigationTitle("导出作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var exportTitle: String {
        switch destination {
        case .photoLibrary: "保存到系统相册"
        case .files: "导出到文件"
        case .share: "打开系统分享"
        }
    }

    private func exportSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
            content()
                .padding(14)
                .frame(maxWidth: .infinity)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 25, style: .continuous),
                    variant: .clear
                )
        }
    }

    private func selectionButton(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(
                isSelected
                    ? colorScheme == .dark ? Color.black : Color.white
                    : Color.primary.opacity(0.72)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                isSelected
                    ? colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.78)
                    : .clear,
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
    }

    private func optionPicker<Value: Hashable & Identifiable & RawRepresentable>(
        title: String,
        symbol: String,
        selection: Binding<Value>,
        values: [Value]
    ) -> some View where Value.RawValue == String {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 28)
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            Picker(title, selection: selection) {
                ForEach(values) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.blue)
        }
        .frame(minHeight: 40)
    }
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FileExportPicker: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
