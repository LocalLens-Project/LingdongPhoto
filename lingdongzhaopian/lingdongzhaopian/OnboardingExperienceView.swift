


import SwiftUI
import UIKit
import ImageIO




struct OnboardingExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let supportsIslandLauncher: Bool
    let onFinish: () -> Void

    @State private var pageIndex = 0
    @State private var direction: CGFloat = 1
    @ScaledMetric(relativeTo: .largeTitle) private var ipadTitleSize: CGFloat = 44
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private static let proBadgeImage: UIImage = {

        let size = CGSize(width: 34, height: 14)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let capsule = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: size.height / 2)


            context.cgContext.saveGState()
            capsule.addClip()
            let colors = [
                UIColor(red: 0.67, green: 0.90, blue: 0.92, alpha: 1).cgColor,
                UIColor(red: 0.95, green: 0.78, blue: 0.66, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: bounds.minX, y: bounds.midY),
                    end: CGPoint(x: bounds.maxX, y: bounds.midY),
                    options: []
                )
            }
            context.cgContext.restoreGState()


            UIColor.white.withAlphaComponent(0.62).setStroke()
            capsule.lineWidth = 0.6
            capsule.stroke()


            let text = NSAttributedString(
                string: "PRO",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 7, weight: .black),
                    .foregroundColor: UIColor(red: 0.08, green: 0.16, blue: 0.20, alpha: 1),
                    .kern: 0.4,
                ]
            )
            let textSize = text.size()
            text.draw(at: CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            ))
        }
    }()



    private struct OnboardingPage {
        let title: String
        let subtitle: String
        let imageName: String
        let caption: String

        var inlineModeIcon: Bool = false

        var proNote: Bool = false
        var templateProNote: String? = nil

        var imageHeightFactor: CGFloat? = nil
    }



    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "一个入口，全部功能",
            subtitle: "随时切换，想创作哪一种都可以。",
            imageName: "mode",
            caption: "，切换体验全部功能。",
            inlineModeIcon: true
        ),
        OnboardingPage(
            title: "影像票根",
            subtitle: "一张照片，一枚票根，把当时的颜色随身携带。",
            imageName: "ticket",
            caption: "选好照片，它会自动读取出行的城市与拍摄时间，排版成一枚可以分享、可以扫码验证的影像票根。"
        ),
        OnboardingPage(
            title: "扫码验证票根",
            subtitle: "每一枚票根，都可以被追溯。",
            imageName: "verify",
            caption: "朋友只需扫描票根上的码即可验证，色盘、拍摄信息与文案在轻应用里即刻打开，无需安装完整应用。",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "琉璃档案",
            subtitle: "封存拍摄那一刻最原始的记录。",
            imageName: "archive",
            caption: "以液态玻璃档案栏封存设备、参数与坐标，让每张照片都有据可查。"
        ),
        OnboardingPage(
            title: "琉璃色盘",
            subtitle: "从一张照片里，取出属于它的颜色。",
            imageName: "palette",
            caption: "照片导入后自动提炼主色盘，每种颜色都有自己的占比与诗意名字。",
            proNote: true,
            imageHeightFactor: 0.74
        ),
        OnboardingPage(
            title: "灵动色卡",
            subtitle: "让照片完整留下，让颜色向外延伸。",
            imageName: "palettecard",
            caption: "提取照片主色，自由选择下方、左侧或右侧色条。调整色条大小时保留完整画面，导出尺寸由你决定。",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "色彩关系",
            subtitle: "两张照片放在一起，看色彩如何相处。",
            imageName: "colorrelation",
            caption: "选两张照片，分析它们的色彩是协调还是对照，一眼看清关系。"
        ),
        OnboardingPage(
            title: "灵动月历",
            subtitle: "原来的画幅，记下那一天。",
            imageName: "monthlycalendar",
            caption: "保留照片原有比例，让日历随画面等比缩放。拍摄日期、节气与能确认的城市，留在同一张月历里。",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "票根集",
            subtitle: "把某一段时光的票根收进票夹。",
            imageName: "collection",
            caption: "票根会按城市自动收进这里，也能整理分集，收纳成属于你的票夹。"
        ),
        OnboardingPage(
            title: "邮票制作",
            subtitle: "把一瞬风景，收藏成自己的邮票。",
            imageName: "stamp",
            caption: "从经典比例到三角形、扇形与圆形，选择喜欢的邮票，微调构图，收藏或贴进明信片。",
            templateProNote: "3:4 邮票免费，其他比例与异形模板需 ",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "明信片",
            subtitle: "一张照片，一封有温度的问候。",
            imageName: "postcard",
            caption: "四种版式搭配寄语、邮票与邮戳，把旅途的光影寄给想念的人。",
            templateProNote: "经典邮政版式免费，其他明信片版式需 ",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "邮集",
            subtitle: "把走过的城市，收进一枚枚邮票。",
            imageName: "postalcollection",
            caption: "带定位的照片制作成邮票后点亮城市。按住左右转动邮票，查看背面的城市与收藏日期。",
            imageHeightFactor: 0.78
        ),
    ]

    private var totalPages: Int { pages.count + 3 + (supportsIslandLauncher ? 1 : 0) + (requiresIOS26Notice ? 1 : 0) }
    private var isLastPage: Bool { pageIndex == totalPages - 1 }

    private var requiresIOS26Notice: Bool {
        !ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
        )
    }

    var body: some View {
        ZStack {
            onboardingBackground

            if isIPad {
                ipadOnboarding
            } else {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 28)

                    if pageIndex == 0 {

                        welcomePage
                            .id("welcome")
                            .transition(textTransition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 30)
                    } else if requiresIOS26Notice, pageIndex == 1 {

                        iosVersionNoticePage
                            .id("ios-version-notice")
                            .transition(textTransition)
                            .padding(.horizontal, 30)
                    } else if pageIndex == (requiresIOS26Notice ? 2 : 1) {

                        floatingModePage
                            .id("mode-floating")
                            .transition(textTransition)
                            .padding(.horizontal, 26)
                    } else if supportsIslandLauncher, pageIndex == (requiresIOS26Notice ? 3 : 2) {

                        islandModePage
                            .id("mode-island")
                            .transition(textTransition)
                            .padding(.horizontal, 26)
                    } else if pageIndex == totalPages - 2 {

                        morePage
                            .id("more")
                            .transition(textTransition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if pageIndex == totalPages - 1 {

                        updatePage
                            .id("update")
                            .transition(textTransition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        let page = pages[pageIndex - (supportsIslandLauncher ? 2 : 1) - (requiresIOS26Notice ? 1 : 0)]
                        if !LocalizedVisualPolicy.showsOnboardingFeatureImage(
                            languageCode: onboardingLanguageCode,
                            imageName: page.imageName
                        ) {

                            textOnlyFeaturePage(page)
                                .id("page-\(pageIndex)")
                                .transition(textTransition)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.horizontal, 30)
                        } else {


                            featurePage(for: pageIndex - (supportsIslandLauncher ? 1 : 0) - (requiresIOS26Notice ? 1 : 0))
                                .id("feature-\(pageIndex)")
                                .padding(.horizontal, 26)
                        }
                    }



                    if !isLastPage {
                        footer
                    }
                }
                .overlay(alignment: .bottom) {
                    if isLastPage {
                        lastPageFooterOverlay
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }


    private var ipadOnboarding: some View {
        GeometryReader { proxy in
            VStack(spacing: 24) {
                HStack {
                    Text("灵动照片").font(.headline).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(pageIndex + 1) / \(totalPages)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityIdentifier("onboarding.pageNumber")
                }
                .frame(maxWidth: 780)
                .padding(.top, 16)

                Group {
                    if pageIndex == totalPages - 2 {
                        morePage
                    } else if isLastPage {
                        updatePage
                    } else {
                        GeometryReader { content in
                            ScrollView {
                                ipadOnboardingText
                                    .padding(.vertical, 28)
                                    .frame(maxWidth: .infinity, minHeight: content.size.height, alignment: .leading)
                            }
                            .scrollBounceBehavior(.basedOnSize)
                        }
                    }
                }
                .id(pageIndex)
                .transition(reduceMotion ? .identity : .opacity)
                .frame(maxWidth: 780, maxHeight: .infinity)

                footer.frame(maxWidth: 600)
            }
            .padding(.horizontal, proxy.size.width < 600 ? 24 : 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ipad.onboarding")
    }

    private var ipadOnboardingText: some View {
        VStack(alignment: .leading, spacing: 26) {
            if pageIndex == 0 {
                Text("欢迎来到灵动照片")
                    .font(.system(size: ipadTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("一张照片，多一种表达。")
                    .font(.title2).foregroundStyle(.white.opacity(0.85))
                Text("灵动照片是一款完全开源的照片应用，代码公开、可审计，你的照片始终只属于你。")
                    .font(.title3).foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(7)
            } else if requiresIOS26Notice, pageIndex == 1 {
                Text("建议升级到 iOS 26")
                    .font(.system(size: ipadTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("灵动照片深度采用 iOS 26 的液态玻璃效果与组件。")
                    .font(.title2).foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(5)
                Text("本引导教程以 iOS 26 为例，更新到 iOS 26，即可获得本应用的最佳使用效果。")
                    .font(.title3).foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(8)
                Text(String(format: "当前系统版本：iOS %@".appLocalized, UIDevice.current.systemVersion))
                    .font(.body).foregroundStyle(.white.opacity(0.5))
            } else {
                let page = pages[pageIndex - 1 - (requiresIOS26Notice ? 1 : 0)]
                Text(page.inlineModeIcon ? "所有创作方式，就在左侧" : LocalizedStringKey(page.title))
                    .font(.system(size: ipadTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(page.subtitle))
                    .font(.title2).foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(5)
                Text(page.inlineModeIcon
                     ? "轻点左侧的独立玻璃按钮，即可切换创作方式。上下滚动可查看全部功能，添加照片、导出与设置仍在右上角。"
                     : LocalizedStringKey(page.caption))
                    .font(.title3).foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(8)
                if page.proNote {
                    Text("色盘与诗意名词免费，出处与来源需 Pro 解锁。")
                        .font(.body).foregroundStyle(.white.opacity(0.55))
                }
                if let note = page.templateProNote {
                    templateProNote(note)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }




    private var onboardingBackground: some View {
        ZStack {
            Color.black


            RadialGradient(
                colors: [
                    Color(hue: 0.64, saturation: 0.45, brightness: 0.55).opacity(0.16),
                    .clear,
                ],
                center: UnitPoint(x: 0.78, y: 0.10),
                startRadius: 0,
                endRadius: 430
            )


            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    .clear,
                    Color.white.opacity(0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }





    private func featurePage(for index: Int) -> some View {
        let page = pages[index - 1]
        return VStack(spacing: 0) {

            headerView(for: page)
                .id("header-\(index)")
                .transition(textTransition)

            let screenshot = onboardingUIImage(named: page.imageName)
            OnboardingArtworkCaptionLayout(
                imageAspect: screenshot.map { $0.size.width / $0.size.height } ?? 0.72,
                imageHeightFactor: page.imageHeightFactor ?? 1
            ) {
                screenshotView(image: screenshot)
                    .accessibilityLabel("功能截图")
                    .accessibilityIdentifier("onboarding.screenshot.\(page.imageName)")
                    .transition(.identity)
                captionView(for: page)
                    .id("caption-\(index)")
                    .transition(textTransition)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("onboarding.caption.\(page.imageName)")
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    @ViewBuilder
    private var floatingModePage: some View {
        let page = OnboardingPage(
            title: "浮光菜单",
            subtitle: "一个按钮，打开全部创作方式。",
            imageName: "mode",
            caption: "轻点右上角的模式按钮，在完整菜单中选择功能。"
        )
        if !LocalizedVisualPolicy.showsOnboardingModeImage(languageCode: onboardingLanguageCode) {
            textOnlyFeaturePage(page)
        } else {
            VStack(spacing: 0) {
                headerView(for: page)

                GeometryReader { proxy in
                    VStack(spacing: 34) {
                        comparisonScreenshot(
                            name: "mode_zh-Hans",
                            aspect: 400.0 / 350.0,
                            maximumWidth: proxy.size.width * 0.94,
                            maximumHeight: min(300, proxy.size.height * 0.48),
                            identifier: "onboarding.mode.floatingScreenshot"
                        )

                        Text(LocalizedStringKey(page.caption))
                            .font(.system(size: 14.5, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }


    @ViewBuilder
    private var islandModePage: some View {
        let page = OnboardingPage(
            title: "灵屿展开",
            subtitle: "灵动岛机型的专属入口。",
            imageName: "mode",
            caption: "从灵动岛自然展开，在屏幕顶部直接选择功能。"
        )
        if !LocalizedVisualPolicy.showsOnboardingModeImage(languageCode: onboardingLanguageCode) {
            textOnlyFeaturePage(page)
        } else {
            VStack(spacing: 0) {
                headerView(for: page)

                GeometryReader { proxy in
                    VStack(spacing: 34) {
                        comparisonScreenshot(
                            name: "mode_island_zh-Hans",
                            aspect: 400.0 / 350.0,
                            maximumWidth: proxy.size.width * 0.94,
                            maximumHeight: min(300, proxy.size.height * 0.48),
                            identifier: "onboarding.mode.islandScreenshot"
                        )

                        Text(LocalizedStringKey(page.caption))
                            .font(.system(size: 14.5, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func comparisonScreenshot(
        name: String,
        aspect: CGFloat,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat,
        identifier: String
    ) -> some View {
        if let image = bundledOnboardingUIImage(named: name) {
            let imageAspect = image.size.width / max(1, image.size.height)
            let fittedHeight = min(maximumHeight, maximumWidth / imageAspect)
            let fittedWidth = fittedHeight * imageAspect
            Group {
                if image.images != nil {

                    AnimatedImageRepresentable(image: image, contentMode: .scaleAspectFit)
                } else {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                }
            }
            .frame(width: fittedWidth, height: fittedHeight)
            .clipped()
            .accessibilityLabel("功能截图")
            .accessibilityIdentifier(identifier)
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                }
                .overlay {
                    VStack(spacing: 6) {
                        Text("待添加截图")
                        Text("\(name).gif").font(.system(size: 9, design: .monospaced))
                    }
                    .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.38))
                }
                .aspectRatio(aspect, contentMode: .fit)
                .frame(maxWidth: maximumWidth, maxHeight: maximumHeight)
                .accessibilityIdentifier(identifier)
        }
    }

    private func bundledOnboardingUIImage(named fullName: String) -> UIImage? {

        for ext in ["gif", "png"] {
            guard let url = Bundle.main.url(forResource: fullName, withExtension: ext),
                  let data = try? Data(contentsOf: url) else { continue }

            if ext == "gif", let animated = animatedImage(gifData: data) {
                return animated
            }
            if let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }


    private func animatedImage(gifData: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(gifData as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return nil }

        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0
        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            var delay = 0.1
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
               let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? 0
                let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double ?? 0
                let value = unclamped > 0 ? unclamped : clamped
                if value > 0 { delay = value }
            }
            totalDuration += delay
            frames.append(UIImage(cgImage: cgImage))
        }
        guard frames.count > 1, totalDuration > 0 else { return nil }
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }


    private var iosVersionNoticePage: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(red: 0.67, green: 0.90, blue: 0.92).opacity(0.24))
                    .frame(width: 104, height: 104)
                    .blur(radius: 22)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.91, blue: 0.91))
                    .frame(width: 84, height: 84)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .padding(.bottom, 6)

            Text("建议升级到 iOS 26")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("灵动照片深度采用 iOS 26 的液态玻璃效果与组件。")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))

            Text("本引导教程以 iOS 26 为例，更新到 iOS 26，即可获得本应用的最佳使用效果。")
                .font(.system(size: 14.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(5)
                .padding(.top, 4)

            Text(String(format: "当前系统版本：iOS %@".appLocalized, UIDevice.current.systemVersion))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .padding(.top, 10)

            Spacer()
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("onboarding.iosVersionNotice")
    }


    private var welcomePage: some View {
        VStack(spacing: 14) {
            Spacer()
            WelcomeIcon()
                .padding(.bottom, 6)
            Text("欢迎使用灵动照片")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("让照片的颜色，有诗的名字。")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            welcomeIntro
                .lineSpacing(4)
                .padding(.top, 8)
            if onboardingLanguageCode == "zh-Hant" {

                Text("引导页截图来自本应用简体中文版本")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.top, 10)
            }
            Spacer()
        }
        .multilineTextAlignment(.center)
    }


    private struct WelcomeIcon: View {
        @State private var breathing = false

        var body: some View {
            ZStack {

                Circle()
                    .fill(Color(red: 0.67, green: 0.90, blue: 0.92).opacity(0.35))
                    .frame(width: 92, height: 92)
                    .blur(radius: 18)
                    .scaleEffect(breathing ? 1.18 : 0.9)
                    .opacity(breathing ? 0.9 : 0.5)

                Image("LingdongAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(width: 96, height: 96)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
        }
    }


    private func textOnlyFeaturePage(_ page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 8)
            Text(LocalizedStringKey(page.title))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(LocalizedStringKey(page.subtitle))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            Text(LocalizedStringKey(page.caption))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
            if let note = page.templateProNote {
                templateProNote(note).padding(.top, 14)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerView(for page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedStringKey(page.title))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(LocalizedStringKey(page.subtitle))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func captionView(for page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if page.inlineModeIcon {

                (Text("点击右上角")
                    + Text(Image(systemName: "square.grid.2x2"))
                    + Text(page.caption))
                    .font(.system(size: 14.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(LocalizedStringKey(page.caption))
                    .font(.system(size: 14.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if page.proNote {

                (Text("色盘与诗意名词免费，出处与来源需 ")

                    + Text(Image(uiImage: Self.proBadgeImage)).baselineOffset(-3.5)
                    + Text(" 解锁。"))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let note = page.templateProNote {
                templateProNote(note)
            }
        }
    }

    private func templateProNote(_ note: String) -> some View {
        (Text(LocalizedStringKey(note))
            + Text(Image(uiImage: Self.proBadgeImage)).baselineOffset(-3.5)
            + Text(" 解锁。"))
            .font(.system(size: 12.5, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("postal.onboardingProNote")
    }


    private var morePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("还有更多")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("每一种模式，都值得试一试。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    updateItem(
                        symbol: "fan",
                        title: "流光折扇",
                        detail: "完整折扇会直接呈现六张照片。“自动寻色”只会组合属于同一色系的照片；也能切换“自由编排”，自行换图、拖动缩放调整每个扇面的取景并保存透明 PNG。"
                    )
                    updateItem(
                        symbol: "play.rectangle",
                        title: "灵动卡片",
                        detail: "导入照片即可生成灵动的动态卡片，配上诗意标题与设备信息，一键保存或分享。"
                    )
                    updateItem(
                        symbol: "camera",
                        title: "气泡印章",
                        detail: "在照片角落加上机型、光圈快门与拍摄时间的气泡水印，风格随心挑选。"
                    )
                    updateItem(
                        symbol: "book.closed",
                        title: "一键手帐",
                        detail: "导入几张照片，自动排版成一页页手帐。"
                    )
                    updateItem(
                        symbol: "photo.artframe",
                        title: "色谱壁纸",
                        detail: "把照片的色谱变成可以收藏的壁纸。"
                    )
                    updateItem(
                        symbol: "eye.slash",
                        title: "隐私马赛克",
                        detail: "自动或手动打上马赛克，安心分享照片。"
                    )
                    updateItem(
                        symbol: "pencil.and.outline",
                        title: "影像素描",
                        detail: "把照片勾勒成线条素描。"
                    )
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }


    private var updatePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本次更新")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("灵动照片 3.0.0（Build 202620）")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }

                VStack(alignment: .leading, spacing: 16) {
                    updateItem(
                        symbol: "fan",
                        title: "新增“流光折扇”功能",
                        detail: "六个独立扇面会完整呈现；“自动寻色”仅组合属于同一色系的照片，“自由编排”支持手动选片。点按扇面即可拖动、缩放并精确取景，完成后可导出透明 PNG。"
                    )
                    updateItem(
                        symbol: "swatchpalette",
                        title: "新增“灵动色卡”功能",
                        detail: "从照片提取主色，色条可向下、向左或向右延伸；调整大小不遮挡、不裁切照片。"
                    )
                    updateItem(
                        symbol: "calendar",
                        title: "新增“灵动月历”功能",
                        detail: "保留横图、竖图和方图的原有比例，日历面板等比适配画面，记录拍摄日期与节气。"
                    )
                    updateItem(
                        symbol: "square.dashed",
                        title: "新增“邮票制作”功能",
                        detail: "五种齿孔模板，从选择样式到导入照片分步制作；可添加标题、日期和字体，收藏或保存 PNG。"
                    )
                    updateItem(
                        symbol: "envelope",
                        title: "新增“明信片”功能",
                        detail: "四种版式搭配照片、寄语、邮票与邮戳，把旅途的光影制作成一张问候。"
                    )
                    updateItem(
                        symbol: "square.grid.2x2",
                        title: "新增“邮集”功能",
                        detail: "收藏带定位的邮票，点亮城市足迹。按住邮票可自由旋转。"
                    )
                    updateItem(
                        symbol: "folder",
                        title: "新增“票根集”功能",
                        detail: "本次添加了票根集，把旅行、演出或某一段时光的影像票根整理分集，收纳成属于你的票夹。"
                    )
                    updateItem(
                        symbol: "camera.viewfinder",
                        title: "新增“票根显影”功能",
                        detail: "本次添加了票根显影，导入实体票的照片即可智能识别，让旧票根重制成可验证的影像票根。"
                    )
                    updateItem(
                        symbol: "cabinet",
                        title: "新增“琉璃档案”功能",
                        detail: "本次添加了琉璃档案，以液态玻璃档案栏封存设备、参数与坐标的原始记录，让每张照片都有据可查。"
                    )
                    updateItem(

                        symbol: "text.magnifyingglass",
                        title: "新增“寻找本机原图”功能",
                        detail: "本次添加了寻找本机原图，扫描票根后可在本机相册里找回当初封存的那张原片，随时重温拍摄那一刻。"
                    )
                    updateItem(
                        symbol: "paintpalette",
                        title: "新增“空白主界面配色”功能",
                        detail: "本次添加了空白主界面配色，尚未选择照片时，所有功能主页的背景都可以换成你喜欢的主色调。"
                    )
                    updateItem(
                        symbol: "heart",
                        title: "新增“支持我们”专属功能",
                        detail: "本次添加了节气诗意色名、典藏票面与支持者标志，一次支持即可解锁。",
                        showsProBadge: true
                    )
                    updateItem(
                        symbol: "slider.horizontal.3",
                        title: "优化“功能设定”体验",
                        detail: "本次将灵动卡片、气泡印章与琉璃档案的功能设定，从设置页直接放进了对应的功能里，随用随达，让创作更顺手。"
                    )
                    updateItem(
                        symbol: "wrench.and.screwdriver",
                        title: "其他优化",
                        detail: "修复了部分已知问题，并优化了整体使用体验。"
                    )
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 6)


            .padding(.bottom, isIPad ? 10 : 132)
        }
    }

    private func updateItem(
        symbol: String,
        title: String,
        detail: String,
        showsProBadge: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if showsProBadge {
                        ProBadge(compact: true)
                    }
                }
                Text(LocalizedStringKey(detail))
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }


    private var welcomeIntro: Text {
        var intro = AttributedString(
            localized: "灵动照片是一款完全开源的照片应用，代码公开、可审计，你的照片始终只属于你。"
        )
        intro.font = .system(size: 14.5, weight: .regular, design: .rounded)
        intro.foregroundColor = .white.opacity(0.72)
        for word in [String(localized: "开源"), String(localized: "可审计")] {
            guard !word.isEmpty, let range = intro.range(of: word) else { continue }
            intro[range].font = .system(size: 14.5, weight: .bold, design: .rounded)
            intro[range].foregroundColor = .white
        }
        return Text(intro)
    }




    private var textTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        let insertionEdge: Edge = direction > 0 ? .trailing : .leading
        let removalEdge: Edge = direction > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }




    @ViewBuilder
    private func screenshotView(image: UIImage?) -> some View {
        if let image {


            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                }
                .overlay {
                    Text("待添加截图")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .aspectRatio(0.72, contentMode: .fit)
                .frame(maxHeight: .infinity)
        }
    }


    private var onboardingLanguageCode: String {
        let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
        if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-HK") || preferred.hasPrefix("zh-TW") {
            return "zh-Hant"
        } else if preferred.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }


    private func onboardingUIImage(named baseName: String) -> UIImage? {
        guard onboardingLanguageCode != "en" else { return nil }

        if let url = Bundle.main.url(
            forResource: "\(baseName)_zh-Hans",
            withExtension: "png"
        ), let uiImage = UIImage(contentsOfFile: url.path) {
            return uiImage
        }
        return nil
    }



    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                if pageIndex > 0 {
                    Button {
                        navigate(to: pageIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 54, height: 54)
                            .background(
                                isLastPage ? Color(white: 0.14) : Color.white.opacity(0.10),
                                in: Circle()
                            )
                    }
                    .accessibilityLabel("返回")
                    .accessibilityIdentifier("onboarding.back")
                }

                Button(action: continueTapped) {
                    Text(isLastPage ? "开始使用" : "继续")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: pageIndex)
                .accessibilityIdentifier("onboarding.continue")
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
    }



    private var lastPageFooterOverlay: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.88),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 132)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)

            footer
        }
    }

    private func continueTapped() {
        if isLastPage {
            onFinish()
            return
        }
        navigate(to: pageIndex + 1)
    }

    private func navigate(to newIndex: Int) {
        direction = newIndex > pageIndex ? 1 : -1
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.45, dampingFraction: 0.88)) {
            pageIndex = newIndex
        }
    }
}




struct OnboardingArtworkCaptionLayout: Layout {
    var imageAspect: CGFloat
    var imageHeightFactor: CGFloat
    let spacing: CGFloat = 14

    func imageSize(in available: CGSize, captionHeight: CGFloat) -> CGSize {
        let aspect = max(0.01, imageAspect)
        let maxHeight = max(0, min(available.height * imageHeightFactor,
                                   available.height - captionHeight - spacing))
        let width = min(available.width, maxHeight * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 320, height: 600))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let caption = subviews[1].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        let image = imageSize(in: bounds.size, captionHeight: caption.height)
        let top = bounds.minY + max(0, (bounds.height - image.height - spacing - caption.height) / 2)
        subviews[0].place(at: CGPoint(x: bounds.midX, y: top), anchor: .top,
                          proposal: ProposedViewSize(image))
        subviews[1].place(at: CGPoint(x: bounds.minX, y: top + image.height + spacing), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: caption.height))
    }
}
