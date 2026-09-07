import UIKit

struct StampLettering: Equatable {
    var showsTitle = false
    var showsDate = false
    var title = "此刻".appLocalized
    var date = ""
    var font: PostalFont = .wenkai
    var size: Double = 1
    var atTop = false
    var inset: Double = 0.06
    var darkInk = false
    var isEnabled: Bool { showsTitle || showsDate }


    func draw(in window: CGRect) {
        let titleText = showsTitle ? String(title.prefix(20)).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let dateText = showsDate ? String(date.prefix(24)).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        guard !titleText.isEmpty || !dateText.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let unit = min(window.width, window.height)
        let titleSize = unit * 0.105 * min(1.5, max(0.6, size))
        let dateSize = titleSize * 0.48
        let titleHeight = titleText.isEmpty ? 0 : titleSize * 1.4
        let dateHeight = dateText.isEmpty ? 0 : dateSize * 1.65
        let gap: CGFloat = titleText.isEmpty || dateText.isEmpty ? 0 : unit * 0.015
        let height = titleHeight + gap + dateHeight
        let margin = unit * min(0.35, max(0.03, inset))
        let y = atTop ? window.minY + margin : window.maxY - margin - height
        let rect = CGRect(x: window.minX + unit * 0.07, y: y, width: window.width - unit * 0.14, height: height)
        context.saveGState()
        context.clip(to: window)
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: unit * 0.009,
                          color: (darkInk ? UIColor.white : UIColor.black).withAlphaComponent(0.7).cgColor)
        let ink: UIColor = darkInk ? .black : .white
        func line(_ text: String, y: CGFloat, height: CGFloat, size: CGFloat) {
            guard !text.isEmpty else { return }
            let text = text.replacingOccurrences(of: "\n", with: " ")
            let base = font.uiFont(size: size)
            let width = (text as NSString).size(withAttributes: [.font: base]).width
            let fitted = base.withSize(size * min(1, rect.width / max(1, width)))
            PostalDrawing.text(text, in: CGRect(x: rect.minX, y: y, width: rect.width, height: height),
                               size: fitted.pointSize, color: ink, font: fitted, alignment: .center, spacing: 0)
        }
        line(titleText, y: y, height: titleHeight, size: titleSize)
        line(dateText, y: y + titleHeight + gap, height: dateHeight, size: dateSize)
        context.restoreGState()
    }
}
