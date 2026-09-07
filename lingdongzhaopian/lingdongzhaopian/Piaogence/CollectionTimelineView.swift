import SwiftUI
import UIKit

private struct TimelineNodeBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [UUID: Anchor<CGRect>],
        nextValue: () -> [UUID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct CollectionTimelineView: View {
    enum Source: Hashable {
        case city(String)
        case custom(UUID)
    }

    let source: Source
    @Environment(TicketStore.self) private var store

    @State private var sortedByTime = true
    @State private var editMode = false
    @State private var selectedTicket: TicketStub?
    @State private var showAddSheet = false
    @State private var appeared = false

    @State private var detailBlocksBackgroundInteraction = false
    @Namespace private var ticketNS

    private var collectionTitle: String {
        switch source {
        case .city(let city): city
        case .custom(let id):
            store.customCollections.first(where: { $0.id == id })?.name ?? "分集".appLocalized
        }
    }

    private var tickets: [TicketStub] {
        switch source {
        case .city(let city): store.tickets(inCity: city)
        case .custom(let id):
            store.customCollections.first(where: { $0.id == id })?.tickets ?? []
        }
    }

    private var displayedTickets: [TicketStub] {
        Array(sortedByTime
            ? tickets.sorted { $0.captureDate < $1.captureDate }
            : tickets)
    }

    private func applyOrder(_ newOrder: [TicketStub]) {
        switch source {
        case .city(let city):
            store.cityTickets = store.cityTickets.filter { $0.city != city } + newOrder
        case .custom(let id):
            guard let index = store.customCollections.firstIndex(where: { $0.id == id }) else { return }
            store.customCollections[index].tickets = newOrder
        }
        store.persist()
    }

    private func requestMove(_ ticket: TicketStub, up: Bool) {
        var order = displayedTickets
        guard let index = order.firstIndex(where: { $0.id == ticket.id }) else { return }
        let target = up ? index - 1 : index + 1
        guard order.indices.contains(target) else { return }
        order.swapAt(index, target)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sortedByTime = false
            applyOrder(order)
        }
    }

    private func delete(_ ticket: TicketStub) {
        switch source {
        case .city:
            store.cityTickets.removeAll { $0.id == ticket.id }
        case .custom(let id):
            guard let index = store.customCollections.firstIndex(where: { $0.id == id }) else { return }
            store.customCollections[index].tickets.removeAll { $0.id == ticket.id }
        }
        store.persist()
    }

    private func openTicketDetail(_ ticket: TicketStub) {
        detailBlocksBackgroundInteraction = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            selectedTicket = ticket
        }
    }

    private func closeTicketDetail(deleting ticket: TicketStub? = nil) {

        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            selectedTicket = nil
            if let ticket {
                delete(ticket)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            guard selectedTicket == nil else { return }
            detailBlocksBackgroundInteraction = false
        }
    }

    private func insertByTime(_ ticket: TicketStub) {
        var list = tickets
        let position = list.firstIndex { $0.captureDate > ticket.captureDate } ?? list.endIndex
        list.insert(ticket, at: position)
        applyOrder(list)
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if tickets.isEmpty && !appeared {
                Color.clear
            }

            timelineScroll

                .overlay(alignment: .top) { controlBar }
                .allowsHitTesting(!detailBlocksBackgroundInteraction)
                .disabled(detailBlocksBackgroundInteraction)
                .accessibilityHidden(detailBlocksBackgroundInteraction)

            if let ticket = selectedTicket {
                TicketDetailView(
                    ticket: ticket,
                    namespace: ticketNS,
                    onClose: {
                        closeTicketDetail()
                    },
                    onDelete: { target in
                        closeTicketDetail(deleting: target)
                    },
                    onUpdate: { updated in
                        store.updateTicket(updated)
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            selectedTicket = updated
                        }
                    })
                    .zIndex(10)
                    .transition(.opacity)
            }
        }
        .modifier(PiaogenceTimelineNavigationChrome(title: collectionTitle))

        .toolbar(detailBlocksBackgroundInteraction ? .hidden : .visible, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .medium), trigger: selectedTicket?.id)
        .sheet(isPresented: $showAddSheet) {
            AddTicketSheet(source: source) { newTickets in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    for ticket in newTickets {
                        insertByTime(ticket)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(colors: [
            Color(red: 0.97, green: 0.95, blue: 0.92),
            Color(red: 0.92, green: 0.91, blue: 0.89),
        ], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            timeSortButton

            Spacer()

            reorderButton
        }
        .padding(.horizontal, 20)

        .padding(.leading, 17)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var timeSortButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: enableTimeSorting) {
                timeSortLabel(foreground: Color(red: 0.22, green: 0.22, blue: 0.25))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
        } else {
            Button(action: enableTimeSorting) {
                timeSortLabel(
                    foreground: sortedByTime
                        ? .white
                        : Color(red: 0.32, green: 0.32, blue: 0.35)
                )
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background {
                    if sortedByTime {
                        Capsule().fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(.black.opacity(0.06), lineWidth: 0.5))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var reorderButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: toggleEditMode) {
                reorderLabel(foreground: Color(red: 0.22, green: 0.22, blue: 0.25))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
        } else {
            Button(action: toggleEditMode) {
                reorderLabel(
                    foreground: editMode
                        ? .white
                        : Color(red: 0.32, green: 0.32, blue: 0.35)
                )
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background {
                    if editMode {
                        Capsule().fill(Color(red: 0.88, green: 0.45, blue: 0.26))
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(.black.opacity(0.06), lineWidth: 0.5))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func timeSortLabel(foreground: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: sortedByTime ? "clock.fill" : "arrow.counterclockwise")
                .font(.system(size: 11))
            Text((sortedByTime ? "时间顺序" : "恢复时间顺序").appLocalized)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(foreground)
    }

    private func reorderLabel(foreground: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: editMode ? "checkmark" : "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
            Text((editMode ? "完成" : "排序").appLocalized)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(foreground)
    }

    private func enableTimeSorting() {
        let chronologicalOrder = tickets.sorted { $0.captureDate < $1.captureDate }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            sortedByTime = true
            applyOrder(chronologicalOrder)
        }
    }

    private func toggleEditMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            editMode.toggle()
        }
    }

    private var timelineScroll: some View {
        ScrollView(showsIndicators: false) {
            if displayedTickets.isEmpty {
                emptyState
                    .padding(.top, 90)
            } else {
                timelineContent

                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        .contentMargins(.top, 54, for: .scrollContent)
    }

    private var timelineContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(displayedTickets.enumerated()), id: \.element.id) { index, ticket in
                    TimelineRow(
                        ticket: ticket,
                        isFirst: index == 0,
                        isLast: index == displayedTickets.count - 1,
                        editMode: editMode,
                        canMoveUp: index > 0,
                        canMoveDown: index < displayedTickets.count - 1,
                        isCitySource: isCitySource,
                        isRepresentative: isRepresentative(ticket),
                        namespace: ticketNS,
                        isHidden: selectedTicket?.id == ticket.id,
                        onTap: { openTicketDetail(ticket) },
                        onMoveUp: { requestMove(ticket, up: true) },
                        onMoveDown: { requestMove(ticket, up: false) },
                        onSetRepresentative: { setRepresentative(ticket) })
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.spring(response: 0.5, dampingFraction: 0.82)
                            .delay(Double(index) * 0.05), value: appeared)
                }
            }

            .overlayPreferenceValue(
                TimelineNodeBoundsPreferenceKey.self,
                alignment: .topLeading
            ) { anchors in
                GeometryReader { geo in
                    timelineRail(
                        nodeCenters: anchors.values
                            .map { geo[$0].midY }
                            .sorted(),
                        height: geo.size.height
                    )
                }
                .allowsHitTesting(false)
            }

            addTicketRow
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(displayedTickets.count) * 0.05 + 0.1), value: appeared)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 60)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: sortedByTime)
    }

    private func timelineRail(nodeCenters: [CGFloat], height: CGFloat) -> some View {
        Canvas { context, _ in
            guard let firstCenter = nodeCenters.first else { return }
            let x: CGFloat = 17

            let solidNodeRadius: CGFloat = 5
            var segmentStart = firstCenter + solidNodeRadius
            var path = Path()

            for center in nodeCenters.dropFirst() {
                let segmentEnd = center - solidNodeRadius
                if segmentEnd > segmentStart {
                    path.move(to: CGPoint(x: x, y: segmentStart))
                    path.addLine(to: CGPoint(x: x, y: segmentEnd))
                }
                segmentStart = center + solidNodeRadius
            }

            let addButtonCenter = height + 21
            if addButtonCenter > segmentStart {
                path.move(to: CGPoint(x: x, y: segmentStart))
                path.addLine(to: CGPoint(x: x, y: addButtonCenter))
            }
            context.stroke(
                path,
                with: .color(Color(red: 0.78, green: 0.70, blue: 0.62).opacity(0.55)),
                style: StrokeStyle(lineWidth: 2, lineCap: .butt)
            )
        }
        .frame(width: 34, height: height + 21, alignment: .topLeading)
    }

    private var isCitySource: Bool {
        if case .city = source { return true }
        return false
    }

    private func isRepresentative(_ ticket: TicketStub) -> Bool {
        guard case .city(let city) = source else { return false }
        return store.representativeTicket(forCity: city)?.id == ticket.id
    }

    private func setRepresentative(_ ticket: TicketStub) {
        guard case .city(let city) = source else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            store.cityRepresentatives[city] = ticket.id
        }
        store.persist()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "ticket")
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            Text("这个分集还是空的")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Button {
                showAddSheet = true
            } label: {
                Text("放入第一张票根")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(red: 0.88, green: 0.45, blue: 0.26)))
            }
            .buttonStyle(TicketPressStyle(scale: 0.95, tilt: 0))
        }
        .frame(maxWidth: .infinity)
    }

    private var addTicketRow: some View {

        HStack(alignment: .center, spacing: 0) {

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.88, green: 0.45, blue: 0.26))
                    .frame(width: 26, height: 26)
                    .background {
                        Circle()
                            .fill(.white.opacity(0.55))
                            .overlay(Circle().strokeBorder(
                                Color(red: 0.88, green: 0.45, blue: 0.26).opacity(0.6),
                                style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])))
                    }
                    .shadow(color: .black.opacity(0.10), radius: 5, y: 3)
            }
            .buttonStyle(TicketPressStyle(scale: 0.82, tilt: 0))
            .sensoryFeedback(.impact(weight: .light), trigger: showAddSheet)
            .frame(width: 34)

            Button {
                showAddSheet = true
            } label: {
                Text("放入新票根 · 实体票根或灵动作品")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.5))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                    .foregroundStyle(Color(red: 0.70, green: 0.55, blue: 0.45).opacity(0.5))
                            }
                    }
            }
            .buttonStyle(TicketPressStyle(scale: 0.96, tilt: 0))
            .padding(.leading, 12)
        }

        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}

