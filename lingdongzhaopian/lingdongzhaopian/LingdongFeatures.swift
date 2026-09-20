


import SwiftUI
import UIKit



enum FeaturePaletteSide: String, CaseIterable, Identifiable {
    case bottom
    case leading
    case trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottom: "下方".appLocalized
        case .leading: "左侧".appLocalized
        case .trailing: "右侧".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .bottom: "rectangle.bottomhalf.inset.filled"
        case .leading: "rectangle.leadinghalf.inset.filled"
        case .trailing: "rectangle.trailinghalf.inset.filled"
        }
    }
}

struct PaletteCardCanvas: View {
    let image: UIImage
    let palette: [RGBColor]
    let side: FeaturePaletteSide
    var bandRatio: Double = 0.295
    var percentages: [Double] = []
    var swatchOrder: [Int] = []
    var showHexValues = true
    var useLiteraryColorNames = false
    var usePoeticColorNames = false
    var showPalettePercentages = true
    var isExporting = false
    var onMoveSwatch: ((Int, Int) -> Void)? = nil
    var onBandRectChange: ((CGRect?) -> Void)? = nil

    @State private var liftedPosition: Int? = nil
    @GestureState private var dragTranslation: CGSize = .zero

    private var isInteractive: Bool { !isExporting && onMoveSwatch != nil }

    private var colors: [RGBColor] {
        Array((palette.isEmpty ? RGBColor.fallback : palette).prefix(5))
    }

