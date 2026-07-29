// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct Version102UpdateView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("灵动照片 1.0.2")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("让照片成为可以分享的票根")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("这次更新带来了影像票根、扫码验证、取色渐变与轻应用体验。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        updateItem(
                            symbol: "ticket",
                            title: "影像票根与扫描验证票根",
                            detail: "可以将照片制作成具有旅行纪念感的影像票根，提供横向经典、纵向旅行和极简凭证等版式，并可自定义展示文字、拍摄信息、配色及验证二维码。通过“扫描验证票根”，可读取二维码并查看对应的票根信息。"
                        )
                        updateItem(
                            symbol: "paintpalette",
                            title: "动态照片卡片新增“取色渐变”",
                            detail: "顶部背景可根据照片的代表色自动生成渐变效果，并自动调整文字显示效果，让卡片色彩与照片更加协调。"
                        )
                        updateItem(
                            symbol: "appclip",
                            title: "新增轻应用（App Clip）",
                            detail: "无需提前安装完整应用，使用 iPhone 相机扫描影像票根上的验证二维码，即可快速打开轻应用，查看票根内容及相关公开信息。"
                        )
                        updateItem(
                            symbol: "square.grid.2x2",
                            title: "更直观的模式浏览",
                            detail: "未添加照片时，每个创作模式都会显示对应的专属图标；左右滑动即可浏览，并可从主界面最后一页直接进入“扫描验证票根”。"
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text("下一步")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(colorScheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .contentShape(Capsule())
            }
            .buttonStyle(LiquidPressButtonStyle())
            .background(colorScheme == .dark ? Color.white : Color.black, in: Capsule())
            .accessibilityHint("关闭更新介绍，开始体验 1.0.2 的新功能")
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
