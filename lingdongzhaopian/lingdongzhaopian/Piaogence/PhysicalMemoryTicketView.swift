import SwiftUI
import UIKit

struct PhysicalMemoryTicketView: View {
    let ticket: TicketStub

    private var type: PhysicalTicketType { ticket.physicalTicketType ?? .other }
    private var colors: [PiaogenceRGBColor] {
        ticket.palette.isEmpty ? PiaogenceRGBColor.fallback : ticket.palette
    }
    private var dominant: PiaogenceRGBColor { colors[0] }
    private var secondary: PiaogenceRGBColor { colors.count > 1 ? colors[1] : colors[0] }
    private var dark: PiaogenceRGBColor {
        colors.min(by: { $0.relativeLuminance < $1.relativeLuminance })
            ?? PiaogenceRGBColor(red: 0.08, green: 0.09, blue: 0.10)
    }
    private var light: PiaogenceRGBColor {
        colors.max(by: { $0.relativeLuminance < $1.relativeLuminance })
            ?? PiaogenceRGBColor(red: 0.96, green: 0.95, blue: 0.92)
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch type {
                case .movie: cinemaTicket(proxy.size)
                case .train: railTicket(proxy.size)
                case .flight: flightTicket(proxy.size)
                case .performance: liveTicket(proxy.size)
                case .musicFestival: festivalTicket(proxy.size)
                case .exhibition: exhibitionTicket(proxy.size)
                case .attraction: scenicTicket(proxy.size)
                case .other: memoryTicket(proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay {
                if ticket.ticketEdition == .collector {
                    CollectorTicketFinish(
                        type: type,
                        layout: ticket.layout,
                        dominant: dominant,
                        secondary: secondary,
                        fingerprint: ticket.fingerprint
                    )
                }
            }
            .mask { PiaogenceTicketMask(layout: ticket.layout) }
        }
        .aspectRatio(ticket.layout.aspectRatio, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.localizedMemoryTemplateName)，\(ticket.title)，\("纪念重制，不可作为入场凭证".appLocalized)")
    }

    private func cinemaTicket(_ size: CGSize) -> some View {
        let scale = size.width / 560
        return ZStack {
            LinearGradient(
                colors: [dark.color, dominant.adjusted(brightness: -0.18, saturation: 0.10).color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(secondary.color.opacity(0.30))
                .frame(width: size.width * 0.42)
                .blur(radius: size.width * 0.09)
                .offset(x: -size.width * 0.12, y: size.height * 0.20)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 7 * scale) {
                    HStack(spacing: 7 * scale) {
                        Image(systemName: "film.stack.fill")
                        Text("银幕票  /  SCREEN MEMORY")
                    }
                    .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                    .tracking(0.8 * scale)
                    .foregroundStyle(.white.opacity(0.70))

                    Spacer(minLength: 2)

                    Text(ticket.title)
                        .font(.system(size: 27 * scale, weight: .black, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.60)
                    if let subtitle = ticket.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11 * scale, weight: .medium))
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(1)
                    }

                    HStack(spacing: 7 * scale) {
                        compactPill("clock", ticket.captureTimeText, scale: scale)
                        if let place = ticket.place, !place.isEmpty {
                            compactPill("mappin", place, scale: scale)
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.leading, 24 * scale)
                .padding(.vertical, 18 * scale)
                .frame(maxWidth: .infinity, alignment: .leading)

                memoryStub(size: CGSize(width: size.width * 0.28, height: size.height),
                           tint: light, ink: dark, scale: scale)
                    .frame(width: size.width * 0.28)
            }
        }
    }

    private func railTicket(_ size: CGSize) -> some View {
        let scale = size.width / 560
        let paper = light.adjusted(brightness: 0.08, saturation: -0.42)
        let ink = readableInk(on: paper)
        return ZStack {
            paper.color
            Text("JOURNEY")
                .font(.system(size: 58 * scale, weight: .black, design: .rounded))
                .tracking(5 * scale)
                .foregroundStyle(ink.color.opacity(0.035))
                .rotationEffect(.degrees(-8))
                .offset(x: -size.width * 0.07, y: size.height * 0.12)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(dominant.adjusted(brightness: -0.12, saturation: -0.05).color)
                    .frame(width: 14 * scale)

                VStack(alignment: .leading, spacing: 9 * scale) {
                    HStack {
                        Label("行旅票", systemImage: "tram.fill")
                            .font(.system(size: 11 * scale, weight: .black, design: .rounded))
                            .tracking(1.2 * scale)
                        Spacer()
                        Text("RAIL MEMORY  ·  \(String(ticket.fingerprint.suffix(6)))")
                            .font(.system(size: 7.5 * scale, weight: .bold, design: .monospaced))
                            .opacity(0.54)
                    }

                    HStack(alignment: .center, spacing: 12 * scale) {
                        VStack(alignment: .leading, spacing: 3 * scale) {
                            Text(ticket.title)
                                .font(.system(size: 24 * scale, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.60)
                            Text(ticket.place?.isEmpty == false ? ticket.place! : "路途与目的地".appLocalized)
                                .font(.system(size: 10 * scale, weight: .semibold))
                                .opacity(0.58)
                                .lineLimit(1)
                        }
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18 * scale, weight: .light))
                            .opacity(0.48)
                        Image(systemName: "location.fill")
                            .font(.system(size: 20 * scale, weight: .bold))
                            .foregroundStyle(dominant.color)
                    }

                    HStack(spacing: 7 * scale) {
                        Circle()
                            .fill(dominant.color)
                            .frame(width: 6 * scale, height: 6 * scale)
                        Rectangle()
                            .fill(ink.color.opacity(0.18))
                            .frame(height: 1 * scale)
                        Image(systemName: "tram.fill")
                            .font(.system(size: 9 * scale, weight: .bold))
                            .foregroundStyle(dominant.color)
                        Rectangle()
                            .fill(ink.color.opacity(0.18))
                            .frame(height: 1 * scale)
                        Circle()
                            .stroke(ink.color.opacity(0.38), lineWidth: 1 * scale)
                            .frame(width: 6 * scale, height: 6 * scale)
                    }
                    .padding(.trailing, 4 * scale)

                    Spacer(minLength: 4 * scale)
                    detailFooter(scale: scale, ink: ink.color)
                }
                .foregroundStyle(ink.color)
                .padding(18 * scale)

                memoryStub(size: CGSize(width: size.width * 0.27, height: size.height),
                           tint: dominant.adjusted(brightness: 0.30, saturation: -0.30), ink: dark, scale: scale)
                    .frame(width: size.width * 0.27)
            }
        }
    }

    private func flightTicket(_ size: CGSize) -> some View {
        let scale = size.width / 560
        let paper = PiaogenceRGBColor(red: 0.965, green: 0.975, blue: 0.985)
        return ZStack {
            paper.color
            Rectangle()
                .fill(LinearGradient(colors: [dominant.color, secondary.color], startPoint: .leading, endPoint: .trailing))
                .frame(height: 11 * scale)
                .frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 9 * scale) {
                    HStack {
                        Label("云端票", systemImage: "airplane")
                            .font(.system(size: 11 * scale, weight: .black, design: .rounded))
                        Spacer()
                        Text("MEMORY BOARDING")
                            .font(.system(size: 8 * scale, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 14 * scale) {
                        airportCode(ticket.title, caption: "JOURNEY", scale: scale)
                        Image(systemName: "airplane")
                            .font(.system(size: 20 * scale, weight: .semibold))
                            .foregroundStyle(dominant.color)
                        airportCode(ticket.place?.isEmpty == false ? ticket.place! : "MEM", caption: "ARRIVAL", scale: scale)
                    }
                    Spacer(minLength: 0)
                    detailFooter(scale: scale, ink: Color.primary)
                }
                .padding(.leading, 22 * scale)
                .padding(.trailing, 16 * scale)
                .padding(.vertical, 18 * scale)
                .frame(maxWidth: .infinity)

                memoryStub(size: CGSize(width: size.width * 0.29, height: size.height),
                           tint: dominant.adjusted(brightness: 0.31, saturation: -0.38), ink: dark, scale: scale)
                    .frame(width: size.width * 0.29)
            }
        }
    }

    private func liveTicket(_ size: CGSize) -> some View {
        verticalPoster(
            size: size,
            eyebrow: "LIVE  /  在场票",
            giantWord: "LIVE",
            symbol: "music.mic",
            background: [dark.color, dominant.adjusted(brightness: -0.14).color],
            foreground: .white,
            accent: secondary.color
        )
    }

    private func festivalTicket(_ size: CGSize) -> some View {
        let scale = size.width / 360
        return ZStack {
            LinearGradient(colors: [dominant.color, secondary.color, light.color], startPoint: .topLeading, endPoint: .bottomTrailing)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 1.4 * scale)
                    .frame(width: CGFloat(90 + index * 46) * scale)
                    .offset(x: 90 * scale, y: -140 * scale)
            }
            VStack(alignment: .leading, spacing: 12 * scale) {
                Label("夏日票  /  MUSIC FESTIVAL", systemImage: "music.note.list")
                    .font(.system(size: 9 * scale, weight: .black, design: .rounded))
                    .tracking(0.8 * scale)
                Spacer()
                Text(ticket.title)
                    .font(.system(size: 31 * scale, weight: .black, design: .rounded))
                    .lineLimit(3)
                    .minimumScaleFactor(0.55)
                Text(ticket.subtitle ?? "把舞台、人群与夏夜收进一张票".appLocalized)
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .lineLimit(2)
                    .opacity(0.68)
                verticalMeta(scale: scale, foreground: .primary)
            }
            .padding(22 * scale)
        }
        .overlay(alignment: .bottomTrailing) { sealBlock(scale: scale, darkMode: false).padding(20 * scale) }
    }

    private func exhibitionTicket(_ size: CGSize) -> some View {
        let scale = size.width / 360
        let paper = light.adjusted(brightness: 0.09, saturation: -0.58)
        let ink = readableInk(on: paper)
        return ZStack(alignment: .topLeading) {
            paper.color
            Rectangle()
                .fill(dominant.color)
                .frame(width: size.width * 0.31)
            VStack(alignment: .leading, spacing: 0) {
                Text("EXHIBITION")
                    .font(.system(size: 9 * scale, weight: .bold, design: .monospaced))
                    .tracking(2 * scale)
                Text("看\n展\n票")
                    .font(.system(size: 47 * scale, weight: .black, design: .rounded))
                    .lineSpacing(-8 * scale)
                    .padding(.top, 16 * scale)
                Spacer()
                paletteRail(scale: scale)
            }
            .foregroundStyle(readableInk(on: dominant).color)
            .padding(20 * scale)
            .frame(width: size.width * 0.31)

            VStack(alignment: .leading, spacing: 10 * scale) {
                Spacer(minLength: size.height * 0.24)
                Text(ticket.title)
                    .font(.system(size: 26 * scale, weight: .black, design: .serif))
                    .lineLimit(4)
                    .minimumScaleFactor(0.58)
                Text(ticket.subtitle ?? "一次看见，一段留存".appLocalized)
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(ink.color.opacity(0.60))
                    .lineLimit(2)
                Divider().overlay(ink.color.opacity(0.18))
                verticalMeta(scale: scale, foreground: ink.color)
                Spacer()
                safeCopyLabel(scale: scale, color: ink.color)
            }
            .foregroundStyle(ink.color)
            .padding(.leading, size.width * 0.37)
            .padding(.trailing, 20 * scale)
            .padding(.vertical, 20 * scale)
        }
    }

    private func scenicTicket(_ size: CGSize) -> some View {
        let scale = size.width / 360
        return ZStack {
            LinearGradient(colors: [light.color, dominant.color], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(.white.opacity(0.32))
                .frame(width: 170 * scale)
                .blur(radius: 3)
                .offset(x: 95 * scale, y: -170 * scale)
            VStack(alignment: .leading, spacing: 11 * scale) {
                HStack {
                    Label("山河票", systemImage: "mountain.2.fill")
                        .font(.system(size: 10 * scale, weight: .black, design: .rounded))
                    Spacer()
                    Text("SCENIC MEMORY")
                        .font(.system(size: 8 * scale, weight: .bold, design: .monospaced))
                        .opacity(0.54)
                }
                Spacer()
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 70 * scale, weight: .light))
                    .foregroundStyle(dark.color.opacity(0.20))
                Text(ticket.title)
                    .font(.system(size: 30 * scale, weight: .black, design: .rounded))
                    .lineLimit(3)
                    .minimumScaleFactor(0.58)
                Text(ticket.place?.isEmpty == false ? ticket.place! : (ticket.subtitle ?? "山河有记，此日有光".appLocalized))
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .opacity(0.58)
                    .lineLimit(2)
                verticalMeta(scale: scale, foreground: dark.color)
            }
            .foregroundStyle(dark.color)
            .padding(22 * scale)
        }
        .overlay(alignment: .bottomTrailing) { sealBlock(scale: scale, darkMode: false).padding(20 * scale) }
    }

    private func memoryTicket(_ size: CGSize) -> some View {
        verticalPoster(
            size: size,
            eyebrow: "MEMORY  /  记忆票",
            giantWord: "MEM",
            symbol: "ticket.fill",
            background: [dominant.adjusted(brightness: 0.17, saturation: -0.18).color, dark.color],
            foreground: .white,
            accent: light.color
        )
    }

    private func verticalPoster(size: CGSize, eyebrow: String, giantWord: String,
                                symbol: String, background: [Color], foreground: Color,
                                accent: Color) -> some View {
        let scale = size.width / 360
        return ZStack {
            LinearGradient(colors: background, startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(giantWord)
                .font(.system(size: 94 * scale, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.055))
                .rotationEffect(.degrees(-90))
                .offset(x: 105 * scale, y: -125 * scale)
            Circle()
                .fill(accent.opacity(0.24))
                .frame(width: 230 * scale)
                .blur(radius: 50 * scale)
                .offset(x: -110 * scale, y: 200 * scale)
            VStack(alignment: .leading, spacing: 12 * scale) {
                HStack {
                    Label(eyebrow, systemImage: symbol)
                    Spacer()
                }
                .font(.system(size: 8.5 * scale, weight: .black, design: .rounded))
                .tracking(0.7 * scale)
                Spacer()
                Text(ticket.title)
                    .font(.system(size: 32 * scale, weight: .black, design: .rounded))
                    .lineLimit(4)
                    .minimumScaleFactor(0.52)
                Text(ticket.subtitle ?? type.rawValue.appLocalized)
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.62))
                    .lineLimit(2)
                verticalMeta(scale: scale, foreground: foreground)
                Divider().overlay(foreground.opacity(0.20))
                HStack(alignment: .bottom) {
                    safeCopyLabel(scale: scale, color: foreground)
                    Spacer()
                    sealBlock(scale: scale, darkMode: true)
                }
            }
            .foregroundStyle(foreground)
            .padding(22 * scale)
        }
    }

    private func memoryStub(size: CGSize, tint: PiaogenceRGBColor,
                            ink: PiaogenceRGBColor, scale: CGFloat) -> some View {
        ZStack {
            tint.color
            VStack(spacing: 7 * scale) {
                Text("记忆封存")
                    .font(.system(size: 8 * scale, weight: .black, design: .rounded))
                    .tracking(0.7 * scale)
                sealQR(side: min(size.width * 0.44, size.height * 0.38), ink: ink)
                Text(String(ticket.fingerprint.suffix(8)))
                    .font(.system(size: 7 * scale, weight: .bold, design: .monospaced))
                paletteRail(scale: scale)
                Spacer(minLength: 0)
                safeCopyLabel(scale: scale, color: ink.color)
            }
            .foregroundStyle(ink.color)
            .padding(.horizontal, 10 * scale)
            .padding(.vertical, 13 * scale)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ink.color.opacity(0.20))
                .frame(width: 1)
                .overlay {
                    Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [4 * scale, 4 * scale]))
                        .foregroundStyle(ink.color.opacity(0.30))
                }
        }
    }

    private func compactPill(_ symbol: String, _ text: String, scale: CGFloat) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 8.5 * scale, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .padding(.horizontal, 8 * scale)
            .padding(.vertical, 5 * scale)
            .background(.white.opacity(0.10), in: Capsule())
    }

    private func detailFooter(scale: CGFloat, ink: Color) -> some View {
        HStack(spacing: 16 * scale) {
            infoBlock("日期".appLocalized, ticket.captureTimeText, scale: scale)
            infoBlock("地点".appLocalized, ticket.place ?? "待确认".appLocalized, scale: scale)
            infoBlock("编号".appLocalized, String(ticket.fingerprint.suffix(6)), scale: scale)
        }
        .foregroundStyle(ink)
    }

    private func infoBlock(_ label: String, _ value: String, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2 * scale) {
            Text(label.uppercased())
                .font(.system(size: 6.5 * scale, weight: .bold, design: .monospaced))
                .opacity(0.44)
            Text(value)
                .font(.system(size: 9 * scale, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func airportCode(_ value: String, caption: String, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2 * scale) {
            Text(String(value.prefix(8)).uppercased())
                .font(.system(size: 23 * scale, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.54)
            Text(caption)
                .font(.system(size: 6.5 * scale, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verticalMeta(scale: CGFloat, foreground: Color) -> some View {
        VStack(alignment: .leading, spacing: 7 * scale) {
            Label(ticket.captureTimeText, systemImage: "calendar")
            if let place = ticket.place, !place.isEmpty {
                Label(place, systemImage: "mappin.and.ellipse")
            }
            if !ticket.message.isEmpty {
                Label(ticket.message, systemImage: "quote.opening")
                    .lineLimit(2)
            }
        }
        .font(.system(size: 9.5 * scale, weight: .semibold, design: .rounded))
        .foregroundStyle(foreground.opacity(0.72))
    }

    private func sealBlock(scale: CGFloat, darkMode: Bool) -> some View {
        VStack(spacing: 4 * scale) {
            sealQR(side: 44 * scale, ink: darkMode
                   ? PiaogenceRGBColor(red: 0.96, green: 0.96, blue: 0.94)
                   : dark)
            Text("记忆封存")
                .font(.system(size: 6.5 * scale, weight: .bold, design: .rounded))
        }
    }

    @ViewBuilder
    private func sealQR(side: CGFloat, ink: PiaogenceRGBColor) -> some View {
        if let image = PiaogenceCodeRenderer.qrImage(
            text: ticket.qrPayload ?? "lingdong://memory/\(ticket.ticketID)?fp=\(ticket.fingerprint)",
            foreground: UIColor(red: ink.red, green: ink.green, blue: ink.blue, alpha: 1)
        ) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: side, height: side)
        }
    }

    private func paletteRail(scale: CGFloat) -> some View {
        HStack(spacing: 3.5 * scale) {
            ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { _, color in
                Capsule()
                    .fill(color.color)
                    .frame(width: 9 * scale, height: 4 * scale)
                    .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 0.4))
            }
        }
    }

    private func safeCopyLabel(scale: CGFloat, color: Color) -> some View {
        Text("纪念重制 · 不可作为入场凭证")
            .font(.system(size: 6.8 * scale, weight: .bold, design: .rounded))
            .tracking(0.35 * scale)
            .foregroundStyle(color.opacity(0.60))
            .lineLimit(1)
            .minimumScaleFactor(0.70)
    }

    private func readableInk(on background: PiaogenceRGBColor) -> PiaogenceRGBColor {
        let black = PiaogenceRGBColor(red: 0.055, green: 0.06, blue: 0.07)
        let white = PiaogenceRGBColor(red: 0.97, green: 0.97, blue: 0.95)
        return black.contrastRatio(with: background) >= white.contrastRatio(with: background)
            ? black : white
    }
}

private struct CollectorTicketFinish: View {
    let type: PhysicalTicketType
    let layout: PiaogenceLayoutStyle
    let dominant: PiaogenceRGBColor
    let secondary: PiaogenceRGBColor
    let fingerprint: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var foil: [Color] {
        let spread = max(dominant.red, dominant.green, dominant.blue)
            - min(dominant.red, dominant.green, dominant.blue)
        if spread < 0.09 {
            return [
                Color(red: 0.72, green: 0.74, blue: 0.76),
                Color(red: 0.98, green: 0.97, blue: 0.93),
                Color(red: 0.56, green: 0.62, blue: 0.66)
            ]
        }
        if dominant.green > dominant.red * 1.06 && dominant.green > dominant.blue * 1.02 {
            return [
                Color(red: 0.60, green: 0.75, blue: 0.68),
                Color(red: 0.94, green: 0.95, blue: 0.87),
                Color(red: 0.56, green: 0.70, blue: 0.72)
            ]
        }
        if dominant.blue > dominant.red * 1.05 {
            return [
                Color(red: 0.55, green: 0.73, blue: 0.82),
                Color(red: 0.94, green: 0.96, blue: 0.95),
                Color(red: 0.72, green: 0.66, blue: 0.78)
            ]
        }
        return [
            Color(red: 0.72, green: 0.53, blue: 0.45),
            Color(red: 0.96, green: 0.89, blue: 0.73),
            Color(red: 0.76, green: 0.65, blue: 0.66)
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
                let seconds = timeline.date.timeIntervalSinceReferenceDate

                let phase = reduceMotion ? 0.38 : seconds.truncatingRemainder(dividingBy: 4.8) / 4.8
                ZStack {
                    typeMotif(size: proxy.size)
                        .opacity(0.42)

                    movingFoil(size: proxy.size, phase: phase)

                    Path(PiaogenceTicketMask.maskPath(
                        in: CGRect(origin: .zero, size: proxy.size),
                        layout: layout
                    ))
                    .stroke(
                        LinearGradient(colors: foil + [foil[0]],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(
                            lineWidth: max(1.25, proxy.size.width * 0.0042),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                    if layout == .classic {
                        collectorEdgeSeal(scale: proxy.size.width / 560)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    } else {
                        collectorSeal(scale: proxy.size.width / 360)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func movingFoil(size: CGSize, phase: Double) -> some View {
        let bandWidth = size.width * (layout == .classic ? 0.20 : 0.34)
        let travel = size.width + bandWidth
        let centerX = -bandWidth * 0.5 + travel * phase
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        foil[0].opacity(0.025),
                        foil[1].opacity(0.23),
                        foil[2].opacity(0.07),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            .frame(width: bandWidth, height: size.height)
            .position(x: centerX, y: size.height * 0.5)
            .blendMode(.screen)
    }

    private func collectorSeal(scale: CGFloat) -> some View {
        HStack(spacing: 5 * scale) {
            Text("PRO")
                .font(.system(size: max(5.8, 7.2 * scale), weight: .black, design: .rounded))
            Rectangle()
                .fill(.white.opacity(0.30))
                .frame(width: 0.7, height: max(7, 9 * scale))
            Text("C\(String(fingerprint.suffix(6)))")
                .font(.system(size: max(5.6, 6.6 * scale), weight: .bold, design: .monospaced))
        }
        .tracking(0.45 * scale)
        .foregroundStyle(
            LinearGradient(colors: foil, startPoint: .leading, endPoint: .trailing)
        )
        .padding(.horizontal, max(7, 9 * scale))
        .padding(.vertical, max(4.5, 5.5 * scale))
        .background(.black.opacity(0.42), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.55))
        .padding(max(8, 11 * scale))
        .shadow(color: foil[0].opacity(0.18), radius: 7 * scale)
    }

    private func collectorEdgeSeal(scale: CGFloat) -> some View {
        let serial = String(fingerprint.suffix(6))
        let fontSize: CGFloat = max(5.5, 6.3 * scale)
        let horizontalPadding: CGFloat = max(6, 7 * scale)
        let verticalPadding: CGFloat = max(3, 3.5 * scale)
        let xOffset: CGFloat = -max(12, 15 * scale)
        let gradient = LinearGradient(colors: foil, startPoint: .leading, endPoint: .trailing)
        return Text("PRO · C\(serial)")
            .font(.system(size: fontSize, weight: .black, design: .monospaced))
            .tracking(0.35 * scale)
            .foregroundStyle(
                gradient
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(.black.opacity(0.34), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 0.5))
            .rotationEffect(.degrees(-90))
            .offset(x: xOffset)
            .shadow(color: foil[0].opacity(0.16), radius: 5 * scale)
    }

    @ViewBuilder
    private func typeMotif(size: CGSize) -> some View {
        let line = max(0.7, size.width * 0.0022)
        let gradient = LinearGradient(colors: foil, startPoint: .topLeading, endPoint: .bottomTrailing)
        switch type {
        case .movie:
            VStack {
                perforations(size: size)
                Spacer()
                perforations(size: size)
            }
            .padding(.vertical, size.height * 0.055)
            .foregroundStyle(gradient)
        case .train:
            HStack(spacing: 0) {
                Circle().fill(gradient).frame(width: line * 5, height: line * 5)
                Rectangle().fill(gradient).frame(height: line)
                Image(systemName: "tram.fill").font(.system(size: size.height * 0.11))
                Rectangle().fill(gradient).frame(height: line)
                Circle().stroke(gradient, lineWidth: line).frame(width: line * 5, height: line * 5)
            }
            .padding(.horizontal, size.width * 0.08)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, size.height * 0.08)
            .foregroundStyle(gradient)
        case .flight:
            ZStack {
                CollectorArcShape()
                    .stroke(gradient, style: StrokeStyle(lineWidth: line, dash: [line * 5, line * 4]))
                    .padding(.horizontal, size.width * 0.08)
                    .padding(.vertical, size.height * 0.18)
                Image(systemName: "airplane")
                    .font(.system(size: size.height * 0.15, weight: .light))
                    .foregroundStyle(gradient)
                    .offset(x: size.width * 0.12, y: -size.height * 0.15)
            }
        case .performance:
            HStack(spacing: size.width * 0.055) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(gradient)
                        .frame(width: line, height: size.height * 0.62)
                        .rotationEffect(.degrees(Double(index - 2) * 9))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: -size.height * 0.10)
        case .musicFestival:
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(gradient, lineWidth: line)
                        .frame(width: size.width * (0.28 + CGFloat(index) * 0.17))
                }
            }
            .offset(x: size.width * 0.25, y: -size.height * 0.28)
        case .exhibition:
            Image(systemName: "viewfinder")
                .resizable()
                .scaledToFit()
                .foregroundStyle(gradient)
                .padding(size.width * 0.08)
        case .attraction:
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .stroke(gradient, lineWidth: line)
                        .frame(width: size.width * (0.30 + CGFloat(index) * 0.12),
                               height: size.height * (0.14 + CGFloat(index) * 0.065))
                        .rotationEffect(.degrees(Double(index) * 7 - 13))
                }
            }
            .offset(x: size.width * 0.20, y: -size.height * 0.24)
        case .other:
            Image(systemName: "circle.grid.cross")
                .resizable()
                .scaledToFit()
                .foregroundStyle(gradient)
                .padding(size.width * 0.15)
                .opacity(0.62)
        }
    }

    private func perforations(size: CGSize) -> some View {
        HStack(spacing: size.width * 0.025) {
            ForEach(0..<10, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill()
                    .frame(width: size.width * 0.035, height: size.height * 0.035)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CollectorArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.74))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.26),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.10)
        )
        return path
    }
}