struct TimelineRow: View {
    let ticket: TicketStub
    let isFirst: Bool
    let isLast: Bool
    let editMode: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isCitySource: Bool
    let isRepresentative: Bool
    var namespace: Namespace.ID
    let isHidden: Bool
    var onTap: () -> Void
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onSetRepresentative: () -> Void

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    var body: some View {
        content
            .padding(.leading, 12)
            .padding(.bottom, isLast ? 6 : 30)
            .padding(.leading, 34)

            .overlay(alignment: .topLeading) { nodeDot }
    }

    private var nodeDot: some View {
        VStack(spacing: 0) {
            if isFirst {
                Color.clear.frame(height: 8)
            } else {
                Color.clear.frame(height: 18)
            }
            ZStack {
                Circle()
                    .fill(Color(red: 0.88, green: 0.45, blue: 0.26).opacity(0.16))
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(Color(red: 0.88, green: 0.45, blue: 0.26))
                    .frame(width: 9, height: 9)
            }

            .anchorPreference(
                key: TimelineNodeBoundsPreferenceKey.self,
                value: .bounds,
                transform: { [ticket.id: $0] }
            )
        }
        .frame(width: 34)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Self.dayFormatter.string(from: ticket.captureDate))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.28))
                Text(Self.yearFormatter.string(from: ticket.captureDate))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(ticket.layout.localizedTitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.42, blue: 0.40))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.black.opacity(0.05)))
                if isRepresentative {
                    Label("代表票根", systemImage: "star.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.80, green: 0.55, blue: 0.10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.80, green: 0.55, blue: 0.10).opacity(0.14)))
                }
                Spacer()
                if editMode { moveControls }
            }

            Button(action: onTap) {
                TicketArtworkView(ticket: ticket)
                    .frame(maxWidth: ticket.layout == .vertical ? 220 : 420)
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 7)
                    .matchedGeometryEffect(id: ticket.id, in: namespace)
            }
            .buttonStyle(TicketPressStyle(scale: 0.96, tilt: -0.6))

            .allowsHitTesting(!editMode)
            .accessibilityHidden(editMode)
            .opacity(isHidden ? 0 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if editMode && isCitySource {
                Button(action: onSetRepresentative) {
                    Label(isRepresentative ? "当前代表票根" : "设为城市代表票根",
                          systemImage: isRepresentative ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.80, green: 0.55, blue: 0.10))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(red: 0.80, green: 0.55, blue: 0.10).opacity(0.12)))
                }
                .buttonStyle(TicketPressStyle(scale: 0.94, tilt: 0))
                .disabled(isRepresentative)
            }
        }
    }

    private var moveControls: some View {
        HStack(spacing: 8) {
            moveButton(icon: "chevron.up", enabled: canMoveUp, action: onMoveUp)
            moveButton(icon: "chevron.down", enabled: canMoveDown, action: onMoveDown)
        }
        .zIndex(2)
    }

    private func moveButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? .white : Color.gray.opacity(0.4))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 8).fill(
                    enabled ? Color(red: 0.20, green: 0.20, blue: 0.23) : Color.black.opacity(0.06)))
        }
        .buttonStyle(TicketPressStyle(scale: 0.85, tilt: 0))
        .disabled(!enabled)
    }
}

