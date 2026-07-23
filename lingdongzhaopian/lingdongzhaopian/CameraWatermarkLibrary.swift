// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Combine
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum CameraWatermarkBrand: String, CaseIterable, Identifiable {
    case canon
    case nikon
    case sony
    case fujifilm
    case panasonic
    case leica
    case hasselblad
    case omSystem
    case ricoh
    case pentax
    case phaseOne
    case sigma
    case gopro
    case dji
    case insta360
    case kodak
    case samsung
    case casio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .canon: "Canon"
        case .nikon: "Nikon"
        case .sony: "Sony"
        case .fujifilm: "FUJIFILM"
        case .panasonic: "Panasonic"
        case .leica: "Leica"
        case .hasselblad: "Hasselblad"
        case .omSystem: "OM SYSTEM / Olympus"
        case .ricoh: "RICOH"
        case .pentax: "PENTAX"
        case .phaseOne: "Phase One"
        case .sigma: "SIGMA"
        case .gopro: "GoPro"
        case .dji: "DJI"
        case .insta360: "Insta360"
        case .kodak: "Kodak"
        case .samsung: "Samsung"
        case .casio: "CASIO"
        }
    }

    static func resolve(from descriptor: CaptureDeviceDescriptor) -> CameraWatermarkBrand? {
        guard descriptor.category == .camera else { return nil }
        let manufacturer = searchable(descriptor.manufacturer)
        let model = searchable(descriptor.model)

        let candidates: [(CameraWatermarkBrand, [String])] = [
            (.canon, ["canon"]),
            (.nikon, ["nikon"]),
            (.sony, ["sony"]),
            (.fujifilm, ["fujifilm", "fuji photo film"]),
            (.panasonic, ["panasonic", "lumix"]),
            (.leica, ["leica", "leitz"]),
            (.hasselblad, ["hasselblad"]),
            (.omSystem, ["om system", "olympus", "om digital"]),
            (.ricoh, ["ricoh"]),
            (.pentax, ["pentax"]),
            (.phaseOne, ["phase one"]),
            (.sigma, ["sigma"]),
            (.gopro, ["gopro"]),
            (.dji, ["dji"]),
            (.insta360, ["insta360", "arashi vision"]),
            (.kodak, ["kodak"]),
            (.samsung, ["samsung"]),
            (.casio, ["casio"])
        ]

        if let manufacturerMatch = candidates.first(where: { _, aliases in
            aliases.contains(where: manufacturer.contains)
        }) {
            return manufacturerMatch.0
        }

        // Some Photos/RAW conversion paths keep the camera model but replace or
        // remove TIFF Make. Falling back to an explicit brand in the model keeps
        // those files connected to the user's locally imported watermark.
        return candidates.first(where: { _, aliases in
            aliases.contains(where: model.contains)
        })?.0
    }

    private static func searchable(_ value: String?) -> String {
        value?
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased() ?? ""
    }
}

enum CameraWatermarkImportError: LocalizedError {
    case notPNG
    case unreadable
    case emptyImage
    case unableToSave

    var errorDescription: String? {
        switch self {
        case .notPNG:
            "为了让图标水印保持清晰美观，请从“文件”App 选择 PNG 格式图片。"
        case .unreadable:
            "无法读取所选图片，请确认文件没有损坏后重试。"
        case .emptyImage:
            "所选 PNG 没有可见内容，请换一张带有可见图案的图片。"
        case .unableToSave:
            "无法将图标水印保存到本机，请稍后重试。"
        }
    }
}

@MainActor
final class CameraWatermarkLibrary: ObservableObject {
    @Published private(set) var images: [CameraWatermarkBrand: UIImage] = [:]

    init() {
        reload()
    }

    func image(for descriptor: CaptureDeviceDescriptor) -> UIImage? {
        guard let brand = CameraWatermarkBrand.resolve(from: descriptor) else { return nil }
        return images[brand]
    }

    func image(for brand: CameraWatermarkBrand) -> UIImage? {
        images[brand]
    }

    var importedBrandCount: Int {
        images.count
    }

