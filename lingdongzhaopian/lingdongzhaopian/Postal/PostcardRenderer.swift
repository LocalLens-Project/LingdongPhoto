import UIKit

enum PostcardStyle: String, CaseIterable, Identifiable {
    case classic, message, instant, seasonal
    var id: String { rawValue }
    var requiresPro: Bool { self != .classic }
    var title: String {
        switch self {
        case .classic: "经典邮政".appLocalized
        case .message: "竖版寄语".appLocalized
        case .instant: "白边快照".appLocalized
        case .seasonal: "满版邮趣".appLocalized
        }
    }
    var size: CGSize {
        switch self {
        case .classic: CGSize(width: 1500, height: 1000)
        case .message, .seasonal: CGSize(width: 1000, height: 1500)
        case .instant: CGSize(width: 1200, height: 1440)
        }
    }
}

struct PostcardDraft: Equatable {
    var style: PostcardStyle = .classic
    var font: PostalFont = .original
    var postmarkFont: PostalFont = .original
    var message = "把这一刻，寄给想念的人。".appLocalized
    var date = ""
    var address = ""
    var title = "此刻".appLocalized
    var poem = "光影落在纸上，时光有了回响。".appLocalized
    var verticalText = "愿每一次抵达，都值得珍藏".appLocalized
    var snow = false
    var city = "旅途留念".appLocalized

    mutating func useMetadata(_ metadata: PhotoMetadata, city: PostalCity?) {
        date = metadata.captureDate.map(PostalDate.short) ?? "日期未记录".appLocalized
        self.city = city?.name ?? "旅途留念".appLocalized
        if let date = metadata.captureDate {
            let term = PostalSolarTerm.at(date)
            title = term.name.appLocalized; poem = term.poem.appLocalized
        } else {
            title = "此刻".appLocalized
            poem = "光影落在纸上，时光有了回响。".appLocalized
        }
    }
}

