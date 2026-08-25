// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct Version210UpdateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var reachedEnd = false

    let onNext: () -> Void

    var body: some View {
        GeometryReader { container in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("灵动照片 2.1.0（Build 202616）")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("让照片的色彩与光影更好懂")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("本次更新新增英文与繁体中文翻译，加入光影解析功能，并修复部分已知问题。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        updateItem(
                            symbol: "globe",
                            title: "新增英文与繁体中文翻译",
                            detail: "iOS 版现已支持简体中文、繁体中文与英文，并可自动跟随系统语言。"
                        )
                        updateItem(
                            symbol: "waveform.path.ecg.rectangle",
                            title: "新增“光影解析”功能",
                            detail: "在琉璃色盘中切换到光影解析，即可查看照片的明暗分布、高光与暗部细节，以及简单易懂的说明。所有分析均在设备本机完成。"
                        )
                        updateItem(
                            symbol: "checkmark.seal",
                            title: "修复部分已知问题",
                            detail: "优化部分界面细节与运行稳定性，让整体使用体验更加流畅。"
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
                    ? "关闭更新介绍，开始体验 2.1.0 的新功能"
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
                Text(LocalizedStringKey(title))
                    .font(.headline)
                Text(LocalizedStringKey(detail))
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
