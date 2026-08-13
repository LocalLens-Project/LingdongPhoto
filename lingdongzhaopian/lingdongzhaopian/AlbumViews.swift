// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

enum AlbumMotion {
    static let present = Animation.spring(response: 0.44, dampingFraction: 0.86)
    static let select = Animation.spring(response: 0.30, dampingFraction: 0.82)
    static let dismissDelay: Duration = .milliseconds(240)

    static let bottomTransition = AnyTransition
        .move(edge: .bottom)
        .combined(with: .opacity)
    static let cardTransition = AnyTransition
        .scale(scale: 0.92)
        .combined(with: .opacity)
}

struct AlbumRootView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = AlbumProjectStore()
    @State private var activeProjectID: UUID?
    @State private var templatePickerPresented = false
    @State private var deleteCandidate: AlbumProject?

    var body: some View {
        ZStack {
            // Keep a stable dark surface behind every cross-fade. Without this,
            // the full-screen cover's default white host briefly shows through.
            Color(red: 0.055, green: 0.066, blue: 0.061)
                .ignoresSafeArea()

            if let activeProjectID {
                AlbumEditorView(
                    store: store,
                    projectID: activeProjectID,
                    onBack: {
                        withAnimation(AlbumMotion.present) { self.activeProjectID = nil }
                    }
                )
                .transition(.opacity)
            } else {
                AlbumLibraryScreen(
                    store: store,
                    onClose: dismiss.callAsFunction,
                    onCreate: {
                        withAnimation(AlbumMotion.present) { templatePickerPresented = true }
                    },
                    onOpen: { id in
                        withAnimation(AlbumMotion.present) { activeProjectID = id }
                    },
                    onDelete: { project in
                        withAnimation(AlbumMotion.present) { deleteCandidate = project }
                    }
                )
                .transition(.opacity)
            }

            if templatePickerPresented {
                AlbumTemplatePickerScreen(
                    onCancel: {
                        withAnimation(AlbumMotion.present) { templatePickerPresented = false }
                    },
                    onCreate: { template, format in
                        let id = store.createProject(template: template, format: format)
                        withAnimation(AlbumMotion.present) {
                            templatePickerPresented = false
                            activeProjectID = id
                        }
                    }
                )
                .transition(AlbumMotion.bottomTransition)
                .zIndex(10)
            }

            if let deleteCandidate {
                AlbumConfirmationOverlay(
                    title: "删除《\(deleteCandidate.title)》？",
                    message: "相簿项目及其中保存的本地图片会被删除，此操作无法撤销。",
                    confirmTitle: "删除相簿",
                    isDestructive: true,
                    onCancel: {
                        withAnimation(AlbumMotion.present) { self.deleteCandidate = nil }
                    },
                    onConfirm: {
                        store.deleteProject(id: deleteCandidate.id)
                        withAnimation(AlbumMotion.present) { self.deleteCandidate = nil }
                    }
                )
                .transition(AlbumMotion.cardTransition)
                .zIndex(20)
            }
        }
        .background(Color(red: 0.055, green: 0.066, blue: 0.061).ignoresSafeArea())
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .task {
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--album-template-picker") {
                templatePickerPresented = true
            } else if arguments.contains("--album-demo") {
                let requestedTemplateID = arguments
                    .first(where: { $0.hasPrefix("--album-template=") })?
                    .dropFirst("--album-template=".count)
                    .description
                let projectID: UUID?
                if let project = store.projects.first {
                    projectID = project.id
                } else if let template = requestedTemplateID.flatMap({ requestedID in
                    AlbumTemplateCatalog.templates.first { $0.id == requestedID }
                }) ?? AlbumTemplateCatalog.templates.first {
                    projectID = store.createProject(
                        template: template,
                        format: template.defaultFormat
                    )
                } else {
                    projectID = nil
                }
                if let projectID {
                    if arguments.contains("--album-demo-images") {
                        seedAlbumDebugImagesIfNeeded(projectID: projectID)
                    }
                    if arguments.contains("--album-nav-test") {
                        // Let the library settle first so the test covers the
                        // in-app library/editor transition rather than launch UI.
                        try? await Task.sleep(for: .milliseconds(900))
                        withAnimation(AlbumMotion.present) { activeProjectID = projectID }
                        try? await Task.sleep(for: .milliseconds(1_250))
                        withAnimation(AlbumMotion.present) { activeProjectID = nil }
                    } else {
                        activeProjectID = projectID
                    }
                }
            }
#endif
        }
    }

