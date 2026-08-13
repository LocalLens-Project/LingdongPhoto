// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

private struct AlbumSourceRequest: Identifiable {
    let id = UUID()
    let pageID: UUID
    let slotID: UUID?
    let expectation: AlbumSlotExpectation
    let isBatch: Bool
}

struct AlbumEditorView: View {
    @ObservedObject var store: AlbumProjectStore
    let projectID: UUID
    let onBack: () -> Void

    @State private var selectedPageIndex = 0
    @State private var selectedSlotID: UUID?
    @State private var sourceRequest: AlbumSourceRequest?
    @State private var pendingPickerRequest: AlbumSourceRequest?
    @State private var pendingPickerKind: AlbumAssetKind = .photo
    @State private var pickerSelections: [PhotoPickerSelection] = []
    @State private var systemPickerPresented = false
    @State private var workPickerPresented = false
    @State private var workRecords: [LingdongWorkRecord] = []
    @State private var textEditorPresented = false
    @State private var addPagePresented = false
    @State private var pageOptionsPresented = false
    @State private var exportPanelPresented = false
    @State private var exportResult: AlbumExportedFile?
    @State private var sharedExport: AlbumExportedFile?
    @State private var documentExport: AlbumExportedFile?
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var previewPresented = false
    @State private var previewImages: [UUID: UIImage] = [:]
    @State private var pageDeleteRequested = false
    @State private var noticeTitle = ""
    @State private var noticeMessage: String?

    private var project: AlbumProject? { store.project(id: projectID) }

    var body: some View {
        ZStack {
            if previewPresented, let project {
                AlbumBookPreviewScreen(
                    project: project,
                    images: previewImages,
                    onClose: { withAnimation(.easeInOut(duration: 0.2)) { previewPresented = false } }
                )
                .transition(.opacity)
                .zIndex(100)
            } else if let project {
                editor(project)
                    // The editor chrome belongs to the book, not to the keyboard.
                    // Only the foreground text panel is allowed to adapt/scroll.
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            } else {
                Color.black.ignoresSafeArea()
                    .task { onBack() }
            }

            overlays
        }
        .fullScreenCover(isPresented: $systemPickerPresented) {
            PrivacyPreservingPhotoPicker(
                isPresented: $systemPickerPresented,
                selectionLimit: pickerLimit,
                colorScheme: .light
            ) { selections in
                pickerSelections = selections
            }
            .ignoresSafeArea()
        }
        .onChange(of: systemPickerPresented) { _, presented in
            guard !presented, !pickerSelections.isEmpty else { return }
            Task { await importPickerSelections() }
        }
        .sheet(item: $sharedExport) { item in
            SystemShareSheet(url: item.url)
                .preferredColorScheme(.light)
        }
        .sheet(item: $documentExport) { item in
            FileExportPicker(url: item.url)
                .preferredColorScheme(.light)
        }
        .task {
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard let project, let page = project.pages.first,
                  let slot = page.slots.first else { return }
            if let pageArgument = arguments.first(where: { $0.hasPrefix("--album-page=") }),
               let requestedIndex = Int(pageArgument.dropFirst("--album-page=".count)) {
                selectedPageIndex = min(max(0, requestedIndex), max(0, project.pages.count - 1))
            }
            if arguments.contains("--album-work-page"),
               let workPageIndex = project.pages.firstIndex(where: { page in
                   page.slots.contains { slot in
                       guard let assetID = slot.assetID else { return false }
                       return project.assets.first(where: { $0.id == assetID })?.kind == .work
                   }
               }) {
                selectedPageIndex = workPageIndex
            }
            if arguments.contains("--album-source-chooser") {
                sourceRequest = AlbumSourceRequest(
                    pageID: page.id,
                    slotID: slot.id,
                    expectation: slot.expectation,
                    isBatch: false
                )
            } else if arguments.contains("--album-preview") {
                previewImages = store.pageImages(projectID: project.id)
                previewPresented = true
            } else if arguments.contains("--album-export-panel") {
                exportPanelPresented = true
            } else if arguments.contains("--album-text-editor") {
                textEditorPresented = true
            } else if arguments.contains("--album-export-test")
                        || arguments.contains("--album-digital-export-test") {
                exportResult = try? AlbumExportService.export(
                    project: project,
                    images: store.pageImages(projectID: project.id),
                    kind: arguments.contains("--album-digital-export-test")
                        ? .digitalPages
                        : .printReady
                )
            }
#endif
        }
    }

