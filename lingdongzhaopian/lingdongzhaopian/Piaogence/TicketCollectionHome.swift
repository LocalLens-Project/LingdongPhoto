import SwiftUI
import UIKit

enum CollectionRoute: Hashable {
    case city(String)
    case custom(UUID)

    var timelineSource: CollectionTimelineView.Source {
        switch self {
        case .city(let name): .city(name)
        case .custom(let id): .custom(id)
        }
    }
}

private enum TicketCollectionPage: String, CaseIterable, Identifiable {
    case cities
    case collections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cities: "城市足迹".appLocalized
        case .collections: "我的分集".appLocalized
        }
    }
}

struct TicketCollectionHome: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPageIndex = 0
    @State private var showNewCollection = false
    @State private var appeared = false
    @State private var isSelectingCollections = false
    @State private var selectedCollectionIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    let onCreateTicket: () -> Void

    init(onCreateTicket: @escaping () -> Void = {}) {
        self.onCreateTicket = onCreateTicket
    }

    private var page: TicketCollectionPage {
        selectedPageIndex == 1 ? .collections : .cities
    }

    private let accent = Color(red: 0.84, green: 0.38, blue: 0.22)
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    overview
                    pageSwitcher
                        .padding(.top, 18)

                    Group {
                        switch page {
                        case .cities: cityPage
                        case .collections: collectionPage
                        }
                    }
                    .id(page)
                    .transition(pageTransition)

                    Spacer(minLength: 28)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .background { backgroundLayer }
        .navigationTitle("票根集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if page == .collections, isSelectingCollections {
                    Button("取消") { exitCollectionSelection() }
                        .font(.system(size: 14, weight: .semibold))
                        .tint(accent)
                } else {
                    Button("关闭", systemImage: "xmark", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("关闭票根集")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    if page == .collections, !store.customCollections.isEmpty {
                        Button {
                            if isSelectingCollections {
                                guard !selectedCollectionIDs.isEmpty else { return }
                                showDeleteConfirmation = true
                            } else {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    isSelectingCollections = true
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .tint(isSelectingCollections && !selectedCollectionIDs.isEmpty ? .red : accent)
                        .disabled(isSelectingCollections && selectedCollectionIDs.isEmpty)
                        .accessibilityLabel("删除分集")
                    }

                    Button {
                        showNewCollection = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .tint(accent)
                    .accessibilityLabel("新建分集")
                    .sensoryFeedback(.impact(weight: .light), trigger: showNewCollection)
                }
            }
        }
        .sheet(isPresented: $showNewCollection) {
            NewCollectionSheet()
                .presentationDetents([.medium])
        }
        .alert("删除分集", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteSelectedCollections() }
        } message: {
            Text(String(
                format: "确定删除选中的 %lld 个分集吗？删除后无法恢复。".appLocalized,
                selectedCollectionIDs.count
            ))
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .move(edge: page == .cities ? .leading : .trailing)),
                removal: .opacity
            )
    }

    private var overview: some View {
        VStack(spacing: 6) {
            if uniqueTicketCount > 0 {
                Text(summaryText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.82))
                    .contentTransition(.numericText())
            }

            Text((uniqueTicketCount == 0
                 ? "把抵达、相遇与在场，从第一张票开始收藏"
                 : "把抵达、相遇与在场，收进一册").appLocalized)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
    }

    private var pageSwitcher: some View {
        Picker("票根集视图", selection: $selectedPageIndex) {
            Text("城市足迹").tag(0)
            Text("我的分集").tag(1)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 286)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("票根集视图")
        .onChange(of: selectedPageIndex) { oldIndex, newIndex in
            guard oldIndex != newIndex else { return }
            UISelectionFeedbackGenerator().selectionChanged()

            exitCollectionSelection()
        }
    }

    @ViewBuilder
    private var cityPage: some View {
        if store.cities.isEmpty {
            EmptyTicketCollectionView(
                accent: accent,
                demoKind: .cities,
                title: "还没有票根",
                message: "选一张照片制作影像票根，\n它会按城市自动收进这里。",
                primaryTitle: "制作第一张票根",
                primarySymbol: "ticket",
                primaryAction: onCreateTicket,
                secondaryTitle: "先新建一个分集",
                secondaryAction: { showNewCollection = true }
            )
            .padding(.top, 36)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                sectionHeading(
                    "城市足迹",
                    caption: "代表票面在前，同城记忆按时间藏在身后"
                )

                LazyVStack(spacing: 30) {
                    ForEach(Array(store.cities.enumerated()), id: \.element) { index, city in
                        if let representative = store.representativeTicket(forCity: city) {
                            NavigationLink(value: CollectionRoute.city(city)) {
                                CityRepresentativeRow(
                                    city: city,
                                    ticket: representative,
                                    backTickets: chronologicalNeighbors(
                                        of: representative,
                                        in: city
                                    ),
                                    count: store.tickets(inCity: city).count
                                )
                            }
                            .buttonStyle(TicketPressStyle(scale: 0.975, tilt: 0))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(
                                .spring(response: 0.52, dampingFraction: 0.82)
                                    .delay(0.04 + Double(index) * 0.045),
                                value: appeared
                            )
                        }
                    }
                }
            }
            .padding(.top, 28)
        }
    }

    private func chronologicalNeighbors(
        of representative: TicketStub,
        in city: String
    ) -> [TicketStub] {
        let ordered = store.tickets(inCity: city).sorted {
            $0.captureDate > $1.captureDate
        }
        guard ordered.count > 1 else { return [] }

        let candidates = ordered
            .filter { $0.id != representative.id }
            .sorted { lhs, rhs in
                let lhsLayoutPenalty = lhs.layout == representative.layout ? 0 : 1
                let rhsLayoutPenalty = rhs.layout == representative.layout ? 0 : 1
                if lhsLayoutPenalty != rhsLayoutPenalty {
                    return lhsLayoutPenalty < rhsLayoutPenalty
                }
                let lhsDistance = abs(lhs.captureDate.timeIntervalSince(representative.captureDate))
                let rhsDistance = abs(rhs.captureDate.timeIntervalSince(representative.captureDate))
                return lhsDistance < rhsDistance
            }
        return Array(candidates.prefix(2))
    }

    @ViewBuilder
    private var collectionPage: some View {
        if store.customCollections.isEmpty {
            EmptyTicketCollectionView(
                accent: accent,
                demoKind: .collections,
                title: "还没有分集",
                message: "把旅行、演出或某一段时光，\n整理成属于你的票夹。",
                primaryTitle: "新建第一个分集",
                primarySymbol: "folder.badge.plus",
                primaryAction: { showNewCollection = true },
                secondaryTitle: uniqueTicketCount == 0 ? "先制作一张票根" : nil,
                secondaryAction: onCreateTicket
            )
            .padding(.top, 36)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeading(
                    "我的分集",
                    caption: "不按地点，只按你想记住的方式收藏"
                )

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(store.customCollections) { collection in
                        if isSelectingCollections {
                            selectableCollectionCard(collection)
                        } else {
                            NavigationLink(value: CollectionRoute.custom(collection.id)) {
                                CustomCollectionCard(collection: collection)
                            }
                            .buttonStyle(TicketPressStyle(scale: 0.96, tilt: 0))
                        }
                    }

                    if !isSelectingCollections {
                        NewCollectionTile(accent: accent) {
                            showNewCollection = true
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
            .padding(.top, 28)
        }
    }


    private func selectableCollectionCard(_ collection: TicketCollection) -> some View {
        let isSelected = selectedCollectionIDs.contains(collection.id)
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                if isSelected {
                    selectedCollectionIDs.remove(collection.id)
                } else {
                    selectedCollectionIDs.insert(collection.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                CustomCollectionCard(collection: collection)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isSelected ? accent : Color.secondary.opacity(0.42))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TicketPressStyle(scale: 0.96, tilt: 0))
        .accessibilityLabel(collection.name)
        .accessibilityHint(isSelected ? "取消选择这个分集" : "选择这个分集")
    }

    private func exitCollectionSelection() {
        guard isSelectingCollections || !selectedCollectionIDs.isEmpty else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isSelectingCollections = false
            selectedCollectionIDs.removeAll()
        }
    }

    private func deleteSelectedCollections() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            store.customCollections.removeAll { selectedCollectionIDs.contains($0.id) }
            store.persist()
            selectedCollectionIDs.removeAll()
            isSelectingCollections = false
        }
    }

    private func sectionHeading(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.appLocalized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.88))
            Text(caption.appLocalized)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var allTickets: [TicketStub] {
        store.cityTickets + store.customCollections.flatMap(\.tickets)
    }

    private var uniqueTicketCount: Int {
        Set(allTickets.map(\.id)).count
    }

    private var summaryText: String {
        String(
            format: "%lld 张票根 · %lld 座城市 · %lld 个分集".appLocalized,
            uniqueTicketCount, store.cities.count, store.customCollections.count
        )
    }

    private var ambientAccent: Color {
        allTickets.max(by: { $0.captureDate < $1.captureDate })?
            .palette.first?.color ?? accent
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.975, green: 0.965, blue: 0.945),
                    Color(red: 0.945, green: 0.935, blue: 0.915),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [ambientAccent.opacity(0.17), .clear],
                center: .topLeading,
                startRadius: 15,
                endRadius: 330
            )
            .animation(.easeInOut(duration: 0.55), value: uniqueTicketCount)
        }
        .ignoresSafeArea()
    }
}

