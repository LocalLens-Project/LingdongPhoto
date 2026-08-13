// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct PublicGoodsCommitmentView: View {
    @Environment(\.colorScheme) private var colorScheme

    let showsUpdateNext: Bool
    let onNext: () -> Void

    @State private var qqGroupCopied = false
    @State private var emailCopied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("灵动照片 · 开源项目")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text("致力于纯粹的数字公共品")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("透明、开放，并以长期维护为目标。")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.72))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        commitmentItem(
                            symbol: "heart.text.square",
                            title: "开放，而非设立围墙",
                            detail: "灵动照片不仅是一款照片创作工具，也是一个透明、开放、持续维护的开源项目。项目不依靠出售用户数据或设置付费墙维持运行。"
                        )
                        commitmentItem(
                            symbol: "building.2",
                            title: "持续的维护与托管",
                            detail: "Wenzhou Dulan Network Technology Co., Ltd. 为项目持续提供资金、研发资源与托管支持，让团队可以专注于长期维护、隐私保护与体验改进，减少短期商业变现对产品方向的影响。"
                        )
                        commitmentItem(
                            symbol: "lock.shield",
                            title: "本地处理与开源守护",
                            detail: "项目源代码持续公开；照片识别、色彩分析与作品渲染均在设备本地完成。稳定的资源支持保障长期迭代，开源机制守护用户的知情权与创作自由。"
                        )

                        Button {
                            UIPasteboard.general.string = "1050047342"
                            withAnimation(.snappy) {
                                qqGroupCopied = true
                            }
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(2))
                                withAnimation(.snappy) {
                                    qqGroupCopied = false
                                }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(qqGroupCopied ? Color.green : Color.white)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(verbatim: "用户交流群")
                                        .font(.headline)
                                        .foregroundStyle(Color.white)
                                    if qqGroupCopied {
                                        Text(verbatim: "群号已复制，请在 QQ 中搜索添加")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.green)
                                    } else {
                                        Text(verbatim: "QQ 群：1050047342")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.white) +
                                        Text(verbatim: " · 遇到问题或想交流时欢迎加入")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.white.opacity(0.72))
                                    }
                                }

                                Spacer(minLength: 8)

                                Image(systemName: qqGroupCopied
                                    ? "checkmark.circle.fill"
                                    : "doc.on.clipboard")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(qqGroupCopied ? Color.green : Color.white.opacity(0.55))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("复制 QQ 用户交流群号")
                        .accessibilityHint("群号 1050047342 将被复制到剪贴板")

                        Button {
                            UIPasteboard.general.string = "help@locallens.cn"
                            withAnimation(.snappy) {
                                emailCopied = true
                            }
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(2))
                                withAnimation(.snappy) {
                                    emailCopied = false
                                }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(emailCopied ? .green : .white)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(verbatim: "客服邮箱")
                                        .font(.headline)
                                        .foregroundStyle(Color.white)
                                    if emailCopied {
                                        Text(verbatim: "邮箱已复制")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.green)
                                    } else {
                                        Text(verbatim: "help@locallens.cn")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.white) +
                                        Text(verbatim: " · 有问题或建议可随时邮件联系")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.white.opacity(0.72))
                                    }
                                }

                                Spacer(minLength: 8)

                                Image(systemName: emailCopied
                                    ? "checkmark.circle.fill"
                                    : "doc.on.clipboard")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(emailCopied ? Color.green : Color.white.opacity(0.55))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("复制客服邮箱地址")
                        .accessibilityHint("邮箱 help@locallens.cn 将被复制到剪贴板")
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text(showsUpdateNext ? "查看更新内容" : "开始使用")
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
            .accessibilityHint(
                showsUpdateNext
                    ? "关闭项目说明并查看版本更新内容"
                    : "关闭项目说明并开始使用灵动照片"
            )
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(Color.black)
        }
        .background {
            Color.black
                .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
    }

    private func commitmentItem(
        symbol: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.white)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