#if DEBUG
    private func seedAlbumDebugImagesIfNeeded(projectID: UUID) {
        guard store.project(id: projectID)?.assets.isEmpty == true else { return }
        let palettes: [(UIColor, UIColor, String)] = [
            (.systemTeal, .systemGreen, "山野"),
            (.systemBlue, .systemIndigo, "海岸"),
            (.systemOrange, .systemPink, "黄昏"),
            (.systemMint, .systemCyan, "清晨"),
            (.systemBrown, .systemOrange, "途中"),
            (.systemBlue, .systemCyan, "灵动票根"),
            (.systemGreen, .systemYellow, "草原"),
            (.darkGray, .systemBlue, "归途")
        ]
        var assetIDs: [UUID] = []
        for (index, palette) in palettes.enumerated() {
            let size: CGSize
            if index == 5 {
                // A deliberately wide exported work verifies that aspect-fit
                // content reveals the page instead of a white slot rectangle.
                size = CGSize(width: 1_800, height: 650)
            } else if index.isMultiple(of: 3) {
                size = CGSize(width: 1_200, height: 1_600)
            } else {
                size = CGSize(width: 1_600, height: 1_080)
            }
            let image = UIGraphicsImageRenderer(size: size).image { renderer in
                let colors = [palette.0.cgColor, palette.1.cgColor] as CFArray
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0, 1]
                )
                if let gradient {
                    renderer.cgContext.drawLinearGradient(
                        gradient,
                        start: .zero,
                        end: CGPoint(x: size.width, y: size.height),
                        options: []
                    )
                }
                UIColor.white.withAlphaComponent(0.22).setFill()
                renderer.cgContext.fillEllipse(in: CGRect(
                    x: size.width * 0.16,
                    y: size.height * 0.18,
                    width: size.width * 0.58,
                    height: size.width * 0.58
                ))
                let title = palette.2 as NSString
                title.draw(
                    at: CGPoint(x: size.width * 0.08, y: size.height * 0.82),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: size.width * 0.08, weight: .semibold),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.86)
                    ]
                )
            }
            guard let data = image.jpegData(compressionQuality: 0.90) else { continue }
            let payload = AlbumImportedPayload(
                data: data,
                fileExtension: "jpg",
                image: image,
                captureDate: Date.now.addingTimeInterval(Double(index) * -86_400)
            )
            if let id = try? store.importAsset(
                payload,
                kind: index == 5 ? .work : .photo,
                workKind: index == 5 ? CreationMode.bubbleStamp.rawValue : nil,
                projectID: projectID
            ) {
                assetIDs.append(id)
            }
        }
        store.batchPlaceAssets(assetIDs, projectID: projectID)
    }
#endif
}

private struct AlbumLibraryScreen: View {
    @ObservedObject var store: AlbumProjectStore
    let onClose: () -> Void
    let onCreate: () -> Void
    let onOpen: (UUID) -> Void
    let onDelete: (AlbumProject) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var backdropColors: [AlbumColor] {
        store.projects.first?.palette ?? AlbumColor.fallback
    }

    var body: some View {
        ZStack {
            AlbumDynamicBackdrop(colors: backdropColors)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 46, height: 46)
                            .contentShape(Circle())
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .liquidGlass(in: Circle(), interactive: true, variant: .clear)
                    .accessibilityLabel("关闭影像相簿")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("影像相簿")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("在本地装订、翻阅与打印")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onCreate) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 48, height: 48)
                            .contentShape(Circle())
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .liquidGlass(in: Circle(), interactive: true, variant: .clear)
                    .accessibilityLabel("新建影像相簿")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 16)

                if store.projects.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(store.projects) { project in
                                AlbumLibraryCard(
                                    project: project,
                                    store: store,
                                    onOpen: { onOpen(project.id) },
                                    onDelete: { onDelete(project) }
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 42)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 126, height: 168)
                    .rotationEffect(.degrees(-5))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 126, height: 168)
                    .rotationEffect(.degrees(4))
                    .overlay {
                        Image(systemName: "book.pages")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.black.opacity(0.58))
                    }
            }
            .shadow(color: .black.opacity(0.24), radius: 24, y: 16)

            VStack(spacing: 7) {
                Text("把散落的影像装订成书")
                    .font(.title3.weight(.bold))
                Text("选择模板，加入普通照片或灵动作品\n整本预览后可直接生成印刷 PDF")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .foregroundStyle(.white)

            Button(action: onCreate) {
                Label("创建第一本相簿", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 54)
                    .contentShape(Capsule())
            }
            .buttonStyle(LiquidPressButtonStyle())
            .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
        }
        .padding(.horizontal, 28)
    }
}

private struct AlbumLibraryCard: View {
    let project: AlbumProject
    @ObservedObject var store: AlbumProjectStore
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                AlbumProjectMiniature(project: project, store: store)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.76, contentMode: .fit)
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(LiquidPressButtonStyle())

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text("\(project.pages.count) 页 · \(project.filledSlotCount) 个内容")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.54))
                }
                .foregroundStyle(.white)

                Spacer(minLength: 0)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(LiquidPressButtonStyle())
                .liquidGlass(in: Circle(), interactive: true, variant: .clear)
                .foregroundStyle(.white.opacity(0.82))
                .accessibilityLabel("删除相簿 \(project.title)")
            }
        }
    }
}

private struct AlbumProjectMiniature: View {
    let project: AlbumProject
    @ObservedObject var store: AlbumProjectStore

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.18))
            if let cover = project.pages.first {
                AlbumPageCanvas(
                    project: project,
                    page: cover,
                    store: store,
                    isEditing: false,
                    selectedSlotID: nil,
                    onSlotTap: { _ in },
                    onFreeformAdd: {}
                )
                .aspectRatio(project.format.aspectRatio, contentMode: .fit)
                .padding(12)
                .shadow(color: .black.opacity(0.28), radius: 15, y: 10)
            }
        }
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            variant: .clear
        )
    }
}

