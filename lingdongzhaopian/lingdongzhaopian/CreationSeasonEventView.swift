import SwiftUI
import UIKit

struct CreationSeasonEventView: View {
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasScrolled = false
    @State private var scrollCueRaised = false

    private var showsArtwork: Bool {
        let language = Bundle.main.preferredLocalizations.first?.lowercased() ?? ""
        return language.hasPrefix("zh")
    }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 720

            ZStack(alignment: .topTrailing) {
                onboardingBackground

                ScrollView {
                    VStack(spacing: wide ? 74 : 58) {
                        hero

                        VStack(spacing: wide ? 82 : 68) {
                            CreationSeasonFeatureSection(
                                symbol: "fan",
                                title: "六张照片，展开一把流光折扇".appLocalized,
                                detail: "让六段光影沿扇面依次展开，可自动寻色，也可自由编排。画布会随屏幕与方向自然舒展，让每一片扇面都有从容的取景空间。".appLocalized,
                                artwork: nil
                            )

                            CreationSeasonFeatureSection(
                                symbol: "envelope",
                                title: "把想说的话，寄进一张明信片".appLocalized,
                                detail: "照片、邮戳与文字会依照画布空间自然重排。从 iPhone 上的轻巧浏览到 iPad 上的宽阔创作，都保留完整、舒展的明信片体验。".appLocalized,
                                artwork: eventArtwork(named: "CreationSeasonPostcard"),
                                placesTitleOnArtwork: true
                            )

                            CreationSeasonFeatureSection(
                                symbol: "seal",
                                title: "把一瞬光影，收藏成一枚邮票".appLocalized,
                                detail: "选择喜欢的齿孔、版式与构图，把一张照片凝成微型影像作品；无论画布大小，比例、留白与操作区域始终清晰自然。".appLocalized,
                                artwork: eventArtwork(named: "CreationSeasonStamp"),
                                placesTitleOnArtwork: true
                            )

                            CreationSeasonFeatureSection(
                                symbol: "calendar",
                                title: "让一张照片陪你走过一个月".appLocalized,
                                detail: "日期、节气、城市与主色会随画布留白自然安放，让每一种尺寸都拥有清晰、从容的月历构图。".appLocalized,
                                artwork: nil
                            )

                            CreationSeasonFeatureSection(
                                symbol: "book.closed",
                                title: "点亮照片去过的城市".appLocalized,
                                detail: "将制作完成的邮票收入邮集。地图、城市与收藏会顺应空间展开，让一路收集的色彩在任何方向都清晰可见。".appLocalized,
                                artwork: eventArtwork(named: "postalcollection_zh-Hans")
                            )

                            CreationSeasonFeatureSection(
                                symbol: "ticket",
                                title: "把旅程封存在影像票根里".appLocalized,
                                detail: "照片、地点、时间与拍摄信息会依照当前空间重新组织，在紧凑或宽阔的画布中都成为完整、易读的旅途凭证。".appLocalized,
                                artwork: eventArtwork(named: "ticket_zh-Hans")
                            )

                            CreationSeasonFeatureSection(
                                symbol: "rectangle.stack",
                                title: "让每一段旅程，在票根集中再次相遇".appLocalized,
                                detail: "把散落的票根按时间收拢成册。纵向回看或横向浏览，旅程都会以自然舒展的节奏连成一条光影轨迹。".appLocalized,
                                artwork: eventArtwork(named: "collection_zh-Hans")
                            )
                        }

                        VStack(spacing: 12) {
                            Text("期待你的作品".appLocalized)
                                .font(.system(size: wide ? 34 : 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("愿每一块屏幕都成为你的创作桌面，让这一季的光影被好好收藏。".appLocalized)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))
                                .multilineTextAlignment(.center)
                        }

                        Button(action: onClose) {
                            Text("开始创作".appLocalized)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: wide ? 360 : .infinity)
                                .frame(height: 56)
                                .background(.white, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 22))
                    }
                    .frame(maxWidth: 780)
                    .padding(.horizontal, wide ? 52 : 26)
                    .padding(.top, max(proxy.safeAreaInsets.top, 20) + 54)
                    .frame(maxWidth: .infinity)
                    .background {
                        GeometryReader { contentProxy in
                            Color.clear.preference(
                                key: CreationSeasonScrollOffsetKey.self,
                                value: contentProxy.frame(in: .named("creationSeasonScroll")).minY
                            )
                        }
                    }
                }
                .coordinateSpace(name: "creationSeasonScroll")
                .scrollIndicators(.hidden)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            guard value.translation.height < -2 else { return }
                            hideScrollCue()
                        }
                )
                .onPreferenceChange(CreationSeasonScrollOffsetKey.self) { offset in
                    guard offset < -2 else { return }
                    hideScrollCue()
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭".appLocalized)
                .padding(.top, max(proxy.safeAreaInsets.top, 14))
                .padding(.trailing, wide ? 34 : 18)

                if !hasScrolled {
                    scrollCue
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 20) + 8)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var onboardingBackground: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(hue: 0.64, saturation: 0.45, brightness: 0.55).opacity(0.16),
                    .clear
                ],
                center: UnitPoint(x: 0.78, y: 0.10),
                startRadius: 0,
                endRadius: 430
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    .clear,
                    Color.white.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(spacing: 15) {
            Text("全新创作活动 · 为每一块屏幕而生".appLocalized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .tracking(1)

            Text("灵动照片3.0创作季".appLocalized)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("从 iPhone 到 iPad，创作始终自然舒展".appLocalized)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)

            Text("用六张照片展开流光折扇，把一张照片制成邮票、明信片或月历。无论使用 iPhone 还是 iPad，每一种创作都会顺应屏幕大小与方向自然展开，以全新方式收藏光影与时间。".appLocalized)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: 640)
                .padding(.top, 5)
        }
    }

    private var scrollCue: some View {
        VStack(spacing: 6) {
            Text("向上滑动，查看本季创作灵感".appLocalized)
                .font(.system(size: 13, weight: .medium, design: .rounded))
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 20, weight: .semibold))
                .offset(y: scrollCueRaised ? -4 : 1)
        }
        .foregroundStyle(.white.opacity(0.66))
        .shadow(color: .black.opacity(0.8), radius: 12)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                scrollCueRaised = true
            }
        }
    }

    private func eventArtwork(named name: String) -> UIImage? {
        guard showsArtwork else { return nil }
        return UIImage(named: name)
    }

    private func hideScrollCue() {
        guard !hasScrolled else { return }
        withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.2)) {
            hasScrolled = true
        }
    }
}

private struct CreationSeasonFeatureSection: View {
    let symbol: String
    let title: String
    let detail: String
    let artwork: UIImage?
    let placesTitleOnArtwork: Bool

    init(
        symbol: String,
        title: String,
        detail: String,
        artwork: UIImage?,
        placesTitleOnArtwork: Bool = false
    ) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.artwork = artwork
        self.placesTitleOnArtwork = placesTitleOnArtwork
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let artwork {
                if placesTitleOnArtwork {
                    artworkView(artwork)
                        .overlay(alignment: .topLeading) {
                            sectionHeading
                        }
                } else {
                    sectionHeading
                    artworkView(artwork)
                }
            } else {
                sectionHeading
            }

            Text(detail)
                .font(.system(size: 15.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 35)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func artworkView(_ artwork: UIImage) -> some View {
        Image(uiImage: artwork)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 720, maxHeight: 620)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
    }

    private var sectionHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 25)

            Text(title)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct CreationSeasonScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