enum PostalDate {
    nonisolated static func short(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian); formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
    nonisolated static func chinese(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = .current
        formatter.calendar = Calendar(identifier: .gregorian); formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}


enum PostalSolarTerm {
    struct Term {
        let month: Int
        let day: Int
        let name: String
        let poem: String
    }
    static let terms: [Term] = [
        .init(month: 1, day: 5, name: "小寒", poem: "寒意渐深，仍有一束光为你停留。"),
        .init(month: 1, day: 20, name: "大寒", poem: "岁暮天寒，把温暖留在一纸之间。"),
        .init(month: 2, day: 4, name: "立春", poem: "风从远处来，带着新一年的绿意。"),
        .init(month: 2, day: 19, name: "雨水", poem: "一场细雨，让记忆有了清新的颜色。"),
        .init(month: 3, day: 6, name: "惊蛰", poem: "万物苏醒，光也悄悄推开了窗。"),
        .init(month: 3, day: 21, name: "春分", poem: "昼夜平分，把一半春光寄给你。"),
        .init(month: 4, day: 5, name: "清明", poem: "风清景明，念想沿着新绿生长。"),
        .init(month: 4, day: 20, name: "谷雨", poem: "雨落百谷，每一种颜色都在生长。"),
        .init(month: 5, day: 6, name: "立夏", poem: "夏日初长，让明亮的心事慢慢展开。"),
        .init(month: 5, day: 21, name: "小满", poem: "不必盈满，此刻的光影恰到好处。"),
        .init(month: 6, day: 6, name: "芒种", poem: "种下一个愿望，等时光替它着色。"),
        .init(month: 6, day: 21, name: "夏至", poem: "在最长的白昼里，收藏一瞬好时光。"),
        .init(month: 7, day: 7, name: "小暑", poem: "风穿过树荫，留下一片清凉的绿。"),
        .init(month: 7, day: 23, name: "大暑", poem: "盛夏浓烈，远方与日光一起闪亮。"),
        .init(month: 8, day: 8, name: "立秋", poem: "风开始转身，给夏天留一张纪念。"),
        .init(month: 8, day: 23, name: "处暑", poem: "暑意渐远，天空把颜色还给了秋天。"),
        .init(month: 9, day: 8, name: "白露", poem: "露从今夜白，思念在晨光里澄明。"),
        .init(month: 9, day: 23, name: "秋分", poem: "秋色平分，一半留给远方的你。"),
        .init(month: 10, day: 8, name: "寒露", poem: "露冷风轻，往事在暖色里停泊。"),
        .init(month: 10, day: 23, name: "霜降", poem: "霜染万物，把深秋的颜色封存。"),
        .init(month: 11, day: 7, name: "立冬", poem: "冬日开篇，愿纸上的光陪你取暖。"),
        .init(month: 11, day: 22, name: "小雪", poem: "轻雪尚浅，想念已经落满纸面。"),
        .init(month: 12, day: 7, name: "大雪", poem: "天地渐白，留一枚温暖的印记。"),
        .init(month: 12, day: 22, name: "冬至", poem: "长夜之后，每一天都多一寸光。")
    ]
    static func at(_ date: Date) -> Term {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let parts = calendar.dateComponents([.month, .day], from: date)
        let key = (parts.month ?? 1) * 100 + (parts.day ?? 1)
        return terms.last(where: { $0.month * 100 + $0.day <= key }) ?? terms[23]
    }
}

enum PostalDrawing {
    static func text(_ text: String, in rect: CGRect, size: CGFloat, color: UIColor,
                     font: UIFont? = nil, alignment: NSTextAlignment = .left, spacing: CGFloat = 4) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment; paragraph.lineBreakMode = .byWordWrapping; paragraph.lineSpacing = spacing
        let baseFont = font ?? UIFont.systemFont(ofSize: size)
        var fittedFont = baseFont
        var attributes: [NSAttributedString.Key: Any] = [
            .font: fittedFont, .foregroundColor: color, .paragraphStyle: paragraph
        ]
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        while fittedFont.pointSize > max(9, size * 0.55) {
            let bounds = (text as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                                        options: options, attributes: attributes, context: nil)
            if bounds.height <= rect.height { break }
            fittedFont = baseFont.withSize(fittedFont.pointSize - 1)
            attributes[.font] = fittedFont
        }
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState(); context?.clip(to: rect)
        (text as NSString).draw(with: rect, options: options, attributes: attributes, context: nil)
        context?.restoreGState()
    }
    static func line(_ a: CGPoint, _ b: CGPoint, color: UIColor, width: CGFloat = 1) {
        let path = UIBezierPath(); path.move(to: a); path.addLine(to: b)
        path.lineWidth = width; color.setStroke(); path.stroke()
    }
    static func postmark(in rect: CGRect, city: String, date: String, color: UIColor, font: PostalFont = .original) {
        let r = rect.width / 2, center = CGPoint(x: rect.midX, y: rect.midY)
        color.setStroke()
        for inset in [CGFloat(0), CGFloat(6)] {
            let circle = UIBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset))
            circle.lineWidth = 1.8; circle.stroke()
        }

        func arc(_ string: String, base: CGFloat, lower: Bool) {
            let letters = Array(string.prefix(14))
            guard !letters.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }

            let span = lower
                ? min(1.8, CGFloat(max(0, letters.count - 1)) * 17 / max(r - 20, 1))
                : min(1.8, CGFloat(letters.count) * 0.19)
            for (i, letter) in letters.enumerated() {
                let fraction = letters.count == 1 ? 0.5 : CGFloat(i) / CGFloat(letters.count - 1)
                let angle = base + (fraction - 0.5) * span * (lower ? -1 : 1)
                context.saveGState()
                context.translateBy(x: center.x + sin(angle) * (r - 20), y: center.y - cos(angle) * (r - 20))
                context.rotate(by: lower ? angle + .pi : angle)
                text(String(letter), in: CGRect(x: -10, y: -10, width: 20, height: 22),
                     size: 13, color: color, font: font.uiFont(size: 13), alignment: .center)
                context.restoreGState()
            }
        }
        arc(city, base: 0, lower: false)
        arc("灵动照片".appLocalized, base: .pi, lower: true)
        text(date, in: CGRect(x: rect.minX + 12, y: center.y - 10, width: rect.width - 24, height: 26),
             size: 11, color: color, font: font.uiFont(size: 11), alignment: .center)
        for d in [-18.0, 20.0] {
            line(CGPoint(x: rect.minX + 18, y: center.y + d), CGPoint(x: rect.maxX - 18, y: center.y + d), color: color)
        }
    }
    static func waves(in rect: CGRect, color: UIColor) {
        for row in 0..<4 {
            let path = UIBezierPath()
            for step in 0...80 {
                let x = rect.minX + rect.width * CGFloat(step) / 80
                let y = rect.minY + CGFloat(row) * 11 + sin(CGFloat(step) / 80 * .pi * 6) * 4
                if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            color.setStroke(); path.lineWidth = 1.2; path.stroke()
        }
    }
    static func handwriting(size: CGFloat) -> UIFont {
        for name in ["STXingkaiSC-Light", "STKaitiSC-Regular", "STKaitiTC-Regular", "STKaiti", "Kaiti SC",
                     "HannotateSC-W5", "HanziPenSC-W3", "STWeibeiSC-Regular", "STWeibei-SC-Bold"] {
            if let font = UIFont(name: name, size: size) { return font }
        }
        let base = UIFont.systemFont(ofSize: size, weight: .medium)
        return UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
    }
}