private struct EmptyTicketCollectionView: View {
    let accent: Color
    let demoKind: EmptyTicketDemoKind
    let title: String
    let message: String
    let primaryTitle: String
    let primarySymbol: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DemoTicketStack(kind: demoKind)

            Text(title.appLocalized)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.86))
                .padding(.top, 20)

            Text(message.appLocalized)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 8)

            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    Image(systemName: primarySymbol)
                        .font(.system(size: 13, weight: .semibold))
                    Text(primaryTitle.appLocalized)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 46)
                .background(Capsule().fill(accent.gradient))
                .shadow(color: accent.opacity(0.22), radius: 12, y: 7)
            }
            .buttonStyle(TicketPressStyle(scale: 0.96, tilt: 0))
            .padding(.top, 24)

            if let secondaryTitle {
                Button(action: secondaryAction) {
                    Text(secondaryTitle.appLocalized)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(accent.opacity(0.86))
                .buttonStyle(.plain)
                .padding(.top, 15)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum EmptyTicketDemoKind {
    case cities
    case collections

    var frontTitle: String {
        switch self {
        case .cities: "杭州".appLocalized
        case .collections: "宝宝成长".appLocalized
        }
    }

    var backTitle: String {
        switch self {
        case .cities: "温州".appLocalized
        case .collections: "旅行".appLocalized
        }
    }

    var frontDate: String {
        switch self {
        case .cities: "2026.04.18 16:24"
        case .collections: "2026.06.01 09:12"
        }
    }

    var backDate: String {
        switch self {
        case .cities: "2025.11.03 18:40"
        case .collections: "2025.08.16 07:36"
        }
    }

    var frontID: String {
        switch self {
        case .cities: "LD-2026-0418"
        case .collections: "LD-2026-0601"
        }
    }

    var backID: String {
        switch self {
        case .cities: "LD-2025-1103"
        case .collections: "LD-2025-0816"
        }
    }

    var frontColor: UIColor {
        switch self {
        case .cities: UIColor(red: 0.47, green: 0.62, blue: 0.60, alpha: 1)
        case .collections: UIColor(red: 0.78, green: 0.58, blue: 0.57, alpha: 1)
        }
    }

    var backColor: UIColor {
        switch self {
        case .cities: UIColor(red: 0.72, green: 0.51, blue: 0.36, alpha: 1)
        case .collections: UIColor(red: 0.46, green: 0.57, blue: 0.62, alpha: 1)
        }
    }
}

private struct DemoTicketStack: View {
    let kind: EmptyTicketDemoKind

    private var frontTicket: TicketStub {
        demoTicket(
            title: kind.frontTitle,
            date: kind.frontDate,
            ticketID: kind.frontID,
            fingerprint: "8F2A6C91D74B3E50",
            photoColor: kind.frontColor
        )
    }

    private var backTicket: TicketStub {
        demoTicket(
            title: kind.backTitle,
            date: kind.backDate,
            ticketID: kind.backID,
            fingerprint: "31C8E407A95D62BF",
            photoColor: kind.backColor
        )
    }

    var body: some View {
        ZStack {
            TicketArtworkView(ticket: backTicket)
                .frame(width: 292)
                .compositingGroup()
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
                .rotationEffect(.degrees(-3.2))
                .offset(x: -9, y: 30)

            TicketArtworkView(ticket: frontTicket)
                .frame(width: 310)
                .compositingGroup()
                .shadow(color: .black.opacity(0.16), radius: 14, y: 9)
                .rotationEffect(.degrees(1.4))
                .offset(x: 7, y: -9)
        }
        .frame(height: 174)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func demoTicket(
        title: String,
        date: String,
        ticketID: String,
        fingerprint: String,
        photoColor: UIColor
    ) -> TicketStub {
        let components = photoColor.cgColor.components ?? [0.62, 0.56, 0.48, 1]
        let red = components.indices.contains(0) ? components[0] : 0.62
        let green = components.indices.contains(1) ? components[1] : red
        let blue = components.indices.contains(2) ? components[2] : red
        let dominant = PiaogenceRGBColor(red: red, green: green, blue: blue)

        return TicketStub(
            ticketID: ticketID,
            fingerprint: fingerprint,
            headerTitle: "LINGDONG",
            title: title,
            subtitle: nil,
            message: "",
            city: title,
            place: nil,
            device: nil,
            captureDate: .distantPast,
            captureTimeText: date,
            layout: .classic,
            theme: .sunset,
            palette: [
                dominant,
                dominant.adjusted(brightness: 0.12, saturation: -0.10),
                dominant.adjusted(brightness: -0.16, saturation: 0.06),
            ],
            isSealed: false,
            isCapsule: false,
            artworkImageData: solidImageData(color: photoColor)
        )
    }

    private func solidImageData(color: UIColor) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }.pngData()
    }
}

private struct TicketSlipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 20)
        let notchRadius = min(rect.height * 0.085, 10)
        path.addEllipse(in: CGRect(
            x: rect.minX - notchRadius,
            y: rect.midY - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        ))
        path.addEllipse(in: CGRect(
            x: rect.maxX - notchRadius,
            y: rect.midY - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        ))
        return path
    }
}

