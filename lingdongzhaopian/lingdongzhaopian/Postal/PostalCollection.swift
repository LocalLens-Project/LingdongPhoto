import SwiftUI

struct PostalStampLibrary: View {
    @Environment(\.dismiss) private var dismiss
    let store: PostalStore
    var city: PostalCity?
    var onSelect: ((PostalStamp) -> Void)?
    @State private var deleting: PostalStamp?
    @State private var notice: String?
    @State private var exporting = false
    private var stamps: [PostalStamp] { city.map { store.stamps(in: $0) } ?? store.stamps }
    var body: some View {
        NavigationStack {
            ScrollView {
                if stamps.isEmpty {
                    ContentUnavailableView("还没有邮票", systemImage: "rectangle.portrait.on.rectangle.portrait",
                        description: Text(LocalizedStringKey(
                            city == nil
                                ? "制作并收藏后，邮票会出现在这里。"
                                : "请用在这座城市拍摄的照片制作邮票。"
                        )))
                        .padding(.top, 80)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                    ForEach(stamps) { stamp in
                        VStack(spacing: 10) {
                            Button {
                                if let onSelect { onSelect(stamp); dismiss() }
                            } label: {
                                Group {
                                    if let image = store.image(stamp) {
                                        Image(uiImage: image).resizable().scaledToFit()
                                    } else { Image(systemName: "exclamationmark.triangle").font(.largeTitle) }
                                }.frame(height: 170).frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).disabled(onSelect == nil)
                                .accessibilityLabel("\(stamp.city?.name ?? "普通邮票".appLocalized)，\(PostalDate.chinese(stamp.addedAt))，\(stamp.format.title)")
                                .accessibilityIdentifier("postal.library.\(stamp.id)")
                            Text(verbatim: stamp.city?.name ?? "普通邮票".appLocalized).font(.subheadline.weight(.semibold))
                            Text(PostalDate.chinese(stamp.addedAt)).font(.caption2).foregroundStyle(.secondary)
                            HStack {
                                Button {
                                    Task {
                                        exporting = true; defer { exporting = false }
                                        do {
                                            guard let image = store.image(stamp, fullSize: true) else { throw PostalError.image }
                                            try await PostalPhotoWriter.save(image)
                                            notice = "已保存 PNG 到相册。".appLocalized
                                        } catch { notice = error.localizedDescription }
                                    }
                                } label: { Image(systemName: "square.and.arrow.down").frame(width: 44, height: 44) }
                                .accessibilityLabel("保存这枚邮票到相册").disabled(exporting)
                                Spacer()
                                Button(role: .destructive) { deleting = stamp } label: {
                                    Image(systemName: "trash").frame(width: 44, height: 44)
                                }.accessibilityLabel("删除这枚邮票")
                            }
                        }.padding(14).liquidGlass(in: RoundedRectangle(cornerRadius: 22), variant: .clear)
                    }
                }.padding(20).frame(maxWidth: 1000).frame(maxWidth: .infinity)
            }
            .background(PostalBackground(tint: .init()))
            .navigationTitle(city.map {
                String(format: "%@的邮票".appLocalized, $0.name)
            } ?? "我的邮票".appLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } } }
            .alert("删除邮票？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let deleting { do { try store.delete(deleting) } catch { notice = error.localizedDescription } }
                    deleting = nil
                }
            } message: { Text("此操作不会删除系统相册里的图片。城市默认封面会自动回退。") }
            .alert("邮票", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(notice ?? "") }
        }.tint(.primary)
    }
}

