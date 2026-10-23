


import SwiftUI
import UIKit
import ImageIO




struct OnboardingExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    let supportsIslandLauncher: Bool
    let startsAtUpdatePage: Bool
    let usesWideLayout: Bool
    let usesDarkAppearance: Bool
    let onFinish: () -> Void

    @State private var pageIndex: Int
    @State private var direction: CGFloat = 1
    @ScaledMetric(relativeTo: .largeTitle) private var ipadTitleSize: CGFloat = 44
    private static func proBadgeImage(scale: CGFloat) -> UIImage {
        let size = CGSize(width: 34, height: 14)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
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
    }



    private struct OnboardingPage {
        let title: String
        let subtitle: String
        let imageName: String
        let caption: String

        var inlineModeIcon: Bool = false
        var inlineShareIcon: Bool = false

        var proNote: Bool = false
        var templateProNote: String? = nil
        var showsNewBadge: Bool = false
        var showsProBadge: Bool = false
        var textOnly: Bool = false
        var centersHeader: Bool = false
        var captionShowsProBadge: Bool = false
        var appendedProCaptionPrefix: String? = nil
        var appendedProCaptionSuffix: String? = nil

        var imageHeightFactor: CGFloat? = nil
        var artworkCaptionSpacing: CGFloat? = nil
        var usesAppearanceVariant: Bool = false
    }



    private static let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "一个入口，全部功能",
            subtitle: "随时切换，想创作哪一种都可以。",
            imageName: "mode",
            caption: "，切换体验全部功能。",
            inlineModeIcon: true
        ),
        OnboardingPage(
            title: "从系统照片，直接开始创作",
            subtitle: "无需先打开应用，选中照片即可直达。",
            imageName: "photoextension",
            caption: "在系统照片应用中，点击左下角的分享按钮，上滑选择“用灵动照片打开”。若为实况照片，建议授予完全访问权限，否则可能无法精确匹配到实况照片的配套视频。选择一种操作模式，点击“在灵动照片中继续”。",
            inlineShareIcon: true,
            imageHeightFactor: 0.78,
            usesAppearanceVariant: true
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
        OnboardingPage(
            title: "节气寻色",
            subtitle: "跟着二十四节气，从照片里收集一年的颜色。",
            imageName: "solarcolors",
            caption: "照片会按原始拍摄时间归入对应节气，提取代表色并点亮节气年；收齐后可回看属于你的一年二十四颜色。",
            proNote: true,
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "照片背面",
            subtitle: "照片留下画面，背面留下没有拍下的话。",
            imageName: "photobacks",
            caption: "从“画面里”“画面外”“写给以后”三个方向写下照片背面的回声，设定再次查看的时间，之后还可以继续补一句“后来”。",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "所有功能，全面适配 iPad",
            subtitle: "从手机到大屏，每一种创作方式都有自己的空间。",
            imageName: "ipadexperience",
            caption: "为 iPad 重新组织界面层级与操作区域，充分利用横屏与大屏空间；在 iPhone 上仍保持熟悉而紧凑的体验。",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "影像入画",
            subtitle: "照片记下所见，笔墨留下所感。",
            imageName: "imagepainting",
            caption: "用多层水彩洗染画心把原照片自然融入纸面；可选横扫、上扬、下掠、竖落、弧扫与枯笔，还可拖动、缩放调整取景并自定义画笺标题。",
            appendedProCaptionPrefix: "自定义画笺字体为“支持我们 ",
            appendedProCaptionSuffix: "”用户专属，可选用邮票与明信片的内置字体。",
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "PRO 专属\n琉璃档案，由你书写",
            subtitle: "支持我们后，即可把琉璃六色与专属文字写进档案。",
            imageName: "archivecustom",
            caption: "”用户专属\n· 档案栏开头或末尾固定一至六色\n· 专属文字搭配邮票与明信片字体",
            showsProBadge: true,
            centersHeader: true,
            captionShowsProBadge: true,
            imageHeightFactor: 0.78
        ),
        OnboardingPage(
            title: "灵动月历·摄影排版",
            subtitle: "一个月，一张照片，把日子留在画面旁边。",
            imageName: "monthlycalendarphoto",
            caption: "照片与单月月历并排呈现，圈出拍摄当天。",
            appendedProCaptionPrefix: "支持我们 ",
            appendedProCaptionSuffix: " 后，可让底板自动取自照片颜色，或自由选择颜色，文字深浅会自动适配。",
            imageHeightFactor: 0.66,
            artworkCaptionSpacing: 4
        ),
    ]

    init(
        supportsIslandLauncher: Bool,
        startsAtUpdatePage: Bool = false,
        usesWideLayout: Bool,
        usesDarkAppearance: Bool,
        onFinish: @escaping () -> Void
    ) {
        self.supportsIslandLauncher = supportsIslandLauncher
        self.startsAtUpdatePage = startsAtUpdatePage
        self.usesWideLayout = usesWideLayout
        self.usesDarkAppearance = usesDarkAppearance
        self.onFinish = onFinish

        let requiresIOS26Notice = !ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
        )
        let totalPages = Self.pages.count + 5
            + (supportsIslandLauncher && !usesWideLayout ? 1 : 0)
            + (requiresIOS26Notice ? 1 : 0)
        _pageIndex = State(initialValue: startsAtUpdatePage ? totalPages - 1 : 0)
    }

    private var pages: [OnboardingPage] { Self.pages }
    private var totalPages: Int {
        Self.pages.count + 5
            + (supportsIslandLauncher && !usesWideLayout ? 1 : 0)
            + (requiresIOS26Notice ? 1 : 0)
    }
    private var isLastPage: Bool { pageIndex == totalPages - 1 }
    private var versionUpdateStartPage: Int {
        totalPages - 1
    }
    private var displayedPageNumber: Int {
        startsAtUpdatePage ? 1 : (pageIndex >= totalPages - 1 ? pageIndex : pageIndex + 1)
    }
    private var displayedTotalPages: Int {
        startsAtUpdatePage ? 1 : totalPages - 1
    }

    private var requiresIOS26Notice: Bool {
        !ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
        )
    }

    var body: some View {
        ZStack {
            onboardingBackground

            if usesWideLayout {
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
                    } else if pageIndex == totalPages - 4 {

                        morePage
                            .id("more")
                            .transition(textTransition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if pageIndex == totalPages - 3 {

                        signatureStampOnboardingPage
                            .id("signature-stamp")
                            .transition(textTransition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 26)
                    } else if startsAtUpdatePage, pageIndex == totalPages - 2 {

                        refreshedAppIconPage
                            .id("refreshed-app-icon")
                            .transition(textTransition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if pageIndex == totalPages - 1 {

                        updatePage
                            .id("update")
                            .transition(textTransition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        let page = pages[pageIndex - (supportsIslandLauncher ? 2 : 1) - (requiresIOS26Notice ? 1 : 0)]
                        if page.textOnly || !LocalizedVisualPolicy.showsOnboardingFeatureImage(
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
        .onChange(of: usesWideLayout) { oldValue, newValue in
            guard supportsIslandLauncher, oldValue != newValue else { return }
            let islandPage = (requiresIOS26Notice ? 3 : 2)
            if newValue {
                if pageIndex >= islandPage {
                    pageIndex = max(islandPage - 1, pageIndex - 1)
                }
            } else if pageIndex >= islandPage {
                pageIndex = min(pageIndex + 1, totalPages - 1)
            }
        }
    }


    private var ipadOnboarding: some View {
        GeometryReader { proxy in
            VStack(spacing: 24) {
                HStack {
                    Text("灵动照片").font(.headline).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(displayedPageNumber) / \(displayedTotalPages)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityIdentifier("onboarding.pageNumber")
                }
                .frame(maxWidth: 780)
                .padding(.top, 16)

                Group {
                    if pageIndex == totalPages - 4 {
                        morePage
                    } else if pageIndex == totalPages - 3 {
                        signatureStampOnboardingPage
                    } else if startsAtUpdatePage, pageIndex == totalPages - 2 {
                        refreshedAppIconPage
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
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(page.inlineModeIcon ? "所有创作方式，就在左侧" : LocalizedStringKey(page.title))
                        .font(.system(size: ipadTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if page.showsNewBadge {
                        NewBadge()
                            .fixedSize()
                    }
                    if page.showsProBadge {
                        ProBadge(compact: true)
                            .fixedSize()
                    }
                }
                Text(LocalizedStringKey(page.subtitle))
                    .font(.title2).foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(5)
                (page.inlineModeIcon
                     ? Text("轻点左侧的独立玻璃按钮，即可切换创作方式。上下滚动可查看全部功能，添加照片、导出与设置仍在右上角。")
                     : pageCaptionText(page))
                    .font(.title3).foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(8)
                if page.proNote {
                    poeticColorProNote
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
                .offset(y: page.imageName == "monthlycalendarphoto" ? 144 : 0)

            let imageName = onboardingImageName(for: page)
            let screenshot = onboardingUIImage(named: imageName)
            OnboardingArtworkCaptionLayout(
                imageAspect: screenshot.map { $0.size.width / $0.size.height } ?? 0.72,
                imageHeightFactor: page.imageHeightFactor ?? 1,
                spacing: page.artworkCaptionSpacing ?? 14
            ) {
                screenshotView(
                    image: screenshot,
                    placeholderName: "\(imageName)_zh-Hans.png"
                )
                    .accessibilityLabel("功能截图")
                    .accessibilityIdentifier("onboarding.screenshot.\(imageName)")
                    .transition(.identity)
                captionView(for: page)
                    .id("caption-\(index)")
                    .transition(textTransition)
                    .offset(y: page.imageName == "ipadexperience" ? -14 : 0)
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


    private var refreshedAppIconPage: some View {
        VStack(spacing: 16) {
            Spacer()

            FloatingApplicationIcon()
                .padding(.bottom, 18)

            Text("应用图标焕然一新")
                .font(.system(size: usesWideLayout ? 36 : 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("以照片与色彩，重新描绘灵动照片。")
                .font(.system(size: usesWideLayout ? 19 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Text("全新的应用图标以照片与色彩为灵感，让熟悉的创作入口以更清晰、明快的模样回到主屏幕。")
                .font(.system(size: usesWideLayout ? 17 : 14.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .frame(maxWidth: usesWideLayout ? 560 : 330)

            Spacer()
        }
        .padding(.horizontal, 30)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.refreshedAppIcon")
    }

    private var signatureStampOnboardingPage: some View {
        let page = OnboardingPage(
            title: "光影签章",
            subtitle: "让名字、字迹与图章留在完整影像上。",
            imageName: "signaturestamp",
            caption: "输入签名或导入自己的 PNG 签章，直接拖动放置并调整大小。自定义 PNG 与非系统字体需支持我们 PRO 解锁。",
            showsNewBadge: false
        )
        return Group {
            if !LocalizedVisualPolicy.showsOnboardingFeatureImage(
                languageCode: onboardingLanguageCode,
                imageName: page.imageName
            ) {
                textOnlyFeaturePage(page)
            } else {
                VStack(spacing: 0) {
                    headerView(for: page)
                    let screenshot = onboardingUIImage(named: page.imageName)
                    OnboardingArtworkCaptionLayout(
                        imageAspect: screenshot.map { $0.size.width / $0.size.height } ?? 0.72,
                        imageHeightFactor: 1,
                        spacing: 14
                    ) {
                        screenshotView(
                            image: screenshot,
                            placeholderName: "signaturestamp_zh-Hans.png"
                        )
                        .accessibilityLabel("功能截图")
                        .accessibilityIdentifier("onboarding.screenshot.signaturestamp")
                        captionView(for: page)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private struct FloatingApplicationIcon: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var floating = false

        var body: some View {
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.30, green: 0.72, blue: 1.00).opacity(0.32),
                                Color(red: 0.28, green: 0.88, blue: 0.58).opacity(0.12),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 112
                        )
                    )
                    .frame(width: 230, height: 190)
                    .blur(radius: 20)
                    .scaleEffect(floating ? 1.08 : 0.92)

                Image("LingdongAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 142, height: 142)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(.white.opacity(0.34), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.38), radius: 22, y: 14)
                    .shadow(color: Color(red: 0.30, green: 0.72, blue: 1.00).opacity(0.20), radius: 24)
                    .offset(y: reduceMotion ? 0 : (floating ? -9 : 9))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (floating ? 1.2 : -1.2)))
            }
            .frame(width: 240, height: 220)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    floating = true
                }
            }
        }
    }


    private func textOnlyFeaturePage(_ page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 8)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LocalizedStringKey(page.title))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if page.showsNewBadge {
                    NewBadge()
                        .fixedSize()
                }
            }
            Text(LocalizedStringKey(page.subtitle))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            pageCaptionText(page)
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
        VStack(alignment: page.centersHeader ? .center : .leading, spacing: 14) {
            if page.centersHeader {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        if page.showsNewBadge {
                            NewBadge()
                                .fixedSize()
                        }
                        if page.showsProBadge {
                            ProBadge(compact: true)
                                .fixedSize()
                        }
                    }
                    Text(LocalizedStringKey(page.title))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(LocalizedStringKey(page.title))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if page.showsNewBadge {
                        NewBadge()
                            .fixedSize()
                    }
                    if page.showsProBadge {
                        ProBadge(compact: true)
                            .fixedSize()
                    }
                }
            }
            Text(LocalizedStringKey(page.subtitle))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(page.centersHeader ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, page.imageName == "ipadexperience" ? 8 : 0)
        }
        .frame(maxWidth: .infinity, alignment: page.centersHeader ? .center : .leading)
    }

    @ViewBuilder
    private func captionView(for page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            pageCaptionText(page)
                .font(.system(size: 14.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if page.proNote {
                poeticColorProNote
            }
            if let note = page.templateProNote {
                templateProNote(note)
            }
        }
    }

    private func templateProNote(_ note: String) -> some View {
        (Text(LocalizedStringKey(note))
            + Text(Image(uiImage: Self.proBadgeImage(scale: displayScale))).baselineOffset(-3.5)
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
                        title: "光影签章",
                        detail: "气泡记录拍摄信息，字迹与自定义 PNG 签章则可在完整画面上自由落款。"
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
                        symbol: "paintbrush.pointed",
                        title: "影像入画",
                        detail: "把原照片融入多层水彩洗染画心，可选不同笔势、自定义画笺标题，也可排成兼有原片、画意与琉璃颜料的一照两境；PRO 用户还可自由选用邮笺字体。"
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
                    Text("灵动照片 4.0.0（Build 202649）· 公开版本")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }

                VStack(alignment: .leading, spacing: 16) {
                    updateItem(
                        symbol: "photo.on.rectangle",
                        title: "普通创作 · 公开版本",
                        detail: "保留本机照片创作与相关工具，包含当前版本的界面适配与渲染改进。"
                    )
                    updateItem(
                        symbol: "lock.shield",
                        title: "加密透明说明",
                        detail: "灵动来信的业务界面与服务端不包含在此版本中；加密协议与独立验证示例见仓库 Transparency 目录。"
                    )
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 6)


            .padding(.bottom, usesWideLayout ? 10 : 132)
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

    private var poeticColorProNote: some View {
        (Text("色盘与诗意名词免费，出处与来源需 ".appLocalized)
            + Text(Image(uiImage: Self.proBadgeImage(scale: displayScale))).baselineOffset(-3.5)
            + Text(" 解锁。".appLocalized))
            .font(.system(size: 12.5, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.52))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    private func screenshotView(image: UIImage?, placeholderName: String) -> some View {
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
                    VStack(spacing: 7) {
                        Text("待添加截图")
                        Text(placeholderName)
                            .font(.system(size: 9, design: .monospaced))
                    }
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

    private func onboardingImageName(for page: OnboardingPage) -> String {
        guard page.usesAppearanceVariant else { return page.imageName }
        return "\(page.imageName)_\(usesDarkAppearance ? "dark" : "light")"
    }

    private func pageCaptionText(_ page: OnboardingPage) -> Text {
        if page.inlineModeIcon {
            return Text("点击右上角")
                + Text(Image(systemName: "square.grid.2x2"))
                + Text(LocalizedStringKey(page.caption))
        }
        if page.inlineShareIcon {
            return Text("在系统照片应用中，点击左下角")
                + Text(Image(systemName: "square.and.arrow.up"))
                + Text("，上滑选择")
                + Text("“用灵动照片打开”").fontWeight(.semibold)
                + Text("。若为实况照片，建议授予完全访问权限，否则可能无法精确匹配到实况照片的配套视频。选择一种操作模式，点击")
                + Text("“在灵动照片中继续”。").fontWeight(.semibold)
        }
        if page.captionShowsProBadge {
            return Text("琉璃档案自定义功能为“支持我们 ")
                + Text(Image(uiImage: Self.proBadgeImage(scale: displayScale))).baselineOffset(-3.5)
                + Text(LocalizedStringKey(page.caption))
        }
        if let prefix = page.appendedProCaptionPrefix,
           let suffix = page.appendedProCaptionSuffix {
            return Text(LocalizedStringKey(page.caption))
                + Text("\n\n")
                + Text(LocalizedStringKey(prefix))
                + Text(Image(uiImage: Self.proBadgeImage(scale: displayScale))).baselineOffset(-3.5)
                + Text(LocalizedStringKey(suffix))
        }
        return Text(LocalizedStringKey(page.caption))
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
                if pageIndex > 0 && (!startsAtUpdatePage || pageIndex > versionUpdateStartPage) {
                    Button {
                        let destination: Int
                        if startsAtUpdatePage, isLastPage {
                            destination = totalPages - 2
                        } else if startsAtUpdatePage, pageIndex == totalPages - 2 {
                            destination = totalPages - 3
                        } else if startsAtUpdatePage, pageIndex == totalPages - 3 {
                            destination = totalPages - 5
                        } else if !startsAtUpdatePage, isLastPage {
                            destination = totalPages - 3
                        } else {
                            destination = pageIndex - 1
                        }
                        navigate(to: destination)
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
                    Text(isLastPage
                         ? (startsAtUpdatePage ? "继续使用".appLocalized : "开始使用".appLocalized)
                         : "继续".appLocalized)
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
        if startsAtUpdatePage, pageIndex == totalPages - 5 {
            navigate(to: totalPages - 3)
            return
        }
        if !startsAtUpdatePage, pageIndex == totalPages - 3 {
            navigate(to: totalPages - 1)
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
    var spacing: CGFloat

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