struct CityRepresentativeRow: View {
    let city: String
    let ticket: TicketStub
    let backTickets: [TicketStub]
    let count: Int

    var body: some View {
        VStack(spacing: 13) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(.black.opacity(0.09))
                    .frame(width: ticket.layout == .vertical ? 118 : 246, height: 18)
                    .blur(radius: 8)
                    .offset(y: 7)

                ForEach(Array(backTickets.prefix(2).reversed().enumerated()), id: \.element.id) {
                    depth, backTicket in
                    let isDeepest = depth == 0 && backTickets.count > 1
                    TicketArtworkView(
                        ticket: backTicket,
                        artworkImageQuality: .thumbnail
                    )
                    .frame(width: backWidth(for: backTicket, deepest: isDeepest))
                    .compositingGroup()
                    .rotationEffect(.degrees(backAngle(for: backTicket, deepest: isDeepest)))
                    .offset(
                        x: backOffsetX(for: backTicket, deepest: isDeepest),
                        y: isDeepest ? -21 : -10
                    )
                    .shadow(color: .black.opacity(isDeepest ? 0.07 : 0.10), radius: 9, y: 5)
                }

                TicketArtworkView(
                    ticket: ticket,
                    artworkImageQuality: .thumbnail
                )
                    .frame(width: ticket.layout == .vertical ? 112 : 270)
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.15), radius: 11, y: 7)
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 172, alignment: .bottom)
            .allowsHitTesting(false)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.88))
                    Text("\(count) 张票根 · \(String(ticket.captureTimeText.prefix(10)))")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.50), in: Circle())
            }

            Divider().opacity(0.38)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开这座城市的票根时间轴")
    }

    private func backWidth(for backTicket: TicketStub, deepest: Bool) -> CGFloat {
        if backTicket.layout == .vertical {
            return deepest ? 92 : 102
        }
        return deepest ? 242 : 256
    }

    private func backAngle(for backTicket: TicketStub, deepest: Bool) -> CGFloat {
        if backTicket.layout == .vertical {
            return deepest ? 12 : 6
        }
        return deepest ? 15 : 8
    }

    private func backOffsetX(for backTicket: TicketStub, deepest: Bool) -> CGFloat {
        if backTicket.layout == .vertical {
            return deepest ? -9 : -5
        }
        return deepest ? -12 : -6
    }
}

