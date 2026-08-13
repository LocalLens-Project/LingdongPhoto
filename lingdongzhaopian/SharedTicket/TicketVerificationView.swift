// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct TicketVerificationView: View {
    @Environment(\.scenePhase) private var scenePhase

    let ticket: VerifiedTicket
    var onClose: (() -> Void)?

    @State private var revealed = false
    @State private var entranceAppeared = false
    @State private var entranceProgress: CGFloat = 0
    @State private var entranceVisible = true
    @State private var didRunEntrance = false

    init(
        ticket: VerifiedTicket,
        onClose: (() -> Void)? = nil
    ) {
        self.ticket = ticket
        self.onClose = onClose
    }

    init(
        payload: TicketPayload,
        onClose: (() -> Void)? = nil
    ) {
        self.init(ticket: .unsigned(payload), onClose: onClose)
    }

    private var payload: TicketPayload { ticket.payload }

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
                    if payload.isEmotionalStyle {
                        timeCapsulePanel
                    }
                    if payload.message != nil {
                        messagePanel
                    }
                    if !payload.palette.isEmpty {
                        palettePanel
                    }
                    metadataPanel
                    sealPanel
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
                    ticket: ticket,
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
        .statusBarHidden(true)
        .task(
            id: TicketEntranceTaskID(
                ticketID: payload.id,
                sceneIsActive: scenePhase == .active
            )
        ) {
            guard scenePhase == .active else { return }
            await runEntrance()
        }
    }

    @MainActor
    private func runEntrance() async {
        guard !didRunEntrance else { return }
        resetInterruptedEntrance()
        didRunEntrance = true

        guard payload.revealLayout != nil,
              TicketRevealIslandSupport.isSupported else {
            entranceVisible = false
            withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                revealed = true
            }
            return
        }

        let presentationDelay = Duration.milliseconds(350)

        guard await waitForEntrance(presentationDelay) else {
            didRunEntrance = false
            return
        }

        let liveActivityStarted = await TicketRevealLiveActivityController.shared.start(
            title: payload.place ?? "北京",
            primaryHex: payload.palette.first?.hex,
            secondaryHex: payload.palette.dropFirst().first?.hex
        )

        guard !Task.isCancelled else {
            if liveActivityStarted {
                await TicketRevealLiveActivityController.shared.cancel()
            }
            didRunEntrance = false
            return
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
            entranceAppeared = true
        }

        guard await waitForEntrance(.milliseconds(320)) else {
            if liveActivityStarted {
                await TicketRevealLiveActivityController.shared.cancel()
            }
            didRunEntrance = false
            return
        }

        if liveActivityStarted {
            await TicketRevealLiveActivityController.shared.update(
                phase: .revealing,
                progress: 0.18
            )
        }

        guard await animateEntranceProgress() else {
            if liveActivityStarted {
                await TicketRevealLiveActivityController.shared.cancel()
            }
            didRunEntrance = false
            return
        }

        if liveActivityStarted {
            await TicketRevealLiveActivityController.shared.end(
                phase: .verified,
                progress: 1
            )
        }

        guard !Task.isCancelled else {
            didRunEntrance = false
            return
        }

        withAnimation(.easeOut(duration: 0.42)) {
            revealed = true
            entranceVisible = false
        }
    }

    @MainActor
    private func resetInterruptedEntrance() {
        guard entranceAppeared || entranceProgress > 0 || !entranceVisible || revealed else {
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            revealed = false
            entranceAppeared = false
            entranceProgress = 0
            entranceVisible = true
        }
    }

    @MainActor
    private func animateEntranceProgress() async -> Bool {
        let frameCount = 120
        for frame in 1...frameCount {
            guard await waitForEntrance(.milliseconds(18)) else {
                return false
            }
            let linear = CGFloat(frame) / CGFloat(frameCount)
            let eased = linear * linear * (3 - 2 * linear)
            entranceProgress = eased * 0.995
        }
        return true
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

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: payload.isEmotionalStyle ? "clock.arrow.circlepath" : "appclip")
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.13), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("灵动照片")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(payload.isEmotionalStyle ? "影像票根 · 时光胶囊" : "影像票根 · 本地验证")
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
                Label(sealBadgeTitle, systemImage: sealBadgeSymbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(sealBadgeColor)
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
                Image(systemName: payload.isEmotionalStyle ? "clock.badge-exclamation" : "number")
                    .font(.caption.weight(.bold))
                Text(payload.isEmotionalStyle ? "时光印记 \(payload.fingerprint)" : "照片指纹 \(payload.fingerprint)")
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

    private var sealBadgeTitle: String {
        if payload.isEmotionalStyle {
            switch ticket.sealValidation {
            case .unsigned: "这段回忆已被封存"
            case .valid: "这段回忆已被设备封印"
            case .invalid: "封印状态异常"
            }
        } else {
            switch ticket.sealValidation {
            case .unsigned: "公开信息完整"
            case .valid: "设备封印有效"
            case .invalid: "设备封印已失效"
            }
        }
    }

    private var sealBadgeSymbol: String {
        switch ticket.sealValidation {
        case .unsigned: "checkmark.circle.fill"
        case .valid: "checkmark.seal.fill"
        case .invalid: "exclamationmark.triangle.fill"
        }
    }

    private var sealBadgeColor: Color {
        if case .invalid = ticket.sealValidation { return .red }
        return .white
    }

    private var sealPanel: some View {
        HStack(alignment: .top, spacing: 13) {
            // 默认 SF Symbol 图标已替换为「灵动琉璃图标 + 设备品牌徽章」组合
            ZStack(alignment: .bottomTrailing) {
                LingdongLiquidGlassIcon()
                    .scaleEffect(0.28)
                    .frame(width: 28, height: 28)

                DeviceBrandBadge(deviceType: sealDeviceType)
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(sealPanelTitle)
                    .font(.subheadline.weight(.bold))
                Text(sealPanelDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ticketGlass(cornerRadius: 24)
    }

    /// 根据设备封印校验结果映射到对应的徽章类型：
    /// - "apple"：iPhone 安全隔区
    /// - "android"：Android 硬件/软件保护的设备密钥
    /// - "unknown"：未识别到来源（含模拟器测试）
    /// - "unsigned"：无设备封印
    /// - "invalid"：设备封印已失效 / 校验未通过
    private var sealDeviceType: String {
        switch ticket.sealValidation {
        case .unsigned:
            return "unsigned"
        case .invalid:
            return "invalid"
        case .valid(let origin, _):
            switch origin {
            case .appleSecureEnclave:
                return "apple"
            case .androidHardware, .androidSoftware:
                return "android"
            case .simulatorTest, .unknown:
                return "unknown"
            }
        }
    }

    private var sealPanelTitle: String {
        if payload.isEmotionalStyle {
            switch ticket.sealValidation {
            case .unsigned:
                "这段回忆由你封存"
            case .valid(let origin, _):
                origin.isHardwareBacked ? "这段回忆已被设备封印" : "这段回忆的签名已校验"
            case .invalid:
                "封印状态异常"
            }
        } else {
            switch ticket.sealValidation {
            case .unsigned:
                "这张票根没有设备封印"
            case .valid(let origin, _):
                origin.isHardwareBacked ? "设备封印通过" : "签名校验通过"
            case .invalid:
                "设备封印没有通过"
            }
        }
    }

    private var sealPanelDescription: String {
        if payload.isEmotionalStyle {
            switch ticket.sealValidation {
            case .unsigned:
                return "这张票根仍可查看公开信息。较早版本生成的票根可能没有设备封印。"
            case .valid(let origin, let keyID):
                let source: String
                switch origin {
                case .appleSecureEnclave:
                    source = "这段回忆由 iPhone 安全隔区的设备密钥盖章封存"
                case .androidHardware:
                    source = "这段回忆由 Android 硬件密钥盖章封存"
                case .androidSoftware:
                    source = "这段回忆由 Android 软件保护的密钥盖章封存"
                case .simulatorTest:
                    source = "这是模拟器测试封印，不代表真实硬件保护"
                case .unknown:
                    source = "这段回忆由兼容的 P-256 设备密钥盖章封存"
                }
                return "\(source)，从封存后内容没有发生变化。密钥编号 \(keyID)。"
            case .invalid:
                return "票根的封印状态异常。你仍可查看内容，但请留意内容可能已被改写。"
            }
        } else {
            switch ticket.sealValidation {
            case .unsigned:
                return "仍可查看公开信息，但无法判断生成后是否被重新改写。较早版本生成的票根也会显示为未封印。"
            case .valid(let origin, let keyID):
                let source: String
                switch origin {
                case .appleSecureEnclave:
                    source = "票根标记为由 iPhone 安全隔区中的设备密钥盖章"
                case .androidHardware:
                    source = "票根标记为由 Android 设备的硬件密钥盖章"
                case .androidSoftware:
                    source = "票根标记为由 Android 软件保护的设备密钥盖章"
                case .simulatorTest:
                    source = "这是模拟器测试签名，不代表真实硬件保护"
                case .unknown:
                    source = "票根标记为由兼容的 P-256 设备密钥盖章"
                }
                return "\(source)，公开信息从盖章后没有发生变化。密钥编号 \(keyID)。"
            case .invalid:
                return "票根的公开信息或签名已发生变化。你仍可查看内容，但不要把它当作原始票根。"
            }
        }
    }

    private var sealPanelSymbol: String {
        switch ticket.sealValidation {
        case .unsigned: "seal"
        case .valid: "checkmark.shield.fill"
        case .invalid: "exclamationmark.shield.fill"
        }
    }

    private var sealPanelTint: Color {
        switch ticket.sealValidation {
        case .unsigned: .white.opacity(0.78)
        case .valid: .green
        case .invalid: .red
        }
    }

    private var messagePanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(messagePanelTitle, systemImage: messagePanelSymbol)
                .font(.headline)

            if let message = payload.message {
                Text(message)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(messagePanelTitle)，\(message)")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ticketGlass(cornerRadius: 26)
    }

    private var messagePanelTitle: String {
        if payload.isEmotionalStyle {
            return payload.isSelfNarrative ? "写给过去的备忘" : "创作者留下的寄语"
        } else {
            return "票根寄语"
        }
    }

    private var messagePanelSymbol: String {
        if payload.isEmotionalStyle {
            return payload.isSelfNarrative ? "envelope.badge" : "quote.opening"
        } else {
            return "quote.opening"
        }
    }

    private var timeCapsulePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(timeCapsuleHeadline)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(timeCapsuleSubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let captureTime = payload.captureTime {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.bold))
                    Text("拍摄于 \(captureTime)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            if let sealedAt = payload.sealedAt,
               let gap = TicketTimeCalculator.daysBetweenCaptureAndSeal(
                   captureTime: payload.captureTime,
                   sealedAt: payload.sealedAt
               ),
               gap > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.caption.weight(.bold))
                    Text("封存于 \(sealedAt)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            if let place = payload.place {
                HStack(spacing: 8) {
                    Image(systemName: "location")
                        .font(.caption.weight(.bold))
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ticketGlass(cornerRadius: 26)
    }

    private var timeCapsuleHeadline: String {
        let captureText = TicketTimeCalculator.formattedTimeSinceCapture(payload.captureTime)
        let gap = TicketTimeCalculator.daysBetweenCaptureAndSeal(
            captureTime: payload.captureTime,
            sealedAt: payload.sealedAt
        )

        if let captureText {
            if payload.isSelfNarrative {
                // 同一天或无法判断时间差：合并叙事
                if gap == nil || gap! <= 0 {
                    return "🕰️ 这是一段\(captureText)的回忆"
                }
                // 封存在拍摄之后：强调"今天的你封存了过去的回忆"
                return "🕰️ \(captureText)的光影，由你封存成这枚票根"
            } else {
                if gap == nil || gap! <= 0 {
                    return "🌿 这是\(captureText)留下的一段光影"
                }
                return "🌿 \(captureText)的光影，被创作者封存于此"
            }
        } else {
            // 拍摄时间缺失
            if let sealText = TicketTimeCalculator.formattedTimeSinceSeal(payload.sealedAt) {
                if payload.isSelfNarrative {
                    return "🕰️ \(sealText)由你封存的一段回忆"
                } else {
                    return "🌿 \(sealText)封存的一段光影"
                }
            }
            if payload.isSelfNarrative {
                return "🕰️ 一段由你封存的回忆"
            } else {
                return "🌿 一段创作者封存的光影"
            }
        }
    }

    private var timeCapsuleSubtitle: String {
        let gap = TicketTimeCalculator.daysBetweenCaptureAndSeal(
            captureTime: payload.captureTime,
            sealedAt: payload.sealedAt
        )

        if payload.isSelfNarrative {
            if let gap, gap > 0 {
                return "那一刻的光、色与心情，被后来的你亲手封存于此。"
            }
            return "这张票根由你亲手封存，记录了那一刻的光、色与心情。"
        } else {
            if let gap, gap > 0 {
                return "创作者在那一刻按下快门，后来的TA将这段色彩与时间凝固于此。"
            }
            return "创作者在那一刻按下快门，让这段色彩与时间凝固于此。"
        }
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
            Label(payload.isEmotionalStyle ? "影像档案" : "拍摄信息", systemImage: payload.isEmotionalStyle ? "archivebox" : "camera.aperture")
                .font(.headline)

            if values.isEmpty {
                Text(payload.isEmotionalStyle ? "这张票根没有公开影像档案信息" : "这张票根没有公开拍摄信息")
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
                Text(payload.isEmotionalStyle ? "不读取相册，不上传照片" : "不读取相册，不上传照片")
                    .font(.subheadline.weight(.bold))
                Text(payload.isEmotionalStyle
                    ? "此页面只呈现二维码中由创作者主动公开的回忆，所有展示与解析均在本机完成。"
                    : "此页面只解析二维码中由发送者主动公开的数据，所有展示与校验均在本机完成。")
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

private struct TicketEntranceTaskID: Equatable {
    let ticketID: String
    let sceneIsActive: Bool
}

private struct TicketRevealTransitionLayer: View, Animatable {
    let ticket: VerifiedTicket
    let layout: TicketRevealLayout
    let colors: [Color]
    let appeared: Bool
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            islandTransition(in: proxy)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("票根正在从灵动岛出票")
    }

    private func islandTransition(
        in proxy: GeometryProxy
    ) -> some View {
        let feedProgress = min(max(progress / 0.64, 0), 1)
        let coverProgress = min(max((progress - 0.64) / 0.36, 0), 0.995)
        let screenWidth = proxy.size.width
        let screenHeight = proxy.size.height
        let ticketWidth = layout == .classic
            ? min(screenWidth * 0.70, 310)
            : min(screenWidth * 0.78, 336)
        let ticketHeight = layout == .classic
            ? min(
                ticketWidth * (
                    ticket.payload.revealWidthMode?.portraitAspectRatio
                        ?? TicketRevealWidthMode.compact.portraitAspectRatio
                ),
                screenHeight * 0.80
            )
            : min(screenHeight * 0.56, 510)
        let surfaceWidth = ticketWidth
            + (screenWidth + 8 - ticketWidth) * coverProgress
        let surfaceHeight = ticketHeight
            + (screenHeight - ticketHeight) * coverProgress
        let outletBottom = TicketRevealIslandSupport.outletBottom
        let clipTop = outletBottom * (1 - coverProgress)
        let feedOffset = -ticketHeight * (1 - feedProgress) * (1 - coverProgress)
        let shapeDetail = 1 - coverProgress
        let cornerRadius = 28 * shapeDetail
        let perforationRadius = min(surfaceWidth, surfaceHeight) * 0.009 * shapeDetail

        return ZStack(alignment: .top) {
            TicketRevealOutlet(
                width: appeared ? ticketWidth + 34 : 126,
                opacity: appeared ? 1 - coverProgress : 0
            )
            .position(
                x: screenWidth / 2,
                y: outletBottom - TicketRevealIslandSupport.islandHeight / 2
            )

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: clipTop)

                ZStack(alignment: .top) {
                    ticketSurface(
                        width: surfaceWidth,
                        height: surfaceHeight,
                        cornerRadius: cornerRadius,
                        perforationRadius: perforationRadius,
                        shapeDetail: shapeDetail
                    )
                    .offset(y: feedOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
            .frame(width: screenWidth, height: screenHeight, alignment: .top)
        }
        .frame(
            width: screenWidth,
            height: screenHeight,
            alignment: .top
        )
    }

    private func ticketSurface(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        perforationRadius: CGFloat,
        shapeDetail: CGFloat
    ) -> some View {
        TicketRevealIntroTicket(
            ticket: ticket,
            layout: layout,
            colors: colors
        )
        .frame(width: width, height: height)
        .mask {
            TicketRevealMaskView(
                layout: layout,
                cornerRadius: cornerRadius,
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
                    perforationRadius: perforationRadius
                )
            }
        }
        .shadow(
            color: .black.opacity(0.34 * shapeDetail),
            radius: 30 * shapeDetail,
            y: 18 * shapeDetail
        )
    }
}

private struct TicketRevealOutlet: View {
    let width: CGFloat
    let opacity: CGFloat

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.black.opacity(0.34))
                .blur(radius: 10)
                .offset(y: 7)

            Capsule(style: .continuous)
                .fill(.black)

            Capsule(style: .continuous)
                .fill(.black)
                .frame(width: max(88, width - 24), height: 12)
                .offset(y: 7)
        }
        .frame(width: width, height: TicketRevealIslandSupport.islandHeight)
        .opacity(opacity)
        .animation(.spring(response: 0.48, dampingFraction: 0.76), value: width)
    }
}

private struct TicketRevealIntroTicket: View {
    let ticket: VerifiedTicket
    let layout: TicketRevealLayout
    let colors: [Color]

    @State private var codeImage: UIImage?

    init(
        ticket: VerifiedTicket,
        layout: TicketRevealLayout,
        colors: [Color]
    ) {
        self.ticket = ticket
        self.layout = layout
        self.colors = colors
        _codeImage = State(initialValue: try? TicketCodeRenderer.verificationImage(
            for: ticket,
            pixelSize: CGSize(width: 540, height: 540),
            foregroundColor: .white,
            backgroundColor: nil
        ))
    }

    private var payload: TicketPayload { ticket.payload }

    private var primary: Color {
        colors.first ?? Color(red: 0.20, green: 0.45, blue: 0.37)
    }

    private var panel: some View {
        ZStack {
            primary
            Color.black.opacity(dominantLuminance > 0.52 ? 0.60 : 0.34)
        }
    }

    private var dominantLuminance: Double {
        guard let hex = payload.palette.first?.hex else { return 0.45 }
        let normalized = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        guard let value = UInt64(normalized, radix: 16) else { return 0.45 }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return red * 0.299 + green * 0.587 + blue * 0.114
    }

    var body: some View {
        switch layout {
        case .classic:
            classicTicket
        case .vertical:
            verticalTicket
        }
    }

    private var classicTicket: some View {
        GeometryReader { proxy in
            let stubHeight = proxy.size.height * 0.35
            let scallopDiameter = proxy.size.width / 7

            ZStack(alignment: .top) {
                primary

                panel
                    .frame(height: stubHeight)

                // Only the lower halves hang below the divider, mirroring
                // the printed ticket where the stub scallops bulge into the
                // body; the stub side above the divider stays flat.
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { _ in
                        TicketRevealScallop()
                            .fill(primary)
                            .overlay {
                                TicketRevealScallop().fill(
                                    Color.black.opacity(
                                        dominantLuminance > 0.52 ? 0.60 : 0.34
                                    )
                                )
                            }
                            .frame(
                                width: scallopDiameter + 1,
                                height: (scallopDiameter + 1) / 2
                            )
                    }
                }
                .frame(width: proxy.size.width)
                .position(
                    x: proxy.size.width / 2,
                    y: stubHeight + (scallopDiameter + 1) / 4
                )

                TicketRevealClassicStub(
                    payload: payload,
                    codeImage: codeImage
                )
                .frame(width: stubHeight, height: proxy.size.width)
                .rotationEffect(.degrees(90))
                .frame(width: proxy.size.width, height: stubHeight)
                .position(x: proxy.size.width / 2, y: stubHeight / 2)

                LinearGradient(
                    colors: [.white.opacity(0.10), .clear, .black.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            }
        }
    }

    private var verticalTicket: some View {
        GeometryReader { proxy in
            let photoHeight = proxy.size.height * 0.54
            let inset = max(16, proxy.size.width * 0.055)

            VStack(spacing: 0) {
                primary
                    .frame(height: photoHeight)
                    .overlay(alignment: .topTrailing) {
                        Text(payload.ticketID)
                            .font(.system(
                                size: max(8, proxy.size.width * 0.028),
                                weight: .bold,
                                design: .monospaced
                            ))
                            .foregroundStyle(.white.opacity(0.90))
                            .padding(inset)
                    }

                VStack(alignment: .leading, spacing: max(8, proxy.size.height * 0.012)) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(payload.title)
                                .font(.system(
                                    size: max(16, proxy.size.width * 0.055),
                                    weight: .bold,
                                    design: .rounded
                                ))
                                .lineLimit(2)

                            if let subtitle = payload.subtitle {
                                Text(subtitle)
                                    .font(.system(size: max(9, proxy.size.width * 0.028)))
                                    .foregroundStyle(.white.opacity(0.68))
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        if let codeImage {
                            Image(uiImage: codeImage)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: proxy.size.width * 0.28)
                        }
                    }

                    Divider().overlay(.white.opacity(0.28))

                    HStack(alignment: .top, spacing: 14) {
                        TicketRevealInfoValue(
                            label: "DATE",
                            value: payload.captureTime ?? "未记录"
                        )
                        TicketRevealInfoValue(
                            label: "CAMERA",
                            value: payload.device ?? "未公开"
                        )
                    }

                    HStack(spacing: 5) {
                        ForEach(payload.palette.prefix(6)) { entry in
                            Circle()
                                .fill(entry.color)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white.opacity(0.30), lineWidth: 0.7))
                        }
                    }

                    if let place = payload.place {
                        Text(place)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .padding(inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(panel)
            }
        }
    }
}

private struct TicketRevealClassicStub: View {
    let payload: TicketPayload
    let codeImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            let inset = max(10, proxy.size.width * 0.075)
            let codeSize = min(proxy.size.width * 0.68, proxy.size.height * 0.41)

            VStack(spacing: max(3, proxy.size.height * 0.012)) {
                if let headerTitle = payload.headerTitle,
                   !headerTitle.isEmpty {
                    Text(headerTitle)
                        .font(.system(
                            size: max(13, proxy.size.width * 0.10),
                            weight: .black,
                            design: .rounded
                        ))
                        .tracking(max(0.8, proxy.size.width * 0.008))
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)
                        .multilineTextAlignment(.center)
                }

                Text(payload.title)
                    .font(.system(
                        size: max(9, proxy.size.width * 0.052),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.center)

                VStack(spacing: 2) {
                    if let captureTime = payload.captureTime {
                        Text(captureTime)
                    }
                    Text("NO.\(payload.ticketID.replacingOccurrences(of: "LD-", with: ""))")
                    Text(String(payload.fingerprint.suffix(8)))
                }
                .font(.system(
                    size: max(7, proxy.size.width * 0.038),
                    weight: .semibold,
                    design: .monospaced
                ))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.64)

                Spacer(minLength: 2)

                if let codeImage {
                    Image(uiImage: codeImage)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: codeSize, height: codeSize)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, inset)
            .padding(.vertical, max(8, proxy.size.height * 0.035))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct TicketRevealInfoValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.64)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A semicircle with its flat edge on top, bulging downward. Used for the
/// divider scallops so the half circles only appear on the body side of the
/// ticket, matching the printed artwork.
private struct TicketRevealScallop: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct TicketRevealMaskView: View {
    let layout: TicketRevealLayout
    let cornerRadius: CGFloat
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

                if layout == .vertical, perforationRadius > 0.2 {
                    ForEach(1...7, id: \.self) { index in
                        TicketRevealScallop()
                            .fill(.black)
                            .frame(
                                width: perforationRadius * 2,
                                height: perforationRadius
                            )
                            .position(
                                x: proxy.size.width * CGFloat(index) / 8,
                                y: dividerY + perforationRadius / 2
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

// MARK: - 灵动琉璃图标 + 设备品牌徽章
// 用于替换 sealPanel 左侧的默认 SF Symbol 图标。

private struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.6))
        path.addCurve(to: CGPoint(x: rect.width, y: rect.height * 0.4),
                      control1: CGPoint(x: rect.width * 0.35, y: rect.height * 0.8),
                      control2: CGPoint(x: rect.width * 0.65, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

private struct GlassLens: View {
    var colors: [Color]
    var waveOpacity: Double
    var offsetY: CGFloat

    var body: some View {
        ZStack {
            // Base shadow
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(width: 80, height: 45)
                .offset(y: 10)
                .blur(radius: 5)

            // Base shape
            Ellipse()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 45)
                .shadow(color: colors.last!.opacity(0.5), radius: 5, x: 0, y: 5)

            // Inner highlight wave
            WaveShape()
                .fill(LinearGradient(colors: [.white.opacity(waveOpacity), .clear], startPoint: .top, endPoint: .bottom))
                .clipShape(Ellipse())
                .frame(width: 80, height: 45)

            // Inner bottom glow
            Ellipse()
                .strokeBorder(LinearGradient(colors: [.clear, .white.opacity(0.6)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                .frame(width: 80, height: 45)

            // Top white border
            Ellipse()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                .frame(width: 80, height: 45)

            // Glare
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
                .blur(radius: 1)
                .offset(x: 20, y: -18)
        }
        .offset(y: offsetY)
    }
}

struct LingdongLiquidGlassIcon: View {
    var body: some View {
        ZStack {
            // Bottom layer
            GlassLens(
                colors: [Color(red: 0.2, green: 0.8, blue: 0.6), Color(red: 0.0, green: 0.4, blue: 0.3)],
                waveOpacity: 0.4,
                offsetY: 20
            )

            // Middle layer
            GlassLens(
                colors: [Color(red: 0.5, green: 0.9, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.4)],
                waveOpacity: 0.5,
                offsetY: 0
            )

            // Top layer
            GlassLens(
                colors: [Color(red: 0.9, green: 0.95, blue: 0.3), Color(red: 0.4, green: 0.8, blue: 0.2)],
                waveOpacity: 0.6,
                offsetY: -20
            )
        }
        .frame(width: 100, height: 100)
    }
}

struct DeviceBrandBadge: View {
    var deviceType: String // "apple"、"android"、"unknown"（未识别到）或 "unsigned"（无设备封印）

    var body: some View {
        ZStack {
            // 半透明白底，与琉璃图标融合更自然
            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 1.2, x: 0, y: 0.6)

            if deviceType == "apple" {
                Image(systemName: "applelogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 8, height: 8)
                    .foregroundColor(.black)
                    .offset(y: -0.5)
            } else if deviceType == "android" {
                ZStack {
                    Path { path in
                        path.addArc(center: CGPoint(x: 4, y: 4), radius: 4, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    }
                    .fill(Color(red: 0.12, green: 0.62, blue: 0.32))
                    .frame(width: 8, height: 4)

                    Circle().fill(Color.white).frame(width: 1.5, height: 1.5).offset(x: -1.5, y: -0.5)
                    Circle().fill(Color.white).frame(width: 1.5, height: 1.5).offset(x: 1.5, y: -0.5)

                    Path { path in
                        path.move(to: CGPoint(x: 1.5, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: -2.5))
                        path.move(to: CGPoint(x: 6.5, y: 0))
                        path.addLine(to: CGPoint(x: 8, y: -2.5))
                    }
                    .stroke(Color(red: 0.12, green: 0.62, blue: 0.32), lineWidth: 0.8)
                    .frame(width: 8, height: 4)
                }
                .offset(y: 1.5)
            } else if deviceType == "unsigned" {
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 7, height: 7)
                    .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
            } else if deviceType == "invalid" {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 8, height: 8)
                    .foregroundColor(Color(red: 0.90, green: 0.25, blue: 0.22))
            } else {
                // 未识别到设备来源：右下角显示问号，代表不知道是否为灵动照片应用生成
                Text("?")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.black)
            }
        }
    }
}
