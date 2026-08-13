// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import Foundation
import SwiftUI
import UIKit

enum AlbumPDFKind: String, CaseIterable, Identifiable {
    case printReady
    case digitalPages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .printReady: "印刷 PDF"
        case .digitalPages: "电子版 PDF"
        }
    }

    var detail: String {
        switch self {
        case .printReady: "逐页输出，包含 3 mm 出血，适合交付打印"
        case .digitalPages: "逐页输出预览中的实际页面，不添加背景或左右拼版"
        }
    }

    var symbol: String {
        switch self {
        case .printReady: "printer"
        case .digitalPages: "doc.richtext"
        }
    }
}

struct AlbumExportedFile: Identifiable {
    let id = UUID()
    let url: URL
    let kind: AlbumPDFKind
}

enum AlbumExportError: LocalizedError {
    case noPages
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .noPages: "相簿中没有可导出的页面。"
        case .renderFailed: "相簿 PDF 生成失败，请稍后重试。"
        }
    }
}

/// Resolves typography once for both the interactive canvas and PDF renderer.
/// It never truncates user copy: the font is reduced only when the complete
/// string cannot fit inside its template text frame.
enum AlbumTypography {
    static func attributedString(
        for block: AlbumTextBlock,
        project: AlbumProject,
        page: AlbumPage,
        bounds: CGRect,
        frame: CGRect
    ) -> NSAttributedString {
        let unit = min(bounds.width, bounds.height)
        let baseFont = font(
            project: project,
            page: page,
            style: block.style,
            unit: unit
        )
        let color: UIColor
        if page.layout == .fullBleed, block.style == .coverTitle {
            color = .white
        } else {
            color = switch block.style {
            case .coverSubtitle, .caption, .pageNumber:
                UIColor.black.withAlphaComponent(0.50)
            default:
                UIColor.black.withAlphaComponent(0.82)
            }
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = block.alignment.nsAlignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = max(0, baseFont.pointSize * 0.12)

        let resolvedFont = fittedFont(
            baseFont,
            text: block.text,
            color: color,
            paragraph: paragraph,
            frame: frame,
            minimumPointSize: max(1.5, unit * 0.004)
        )
        paragraph.lineSpacing = max(0, resolvedFont.pointSize * 0.12)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if page.layout == .fullBleed, block.style == .coverTitle {
            let shadow = NSShadow()
            shadow.shadowOffset = CGSize(width: 0, height: unit * 0.003)
            shadow.shadowBlurRadius = unit * 0.012
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            attributes[.shadow] = shadow
        }
        return NSAttributedString(string: block.text, attributes: attributes)
    }

    static func draw(_ text: NSAttributedString, in frame: CGRect) {
        guard !text.string.isEmpty, frame.width > 0, frame.height > 0 else { return }
        let measured = text.boundingRect(
            with: CGSize(width: frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let height = min(frame.height, ceil(measured.height))
        let drawingFrame = CGRect(
            x: frame.minX,
            y: frame.minY + max(0, (frame.height - height) / 2),
            width: frame.width,
            height: height
        )
        text.draw(
            with: drawingFrame,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
    }

    private static func fittedFont(
        _ baseFont: UIFont,
        text: String,
        color: UIColor,
        paragraph: NSMutableParagraphStyle,
        frame: CGRect,
        minimumPointSize: CGFloat
    ) -> UIFont {
        guard !text.isEmpty else { return baseFont }

        func fits(_ font: UIFont) -> Bool {
            let candidateParagraph = paragraph.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            candidateParagraph.lineSpacing = max(0, font.pointSize * 0.12)
            let value = NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: candidateParagraph
            ])
            let measured = value.boundingRect(
                with: CGSize(width: frame.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            return ceil(measured.width) <= ceil(frame.width) + 0.5
                && ceil(measured.height) <= ceil(frame.height) + 0.5
        }

        if fits(baseFont) { return baseFont }
        var lower = min(minimumPointSize, baseFont.pointSize)
        var upper = baseFont.pointSize
        for _ in 0..<12 {
            let candidate = (lower + upper) / 2
            if fits(baseFont.withSize(candidate)) {
                lower = candidate
            } else {
                upper = candidate
            }
        }
        return baseFont.withSize(lower)
    }

    private static func font(
        project: AlbumProject,
        page: AlbumPage,
        style: AlbumTextStyle,
        unit: CGFloat
    ) -> UIFont {
        switch style {
        case .coverTitle:
            return displayFont(project: project, page: page, size: max(8, unit * 0.056), weight: .medium)
        case .coverSubtitle:
            return supportingFont(project: project, page: page, size: max(5, unit * 0.020), weight: .semibold)
        case .headline:
            return displayFont(project: project, page: page, size: max(7, unit * 0.042), weight: .semibold)
        case .body:
            return supportingFont(project: project, page: page, size: max(5, unit * 0.022), weight: .regular)
        case .caption:
            return supportingFont(project: project, page: page, size: max(4, unit * 0.018), weight: .regular)
        case .quote:
            return displayFont(project: project, page: page, size: max(6, unit * 0.031), weight: .regular)
        case .pageNumber:
            return overridePageFont(page: page, size: max(4, unit * 0.014), weight: .medium)
                ?? UIFont.monospacedDigitSystemFont(ofSize: max(4, unit * 0.014), weight: .medium)
        }
    }

    private static func displayFont(
        project: AlbumProject,
        page: AlbumPage,
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFont {
        if let font = overridePageFont(page: page, size: size, weight: weight) { return font }
        switch project.resolvedDesignStyle {
        case .filmDiary, .growthNotes, .studioGrid:
            return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .coastPostcard, .sundayTable, .littleUniverse, .rainbowPlay, .playfulPaws, .freeCollage:
            return roundedFont(size: size, weight: weight)
        default:
            return UIFont(name: "Songti SC", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: weight)
        }
    }

    private static func supportingFont(
        project: AlbumProject,
        page: AlbumPage,
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFont {
        if let font = overridePageFont(page: page, size: size, weight: weight) { return font }
        switch project.resolvedDesignStyle {
        case .filmDiary, .growthNotes, .studioGrid:
            return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .coastPostcard, .sundayTable, .littleUniverse, .rainbowPlay, .playfulPaws, .freeCollage:
            return roundedFont(size: size, weight: weight)
        default:
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }

    private static func overridePageFont(
        page: AlbumPage,
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFont? {
        switch page.resolvedFontStyle {
        case .template:
            nil
        case .modern:
            UIFont.systemFont(ofSize: size, weight: weight)
        case .songti:
            UIFont(name: "Songti SC", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: weight)
        case .rounded:
            roundedFont(size: size, weight: weight)
        case .handwritten:
            UIFont(name: "Kaiti SC", size: size)
                ?? UIFont(name: "STKaitiSC-Regular", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: weight)
        case .monospaced:
            UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

/// Produces the exact opaque page colors used by both SwiftUI and PDF output.
/// Keeping the stops opaque also prevents PDF transparency groups from making
/// a pale content page look like a saturated dark backing sheet.
enum AlbumPageAppearance {
    static func paperColor(for style: AlbumDesignStyle) -> UIColor {
        switch style {
        case .coastPostcard: UIColor(red: 0.965, green: 0.982, blue: 0.982, alpha: 1)
        case .filmDiary: UIColor(red: 0.956, green: 0.944, blue: 0.915, alpha: 1)
        case .warmNeutral, .softArch, .sundayTable: UIColor(red: 0.985, green: 0.958, blue: 0.910, alpha: 1)
        case .littleUniverse, .rainbowPlay, .growthNotes: UIColor(red: 0.984, green: 0.979, blue: 0.950, alpha: 1)
        case .quietCompanion, .playfulPaws, .trailJournal: UIColor(red: 0.970, green: 0.966, blue: 0.930, alpha: 1)
        case .studioGrid: UIColor(red: 0.955, green: 0.960, blue: 0.955, alpha: 1)
        default: UIColor(red: 0.985, green: 0.979, blue: 0.962, alpha: 1)
        }
    }

    static func backgroundStops(project: AlbumProject, page: AlbumPage) -> [UIColor] {
        let paper = paperColor(for: project.resolvedDesignStyle)
        let palette = resolvedColors(project.palette)
        if page.role == .cover || page.role == .backCover {
            return palette
        }

        let pageColors = resolvedPageColors(project: project, page: page)
        if !pageColors.isEmpty {
            let strength = max(page.tintStrength, page.layout == .workFeature ? 0.30 : 0.19)
            return pageColors.prefix(3).enumerated().map { index, color in
                composited(
                    color,
                    over: paper,
                    alpha: strength * (1 - CGFloat(index) * 0.18)
                )
            } + [paper]
        }

        guard let first = palette.first, page.tintStrength > 0 else {
            return [paper, paper]
        }
        return [composited(first, over: paper, alpha: page.tintStrength), paper]
    }

    private static func resolvedColors(_ source: [AlbumColor]) -> [UIColor] {
        let colors = source.isEmpty ? AlbumColor.fallback : source
        return colors.map {
            UIColor(red: $0.red, green: $0.green, blue: $0.blue, alpha: 1)
        }
    }

    private static func resolvedPageColors(project: AlbumProject, page: AlbumPage) -> [UIColor] {
        let ids = Set(page.slots.compactMap(\.assetID))
        return Array(project.assets
            .filter { ids.contains($0.id) }
            .flatMap { $0.colors.prefix(2) }
            .prefix(4))
            .map { UIColor(red: $0.red, green: $0.green, blue: $0.blue, alpha: 1) }
    }

    private static func composited(
        _ foreground: UIColor,
        over background: UIColor,
        alpha: CGFloat
    ) -> UIColor {
        var foregroundRed: CGFloat = 0
        var foregroundGreen: CGFloat = 0
        var foregroundBlue: CGFloat = 0
        var foregroundAlpha: CGFloat = 0
        var backgroundRed: CGFloat = 0
        var backgroundGreen: CGFloat = 0
        var backgroundBlue: CGFloat = 0
        var backgroundAlpha: CGFloat = 0
        guard foreground.getRed(
            &foregroundRed,
            green: &foregroundGreen,
            blue: &foregroundBlue,
            alpha: &foregroundAlpha
        ), background.getRed(
            &backgroundRed,
            green: &backgroundGreen,
            blue: &backgroundBlue,
            alpha: &backgroundAlpha
        ) else {
            return background
        }
        let amount = max(0, min(1, alpha * foregroundAlpha))
        return UIColor(
            red: foregroundRed * amount + backgroundRed * (1 - amount),
            green: foregroundGreen * amount + backgroundGreen * (1 - amount),
            blue: foregroundBlue * amount + backgroundBlue * (1 - amount),
            alpha: 1
        )
    }
}

enum AlbumPageRenderer {
    static func renderPage(
        project: AlbumProject,
        page: AlbumPage,
        images: [UUID: UIImage],
        pixelWidth: CGFloat
    ) -> UIImage? {
        let width = max(320, pixelWidth)
        let size = CGSize(width: width, height: width / project.format.aspectRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            drawPage(
                project: project,
                page: page,
                images: images,
                fullBounds: CGRect(origin: .zero, size: size),
                trimBounds: CGRect(origin: .zero, size: size),
                context: context.cgContext
            )
        }
    }

    static func renderBookPages(
        project: AlbumProject,
        images: [UUID: UIImage],
        pagePixelHeight: CGFloat = 1_300
    ) -> [UIImage] {
        guard !project.pages.isEmpty else { return [] }
        let pageWidth = pagePixelHeight * project.format.aspectRatio
        let rendered = project.pages.compactMap { page in
            renderPage(
                project: project,
                page: page,
                images: images,
                pixelWidth: pageWidth
            )
        }
        guard let first = rendered.first else { return [] }
        var pages = [blankPage(size: first.size)]
        pages.append(contentsOf: rendered)
        if !pages.count.isMultiple(of: 2) {
            pages.append(blankPage(size: first.size))
        }
        return pages
    }

    private static func blankPage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in }
    }

    static func drawPage(
        project: AlbumProject,
        page: AlbumPage,
        images: [UUID: UIImage],
        fullBounds: CGRect,
        trimBounds: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        drawBackground(
            project: project,
            page: page,
            bounds: fullBounds,
            context: context
        )
        drawDecorations(
            project: project,
            page: page,
            bounds: trimBounds,
            context: context
        )
        drawLayoutBackground(
            project: project,
            page: page,
            bounds: trimBounds,
            context: context
        )

        for slot in page.slots.sorted(by: { $0.zIndex < $1.zIndex }) {
            guard let assetID = slot.assetID,
                  let image = images[assetID] else { continue }
            let asset = project.assets.first { $0.id == assetID }
            var frame = slot.frame.rect(in: trimBounds)
            frame = expandedForBleed(frame, normalized: slot.frame, full: fullBounds, trim: trimBounds)
            draw(
                image: image,
                in: frame,
                fit: slot.fit,
                rotation: slot.rotation,
                contentScale: slot.resolvedContentScale,
                contentOffsetX: slot.resolvedContentOffsetX,
                contentOffsetY: slot.resolvedContentOffsetY,
                cornerRadius: CGFloat(slot.cornerRadius) * min(trimBounds.width, trimBounds.height),
                drawsPaper: asset?.kind != .work && slot.fit == .fit,
                drawsBorder: asset?.kind != .work,
                context: context
            )
        }

        drawLayoutForeground(
            project: project,
            page: page,
            bounds: trimBounds,
            context: context
        )

        for block in page.textBlocks where !block.text.isEmpty {
            drawText(
                block,
                project: project,
                page: page,
                bounds: trimBounds,
                context: context
            )
        }
        context.restoreGState()
    }

    private static func drawBackground(
        project: AlbumProject,
        page: AlbumPage,
        bounds: CGRect,
        context: CGContext
    ) {
        drawGradient(
            colors: AlbumPageAppearance.backgroundStops(project: project, page: page),
            bounds: bounds,
            context: context
        )
    }

    private static func drawGradient(
        colors: [UIColor],
        bounds: CGRect,
        context: CGContext
    ) {
        let values = (colors.isEmpty ? [UIColor.systemGray] : colors).map(\.cgColor)
        let locations = values.indices.map { CGFloat($0) / CGFloat(max(1, values.count - 1)) }
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: values as CFArray,
            locations: locations
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.minX, y: bounds.minY),
            end: CGPoint(x: bounds.maxX, y: bounds.maxY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private static func drawDecorations(
        project: AlbumProject,
        page: AlbumPage,
        bounds: CGRect,
        context: CGContext
    ) {
        let unit = min(bounds.width, bounds.height)
        let colors = resolvedColors(project.palette)
        switch project.resolvedDesignStyle {
        case .editorialLetter:
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.18).cgColor)
            context.setLineWidth(max(0.6, unit * 0.0012))
            context.move(to: CGPoint(x: bounds.minX + unit * 0.045, y: bounds.minY + unit * 0.055))
            context.addLine(to: CGPoint(x: bounds.minX + unit * 0.16, y: bounds.minY + unit * 0.055))
            context.strokePath()
        case .coastPostcard:
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.13).cgColor)
            context.setLineWidth(max(0.7, unit * 0.0012))
            context.setLineDash(phase: 0, lengths: [unit * 0.008, unit * 0.006])
            context.strokeEllipse(in: CGRect(
                x: bounds.maxX - unit * 0.16,
                y: bounds.minY + unit * 0.025,
                width: unit * 0.11,
                height: unit * 0.11
            ))
            context.setLineDash(phase: 0, lengths: [])
            for index in 0..<3 {
                let y = bounds.minY + unit * (0.055 + CGFloat(index) * 0.018)
                context.move(to: CGPoint(x: bounds.maxX - unit * 0.28, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX - unit * 0.17, y: y))
            }
            context.strokePath()
        case .filmDiary:
            context.setFillColor(UIColor.black.withAlphaComponent(0.16).cgColor)
            for index in 0..<9 {
                context.fill(CGRect(
                    x: bounds.minX + unit * (0.08 + CGFloat(index) * 0.075),
                    y: bounds.maxY - unit * 0.045,
                    width: unit * 0.035,
                    height: unit * 0.010
                ))
            }
        case .warmNeutral:
            guard page.role == .content else { return }
            for (index, color) in colors.prefix(3).enumerated() {
                let diameter = unit * (0.025 + CGFloat(index) * 0.008)
                let circle = CGRect(
                    x: bounds.maxX - unit * (0.08 + CGFloat(index) * 0.036),
                    y: bounds.minY + unit * 0.055,
                    width: diameter,
                    height: diameter
                )
                context.setFillColor(color.withAlphaComponent(0.30).cgColor)
                context.fillEllipse(in: circle)
            }
        case .softArch:
            guard let color = colors.last else { return }
            context.setFillColor(color.withAlphaComponent(0.15).cgColor)
            let rect = CGRect(
                x: bounds.maxX - unit * 0.31,
                y: bounds.minY - unit * 0.05,
                width: unit * 0.28,
                height: unit * 0.20
            )
            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: unit * 0.12).cgPath)
            context.fillPath()
        case .sundayTable, .freeCollage:
            context.saveGState()
            context.translateBy(x: bounds.minX + unit * 0.14, y: bounds.minY + unit * 0.08)
            context.rotate(by: -7 * .pi / 180)
            context.setFillColor((colors.first ?? .systemGray).withAlphaComponent(0.17).cgColor)
            context.fill(CGRect(x: -unit * 0.075, y: -unit * 0.010, width: unit * 0.15, height: unit * 0.020))
            context.restoreGState()
        case .littleUniverse:
            guard page.role == .content else { return }
            for index in 0..<4 {
                let diameter = unit * (index.isMultiple(of: 2) ? 0.018 : 0.010)
                let circle = CGRect(
                    x: bounds.minX + unit * (0.05 + CGFloat(index) * 0.035),
                    y: bounds.maxY - unit * (0.075 + CGFloat(index % 2) * 0.02),
                    width: diameter,
                    height: diameter
                )
                context.setFillColor(colors[index % colors.count].withAlphaComponent(0.52).cgColor)
                context.fillEllipse(in: circle)
            }
        case .rainbowPlay:
            for index in 0..<3 {
                context.setStrokeColor(colors[index % colors.count].withAlphaComponent(0.34).cgColor)
                context.setLineWidth(max(2, unit * 0.010))
                context.addArc(
                    center: CGPoint(x: bounds.maxX - unit * 0.10, y: bounds.minY + unit * 0.08),
                    radius: unit * (0.07 + CGFloat(index) * 0.025),
                    startAngle: .pi,
                    endAngle: 0,
                    clockwise: false
                )
                context.strokePath()
            }
        case .growthNotes:
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.14).cgColor)
            context.setLineWidth(max(0.6, unit * 0.001))
            for index in 0..<8 {
                let y = bounds.minY + unit * (0.25 + CGFloat(index) * 0.06)
                context.move(to: CGPoint(x: bounds.minX + unit * 0.02, y: y))
                context.addLine(to: CGPoint(
                    x: bounds.minX + unit * (index.isMultiple(of: 2) ? 0.075 : 0.055),
                    y: y
                ))
            }
            context.strokePath()
        case .quietCompanion, .playfulPaws:
            guard page.role == .content else { return }
            let pawColor = project.resolvedDesignStyle == .playfulPaws
                ? (colors.first ?? UIColor.black)
                : UIColor.black
            context.setFillColor(pawColor.withAlphaComponent(
                project.resolvedDesignStyle == .playfulPaws ? 0.22 : 0.08
            ).cgColor)
            let base = CGPoint(x: bounds.maxX - unit * 0.10, y: bounds.minY + unit * 0.075)
            context.fillEllipse(in: CGRect(x: base.x, y: base.y, width: unit * 0.028, height: unit * 0.023))
            for angle in stride(from: -1.0, through: 1.0, by: 0.66) {
                context.fillEllipse(in: CGRect(
                    x: base.x + unit * (0.012 + angle * 0.019),
                    y: base.y - unit * 0.025,
                    width: unit * 0.012,
                    height: unit * 0.014
                ))
            }
        case .trailJournal:
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.13).cgColor)
            context.setLineWidth(max(0.7, unit * 0.0012))
            context.setLineDash(phase: 0, lengths: [unit * 0.008, unit * 0.008])
            context.move(to: CGPoint(x: bounds.minX + unit * 0.07, y: bounds.maxY - unit * 0.09))
            context.addCurve(
                to: CGPoint(x: bounds.minX + unit * 0.40, y: bounds.maxY - unit * 0.14),
                control1: CGPoint(x: bounds.minX + unit * 0.16, y: bounds.maxY - unit * 0.18),
                control2: CGPoint(x: bounds.minX + unit * 0.31, y: bounds.maxY - unit * 0.04)
            )
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        case .studioGrid:
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.08).cgColor)
            context.setLineWidth(max(0.5, unit * 0.0008))
            context.move(to: CGPoint(x: bounds.minX + unit * 0.07, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.minX + unit * 0.07, y: bounds.maxY))
            context.move(to: CGPoint(x: bounds.minX, y: bounds.minY + unit * 0.07))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + unit * 0.07))
            context.strokePath()
        case .cleanCanvas:
            break
        }
    }

    private static func drawLayoutBackground(
        project: AlbumProject,
        page: AlbumPage,
        bounds: CGRect,
        context: CGContext
    ) {
        let unit = min(bounds.width, bounds.height)
        let accent = resolvedColors(project.palette).first ?? UIColor.systemBlue
        context.saveGState()
        switch page.layout {
        case .cinematicSea:
            context.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
            for index in 0..<5 {
                context.fillEllipse(in: CGRect(
                    x: bounds.midX - unit * 0.003,
                    y: bounds.minY + unit * (0.09 + CGFloat(index) * 0.018),
                    width: unit * 0.006,
                    height: unit * 0.006
                ))
            }
        case .verticalTravelogue:
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            context.setLineWidth(max(0.5, unit * 0.001))
            for index in 0..<11 {
                context.strokeEllipse(in: CGRect(
                    x: bounds.minX + unit * (0.19 + CGFloat(index) * 0.035),
                    y: bounds.minY + unit * 0.018,
                    width: unit * 0.012,
                    height: unit * 0.012
                ))
            }
        case .postcardScrapbook:
            context.setFillColor(accent.withAlphaComponent(0.15).cgColor)
            context.fill(bounds)
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.72).cgColor)
            context.setLineWidth(max(1.2, unit * 0.004))
            context.setLineDash(phase: 0, lengths: [unit * 0.012, unit * 0.012])
            context.move(to: CGPoint(x: bounds.minX + bounds.width * 0.08, y: bounds.minY + bounds.height * 0.82))
            context.addCurve(
                to: CGPoint(x: bounds.minX + bounds.width * 0.90, y: bounds.minY + bounds.height * 0.22),
                control1: CGPoint(x: bounds.minX + bounds.width * 0.32, y: bounds.minY + bounds.height * 0.60),
                control2: CGPoint(x: bounds.minX + bounds.width * 0.55, y: bounds.minY + bounds.height * 0.38)
            )
            context.strokePath()
        case .tornPaperJourney:
            context.setFillColor(UIColor.white.withAlphaComponent(0.72).cgColor)
            context.beginPath()
            context.move(to: CGPoint(x: bounds.minX + bounds.width * 0.35, y: bounds.minY))
            for step in 0...14 {
                let y = bounds.minY + bounds.height * CGFloat(step) / 14
                let x = bounds.minX + bounds.width * (0.37 + (step.isMultiple(of: 2) ? 0.018 : -0.012))
                context.addLine(to: CGPoint(x: x, y: y))
            }
            context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            context.closePath()
            context.fillPath()
        case .colorAtlas:
            context.setLineWidth(max(0.5, unit * 0.001))
            for index in 1..<5 {
                context.setStrokeColor(accent.withAlphaComponent(0.10).cgColor)
                let x = bounds.minX + bounds.width * CGFloat(index) / 5
                context.move(to: CGPoint(x: x, y: bounds.minY))
                context.addLine(to: CGPoint(x: x, y: bounds.maxY))
                context.strokePath()
                context.setStrokeColor(UIColor.black.withAlphaComponent(0.06).cgColor)
                let y = bounds.minY + bounds.height * CGFloat(index) / 5
                context.move(to: CGPoint(x: bounds.minX, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: y))
                context.strokePath()
            }
        case .clippedMemoir:
            context.saveGState()
            context.translateBy(x: bounds.minX + bounds.width * 0.27, y: bounds.midY)
            context.rotate(by: -2 * .pi / 180)
            context.setFillColor(UIColor.white.withAlphaComponent(0.58).cgColor)
            context.fill(CGRect(
                x: -bounds.width * 0.21,
                y: -bounds.height * 0.38,
                width: bounds.width * 0.42,
                height: bounds.height * 0.76
            ))
            context.restoreGState()
        case .galleryWindow:
            context.setFillColor(accent.withAlphaComponent(0.88).cgColor)
            context.fill(bounds)
            context.setFillColor(UIColor.black.withAlphaComponent(0.82).cgColor)
            context.fill(CGRect(x: bounds.midX - bounds.width * 0.0175, y: bounds.minY, width: bounds.width * 0.035, height: bounds.height))
            context.fill(CGRect(x: bounds.minX, y: bounds.minY + bounds.height * 0.0625, width: bounds.width, height: bounds.height * 0.035))
            context.fill(CGRect(x: bounds.minX, y: bounds.minY + bounds.height * 0.8425, width: bounds.width, height: bounds.height * 0.035))
        default:
            break
        }
        context.restoreGState()
    }

    private static func drawLayoutForeground(
        project: AlbumProject,
        page: AlbumPage,
        bounds: CGRect,
        context: CGContext
    ) {
        let unit = min(bounds.width, bounds.height)
        context.saveGState()
        switch page.layout {
        case .oceanPoster:
            context.setFillColor(UIColor.white.withAlphaComponent(0.78).cgColor)
            context.fill(CGRect(
                x: bounds.minX + bounds.width * 0.04,
                y: bounds.minY + bounds.height * 0.465,
                width: bounds.width * 0.34,
                height: bounds.height * 0.11
            ))
        case .postcardScrapbook:
            for (index, point) in [
                CGPoint(x: 0.08, y: 0.18), CGPoint(x: 0.18, y: 0.78),
                CGPoint(x: 0.87, y: 0.15), CGPoint(x: 0.92, y: 0.72),
                CGPoint(x: 0.52, y: 0.90)
            ].enumerated() {
                let diameter = unit * (index.isMultiple(of: 2) ? 0.038 : 0.023)
                context.setFillColor(UIColor.white.withAlphaComponent(index.isMultiple(of: 2) ? 0.90 : 0.64).cgColor)
                context.fillEllipse(in: CGRect(
                    x: bounds.minX + bounds.width * point.x - diameter / 2,
                    y: bounds.minY + bounds.height * point.y - diameter / 2,
                    width: diameter,
                    height: diameter
                ))
            }
        case .tornPaperJourney, .clippedMemoir:
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.34).cgColor)
            context.setLineWidth(max(1, unit * 0.004))
            let center = page.layout == .tornPaperJourney
                ? CGPoint(x: bounds.minX + bounds.width * 0.64, y: bounds.minY + bounds.height * 0.10)
                : CGPoint(x: bounds.minX + bounds.width * 0.43, y: bounds.minY + bounds.height * 0.08)
            let clip = UIBezierPath(roundedRect: CGRect(
                x: center.x - unit * 0.018,
                y: center.y - unit * 0.045,
                width: unit * 0.036,
                height: unit * 0.09
            ), cornerRadius: unit * 0.018)
            context.addPath(clip.cgPath)
            context.strokePath()
        case .galleryWindow:
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.80).cgColor)
            context.setLineWidth(max(2, unit * 0.012))
            for x in [0.06, 0.54] {
                context.stroke(CGRect(
                    x: bounds.minX + bounds.width * x,
                    y: bounds.minY + bounds.height * 0.105,
                    width: bounds.width * 0.40,
                    height: bounds.height * 0.73
                ))
            }
        default:
            break
        }
        context.restoreGState()
    }

    private static func draw(
        image: UIImage,
        in frame: CGRect,
        fit: AlbumImageFit,
        rotation: Double,
        contentScale: Double,
        contentOffsetX: Double,
        contentOffsetY: Double,
        cornerRadius: CGFloat,
        drawsPaper: Bool,
        drawsBorder: Bool,
        context: CGContext
    ) {
        context.saveGState()
        context.translateBy(x: frame.midX, y: frame.midY)
        context.rotate(by: CGFloat(rotation * .pi / 180))
        let local = CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height)
        let path = UIBezierPath(roundedRect: local, cornerRadius: cornerRadius)
        path.addClip()
        if drawsPaper {
            context.setFillColor(UIColor.white.cgColor)
            context.fill(local)
        }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            context.restoreGState()
            return
        }
        let baseScale = fit == .fill
            ? max(local.width / imageSize.width, local.height / imageSize.height)
            : min(local.width / imageSize.width, local.height / imageSize.height)
        let scale = baseScale * CGFloat(max(1, min(6, contentScale)))
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let maximumX = max(0, (drawSize.width - local.width) / 2)
        let maximumY = max(0, (drawSize.height - local.height) / 2)
        let offset = CGPoint(
            x: max(-maximumX, min(maximumX, CGFloat(contentOffsetX) * local.width)),
            y: max(-maximumY, min(maximumY, CGFloat(contentOffsetY) * local.height))
        )
        image.draw(in: CGRect(
            x: local.midX - drawSize.width / 2 + offset.x,
            y: local.midY - drawSize.height / 2 + offset.y,
            width: drawSize.width,
            height: drawSize.height
        ))
        context.restoreGState()

        if drawsBorder {
            context.saveGState()
            context.translateBy(x: frame.midX, y: frame.midY)
            context.rotate(by: CGFloat(rotation * .pi / 180))
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.10).cgColor)
            context.setLineWidth(max(0.5, min(frame.width, frame.height) * 0.003))
            context.addPath(UIBezierPath(roundedRect: local, cornerRadius: cornerRadius).cgPath)
            context.strokePath()
            context.restoreGState()
        }
    }

    private static func drawText(
        _ block: AlbumTextBlock,
        project: AlbumProject,
        page: AlbumPage,
        bounds: CGRect,
        context: CGContext
    ) {
        let frame = block.frame.rect(in: bounds)
        let attributedText = AlbumTypography.attributedString(
            for: block,
            project: project,
            page: page,
            bounds: bounds,
            frame: frame
        )
        AlbumTypography.draw(attributedText, in: frame)
    }

    private static func expandedForBleed(
        _ frame: CGRect,
        normalized: AlbumNormalizedRect,
        full: CGRect,
        trim: CGRect
    ) -> CGRect {
        var result = frame
        if normalized.x <= 0.001 { result.origin.x = full.minX; result.size.width += trim.minX - full.minX }
        if normalized.y <= 0.001 { result.origin.y = full.minY; result.size.height += trim.minY - full.minY }
        if normalized.x + normalized.width >= 0.999 { result.size.width = full.maxX - result.minX }
        if normalized.y + normalized.height >= 0.999 { result.size.height = full.maxY - result.minY }
        return result
    }

    private static func resolvedColors(_ colors: [AlbumColor]) -> [UIColor] {
        let source = colors.isEmpty ? AlbumColor.fallback : colors
        return source.map {
            UIColor(red: $0.red, green: $0.green, blue: $0.blue, alpha: 1)
        }
    }

}

