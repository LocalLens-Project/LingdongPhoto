// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import SwiftUI
import UIKit

enum ColorInsightPage: String, CaseIterable, Identifiable {
    case palette
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .palette: String(localized: "琉璃色盘")
        case .light: String(localized: "光影解析")
        }
    }
}

enum LightToneRange: String, CaseIterable, Identifiable {
    case shadows
    case midtones
    case highlights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shadows: String(localized: "暗处")
        case .midtones: String(localized: "日常亮度")
        case .highlights: String(localized: "明亮处")
        }
    }

    nonisolated fileprivate func contains(_ luminance: Double) -> Bool {
        switch self {
        case .shadows: luminance < 0.25
        case .midtones: luminance >= 0.25 && luminance < 0.75
        case .highlights: luminance >= 0.75
        }
    }
}

struct PhotoLightAnalysis: Equatable, @unchecked Sendable {
    nonisolated static let binCount = 64

    let luminanceHistogram: [Double]
    let redHistogram: [Double]
    let greenHistogram: [Double]
    let blueHistogram: [Double]
    let shadowShare: Double
    let midtoneShare: Double
    let highlightShare: Double
    let crushedBlackShare: Double
    let clippedWhiteShare: Double
    let averageLuminance: Double
    let contrastSpan: Double
    let redAverage: Double
    let greenAverage: Double
    let blueAverage: Double
    let toneOverlays: [LightToneRange: UIImage]

    func share(for range: LightToneRange) -> Double {
        switch range {
        case .shadows: shadowShare
        case .midtones: midtoneShare
        case .highlights: highlightShare
        }
    }

    func overlay(for range: LightToneRange?) -> UIImage? {
        guard let range else { return nil }
        return toneOverlays[range]
    }
}

enum PhotoLightAnalyzer {
    nonisolated private static let sampleLongEdge = 512

    nonisolated static func analyze(_ image: UIImage) async -> PhotoLightAnalysis? {
        await Task.detached(priority: .userInitiated) {
            analyzeSynchronously(image)
        }.value
    }

    nonisolated private static func analyzeSynchronously(_ image: UIImage) -> PhotoLightAnalysis? {
        guard let source = normalizedCGImage(from: image) else { return nil }
        let sourceWidth = source.width
        let sourceHeight = source.height
        guard sourceWidth > 0, sourceHeight > 0 else { return nil }

        let scale = min(1, Double(sampleLongEdge) / Double(max(sourceWidth, sourceHeight)))
        let width = max(1, Int((Double(sourceWidth) * scale).rounded()))
        let height = max(1, Int((Double(sourceHeight) * scale).rounded()))
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminanceBins = [Double](repeating: 0, count: PhotoLightAnalysis.binCount)
        var redBins = luminanceBins
        var greenBins = luminanceBins
        var blueBins = luminanceBins
        var luminances = [Double]()
        luminances.reserveCapacity(width * height)
        var redSum = 0.0
        var greenSum = 0.0
        var blueSum = 0.0
        var shadowCount = 0
        var midtoneCount = 0
        var highlightCount = 0
        var crushedCount = 0
        var clippedCount = 0

        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[pixel + 3]) / 255
            guard alpha > 0.02 else { continue }
            let red = min(1, Double(pixels[pixel]) / 255 / alpha)
            let green = min(1, Double(pixels[pixel + 1]) / 255 / alpha)
            let blue = min(1, Double(pixels[pixel + 2]) / 255 / alpha)
            // Rec. 709 coefficients on gamma-encoded display values produce a
            // histogram that matches what people perceive in Photos more closely
            // than a linear-light engineering histogram.
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
            luminances.append(luminance)
            redSum += red
            greenSum += green
            blueSum += blue
            redBins[bin(for: red)] += 1
            greenBins[bin(for: green)] += 1
            blueBins[bin(for: blue)] += 1
            luminanceBins[bin(for: luminance)] += 1