private struct AlbumTemplatePickerScreen: View {
    let onCancel: () -> Void
    let onCreate: (AlbumTemplateDescriptor, AlbumBookFormat) -> Void

    @State private var selectedTheme: AlbumTheme = .travel
    @State private var selectedTemplateID = AlbumTemplateCatalog.templates[0].id
    @State private var selectedFormat = AlbumTemplateCatalog.templates[0].defaultFormat
    @State private var showsVariants = false

    private var selectedTemplate: AlbumTemplateDescriptor {
        AlbumTemplateCatalog.templates.first { $0.id == selectedTemplateID }
            ?? AlbumTemplateCatalog.templates[0]
    }

    private var themeTemplates: [AlbumTemplateDescriptor] {
        AlbumTemplateCatalog.templates(for: selectedTheme)
    }

    var body: some View {
        ZStack {
            AlbumDynamicBackdrop(colors: selectedTemplate.colors)

            VStack(spacing: 0) {
                HStack {
                    Button {
                        if showsVariants {
                            withAnimation(AlbumMotion.present) { showsVariants = false }
                        } else {
                            onCancel()
                        }
                    } label: {
                        Image(systemName: showsVariants ? "chevron.left" : "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 46, height: 46)
                            .contentShape(Circle())
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .liquidGlass(in: Circle(), interactive: true, variant: .clear)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(showsVariants ? "\(selectedTheme.title)模板" : "选择相簿主题")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                        Text(showsVariants ? "挑选最适合这本相簿的视觉版式" : "每个主题均提供 3 套原创版式")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.54))
                    }
                    .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 14)

                ScrollView {
                    Group {
                        if showsVariants {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 14
                            ) {
                                ForEach(themeTemplates) { template in
                                    variantCard(template)
                                }
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            VStack(spacing: 16) {
                                ForEach(AlbumTheme.allCases, id: \.self) { theme in
                                    themeCard(theme)
                                }
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 190)
                }
                .scrollIndicators(.hidden)
            }

            VStack {
                Spacer()
                VStack(spacing: 14) {
                    if showsVariants {
                        HStack(spacing: 8) {
                            ForEach(AlbumBookFormat.allCases) { format in
                                Button {
                                    withAnimation(AlbumMotion.select) { selectedFormat = format }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Text(format.shortTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedFormat == format ? .black : .white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(
                                            selectedFormat == format ? Color.white : Color.clear,
                                            in: Capsule()
                                        )
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(LiquidPressButtonStyle())
                            }
                        }
                    }

                    Button {
                        if showsVariants {
                            onCreate(selectedTemplate, selectedFormat)
                        } else {
                            withAnimation(AlbumMotion.present) { showsVariants = true }
                        }
                    } label: {
                        Label(
                            showsVariants
                                ? "使用“\(selectedTemplate.title)”创建"
                                : "进入“\(selectedTemplate.title)”模板选择",
                            systemImage: showsVariants ? "book.closed" : "rectangle.stack"
                        )
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                }
                .padding(16)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous),
                    variant: .clear
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .task {
#if DEBUG
            guard ProcessInfo.processInfo.arguments.contains("--album-template-variants") else { return }
            selectTheme(.family)
            showsVariants = true
#endif
        }
    }

    private func selectTheme(_ theme: AlbumTheme) {
        let featured = AlbumTemplateCatalog.featuredTemplate(for: theme)
        withAnimation(AlbumMotion.select) {
            selectedTheme = theme
            selectedTemplateID = featured.id
            selectedFormat = featured.defaultFormat
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func themeCard(_ theme: AlbumTheme) -> some View {
        let featured = AlbumTemplateCatalog.featuredTemplate(for: theme)
        let templates = AlbumTemplateCatalog.templates(for: theme)
        let selected = selectedTheme == theme
        return Button { selectTheme(theme) } label: {
            HStack(spacing: 15) {
                ZStack {
                    ForEach(Array(templates.prefix(3).enumerated()), id: \.element.id) { index, template in
                        AlbumTemplateMiniature(template: template)
                            .frame(width: 78, height: 104)
                            .rotationEffect(.degrees(Double(index - 1) * 5))
                            .offset(x: CGFloat(index - 1) * 18)
                    }
                }
                .frame(width: 124, height: 122)

                VStack(alignment: .leading, spacing: 6) {
                    Label(theme.title, systemImage: theme.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(featured.title)
                        .font(.title3.weight(.bold))
                    Text("\(templates.count) 套版式 · \(featured.subtitle)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.leading)
                    Text(featured.detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(.white)

                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white.opacity(selected ? 1 : 0.36))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(selected ? Color.white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true, variant: .clear)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.56), lineWidth: 1.2)
            }
        }
    }

    private func variantCard(_ template: AlbumTemplateDescriptor) -> some View {
        let selected = selectedTemplateID == template.id
        return Button {
            withAnimation(AlbumMotion.select) {
                selectedTemplateID = template.id
                selectedFormat = template.defaultFormat
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                AlbumTemplateMiniature(template: template)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.78, contentMode: .fit)

                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                            .font(.subheadline.weight(.bold))
                    Text(template.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.36))
                }
            }
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 222, alignment: .top)
            .background(
                selected ? Color.white.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: true,
            variant: .clear
        )
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.56), lineWidth: 1.2)
            }
        }
    }
}

private struct AlbumTemplateMiniature: View {
    let template: AlbumTemplateDescriptor

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: template.colors.map(\.swiftUIColor),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                miniatureArt(size: size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.42), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    }