enum AlbumExportService {
    private static let millimeterToPoint: CGFloat = 72 / 25.4

    static func export(
        project: AlbumProject,
        images: [UUID: UIImage],
        kind: AlbumPDFKind
    ) throws -> AlbumExportedFile {
        guard !project.pages.isEmpty else { throw AlbumExportError.noPages }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-album-export", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeTitle = project.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let suffix = kind == .printReady ? "印刷版" : "电子版"
        let url = directory
            .appendingPathComponent("\(safeTitle)-\(suffix)-\(Int(Date.now.timeIntervalSince1970))")
            .appendingPathExtension("pdf")

        switch kind {
        case .printReady:
            try writePrintPDF(project: project, images: images, to: url)
        case .digitalPages:
            try writeDigitalPagesPDF(project: project, images: images, to: url)
        }
        return AlbumExportedFile(url: url, kind: kind)
    }

    static func lowResolutionCount(project: AlbumProject) -> Int {
        let pagePixelWidth = project.format.millimeters.width / 25.4 * 300
        var lowAssets = Set<UUID>()
        for page in project.pages {
            for slot in page.slots {
                guard let assetID = slot.assetID,
                      let asset = project.assets.first(where: { $0.id == assetID }) else { continue }
                let requiredWidth = pagePixelWidth * slot.frame.width
                if Double(asset.pixelWidth) < requiredWidth * 0.72 {
                    lowAssets.insert(assetID)
                }
            }
        }
        return lowAssets.count
    }

