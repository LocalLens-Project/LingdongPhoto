// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreImage
import ImageIO
import SwiftUI
import UIKit
import Vision

enum PrivacyMaskKind: String, Sendable {
    case face
    case licensePlate
    case qrCode
    case sensitiveText

    var title: String {
        switch self {
        case .face: "人脸"
        case .licensePlate: "车牌"
        case .qrCode: "二维码"
        case .sensitiveText: "敏感文字"
        }
    }

    var symbol: String {
        switch self {
        case .face: "face.smiling"
        case .licensePlate: "car.side"
        case .qrCode: "qrcode"
        case .sensitiveText: "text.viewfinder"
        }
    }
}

struct PrivacyMask: Identifiable, Equatable, Sendable {
    let id: UUID
    var kind: PrivacyMaskKind
    var normalizedRect: CGRect
    var isEnabled: Bool

    nonisolated init(
        id: UUID = UUID(),
        kind: PrivacyMaskKind,
        normalizedRect: CGRect,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.normalizedRect = normalizedRect
        self.isEnabled = isEnabled
    }
}

struct PrivacyStroke: Identifiable, Equatable, Sendable {
    let id: UUID
    var points: [CGPoint]
    var normalizedWidth: CGFloat

    nonisolated init(id: UUID = UUID(), points: [CGPoint], normalizedWidth: CGFloat) {
        self.id = id
        self.points = points
        self.normalizedWidth = normalizedWidth
    }
}

struct PrivacyEditSnapshot {
    let masks: [PrivacyMask]
    let strokes: [PrivacyStroke]
}

enum PrivacyBrushMode: String, CaseIterable, Identifiable {
    case paint = "涂抹"
    case erase = "擦除"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .paint: "paintbrush.pointed"
        case .erase: "eraser"
        }
    }
}

enum PrivacyContentDetector {
    nonisolated static func detect(_ data: Data) async -> [PrivacyMask] {
        await Task.detached(priority: .userInitiated) {
            detectSynchronously(data)
        }.value
    }

    nonisolated private static func detectSynchronously(_ data: Data) -> [PrivacyMask] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return []
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up

