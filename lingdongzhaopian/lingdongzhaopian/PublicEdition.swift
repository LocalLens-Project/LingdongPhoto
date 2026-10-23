// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct PublicEditionInfoCard: View {
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "info.circle").frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text("公开版本说明").font(.subheadline.weight(.semibold))
                    Text("本机照片创作与加密透明资料")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(18)
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $presented) { PublicEditionScopeView() }
    }
}

private struct PublicEditionScopeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("本版本包含") {
                    Text("普通创作模式及本机照片处理工具。商业图片与内购使用公开占位实现。")
                }
                Section("灵动来信") {
                    Text("完整来信功能仅在官方发行版提供。此公开版本不包含写信、信匣、拆信阅读器、账号与服务器实现。")
                    Text("加密协议、密钥处理边界与离线验证示例位于仓库 Transparency 目录。")
                }
                Section("加密边界") {
                    Text("正常投递在客户端加密正文，收件端本地解密。提供信件内容的举报会主动披露本封内容密钥。")
                    Text("独立示例用于核对协议与算法，不代表完整官方 App 或线上部署的可复现构建。")
                }
            }
            .navigationTitle("公开版本说明")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            } }
        }
    }
}

enum PublicEditionLegal {
    enum Page { case privacy, terms }

    static func url(_ page: Page) -> URL {
        let path = page == .privacy ? "privacy" : "terms"
        var components = URLComponents(string: "https://moerzhi.com/LingdongPhoto/" + path)!
        components.queryItems = [URLQueryItem(name: "lang", value: Bundle.main.preferredLocalizations.first ?? "en")]
        return components.url!
    }
}