    private static func writePrintPDF(
        project: AlbumProject,
        images: [UUID: UIImage],
        to url: URL
    ) throws {
        let bleed = 3 * millimeterToPoint
        let trimSize = CGSize(
            width: project.format.millimeters.width * millimeterToPoint,
            height: project.format.millimeters.height * millimeterToPoint
        )
        let fullBounds = CGRect(
            x: 0,
            y: 0,
            width: trimSize.width + bleed * 2,
            height: trimSize.height + bleed * 2
        )
        let trimBounds = CGRect(origin: CGPoint(x: bleed, y: bleed), size: trimSize)
        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = [
            kCGPDFContextTitle as String: project.title,
            kCGPDFContextCreator as String: "灵动照片 · 影像相簿"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: fullBounds, format: rendererFormat)
        do {
            try renderer.writePDF(to: url) { context in
                for page in project.pages {
                    context.beginPage()
                    AlbumPageRenderer.drawPage(
                        project: project,
                        page: page,
                        images: images,
                        fullBounds: fullBounds,
                        trimBounds: trimBounds,
                        context: context.cgContext
                    )
                }
            }
        } catch {
            throw AlbumExportError.renderFailed
        }
    }

    private static func writeDigitalPagesPDF(
        project: AlbumProject,
        images: [UUID: UIImage],
        to url: URL
    ) throws {
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: project.format.millimeters.width * millimeterToPoint,
            height: project.format.millimeters.height * millimeterToPoint
        )
        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = [
            kCGPDFContextTitle as String: project.title,
            kCGPDFContextCreator as String: "灵动照片 · 影像相簿"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: rendererFormat)
        do {
            try renderer.writePDF(to: url) { context in
                for page in project.pages {
                    context.beginPage()
                    AlbumPageRenderer.drawPage(
                        project: project,
                        page: page,
                        images: images,
                        fullBounds: pageBounds,
                        trimBounds: pageBounds,
                        context: context.cgContext
                    )
                }
            }
        } catch {
            throw AlbumExportError.renderFailed
        }
    }
}