    private var orderedIndices: [Int] {
        let count = colors.count
        var seen = Set<Int>()
        var order: [Int] = []
        for index in swatchOrder where (0..<count).contains(index) && seen.insert(index).inserted {
            order.append(index)
        }
        for index in 0..<count where !seen.contains(index) {
            order.append(index)
        }
        return order
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = FeatureArtworkLayout.palette(imageSize: image.size, side: side, bandRatio: bandRatio)
                .fitted(in: proxy.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: layout.photo.width, height: layout.photo.height)
                    .position(x: layout.photo.midX, y: layout.photo.midY)
                    .accessibilityLabel("完整照片")
                    .accessibilityIdentifier("feature.palettePhoto")
                if side == .bottom {
                    bandRow(width: layout.band.width, height: layout.band.height)
                        .position(x: layout.band.midX, y: layout.band.midY)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("feature.paletteBand")
                        .accessibilityHint(isInteractive ? "长按并拖动可调整色块顺序".appLocalized : "")
                } else {
                    bandColumn(width: layout.band.width, height: layout.band.height)
                        .position(x: layout.band.midX, y: layout.band.midY)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("feature.paletteBand")
                        .accessibilityHint(isInteractive ? "长按并拖动可调整色块顺序".appLocalized : "")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onGeometryChange(for: CGRect.self) { canvasProxy in
                canvasProxy.frame(in: .global)
            } action: { canvasRect in
                reportBandRect(CGRect(
                    x: canvasRect.minX + layout.band.minX,
                    y: canvasRect.minY + layout.band.minY,
                    width: layout.band.width,
                    height: layout.band.height
                ))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feature.paletteCard")
    }

    private func reportBandRect(_ rect: CGRect) {
        guard !isExporting, let onBandRectChange else { return }
        onBandRectChange(rect)
    }

    private func bandRow(width: CGFloat, height: CGFloat) -> some View {
        let slotLength = width / CGFloat(max(orderedIndices.count, 1))
        let hovered = hoveredPosition(slotLength: slotLength, movesVertically: false)
        return HStack(spacing: 0) {
            ForEach(Array(orderedIndices.enumerated()), id: \.element) { position, originalIndex in
                swatchView(
                    position: position,
                    originalIndex: originalIndex,
                    slotWidth: slotLength,
                    slotHeight: height,
                    verticalText: true,
                    isDropTarget: hovered == position
                )
            }
        }
        .frame(width: width, height: height)
    }

    private func bandColumn(width: CGFloat, height: CGFloat) -> some View {
        let slotLength = height / CGFloat(max(orderedIndices.count, 1))
        let hovered = hoveredPosition(slotLength: slotLength, movesVertically: true)
        return VStack(spacing: 0) {
            ForEach(Array(orderedIndices.enumerated()), id: \.element) { position, originalIndex in
                swatchView(
                    position: position,
                    originalIndex: originalIndex,
                    slotWidth: width,
                    slotHeight: slotLength,
                    verticalText: false,
                    isDropTarget: hovered == position
                )
            }
        }
        .frame(width: width, height: height)
    }

    private func hoveredPosition(slotLength: CGFloat, movesVertically: Bool) -> Int? {
        guard isInteractive, let lifted = liftedPosition else { return nil }
        let movement = movesVertically ? dragTranslation.height : dragTranslation.width
        let shift = Int((movement / max(slotLength, 1)).rounded())
        let target = min(max(lifted + shift, 0), orderedIndices.count - 1)
        return target == lifted ? nil : target
    }

    private func swatchView(
        position: Int,
        originalIndex: Int,
        slotWidth: CGFloat,
        slotHeight: CGFloat,
        verticalText: Bool,
        isDropTarget: Bool
    ) -> some View {
        let color = colors[originalIndex]
        let percent = percentages.indices.contains(originalIndex) ? percentages[originalIndex] : 0
        let isLifted = isInteractive && liftedPosition == position
        return ZStack {
            color.color
            swatchLabel(
                color: color,
                percent: percent,
                slotWidth: slotWidth,
                slotHeight: slotHeight,
                verticalText: verticalText
            )
        }
        .frame(width: slotWidth, height: slotHeight)
        .clipShape(isLifted
            ? AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            : AnyShape(Rectangle()))
        .overlay {
            if isDropTarget {
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
            }
        }
        .scaleEffect(isLifted ? 1.12 : 1)
        .shadow(color: .black.opacity(isLifted ? 0.32 : 0), radius: 12, y: 6)
        .offset(isLifted ? dragTranslation : .zero)
        .zIndex(isLifted ? 10 : (isDropTarget ? 1 : 0))
        .gesture(
            liftGesture(
                position: position,
                slotLength: verticalText ? slotWidth : slotHeight,
                movesVertically: !verticalText
            )
        )
    }

    private func liftGesture(position: Int, slotLength: CGFloat, movesVertically: Bool) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragTranslation) { value, state, _ in
                if case .second(true, let drag) = value {
                    state = drag?.translation ?? .zero
                } else {
                    state = .zero
                }
            }
            .onChanged { value in
                guard isInteractive, case .second(true, _) = value else { return }
                if liftedPosition != position {
                    liftedPosition = position
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            .onEnded { value in
                defer { liftedPosition = nil }
                guard isInteractive,
                      case .second(true, let drag) = value,
                      let drag else { return }
                let movement = movesVertically ? drag.translation.height : drag.translation.width
                let shift = Int((movement / max(slotLength, 1)).rounded())
                let target = min(max(position + shift, 0), orderedIndices.count - 1)
                guard target != position else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onMoveSwatch?(position, target)
            }
    }

    @ViewBuilder
    private func swatchLabel(
        color: RGBColor,
        percent: Double,
        slotWidth: CGFloat,
        slotHeight: CGFloat,
        verticalText: Bool
    ) -> some View {
        let baseSize = max(7, min(slotWidth, slotHeight) * 0.16)
        let showsLabel = showHexValues || useLiteraryColorNames || usePoeticColorNames
        let usesWords = useLiteraryColorNames || usePoeticColorNames
        VStack(spacing: 2) {
            if showsLabel {
                Text(swatchLabelText(for: color))
                    .font(.system(size: baseSize, weight: usesWords ? .semibold : .medium,
                                  design: usesWords ? .rounded : .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if showPalettePercentages {
                Text(String(format: "%.1f%%", percent))
                    .font(.system(size: max(6, baseSize * 0.82), weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(labelColor(for: color))
        .fixedSize()
        .rotationEffect(.degrees(verticalText ? -90 : 0))
    }

    private func swatchLabelText(for color: RGBColor) -> String {
        if usePoeticColorNames { return color.poeticEntry().localizedName }
        if useLiteraryColorNames { return color.literaryName }
        return color.hex
    }

    private func labelColor(for color: RGBColor) -> Color {
        color.luminance > 0.62 ? Color.black.opacity(0.55) : Color.white.opacity(0.85)
    }
}



enum SolarTermDates {
    static func day(termIndex: Int, year: Int) -> Int? {
        guard SolarTerm.allCases.indices.contains(termIndex) else { return nil }
        let term = SolarTerm.allCases[termIndex]
        guard let occurrence = SolarTermCalendar.occurrences(inGregorianYear: year)
            .first(where: { $0.term == term }) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SolarTermCalendar.chinaTimeZone
        return calendar.component(.day, from: occurrence.instant)
    }


    static func terms(year: Int, month: Int) -> [(day: Int, name: String)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SolarTermCalendar.chinaTimeZone
        return SolarTermCalendar.occurrences(inGregorianYear: year)
            .filter { calendar.component(.month, from: $0.instant) == month }
            .map { (calendar.component(.day, from: $0.instant), $0.term.localizedName) }
            .sorted { $0.0 < $1.0 }
    }
}

struct MonthlyCalendarCanvas: View {
    let image: UIImage
    let palette: [RGBColor]
    let captureDate: Date?
    let cityName: String?
    var showsLocation = true

    private var referenceDate: Date { captureDate ?? .now }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let photo = FeatureArtworkLayout.photoFrame(imageSize: image.size, in: size)
            let card = FeatureArtworkLayout.calendarFrame(in: photo)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: photo.width, height: photo.height)
                    .position(x: photo.midX, y: photo.midY)
                    .accessibilityLabel("完整照片")
                    .accessibilityIdentifier("feature.calendarPhoto")

                glassCard(width: card.width, height: card.height)
                    .position(x: card.midX, y: card.midY)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(referenceDate, format: .dateTime.year().month()))
                    .accessibilityValue(captureDate.map { DateFormatter.localizedString(from: $0, dateStyle: .long, timeStyle: .none) } ?? "")
                    .accessibilityIdentifier("feature.calendarPanel")
            }
            .frame(width: size.width, height: size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feature.monthlyCalendar")
    }



    @ViewBuilder
    private func glassCard(width: CGFloat, height: CGFloat) -> some View {
        let cornerRadius = width * 0.095
        ZStack {
            calendarBody(width: width * 0.86)
        }
        .frame(width: width, height: height)
        .paletteLiquidGlassPanel(
            colors: palette,
            cornerRadius: cornerRadius,
            lineWidth: max(1, width * 0.0045),
            shadowRadius: width * 0.05,
            shadowY: width * 0.024
        )
    }

    private func calendarBody(width: CGFloat) -> some View {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        let captureDay = captureDate == nil ? nil : components.day
        let terms = SolarTermDates.terms(year: year, month: month)
        let termByDay = Dictionary(uniqueKeysWithValues: terms.map { ($0.day, $0.name) })

        let activeTermName: String? = {
            if let captureDay {
                if let active = terms.last(where: { $0.day <= captureDay })?.name { return active }
            }
            return terms.first?.name
        }()

        return VStack(spacing: width * 0.032) {
            Text(monthTitle(month: month))
                .font(.system(size: width * 0.125, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 6, y: 2)

            HStack(spacing: width * 0.022) {
                if showsLocation, let cityName, !cityName.isEmpty {
                    Text(String(format: "拍摄于 %@".appLocalized, cityName))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .font(.system(size: width * 0.042, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.88))
                }
                if let activeTermName {
                    Text(verbatim: activeTermName)
                        .font(.system(size: width * 0.042, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.76))
                }
            }
            .shadow(color: .black.opacity(0.24), radius: 4, y: 1)
            .frame(height: width * 0.055)

            grid(width: width, year: year, month: month, captureDay: captureDay, termByDay: termByDay)
        }
        .frame(width: width)
    }

    private func monthTitle(month: Int) -> String {
        switch LexiconLanguage.current {
        case .english:
            let names = ["January", "February", "March", "April", "May", "June",
                         "July", "August", "September", "October", "November", "December"]
            return names[(month - 1) % 12]
        case .traditional:
            let names = ["一月", "二月", "三月", "四月", "五月", "六月",
                         "七月", "八月", "九月", "十月", "十一月", "十二月"]
            return names[(month - 1) % 12]
        case .simplified:
            let names = ["一月", "二月", "三月", "四月", "五月", "六月",
                         "七月", "八月", "九月", "十月", "十一月", "十二月"]
            return names[(month - 1) % 12]
        }
    }

    private func grid(width: CGFloat, year: Int, month: Int, captureDay: Int?, termByDay: [Int: String]) -> some View {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? referenceDate
        let dayCount = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let leadingBlanks = calendar.component(.weekday, from: firstOfMonth) - 1
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let cell = width / 7

        return VStack(spacing: cell * 0.16) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(symbols[index % symbols.count])
                        .font(.system(size: cell * 0.30, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                        .frame(width: cell)
                }
            }
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let dayNumber = row * 7 + column - leadingBlanks + 1
                        cellView(day: (dayNumber >= 1 && dayNumber <= dayCount) ? dayNumber : nil,
                                 isCapture: dayNumber == captureDay,
                                 term: termByDay[dayNumber],
                                 cell: cell)
                    }
                }
            }
        }
    }

    private func cellView(day: Int?, isCapture: Bool, term: String?, cell: CGFloat) -> some View {
        VStack(spacing: cell * 0.06) {
            ZStack {
                if isCapture {
                    Circle().stroke(Color.red.opacity(0.9), lineWidth: max(1, cell * 0.06))
                        .frame(width: cell * 0.72, height: cell * 0.72)
                }
                Text(day.map(String.init) ?? "")
                    .font(.system(size: cell * 0.34, weight: isCapture ? .semibold : .regular, design: .serif))
                    .foregroundStyle(.white.opacity(day == nil ? 0 : (isCapture ? 1 : 0.92)))
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
            }
            .frame(width: cell, height: cell * 0.78)

            Text(term ?? "")
                .font(.system(size: cell * 0.22, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.62))
                .shadow(color: .black.opacity(0.20), radius: 3, y: 1)
                .frame(height: cell * 0.26)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: cell)
    }
}

struct MonthlyCalendarSettingsSheet: View {
    @Binding var hidesLocation: Bool

    var body: some View {
        Form {
            Section {
                Toggle("不显示位置信息", isOn: $hidesLocation)
                    .accessibilityIdentifier("feature.calendarHideLocation")
            } footer: {
                Text("同时隐藏月历预览与导出作品中的位置，不更改原照片。")
            }
        }
        .formStyle(.grouped)
    }
}

struct PaletteCardSettingsSheet: View {
    @Binding var usePoeticColorNames: Bool
    @Binding var useLiteraryColorNames: Bool
    @Binding var showPalettePercentages: Bool

    var body: some View {
        Form {
            Section {
                Toggle("以二十四节气名称替换", isOn: $usePoeticColorNames)
                    .accessibilityIdentifier("feature.paletteCardPoeticNames")
            }
            Section {
                Toggle("用颜色名称替换颜色码", isOn: $useLiteraryColorNames)
                    .accessibilityIdentifier("feature.paletteCardLiteraryNames")
            } footer: {
                Text("将颜色代码替换为极具文学气息的自然命名。")
            }
            Section {
                Toggle("显示颜色占比", isOn: $showPalettePercentages)
                    .accessibilityIdentifier("feature.paletteCardPercentages")
            } footer: {
                Text("关闭后，琉璃色盘将不再显示各颜色所占百分比。")
            }
            Section {
            } footer: {
                Text("长按色块可拖动调整排列顺序，预览与导出保持一致。")
            }
        }
        .formStyle(.grouped)
    }
}



struct FeatureModeControls: View {
    let mode: CreationMode
    @Binding var paletteSide: FeaturePaletteSide
    @Binding var paletteBandRatio: Double
    let calendarCity: String?
    let isResolvingCity: Bool
    var locationMessage: String? = nil
    var hidesCalendarLocation = false
    var onCalendarSettings: () -> Void = {}
    var onPaletteCardSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            switch mode {
            case .paletteCard:
                HStack(spacing: 8) {
                    ForEach(FeaturePaletteSide.allCases) { side in
                        sideButton(side)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.62))
                        .frame(width: 18)
                    Slider(value: $paletteBandRatio, in: 0.12...0.45)
                        .accessibilityLabel("色条比例".appLocalized)
                        .accessibilityIdentifier("feature.bandRatio")
                    Text(String(format: "%.0f%%", paletteBandRatio * 100))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.72))
                        .frame(width: 42, alignment: .trailing)
                }
                .frame(height: 43)

                Button(action: onPaletteCardSettings) {
                    Label("灵动色卡设定", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feature.paletteCardSettings")
            case .monthlyCalendar:
                HStack(spacing: 8) {
                    Image(systemName: hidesCalendarLocation ? "location.slash" : "location.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.62))
                    if hidesCalendarLocation {
                        Text("位置信息已隐藏")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    } else if isResolvingCity {
                        Text("识别城市中…".appLocalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if let calendarCity {
                        Text(String(format: "拍摄于 %@".appLocalized, calendarCity))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    } else {
                        Text(locationMessage ?? "无定位，仅显示日期".appLocalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(height: 43)
                .background(Capsule().fill(.primary.opacity(0.05)))
                .contentShape(Capsule())
                Button(action: onCalendarSettings) {
                    Label("灵动月历设定", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feature.calendarSettings")
            default:
                EmptyView()
            }
        }
        .padding(8)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            interactive: true,
            variant: .clear
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feature.controls")
    }

    private func sideButton(_ side: FeaturePaletteSide) -> some View {
        Button {

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { paletteSide = side }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: side.symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(side.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background {
                if paletteSide == side {
                    Capsule().fill(.primary.opacity(0.12))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .accessibilityIdentifier("feature.paletteSide.\(side.rawValue)")
        .accessibilityLabel(
            "\(side.title)\(paletteSide == side ? "，当前选择".appLocalized : "")"
        )
    }
}

struct PaletteSwapSpotlight: View {
    let bandRect: CGRect
    let side: FeaturePaletteSide
    let tint: Color
    let foreground: Color
    let action: () -> Void

    private let calloutWidth: CGFloat = 236
    private let bubbleHeight: CGFloat = 58
    private let confirmWidth: CGFloat = 124
    private let confirmHeight: CGFloat = 40

    private var holeRect: CGRect { bandRect.insetBy(dx: -5, dy: -5) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let hole = holeRect
            let scrim = SpotlightScrimShape(hole: hole, cornerRadius: 14)
            ZStack {
                scrim
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .contentShape(scrim, eoFill: true)
                    .onTapGesture(perform: action)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.92), lineWidth: 2)
                    .frame(width: hole.width, height: hole.height)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                    .position(x: hole.midX, y: hole.midY)
                    .allowsHitTesting(false)

                bubble
                    .frame(width: calloutWidth)
                    .position(bubblePosition(in: size))

                confirmButton
                    .frame(width: confirmWidth, height: confirmHeight)
                    .position(confirmPosition(in: size))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feature.paletteSwapSpotlight")
    }

    private var confirmButton: some View {
        Button(action: action) {
            Text("我知道了")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: confirmWidth, height: confirmHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
        .accessibilityIdentifier("feature.paletteSwapHintConfirm")
    }

    private var bubble: some View {
        let arrowEdge = SpotlightCalloutShape.ArrowEdge(side: side)
        let shape = SpotlightCalloutShape(arrowEdge: arrowEdge)
        return Text("长按色块可交替位置")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 14)
            .padding(.bottom, arrowEdge == .bottom ? 8 : 0)
            .padding(.leading, arrowEdge == .leading ? 8 : 0)
            .padding(.trailing, arrowEdge == .trailing ? 8 : 0)
            .frame(width: calloutWidth, height: bubbleHeight)
            .background {
                shape.fill(tint.opacity(0.18))
            }
            .liquidGlass(in: shape, interactive: false, variant: .clear)
    }

    private func bubblePosition(in size: CGSize) -> CGPoint {
        let hole = holeRect
        let halfWidth = calloutWidth / 2
        let halfHeight = bubbleHeight / 2
        switch side {
        case .bottom:
            let x = min(max(hole.midX, halfWidth + 10), size.width - halfWidth - 10)
            let y = max(hole.minY - 10 - halfHeight, halfHeight + 8)
            return CGPoint(x: x, y: y)
        case .leading:
            let x = min(hole.maxX + 12 + halfWidth, size.width - halfWidth - 10)
            let y = verticalBubbleY(for: hole, in: size)
            return CGPoint(x: x, y: y)
        case .trailing:
            let x = max(hole.minX - 12 - halfWidth, halfWidth + 10)
            let y = verticalBubbleY(for: hole, in: size)
            return CGPoint(x: x, y: y)
        }
    }

    private func confirmPosition(in size: CGSize) -> CGPoint {
        let hole = holeRect
        let halfWidth = confirmWidth / 2
        let halfHeight = confirmHeight / 2
        let x = min(max(hole.midX, halfWidth + 10), size.width - halfWidth - 10)
        switch side {
        case .bottom:
            let y = min(hole.maxY + 14 + halfHeight, size.height - halfHeight - 10)
            return CGPoint(x: x, y: y)
        case .leading, .trailing:
            let bubblePoint = bubblePosition(in: size)
            let y = min(
                bubblePoint.y + bubbleHeight / 2 + 12 + halfHeight,
                size.height - halfHeight - 10
            )
            return CGPoint(x: bubblePoint.x, y: y)
        }
    }

    private func verticalBubbleY(for hole: CGRect, in size: CGSize) -> CGFloat {
        let halfBubble = bubbleHeight / 2
        let requiredBelow = 12 + confirmHeight
        return min(
            max(hole.midY - requiredBelow / 2, halfBubble + 8),
            size.height - halfBubble - requiredBelow - 10
        )
    }
}

private struct SpotlightScrimShape: Shape {
    let hole: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: hole,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        return path
    }
}

private struct SpotlightCalloutShape: InsettableShape {
    enum ArrowEdge {
        case bottom
        case leading
        case trailing

        init(side: FeaturePaletteSide) {
            switch side {
            case .bottom: self = .bottom
            case .leading: self = .leading
            case .trailing: self = .trailing
            }
        }
    }

    let arrowEdge: ArrowEdge
    private var insetAmount: CGFloat = 0

    fileprivate init(arrowEdge: ArrowEdge) {
        self.arrowEdge = arrowEdge
    }

    func path(in rect: CGRect) -> Path {
        switch arrowEdge {
        case .bottom:
            let pointerHeight = max(4, 9 - insetAmount)
            let bodyRect = CGRect(
                x: rect.minX + insetAmount,
                y: rect.minY + insetAmount,
                width: max(0, rect.width - insetAmount * 2),
                height: max(0, rect.height - pointerHeight - insetAmount * 2)
            )
            let half = max(4, 8 - insetAmount)
            var path = Path(roundedRect: bodyRect, cornerRadius: min(18, bodyRect.height / 2))
            path.move(to: CGPoint(x: rect.midX - half, y: bodyRect.maxY - 1))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - insetAmount))
            path.addLine(to: CGPoint(x: rect.midX + half, y: bodyRect.maxY - 1))
            path.closeSubpath()
            return path
        case .leading:
            let pointerWidth = max(5, 9 - insetAmount)
            let bodyRect = CGRect(
                x: rect.minX + pointerWidth + insetAmount,
                y: rect.minY + insetAmount,
                width: max(0, rect.width - pointerWidth - insetAmount * 2),
                height: max(0, rect.height - insetAmount * 2)
            )
            let half = max(3, 6 - insetAmount * 0.5)
            var path = Path(roundedRect: bodyRect, cornerRadius: min(18, bodyRect.height / 2))
            path.move(to: CGPoint(x: bodyRect.minX + 1, y: bodyRect.midY - half))
            path.addLine(to: CGPoint(x: rect.minX + insetAmount, y: bodyRect.midY))
            path.addLine(to: CGPoint(x: bodyRect.minX + 1, y: bodyRect.midY + half))
            path.closeSubpath()
            return path
        case .trailing:
            let pointerWidth = max(5, 9 - insetAmount)
            let bodyRect = CGRect(
                x: rect.minX + insetAmount,
                y: rect.minY + insetAmount,
                width: max(0, rect.width - pointerWidth - insetAmount * 2),
                height: max(0, rect.height - insetAmount * 2)
            )
            let half = max(3, 6 - insetAmount * 0.5)
            var path = Path(roundedRect: bodyRect, cornerRadius: min(18, bodyRect.height / 2))
            path.move(to: CGPoint(x: bodyRect.maxX - 1, y: bodyRect.midY - half))
            path.addLine(to: CGPoint(x: rect.maxX - insetAmount, y: bodyRect.midY))
            path.addLine(to: CGPoint(x: bodyRect.maxX - 1, y: bodyRect.midY + half))
            path.closeSubpath()
            return path
        }
    }

    func inset(by amount: CGFloat) -> SpotlightCalloutShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
