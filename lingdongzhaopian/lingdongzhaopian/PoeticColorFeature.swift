import SwiftUI
import UIKit

extension RGBColor {
    func poeticEntry() -> TraditionalColorEntry {
        TraditionalColorLexicon.nearest(
            red: Double(red),
            green: Double(green),
            blue: Double(blue)
        )
    }
}

private struct UniformPoeticRowsLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width
            ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max()
            ?? 0
        let rowProposal = ProposedViewSize(width: width, height: nil)
        let rowHeight = subviews
            .map { $0.sizeThatFits(rowProposal).height }
            .max() ?? 0
        return CGSize(
            width: width,
            height: rowHeight * CGFloat(subviews.count)
                + spacing * CGFloat(max(subviews.count - 1, 0))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard !subviews.isEmpty else { return }
        let measurementProposal = ProposedViewSize(width: bounds.width, height: nil)
        let rowHeight = subviews
            .map { $0.sizeThatFits(measurementProposal).height }
            .max() ?? 0
        let placementProposal = ProposedViewSize(width: bounds.width, height: rowHeight)
        var y = bounds.minY
        for subview in subviews {
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                anchor: .topLeading,
                proposal: placementProposal
            )
            y += rowHeight + spacing
        }
    }
}

struct PoeticPaletteCard: View {
    let palette: [RGBColor]
    let isUnlocked: Bool
    var isExporting = false
    var percentages: [Double] = []
    var onLockedTap: () -> Void = {}

    private var rows: [(RGBColor, TraditionalColorEntry)] {
        let colors = Array(palette.prefix(6))
        let entries = TraditionalColorLexicon.uniqueMatches(
            colors: colors,
            percentages: Array(percentages.prefix(6))
        )
        return Array(zip(colors, entries))
    }

    private struct SourceDetail {
        let showsMarker: Bool
        let text: String
    }


    private static var sourceMarker: String {
        NSLocalizedString("自 ·", comment: "")
    }