            if luminance < 0.25 {
                shadowCount += 1
            } else if luminance < 0.75 {
                midtoneCount += 1
            } else {
                highlightCount += 1
            }
            if luminance <= 2.5 / 255 { crushedCount += 1 }
            if luminance >= 252.5 / 255 { clippedCount += 1 }
        }

        let count = max(1, luminances.count)
        let sorted = luminances.sorted()
        let low = percentile(0.05, in: sorted)
        let high = percentile(0.95, in: sorted)
        let normalization = Double(count)
        let overlays = Dictionary(uniqueKeysWithValues: LightToneRange.allCases.compactMap { range in
            makeOverlay(
                pixels: pixels,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                range: range,
                colorSpace: colorSpace
            ).map { (range, $0) }
        })

        return PhotoLightAnalysis(
            luminanceHistogram: normalize(luminanceBins, by: normalization),
            redHistogram: normalize(redBins, by: normalization),
            greenHistogram: normalize(greenBins, by: normalization),
            blueHistogram: normalize(blueBins, by: normalization),
            shadowShare: Double(shadowCount) / normalization,
            midtoneShare: Double(midtoneCount) / normalization,
            highlightShare: Double(highlightCount) / normalization,
            crushedBlackShare: Double(crushedCount) / normalization,
            clippedWhiteShare: Double(clippedCount) / normalization,
            averageLuminance: luminances.reduce(0, +) / normalization,
            contrastSpan: max(0, high - low),
            redAverage: redSum / normalization,
            greenAverage: greenSum / normalization,
            blueAverage: blueSum / normalization,
            toneOverlays: overlays
        )
    }

    nonisolated private static func bin(for value: Double) -> Int {
        min(PhotoLightAnalysis.binCount - 1, max(0, Int(value * Double(PhotoLightAnalysis.binCount))))
    }

    nonisolated private static func normalize(_ values: [Double], by count: Double) -> [Double] {
        guard count > 0 else { return values }
        return values.map { $0 / count }
    }

    nonisolated private static func percentile(_ value: Double, in sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * value).rounded())))
        return sorted[index]
    }

    nonisolated private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: image.size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
            .cgImage
    }

    nonisolated private static func makeOverlay(
        pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        range: LightToneRange,
        colorSpace: CGColorSpace
    ) -> UIImage? {
        var overlay = [UInt8](repeating: 0, count: pixels.count)
        let tint: (UInt8, UInt8, UInt8)
        switch range {
        case .shadows: tint = (91, 181, 255)
        case .midtones: tint = (255, 210, 94)
        case .highlights: tint = (255, 126, 91)
        }
        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[pixel + 3]) / 255
            guard alpha > 0.02 else { continue }
            let red = min(1, Double(pixels[pixel]) / 255 / alpha)
            let green = min(1, Double(pixels[pixel + 1]) / 255 / alpha)
            let blue = min(1, Double(pixels[pixel + 2]) / 255 / alpha)
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
            guard range.contains(luminance) else { continue }
            overlay[pixel] = tint.0
            overlay[pixel + 1] = tint.1
            overlay[pixel + 2] = tint.2
            overlay[pixel + 3] = 116
        }
        guard let provider = CGDataProvider(data: Data(overlay) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }
}

enum PhotoLightNarrative {
    static func headline(for analysis: PhotoLightAnalysis, semantic: PhotoSemantic) -> String {
        if analysis.clippedWhiteShare >= 0.035 {
            return String(localized: "最亮处有一部分已经看不见纹理")
        }
        if analysis.crushedBlackShare >= 0.08 {
            return semantic.primaryCategory == .night
                ? String(localized: "暗色很多，但很符合夜景的氛围")
                : String(localized: "画面偏暗，最深处藏住了一些细节")
        }
        if analysis.midtoneShare >= 0.58 {
            return String(localized: "大部分光线都落在舒服、自然的范围里")
        }
        if analysis.averageLuminance >= 0.66 {
            return String(localized: "这是一张轻盈明亮的照片")
        }
        if analysis.averageLuminance <= 0.34 {
            return String(localized: "这张照片用较深的光影营造气氛")
        }
        return String(localized: "明暗分布均衡，主体层次保留得很好")
    }

