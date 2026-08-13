// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct Version200UpdateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var reachedEnd = false

    let onNext: () -> Void

    var body: some View {
        GeometryReader { container in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("灵动照片 2.0.0（Build 202601）")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("让每一张照片拥有更多表达")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("本次更新新增灵动卡片与影像票根的局部取色、影像素描、影像票根时光胶囊文案、横向票根宽度选择、影像相簿与色彩关系功能，重构轻 App 的票根验证体验，并带来部分界面优化与稳定性提升。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        updateItem(
                            symbol: "viewfinder",
                            title: "灵动卡片与影像票根新增“局部取色”",
                            detail: "在灵动卡片与影像票根（竖屏）中，均可框选照片中的指定区域单独提取颜色，生成更精准的背景取色效果；也可以随时调整选区或恢复整图取色。"
                        )
                        updateItem(
                            symbol: "pencil",
                            title: "新增“影像素描”功能",
                            detail: "把照片转化为铅笔素描、炭笔速写或水彩绘画，并可自由调整效果强度、笔触、色彩保留与纸面质感。所有影像处理均在设备端完成。"
                        )
                        updateItem(
                            symbol: "clock.arrow.circlepath",
                            title: "影像票根新增“时光胶囊”文案",
                            detail: "扫描票根时，除了原有的标准信息展示，现在可以选择“时光胶囊”叙事风格——以“这是一段 X 天前的回忆”呈现拍摄时间与情感化叙述，并区分“写给未来的我”与“分享给朋友”两种视角。"
                        )
                        updateItem(
                            symbol: "app.badge",
                            title: "重构轻 App 使用逻辑",
                            detail: "重新设计扫描影像票根后的轻 App 开场：在支持灵动岛的 iPhone 上，真实票根会继承扫描票根的主色并从灵动岛缓缓展开，随后覆盖全屏并展示完整验证内容；应用内扫描也同步采用一致的体验。"
                        )
                        updateItem(
                            symbol: "rectangle.expand.vertical",
                            title: "横向票根新增宽度选择",
                            detail: "在“横向经典”版式下，新增“紧凑 / 标准 / 海报”三档宽度选择，适配锁屏小组件、日常分享与收藏展示等不同场景。"
                        )
                        updateItem(
                            symbol: "book.closed",
                            title: "新增“影像相簿”功能",
                            detail: "把散落的影像装订成书。选择模板，加入普通照片或灵动作品，整本预览后可直接生成印刷 PDF 文件。"
                        )
                        updateItem(
                            symbol: "point.3.connected.trianglepath.dotted",
                            title: "新增“色彩关系”功能",
                            detail: "选择两张照片，从共鸣、对照与过渡三种方式观察它们的共同色、色彩距离和连接色阶。支持横图、竖图与混合方向的完整展示，并可保存对比图或完整分析作品。所有分析均在设备本机完成。"
                        )
                        updateItem(
                            symbol: "sparkles",
                            title: "部分界面优化与稳定性提升",
                            detail: "优化部分界面细节与交互体验，修复若干已知问题，提升整体运行稳定性。"
                        )
                    }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 18)

                    Color.clear
                        .frame(height: 1)
                        .background {
                            GeometryReader { marker in
                                Color.clear.preference(
                                    key: UpdateScrollBottomPreferenceKey.self,
                                    value: marker.frame(in: .named("versionUpdateScroll")).maxY
                                )
                            }
                        }
                }
                .coordinateSpace(name: "versionUpdateScroll")
                .scrollIndicators(.hidden)
                .onPreferenceChange(UpdateScrollBottomPreferenceKey.self) { bottomY in
                    let visibleBottom = container.size.height - 82
                    guard bottomY <= visibleBottom + 4, !reachedEnd else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        reachedEnd = true
                    }
                }

                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text(reachedEnd ? "下一步" : "请向上滑动查看更新内容以继续")
                        if reachedEnd {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(reachedEnd ? .headline : .subheadline.weight(.semibold))
                    .foregroundStyle(reachedEnd
                        ? (colorScheme == .dark ? Color.black : Color.white)
                        : Color.white.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Capsule())
                }
                .buttonStyle(LiquidPressButtonStyle())
                .background(
                    reachedEnd
                        ? (colorScheme == .dark ? Color.white : Color.black)
                        : Color.white.opacity(0.12),
                    in: Capsule()
                )
                .disabled(!reachedEnd)
                .accessibilityHint(reachedEnd
                    ? "关闭更新介绍，开始体验 2.0.0 的新功能"
                    : "请先将更新内容滚动到底部")
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(Color.black)
            }
            .background {
                Color.black
                    .ignoresSafeArea()
            }
            .onAppear {
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--update-scrolled") {
                    reachedEnd = true
                }
#endif
            }
        }
    }

    private func updateItem(
        symbol: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UpdateScrollBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}