struct CustomCollectionCard: View {
    let collection: TicketCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                TicketSlipShape()
                    .fill(.white.opacity(0.48), style: FillStyle(eoFill: true))
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 6)

                if let first = collection.tickets.first {
                    TicketArtworkView(
                        ticket: first,
                        artworkImageQuality: .thumbnail
                    )
                        .frame(width: first.layout == .vertical ? 72 : 142)
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.12), radius: 7, y: 4)
                } else {
                    VStack(spacing: 7) {
                        Image(systemName: collection.icon)
                            .font(.system(size: 23, weight: .medium))
                        Text("等待收入第一张")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 112)

            HStack(spacing: 7) {
                Image(systemName: collection.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.84, green: 0.38, blue: 0.22))
                Text(collection.name.appLocalized)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.86))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(collection.tickets.count)")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开这个分集")
    }
}

private struct NewCollectionTile: View {
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    TicketSlipShape()
                        .fill(.white.opacity(0.24), style: FillStyle(eoFill: true))
                        .overlay {
                            TicketSlipShape()
                                .stroke(
                                    accent.opacity(0.38),
                                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                                )
                        }

                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(accent.opacity(0.82))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 112)

                Text("新建分集")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TicketPressStyle(scale: 0.96, tilt: 0))
        .accessibilityHint("创建一个新的票根分集")
    }
}