    func importPNG(from sourceURL: URL, for brand: CameraWatermarkBrand) throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: sourceURL),
              Self.isPNG(data) else {
            throw CameraWatermarkImportError.notPNG
        }
        guard let image = UIImage(data: data) else {
            throw CameraWatermarkImportError.unreadable
        }
        guard let normalized = Self.normalizedWatermark(from: image),
              let normalizedData = normalized.pngData() else {
            throw CameraWatermarkImportError.emptyImage
        }

        do {
            try Self.ensureDirectoryExists()
            try normalizedData.write(to: Self.fileURL(for: brand), options: .atomic)
            images[brand] = Self.preparedForArtwork(normalized)
        } catch {
            throw CameraWatermarkImportError.unableToSave
        }
    }

    func remove(_ brand: CameraWatermarkBrand) {
        let url = Self.fileURL(for: brand)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        images.removeValue(forKey: brand)
    }

    func reload() {
        try? Self.ensureDirectoryExists()
        var loaded: [CameraWatermarkBrand: UIImage] = [:]
        for brand in CameraWatermarkBrand.allCases {
            let url = Self.fileURL(for: brand)
            guard let data = try? Data(contentsOf: url),
                  Self.isPNG(data),
                  let image = UIImage(data: data) else { continue }
            loaded[brand] = Self.preparedForArtwork(image)
        }
        images = loaded
    }

    private static var directoryURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("LingdongPhoto", isDirectory: true)
            .appendingPathComponent("CameraWatermarks", isDirectory: true)
    }

    private static func fileURL(for brand: CameraWatermarkBrand) -> URL {
        directoryURL.appendingPathComponent("\(brand.rawValue).png")
    }

    private static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private static func isPNG(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count >= signature.count,
              Array(data.prefix(signature.count)) == signature,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return false }
        return UTType(type as String)?.conforms(to: .png) == true
    }

    /// Single-color transparent marks can adapt to light/dark photos as a
    /// template. Multi-color marks (for example Leica's red disc and white
    /// lettering) must retain their original pixels or their internal artwork
    /// collapses into one solid silhouette.
    private static func preparedForArtwork(_ image: UIImage) -> UIImage {
        image.withRenderingMode(
            containsMultipleOpaqueColors(image) ? .alwaysOriginal : .alwaysTemplate
        )
    }

    private static func containsMultipleOpaqueColors(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let sampleWidth = 32
        let sampleHeight = 32
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](
            repeating: 0,
            count: sampleHeight * bytesPerRow
        )
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.interpolationQuality = .medium
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        )

        var buckets: [Int: Int] = [:]
        var visiblePixelCount = 0
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let alpha = Int(pixels[index + 3])
            guard alpha >= 160 else { continue }
            visiblePixelCount += 1

            // Undo premultiplication before quantizing so translucent edges do
            // not make a one-color transparent logo appear multi-color.
            let red = min(255, Int(pixels[index]) * 255 / alpha)
            let green = min(255, Int(pixels[index + 1]) * 255 / alpha)
            let blue = min(255, Int(pixels[index + 2]) * 255 / alpha)
            let key = (red / 32) << 6 | (green / 32) << 3 | (blue / 32)
            buckets[key, default: 0] += 1
        }
        guard visiblePixelCount > 0 else { return false }

        // Preserve color only for badge-like artwork whose opaque pixels fill
        // most of its normalized bounds. Transparent wordmarks such as
        // FUJIFILM may contain a small accent color, but still need adaptive
        // monochrome rendering to stay legible on dark photographs.
        let opaqueCoverage = Double(visiblePixelCount)
            / Double(sampleWidth * sampleHeight)
        guard opaqueCoverage >= 0.64 else { return false }

        let minimumBucketCount = max(2, visiblePixelCount / 50)
        let significantColors = buckets.compactMap { key, count -> SIMD3<Int>? in
            guard count >= minimumBucketCount else { return nil }
            return SIMD3(
                ((key >> 6) & 0x7) * 32 + 16,
                ((key >> 3) & 0x7) * 32 + 16,
                (key & 0x7) * 32 + 16
            )
        }
        guard significantColors.count >= 2 else { return false }

        for firstIndex in significantColors.indices {
            for secondIndex in significantColors.indices where secondIndex > firstIndex {
                let first = significantColors[firstIndex]
                let second = significantColors[secondIndex]
                let redDelta = first.x - second.x
                let greenDelta = first.y - second.y
                let blueDelta = first.z - second.z
                let distanceSquared = redDelta * redDelta
                    + greenDelta * greenDelta
                    + blueDelta * blueDelta
                if distanceSquared >= 80 * 80 {
                    return true
                }
            }
        }
        return false
    }

    /// Re-renders into a predictable RGBA buffer, removes transparent margins
    /// and caps very large source files without changing the visible aspect.
    private static func normalizedWatermark(from source: UIImage) -> UIImage? {
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let maximumDimension: CGFloat = 2048
        let downscale = min(
            1,
            maximumDimension / max(sourceSize.width, sourceSize.height)
        )
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * downscale).rounded()),
            height: max(1, (sourceSize.height * downscale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let cgImage = rendered.cgImage,
              let cropped = croppedToVisiblePixels(cgImage) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    private static func croppedToVisiblePixels(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let rawPixels = context.data else { return nil }
        let pixels = rawPixels.assumingMemoryBound(to: UInt8.self)

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
                guard alpha > 3 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        let padding = max(2, Int(CGFloat(max(width, height)) * 0.012))
        let cropRect = CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: min(width - 1, maxX + padding) - max(0, minX - padding) + 1,
            height: min(height - 1, maxY + padding) - max(0, minY - padding) + 1
        )
        return context.makeImage()?.cropping(to: cropRect)
    }
}