    static func detail(for analysis: PhotoLightAnalysis, semantic: PhotoSemantic) -> String {
        if analysis.clippedWhiteShare >= 0.035 {
            return semantic.primaryCategory == .sunset || semantic.primaryCategory == .sky
                ? String(localized: "高光多半来自天空或光源；只要主体仍然清楚，就更像一种取舍，而不是整张照片失败。")
                : String(localized: "可以留意白色物体、窗外或灯光附近；这些位置可能已经亮到无法恢复细节。")
        }
        if analysis.crushedBlackShare >= 0.08 {
            return semantic.primaryCategory == .night
                ? String(localized: "夜景本来就允许大片暗处。这里的暗色更像氛围，只需确认人物或主体仍然清楚。")
                : String(localized: "最暗区域已经接近纯黑。若主体也落在其中，可以尝试稍微提亮阴影。")
        }
        if analysis.contrastSpan >= 0.78 {
            return String(localized: "照片同时拥有很深和很亮的区域，因此看起来更有力量；主体附近仍保留着可读的过渡。")
        }
        if analysis.contrastSpan <= 0.40 {
            return String(localized: "亮与暗之间距离不大，画面会显得柔和、安静，而不是没有层次。")
        }
        return String(localized: "从暗处到明亮处都有连续过渡，没有明显挤在某一个亮度区间。")
    }

    static func colorHint(for analysis: PhotoLightAnalysis) -> String? {
        let maximum = max(analysis.redAverage, analysis.greenAverage, analysis.blueAverage)
        let minimum = min(analysis.redAverage, analysis.greenAverage, analysis.blueAverage)
        guard maximum - minimum >= 0.075 else { return nil }
        if analysis.redAverage == maximum {
            return String(localized: "红色通道更突出，画面整体偏暖。")
        }
        if analysis.blueAverage == maximum {
            return String(localized: "蓝色通道更突出，画面整体偏冷。")
        }
        return String(localized: "绿色通道更突出，植物或自然色可能占据较多画面。")
    }
}

struct ColorInsightSwitcher: View {
    @Binding var selection: ColorInsightPage
    let reduceMotion: Bool

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            PhotosStyleSegmentedControl(selection: $selection)
                .frame(width: 244, height: 48)
                .accessibilityLabel(String(localized: "光色解读视图"))
        } else {
            Picker("光色解读视图", selection: animatedSelection) {
                ForEach(ColorInsightPage.allCases) { page in
                    Text(LocalizedStringKey(page.title))
                        .tag(page)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .labelsHidden()
            .frame(width: 244)
            .accessibilityLabel(String(localized: "光色解读视图"))
        }
    }

    private var animatedSelection: Binding<ColorInsightPage> {
        Binding(
            get: { selection },
            set: { page in
                guard page != selection else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.12)
                        : .snappy(duration: 0.38, extraBounce: 0.06)
                ) {
                    selection = page
                }
            }
        )
    }
}

@available(iOS 26.0, *)
private struct PhotosStyleSegmentedControl: UIViewRepresentable {
    @Binding var selection: ColorInsightPage

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: ColorInsightPage.allCases.map(\.title))
        control.selectedSegmentIndex = selectedIndex
        control.selectedSegmentTintColor = .secondarySystemFill
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:)),
            for: .valueChanged
        )
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        if control.selectedSegmentIndex != selectedIndex {
            control.selectedSegmentIndex = selectedIndex
        }

        for (index, page) in ColorInsightPage.allCases.enumerated()
        where control.titleForSegment(at: index) != page.title {
            control.setTitle(page.title, forSegmentAt: index)
        }
    }

    private var selectedIndex: Int {
        ColorInsightPage.allCases.firstIndex(of: selection) ?? 0
    }

    final class Coordinator: NSObject {
        var selection: Binding<ColorInsightPage>

        init(selection: Binding<ColorInsightPage>) {
            self.selection = selection
        }

        @objc func selectionChanged(_ control: UISegmentedControl) {
            guard ColorInsightPage.allCases.indices.contains(control.selectedSegmentIndex) else {
                return
            }
            UISelectionFeedbackGenerator().selectionChanged()
            selection.wrappedValue = ColorInsightPage.allCases[control.selectedSegmentIndex]
        }
    }
}