struct NewCollectionSheet: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "folder.fill"

    private let iconChoices = [
        "airplane", "heart.fill", "figure.and.child.holdinghands",
        "birthday.cake.fill", "graduationcap.fill", "camera.fill",
        "fork.knife", "pawprint.fill", "star.fill", "book.fill",
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("分集名称")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("例如：旅行、宝贝、毕业季", text: $name)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("选择一个图标")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(iconChoices, id: \.self) { symbol in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    icon = symbol
                                }
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 17))
                                    .foregroundStyle(icon == symbol ? .white : Color(red: 0.35, green: 0.35, blue: 0.38))
                                    .frame(height: 46)
                                    .frame(maxWidth: .infinity)
                                    .background {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(icon == symbol
                                                  ? Color(red: 0.88, green: 0.45, blue: 0.26)
                                                  : Color(.systemGray6))
                                    }
                            }
                            .buttonStyle(TicketPressStyle(scale: 0.9, tilt: 0))
                        }
                    }
                }

                Spacer()

                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        store.customCollections.append(
                            TicketCollection(name: trimmed, icon: icon, tickets: []))
                        store.persist()
                    }
                    dismiss()
                } label: {
                    Text("创建分集")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(
                            name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray.opacity(0.4)
                                : Color(red: 0.88, green: 0.45, blue: 0.26)))
                }
                .buttonStyle(TicketPressStyle(scale: 0.98, tilt: 0))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
            .navigationTitle("新建分集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TicketCollectionHome()
    }
    .environment(TicketStore())
}
