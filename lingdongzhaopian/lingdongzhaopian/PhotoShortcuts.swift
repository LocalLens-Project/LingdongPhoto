// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import AppIntents
import CoreImage
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct ExtractPhotoPaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "提取照片色彩"
    static let description = IntentDescription("在本机提取照片的六种代表色，并返回 HEX 色值。")
    static let openAppWhenRun = false

    @Parameter(title: "照片")
    var photo: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog {
        guard let image = UIImage(data: photo.data) else {
            throw PhotoShortcutError.unreadableImage
        }
        let values = await MainActor.run {
            PaletteExtractor.extract(from: image).colors.map { color in color.hex }
        }
        return .result(
            value: values,
            dialog: IntentDialog("已在本机提取六种代表色。")
        )
    }
}

struct RemovePhotoMetadataIntent: AppIntent {
    static let title: LocalizedStringResource = "净化照片元数据"
    static let description = IntentDescription("移除照片中的 GPS、设备、镜头与原始拍摄时间，返回一张净化后的 JPEG。")
    static let openAppWhenRun = false

    @Parameter(title: "照片")
    var photo: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        guard let image = UIImage(data: photo.data) else {
            throw PhotoShortcutError.unreadableImage
        }
        let data = try await MainActor.run {
            try ArtworkExporter.encodedStillData(
                image,
                metadata: .empty,
                originalImageData: nil,
                format: .jpeg,
                metadataPolicy: .removeAll
            )
        }
        return .result(
            value: IntentFile(
                data: data,
                filename: "\("净化照片".appLocalized).jpg",
                type: .jpeg
            ),
            dialog: IntentDialog("敏感元数据已全部移除。")
        )
    }
}

struct GenerateSpectrumWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "生成色谱壁纸"
    static let description = IntentDescription("根据照片主色在本机生成一张 1290 × 2796 的渐变壁纸。")
    static let openAppWhenRun = false

    @Parameter(title: "照片")
    var photo: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        guard let image = UIImage(data: photo.data) else {
            throw PhotoShortcutError.unreadableImage
        }
        let data = await MainActor.run {
            ShortcutArtworkGenerator.spectrumWallpaper(from: image)?
                .jpegData(compressionQuality: 0.95)
        }
        guard let data else {
            throw PhotoShortcutError.renderFailed
        }
        return .result(
            value: IntentFile(
                data: data,
                filename: "\("色谱壁纸".appLocalized).jpg",
                type: .jpeg
            ),
            dialog: IntentDialog("色谱壁纸已生成，全程未上传照片。")
        )
    }
}

struct LingdongPhotoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ExtractPhotoPaletteIntent(),
            phrases: ["使用 \(.applicationName) 提取照片色彩"],
            shortTitle: "提取照片色彩",
            systemImageName: "paintpalette"
        )
        AppShortcut(
            intent: RemovePhotoMetadataIntent(),
            phrases: ["使用 \(.applicationName) 清除照片元数据"],
            shortTitle: "净化照片元数据",
            systemImageName: "shield.lefthalf.filled"
        )
        AppShortcut(
            intent: GenerateSpectrumWallpaperIntent(),
            phrases: ["使用 \(.applicationName) 生成色谱壁纸"],
            shortTitle: "生成色谱壁纸",
            systemImageName: "rectangle.on.rectangle"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .teal }
}

private enum PhotoShortcutError: LocalizedError {
    case unreadableImage
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "无法读取输入照片。".appLocalized
        case .renderFailed: "作品生成失败，请换一张照片后重试。".appLocalized
        }
    }
}

@MainActor
private enum ShortcutArtworkGenerator {
    static func spectrumWallpaper(from image: UIImage) -> UIImage? {
        let size = CGSize(width: 1290, height: 2796)
        guard let gradient = SpectrumWallpaperRenderer.gradient(from: image) else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let scale = max(size.width / gradient.size.width, size.height / gradient.size.height)
            let drawnSize = CGSize(width: gradient.size.width * scale, height: gradient.size.height * scale)
            gradient.draw(in: CGRect(
                x: (size.width - drawnSize.width) / 2,
                y: (size.height - drawnSize.height) / 2,
                width: drawnSize.width, height: drawnSize.height
            ))
        }
    }
}