enum PostcardRenderer {
    static func render(photo: UIImage, stamp: UIImage?, draft: PostcardDraft,
                       tint: PostalTint, preview: Bool = false) -> UIImage {
        let output = draft.style.size
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let scale: CGFloat = preview ? 0.55 : 1
        let size = CGSize(width: output.width * scale, height: output.height * scale)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in

            let factor = min(output.width, output.height) / 600 * scale
            ctx.cgContext.scaleBy(x: factor, y: factor)
            ctx.cgContext.setBlendMode(.normal)
            let w = output.width / (min(output.width, output.height) / 600)
            let h = output.height / (min(output.width, output.height) / 600)
            let ink = tint.uiColor.mixedWith(.black, fraction: 0.68)
            let paper = tint.uiColor.mixedWith(.white, fraction: 0.96)
            paper.setFill(); ctx.cgContext.fill(CGRect(x: 0, y: 0, width: w, height: h))
            func photoRect(_ rect: CGRect) {
                ctx.cgContext.saveGState(); ctx.cgContext.clip(to: rect)
                StampRenderer.drawCover(photo, in: rect); ctx.cgContext.restoreGState()
            }
            func text(_ string: String, _ rect: CGRect, _ size: CGFloat = 18, _ handwritten: Bool = false) {
                PostalDrawing.text(string, in: rect, size: size, color: ink,
                    font: draft.font.uiFont(size: size, handwritten: handwritten))
            }
            func attachStamp(_ rect: CGRect) {
                if let stamp {
                    let factor = min(rect.width / stamp.size.width, rect.height / stamp.size.height)
                    stamp.draw(in: CGRect(x: rect.midX - stamp.size.width * factor / 2, y: rect.midY - stamp.size.height * factor / 2,
                                          width: stamp.size.width * factor, height: stamp.size.height * factor))
                    PostalDrawing.postmark(in: CGRect(x: rect.minX - 54, y: rect.maxY - 60, width: 115, height: 115),
                                           city: draft.city, date: draft.date, color: ink.withAlphaComponent(0.8), font: draft.postmarkFont)
                } else {
                    let path = UIBezierPath(rect: rect); path.setLineDash([5, 5], count: 2, phase: 0)
                    ink.withAlphaComponent(0.35).setStroke(); path.stroke()
                    PostalDrawing.text("贴票处".appLocalized, in: rect.insetBy(dx: 8, dy: rect.height / 2 - 8), size: 13,
                                       color: ink.withAlphaComponent(0.5), alignment: .center)
                }
            }
            switch draft.style {
            case .classic:
                photoRect(CGRect(x: 24, y: 24, width: 410, height: h - 48))
                PostalDrawing.line(CGPoint(x: 460, y: 28), CGPoint(x: 460, y: h - 28), color: ink.withAlphaComponent(0.25))
                text("POST CARD", CGRect(x: 490, y: 34, width: 235, height: 35), 27)
                text("明 信 片".appLocalized, CGRect(x: 491, y: 72, width: 180, height: 25), 13)
                attachStamp(CGRect(x: 768, y: 30, width: 100, height: 130))
                text(draft.message, CGRect(x: 490, y: 202, width: 360, height: 136), 23, true)
                text(draft.address, CGRect(x: 495, y: 360, width: 348, height: 146), 18)
                for y in stride(from: CGFloat(390), through: 510, by: 40) {
                    PostalDrawing.line(CGPoint(x: 490, y: y), CGPoint(x: 850, y: y), color: ink.withAlphaComponent(0.25))
                }
                text(draft.date, CGRect(x: 490, y: 546, width: 345, height: 24), 14)
            case .message:
                photoRect(CGRect(x: 22, y: 22, width: w - 44, height: 520))
                text(draft.message, CGRect(x: 38, y: 580, width: 365, height: 162), 26, true)
                text(draft.address, CGRect(x: 38, y: 762, width: 360, height: 54), 15)
                text(draft.date, CGRect(x: 38, y: 848, width: 300, height: 24), 15)
                attachStamp(CGRect(x: 455, y: 603, width: 106, height: 142))
            case .instant:
                photoRect(CGRect(x: 35, y: 35, width: w - 70, height: 487))
                text(draft.message.replacingOccurrences(of: "\n", with: " "), CGRect(x: 42, y: 553, width: 360, height: 66), 25, true)
                text(draft.address, CGRect(x: 42, y: 625, width: 340, height: 35), 13)
                text(draft.date, CGRect(x: 42, y: 672, width: 330, height: 24), 13)
                attachStamp(CGRect(x: 461, y: 552, width: 93, height: 124))
            case .seasonal:
                photoRect(CGRect(x: 0, y: 0, width: w, height: h))

                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                    paper.withAlphaComponent(0.95).cgColor, paper.withAlphaComponent(0.5).cgColor,
                    paper.withAlphaComponent(0.04).cgColor, paper.withAlphaComponent(0.85).cgColor
                ] as CFArray, locations: [0, 0.27, 0.58, 1])!
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
                text(String(draft.title.prefix(8)), CGRect(x: 36, y: 40, width: 150, height: 220), 72, true)
                text(draft.poem, CGRect(x: 214, y: 53, width: 282, height: 120), 19, true)
                paper.withAlphaComponent(0.66).setFill(); ctx.cgContext.fill(CGRect(x: 535, y: 200, width: 36, height: 475))
                for (i, char) in draft.verticalText.prefix(20).enumerated() {
                    text(String(char), CGRect(x: 543, y: 210 + CGFloat(i) * 22, width: 24, height: 24), 16, true)
                }
                attachStamp(CGRect(x: 377, y: 420, width: 138, height: 184))
                text(draft.message, CGRect(x: 36, y: 732, width: 464, height: 94), 23, true)
                text(draft.address, CGRect(x: 36, y: 834, width: 464, height: 26), 14)
                text(draft.date, CGRect(x: 36, y: 868, width: 464, height: 22), 13)

                for i in 0..<2200 {
                    let x = CGFloat((i * 137 + 29) % 600), y = CGFloat((i * 271 + 43) % 900)
                    ink.withAlphaComponent(0.035).setFill(); ctx.cgContext.fill(CGRect(x: x, y: y, width: 0.7, height: 1.4))
                }
                if draft.snow {
                    for i in 0..<65 {
                        let x = CGFloat((i * 173 + 21) % 600), y = CGFloat((i * 277 + 71) % 900)
                        UIColor.white.withAlphaComponent(0.6).setFill()
                        UIBezierPath(ovalIn: CGRect(x: x, y: y, width: CGFloat(i % 4 + 2), height: CGFloat(i % 4 + 2))).fill()
                    }
                }
            }
        }
    }
}

private extension UIColor {
    func mixedWith(_ other: UIColor, fraction: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a); other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r * (1-fraction) + r2 * fraction, green: g * (1-fraction) + g2 * fraction,
                       blue: b * (1-fraction) + b2 * fraction, alpha: 1)
    }
}