    @ViewBuilder
    private func miniatureArt(size: CGSize) -> some View {
        let ink = Color.black.opacity(0.66)
        switch template.style {
        case .editorialLetter, .quietCompanion, .cleanCanvas:
            VStack(spacing: size.height * 0.06) {
                Text(template.title)
                    .font(.system(size: max(7, size.width * 0.10), weight: .semibold, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Rectangle().fill(.white.opacity(0.88))
                    .frame(width: size.width * 0.58, height: size.height * 0.48)
                Text(template.style.shortTitle.uppercased())
                    .font(.system(size: max(4, size.width * 0.037), weight: .bold, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.62))
            }
            .padding(size.width * 0.10)
        case .coastPostcard, .trailJournal:
            VStack(spacing: size.height * 0.04) {
                HStack {
                    Text(template.title).font(.system(size: max(7, size.width * 0.09), weight: .bold, design: .rounded))
                    Spacer()
                    Circle().stroke(ink.opacity(0.5), lineWidth: 1).frame(width: size.width * 0.18)
                }
                Rectangle().fill(.white.opacity(0.88)).frame(height: size.height * 0.45)
                HStack { Rectangle().frame(height: 1); Spacer(); Text("POST").font(.system(size: 5, design: .monospaced)) }
                    .foregroundStyle(ink.opacity(0.55))
            }
            .padding(size.width * 0.10)
        case .filmDiary, .studioGrid, .growthNotes:
            VStack(spacing: size.height * 0.035) {
                HStack {
                    Text("01 / 24").font(.system(size: 5, weight: .bold, design: .monospaced))
                    Spacer()
                    Text(template.title).font(.system(size: max(7, size.width * 0.075), weight: .bold, design: .monospaced))
                }
                Rectangle().fill(.black.opacity(0.74)).frame(height: size.height * 0.50)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.76), lineWidth: 2).padding(size.width * 0.08)
                    }
                HStack(spacing: 3) {
                    ForEach(0..<8, id: \.self) { _ in Rectangle().fill(ink.opacity(0.55)).frame(height: 2) }
                }
            }
            .foregroundStyle(ink)
            .padding(size.width * 0.09)
        case .warmNeutral, .softArch:
            ZStack {
                Capsule().fill(.white.opacity(0.30)).frame(width: size.width * 0.74, height: size.height * 0.64)
                    .offset(x: -size.width * 0.08, y: size.height * 0.09)
                RoundedRectangle(cornerRadius: size.width * 0.28, style: .continuous)
                    .fill(.white.opacity(0.88))
                    .frame(width: size.width * 0.54, height: size.height * 0.52)
                Text(template.title).font(.system(size: max(7, size.width * 0.09), weight: .semibold, design: .serif))
                    .foregroundStyle(ink).offset(y: -size.height * 0.37)
            }
        case .sundayTable, .freeCollage:
            ZStack {
                Rectangle().fill(.white.opacity(0.88)).frame(width: size.width * 0.58, height: size.height * 0.40)
                    .rotationEffect(.degrees(-6)).offset(x: -size.width * 0.08, y: size.height * 0.08)
                Rectangle().fill(.white.opacity(0.72)).frame(width: size.width * 0.48, height: size.height * 0.30)
                    .rotationEffect(.degrees(7)).offset(x: size.width * 0.12, y: size.height * 0.22)
                Text(template.title).font(.system(size: max(7, size.width * 0.09), weight: .bold, design: .rounded))
                    .foregroundStyle(ink).offset(y: -size.height * 0.34)
            }
        case .littleUniverse, .rainbowPlay, .playfulPaws:
            ZStack {
                Circle().fill(.white.opacity(0.34)).frame(width: size.width * 0.78).offset(x: -size.width * 0.18, y: -size.height * 0.22)
                RoundedRectangle(cornerRadius: size.width * 0.12).fill(.white.opacity(0.88))
                    .frame(width: size.width * 0.60, height: size.height * 0.46)
                Image(systemName: template.theme.symbol)
                    .font(.system(size: max(14, size.width * 0.20), weight: .light))
                    .foregroundStyle(ink.opacity(0.52))
                Text(template.title).font(.system(size: max(7, size.width * 0.09), weight: .bold, design: .rounded))
                    .foregroundStyle(ink).offset(y: -size.height * 0.37)
            }
        }
    }
}