struct AddTicketSheet: View {
    let source: CollectionTimelineView.Source
    var onAdd: ([TicketStub]) -> Void

    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID> = []
    @State private var showPhysicalImport = false

    private var cityName: String? {
        if case .city(let city) = source { return city }
        return nil
    }

    private var existingTicketIDs: Set<String> {
        switch source {
        case .city(let city):
            return Set(store.tickets(inCity: city).map(\.ticketID))
        case .custom(let id):
            let tickets = store.customCollections
                .first(where: { $0.id == id })?.tickets ?? []
            return Set(tickets.map(\.ticketID))
        }
    }

    var body: some View {
        NavigationStack {
            artworkLibrary
            .navigationTitle("放入票根")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showPhysicalImport) {
                TicketOCRImportView(source: source) { tickets in
                    onAdd(tickets)
                    showPhysicalImport = false
                    dismiss()
                }
            }
        }
    }

    private var libraryItems: [(record: LingdongWorkRecord, included: Bool)] {
        let ids = existingTicketIDs
        return LingdongWorkArchive.records()
            .filter { $0.kind == CreationMode.travelTicket.rawValue }
            .map { ($0, ids.contains(Self.workTicketID($0))) }
    }

    private static func workTicketID(_ record: LingdongWorkRecord) -> String {
        "WORK-\(record.id.uuidString)"
    }

    private var artworkLibrary: some View {
        VStack(spacing: 0) {
            physicalImportEntry
            if libraryItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 34))
                        .foregroundStyle(.tertiary)
                    Text("还没有影像票根作品")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("去首页用「影像票根」模式制作并导出一张，\n作品会自动出现在这里")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(libraryItems, id: \.record.id) { item in
                            libraryCell(item.record, included: item.included)
                        }
                    }
                    .padding(16)
                }
                confirmBar
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var physicalImportEntry: some View {
        Button {
            showPhysicalImport = true
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.28, green: 0.57, blue: 0.60), Color(red: 0.82, green: 0.49, blue: 0.31)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "viewfinder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text("票根显影")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("也可从这里导入 · 原票取色 · 记忆重制")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.black.opacity(0.055)))
        }
        .buttonStyle(TicketPressStyle(scale: 0.97, tilt: 0))
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func libraryCell(_ record: LingdongWorkRecord, included: Bool) -> some View {
        let isSelected = selectedIDs.contains(record.id)
        let aspect = record.pixelHeight > 0
            ? CGFloat(record.pixelWidth) / CGFloat(record.pixelHeight)
            : 1
        return Button {
            guard !included else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected { selectedIDs.remove(record.id) }
                else { selectedIDs.insert(record.id) }
            }
        } label: {
            VStack(spacing: 7) {
                Group {
                    if let thumbnail = LingdongWorkArchive.image(for: record, thumbnail: true) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                    }
                }
                .aspectRatio(aspect, contentMode: .fit)
                .frame(maxWidth: record.pixelWidth < record.pixelHeight ? 110 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected
                                      ? Color(red: 0.88, green: 0.45, blue: 0.26)
                                      : .clear, lineWidth: 2)
                }
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.88, green: 0.45, blue: 0.26))
                    }
                    Text(record.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(Self.workDateText(record.createdAt))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
            .opacity(included ? 0.45 : 1)
            .overlay(alignment: .topTrailing) {
                if included {
                    Text("已在本分集")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.gray))
                        .padding(6)
                }
            }
        }
        .buttonStyle(TicketPressStyle(scale: 0.95, tilt: 0))
        .disabled(included)
    }

    private static let workDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()

    private static func workDateText(_ date: Date) -> String {
        workDateFormatter.string(from: date)
    }

    private var confirmBar: some View {
        VStack(spacing: 8) {
            Text("选中的作品会按拍摄时间自动插入时间轴的合适位置")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Button {
                let chosenRecords = LingdongWorkArchive.records()
                    .filter { selectedIDs.contains($0.id) }
                var newTickets: [TicketStub] = []
                for record in chosenRecords {

                    guard !existingTicketIDs.contains(Self.workTicketID(record)) else { continue }
                    let image = LingdongWorkArchive.image(for: record, thumbnail: false)

                    let imageData = record.fileName.hasSuffix("png")
                        ? image?.pngData()
                        : image?.jpegData(compressionQuality: 0.86)
                    var ticket = TicketStub.archivedWorkTicket(
                        workID: record.id,
                        title: record.title,
                        createdAt: record.createdAt,
                        city: cityName,
                        pixelWidth: record.pixelWidth,
                        pixelHeight: record.pixelHeight,
                        artworkImageData: imageData)
                    ticket.ticketID = Self.workTicketID(record)
                    newTickets.append(ticket)
                }
                onAdd(newTickets)
                dismiss()
            } label: {
                Text("放入时间轴（\(selectedIDs.count)）")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(selectedIDs.isEmpty
                                               ? Color.gray.opacity(0.4)
                                               : Color(red: 0.88, green: 0.45, blue: 0.26)))
            }
            .buttonStyle(TicketPressStyle(scale: 0.98, tilt: 0))
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

#Preview("时间轴") {
    NavigationStack {
        CollectionTimelineView(source: .city("温州"))
    }
    .environment(TicketStore())
}

private struct PiaogenceTimelineNavigationChrome: ViewModifier {
    let title: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .padding(.horizontal, 17)
                            .frame(height: 40)
                            .glassEffect(.regular, in: Capsule())
                    }
                }
        } else if #available(iOS 18.0, *) {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        } else {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
}
