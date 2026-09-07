import SwiftUI


struct PostalCityCollectionNotes: View {
    @Environment(\.dismiss) private var dismiss
    static let title = "城市收录说明"
    static let footer = "城市按收录规则展示，顺序不代表排名。由地级市代管的县级市统一计入代管市，不单独展示。行政区划信息以官方公布为准。"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section("收录范围", "本目录按城市收录。由地级市代管的县级市统一计入代管市，例如余姚市计入宁波市，不单独展示或计入点亮数量。区、县同样计入可确认的所属城市。")
                    section("港澳台收录", "香港特别行政区、澳门特别行政区各收录一枚城市邮票，不按区细分。台湾地区收录台北、新北、桃园、台中、台南、高雄、基隆、新竹、嘉义九个城市；县和县辖市暂不单独收录，也不会归入邻近城市。")
                    section("不推测城市归属", "没有对应地级市的县级市，以及无法按本规则归入城市的地区，暂不提供独立城市解锁，也不会归入邻近城市。仅有省份、城市信息冲突或无法确认城市时，不自动点亮；照片仍可制作并收藏为普通邮票。")
                    section("展示顺序", "展示顺序不代表城市排名。组内已点亮城市按首次收藏时间排列在前，未点亮城市以省会、首府及计划单列市优先，其余沿用目录顺序。")
                    section("语言与目录之外的城市", "简体中文按省份展示城市目录，其他语言保留已发现城市的展示方式。切换语言不会改变本目录内城市的归并结果；目录之外的旅行城市延续原有收录方式。")
                    section("数据来源", "原有目录使用民政部公布的 2024 年县以上行政区划名称及代码；港澳台补充条目依据公开的城市及地区资料整理。邮集展示用于整理个人照片与收藏，不作为行政区划认定依据；后续变更及正式行政区划信息以官方公布为准。")
                    Link(destination: URL(string: "https://www.mca.gov.cn/mzsj/xzqh/2025/202401xzqh.html")!) {
                        Text(verbatim: "查看行政区划数据来源")
                    }
                    .font(.subheadline).padding(.vertical, 8)
                    Link(destination: URL(string: "https://www.gov.hk/sc/about/abouthk/facts.htm")!) {
                        Text(verbatim: "香港资料来源")
                    }
                    Link(destination: URL(string: "https://www.gcs.gov.mo/news/factSheet/zh-hans")!) {
                        Text(verbatim: "澳门资料来源")
                    }
                    Link(destination: URL(string: "https://www.moi.gov.tw/cl.aspx?n=11208")!) {
                        Text(verbatim: "台湾城市资料来源")
                    }
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(PostalBackground(tint: .init()))
            .navigationTitle(Text(verbatim: Self.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: dismiss.callAsFunction) { Text(verbatim: "完成") }
                }
            }
        }
        .tint(.primary)
    }

    private func section(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: title).font(.headline)
            Text(verbatim: detail).font(.subheadline).foregroundStyle(.secondary)
                .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
