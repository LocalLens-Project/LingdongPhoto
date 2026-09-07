import SwiftUI
import AVFoundation

enum PostalCreationStep {
    case template, photo
    func canSave(hasPhoto: Bool, busy: Bool, resolving: Bool) -> Bool {
        self == .photo && hasPhoto && !busy && !resolving
    }
}

enum PostalTemplate: Identifiable {
    case stamp(StampFormat), postcard(PostcardStyle)
    var id: String {
        switch self {
        case .stamp(let format): "stamp.\(format.rawValue)"
        case .postcard(let style): "postcard.\(style.rawValue)"
        }
    }
    var title: String {
        switch self {
        case .stamp(let format): format.title
        case .postcard(let style): style.title
        }
    }
    var size: CGSize {
        switch self {
        case .stamp(let format): (try? StampRenderer.template(format).size) ?? CGSize(width: 3, height: 4)
        case .postcard(let style): style.size
        }
    }
    var isPostcard: Bool { if case .postcard = self { true } else { false } }
    var requiresPro: Bool {
        switch self {
        case .stamp(let format): format.requiresPro
        case .postcard(let style): style.requiresPro
        }
    }
    func isAvailable(hasPro: Bool) -> Bool { !requiresPro || hasPro }
}


struct PostalGripLayout {
    let canvas: CGSize
    var paperBottom: CGFloat { canvas.height * 0.57 }
    var stride: CGFloat { min(canvas.width * 0.50, 300) }
    var handWidth: CGFloat { min(canvas.width * 0.33, 155) }
    var handSize: CGSize { CGSize(width: handWidth, height: handWidth * PostalHandArtwork.aspect) }
    var handOrigin: CGPoint {
        CGPoint(x: canvas.width / 2 - handSize.width * 0.37, y: paperBottom - handSize.height * 0.09)
    }
    func paperSize(_ native: CGSize) -> CGSize {
        let scale = min(min(canvas.width * 0.64, 300) / native.width,
                        max(60, paperBottom - 24) / native.height)
        return CGSize(width: native.width * scale, height: native.height * scale)
    }
    static func destination(current: Int, count: Int, translation: CGFloat, predicted: CGFloat, stride: CGFloat) -> Int {
        let travel = abs(translation) > stride * 0.18 ? translation : predicted
        let delta = abs(travel) < stride * 0.18 ? 0 : (travel < 0 ? 1 : -1)
        return min(max(0, count - 1), max(0, current + delta))
    }
}

enum PostalHandArtwork {

    static let image: UIImage? = {
        guard let cg = UIImage(named: "postal_hand")?.cgImage,
              let pixels = try? StampRenderer.rgba(cg) else { return nil }
        var left = cg.width, top = cg.height, right = 0, bottom = 0
        for y in 0..<cg.height { for x in 0..<cg.width where pixels[(y * cg.width + x) * 4 + 3] > 12 {
            left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
        } }
        guard right > left, bottom > top,
              let cropped = cg.cropping(to: CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)) else { return nil }
        return UIImage(cgImage: cropped)
    }()
    static var aspect: CGFloat { image.map { $0.size.height / $0.size.width } ?? 1.98 }
}

private struct PostalThumbMask: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.415, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY)); p.addLine(to: CGPoint(x: 0, y: rect.height * 0.20))
        p.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.20))
        p.addQuadCurve(to: CGPoint(x: rect.width * 0.282, y: rect.height * 0.07),
                      control: CGPoint(x: rect.width * 0.285, y: rect.height * 0.135))
        p.addQuadCurve(to: CGPoint(x: rect.width * 0.415, y: 0),
                      control: CGPoint(x: rect.width * 0.26, y: rect.height * 0.009))
        p.closeSubpath(); return p
    }
}