struct PostalCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var flight
    let store: PostalStore
    @State private var selected: PostalCitySlot?
    @State private var rotation = 0.0
    @State private var dragOrigin: Double?
    @State private var reducedBack = false
    @State private var changeMenu = false
    @State private var existing = false
    @State private var creating = false
    @State private var newCity = false
    @State private var library = false
    @State private var collectionNotes = false
    @State private var deleting = false
    @State private var notice: String?
    @State private var lockedCity: PostalCity?
    @State private var lockedHintGeneration = 0
    @State private var livePlayback = false
    init(store: PostalStore? = nil) { self.store = store ?? .shared }
    private var tint: PostalTint { selected?.tint ?? store.cities.first?.tint ?? .init() }
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("邮集").font(.largeTitle.bold())
                                Text("把走过的城市，收进一枚枚邮票。")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("已点亮 \(store.litCityCount) 城")
                                .font(.caption.weight(.semibold)).padding(12)
                                .liquidGlass(in: Capsule(), variant: .clear)
                                .accessibilityIdentifier("postal.litCount")
                        }
                        if PostalCollectionLanguage.usesProvinceLayout {
                            ForEach(PostalCollectionGrouping.groups(slots: store.cities, stamps: store.stamps)) { group in
                                provinceRow(group)
                            }
                        } else {
                            legacyCityGrid
                        }
                        Text(PostalCollectionLanguage.usesProvinceLayout
                             ? "灰色城市印章等待你的抵达。用带定位的照片制作并收藏邮票，即可点亮对应城市。"
                             : "城市来自你的邮票和票根定位。城市印章只是封面；收藏一枚带定位的邮票后才会点亮。")
                            .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
                        if PostalCollectionLanguage.usesProvinceLayout {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verbatim: PostalCityCollectionNotes.footer)
                                    .font(.caption2).foregroundStyle(.secondary).lineSpacing(4)
                                Button { collectionNotes = true } label: {
                                    Text(verbatim: PostalCityCollectionNotes.title)
                                        .font(.caption.weight(.medium)).frame(minHeight: 44)
                                }
                                .accessibilityIdentifier("postal.collectionNotes")
                            }
                        }
                    }.padding(24).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                }
                .blur(radius: selected == nil ? 0 : 10)
                .allowsHitTesting(selected == nil).accessibilityHidden(selected != nil)
                if let selected {
                    Color.black.opacity(0.30).ignoresSafeArea().onTapGesture { close() }
                        .accessibilityHidden(true)
                    center(selected).transition(.opacity).zIndex(1)
                }
            }
            .background(PostalBackground(tint: tint))
            .overlay(alignment: .bottom) {
                if let lockedCity, selected == nil {
                    Text(unlockHint(for: lockedCity))
                        .font(.footnote).multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .padding(18).frame(maxWidth: 540)
                        .accessibilityIdentifier("postal.unlockHint")
                        .allowsHitTesting(false).transition(.opacity)
                }
            }
            .task(id: lockedHintGeneration) {
                guard lockedCity != nil else { return }
                do {
                    try await Task.sleep(for: .seconds(4))
                    withAnimation(.easeOut(duration: 0.2)) { lockedCity = nil }
                } catch {  }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(selected == nil ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("我的邮票") { library = true }
                    Button { newCity = true } label: { Image(systemName: "plus") }.accessibilityLabel("制作新邮票")
                }
            }
            .task {
                do { try store.importTicketCities(TicketStore.shared.cityTickets) }
                catch { notice = error.localizedDescription }
                if let error = store.loadError { notice = error }
            }
            .confirmationDialog("更改默认邮票", isPresented: $changeMenu, titleVisibility: .visible) {
                Button("已有邮票") { existing = true }
                Button("从相册重新添加照片制作") { creating = true }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $existing) {
                if let selected {
                    PostalStampLibrary(store: store, city: selected.city) { stamp in
                        do { try store.choose(stamp, for: selected.city); resetRotation() }
                        catch { notice = error.localizedDescription }
                    }
                }
            }
            .sheet(isPresented: $creating) {
                if let selected {
                    StampStudio(store: store, targetCity: selected.city, onSaved: { _ in resetRotation() })
                }
            }
            .sheet(isPresented: $newCity) { StampStudio(store: store) }
            .sheet(isPresented: $library) { PostalStampLibrary(store: store) }
            .fullScreenCover(isPresented: $livePlayback) {
                if let selected, let stamp = store.representative(for: selected.city),
                   let videoURL = store.liveVideoURL(for: stamp),
                   let artwork = store.image(stamp, fullSize: true) {
                    PostalLivePlaybackView(
                        artwork: artwork,
                        videoURL: videoURL,
                        photoRectFraction: stamp.format.livePhotoRectFraction
                            ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                    )
                }
            }
            .sheet(isPresented: $collectionNotes) {
                if PostalCollectionLanguage.usesProvinceLayout { PostalCityCollectionNotes() }
            }
            .alert("删除当前邮票？", isPresented: $deleting) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    guard let selected, let stamp = store.representative(for: selected.city) else { return }
                    do { try store.delete(stamp); resetRotation() } catch { notice = error.localizedDescription }
                }
            } message: { Text("默认封面会回退到最早制作的邮票；没有邮票时显示城市印章。") }
            .alert("邮集", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(notice ?? "") }
        }.tint(.primary)
    }

    private var legacyCityGrid: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("城市邮票").font(.title3.weight(.semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 24) {
                ForEach(store.cities) { slot in
                    VStack(spacing: 8) {
                        Button { open(slot) } label: {
                            PostalCollectionArtworkFrame {
                                if selected?.id == slot.id { Color.clear }
                                else { flyingFront(slot, source: true) }
                            }
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("postal.city.\(slot.id)")
                            .accessibilityLabel(slotLabel(slot))
                            .accessibilityHint("放大邮票，可翻看背面或更改默认邮票")
                        Text(slot.city.name).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(LocalizedStringKey(
                            store.representative(for: slot.city) == nil ? "等待点亮" : "已点亮"
                        ))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ForEach(0..<3, id: \.self) { index in
                    Button { newCity = true } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(.primary.opacity(0.04))
                                Image(systemName: "sparkle.magnifyingglass").font(.largeTitle).opacity(0.4)
                            }.aspectRatio(0.75, contentMode: .fit)
                            Text("未探索").font(.caption.weight(.medium))
                            Text("下一站").font(.caption2)
                        }.foregroundStyle(.secondary)
                    }.buttonStyle(.plain).accessibilityLabel("未探索城市，添加照片制作邮票")
                        .accessibilityIdentifier("postal.unexplored.\(index)")
                }
            }
        }.accessibilityIdentifier("postal.legacyGrid")
    }
    private func provinceRow(_ group: PostalCollectionGrouping.Group) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().opacity(0.65)
            HStack {
                Text(group.title).font(.title3.weight(.semibold))
                    .accessibilityIdentifier("postal.provinceTitle.\(group.id)")
                Spacer()
                Text("\(group.unlockedCount) / \(group.entries.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityLabel("\(group.title)，已点亮 \(group.unlockedCount) 座城市")
                    .accessibilityIdentifier("postal.provinceCount.\(group.id)")
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(group.entries) { entry in
                        PostalProvinceStampCell(entry: entry, onOpen: { open(entry.slot) },
                                                onLocked: { showLockedHint(entry.slot.city) }) {
                            Group {
                                if selected?.id == entry.id { Color.clear }
                                else if entry.isUnlocked { flyingFront(entry.slot, source: true) }
                                else { front(entry.slot).saturation(0) }
                            }
                        }.containerRelativeFrame(.horizontal, count: 4, spacing: 14)
                    }
                }.padding(.vertical, 10)
            }
            .scrollIndicators(.hidden).scrollClipDisabled()
            .accessibilityIdentifier("postal.province.\(group.id)")
        }
    }
    private func unlockHint(for city: PostalCity) -> String {
        "用一张在\(city.name)拍摄、带有定位的照片制作并收藏邮票，即可解锁。"
    }
    private func showLockedHint(_ city: PostalCity) {
        withAnimation(.easeOut(duration: 0.15)) { lockedCity = city }
        lockedHintGeneration += 1
        UIAccessibility.post(notification: .announcement, argument: unlockHint(for: city))
    }
    private func center(_ slot: PostalCitySlot) -> some View {
        GeometryReader { proxy in
            let stamp = store.representative(for: slot.city)
            let format = stamp?.format ?? .classic
            let native = (try? StampRenderer.template(format).size) ?? CGSize(width: 3, height: 4)
            let scale = min(min(proxy.size.width * 0.64, 340) / native.width,
                            proxy.size.height * 0.49 / native.height)
            let size = CGSize(width: native.width * scale, height: native.height * scale)
            let centerY = min(proxy.size.height * 0.46, proxy.size.height - size.height / 2 - 185)
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if reduceMotion {
                        if reducedBack { PostalStampBack(slot: slot, stamp: stamp).transition(.opacity) }
                        else { front(slot).transition(.opacity) }
                    } else {
                        flyingFront(slot, source: true).modifier(PostalFlipFace(angle: rotation))
                        PostalStampBack(slot: slot, stamp: stamp)
                            .modifier(PostalFlipFace(angle: rotation + 180))
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(rotationGesture(width: size.width))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isShowingBack
                    ? String(
                        format: "%@，添加日期，%@，邮票背面".appLocalized,
                        slot.city.name,
                        PostalDate.chinese(stamp?.addedAt ?? slot.discoveredAt)
                    )
                    : slotLabel(slot))
                .accessibilityValue(String(
                    format: "%lld 度，%@".appLocalized,
                    Int64(rotation.rounded()),
                    (isShowingBack ? "背面" : "正面").appLocalized
                ))
                .accessibilityHint("左右拖动旋转，松手停在当前角度；向上或向下轻扫可分步旋转")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: setRotation(rotation + 45)
                    case .decrement: setRotation(rotation - 45)
                    @unknown default: break
                    }
                }
                .accessibilityAction(named: "查看背面") { setRotation(180) }
                .accessibilityAction(named: "查看正面") { setRotation(0) }
                .accessibilityIdentifier("postal.rotatingStamp")
                .position(x: proxy.size.width / 2, y: centerY)

                VStack(spacing: 12) {
                    Text(slot.city.name).font(.headline)
                    if let stamp, store.liveVideoURL(for: stamp) != nil {
                        PostalLiveBadge { livePlayback = true }
                    }
                    if reduceMotion {
                        Button(isShowingBack ? "查看正面" : "查看背面") { setRotation(isShowingBack ? 0 : 180) }
                            .font(.subheadline).accessibilityIdentifier("postal.reducedFlip")
                    } else {
                        Text("按住左右拖动 · 松手即停").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("更改默认邮票") { changeMenu = true }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("postal.changeDefault")
                    if stamp != nil {
                        Button("删除这枚邮票", role: .destructive) { deleting = true }.font(.caption)
                    }
                }
                .frame(width: min(340, proxy.size.width - 48), height: 200, alignment: .top)
                .position(x: proxy.size.width / 2, y: centerY + size.height / 2 + 24 + 85)

                Button { close() } label: {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .medium)).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).padding(.trailing, 16).padding(.top, 8)
                .accessibilityLabel("关闭邮票详情").accessibilityIdentifier("postal.closeDetail")
            }
        }
    }
    private var isShowingBack: Bool { reduceMotion ? reducedBack : PostalRotation.isBack(rotation) }
    private func rotationGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragOrigin == nil { dragOrigin = rotation }
                setRotation(PostalRotation.dragged(from: dragOrigin ?? rotation,
                    translation: value.translation.width, width: width))
            }
            .onEnded { _ in dragOrigin = nil }
    }
    private func setRotation(_ angle: Double) {

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { rotation = angle }
        if reduceMotion && reducedBack != PostalRotation.isBack(angle) {
            withAnimation(.easeInOut(duration: 0.18)) { reducedBack = PostalRotation.isBack(angle) }
        }
    }
    private func resetRotation() { rotation = 0; dragOrigin = nil; reducedBack = false }
    private func front(_ slot: PostalCitySlot) -> some View {
        PostalStampFront(slot: slot, stampImage: store.representative(for: slot.city).flatMap { store.image($0) })
    }
    @ViewBuilder private func flyingFront(_ slot: PostalCitySlot, source: Bool) -> some View {
        if reduceMotion { front(slot) }
        else { front(slot).matchedGeometryEffect(id: slot.id, in: flight, isSource: source) }
    }
    private func slotLabel(_ slot: PostalCitySlot) -> String {
        let stamp = store.representative(for: slot.city)
        return String(
            format: "%@，%@，%@".appLocalized,
            slot.city.name,
            (stamp == nil ? "未点亮，城市印章" : "已点亮").appLocalized,
            PostalDate.chinese(stamp?.addedAt ?? slot.discoveredAt)
        )
    }
    private func open(_ slot: PostalCitySlot) {
        lockedCity = nil
        resetRotation()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.85)) { selected = slot }
    }
    private func close() {
        resetRotation()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.9)) { selected = nil }
    }
}