struct CameraWatermarkManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var isEnabled: Bool
    @ObservedObject var library: CameraWatermarkLibrary

    @State private var importingBrand: CameraWatermarkBrand?
    @State private var isImporterPresented = false
    @State private var alertMessage = ""
    @State private var isAlertPresented = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("相机图标水印")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .liquidGlass(in: Circle(), interactive: true, variant: .clear)
            }
            .padding(.horizontal, 18)
            .frame(height: 66)
            .background(.ultraThinMaterial)
            .zIndex(5)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 30)

                        Text("本应用不内置、不提供、也不使用任何相机品牌素材。所有图标均由用户从“文件”App 本地导入，不会上传。请确保你有权使用所选素材。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .liquidGlass(
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                        variant: .clear
                    )

                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "seal")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("使用本地图标水印")
                                .font(.headline)
                            Text("启用后，有对应品牌 PNG 时将替换默认圆形相机图标。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Toggle("使用本地图标水印", isOn: $isEnabled)
                            .labelsHidden()
                    }
                    .padding(16)
                    .liquidGlass(
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                        interactive: true,
                        variant: .clear
                    )

                    if isEnabled {
                        Text("品牌图标")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(CameraWatermarkBrand.allCases) { brand in
                                brandCard(brand)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .animation(.easeInOut(duration: 0.22), value: isEnabled)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("无法添加图标水印", isPresented: $isAlertPresented) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    @ViewBuilder
    private func brandCard(_ brand: CameraWatermarkBrand) -> some View {
        let image = library.image(for: brand)
        VStack(spacing: 10) {
            Text(brand.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)

            if let image {
                Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 92, maxHeight: 42)
                    .frame(height: 46)

                HStack(spacing: 8) {
                    Button {
                        presentImporter(for: brand)
                    } label: {
                        Label("替换", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        library.remove(brand)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    presentImporter(for: brand)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .liquidGlass(in: Circle(), interactive: true, variant: .clear)
                .accessibilityLabel("为\(brand.displayName)添加 PNG 图标水印")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: image == nil ? 104 : 136)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            variant: .clear
        )
    }

    private func presentImporter(for brand: CameraWatermarkBrand) {
        importingBrand = brand
        isImporterPresented = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let brand = importingBrand else { return }
        importingBrand = nil
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            try library.importPNG(from: url, for: brand)
        } catch is CancellationError {
            return
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription
                ?? "无法读取所选图片，请稍后重试。"
            isAlertPresented = true
        }
    }
}