struct PostalBlankTemplate: View {
    let template: PostalTemplate
    var body: some View {
        switch template {
        case .stamp(let format):
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.94).mask(PostalStampSilhouette(format: format))
                if let processed = try? StampRenderer.template(format) {
                    Image(uiImage: processed.paper).resizable()
                }
            }
        case .postcard(let style):
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.99, green: 0.98, blue: 0.95)))
                var lines = Path()
                if style == .classic {
                    lines.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.10))
                    lines.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.90))
                    for row in 0..<3 {
                        let y = size.height * (0.59 + CGFloat(row) * 0.11)
                        lines.move(to: CGPoint(x: size.width * 0.59, y: y)); lines.addLine(to: CGPoint(x: size.width * 0.89, y: y))
                    }
                } else if style == .message || style == .instant {
                    let inset = size.width * 0.06
                    let photo = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height * 0.68)
                    context.fill(Path(photo), with: .color(.black.opacity(0.025)))
                    lines.addRect(photo)
                } else {
                    for i in 0..<180 {
                        let r = CGRect(x: CGFloat((i * 67) % 100) / 100 * size.width,
                                       y: CGFloat((i * 43) % 100) / 100 * size.height, width: 0.6, height: 1)
                        context.fill(Path(r), with: .color(.black.opacity(0.05)))
                    }
                }
                context.stroke(lines, with: .color(.black.opacity(0.10)), lineWidth: 0.6)
            }
        }
    }
}

struct PostalHeldCarousel: View {
    let templates: [PostalTemplate]
    @Binding var selection: Int
    let step: PostalCreationStep
    var preview: UIImage?
    var hasPhoto: Bool
    var isLoading: Bool
    var onPhoto: () -> Void
    var onPreview: () -> Void
    var hasPro: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let layout = PostalGripLayout(canvas: proxy.size)
            ZStack(alignment: .topLeading) {
                hand(layout, foreground: false).zIndex(-2).accessibilityHidden(true)
                if reduceMotion {
                    paper(templates[selection], index: selection, layout: layout, relative: 0)
                        .id(templates[selection].id).transition(.opacity)
                } else {
                    ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in

                        if index == selection || (step == .template && abs(index - selection) <= 1) {
                            let relative = CGFloat(index - selection) + drag / layout.stride
                            paper(template, index: index, layout: layout, relative: relative)
                        }
                    }
                }