    static func exportHeight(
        for palette: [RGBColor],
        percentages: [Double] = [],
        width: CGFloat
    ) -> CGFloat {
        let colors = Array(palette.prefix(6))
        let entries = TraditionalColorLexicon.uniqueMatches(
            colors: colors,
            percentages: Array(percentages.prefix(6))
        )
        guard !entries.isEmpty else { return 0 }

        let fontSize: CGFloat = 10.5
        let baseFont = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let descriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: fontSize)
        let markerFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)

        let detailColumnWidth = max(width - 154, 80)
        let markerWidth = (sourceMarker as NSString).size(
            withAttributes: [.font: markerFont]
        ).width + 3

        let maximumDetailHeight = entries.compactMap { entry -> CGFloat? in
            guard let detail = sourceDetail(for: entry) else { return nil }
            let textWidth = max(
                detailColumnWidth - (detail.showsMarker ? markerWidth : 0),
                44
            )
            let bounds = (detail.text as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let lineCount = max(Int(ceil(bounds.height / font.lineHeight)), 1)
            return CGFloat(lineCount) * font.lineHeight + CGFloat(lineCount - 1)
        }.max() ?? font.lineHeight


        let minimumNameHeight: CGFloat = LexiconLanguage.current == .english ? 30 : 24
        let rowHeight = max(minimumNameHeight, maximumDetailHeight) + 14
        let separators = CGFloat(max(entries.count - 1, 0)) * 0.5
        let cardHeight = rowHeight * CGFloat(entries.count) + separators + 24

        return ceil(cardHeight + 24)
    }

    var body: some View {
        UniformPoeticRowsLayout(spacing: 0.5) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                poeticRow(color: row.0, entry: row.1)
                    .overlay(alignment: .bottom) {
                        if index < rows.count - 1 {
                            Rectangle()
                                .fill((isExporting ? Color.white : Color.primary).opacity(0.075))
                                .frame(height: 0.5)
                                .padding(.leading, isExporting ? 42 : 38)
                        }
                    }
            }
        }
        .foregroundStyle(isExporting ? Color.white : Color.primary.opacity(0.90))
        .padding(.horizontal, isExporting ? 13 : 11)
        .padding(.vertical, isExporting ? 12 : 10)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            interactive: !isUnlocked && !isExporting,
            variant: .clear
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            guard !isUnlocked, !isExporting else { return }
            onLockedTap()
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(!isUnlocked && !isExporting ? "轻点了解诗意色名" : "")
    }

    private func poeticRow(color: RGBColor, entry: TraditionalColorEntry) -> some View {
        HStack(alignment: .center, spacing: isExporting ? 10 : 8) {
            Circle()
                .fill(color.color)
                .frame(width: isExporting ? 24 : 21, height: isExporting ? 24 : 21)
                .shadow(color: color.color.opacity(0.28), radius: 5)

            Text(entry.localizedName)
                .font(.system(size: isExporting ? 12 : 10.5, weight: .bold, design: .rounded))

                .lineLimit(LexiconLanguage.current == .english ? 2 : 1)
                .frame(width: isExporting ? (LexiconLanguage.current == .english ? 68 : 62)
                                          : (LexiconLanguage.current == .english ? 58 : 52),
                       alignment: .leading)

            detailText(entry)
                .font(.system(size: isExporting ? 10.5 : 9, weight: .medium, design: .rounded))
                .foregroundStyle((isExporting ? Color.white : Color.secondary).opacity(isExporting ? 0.78 : 0.94))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: isUnlocked ? 0 : (isExporting ? 0 : 11))
                .overlay {
                    if !isUnlocked && !isExporting {
                        LinearGradient(
                            colors: [.clear, Color.primary.opacity(0.13), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }

            if !isUnlocked && !isExporting {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.72))
            }
        }
        .padding(.horizontal, isExporting ? 11 : 9)
        .padding(.vertical, isExporting ? 7 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func detailText(_ entry: TraditionalColorEntry) -> some View {
        if isExporting && !isUnlocked {
            EmptyView()
        } else if let detail = Self.sourceDetail(for: entry) {
            HStack(alignment: .center, spacing: 3) {
                if detail.showsMarker {
                    Text(Self.sourceMarker)
                        .fontWeight(.bold)
                        .fixedSize()
                }
                Text(detail.text)
            }
        }
    }

    private static func sourceDetail(for entry: TraditionalColorEntry) -> SourceDetail? {
        let byline = entry.localizedByline
        if entry.localizedQuote.isEmpty {
            return byline.isEmpty ? nil : SourceDetail(showsMarker: true, text: byline)
        }
        return SourceDetail(
            showsMarker: !byline.isEmpty,
            text: byline.isEmpty ? "「\(entry.localizedQuote)」" : "\(byline)「\(entry.localizedQuote)」"
        )
    }
}

struct PoeticColorInvitation: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.18))
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text("试试诗意色名")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        ProBadge(compact: true)
                    }
                    Text("给照片的颜色，一个有出处的名字")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .opacity(0.62)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.55)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 62)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true, variant: .clear)
    }
}

struct ProBadge: View {
    var compact = false

    var body: some View {
        Text("PRO")
            .font(.system(size: compact ? 8 : 9, weight: .black, design: .rounded))
            .tracking(0.5)
        .foregroundStyle(Color(red: 0.08, green: 0.16, blue: 0.20))
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.67, green: 0.90, blue: 0.92),
                    Color(red: 0.95, green: 0.78, blue: 0.66)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .overlay(Capsule().stroke(.white.opacity(0.62), lineWidth: 0.6))
        .shadow(color: Color(red: 0.48, green: 0.78, blue: 0.82).opacity(0.20), radius: 7, y: 2)
        .accessibilityLabel("Pro 功能")
    }
}

struct NewBadge: View {
    var compact = true

    var body: some View {
        Text("新")
            .font(.system(size: compact ? 8 : 9, weight: .black, design: .rounded))
            .foregroundStyle(Color(red: 0.08, green: 0.16, blue: 0.20))
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.67, green: 0.90, blue: 0.92),
                        Color(red: 0.95, green: 0.78, blue: 0.66)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.62), lineWidth: 0.6))
            .shadow(color: Color(red: 0.48, green: 0.78, blue: 0.82).opacity(0.20), radius: 7, y: 2)
            .accessibilityLabel("新功能")
    }
}