    private func editor(_ project: AlbumProject) -> some View {
        GeometryReader { proxy in
            let pageIndex = min(selectedPageIndex, max(0, project.pages.count - 1))
            let page = project.pages[pageIndex]
            ZStack {
                AlbumDynamicBackdrop(colors: project.palette)

                VStack(spacing: 0) {
                    editorTopBar(project, availableWidth: proxy.size.width)
                    Spacer(minLength: 8)
                    pageWorkspace(project: project, page: page, availableSize: proxy.size)
                        .id(page.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    Spacer(minLength: 10)
                    pageStrip(
                        project: project,
                        selectedIndex: pageIndex,
                        availableWidth: proxy.size.width
                    )
                    selectedSlotID == nil
                        ? AnyView(defaultBottomBar(project: project, page: page, availableWidth: proxy.size.width))
                        : AnyView(slotInspector(project: project, page: page, availableWidth: proxy.size.width))
                }
                .frame(width: proxy.size.width, alignment: .center)
                .animation(AlbumMotion.select, value: selectedPageIndex)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .statusBarHidden(true)
    }

    private func editorTopBar(_ project: AlbumProject, availableWidth: CGFloat) -> some View {
        HStack(spacing: 10) {
            editorCircleButton(symbol: "chevron.left", label: "返回相簿列表", action: onBack)

            Button {
                // Album-level title and subtitle belong to the cover. Jump to
                // the first page instead of exposing them on every page.
                withAnimation(AlbumMotion.present) {
                    selectedPageIndex = 0
                    selectedSlotID = nil
                    textEditorPresented = true
                }
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(project.format.title) · 自动保存")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
            .accessibilityHint("前往封面编辑相簿名称与副标题")

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                editorCircleButton(symbol: "book.pages", label: "整本横屏预览") {
                    previewImages = store.pageImages(projectID: project.id)
                    withAnimation(.easeInOut(duration: 0.22)) { previewPresented = true }
                }
                editorCircleButton(symbol: "printer", label: "导出或打印相簿") {
                    withAnimation(AlbumMotion.present) { exportPanelPresented = true }
                }
            }
            .fixedSize()
        }
        .frame(width: max(260, availableWidth - 36))
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func pageWorkspace(
        project: AlbumProject,
        page: AlbumPage,
        availableSize: CGSize
    ) -> some View {
        let maxHeight = max(220, availableSize.height - 292)
        let widthFromHeight = maxHeight * project.format.aspectRatio
        let width = min(availableSize.width - 34, widthFromHeight)
        let height = width / project.format.aspectRatio
        return VStack(spacing: 8) {
            AlbumPageCanvas(
                project: project,
                page: page,
                store: store,
                isEditing: true,
                selectedSlotID: selectedSlotID,
                onSlotTap: { slot in handleSlotTap(slot, page: page) },
                onFreeformAdd: {
                    withAnimation(AlbumMotion.present) {
                        sourceRequest = AlbumSourceRequest(
                            pageID: page.id,
                            slotID: nil,
                            expectation: .any,
                            isBatch: false
                        )
                    }
                }
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .shadow(color: .black.opacity(0.30), radius: 24, y: 16)
            .overlay(alignment: .topLeading) {
                Text(page.role == .cover ? "封面" : page.role == .backCover ? "封底" : "第 \(selectedPageIndex + 1) 页")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .liquidGlass(in: Capsule(), variant: .clear)
                    .offset(x: 8, y: 8)
            }

            Text(page.layout.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
        }
    }

    private func pageStrip(
        project: AlbumProject,
        selectedIndex: Int,
        availableWidth: CGFloat
    ) -> some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(project.pages.enumerated()), id: \.element.id) { index, page in
                        Button {
                            withAnimation(AlbumMotion.select) {
                                selectedPageIndex = index
                                selectedSlotID = nil
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            AlbumPageCanvas(
                                project: project,
                                page: page,
                                store: store,
                                isEditing: false,
                                selectedSlotID: nil,
                                onSlotTap: { _ in },
                                onFreeformAdd: {}
                            )
                            .frame(width: 48 * project.format.aspectRatio, height: 48)
                            .overlay {
                                Rectangle()
                                    .stroke(
                                        index == selectedIndex ? Color.white : Color.white.opacity(0.18),
                                        lineWidth: index == selectedIndex ? 2 : 0.7
                                    )
                            }
                            .shadow(color: .black.opacity(0.20), radius: 4, y: 3)
                            .frame(
                                width: max(58, 48 * project.format.aspectRatio + 10),
                                height: 58
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(LiquidPressButtonStyle())
                        .id(page.id)
                        .accessibilityLabel(index == 0 ? "封面" : "第 \(index + 1) 页")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
            }
            .scrollIndicators(.hidden)
            .frame(width: availableWidth, height: 72)
            .onChange(of: selectedPageIndex) { _, index in
                guard project.pages.indices.contains(index) else { return }
                withAnimation { reader.scrollTo(project.pages[index].id, anchor: .center) }
            }
        }
    }

    private func defaultBottomBar(
        project: AlbumProject,
        page: AlbumPage,
        availableWidth: CGFloat
    ) -> some View {
        HStack(spacing: 9) {
            editorBarButton(symbol: "photo.stack", title: "批量导入") {
                guard project.emptySlotCount > 0 else {
                    showNotice("没有空位", "可以先添加新页面，或替换现有页面中的内容。")
                    return
                }
                withAnimation(AlbumMotion.present) {
                    sourceRequest = AlbumSourceRequest(
                        pageID: page.id,
                        slotID: nil,
                        expectation: .photo,
                        isBatch: true
                    )
                }
            }
            editorBarButton(symbol: "textformat", title: "文字") {
                withAnimation(AlbumMotion.present) { textEditorPresented = true }
            }
            editorBarButton(symbol: "plus.rectangle.on.rectangle", title: "加页") {
                withAnimation(AlbumMotion.present) { addPagePresented = true }
            }
            editorBarButton(symbol: "ellipsis", title: "页面") {
                withAnimation(AlbumMotion.present) { pageOptionsPresented = true }
            }
        }
        .frame(width: max(240, availableWidth - 48))
        .padding(10)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            variant: .clear
        )
        .padding(.bottom, 10)
    }

    private func slotInspector(
        project: AlbumProject,
        page: AlbumPage,
        availableWidth: CGFloat
    ) -> some View {
        let slot = page.slots.first { $0.id == selectedSlotID }
        let asset = slot?.assetID.flatMap { id in project.assets.first { $0.id == id } }
        let locksTransform = asset?.locksContentTransform == true
        return VStack(spacing: 8) {
            HStack(spacing: 7) {
                if asset?.kind != .work {
                    editorCompactButton(symbol: "arrow.up.left.and.arrow.down.right", label: "切换填满或完整显示") {
                        guard let slot else { return }
                        store.toggleFit(projectID: project.id, pageID: page.id, slotID: slot.id)
                    }
                }
                if let slot, asset != nil, !locksTransform {
                    editorCompactButton(symbol: "arrow.counterclockwise", label: "重置照片位置和缩放") {
                        store.resetSlotContentTransform(projectID: project.id, pageID: page.id, slotID: slot.id)
                    }
                } else if locksTransform {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .accessibilityLabel("影像票根已锁定，不能裁切或移动")
                }
                editorCompactButton(symbol: "arrow.triangle.2.circlepath", label: "替换内容") {
                    guard let slot else { return }
                    withAnimation(AlbumMotion.present) {
                        sourceRequest = AlbumSourceRequest(
                            pageID: page.id,
                            slotID: slot.id,
                            expectation: slot.expectation,
                            isBatch: false
                        )
                    }
                }
                if page.layout == .freeform, let slot {
                    editorCompactButton(symbol: "minus.magnifyingglass", label: "缩小") {
                        store.adjustFreeformSlot(projectID: project.id, pageID: page.id, slotID: slot.id, scale: 0.9)
                    }
                    editorCompactButton(symbol: "plus.magnifyingglass", label: "放大") {
                        store.adjustFreeformSlot(projectID: project.id, pageID: page.id, slotID: slot.id, scale: 1.1)
                    }
                    editorCompactButton(symbol: "rotate.left", label: "向左旋转") {
                        store.adjustFreeformSlot(projectID: project.id, pageID: page.id, slotID: slot.id, rotation: -2)
                    }
                }
                editorCompactButton(symbol: "trash", label: "移除内容", tint: .red) {
                    guard let slot else { return }
                    store.removeAssetFromSlot(projectID: project.id, pageID: page.id, slotID: slot.id)
                    withAnimation(AlbumMotion.select) { selectedSlotID = nil }
                }
                editorCompactButton(symbol: "xmark", label: "完成调整") {
                    withAnimation(AlbumMotion.select) { selectedSlotID = nil }
                }
            }
            if locksTransform {
                Text("影像票根保持完整比例，不能拖动、缩放或裁切")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
            } else if asset != nil {
                Text("在照片上拖动调整位置，双指捏合缩放")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }
            if page.layout == .freeform, let slot {
                HStack(spacing: 8) {
                    editorNudgeButton("arrow.left", x: -0.025, y: 0, slot: slot, project: project, page: page)
                    editorNudgeButton("arrow.up", x: 0, y: -0.025, slot: slot, project: project, page: page)
                    Text("移动自由内容")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.56))
                    editorNudgeButton("arrow.down", x: 0, y: 0.025, slot: slot, project: project, page: page)
                    editorNudgeButton("arrow.right", x: 0.025, y: 0, slot: slot, project: project, page: page)
                }
            }
        }
        .frame(width: max(240, availableWidth - 48))
        .padding(10)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            variant: .clear
        )
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var overlays: some View {
        if let sourceRequest {
            AlbumSourceChooserOverlay(
                expectation: sourceRequest.expectation,
                isBatch: sourceRequest.isBatch,
                workCount: LingdongWorkArchive.records().count,
                onCancel: {
                    withAnimation(AlbumMotion.present) { self.sourceRequest = nil }
                },
                onChoosePhoto: { openSystemPicker(kind: .photo, request: sourceRequest) },
                onChooseWork: { chooseWorkSource(request: sourceRequest) }
            )
            .transition(AlbumMotion.bottomTransition)
            .zIndex(20)
        }

        if workPickerPresented, let pendingPickerRequest {
            AlbumWorkPickerOverlay(
                records: workRecords,
                onCancel: {
                    withAnimation(AlbumMotion.present) { workPickerPresented = false }
                    self.pendingPickerRequest = nil
                },
                onImportFromPhotos: {
                    openSystemPicker(kind: .work, request: pendingPickerRequest)
                },
                onSelect: { record in importArchivedWork(record, request: pendingPickerRequest) }
            )
            .transition(AlbumMotion.bottomTransition)
            .zIndex(30)
        }

        if textEditorPresented, let project, !project.pages.isEmpty {
            let page = project.pages[min(selectedPageIndex, project.pages.count - 1)]
            AlbumTextEditorOverlay(
                project: project,
                page: page,
                onCancel: {
                    withAnimation(AlbumMotion.present) { textEditorPresented = false }
                },
                onSave: { title, subtitle, values, fontStyle in
                    if let title, let subtitle {
                        store.renameProject(id: project.id, title: title, subtitle: subtitle)
                    }
                    for (id, value) in values {
                        store.updateText(projectID: project.id, pageID: page.id, textID: id, value: value)
                    }
                    store.updatePageFont(projectID: project.id, pageID: page.id, fontStyle: fontStyle)
                    withAnimation(AlbumMotion.present) { textEditorPresented = false }
                }
            )
            .transition(AlbumMotion.bottomTransition)
            .zIndex(20)
        }

        if addPagePresented, let project {
            AlbumAddPageOverlay(
                theme: project.theme,
                onCancel: {
                    withAnimation(AlbumMotion.present) { addPagePresented = false }
                },
                onSelect: { layout in
                    store.addPage(projectID: project.id, layout: layout)
                    withAnimation(AlbumMotion.present) {
                        selectedPageIndex = max(1, (store.project(id: project.id)?.pages.count ?? 2) - 2)
                        addPagePresented = false
                    }
                }
            )
            .transition(AlbumMotion.bottomTransition)
            .zIndex(20)
        }

        if pageOptionsPresented, let project, !project.pages.isEmpty {
            let page = project.pages[min(selectedPageIndex, project.pages.count - 1)]
            AlbumPageOptionsOverlay(
                page: page,
                canMoveLeft: selectedPageIndex > 1,
                canMoveRight: selectedPageIndex < project.pages.count - 2,
                onCancel: {
                    withAnimation(AlbumMotion.present) { pageOptionsPresented = false }
                },
                onDuplicate: {
                    store.duplicatePage(projectID: project.id, pageID: page.id)
                    withAnimation(AlbumMotion.present) {
                        selectedPageIndex = min(selectedPageIndex + 1, (store.project(id: project.id)?.pages.count ?? 1) - 1)
                        pageOptionsPresented = false
                    }
                },
                onMoveLeft: {
                    store.movePage(projectID: project.id, pageID: page.id, direction: -1)
                    withAnimation(AlbumMotion.present) {
                        selectedPageIndex = max(1, selectedPageIndex - 1)
                        pageOptionsPresented = false
                    }
                },
                onMoveRight: {
                    store.movePage(projectID: project.id, pageID: page.id, direction: 1)
                    withAnimation(AlbumMotion.present) {
                        selectedPageIndex = min(project.pages.count - 2, selectedPageIndex + 1)
                        pageOptionsPresented = false
                    }
                },
                onDelete: {
                    withAnimation(AlbumMotion.present) {
                        pageOptionsPresented = false
                        pageDeleteRequested = true
                    }
                }
            )
            .transition(AlbumMotion.bottomTransition)
            .zIndex(20)
        }

        if pageDeleteRequested, let project, project.pages.indices.contains(selectedPageIndex) {
            let page = project.pages[selectedPageIndex]
            AlbumConfirmationOverlay(
                title: "删除这一页？",
                message: "页面排版会被移除，已经导入到项目中的原图仍保留在本地。",
                confirmTitle: "删除页面",
                isDestructive: true,
                onCancel: {
                    withAnimation(AlbumMotion.present) { pageDeleteRequested = false }
                },
                onConfirm: {
                    store.deletePage(projectID: project.id, pageID: page.id)
                    withAnimation(AlbumMotion.present) {
                        selectedPageIndex = min(selectedPageIndex, max(0, (store.project(id: project.id)?.pages.count ?? 1) - 1))
                        selectedSlotID = nil
                        pageDeleteRequested = false
                    }
                }
            )
            .transition(AlbumMotion.cardTransition)
            .zIndex(30)
        }

        if exportPanelPresented, let project {
            AlbumExportOverlay(
                project: project,
                lowResolutionCount: AlbumExportService.lowResolutionCount(project: project),
                isExporting: isExporting,
                onCancel: {
                    withAnimation(AlbumMotion.present) { exportPanelPresented = false }
                },
                onExport: { kind in generateExport(project: project, kind: kind) }
            )
            .transition(AlbumMotion.bottomTransition)
            .zIndex(20)
        }

        if let exportResult {
            AlbumExportCompleteOverlay(
                result: exportResult,
                onClose: {
                    withAnimation(AlbumMotion.present) { self.exportResult = nil }
                },
                onShare: { sharedExport = exportResult },
                onSave: { documentExport = exportResult },
                onPrint: { AlbumSystemPrintPresenter.present(url: exportResult.url) }
            )
            .transition(AlbumMotion.cardTransition)
            .zIndex(30)
        }

        if isImporting {
            AlbumProgressOverlay(title: "正在把内容装订进相簿…")
                .transition(.opacity)
                .zIndex(50)
        }

        if let noticeMessage {
            AlbumNoticeOverlay(
                title: noticeTitle,
                message: noticeMessage,
                onClose: {
                    withAnimation(AlbumMotion.present) { self.noticeMessage = nil }
                }
            )
            .transition(AlbumMotion.cardTransition)
            .zIndex(60)
        }
    }

    private var pickerLimit: Int {
        guard let request = pendingPickerRequest, request.isBatch else { return 1 }
        return min(50, max(1, project?.emptySlotCount ?? 1))
    }

    private func handleSlotTap(_ slot: AlbumSlot, page: AlbumPage) {
        if slot.assetID == nil {
            withAnimation(AlbumMotion.present) {
                sourceRequest = AlbumSourceRequest(
                    pageID: page.id,
                    slotID: slot.id,
                    expectation: slot.expectation,
                    isBatch: false
                )
            }
        } else {
            withAnimation(AlbumMotion.select) { selectedSlotID = slot.id }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func openSystemPicker(kind: AlbumAssetKind, request: AlbumSourceRequest) {
        let waitsForDismissal = sourceRequest != nil || workPickerPresented
        pendingPickerRequest = request
        pendingPickerKind = kind
        pickerSelections = []
        withAnimation(AlbumMotion.present) {
            sourceRequest = nil
            workPickerPresented = false
        }
        Task { @MainActor in
            if waitsForDismissal {
                try? await Task.sleep(for: AlbumMotion.dismissDelay)
            }
            systemPickerPresented = true
        }
    }

    private func chooseWorkSource(request: AlbumSourceRequest) {
        workRecords = LingdongWorkArchive.records()
        pendingPickerRequest = request
        if workRecords.isEmpty {
            openSystemPicker(kind: .work, request: request)
        } else {
            withAnimation(AlbumMotion.present) { sourceRequest = nil }
            Task { @MainActor in
                try? await Task.sleep(for: AlbumMotion.dismissDelay)
                withAnimation(AlbumMotion.present) { workPickerPresented = true }
            }
        }
    }

    private func importPickerSelections() async {
        guard let request = pendingPickerRequest else { return }
        withAnimation(AlbumMotion.present) { isImporting = true }
        defer {
            pickerSelections = []
            pendingPickerRequest = nil
            withAnimation(AlbumMotion.present) { isImporting = false }
        }
        do {
            var assetIDs: [UUID] = []
            for selection in pickerSelections.prefix(pickerLimit) {
                let payload = try await AlbumImageImporter.load(selection)
                let assetID = try store.importAsset(
                    payload,
                    kind: pendingPickerKind,
                    workKind: pendingPickerKind == .work ? "imported-work" : nil,
                    projectID: projectID
                )
                assetIDs.append(assetID)
            }
            if request.isBatch {
                store.batchPlaceAssets(assetIDs, projectID: projectID)
            } else if let first = assetIDs.first {
                store.placeAsset(
                    first,
                    projectID: projectID,
                    pageID: request.pageID,
                    slotID: request.slotID
                )
                withAnimation(AlbumMotion.select) { selectedSlotID = request.slotID }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            showNotice("无法导入", error.localizedDescription)
        }
    }

    private func importArchivedWork(_ record: LingdongWorkRecord, request: AlbumSourceRequest) {
        withAnimation(AlbumMotion.present) {
            workPickerPresented = false
            isImporting = true
        }
        Task { @MainActor in
            defer {
                pendingPickerRequest = nil
                withAnimation(AlbumMotion.present) { isImporting = false }
            }
            do {
                let payload = try LingdongWorkArchive.payload(for: record)
                let assetID = try store.importAsset(
                    payload,
                    kind: .work,
                    workKind: record.kind,
                    projectID: projectID
                )
                store.placeAsset(
                    assetID,
                    projectID: projectID,
                    pageID: request.pageID,
                    slotID: request.slotID
                )
                withAnimation(AlbumMotion.select) { selectedSlotID = request.slotID }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                showNotice("无法导入灵动作品", error.localizedDescription)
            }
        }
    }

    private func generateExport(project: AlbumProject, kind: AlbumPDFKind) {
        isExporting = true
        Task { @MainActor in
            await Task.yield()
            do {
                let result = try AlbumExportService.export(
                    project: project,
                    images: store.pageImages(projectID: project.id),
                    kind: kind
                )
                withAnimation(AlbumMotion.present) {
                    exportPanelPresented = false
                    exportResult = result
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                showNotice("无法导出相簿", error.localizedDescription)
            }
            isExporting = false
        }
    }

    private func showNotice(_ title: String, _ message: String) {
        noticeTitle = title
        withAnimation(AlbumMotion.present) { noticeMessage = message }
    }

    private func editorCircleButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(in: Circle(), interactive: true, variant: .clear)
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }

    private func editorBarButton(
        symbol: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidPressButtonStyle())
    }

    private func editorCompactButton(
        symbol: String,
        label: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .accessibilityLabel(label)
    }

    private func editorNudgeButton(
        _ symbol: String,
        x: Double,
        y: Double,
        slot: AlbumSlot,
        project: AlbumProject,
        page: AlbumPage
    ) -> some View {
        Button {
            store.adjustFreeformSlot(
                projectID: project.id,
                pageID: page.id,
                slotID: slot.id,
                x: x,
                y: y
            )
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 28)
                .contentShape(Capsule())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
    }
}

private struct AlbumSourceChooserOverlay: View {
    let expectation: AlbumSlotExpectation
    let isBatch: Bool
    let workCount: Int
    let onCancel: () -> Void
    let onChoosePhoto: () -> Void
    let onChooseWork: () -> Void

    var body: some View {
        AlbumBottomOverlay(onDismiss: onCancel) {
            VStack(alignment: .leading, spacing: 16) {
                overlayHeader(
                    title: isBatch ? "批量添加内容" : "添加到这个位置",
                    subtitle: isBatch ? "选择多张图片后会按照横竖比例自动填入空位" : "不同来源会采用不同的排版保护方式",
                    onClose: onCancel
                )

                sourceButton(
                    symbol: "photo.on.rectangle",
                    title: "从系统照片选择",
                    detail: "允许自动裁切、填满和参与背景取色",
                    recommended: expectation == .photo,
                    action: onChoosePhoto
                )

                sourceButton(
                    symbol: "wand.and.stars.inverse",
                    title: "从灵动作品选择",
                    detail: workCount > 0
                        ? "已有 \(workCount) 件本地导出作品，默认完整显示不裁字"
                        : "其他创作模式成功导出后会自动加入；也可从照片导入旧作品",
                    recommended: expectation == .work,
                    action: onChooseWork
                )

                Text("灵动作品库在设备本地自动建立；照片与作品只会复制到当前相簿，不会上传。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func sourceButton(
        symbol: String,
        title: String,
        detail: String,
        recommended: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .background(Color.black.opacity(0.06), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline)
                        if recommended {
                            Text("推荐")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .frame(height: 17)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
    }
}

struct LingdongWorkGrid: View {
    let records: [LingdongWorkRecord]
    var selectedIDs: Set<UUID> = []
    var showsSelection = false
    let onSelect: (LingdongWorkRecord) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(records) { record in
                let isSelected = selectedIDs.contains(record.id)
                Button { onSelect(record) } label: {
                    VStack(spacing: 7) {
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let image = LingdongWorkArchive.image(for: record, thumbnail: true) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(0.78, contentMode: .fit)
                            .background(Color.black.opacity(0.045))

                            if showsSelection {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(
                                        isSelected ? Color.white : Color.white.opacity(0.92),
                                        isSelected ? Color.blue : Color.black.opacity(0.32)
                                    )
                                    .padding(7)
                                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.blue : .clear, lineWidth: 3)
                        }

                        Text(record.kindTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(LiquidPressButtonStyle())
                .accessibilityLabel("\(record.kindTitle)，\(record.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityValue(showsSelection ? (isSelected ? "已选择" : "未选择") : "")
            }
        }
    }
}

private struct AlbumWorkPickerOverlay: View {
    let records: [LingdongWorkRecord]
    let onCancel: () -> Void
    let onImportFromPhotos: () -> Void
    let onSelect: (LingdongWorkRecord) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.50).ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(spacing: 0) {
                overlayHeader(
                    title: "选择灵动作品",
                    subtitle: "作品会完整放入页面，避免裁掉文字和票根信息",
                    onClose: onCancel
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 16)

                ScrollView {
                    LingdongWorkGrid(records: records, onSelect: onSelect)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                }

                Button(action: onImportFromPhotos) {
                    Label("从系统照片导入以前的作品", systemImage: "photo.badge.plus")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .contentShape(Capsule())
                }
                .buttonStyle(LiquidPressButtonStyle())
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.78)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 74)
        }
    }
}

private struct AlbumTextEditorOverlay: View {
    let project: AlbumProject
    let page: AlbumPage
    let onCancel: () -> Void
    let onSave: (String?, String?, [UUID: String], AlbumPageFontStyle) -> Void

    @State private var title: String
    @State private var subtitle: String
    @State private var values: [UUID: String]
    @State private var selectedFontStyle: AlbumPageFontStyle
    @FocusState private var focusedField: String?

    init(
        project: AlbumProject,
        page: AlbumPage,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String?, String?, [UUID: String], AlbumPageFontStyle) -> Void
    ) {
        self.project = project
        self.page = page
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: project.title)
        _subtitle = State(initialValue: project.subtitle)
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: page.textBlocks
            .filter { $0.isEditable && (page.role != .cover || !Self.isAlbumTitleStyle($0.style)) }
            .map { ($0.id, $0.text) }))
        _selectedFontStyle = State(initialValue: page.resolvedFontStyle)
    }

    private var editsAlbumInfo: Bool { page.role == .cover }

    private var editablePageBlocks: [AlbumTextBlock] {
        page.textBlocks.filter {
            $0.isEditable && (page.role != .cover || !Self.isAlbumTitleStyle($0.style))
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea().onTapGesture(perform: onCancel)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overlayHeader(
                        title: editsAlbumInfo ? "编辑封面文字" : "编辑本页文字",
                        subtitle: editsAlbumInfo ? "相簿名称只在封面修改" : "修改仅作用于当前页面",
                        onClose: onCancel
                    )

                    if editsAlbumInfo {
                        editorField("相簿名称", text: $title, focusID: "project-title")
                        editorField("相簿副标题", text: $subtitle, focusID: "project-subtitle")
                    }

                    pageFontPicker

                    ForEach(editablePageBlocks) { block in
                        editorField(textLabel(block.style), text: Binding(
                            get: { values[block.id] ?? "" },
                            set: { values[block.id] = $0 }
                        ), focusID: block.id.uuidString, multiline: block.style == .caption || block.style == .quote)
                    }

                    if !editsAlbumInfo, editablePageBlocks.isEmpty {
                        Text("当前页面没有可编辑文字，但仍可为本页选择字体。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }

                    Button {
                        onSave(
                            editsAlbumInfo ? title : nil,
                            editsAlbumInfo ? subtitle : nil,
                            values,
                            selectedFontStyle
                        )
                    } label: {
                        Text("保存文字")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: 430, maxHeight: 650)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.vertical, 62)
        }
        .task {
#if DEBUG
            guard ProcessInfo.processInfo.arguments.contains("--album-keyboard-test") else { return }
            try? await Task.sleep(for: .milliseconds(500))
            focusedField = "project-subtitle"
#endif
        }
    }

    private var pageFontPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("本页字体")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    ForEach(AlbumPageFontStyle.allCases) { fontStyle in
                        Button {
                            withAnimation(AlbumMotion.select) { selectedFontStyle = fontStyle }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            VStack(spacing: 4) {
                                Text(fontStyle.sample)
                                    .font(sampleFont(fontStyle))
                                Text(fontStyle.title)
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(selectedFontStyle == fontStyle ? Color.white : Color.primary)
                            .frame(width: 78, height: 58)
                            .background(
                                selectedFontStyle == fontStyle ? Color.black.opacity(0.76) : Color.primary.opacity(0.045),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(LiquidPressButtonStyle())
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sampleFont(_ fontStyle: AlbumPageFontStyle) -> Font {
        switch fontStyle {
        case .template, .modern: .system(size: 18, weight: .medium)
        case .songti: .custom("Songti SC", size: 18)
        case .rounded: .system(size: 18, weight: .medium, design: .rounded)
        case .handwritten: .custom("Kaiti SC", size: 18)
        case .monospaced: .system(size: 17, weight: .medium, design: .monospaced)
        }
    }

    private static func isAlbumTitleStyle(_ style: AlbumTextStyle) -> Bool {
        style == .coverTitle || style == .coverSubtitle
    }

    private func editorField(
        _ label: String,
        text: Binding<String>,
        focusID: String,
        multiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if multiline {
                TextField(label, text: text, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: focusID)
                    .padding(13)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                TextField(label, text: text)
                    .focused($focusedField, equals: focusID)
                    .padding(13)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func textLabel(_ style: AlbumTextStyle) -> String {
        switch style {
        case .coverTitle: "页面标题"
        case .coverSubtitle: "页面副标题"
        case .headline: "标题"
        case .body: "正文"
        case .caption: "注脚"
        case .quote: "寄语"
        case .pageNumber: "页码"
        }
    }
}

private struct AlbumAddPageOverlay: View {
    let theme: AlbumTheme
    let onCancel: () -> Void
    let onSelect: (AlbumPageLayout) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        AlbumBottomOverlay(onDismiss: onCancel) {
            VStack(alignment: .leading, spacing: 16) {
                overlayHeader(title: "添加页面", subtitle: "新页面会插入到封底之前", onClose: onCancel)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AlbumTemplateCatalog.addableLayouts) { layout in
                        Button { onSelect(layout) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: layout.symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.05), in: Circle())
                                Text(layout.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.primary)
                            .padding(11)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(LiquidPressButtonStyle())
                    }
                }
            }
        }
    }
}

private struct AlbumPageOptionsOverlay: View {
    let page: AlbumPage
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let onCancel: () -> Void
    let onDuplicate: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onDelete: () -> Void

    var body: some View {
        AlbumBottomOverlay(onDismiss: onCancel) {
            VStack(alignment: .leading, spacing: 14) {
                overlayHeader(title: "页面操作", subtitle: page.layout.title, onClose: onCancel)
                option("doc.on.doc", "复制这一页", enabled: page.role == .content, action: onDuplicate)
                option("arrow.left", "向前移动", enabled: canMoveLeft && page.role == .content, action: onMoveLeft)
                option("arrow.right", "向后移动", enabled: canMoveRight && page.role == .content, action: onMoveRight)
                option("trash", "删除这一页", tint: .red, enabled: page.role == .content, action: onDelete)
            }
        }
    }

    private func option(
        _ symbol: String,
        _ title: String,
        tint: Color = .primary,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 52)
                .padding(.horizontal, 15)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.30)
    }
}

private struct AlbumExportOverlay: View {
    let project: AlbumProject
    let lowResolutionCount: Int
    let isExporting: Bool
    let onCancel: () -> Void
    let onExport: (AlbumPDFKind) -> Void

    @State private var selectedKind = AlbumPDFKind.printReady

    var body: some View {
        AlbumBottomOverlay(onDismiss: isExporting ? {} : onCancel) {
            VStack(alignment: .leading, spacing: 16) {
                overlayHeader(title: "导出整本相簿", subtitle: "\(project.format.title) · \(project.pages.count) 页", onClose: onCancel)

                ForEach(AlbumPDFKind.allCases) { kind in
                    Button {
                        withAnimation(AlbumMotion.select) { selectedKind = kind }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 19, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .background(Color.black.opacity(0.05), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title).font(.headline)
                                Text(kind.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: selectedKind == kind ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(selectedKind == kind ? .blue : .secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(13)
                        .background(
                            selectedKind == kind ? Color.blue.opacity(0.07) : Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 21, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                }

                if project.emptySlotCount > 0 {
                    Label("仍有 \(project.emptySlotCount) 个空位；导出时会保持留白，不会显示加号。", systemImage: "square.dashed")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if lowResolutionCount > 0 {
                    Label("有 \(lowResolutionCount) 张图片用于大幅打印时可能不够清晰。", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button { onExport(selectedKind) } label: {
                    Group {
                        if isExporting {
                            ProgressView().tint(.primary)
                        } else {
                            Label("生成 \(selectedKind.title)", systemImage: selectedKind.symbol)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(Capsule())
                }
                .buttonStyle(LiquidPressButtonStyle())
                .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                .disabled(isExporting)
            }
        }
    }
}

private struct AlbumExportCompleteOverlay: View {
    let result: AlbumExportedFile
    let onClose: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onPrint: () -> Void

    var body: some View {
        AlbumBottomOverlay(onDismiss: onClose) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.green)
                VStack(spacing: 5) {
                    Text("整本相簿已生成")
                        .font(.title3.weight(.bold))
                    Text(result.kind.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    resultButton("square.and.arrow.up", "分享", action: onShare)
                    resultButton("folder", "存入文件", action: onSave)
                    if result.kind == .printReady {
                        resultButton("printer", "立即打印", action: onPrint)
                    }
                }
                Button("完成", action: onClose)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                    .buttonStyle(LiquidPressButtonStyle())
            }
        }
    }

    private func resultButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(LiquidPressButtonStyle())
    }
}

private struct AlbumProgressOverlay: View {
    let title: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()
            VStack(spacing: 13) {
                ProgressView().controlSize(.large)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 24)
            .frame(height: 128)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}

private struct AlbumNoticeOverlay: View {
    let title: String
    let message: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.46).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(title).font(.title3.weight(.bold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("好", action: onClose)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .liquidGlass(in: Capsule(), interactive: true, variant: .clear)
                    .buttonStyle(LiquidPressButtonStyle())
            }
            .padding(22)
            .frame(maxWidth: 350)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, 24)
        }
    }
}

private struct AlbumBottomOverlay<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.46)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            content()
                .padding(20)
                .background(.regularMaterial, in: UnevenRoundedRectangle(
                    topLeadingRadius: 34,
                    topTrailingRadius: 34
                ))
                .shadow(color: .black.opacity(0.24), radius: 28, y: -8)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

@ViewBuilder
private func overlayHeader(
    title: String,
    subtitle: String,
    onClose: @escaping () -> Void
) -> some View {
    HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.bold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 10)
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(in: Circle(), interactive: true, variant: .clear)
    }
}
