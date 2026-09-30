import SwiftUI


enum PostalFont: String, CaseIterable, Identifiable {
    case original, wenkai, brush, grassScript, retro, handwritten, postcardScript
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: "原生字体".appLocalized
        case .wenkai: "邮笺楷书".appLocalized
        case .brush: "山水墨书".appLocalized
        case .grassScript: "尺素行草".appLocalized
        case .retro: "复古铅印".appLocalized
        case .handwritten: "行旅手记".appLocalized
        case .postcardScript: "远方花体".appLocalized
        }
    }
    var compactPickerTitle: String {
        let language = (Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "zh-Hans").lowercased()
        guard language.hasPrefix("en") else { return title }
        return switch self {
        case .original: "System"
        case .wenkai: "Kaiti"
        case .brush: "Ink"
        case .grassScript: "Cursive"
        case .retro: "Press"
        case .handwritten: "Script"
        case .postcardScript: "Postcard"
        }
    }
    var originalName: String {
        switch self {
        case .original: "iOS 系统字体"
        case .wenkai: "LXGW WenKai Lite · 霞鹜文楷 轻便版"
        case .brush: "Ma Shan Zheng · 马善政毛笔楷书"
        case .grassScript: "Liu Jian Mao Cao · 刘建毛草"
        case .retro: "ZCOOL XiaoWei · 站酷小薇体"
        case .handwritten: "Long Cang · 龙藏体"
        case .postcardScript: "Sacramento · Sacramento 英文手写体"
        }
    }
    var fileName: String? {
        switch self {
        case .original: nil
        case .wenkai: "LXGWWenKaiLite-Regular"
        case .brush: "MaShanZheng-Regular"
        case .grassScript: "LiuJianMaoCao-Regular"
        case .retro: "ZCOOLXiaoWei-Regular"
        case .handwritten: "LongCang-Regular"
        case .postcardScript: "Sacramento-Regular"
        }
    }
    var postScriptName: String? { fileName }
    func uiFont(size: CGFloat, handwritten: Bool = false) -> UIFont {
        if let postScriptName, let font = UIFont(name: postScriptName, size: size) { return font }
        return handwritten ? PostalDrawing.handwriting(size: size) : .systemFont(ofSize: size)
    }
    var license: String {
        guard let fileName,
              let url = Bundle.main.url(forResource: fileName + "-OFL", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "iOS 系统字体由系统提供。".appLocalized }
        return text
    }
}

struct PostalFontPicker: View {
    @Binding var selection: PostalFont
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    var body: some View {
        let roomy = horizontalSizeClass == .regular && verticalSizeClass == .regular
        VStack(spacing: 0) {
            ForEach(PostalFont.allCases) { font in
                Button { selection = font } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: font.title)
                                .font(roomy ? .body : .caption)
                                .foregroundStyle(.secondary)
                            Group {
                                if font == .postcardScript {
                                    Text(verbatim: "Wish You Were Here")
                                } else {
                                    Text("把时光寄给远方")
                                }
                            }
                            .font(Font(font.uiFont(size: roomy ? 31 : 25)))
                        }
                        Spacer()
                        Image(systemName: selection == font ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection == font ? .black : .black.opacity(0.15))
                    }.padding(.vertical, roomy ? 18 : 14).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(Text(verbatim: font.title))
                    .accessibilityValue(selection == font ? "已选择" : "未选择")
                    .accessibilityIdentifier("postal.font.\(font.rawValue)")
                Divider().opacity(0.5)
            }
            NavigationLink("字体说明与授权") { PostalFontCredits() }
                .font(.caption).padding(.top, 22).accessibilityIdentifier("postal.fontCredits")
        }
    }
}

private struct PostalFontCredits: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("这里的中文名称是应用内的风格别名。字体文件未作改名或修改，原作者署名和完整授权保留如下。所有字体随应用提供，无需联网下载。")
                    .font(.subheadline)
                ForEach(PostalFont.allCases.filter { $0 != .original }) { font in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: font.title).font(.headline)
                        Text(font.originalName).font(.subheadline)
                        Text(font.license).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.navigationTitle("字体说明").navigationBarTitleDisplayMode(.inline)
    }
}


struct PostalEditingPage<Controls: View>: View {
    let title: String
    let preview: UIImage?
    let tint: PostalTint
    let tabs: [String]
    @Binding var selection: Int
    let onPreview: () -> Void
    let onDone: () -> Void
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        GeometryReader { proxy in
            let roomy = proxy.size.width >= 700
            VStack(spacing: 0) {
                if let preview {
                    Button(action: onPreview) {
                        Image(uiImage: preview).resizable().scaledToFit()
                            .padding(.horizontal, 28).padding(.vertical, 18)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(120, min(roomy ? 460 : 310, proxy.size.height * (roomy ? 0.46 : 0.40))))
                    }.buttonStyle(.plain).accessibilityLabel("查看作品大图")
                        .accessibilityIdentifier("postal.editPreview")
                }
                Picker("调整项目", selection: $selection) {
                    ForEach(tabs.indices, id: \.self) { index in
                        Text(LocalizedStringKey(tabs[index])).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: roomy ? 760 : 680)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("postal.editorTabs")
                ScrollView {
                    controls()
                        .frame(maxWidth: roomy ? 760 : 680)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(roomy ? 36 : 24)
                }.scrollDismissesKeyboard(.interactively)
            }
            .controlSize(roomy ? .large : .regular)
        }
        .background(PostalBackground(tint: tint))
        .navigationTitle(Text(LocalizedStringKey(title))).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", action: onDone) } }
        .tint(.black).preferredColorScheme(.light)
    }
}