private struct SupportContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct SupportUsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @AppStorage("poeticNamesEnabled") private var poeticNamesEnabled = false
    @ObservedObject private var supporterStore = SupporterStore.shared
    @State private var supportContentHeight: CGFloat = 0
    private let supportActionPanelHeight: CGFloat = 112

    var onEnable: (() -> Void)?

    var body: some View {
        ZStack {
            supportBackground
            VStack(spacing: 0) {

                header
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .zIndex(1)

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            if let bannerText = firstBatchBannerText {
                                firstBatchBanner(bannerText)
                            }
                            featureCard
                            supportCard
                        }
                        .padding(.horizontal, 18)

                        .padding(.top, 26)
                        .background(
                            GeometryReader { contentProxy in
                                Color.clear.preference(
                                    key: SupportContentHeightKey.self,
                                    value: contentProxy.size.height
                                )
                            }
                        )


                        .padding(.bottom, supportActionPanelHeight + 16)
                    }


                    .mask(alignment: .top) {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 26)
                            Rectangle().fill(.black)
                        }
                    }

                    .scrollDisabled(
                        supportContentHeight > 0
                            && supportContentHeight <= max(0, proxy.size.height - supportActionPanelHeight)
                    )
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .onPreferenceChange(SupportContentHeightKey.self) { supportContentHeight = $0 }
        .overlay(alignment: .bottom) {
            purchaseActionPanel
        }
        .overlay(alignment: .topTrailing) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.70))
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.28), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
            .accessibilityIdentifier("support.close")
            .padding(18)
        }
        .preferredColorScheme(.dark)
        .task {
            supporterStore.bootstrap()
            supporterStore.refreshFirstBatchStatus()
            await supporterStore.refreshProductIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await supporterStore.refreshProductIfNeeded() }
        }
        .alert("提示".appLocalized, isPresented: Binding(
            get: { supporterStore.errorMessage != nil },
            set: { if !$0 { supporterStore.errorMessage = nil } }
        )) {
            Button("好".appLocalized, role: .cancel) {}
        } message: {
            Text((supporterStore.errorMessage ?? "").appLocalized)
        }
    }

    private var supportBackground: some View {
        ZStack {
            Color(red: 0.055, green: 0.063, blue: 0.082)
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.39, blue: 0.47).opacity(0.52),
                    Color(red: 0.48, green: 0.31, blue: 0.38).opacity(0.23),
                    Color(red: 0.055, green: 0.063, blue: 0.082)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Color.black.opacity(0.34)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 12) {
            SupportTicketShowcase(reduceMotion: reduceMotion)
                .padding(.horizontal, -18)

            HStack(spacing: 9) {
                Text((supporterUnlocked ? "谢谢你，让灵感继续生长" : "支持我们").appLocalized)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                ProBadge()
            }
            Text("让照片的颜色，有诗的名字")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text("三百八十四种传统色名与出处，取自中国古籍与历代诗词。")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }

    private var featureCard: some View {
        VStack(spacing: 0) {
            supportFeature("camera.filters", "二十四节气", "从三百八十四种传统色中全局匹配")
            supportFeatureDivider
            supportFeature("text.quote", "出处可考", "384 色逐条附古籍与诗词出处")
            supportFeatureDivider
            supportFeature("ticket.fill", "典藏票面", "八类实体票专属纹样与原票色矿物箔光")
            supportFeatureDivider
            supportFeature("photo.artframe", "更多邮票模板", "解锁全部比例与三角形、扇形、圆形邮票；3:4 邮票免费。")
            supportFeatureDivider
            supportFeature("envelope", "更多明信片版式", "解锁竖版寄语、白边快照与满版邮趣；经典邮政版式免费。")
            supportFeatureDivider
            supportFeature("app.badge", "专属应用图标", "解锁四款应用图标，随心更换主屏幕上的灵动照片。")
            supportFeatureDivider
            supportFeature(
                "checkmark.seal",
                "支持者标志",
                "可选择在编辑页标题旁或标题位置显示 PRO",
                usesProBadge: true
            )
        }
        .padding(.horizontal, 5)
    }

    private var supportFeatureDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.095))
            .frame(height: 0.7)
            .padding(.leading, 54)
    }

    private func supportFeature(
        _ symbol: String,
        _ title: LocalizedStringKey,
        _ detail: LocalizedStringKey,
        usesProBadge: Bool = false
    ) -> some View {
        HStack(spacing: 13) {
            Group {
                if usesProBadge {
                    ProBadge()
                        .fixedSize()
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(red: 0.70, green: 0.89, blue: 0.91))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.08), in: Circle())
                }
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var supportCard: some View {
        VStack(spacing: 13) {
            Text((supporterUnlocked ? "支持者礼物已解锁" : "一次支持 · 长久感谢").appLocalized)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(supportSubtitle.appLocalized)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 5)
        .padding(.top, 7)
        .overlay(alignment: .topTrailing) {
            if supporterStore.isFirstBatchUser {
                firstBatchStamp
                    .offset(x: 6, y: -20)
            }
        }
    }



    private var purchaseActionPanel: some View {
        VStack(spacing: 10) {
            purchaseButton
            restorePurchaseButton
        }
        .padding(.horizontal, 23)
        .padding(.top, 22)
        .padding(.bottom, 4)
        .background {
            LinearGradient(
                colors: [
                    .clear,
                    Color(red: 0.055, green: 0.063, blue: 0.082).opacity(0.90),
                    Color(red: 0.055, green: 0.063, blue: 0.082),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    private var purchaseButton: some View {
        Button {
            if supporterUnlocked {
                poeticNamesEnabled = true
                onEnable?()
                dismiss()
            } else {
                Task { await supporterStore.purchase() }
            }
        } label: {
            HStack {
                if supporterStore.isPurchasing || supporterStore.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: supporterUnlocked ? "checkmark.seal.fill" : "heart.fill")
                }
                Text(purchaseButtonTitle)
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.13))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.72, green: 0.91, blue: 0.91), Color(red: 0.92, green: 0.74, blue: 0.68)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(!supporterUnlocked && (supporterStore.isPurchasing || supporterStore.isLoading))
        .accessibilityIdentifier("support.purchase")
    }

    private var restorePurchaseButton: some View {
        Button {
            Task { await supporterStore.restore() }
        } label: {
            Text("恢复购买")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
        }
        .buttonStyle(.plain)
        .disabled(supporterStore.isPurchasing || supporterStore.isLoading)
    }

    private var purchaseButtonTitle: String {
        if supporterUnlocked {
            return "开始使用".appLocalized
        }
        if supporterStore.isLoading {
            return "正在连接 App Store…".appLocalized
        }
        if let price = supporterStore.displayPrice {
            return String(format: "支持 %@".appLocalized, price)
        }
        if supporterStore.productLoadFailed {
            return "重新连接 App Store".appLocalized
        }
        return "连接 App Store".appLocalized
    }

    private var supportSubtitle: String {
        if supporterUnlocked {
            return "你已可以使用节气诗名、典藏票面、全部邮票与明信片模板、专属应用图标及支持者标志。".appLocalized
        }
        return "一次解锁节气词库、典藏票面、全部邮票与明信片模板、专属应用图标及支持者标志。".appLocalized
    }

    private var firstBatchBannerText: String? {
        guard supporterStore.isFirstBatchUser,
              let dateText = supporterStore.firstBatchDownloadDateText else { return nil }
        return String(format: "您是首批 1.0.0 版本下载用户，下载日期为%@，感谢您的一路陪伴。".appLocalized, dateText)
    }

    private func firstBatchBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Color(red: 0.98, green: 0.86, blue: 0.62))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.90, green: 0.72, blue: 0.42).opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.90, green: 0.72, blue: 0.42).opacity(0.34), lineWidth: 1)
        )
    }


    private var firstBatchStamp: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.86, green: 0.33, blue: 0.27).opacity(0.85), lineWidth: 2)
            Circle()
                .stroke(Color(red: 0.86, green: 0.33, blue: 0.27).opacity(0.55), lineWidth: 1)
                .padding(4)
            VStack(spacing: 1) {
                Text("首批用户".appLocalized)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                Text("FIRST BATCH")
                    .font(.system(size: 5.5, weight: .bold, design: .rounded))
                    .kerning(0.4)
                    .opacity(0.72)
            }
            .foregroundStyle(Color(red: 0.86, green: 0.33, blue: 0.27))
        }
        .frame(width: 62, height: 62)
        .rotationEffect(.degrees(-13))
        .allowsHitTesting(false)
    }
}

