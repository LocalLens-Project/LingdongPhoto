// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct Version101UpdateView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onNext: () -> Void

    private static let updateArtworkImage: UIImage? = {
        guard let url = Bundle.main.url(
            forResource: "version101_pic",
            withExtension: "jpg"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("灵动照片 1.0.1")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("让相机标志回到照片里")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("这次更新让气泡印章更像你自己的作品。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    updateArtwork
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .accessibilityLabel("使用自定义徕卡相机图标制作的气泡印章示例")

                    VStack(alignment: .leading, spacing: 14) {
                        updateItem(
                            symbol: "photo.badge.plus",
                            title: "放入你的相机图标",
                            detail: "可从“文件”App 导入 PNG 相机图标，并按品牌保存在应用本机。"
                        )
                        updateItem(
                            symbol: "camera.aperture",
                            title: "自动匹配拍摄设备",
                            detail: "启用后，气泡印章会用对应品牌图标替代通用相机标志；图标可随时替换或删除。"
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
            .accessibilityHint("关闭更新介绍，并在载入照片后查看新的模式入口")
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

    @ViewBuilder
    private var updateArtwork: some View {
        if let image = Self.updateArtworkImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                Color.secondary.opacity(0.08)
                Image(systemName: "photo")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 260)
        }
    }

}