struct LightAnalysisPanel: View {
    let analysis: PhotoLightAnalysis
    let semantic: PhotoSemantic
    @Binding var activeRange: LightToneRange?

    private var headline: String {
        PhotoLightNarrative.headline(for: analysis, semantic: semantic)
    }

    private var detail: String {
        PhotoLightNarrative.detail(for: analysis, semantic: semantic)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(headline))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey(detail))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            histogram
                .frame(height: 86)

            Label(
                String(localized: "按住图表查看照片中的对应区域"),
                systemImage: "hand.point.up.left"
            )
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)

            HStack(spacing: 8) {
                ForEach(LightToneRange.allCases) { range in
                    toneSummary(range)
                }
            }

            if let colorHint = PhotoLightNarrative.colorHint(for: analysis) {
                Label(LocalizedStringKey(colorHint), systemImage: "circle.lefthalf.filled")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            variant: .clear
        )
        .accessibilityElement(children: .contain)
    }

    private var histogram: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 0) {
                    Color.blue.opacity(activeRange == .shadows ? 0.13 : 0.035)
                    Color.yellow.opacity(activeRange == .midtones ? 0.13 : 0.035)
                    Color.orange.opacity(activeRange == .highlights ? 0.13 : 0.035)
                }

                Canvas { context, size in
                    drawHistogram(analysis.redHistogram, color: .red.opacity(0.48), in: &context, size: size)
                    drawHistogram(analysis.greenHistogram, color: .green.opacity(0.42), in: &context, size: size)
                    drawHistogram(analysis.blueHistogram, color: .blue.opacity(0.50), in: &context, size: size)
                    drawHistogram(analysis.luminanceHistogram, color: .primary.opacity(0.72), in: &context, size: size, lineWidth: 1.6)
                }

                HStack {
                    Text(String(localized: "更暗"))
                    Spacer()
                    Text(String(localized: "更亮"))
                }
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.76))
                .padding(.horizontal, 7)
                .padding(.bottom, 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.primary.opacity(0.08), lineWidth: 0.8))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = min(max(value.location.x / max(proxy.size.width, 1), 0), 0.999)
                        let range: LightToneRange = fraction < 0.25
                            ? .shadows
                            : (fraction < 0.75 ? .midtones : .highlights)
                        guard activeRange != range else { return }
                        activeRange = range
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    .onEnded { _ in activeRange = nil }
            )
            .accessibilityLabel(String(localized: "照片明暗分布图"))
            .accessibilityHint(String(localized: "按住并左右移动，可在照片中查看对应的暗处、日常亮度和明亮区域"))
        }
    }

    private func toneSummary(_ range: LightToneRange) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(range.title))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(analysis.share(for: range), format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(height: 43)
        .background(.primary.opacity(activeRange == range ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 13))
        .animation(.easeOut(duration: 0.12), value: activeRange)
        .accessibilityElement(children: .combine)
    }

    private func drawHistogram(
        _ values: [Double],
        color: Color,
        in context: inout GraphicsContext,
        size: CGSize,
        lineWidth: CGFloat = 1
    ) {
        guard values.count > 1, let maximum = values.max(), maximum > 0 else { return }
        // A square-root scale keeps small but meaningful groups visible without
        // allowing one narrow spike to flatten the rest of the photograph.
        let scaledMaximum = sqrt(maximum)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let normalized = sqrt(max(0, value)) / scaledMaximum
            path.addLine(to: CGPoint(x: x, y: size.height - CGFloat(normalized) * (size.height - 9)))
        }
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }
}

struct LightAnalysisLoadingPanel: View {
    var body: some View {
        HStack(spacing: 11) {
            ProgressView().controlSize(.small)
            Text("正在读取照片里的光线…")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), variant: .clear)
    }
}