private struct SupportTicketShowcase: View {
    let reduceMotion: Bool

    private static let photoTickets = (1...6).map {
        SupportShowcaseAsset(name: "SupportPhotoTicket\($0)", width: 184, height: 79)
    }

    private static let developedTickets = [
        SupportShowcaseAsset(name: "SupportDevelopRailway", width: 184, height: 79),
        SupportShowcaseAsset(name: "SupportDevelopLive", width: 66, height: 88),
        SupportShowcaseAsset(name: "SupportDevelopFlight", width: 184, height: 79),
        SupportShowcaseAsset(name: "SupportDevelopExhibition", width: 66, height: 88),
        SupportShowcaseAsset(name: "SupportDevelopCinema", width: 184, height: 79),
        SupportShowcaseAsset(name: "SupportDevelopFestival", width: 66, height: 88)
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 11) {
                SupportTicketMarqueeRow(
                    assets: Self.photoTickets,
                    direction: .leading,
                    speed: 29,
                    phaseOffset: 0.12,
                    reduceMotion: reduceMotion
                )
                .frame(height: 79)

                SupportTicketMarqueeRow(
                    assets: Self.developedTickets,
                    direction: .trailing,
                    speed: 26,
                    phaseOffset: 0.43,
                    reduceMotion: reduceMotion
                )
                .frame(height: 88)
            }
            .saturation(0.82)
            .brightness(-0.12)
            .opacity(0.88)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(red: 0.055, green: 0.063, blue: 0.082).opacity(0.18), location: 0.34),
                    .init(color: Color(red: 0.055, green: 0.063, blue: 0.082).opacity(0.50), location: 0.50),
                    .init(color: Color(red: 0.055, green: 0.063, blue: 0.082).opacity(0.18), location: 0.66),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .allowsHitTesting(false)

            applicationIcon
        }
        .frame(height: 178)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.035),
                    .init(color: .black, location: 0.965),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("上排影像票根、下排票根显影作品")
        .accessibilityValue(ApplicationIconStore.shared.selected.title)
        .accessibilityIdentifier("support.showcase")
    }

    @ViewBuilder
    private var applicationIcon: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .white.opacity(0.20), location: 0),
                            .init(color: Color(red: 0.80, green: 0.96, blue: 0.62).opacity(0.16), location: 0.28),
                            .init(color: Color(red: 0.56, green: 0.89, blue: 0.88).opacity(0.10), location: 0.60),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 62
                    )
                )
                .frame(width: 128, height: 108)
                .blur(radius: 7)

            CurrentApplicationIcon()
            .frame(width: 66, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.38), lineWidth: 0.85)
            }
            .shadow(color: .white.opacity(0.15), radius: 5)
            .shadow(color: Color(red: 0.58, green: 0.91, blue: 0.85).opacity(0.22), radius: 20)
            .shadow(color: .black.opacity(0.30), radius: 10, y: 6)
        }
    }


}