struct AlbumPageCanvas: View {
    let project: AlbumProject
    let page: AlbumPage
    @ObservedObject var store: AlbumProjectStore
    let isEditing: Bool
    let selectedSlotID: UUID?
    let onSlotTap: (AlbumSlot) -> Void
    let onFreeformAdd: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            ZStack {
                pageBackground
                pageDecorations(size: proxy.size)
                layoutBackgroundDecorations(size: proxy.size)

                ForEach(page.slots.sorted(by: { $0.zIndex < $1.zIndex })) { slot in
                    slotView(slot, in: bounds)
                }

                layoutForegroundDecorations(size: proxy.size)

                ForEach(page.textBlocks) { block in
                    textView(block, in: bounds)
                }

                if isEditing, page.layout == .freeform, page.slots.isEmpty {
                    Button(action: onFreeformAdd) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .light))
                            Text("添加第一项内容")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.black.opacity(0.50))
                        .frame(width: proxy.size.width * 0.62, height: proxy.size.height * 0.26)
                        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                                .foregroundStyle(.black.opacity(0.18))
                        }
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                } else if isEditing, page.layout == .freeform {
                    Button(action: onFreeformAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.60))
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.82), in: Circle())
                            .overlay {
                                Circle().stroke(.black.opacity(0.10), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .position(x: proxy.size.width - 28, y: 28)
                    .accessibilityLabel("继续添加自由内容")
                    .zIndex(200)
                }
            }
            .clipped()
        }
        .background(paperColor)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: AlbumPageAppearance.backgroundStops(project: project, page: page).map(Color.init(uiColor:)),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var paperColor: Color {
        Color(uiColor: AlbumPageAppearance.paperColor(for: project.resolvedDesignStyle))
    }

    @ViewBuilder
    private func layoutBackgroundDecorations(size: CGSize) -> some View {
        let accent = (project.palette.first ?? AlbumColor.fallback[0]).swiftUIColor
        switch page.layout {
        case .oceanPoster:
            ZStack {
                Rectangle().fill(.white.opacity(0.78))
                    .frame(width: size.width * 0.34, height: size.height * 0.11)
                    .position(x: size.width * 0.21, y: size.height * 0.52)
                Rectangle().fill(.white.opacity(0.62)).frame(width: 1)
                    .position(x: size.width * 0.50, y: size.height * 0.50)
            }
        case .cinematicSea:
            VStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle().fill(.black.opacity(0.18)).frame(width: 2.5, height: 2.5)
                }
            }
            .position(x: size.width * 0.50, y: size.height * 0.17)
        case .verticalTravelogue:
            HStack(spacing: size.width * 0.018) {
                ForEach(0..<11, id: \.self) { _ in
                    Circle().stroke(.black.opacity(0.15), lineWidth: 0.8)
                        .frame(width: size.width * 0.017)
                }
            }
            .position(x: size.width * 0.50, y: size.height * 0.035)
        case .postcardScrapbook:
            ZStack {
                accent.opacity(0.15)
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.82))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.90, y: size.height * 0.22),
                        control1: CGPoint(x: size.width * 0.32, y: size.height * 0.60),
                        control2: CGPoint(x: size.width * 0.55, y: size.height * 0.38)
                    )
                }
                .stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
        case .tornPaperJourney:
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.35, y: 0))
                for step in 0...14 {
                    let y = size.height * CGFloat(step) / 14
                    let x = size.width * (0.37 + (step.isMultiple(of: 2) ? 0.018 : -0.012))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: 0))
                path.closeSubpath()
            }
            .fill(.white.opacity(0.72))
        case .colorAtlas:
            ZStack {
                ForEach(1..<5, id: \.self) { index in
                    Rectangle().fill(accent.opacity(0.10)).frame(width: 1)
                        .position(x: size.width * CGFloat(index) / 5, y: size.height * 0.5)
                    Rectangle().fill(.black.opacity(0.06)).frame(height: 1)
                        .position(x: size.width * 0.5, y: size.height * CGFloat(index) / 5)
                }
            }
        case .clippedMemoir:
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.58))
                .frame(width: size.width * 0.42, height: size.height * 0.76)
                .rotationEffect(.degrees(-2))
                .position(x: size.width * 0.27, y: size.height * 0.50)
        case .galleryWindow:
            ZStack {
                Rectangle().fill(accent.opacity(0.88))
                Rectangle().fill(.black.opacity(0.82)).frame(width: size.width * 0.035)
                    .position(x: size.width * 0.50, y: size.height * 0.5)
                Rectangle().fill(.black.opacity(0.82)).frame(height: size.height * 0.035)
                    .position(x: size.width * 0.5, y: size.height * 0.08)
                Rectangle().fill(.black.opacity(0.82)).frame(height: size.height * 0.035)
                    .position(x: size.width * 0.5, y: size.height * 0.86)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func layoutForegroundDecorations(size: CGSize) -> some View {
        switch page.layout {
        case .oceanPoster:
            Rectangle()
                .fill(.white.opacity(0.78))
                .frame(width: size.width * 0.34, height: size.height * 0.11)
                .position(x: size.width * 0.21, y: size.height * 0.52)
                .allowsHitTesting(false)
        case .postcardScrapbook:
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.90 : 0.64))
                        .frame(width: size.width * (index.isMultiple(of: 2) ? 0.040 : 0.024))
                        .position(
                            x: size.width * [0.08, 0.18, 0.87, 0.92, 0.52][index],
                            y: size.height * [0.18, 0.78, 0.15, 0.72, 0.90][index]
                        )
                }
                Rectangle().fill(.white.opacity(0.52))
                    .frame(width: size.width * 0.14, height: size.height * 0.025)
                    .rotationEffect(.degrees(-8))
                    .position(x: size.width * 0.74, y: size.height * 0.67)
            }
            .allowsHitTesting(false)
        case .tornPaperJourney:
            Image(systemName: "paperclip")
                .font(.system(size: max(12, size.width * 0.055), weight: .light))
                .foregroundStyle(.black.opacity(0.34))
                .rotationEffect(.degrees(12))
                .position(x: size.width * 0.64, y: size.height * 0.10)
                .allowsHitTesting(false)
        case .clippedMemoir:
            Image(systemName: "paperclip")
                .font(.system(size: max(13, size.width * 0.065), weight: .light))
                .foregroundStyle(.black.opacity(0.38))
                .rotationEffect(.degrees(-14))
                .position(x: size.width * 0.43, y: size.height * 0.08)
                .allowsHitTesting(false)
        case .galleryWindow:
            ZStack {
                RoundedRectangle(cornerRadius: 1).stroke(.white.opacity(0.80), lineWidth: max(2, size.width * 0.012))
                    .frame(width: size.width * 0.40, height: size.height * 0.73)
                    .position(x: size.width * 0.26, y: size.height * 0.47)
                RoundedRectangle(cornerRadius: 1).stroke(.white.opacity(0.80), lineWidth: max(2, size.width * 0.012))
                    .frame(width: size.width * 0.40, height: size.height * 0.73)
                    .position(x: size.width * 0.74, y: size.height * 0.47)
            }
            .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func pageDecorations(size: CGSize) -> some View {
        switch project.resolvedDesignStyle {
        case .editorialLetter:
            Rectangle()
                .fill(.black.opacity(0.14))
                .frame(width: size.width * 0.14, height: 1)
                .position(x: size.width * 0.105, y: size.height * 0.055)
        case .coastPostcard:
            ZStack {
                Circle()
                    .stroke(.black.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: size.width * 0.12)
                    .position(x: size.width * 0.87, y: size.height * 0.075)
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(.black.opacity(0.10)).frame(width: size.width * 0.13, height: 1)
                    }
                }
                .position(x: size.width * 0.79, y: size.height * 0.075)
            }
        case .filmDiary:
            HStack(spacing: size.width * 0.018) {
                ForEach(0..<9, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.black.opacity(0.16))
                        .frame(width: size.width * 0.035, height: size.height * 0.008)
                }
            }
            .position(x: size.width * 0.5, y: size.height * 0.965)
        case .warmNeutral:
            HStack(spacing: 3) {
                ForEach(Array(project.palette.prefix(3).enumerated()), id: \.offset) { index, color in
                    Circle()
                        .fill(color.swiftUIColor.opacity(0.38))
                        .frame(width: 6 + CGFloat(index) * 2, height: 6 + CGFloat(index) * 2)
                }
            }
            .position(x: size.width * 0.86, y: size.height * 0.06)
        case .softArch:
            RoundedRectangle(cornerRadius: size.width * 0.18, style: .continuous)
                .fill((project.palette.last ?? AlbumColor.fallback.last!).swiftUIColor.opacity(0.16))
                .frame(width: size.width * 0.31, height: size.height * 0.19)
                .position(x: size.width * 0.88, y: size.height * 0.04)
        case .sundayTable, .freeCollage:
            ZStack {
                Rectangle()
                    .fill((project.palette.first ?? AlbumColor.fallback[0]).swiftUIColor.opacity(0.17))
                    .frame(width: size.width * 0.15, height: size.height * 0.018)
                    .rotationEffect(.degrees(-7))
                    .position(x: size.width * 0.15, y: size.height * 0.08)
                Rectangle()
                    .fill(.white.opacity(0.46))
                    .frame(width: size.width * 0.12, height: size.height * 0.016)
                    .rotationEffect(.degrees(6))
                    .position(x: size.width * 0.84, y: size.height * 0.89)
            }
        case .littleUniverse:
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill((project.palette.isEmpty ? AlbumColor.fallback : project.palette)[index % max(1, project.palette.count)].swiftUIColor.opacity(0.5))
                        .frame(width: index.isMultiple(of: 2) ? 6 : 4)
                }
            }
            .position(x: size.width * 0.14, y: size.height * 0.93)
        case .rainbowPlay:
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .trim(from: 0.03, to: 0.47)
                        .stroke(
                            (project.palette.isEmpty ? AlbumColor.fallback : project.palette)[index % max(1, project.palette.count)].swiftUIColor.opacity(0.34),
                            style: StrokeStyle(lineWidth: max(2, size.width * 0.012), lineCap: .round)
                        )
                        .frame(width: size.width * (0.20 + CGFloat(index) * 0.055))
                }
            }
            .rotationEffect(.degrees(8))
            .position(x: size.width * 0.84, y: size.height * 0.05)
        case .growthNotes:
            VStack(spacing: size.height * 0.018) {
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(.black.opacity(index.isMultiple(of: 2) ? 0.18 : 0.10))
                        .frame(width: size.width * (index.isMultiple(of: 2) ? 0.055 : 0.035), height: 1)
                }
            }
            .position(x: size.width * 0.04, y: size.height * 0.52)
        case .quietCompanion:
            Image(systemName: "pawprint.fill")
                .font(.system(size: max(7, size.width * 0.035)))
                .foregroundStyle(.black.opacity(0.08))
                .position(x: size.width * 0.88, y: size.height * 0.07)
        case .playfulPaws:
            HStack(spacing: 7) {
                Image(systemName: "pawprint.fill")
                Circle().frame(width: size.width * 0.018)
                Circle().frame(width: size.width * 0.010)
            }
            .font(.system(size: max(8, size.width * 0.040)))
            .foregroundStyle((project.palette.first ?? AlbumColor.fallback[0]).swiftUIColor.opacity(0.25))
            .rotationEffect(.degrees(-10))
            .position(x: size.width * 0.84, y: size.height * 0.08)
        case .trailJournal:
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.91))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.40, y: size.height * 0.86),
                    control1: CGPoint(x: size.width * 0.17, y: size.height * 0.82),
                    control2: CGPoint(x: size.width * 0.31, y: size.height * 0.96)
                )
            }
            .stroke(.black.opacity(0.13), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
        case .studioGrid:
            ZStack {
                Rectangle().fill(.black.opacity(0.08)).frame(width: 1)
                    .position(x: size.width * 0.08, y: size.height * 0.5)
                Rectangle().fill(.black.opacity(0.08)).frame(height: 1)
                    .position(x: size.width * 0.5, y: size.height * 0.07)
            }
        case .cleanCanvas:
            EmptyView()
        }
    }

    @ViewBuilder
    private func slotView(_ slot: AlbumSlot, in bounds: CGRect) -> some View {
        let frame = slot.frame.rect(in: bounds)
        let asset = slot.assetID.flatMap { id in project.assets.first { $0.id == id } }
        let canTransform = isEditing
            && selectedSlotID == slot.id
            && asset != nil
            && asset?.locksContentTransform == false
        slotContent(
            slot,
            asset: asset,
            frame: frame,
            bounds: bounds,
            showsPlaceholder: isEditing,
            canTransform: canTransform
        )
        .onTapGesture {
            guard isEditing else { return }
            onSlotTap(slot)
        }
        .allowsHitTesting(isEditing)
        .rotationEffect(.degrees(slot.rotation))
        .position(x: frame.midX, y: frame.midY)
        .zIndex(Double(slot.zIndex))
        .accessibilityLabel(
            slot.assetID == nil ? slot.expectation.placeholderTitle : "相簿内容，点击调整"
        )
    }

    private func slotContent(
        _ slot: AlbumSlot,
        asset: AlbumAsset?,
        frame: CGRect,
        bounds: CGRect,
        showsPlaceholder: Bool,
        canTransform: Bool
    ) -> some View {
        let isFramelessWork = asset?.kind == .work
        return ZStack {
            if !isFramelessWork {
                Color.white.opacity(0.94)
            }

            if let assetID = slot.assetID,
               let image = store.image(projectID: project.id, assetID: assetID, thumbnail: !isEditing) {
                AlbumPositionedImage(
                    image: image,
                    slot: slot,
                    viewport: frame.size,
                    canTransform: canTransform,
                    onCommit: { scale, offsetX, offsetY in
                        store.updateSlotContentTransform(
                            projectID: project.id,
                            pageID: page.id,
                            slotID: slot.id,
                            scale: scale,
                            offsetX: offsetX,
                            offsetY: offsetY
                        )
                    }
                )
            } else if showsPlaceholder {
                VStack(spacing: max(3, min(frame.width, frame.height) * 0.045)) {
                    Image(systemName: "plus")
                        .font(.system(size: max(12, min(frame.width, frame.height) * 0.13), weight: .light))
                    if frame.height > 45, frame.width > 65 {
                        Text(slot.expectation.placeholderTitle)
                            .font(.system(size: max(8, min(12, frame.width * 0.065)), weight: .semibold))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.black.opacity(0.44))
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(
            cornerRadius: max(1, CGFloat(slot.cornerRadius) * min(bounds.width, bounds.height)),
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(
                cornerRadius: max(1, CGFloat(slot.cornerRadius) * min(bounds.width, bounds.height)),
                style: .continuous
            )
            .stroke(
                selectedSlotID == slot.id
                    ? Color.accentColor.opacity(0.92)
                    : isFramelessWork
                        ? Color.clear
                        : Color.black.opacity(slot.assetID == nil && showsPlaceholder ? 0.18 : 0.08),
                style: StrokeStyle(
                    lineWidth: selectedSlotID == slot.id ? 2 : 0.8,
                    dash: slot.assetID == nil && showsPlaceholder ? [5, 4] : []
                )
            )
        }
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            if selectedSlotID == slot.id, asset?.locksContentTransform == true {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.46), in: Circle())
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
    }

    private func textView(_ block: AlbumTextBlock, in bounds: CGRect) -> some View {
        let frame = block.frame.rect(in: bounds)
        let attributedText = AlbumTypography.attributedString(
            for: block,
            project: project,
            page: page,
            bounds: bounds,
            frame: frame
        )
        return AlbumRenderedTextView(attributedText: attributedText)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
            .accessibilityLabel(block.text)
            .zIndex(100)
    }
}

private struct AlbumRenderedTextView: UIViewRepresentable {
    let attributedText: NSAttributedString

    func makeUIView(context: Context) -> AlbumRenderedTextUIView {
        let view = AlbumRenderedTextUIView()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: AlbumRenderedTextUIView, context: Context) {
        view.attributedText = attributedText
    }
}

private final class AlbumRenderedTextUIView: UIView {
    var attributedText = NSAttributedString() {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        AlbumTypography.draw(attributedText, in: bounds)
    }
}

private struct AlbumImageGestureState: Equatable {
    var translation: CGSize = .zero
    var magnification: CGFloat = 1
}

/// Keeps crop state inside the photo viewport while the user pans and pinches.
/// The committed values are normalized so editor, preview and PDF export share
/// exactly the same result at every output size.
private struct AlbumPositionedImage: View {
    let image: UIImage
    let slot: AlbumSlot
    let viewport: CGSize
    let canTransform: Bool
    let onCommit: (Double, Double, Double) -> Void

    @GestureState private var gestureState = AlbumImageGestureState()

    var body: some View {
        Group {
            if canTransform {
                positionedImage
                    .gesture(transformGesture)
            } else {
                positionedImage
            }
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
    }

    private var positionedImage: some View {
        let scale = effectiveScale
        let size = contentSize(scale: scale)
        let offset = clampedOffset(scale: scale, translation: gestureState.translation)
        return Image(uiImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            .offset(offset)
            .contentShape(Rectangle())
    }

    private var effectiveScale: CGFloat {
        max(1, min(6, CGFloat(slot.resolvedContentScale) * gestureState.magnification))
    }

    private var baseContentSize: CGSize {
        guard image.size.width > 0, image.size.height > 0,
              viewport.width > 0, viewport.height > 0 else { return viewport }
        let factor = slot.fit == .fill
            ? max(viewport.width / image.size.width, viewport.height / image.size.height)
            : min(viewport.width / image.size.width, viewport.height / image.size.height)
        return CGSize(width: image.size.width * factor, height: image.size.height * factor)
    }

    private func contentSize(scale: CGFloat) -> CGSize {
        CGSize(width: baseContentSize.width * scale, height: baseContentSize.height * scale)
    }

    private func clampedOffset(scale: CGFloat, translation: CGSize) -> CGSize {
        let size = contentSize(scale: scale)
        let maximumX = max(0, (size.width - viewport.width) / 2)
        let maximumY = max(0, (size.height - viewport.height) / 2)
        let stored = CGSize(
            width: CGFloat(slot.resolvedContentOffsetX) * viewport.width,
            height: CGFloat(slot.resolvedContentOffsetY) * viewport.height
        )
        return CGSize(
            width: max(-maximumX, min(maximumX, stored.width + translation.width)),
            height: max(-maximumY, min(maximumY, stored.height + translation.height))
        )
    }

    private var transformGesture: some Gesture {
        SimultaneousGesture(
            DragGesture(minimumDistance: 2),
            MagnificationGesture()
        )
        .updating($gestureState) { value, state, _ in
            state.translation = value.first?.translation ?? .zero
            state.magnification = value.second ?? 1
        }
        .onEnded { value in
            let magnification = value.second ?? 1
            let finalScale = max(1, min(6, CGFloat(slot.resolvedContentScale) * magnification))
            let finalOffset = clampedOffset(
                scale: finalScale,
                translation: value.first?.translation ?? .zero
            )
            onCommit(
                Double(finalScale),
                viewport.width > 0 ? Double(finalOffset.width / viewport.width) : 0,
                viewport.height > 0 ? Double(finalOffset.height / viewport.height) : 0
            )
        }
    }
}

struct AlbumConfirmationOverlay: View {
    let title: String
    let message: String
    let confirmTitle: String
    var isDestructive = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 16) {
                Image(systemName: isDestructive ? "trash" : "questionmark")
                    .font(.system(size: 23, weight: .semibold))
                    .frame(width: 54, height: 54)
                    .background(
                        (isDestructive ? Color.red : Color.blue).opacity(0.12),
                        in: Circle()
                    )
                    .foregroundStyle(isDestructive ? .red : .blue)

                VStack(spacing: 7) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Button("取消", action: onCancel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                    Button(confirmTitle, action: onConfirm)
                        .font(.headline)
                        .foregroundStyle(isDestructive ? .red : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                }
                .buttonStyle(LiquidPressButtonStyle())
            }
            .padding(22)
            .frame(maxWidth: 350)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 30, style: .continuous),
                variant: .regular
            )
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.25), radius: 30, y: 18)
        }
    }
}
