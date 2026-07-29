// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct TicketVerificationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let payload: TicketPayload
    var onClose: (() -> Void)?

    @State private var revealed = false
    @State private var entranceAppeared = false
    @State private var entranceProgress: CGFloat = 0
    @State private var entranceVisible = true
    @State private var didRunEntrance = false

    private var colors: [Color] {
        let values = payload.palette.map(\.color)
        return values.isEmpty
            ? [Color(red: 0.20, green: 0.45, blue: 0.37), .indigo, .mint]
            : values
    }

    var body: some View {
        ZStack {
            TicketAmbientBackground(colors: colors)

            ScrollView {
                VStack(spacing: 18) {
                    header
                    heroTicket
                    if payload.message != nil {
                        messagePanel
                    }
                    if !payload.palette.isEmpty {
                        palettePanel
                    }
                    metadataPanel
                    privacyPanel
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 36)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 24)
            }
            .scrollIndicators(.hidden)

            if let revealLayout = payload.revealLayout,
               entranceVisible {
                TicketRevealTransitionLayer(
                    layout: revealLayout,
                    colors: colors,
                    appeared: entranceAppeared,
                    progress: entranceProgress
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
        .task(id: payload.id, runEntrance)
    }

    @MainActor
    private func runEntrance() async {
        guard !didRunEntrance else { return }
        didRunEntrance = true

        guard payload.revealLayout != nil, !reduceMotion else {
            entranceVisible = false
            withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                revealed = true
            }
            return
        }

        guard await waitForEntrance(.milliseconds(100)) else {
            revealImmediately()
            return
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
            entranceAppeared = true
        }

        guard await waitForEntrance(.milliseconds(420)) else {
            revealImmediately()
            return
        }

        withAnimation(.timingCurve(0.20, 0.84, 0.18, 1, duration: 1.02)) {
            entranceProgress = 1
        }

        guard await waitForEntrance(.milliseconds(980)) else {
            revealImmediately()
            return
        }

        withAnimation(.easeOut(duration: 0.42)) {
            revealed = true
            entranceVisible = false
        }
    }

    @MainActor
    private func waitForEntrance(
        _ duration: Duration
    ) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    @MainActor
    private func revealImmediately() {
        entranceVisible = false
        entranceAppeared = false
        entranceProgress = 1
        revealed = true
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "appclip")
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.13), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("灵动照片")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("影像票根 · 本地验证")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.12), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭验证页面")
            }
        }
        .foregroundStyle(.white)
    }

    private var heroTicket: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("票根信息完整", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.15), in: Capsule())

                Spacer()

                Text(payload.ticketID)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(payload.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = payload.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "number")
                    .font(.caption.weight(.bold))
                Text("照片指纹 \(payload.fingerprint)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ticketGlass(cornerRadius: 30)
    }

    private var messagePanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("票根寄语", systemImage: "quote.opening")
                .font(.headline)

            if let message = payload.message {
                Text(message)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("票根寄语，\(message)")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ticketGlass(cornerRadius: 26)
    }

    private var palettePanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("照片色盘", systemImage: "paintpalette.fill")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(payload.palette) { entry in
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(entry.color)
                            .frame(height: 58)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.22), lineWidth: 1)
                            }

                        Text(entry.hex)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .lineLimit(1)

                        Text("\(entry.percentage, specifier: "%.1f")%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .ticketGlass(cornerRadius: 26)
    }

    private var metadataPanel: some View {
        let values = metadataValues
        return VStack(alignment: .leading, spacing: 15) {
            Label("拍摄信息", systemImage: "camera.aperture")
                .font(.headline)

            if values.isEmpty {
                Text("这张票根没有公开拍摄信息")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(values) { value in
                        VStack(alignment: .leading, spacing: 5) {
                            Label(value.label, systemImage: value.symbol)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.52))
                            Text(value.value)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
                        .padding(13)
                        .background(.white.opacity(0.08), in: RoundedRectangle(
                            cornerRadius: 17,
                            style: .continuous
                        ))
                    }
                }
            }
        }
        .padding(20)
        .ticketGlass(cornerRadius: 26)
    }

    private var privacyPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.80))

            VStack(alignment: .leading, spacing: 4) {
                Text("不读取相册，不上传照片")
                    .font(.subheadline.weight(.bold))
                Text("此页面只解析二维码中由发送者主动公开的数据，所有展示与校验均在本机完成。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ticketGlass(cornerRadius: 24)
    }

    private var metadataValues: [TicketMetadataValue] {
        [
            payload.captureTime.map {
                TicketMetadataValue(label: "拍摄时间", value: $0, symbol: "calendar")
            },
            payload.place.map {
                TicketMetadataValue(label: "地点", value: $0, symbol: "location")
            },
            payload.device.map {
                TicketMetadataValue(label: "拍摄设备", value: $0, symbol: "camera")
            },
            payload.lens.map {
                TicketMetadataValue(label: "镜头", value: $0, symbol: "camera.aperture")
            },
            payload.captureSettings.map {
                TicketMetadataValue(label: "拍摄参数", value: $0, symbol: "dial.medium")
            }
        ]
        .compactMap { $0 }
    }
}