private struct SupportShowcaseAsset: Identifiable {
    let name: String
    let width: CGFloat
    let height: CGFloat

    var id: String { name }
}

private struct SupportTicketMarqueeRow: View {
    enum Direction {
        case leading
        case trailing
    }

    let assets: [SupportShowcaseAsset]
    let direction: Direction
    let speed: CGFloat
    let phaseOffset: CGFloat
    let reduceMotion: Bool

    @State private var startedAt = Date()

    private let spacing: CGFloat = 10

    private var groupWidth: CGFloat {
        assets.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(assets.count - 1, 0))
    }

    private var cycleWidth: CGFloat { groupWidth + spacing }

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                let rawDistance = CGFloat(elapsed) * speed + cycleWidth * phaseOffset
                let distance = rawDistance.truncatingRemainder(dividingBy: cycleWidth)
                let offset = direction == .leading ? -distance : -cycleWidth + distance

                HStack(spacing: spacing) {
                    ticketGroup
                    ticketGroup
                    ticketGroup
                }
                .offset(x: offset)
            }
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private var ticketGroup: some View {
        HStack(spacing: spacing) {
            ForEach(assets) { asset in
                Image(asset.name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: asset.width, height: asset.height)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.13), lineWidth: 0.7)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
            }
        }
        .frame(width: groupWidth, alignment: .leading)
    }
}
