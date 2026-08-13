// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct AlbumBookPreviewScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let project: AlbumProject
    let images: [UUID: UIImage]
    let onClose: () -> Void

    @State private var bookPages: [UIImage] = []
    @State private var currentSpread = 0
    @State private var isPreparing = true

    private var spreadCount: Int { bookPages.count / 2 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AlbumDynamicBackdrop(colors: project.palette)

                if isPreparing {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text("正在装订整本预览…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                    }
                } else if reduceMotion {
                    TabView(selection: $currentSpread) {
                        ForEach(0..<spreadCount, id: \.self) { index in
                            staticSpread(index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    AlbumPageCurlView(images: bookPages, currentSpread: $currentSpread)
                        .ignoresSafeArea()
                }

                VStack {
                    HStack(spacing: 12) {
                        Button(action: closePreview) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 46, height: 46)
                                .contentShape(Circle())
                        }
                        .buttonStyle(LiquidPressButtonStyle())
                        .liquidGlass(in: Circle(), interactive: true, variant: .clear)
                        .accessibilityLabel("关闭整本预览")

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("整本预览 · \(project.pages.count) 页")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(min(currentSpread + 1, max(spreadCount, 1))) / \(max(spreadCount, 1))")
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .liquidGlass(in: Capsule(), variant: .clear)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                    Spacer()
                }

                if proxy.size.width < proxy.size.height, UIDevice.current.userInterfaceIdiom == .phone {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone.gen3.landscape")
                            .font(.system(size: 30, weight: .medium))
                        Text("请将手机横向旋转")
                            .font(.headline)
                        Text("横屏才能完整呈现左右跨页和翻页效果")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .frame(width: 290, height: 160)
                    .liquidGlass(
                        in: RoundedRectangle(cornerRadius: 30, style: .continuous),
                        variant: .clear
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .statusBarHidden(true)
        .task {
            if UIDevice.current.userInterfaceIdiom == .phone {
                InterfaceOrientationController.shared.request(.landscape)
            }
            await Task.yield()
            bookPages = AlbumPageRenderer.renderBookPages(project: project, images: images)
#if DEBUG
            let runsTurnTest = ProcessInfo.processInfo.arguments.contains("--album-preview-turn-test")
            let runsReverseTurnTest = ProcessInfo.processInfo.arguments.contains("--album-preview-reverse-test")
            if runsReverseTurnTest {
                currentSpread = min(3, max(1, spreadCount - 1))
            } else if runsTurnTest {
                currentSpread = min(2, max(0, spreadCount - 2))
            }
#endif
            withAnimation(.easeOut(duration: 0.24)) { isPreparing = false }
#if DEBUG
            if runsTurnTest, currentSpread + 1 < spreadCount {
                try? await Task.sleep(for: .milliseconds(1_200))
                currentSpread += 1
            } else if runsReverseTurnTest, currentSpread > 0 {
                try? await Task.sleep(for: .milliseconds(1_200))
                currentSpread -= 1
            }
#endif
        }
        .onDisappear {
            if UIDevice.current.userInterfaceIdiom == .phone {
                InterfaceOrientationController.shared.request(.portrait)
            }
        }
    }

    private func staticSpread(_ index: Int) -> some View {
        HStack(spacing: 0) {
            previewPage(at: index * 2, alignment: .trailing)
            previewPage(at: index * 2 + 1, alignment: .leading)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 58)
    }

    private func previewPage(at index: Int, alignment: Alignment) -> some View {
        Group {
            if bookPages.indices.contains(index) {
                Image(uiImage: bookPages[index])
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
    }

    private func closePreview() {
        InterfaceOrientationController.shared.request(.portrait)
        onClose()
    }
}

private struct AlbumPageCurlView: UIViewControllerRepresentable {
    let images: [UIImage]
    @Binding var currentSpread: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [
                .spineLocation: NSNumber(value: UIPageViewController.SpineLocation.mid.rawValue)
            ]
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.isDoubleSided = true
        controller.view.backgroundColor = .clear
        if let pair = context.coordinator.controllers(for: currentSpread) {
            controller.setViewControllers(pair, direction: .forward, animated: false)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        let visibleSpread = controller.viewControllers?
            .compactMap { ($0 as? AlbumLeafViewController)?.index }
            .min()
            .map { $0 / 2 }
        guard visibleSpread != currentSpread,
              let destination = context.coordinator.controllers(for: currentSpread) else { return }
        controller.setViewControllers(
            destination,
            direction: currentSpread > (visibleSpread ?? 0) ? .forward : .reverse,
            animated: true
        )
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: AlbumPageCurlView

        init(parent: AlbumPageCurlView) {
            self.parent = parent
        }

        func controller(at index: Int) -> AlbumLeafViewController? {
            guard parent.images.indices.contains(index) else { return nil }
            return AlbumLeafViewController(image: parent.images[index], index: index)
        }

        func controllers(for spread: Int) -> [UIViewController]? {
            let leftIndex = spread * 2
            guard let left = controller(at: leftIndex),
                  let right = controller(at: leftIndex + 1) else { return nil }
            return [left, right]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let leaf = viewController as? AlbumLeafViewController else { return nil }
            return controller(at: leaf.index - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let leaf = viewController as? AlbumLeafViewController else { return nil }
            return controller(at: leaf.index + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let firstIndex = pageViewController.viewControllers?
                    .compactMap({ ($0 as? AlbumLeafViewController)?.index })
                    .min() else { return }
            parent.currentSpread = firstIndex / 2
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            spineLocationFor orientation: UIInterfaceOrientation
        ) -> UIPageViewController.SpineLocation {
            .mid
        }
    }
}

private final class AlbumLeafViewController: UIViewController {
    let index: Int
    private let image: UIImage
    private let imageView = UIImageView()

    init(image: UIImage, index: Int) {
        self.image = image
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .clear
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOpacity = 0.34
        imageView.layer.shadowRadius = 22
        imageView.layer.shadowOffset = CGSize(width: 0, height: 12)
        root.addSubview(imageView)
        view = root
        view.accessibilityLabel = "相簿第 \(index + 1) 页"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.bounds.inset(by: UIEdgeInsets(top: 58, left: 2, bottom: 38, right: 2))
        guard safe.width > 0, safe.height > 0,
              image.size.width > 0, image.size.height > 0 else { return }

        let scale = min(safe.width / image.size.width, safe.height / image.size.height)
        let pageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // Even indices are left-hand pages and hug the centre spine from the
        // left; odd indices are right-hand pages and hug it from the right.
        // This removes the large gap caused by centring each page in a half-screen.
        let x = index.isMultiple(of: 2)
            ? safe.maxX - pageSize.width
            : safe.minX
        imageView.frame = CGRect(
            x: x,
            y: safe.midY - pageSize.height / 2,
            width: pageSize.width,
            height: pageSize.height
        ).integral
    }
}