                Ellipse().fill(.black.opacity(0.20)).frame(width: layout.handWidth * 0.22, height: 9)
                    .blur(radius: 3).position(x: proxy.size.width / 2 + 2, y: layout.paperBottom - 4)
                    .zIndex(1).allowsHitTesting(false).accessibilityHidden(true)
                hand(layout, foreground: true).zIndex(2)
                    .accessibilityElement(children: .ignore).accessibilityLabel("固定手部展示")
                    .accessibilityIdentifier("postal.hand")
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard step == .template, !reduceMotion, abs(value.translation.width) > abs(value.translation.height) else { return }
                    drag = max(-layout.stride, min(layout.stride, value.translation.width))
                }
                .onEnded { value in
                    guard step == .template else { return }
                    let next = abs(value.translation.width) > abs(value.translation.height)
                        ? PostalGripLayout.destination(current: selection, count: templates.count,
                            translation: value.translation.width, predicted: value.predictedEndTranslation.width, stride: layout.stride)
                        : selection
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.48, dampingFraction: 0.88)) {
                        selection = next; drag = 0
                    }
                })
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.78),
                                         .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .clipped()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("postal.templateCarousel")
            .accessibilityValue(templates[selection].title)

        }
    }

    private func hand(_ layout: PostalGripLayout, foreground: Bool) -> some View {
        Group {
            if let hand = PostalHandArtwork.image {
                Image(uiImage: hand).resizable().scaledToFit()
                    .mask { if foreground { PostalThumbMask() } else { Rectangle() } }
            }
        }
        .frame(width: layout.handSize.width, height: layout.handSize.height)
        .position(x: layout.handOrigin.x + layout.handSize.width / 2, y: layout.handOrigin.y + layout.handSize.height / 2)
        .transaction { $0.animation = nil }
        .allowsHitTesting(false)
    }

    private func paper(_ template: PostalTemplate, index: Int, layout: PostalGripLayout, relative: CGFloat) -> some View {
        let size = layout.paperSize(template.size)
        let active = index == selection
        let locked = !template.isAvailable(hasPro: hasPro)
        return ZStack {
            if step == .photo, active, let preview {
                Image(uiImage: preview).resizable().scaledToFit()
            } else { PostalBlankTemplate(template: template) }
            if locked {
                Image(systemName: "lock.fill").font(.system(size: 24, weight: .medium))
                .foregroundStyle(.black.opacity(0.65))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("此模板需要支持者 PRO")
                .accessibilityIdentifier(active ? "postal.templateLock" : "postal.neighborLock.\(index)")
            } else if active && (step == .photo || template.isPostcard) {
                if step == .photo {
                    ZStack {
                        Color.clear
                        if !hasPhoto {
                            Image(systemName: "plus").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(.black.opacity(0.45))
                        }
                        if isLoading { ProgressView().tint(.black) }
                    }
                    .contentShape(Rectangle())

                    .gesture(TapGesture(count: 2).exclusively(before: TapGesture())
                        .onEnded { gesture in
                            guard !isLoading else { return }
                            switch gesture {
                            case .first: if hasPhoto { onPreview() } else { onPhoto() }
                            case .second: onPhoto()
                            }
                        })
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(hasPhoto ? "更换照片" : "添加照片")
                    .accessibilityIdentifier("postal.pickPhoto")
                    .accessibilityAction { if !isLoading { onPhoto() } }
                    .accessibilityAction(named: Text("查看大图")) { if hasPhoto && !isLoading { onPreview() } }

                } else {
                    Image(systemName: "plus").font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(.black.opacity(0.25)).accessibilityHidden(true)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .zIndex(active ? 0 : -1)
        .shadow(color: .black.opacity(0.10), radius: 10, x: 3, y: 10)
        .rotationEffect(.degrees(-3 + Double(relative) * 5), anchor: .bottom)
        .scaleEffect(1 - min(abs(relative), 1) * 0.12, anchor: .bottom)
        .blur(radius: min(abs(relative) * 4, 7))
        .opacity(step == .template ? max(0.12, 1 - abs(relative) * 0.42) : 1)
        .position(x: layout.canvas.width / 2 + relative * layout.stride, y: layout.paperBottom - size.height / 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(template.title)
        .accessibilityIdentifier(active ? "postal.activeTemplate" : "postal.neighbor.\(index)")
        .accessibilityHidden(!active)
        .allowsHitTesting(active && step == .photo)
    }
}

struct PostalFlowPage<Actions: View>: View {
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @AppStorage("poeticNamesEnabled") private var poeticNamesEnabled = false
    @State private var supportPresented = false
    let title: String
    let step: PostalCreationStep
    let templates: [PostalTemplate]
    @Binding var selection: Int
    let model: PostalEditorModel
    var preview: UIImage?
    var busy: Bool
    var onBack: () -> Void
    var onPhoto: () -> Void
    var onPreview: () -> Void
    var onNext: () -> Void
    var onLibrary: () -> Void
    var onCamera: () -> Void
    @ViewBuilder var actions: Actions
    private var selectedTemplate: PostalTemplate { templates[selection] }
    private var templateAvailable: Bool { selectedTemplate.isAvailable(hasPro: supporterUnlocked) }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) { Image(systemName: step == .template ? "xmark" : "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel(step == .template ? "关闭制作" : "返回选择模板")
                        .accessibilityIdentifier("postal.back").disabled(busy)
                    Spacer()
                    Text(LocalizedStringKey(title))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black.opacity(0.55))
                    Spacer()
                    Menu {
                        Button("我的邮票", action: onLibrary)
                        if step == .photo && templateAvailable {
                            Button("从相册添加照片", action: onPhoto)
                            if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("拍摄照片", action: onCamera) }
                        }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("更多操作").disabled(busy || model.isLoading)
                }.font(.system(size: 18, weight: .regular)).buttonStyle(.plain).padding(.horizontal, 14)

                PostalHeldCarousel(templates: templates, selection: $selection, step: step,
                    preview: preview, hasPhoto: model.source != nil, isLoading: model.isLoading || busy,
                    onPhoto: onPhoto, onPreview: onPreview, hasPro: supporterUnlocked)
                    .frame(height: min(500, max(230, proxy.size.height * 0.57)))

                ScrollView {
                    VStack(spacing: 18) {
                        if step == .template {
                            VStack(spacing: 9) {
                                Text(verbatim: templates[selection].title).font(.title2.weight(.medium))
                                    .accessibilityIdentifier("postal.templateTitle")
                                    .accessibilityHint("向上或向下轻扫切换样式")
                                    .accessibilityAdjustableAction { direction in
                                        switch direction {
                                        case .increment: selection = min(templates.count - 1, selection + 1)
                                        case .decrement: selection = max(0, selection - 1)
                                        @unknown default: break
                                        }
                                    }
                                if selectedTemplate.requiresPro { ProBadge(compact: true) }
                                Text("左右滑动，选一个喜欢的样式").font(.subheadline).foregroundStyle(.black.opacity(0.45))
                                HStack(spacing: 7) {
                                    ForEach(templates.indices, id: \.self) { i in
                                        Circle().fill(.black.opacity(i == selection ? 0.7 : 0.15)).frame(width: 5, height: 5)
                                    }
                                }.padding(.top, 4).accessibilityHidden(true)
                            }
                            if templateAvailable {
                                Button(action: onNext) {
                                    Text("下一步").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                                        .foregroundStyle(.white).background(.black, in: Capsule())
                                }.buttonStyle(.plain).accessibilityIdentifier("postal.next")
                                    .padding(.top, 8)
                            } else { unlockButton }
                        } else if !templateAvailable {
                            Text("此模板需要支持者 PRO").font(.headline)
                            unlockButton
                        } else {
                            VStack(spacing: 7) {
                                Text(LocalizedStringKey(
                                    model.source == nil ? "点击 +，放入一张照片" : "这一刻，值得收藏"
                                ))
                                    .font(.title3.weight(.medium))
                                if model.source != nil {
                                    Text(LocalizedStringKey(
                                        templates[selection].isPostcard
                                            ? "双击可查看明信片大图"
                                            : "双击可查看邮票大图"
                                    ))
                                        .font(.caption2).foregroundStyle(.black.opacity(0.4))
                                        .accessibilityIdentifier("postal.previewHint")
                                    Text(verbatim: model.locationMessage).font(.caption).foregroundStyle(.black.opacity(0.45))
                                    if model.source?.metadata.hasLocation == true && model.source?.city == nil {
                                        Button("重试城市识别") { Task { await model.resolveCity() } }
                                            .font(.caption).disabled(model.isResolvingCity)
                                    }
                                } else {
                                    Text("照片只在本机处理").font(.caption).foregroundStyle(.black.opacity(0.4))
                                }
                            }
                            actions
                        }
                    }
                    .frame(width: max(0, min(proxy.size.width - 48, 400)))
                    .padding(.top, 4).padding(.bottom, 22)
                    .frame(maxWidth: .infinity)
                }.scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("postal.flowActions")
            }.frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(PostalBackground(tint: model.tint))
        .foregroundStyle(.black).tint(.black)
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $supportPresented) {
            SupportUsView {
                poeticNamesEnabled = true
            }
        }
        .onChange(of: supporterUnlocked) { _, unlocked in
            if unlocked { supportPresented = false }
        }
    }

    private var unlockButton: some View {
        Button { supportPresented = true } label: {
            HStack(spacing: 8) {
                AnimatedSupporterProBadge()
                Text("支持我们，解锁此模板").font(.headline)
                    .multilineTextAlignment(.center)
            }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.white).background(.black, in: Capsule())
        }
        .buttonStyle(.plain).padding(.top, 8)
        .accessibilityIdentifier("postal.unlockTemplate")
    }
}