private struct TicketRevealTransitionLayer: View {
    let layout: TicketRevealLayout
    let colors: [Color]
    let appeared: Bool
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let horizontalProgress = min(
                max((progress - 0.70) / 0.30, 0),
                1
            )
            let initialWidth = min(proxy.size.width * 0.70, 318)
            let initialHeight = min(
                proxy.size.height * (layout == .classic ? 0.36 : 0.44),
                layout == .classic ? 365 : 430
            )
            let width = initialWidth
                + (proxy.size.width + 6 - initialWidth) * horizontalProgress
            let height = initialHeight
                + (proxy.size.height + 8 - initialHeight) * progress
            let shapeDetail = 1 - horizontalProgress
            let cornerRadius = 32 * shapeDetail
            let notchRadius = min(width, height) * 0.058 * shapeDetail
            let perforationRadius = min(width, height) * 0.010 * shapeDetail

            TicketRevealBlankTicket(
                layout: layout,
                colors: colors
            )
            .frame(width: width, height: height)
            .mask {
                TicketRevealMaskView(
                    layout: layout,
                    cornerRadius: cornerRadius,
                    notchRadius: notchRadius,
                    perforationRadius: perforationRadius
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.50 * shapeDetail),
                            .white.opacity(0.12 * shapeDetail)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.8, 1.4 * shapeDetail)
                )
                .mask {
                    TicketRevealMaskView(
                        layout: layout,
                        cornerRadius: cornerRadius,
                        notchRadius: notchRadius,
                        perforationRadius: perforationRadius
                    )
                }
            }
            .shadow(
                color: .black.opacity(0.34 * shapeDetail),
                radius: 30 * shapeDetail,
                y: 18 * shapeDetail
            )
            .scaleEffect(appeared ? 1 : 0.82)
            .opacity(appeared ? 1 : 0)
            .position(
                x: proxy.size.width / 2,
                y: proxy.size.height / 2
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("正在展开空白票根")
        }
        .ignoresSafeArea()
    }
}

private struct TicketRevealBlankTicket: View {
    let layout: TicketRevealLayout
    let colors: [Color]

    private var primary: Color {
        colors.first ?? Color(red: 0.20, green: 0.45, blue: 0.37)
    }

    private var secondary: Color {
        colors[min(1, colors.count - 1)]
    }

    private var tertiary: Color {
        colors[min(2, colors.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            let dividerFraction: CGFloat = layout == .classic ? 0.35 : 0.54
            let dividerY = proxy.size.height * dividerFraction

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        secondary.opacity(0.98),
                        tertiary.opacity(0.90),
                        primary.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if layout == .classic {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    primary.opacity(0.98),
                                    secondary.opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: dividerY)

                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { _ in
                            Circle()
                                .fill(secondary.opacity(0.96))
                                .frame(
                                    width: proxy.size.width / 8 + 1,
                                    height: proxy.size.width / 8 + 1
                                )
                        }
                    }
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.width / 8 + 1
                    )
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: proxy.size.width / 16 + 1)
                    }
                    .position(x: proxy.size.width / 2, y: dividerY)
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tertiary.opacity(0.92),
                                    secondary.opacity(0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: dividerY)

                    Rectangle()
                        .fill(primary.opacity(0.88))
                        .frame(height: max(1, proxy.size.height - dividerY))
                        .offset(y: dividerY)
                }

                LinearGradient(
                    colors: [
                        .white.opacity(0.15),
                        .clear,
                        .black.opacity(0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

private struct TicketRevealMaskView: View {
    let layout: TicketRevealLayout
    let cornerRadius: CGFloat
    let notchRadius: CGFloat
    let perforationRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let dividerFraction: CGFloat = layout == .classic ? 0.35 : 0.54
            let dividerY = proxy.size.height * dividerFraction

            ZStack {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(.white)

                if notchRadius > 0.2 {
                    Circle()
                        .fill(.black)
                        .frame(
                            width: notchRadius * 2,
                            height: notchRadius * 2
                        )
                        .position(x: 0, y: dividerY)

                    Circle()
                        .fill(.black)
                        .frame(
                            width: notchRadius * 2,
                            height: notchRadius * 2
                        )
                        .position(x: proxy.size.width, y: dividerY)
                }

                if layout == .vertical, perforationRadius > 0.2 {
                    ForEach(1...7, id: \.self) { index in
                        Circle()
                            .fill(.black)
                            .frame(
                                width: perforationRadius * 2,
                                height: perforationRadius * 2
                            )
                            .position(
                                x: proxy.size.width * CGFloat(index) / 8,
                                y: dividerY
                            )
                    }
                }
            }
            .compositingGroup()
            .luminanceToAlpha()
        }
    }
}

struct TicketVerificationErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.14), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .frame(width: 82, height: 82)
                    .background(.white.opacity(0.10), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))

                Text("无法验证影像票根")
                    .font(.title2.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(28)
            .frame(maxWidth: 360)
        }
        .preferredColorScheme(.dark)
    }
}

private struct TicketMetadataValue: Identifiable {
    let label: String
    let value: String
    let symbol: String

    var id: String { label }
}

private struct TicketAmbientBackground: View {
    let colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        colors[0],
                        colors[min(1, colors.count - 1)].opacity(0.82),
                        Color.black.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(colors[min(2, colors.count - 1)].opacity(0.60))
                    .frame(width: proxy.size.width * 1.12)
                    .blur(radius: 92)
                    .offset(x: -proxy.size.width * 0.42, y: proxy.size.height * 0.26)

                Circle()
                    .fill(colors[min(3, colors.count - 1)].opacity(0.40))
                    .frame(width: proxy.size.width * 0.86)
                    .blur(radius: 76)
                    .offset(x: proxy.size.width * 0.42, y: -proxy.size.height * 0.25)

                LinearGradient(
                    colors: [.white.opacity(0.09), .clear, .black.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func ticketGlass(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.34), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
        }
    }
}