@MainActor
enum AlbumSystemPrintPresenter {
    static func present(url: URL) {
        guard UIPrintInteractionController.isPrintingAvailable,
              UIPrintInteractionController.canPrint(url) else { return }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = url.deletingPathExtension().lastPathComponent
        info.outputType = .photo
        if let document = CGPDFDocument(url as CFURL),
           let firstPage = document.page(at: 1) {
            let mediaBox = firstPage.getBoxRect(.mediaBox)
            info.orientation = mediaBox.width > mediaBox.height ? .landscape : .portrait
        } else {
            info.orientation = .portrait
        }
        controller.printInfo = info
        controller.printingItem = url
        controller.showsNumberOfCopies = true
        controller.present(animated: true)
    }
}

struct AlbumDynamicBackdrop: View {
    let colors: [AlbumColor]
    var isAnimated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: isAnimated ? 1 / 24 : 60)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let resolved = colors.isEmpty ? AlbumColor.fallback : colors
            ZStack {
                Color(red: 0.075, green: 0.095, blue: 0.082)
                ForEach(Array(resolved.prefix(3).enumerated()), id: \.offset) { index, color in
                    Circle()
                        .fill(color.swiftUIColor.opacity(0.58 - Double(index) * 0.08))
                        .frame(width: 430, height: 430)
                        .blur(radius: 90)
                        .offset(
                            x: cos(time * (0.08 + Double(index) * 0.025) + Double(index)) * 150,
                            y: sin(time * (0.07 + Double(index) * 0.02) + Double(index) * 1.7) * 230
                        )
                }
                LinearGradient(
                    colors: [.black.opacity(0.06), .black.opacity(0.56)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

extension AlbumColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

private extension AlbumTextAlignment {
    var nsAlignment: NSTextAlignment {
        switch self {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }
}