struct PostalFlowAction: View {
    var title: String
    var symbol: String
    var enabled: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label {
                Text(LocalizedStringKey(title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } icon: {
                Image(systemName: symbol)
            }
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(enabled ? Color.black : Color.black.opacity(0.23))
        }.buttonStyle(.plain).disabled(!enabled)
    }
}


struct PostalPhotoImport: ViewModifier {
    let model: PostalEditorModel
    @Binding var picker: Bool
    @Binding var camera: Bool
    @State private var cameraReady = false
    @State private var location = PostalCaptureLocation()

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $picker) {
                PrivacyPreservingPhotoPicker(isPresented: $picker, selectionLimit: 1, colorScheme: .light) { selections in
                    if let selection = selections.first { Task { await model.load(selection) } }
                }.ignoresSafeArea()
            }
            .task(id: camera) {
                guard camera else { return }
                guard await AVCaptureDevice.requestAccess(for: .video) else {
                    model.error = "请在系统设置中允许相机访问后重试。"; camera = false; return
                }
                await location.prepare()
                guard camera, !Task.isCancelled else { location.stop(); return }
                cameraReady = true
            }
            .fullScreenCover(isPresented: $cameraReady, onDismiss: { camera = false; location.stop() }) {
                PostalCamera { image, date in
                    let fix = location.recentLocation
                    cameraReady = false; camera = false; location.stop()
                    if let image { Task { await model.acceptCamera(image: image, location: fix, capturedAt: date) } }
                }.ignoresSafeArea()
            }
            .onDisappear { if !cameraReady { location.stop() } }
    }
}