        let faceRequest = VNDetectFaceRectanglesRequest()
        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.qr]
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.automaticallyDetectsLanguage = true
        textRequest.minimumTextHeight = 0.012

        let requests: [(name: String, request: VNRequest)] = [
            ("face", faceRequest),
            ("barcode", barcodeRequest),
            ("text", textRequest)
        ]
        var completedRequestCount = 0
        for request in requests {
            do {
                try VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                ).perform([request.request])
                completedRequestCount += 1
            } catch {
#if DEBUG
                print("PRIVACY_VISION_\(request.name.uppercased())_ERROR: \(error.localizedDescription)")
#endif
            }
        }
        guard completedRequestCount > 0 else { return [] }

        var masks: [PrivacyMask] = []
        let visionFaceRects = (faceRequest.results ?? []).map { topLeftRect($0.boundingBox) }
        let faceRects = visionFaceRects.isEmpty
            ? fallbackFaceRects(cgImage: cgImage, exifOrientation: rawOrientation)
            : visionFaceRects
        for rect in faceRects {
            masks.append(PrivacyMask(
                kind: .face,
                normalizedRect: expanded(rect, horizontal: 0.16, vertical: 0.20)
            ))
        }
        let visionBarcodeRects = (barcodeRequest.results ?? []).map { topLeftRect($0.boundingBox) }
        let qrCodeRects = visionBarcodeRects.isEmpty
            ? fallbackQRCodeRects(cgImage: cgImage, exifOrientation: rawOrientation)
            : visionBarcodeRects
        for rect in qrCodeRects {
            masks.append(PrivacyMask(
                kind: .qrCode,
                normalizedRect: expanded(rect, horizontal: 0.10, vertical: 0.10)
            ))
        }
        let recognizedText: [(observation: VNRecognizedTextObservation, value: String)] =
            (textRequest.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= 0.25 else { return nil }
                return (
                    observation,
                    candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        let identityDocumentKeywords = [
            "居民身份证", "公民身份号码", "姓名", "住址", "签发机关", "有效期限"
        ]
        let identityKeywordHits = recognizedText.reduce(into: 0) { count, item in
            if identityDocumentKeywords.contains(where: item.value.contains) { count += 1 }
        }
        let isIdentityDocument = identityKeywordHits >= 2
            || recognizedText.contains(where: { $0.value.contains("公民身份号码") })

        for item in recognizedText {
            let value = item.value
            let observation = item.observation
            let rect = topLeftRect(observation.boundingBox)
            if looksLikeLicensePlate(value, aspectRatio: rect.width / max(rect.height, 0.001)) {
                masks.append(PrivacyMask(
                    kind: .licensePlate,
                    normalizedRect: expanded(rect, horizontal: 0.12, vertical: 0.24)
                ))
            } else if isIdentityDocument || looksSensitive(value) {
                masks.append(PrivacyMask(
                    kind: .sensitiveText,
                    normalizedRect: expanded(rect, horizontal: 0.08, vertical: 0.18)
                ))
            }
        }
        return deduplicated(masks)
    }

    nonisolated private static func topLeftRect(_ visionRect: CGRect) -> CGRect {
        CGRect(
            x: visionRect.minX,
            y: 1 - visionRect.maxY,
            width: visionRect.width,
            height: visionRect.height
        )
    }

    nonisolated private static func fallbackQRCodeRects(
        cgImage: CGImage,
        exifOrientation: UInt32
    ) -> [CGRect] {
        let image = CIImage(cgImage: cgImage)
            .oriented(forExifOrientation: Int32(exifOrientation))
        let extent = image.extent
        guard extent.width > 0,
              extent.height > 0,
              let detector = CIDetector(
                ofType: CIDetectorTypeQRCode,
                context: CIContext(options: [.cacheIntermediates: false]),
                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
              ) else { return [] }

        return detector.features(in: image)
            .compactMap { $0 as? CIQRCodeFeature }
            .map { feature in
                CGRect(
                    x: (feature.bounds.minX - extent.minX) / extent.width,
                    y: 1 - (feature.bounds.maxY - extent.minY) / extent.height,
                    width: feature.bounds.width / extent.width,
                    height: feature.bounds.height / extent.height
                )
            }
    }

    nonisolated private static func fallbackFaceRects(
        cgImage: CGImage,
        exifOrientation: UInt32
    ) -> [CGRect] {
        let image = CIImage(cgImage: cgImage)
            .oriented(forExifOrientation: Int32(exifOrientation))
        let extent = image.extent
        guard extent.width > 0,
              extent.height > 0,
              let detector = CIDetector(
                ofType: CIDetectorTypeFace,
                context: CIContext(options: [.cacheIntermediates: false]),
                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
              ) else { return [] }

        return detector.features(in: image)
            .compactMap { $0 as? CIFaceFeature }
            .map { feature in
                CGRect(
                    x: (feature.bounds.minX - extent.minX) / extent.width,
                    y: 1 - (feature.bounds.maxY - extent.minY) / extent.height,
                    width: feature.bounds.width / extent.width,
                    height: feature.bounds.height / extent.height
                )
            }
    }

    nonisolated private static func expanded(
        _ rect: CGRect,
        horizontal: CGFloat,
        vertical: CGFloat
    ) -> CGRect {
        let expanded = rect.insetBy(
            dx: -rect.width * horizontal,
            dy: -rect.height * vertical
        )
        return expanded.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    nonisolated private static func looksLikeLicensePlate(_ text: String, aspectRatio: CGFloat) -> Bool {
        let compact = text
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "-", with: "")
        if compact.range(
            of: "^[\\p{Han}][A-Z][A-Z0-9]{5,6}$",
            options: .regularExpression
        ) != nil {
            return true
        }
        let hasLetter = compact.rangeOfCharacter(from: .letters) != nil
        let hasNumber = compact.rangeOfCharacter(from: .decimalDigits) != nil
        return aspectRatio >= 2.1
            && (5...9).contains(compact.count)
            && hasLetter
            && hasNumber
            && compact.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil
    }

    nonisolated private static func looksSensitive(_ text: String) -> Bool {
        let normalized = text.replacingOccurrences(of: " ", with: "")
        let patterns = [
            "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
            "(?:https?://|www\\.)[^\\s]+",
            "(?:\\+?86[- ]?)?1[3-9]\\d{9}",
            "(?<!\\d)\\d{7,12}(?!\\d)",
            "(?<!\\d)\\d{15}(?:\\d{2}[0-9Xx])?(?!\\d)",
            "(?<!\\d)\\d{16,19}(?!\\d)"
        ]
        if patterns.contains(where: {
            normalized.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) {
            return true
        }
        let keywords = [
            "身份证", "公民身份号码", "证件号码", "姓名", "性别", "民族",
            "出生", "出生日期", "住址", "地址", "门牌", "签发机关", "有效期限",
            "电话", "手机号", "邮箱", "银行卡", "账号", "收件人", "快递单",
            "护照", "车牌"
        ]
        return keywords.contains(where: normalized.contains)
    }

    nonisolated private static func deduplicated(_ masks: [PrivacyMask]) -> [PrivacyMask] {
        var result: [PrivacyMask] = []
        for mask in masks.sorted(by: { $0.normalizedRect.width * $0.normalizedRect.height > $1.normalizedRect.width * $1.normalizedRect.height }) {
            let duplicate = result.contains {
                $0.kind == mask.kind && intersectionOverUnion($0.normalizedRect, mask.normalizedRect) > 0.52
            }
            if !duplicate { result.append(mask) }
        }
        return result.sorted {
            if $0.normalizedRect.minY == $1.normalizedRect.minY {
                return $0.normalizedRect.minX < $1.normalizedRect.minX
            }
            return $0.normalizedRect.minY < $1.normalizedRect.minY
        }
    }

    nonisolated private static func intersectionOverUnion(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = lhs.width * lhs.height + rhs.width * rhs.height - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }
}

enum PrivacyMosaicRenderer {
    static func makePixelatedImage(from image: UIImage, strength: Double) -> UIImage? {
        guard let normalized = normalizedImage(image), let cgImage = normalized.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let minimumDimension = CGFloat(min(cgImage.width, cgImage.height))
        let blockSize = minimumDimension * (0.018 + CGFloat(min(max(strength, 0), 1)) * 0.052)

        let blur = CIFilter(name: "CIGaussianBlur")
        blur?.setValue(input, forKey: kCIInputImageKey)
        blur?.setValue(max(5, blockSize * 0.62), forKey: kCIInputRadiusKey)
        let blurred = blur?.outputImage?.cropped(to: input.extent) ?? input

        let pixelate = CIFilter(name: "CIPixellate")
        pixelate?.setValue(blurred, forKey: kCIInputImageKey)
        pixelate?.setValue(blockSize, forKey: kCIInputScaleKey)
        pixelate?.setValue(
            CIVector(x: input.extent.midX, y: input.extent.midY),
            forKey: kCIInputCenterKey
        )
        guard let output = pixelate?.outputImage?.cropped(to: input.extent),
              let outputImage = CIContext(options: [.cacheIntermediates: false]).createCGImage(
                output,
                from: input.extent
              ) else { return nil }
        return UIImage(cgImage: outputImage, scale: 1, orientation: .up)
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage? {
        if image.imageOrientation == .up, image.scale == 1, image.cgImage != nil {
            return image
        }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

struct PrivacyMosaicCanvas: View {
    let image: UIImage
    let pixelatedImage: UIImage?
    let masks: [PrivacyMask]
    let strokes: [PrivacyStroke]
    let imageScale: CGFloat
    let imageOffset: CGSize
    let isExporting: Bool

    var body: some View {
        GeometryReader { proxy in
            let contentSize = aspectFitSize(imageSize: image.size, canvasSize: proxy.size)
            ZStack {
                Color.black.opacity(0.88)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: contentSize.width, height: contentSize.height)
                        .clipped()

                    Group {
                        if let pixelatedImage {
                            Image(uiImage: pixelatedImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            // A filter failure must never expose the selected privacy area.
                            Color.black
                        }
                    }
                    .frame(width: contentSize.width, height: contentSize.height)
                    .clipped()
                    .mask {
                        PrivacyMosaicMaskLayer(masks: masks, strokes: strokes)
                    }

                    if !isExporting {
                        PrivacyMaskGuides(masks: masks)
                    }
                }
                .frame(width: contentSize.width, height: contentSize.height)
                .scaleEffect(imageScale)
                .offset(imageOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private func aspectFitSize(imageSize: CGSize, canvasSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return canvasSize }
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private struct PrivacyMosaicMaskLayer: View {
    let masks: [PrivacyMask]
    let strokes: [PrivacyStroke]

    var body: some View {
        Canvas { context, size in
            for mask in masks where mask.isEnabled {
                let rect = CGRect(
                    x: mask.normalizedRect.minX * size.width,
                    y: mask.normalizedRect.minY * size.height,
                    width: mask.normalizedRect.width * size.width,
                    height: mask.normalizedRect.height * size.height
                )
                var path = Path()
                path.addRoundedRect(
                    in: rect,
                    cornerSize: CGSize(width: min(12, rect.height * 0.22), height: min(12, rect.height * 0.22))
                )
                context.fill(path, with: .color(.white))
            }

            let minimumDimension = min(size.width, size.height)
            for stroke in strokes where !stroke.points.isEmpty {
                let lineWidth = max(3, stroke.normalizedWidth * minimumDimension)
                if stroke.points.count == 1, let point = stroke.points.first {
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: point.x * size.width - lineWidth / 2,
                            y: point.y * size.height - lineWidth / 2,
                            width: lineWidth,
                            height: lineWidth
                        )),
                        with: .color(.white)
                    )
                } else {
                    var path = Path()
                    if let first = stroke.points.first {
                        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    }
                    for point in stroke.points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                    context.stroke(
                        path,
                        with: .color(.white),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }
}

private struct PrivacyMaskGuides: View {
    let masks: [PrivacyMask]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(masks) { mask in
                    let rect = CGRect(
                        x: mask.normalizedRect.minX * proxy.size.width,
                        y: mask.normalizedRect.minY * proxy.size.height,
                        width: mask.normalizedRect.width * proxy.size.width,
                        height: mask.normalizedRect.height * proxy.size.height
                    )
                    RoundedRectangle(cornerRadius: min(12, rect.height * 0.22), style: .continuous)
                        .stroke(
                            mask.isEnabled ? Color.white.opacity(0.90) : Color.orange.opacity(0.95),
                            style: StrokeStyle(
                                lineWidth: mask.isEnabled ? 1.4 : 2,
                                dash: mask.isEnabled ? [] : [5, 4]
                            )
                        )
                        .frame(width: rect.width, height: rect.height)
                        .overlay(alignment: .topLeading) {
                            Image(systemName: mask.isEnabled ? mask.kind.symbol : "eye.slash.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(mask.isEnabled ? .black : .white)
                                .frame(width: 20, height: 20)
                                .background(mask.isEnabled ? .white.opacity(0.92) : .orange, in: Circle())
                                .offset(x: -7, y: -7)
                        }
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct PrivacyMosaicControls: View {
    @Binding var brushMode: PrivacyBrushMode
    @Binding var strength: Double
    let isPainting: Bool
    let isDetecting: Bool
    let canUndo: Bool
    let detectedCount: Int
    let disabledCount: Int
    let hasLivePhoto: Bool
    let onTogglePainting: () -> Void
    let onDetect: () -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                privacyActionButton(
                    title: isPainting ? "完成涂抹" : "手动涂抹",
                    symbol: isPainting ? "checkmark" : "hand.draw",
                    isActive: isPainting,
                    isBusy: false,
                    action: onTogglePainting
                )
                privacyActionButton(
                    title: "智能识别",
                    symbol: "viewfinder",
                    isActive: false,
                    isBusy: isDetecting,
                    action: onDetect
                )
                .disabled(isDetecting)
                .opacity(isDetecting ? 0.72 : 1)
            }

            if isPainting {
                HStack(spacing: 7) {
                    ForEach(PrivacyBrushMode.allCases) { tool in
                        Button {
                            brushMode = tool
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(tool.rawValue, systemImage: tool.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(brushMode == tool ? .white : .primary.opacity(0.68))
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(
                                    brushMode == tool ? Color.black.opacity(0.78) : Color.clear,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 4)
                    Text("单指\(brushMode.rawValue)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(height: 42)
                .liquidGlass(in: Capsule(), variant: .clear)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Slider(value: $strength, in: 0...1)
                        .tint(.primary)
                        .accessibilityLabel("马赛克颗粒大小")
                    Text(strength < 0.34 ? "细" : strength < 0.68 ? "中" : "强")
                        .font(.caption2.bold())
                        .frame(width: 22)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .liquidGlass(in: Capsule(), variant: .clear)

                LiquidCircleButton(
                    symbol: "arrow.uturn.backward",
                    isEnabled: canUndo,
                    action: onUndo
                )
                .scaleEffect(0.92)
            }

            if detectedCount > 0 {
                Text("已识别 \(detectedCount) 处 · 点击区域可关闭或恢复\(disabledCount > 0 ? "（已关闭 \(disabledCount) 处）" : "")")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.62))
                    .multilineTextAlignment(.center)
            }

            if hasLivePhoto {
                Label("隐私遮挡后仅支持静态导出", systemImage: "livephoto.slash")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .animation(.snappy, value: isPainting)
        .animation(.easeInOut(duration: 0.2), value: detectedCount)
    }

    private func privacyActionButton(
        title: String,
        symbol: String,
        isActive: Bool,
        isBusy: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: symbol)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isActive ? .white.opacity(0.28) : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PrivacyCapsuleButtonStyle())
        .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
    }
}

private struct PrivacyCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