private struct PostalCollectionArtworkFrame<Artwork: View>: View {
    @ViewBuilder var artwork: () -> Artwork

    var body: some View {
        Color.clear.aspectRatio(0.75, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    artwork()
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                }
            }
    }
}

private struct PostalProvinceStampCell<Artwork: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let entry: PostalCollectionGrouping.Entry
    let onOpen: () -> Void
    let onLocked: () -> Void
    @ViewBuilder var artwork: () -> Artwork
    @State private var attempts = 0

    var body: some View {
        VStack(spacing: 8) {
            Button {
                if entry.isUnlocked { onOpen() }
                else {
                    withAnimation(reduceMotion ? nil : .linear(duration: 0.38)) { attempts += 1 }
                    onLocked()
                }
            } label: {
                PostalCollectionArtworkFrame { artwork() }
                    .modifier(PostalLockedStampShake(phase: CGFloat(attempts), amount: reduceMotion ? 0 : 6))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .sensoryFeedback(.warning, trigger: attempts)
                .accessibilityLabel(entry.slot.city.name)
                .accessibilityValue(entry.isUnlocked ? "已点亮" : "未解锁")
                .accessibilityHint(entry.isUnlocked ? "放大邮票，可翻看背面或更改默认邮票" : "轻点查看解锁方式")
                .accessibilityIdentifier("postal.city.\(entry.id)")
            Text(entry.slot.city.name).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(entry.isUnlocked ? .primary : .secondary)
            Text(LocalizedStringKey(entry.isUnlocked ? "已点亮" : "未解锁"))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct PostalLockedStampShake: GeometryEffect {
    var phase: CGFloat
    var amount: CGFloat = 6
    var animatableData: CGFloat { get { phase } set { phase = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(phase * .pi * 6) * amount, y: 0))
    }
}

private struct PostalFlipFace: AnimatableModifier {
    var angle: Double
    var animatableData: Double { get { angle } set { angle = newValue } }
    func body(content: Content) -> some View {
        content.opacity(cos(angle * .pi / 180) > 0 ? 1 : 0)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

struct PostalStampFront: View {
    @Environment(\.colorScheme) private var colorScheme
    let slot: PostalCitySlot
    let stampImage: UIImage?
    var body: some View {
        Group {
            if let stampImage { Image(uiImage: stampImage).resizable().scaledToFit() }
            else {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack {
                        Color(uiColor: .secondarySystemBackground).mask(PostalStampSilhouette(format: .classic))
                        if let template = try? StampRenderer.template(.classic) {
                            Image(uiImage: template.paper).resizable()
                        }
                        ZStack {
                            Circle().stroke(slot.tint.ink(in: colorScheme).opacity(0.7), lineWidth: 1)
                            Circle().inset(by: width * 0.035).stroke(slot.tint.ink(in: colorScheme).opacity(0.5), lineWidth: 0.6)
                            Text(slot.city.name).font(.system(size: width * 0.10, weight: .semibold, design: .serif))
                                .minimumScaleFactor(0.5).lineLimit(1).padding(width * 0.06)
                        }.frame(width: width * 0.66, height: width * 0.66)
                            .position(x: width / 2, y: proxy.size.height * 0.46)
                        Text("城市印章").font(.system(size: width * 0.065)).tracking(1)
                            .position(x: width / 2, y: proxy.size.height * 0.80)
                    }.foregroundStyle(slot.tint.ink(in: colorScheme)).opacity(0.6)
                }
            }
        }.shadow(color: stampImage == nil ? .clear : slot.tint.color.opacity(0.45), radius: 16, y: 4)
    }
}

struct PostalStampBack: View {
    let slot: PostalCitySlot
    let stamp: PostalStamp?
    private var format: StampFormat { stamp?.format ?? .classic }
    private var tint: Color { slot.tint.ink(in: .light) }
    private var aspect: CGFloat {
        guard let size = try? StampRenderer.template(format).size else { return 0.75 }
        return size.width / size.height
    }
    var body: some View {
        Group {
            if format.isShaped {
                shapedBack
            } else {
                rectangularBack
            }
        }.aspectRatio(aspect, contentMode: .fit)
    }


    private var shapedBack: some View {
        GeometryReader { proxy in
            if let template = try? StampRenderer.template(format) {
                let scale = proxy.size.width / template.size.width
                let rect = template.contentRect
                let unit = min(rect.width, rect.height) * scale
                ZStack(alignment: .topLeading) {
                    Color(red: 0.96 + slot.tint.red * 0.035,
                          green: 0.96 + slot.tint.green * 0.035,
                          blue: 0.96 + slot.tint.blue * 0.035)
                    VStack(spacing: unit * 0.045) {
                        Text("灵动照片 · 城市邮票")
                            .font(.system(size: unit * 0.055))
                        Rectangle().fill(tint.opacity(0.25)).frame(height: 0.5)
                        Text(slot.city.name)
                            .font(.system(size: unit * 0.17, weight: .semibold, design: .serif))
                        Text("添加日期").font(.system(size: unit * 0.065))
                        Text(PostalDate.chinese(stamp?.addedAt ?? slot.discoveredAt))
                            .font(.system(size: unit * 0.085, weight: .medium))
                        Rectangle().fill(tint.opacity(0.25)).frame(height: 0.5)
                        Text("时光留印").font(.system(size: unit * 0.055))
                    }
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .frame(width: rect.width * scale * 0.86, height: rect.height * scale * 0.9)
                    .position(x: rect.midX * scale, y: rect.midY * scale)
                }
                .foregroundStyle(tint)
                .mask(PostalStampSilhouette(format: format))
            }
        }
    }

    private var rectangularBack: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let ring = min(width * 0.44, height * 0.44)
            ZStack(alignment: .topLeading) {
                Color(red: 0.96 + slot.tint.red * 0.035,
                      green: 0.96 + slot.tint.green * 0.035,
                      blue: 0.96 + slot.tint.blue * 0.035)
                VStack(spacing: 7) {
                    HStack {
                        Text("+"); Spacer()
                        Text("灵动照片 · 城市邮票").lineLimit(1).minimumScaleFactor(0.6)
                        Spacer(); Text("+")
                    }
                    .font(.system(size: width * 0.025))
                    Rectangle().fill(tint.opacity(0.22)).frame(height: 0.5)
                }.frame(width: width * 0.78).position(x: width * 0.5, y: height * 0.12)

                Canvas { context, size in
                    for row in 0..<5 {
                        var path = Path()
                        for step in 0...70 {
                            let x = size.width * CGFloat(step) / 70
                            let y = size.height * (CGFloat(row) + 0.5) / 5 + sin(CGFloat(step) / 70 * .pi * 2) * size.height * 0.065
                            if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(path, with: .color(tint.opacity(0.65)), lineWidth: 0.9)
                    }
                }
                .frame(width: width * 0.235, height: ring * 0.63)
                .position(x: width * 0.215, y: height * 0.55)
                .accessibilityHidden(true)

                ZStack {
                    Circle().stroke(tint.opacity(0.8), lineWidth: 1)
                    Circle().inset(by: 3).stroke(tint.opacity(0.35), lineWidth: 0.5)
                    VStack(spacing: ring * 0.055) {
                        Text(slot.city.name).font(.system(size: ring * 0.08, weight: .medium))
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("添加日期").font(.system(size: ring * 0.055))
                        Rectangle().fill(tint.opacity(0.25)).frame(height: 0.5)
                        Text(PostalDate.chinese(stamp?.addedAt ?? slot.discoveredAt))
                            .font(.system(size: ring * 0.07, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Rectangle().fill(tint.opacity(0.25)).frame(height: 0.5)
                        Text("时光留印").font(.system(size: ring * 0.05))
                    }.frame(width: ring * 0.76)
                }
                .frame(width: ring, height: ring)
                .position(x: width * 0.66, y: height * 0.55)

                VStack(spacing: 8) {
                    Rectangle().fill(tint.opacity(0.22)).frame(height: 0.5)
                    HStack { Text("+"); Spacer(); Text("影像珍藏"); Spacer(); Text("+") }
                        .font(.system(size: width * 0.024))
                    Text(LocalizedStringKey(
                        stamp == nil ? "等待第一枚城市邮票" : "以照片为证 · 珍藏每次抵达"
                    ))
                        .font(.system(size: width * 0.018)).lineLimit(1).minimumScaleFactor(0.7)
                }.frame(width: width * 0.78).position(x: width * 0.5, y: height * 0.865)
            }
            .foregroundStyle(tint)
            .mask(PostalStampSilhouette(format: format))
        }.aspectRatio(aspect, contentMode: .fit)
    }
}

struct PostalStampSilhouette: View {
    let format: StampFormat
    var body: some View {
        if let template = try? StampRenderer.template(format) {
            ZStack {
                Image(uiImage: template.paper).resizable()
                Image(uiImage: template.windowMask).resizable()
            }
        }
    }
}


enum PostalRotation {
    static func dragged(from start: Double, translation: CGFloat, width: CGFloat) -> Double {
        start + Double(translation / max(width, 1)) * 180
    }
    static func isBack(_ angle: Double) -> Bool {
        cos(angle * .pi / 180) < 0
    }
}
