#if !COMMERCIAL_BUILD
import Foundation

enum TraditionalColorLexiconData {
    private static let undisclosedNotice = "此为非公开（商业/内购）内容，请联系我们购买获取商业版本许可证。"

    static let entries: [TraditionalColorEntry] = {
        let roles: [ColorRole] = [.qi, .cheng, .zhuan, .he]
        var result: [TraditionalColorEntry] = []
        for term in SolarTerm.allCases {
            for _ in 0..<4 {
                for role in roles {
                    result.append(
                        TraditionalColorEntry(
                            name: "示例",
                            term: term,
                            pentad: "示例",
                            role: role,
                            rgb: (128, 128, 128),
                            cmyk: (0, 0, 0, 50),
                            quote: "",
                            author: "",
                            source: undisclosedNotice
                        )
                    )
                }
            }
        }
        return result
    }()
}


enum TraditionalColorLexiconTranslations {
    static let traditionalNames: [String] = []
    static let traditionalQuotes: [String] = []
    static let traditionalAuthors: [String] = []
    static let traditionalSources: [String] = []
    static let englishNames: [String] = []
    static let englishQuotes: [String] = []
    static let englishAuthors: [String] = []
    static let englishSources: [String] = []
    static let traditionalSolarTerms: [SolarTerm: String] = [:]
    static let englishSolarTerms: [SolarTerm: String] = [:]
    static let traditionalRoles: [ColorRole: String] = [:]
    static let englishRoles: [ColorRole: String] = [:]
}
#endif
