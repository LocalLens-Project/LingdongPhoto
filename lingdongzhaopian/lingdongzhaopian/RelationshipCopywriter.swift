// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

struct RelationshipCopyInput {
    let leftPalette: [PaletteColor]
    let rightPalette: [PaletteColor]
    let resonancePairs: [ColorPair]
    let contrastPairs: [ColorPair]
    let affinity: Int
    let lightShift: Double
    let warmthShift: Double
    let saturationShift: Double
    let neutralShift: Double
    let hueSeparation: Double
    let resonanceCoverage: Double
    let closestDistance: Double
    let averageLightness: Double
    let averageSaturation: Double
    let leftDominantName: String
    let rightDominantName: String
    let sharedName: String
    let contrastLeftName: String
    let contrastRightName: String
    let bridgeLeftName: String
    let bridgeRightName: String
}

enum RelationshipCopywriter {
    private enum Archetype: String, CaseIterable {
        case luminousUnison
        case deepUnison
        case tonalUnison
        case monochrome
        case lightShift
        case vividMuted
        case warmCool
        case neutralAnchor
        case hueTension
        case sharedAccent
        case distant
        case balancedEcho
    }

    private enum Focus {
        case lightness
        case temperature
        case saturation
        case neutrality
        case hue
        case affinity
    }

    static func compose(_ input: RelationshipCopyInput) -> RelationshipCopySet {
        let activeLocalization = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        if !activeLocalization.hasPrefix("zh-Hans") {
            return localizedSummary(for: input)
        }
        let picker = StablePicker(seed: stableSeed(for: input))
        let archetype = archetype(for: input)
        let focus = strongestFocus(for: input)
        return RelationshipCopySet(
            resonance: resonanceCopy(input, archetype: archetype, focus: focus, picker: picker),
            contrast: contrastCopy(input, archetype: archetype, focus: focus, picker: picker),
            bridge: bridgeCopy(input, archetype: archetype, focus: focus, picker: picker)
        )
    }

    private static func localizedSummary(
        for input: RelationshipCopyInput
    ) -> RelationshipCopySet {
        let shared = input.sharedName.appLocalized
        let left = input.contrastLeftName.appLocalized
        let right = input.contrastRightName.appLocalized
        let bridgeLeft = input.bridgeLeftName.appLocalized
        let bridgeRight = input.bridgeRightName.appLocalized
        return RelationshipCopySet(
            resonance: RelationshipCopy(
                title: "共同色".appLocalized,
                narrative: String(
                    format: "两张照片都含有%@，它成为最自然的视觉联系。".appLocalized,
                    shared
                )
            ),
            contrast: RelationshipCopy(
                title: "明暗与色温".appLocalized,
                narrative: String(
                    format: "%@与%@形成最清晰的差异，让两张照片各自保持个性。".appLocalized,
                    left,
                    right
                )
            ),
            bridge: RelationshipCopy(
                title: "过渡色阶".appLocalized,
                narrative: String(
                    format: "从%@逐渐走向%@，中间色让变化自然连贯。".appLocalized,
                    bridgeLeft,
                    bridgeRight
                )
            )
        )
    }

    private static func resonanceCopy(
        _ input: RelationshipCopyInput,
        archetype: Archetype,
        focus: Focus,
        picker: StablePicker
    ) -> RelationshipCopy {
        let title = picker.pick(resonanceTitles(for: archetype), salt: 11)
        let lead = picker.pick(resonanceLeads(for: archetype, input: input), salt: 17)
        let detail = picker.pick(relationDetails(for: focus, input: input), salt: 23)
        let scope = picker.pick(resonanceScopePhrases(input), salt: 29)
        return RelationshipCopy(
            title: title,
            narrative: "\(lead)，\(detail)；\(scope)。"
        )
    }

    private static func contrastCopy(
        _ input: RelationshipCopyInput,
        archetype: Archetype,
        focus: Focus,
        picker: StablePicker
    ) -> RelationshipCopy {
        let title = picker.pick(contrastTitles(for: focus, archetype: archetype), salt: 41)
        let lead = picker.pick([
            "最强差异落在\(input.contrastLeftName)与\(input.contrastRightName)之间",
            "\(input.contrastLeftName)和\(input.contrastRightName)把两端拉开",
            "两张照片的张力从\(input.contrastLeftName)与\(input.contrastRightName)开始",
            "最醒目的分界由\(input.contrastLeftName)和\(input.contrastRightName)构成"
        ], salt: 43)
        let detail = picker.pick(contrastDetails(for: focus, input: input), salt: 47)
        let ending = picker.pick(contrastEndings(input, archetype: archetype), salt: 53)
        return RelationshipCopy(
            title: title,
            narrative: "\(lead)，\(detail)；\(ending)。"
        )
    }

    private static func bridgeCopy(
        _ input: RelationshipCopyInput,
        archetype: Archetype,
        focus: Focus,
        picker: StablePicker
    ) -> RelationshipCopy {
        let title = picker.pick(bridgeTitles(for: archetype, input: input), salt: 67)
        let lead: String
        if input.bridgeLeftName == input.bridgeRightName {
            lead = picker.pick([
                "过渡以\(input.sharedName)为中心展开",
                "两端都从\(input.sharedName)附近起步",
                "色阶围绕\(input.sharedName)缓慢展开"
            ], salt: 71)
        } else {
            lead = picker.pick([
                "色阶从\(input.bridgeLeftName)经过\(input.sharedName)走向\(input.bridgeRightName)",
                "\(input.sharedName)把\(input.bridgeLeftName)和\(input.bridgeRightName)接在一起",
                "从\(input.bridgeLeftName)到\(input.bridgeRightName)，\(input.sharedName)承担中间层",
                "过渡由\(input.bridgeLeftName)起步，经\(input.sharedName)抵达\(input.bridgeRightName)"
            ], salt: 71)
        }
        let detail = picker.pick(bridgeDetails(for: focus, input: input), salt: 73)
        let ending = picker.pick(bridgeEndings(input), salt: 79)
        return RelationshipCopy(
            title: title,
            narrative: "\(lead)，\(detail)；\(ending)。"
        )
    }

    private static func archetype(for input: RelationshipCopyInput) -> Archetype {
        let light = abs(input.lightShift)
        let warmth = abs(input.warmthShift)
        let saturation = abs(input.saturationShift)
        let neutrality = abs(input.neutralShift)

        if input.averageSaturation < 0.10 { return .monochrome }
        if input.affinity >= 84, light < 0.08, warmth < 0.08 {
            return input.averageLightness > 0.68 ? .luminousUnison
                : input.averageLightness < 0.28 ? .deepUnison
                : .tonalUnison
        }
        if input.affinity >= 74 { return .tonalUnison }
        if neutrality >= 0.28 { return .neutralAnchor }
        if light >= 0.20, input.hueSeparation < 70 { return .lightShift }
        if saturation >= 0.22 { return .vividMuted }
        if warmth >= 0.22 { return .warmCool }
        if input.hueSeparation >= 125, input.averageSaturation > 0.16 { return .hueTension }
        if input.resonanceCoverage < 0.28, input.closestDistance < 0.13 { return .sharedAccent }
        if input.affinity < 32 { return .distant }
        return .balancedEcho
    }

    private static func strongestFocus(for input: RelationshipCopyInput) -> Focus {
        let scores: [(Focus, Double)] = [
            (.lightness, abs(input.lightShift) / 0.34),
            (.temperature, abs(input.warmthShift) / 0.34),
            (.saturation, abs(input.saturationShift) / 0.34),
            (.neutrality, abs(input.neutralShift) / 0.45),
            (.hue, input.hueSeparation / 180 * max(input.averageSaturation, 0.12)),
            (.affinity, Double(100 - input.affinity) / 100 * 0.72)
        ]
        return scores.max { $0.1 < $1.1 }?.0 ?? .affinity
    }

    private static func resonanceTitles(for archetype: Archetype) -> [String] {
        switch archetype {
        case .luminousUnison: ["亮色同频", "同光相认", "明色合拍"]
        case .deepUnison: ["暗调同频", "深色相认", "静默合拍"]
        case .tonalUnison: ["同频", "色调合拍", "底色相认"]
        case .monochrome: ["灰阶相认", "中性色同频", "静色呼应"]
        case .lightShift: ["同色异明", "明暗回声", "光阶呼应"]
        case .vividMuted: ["浓淡相认", "饱和回声", "一浓一淡"]
        case .warmCool: ["冷暖交点", "温差共鸣", "冷暖相认"]
        case .neutralAnchor: ["中性色锚点", "灰色承接", "静色作桥"]
        case .hueTension: ["异色相认", "远色回声", "跨色呼应"]
        case .sharedAccent: ["一点相认", "局部回声", "点色呼应"]
        case .distant: ["微弱交点", "远处回声", "仅此相认"]
        case .balancedEcho: ["遥相呼应", "色彩回声", "彼此照应"]
        }
    }

    private static func resonanceLeads(for archetype: Archetype, input: RelationshipCopyInput) -> [String] {
        let color = input.sharedName
        return switch archetype {
        case .luminousUnison:
            ["\(color)在两张照片里保持着接近的亮度", "两张照片都把\(color)留在明亮一侧", "\(color)让两端共享同一层亮色"]
        case .deepUnison:
            ["\(color)在两张照片的暗部彼此认出", "两端都把\(color)压进较深层次", "\(color)让两张照片共享沉静底色"]
        case .tonalUnison:
            ["两张照片在\(color)附近高度靠近", "\(color)构成两端最稳定的共同色", "两组主色都向\(color)收拢"]
        case .monochrome:
            ["两张照片都由低彩度颜色维持秩序", "中性色在两端形成主要呼应", "灰阶变化比色相变化更突出"]
        case .lightShift:
            ["两张照片共享\(color)，但落在不同明度", "\(color)在一明一暗之间保持联系", "同一组\(color)被两端处理成不同光阶"]
        case .vividMuted:
            ["\(color)在浓淡变化中仍能相认", "两端共享\(color)，饱和程度却不同", "\(color)连接了一端的鲜明与另一端的克制"]
        case .warmCool:
            ["\(color)停在两张照片的冷暖交界", "两端温度不同，却在\(color)附近相遇", "\(color)为冷暖两侧保留了共同落点"]
        case .neutralAnchor:
            ["中性色把\(color)稳稳托在两张照片之间", "\(color)借助灰阶区域形成联系", "两端由中性色承接，并在\(color)处相认"]
        case .hueTension:
            ["整体色相相隔较远，\(color)仍留下交点", "两端主色不同，却在\(color)处短暂重合", "\(color)是跨色相关系里最清晰的回声"]
        case .sharedAccent:
            ["\(color)不是大面积主色，却在两端同时出现", "两张照片只在局部的\(color)上彼此认出", "\(color)以点缀色的方式连接两端"]
        case .distant:
            ["两组颜色整体相隔较远，仅在\(color)附近靠近", "共同色并不多，\(color)是少数交点", "两张照片保持距离，只留下\(color)这一处回声"]
        case .balancedEcho:
            ["\(color)在两张照片之间形成稳定呼应", "两端并不相同，却都保留了\(color)", "\(color)让两组颜色保持可辨认的联系"]
        }
    }

    private static func relationDetails(for focus: Focus, input: RelationshipCopyInput) -> [String] {
        switch focus {
        case .lightness: directionalLightPhrases(input.lightShift)
        case .temperature: directionalWarmthPhrases(input.warmthShift)
        case .saturation: directionalSaturationPhrases(input.saturationShift)
        case .neutrality: directionalNeutralPhrases(input.neutralShift)
        case .hue:
            ["主色从\(input.leftDominantName)转向\(input.rightDominantName)", "两端主色分别落在\(input.leftDominantName)与\(input.rightDominantName)", "\(input.leftDominantName)和\(input.rightDominantName)保留了色相距离"]
        case .affinity:
            input.affinity >= 60
                ? ["其余颜色也保持相近步幅", "整体色差仍处于柔和范围", "主要色块没有明显分离"]
                : ["其余颜色仍保留明显距离", "共同色之外的差异依然清楚", "整体关系更像局部相连"]
        }
    }

    private static func resonanceScopePhrases(_ input: RelationshipCopyInput) -> [String] {
        if input.resonanceCoverage >= 0.58 {
            return ["这种呼应覆盖了主要色块", "共同色占据了较大画面权重", "相近颜色贯穿了两端主体"]
        }
        if input.resonanceCoverage >= 0.32 {
            return ["呼应集中在几组稳定主色", "共同色拥有清晰但有限的分量", "联系落在可见的主要区域"]
        }
        return ["共同色更接近局部点缀", "呼应范围不大但位置明确", "这份联系轻而集中"]
    }

    private static func contrastTitles(for focus: Focus, archetype: Archetype) -> [String] {
        if archetype == .monochrome { return ["灰阶分界", "明度张力", "静色两端"] }
        return switch focus {
        case .lightness: ["明暗对望", "光影两端", "亮度分界"]
        case .temperature: ["冷暖对望", "温差成景", "冷暖分界"]
        case .saturation: ["浓淡分野", "彩度张力", "鲜灰两端"]
        case .neutrality: ["彩灰对照", "中性色分界", "静彩两端"]
        case .hue: ["色相张力", "异色对望", "两色分野"]
        case .affinity: ["彼此拉开", "色差成形", "距离可见"]
        }
    }

    private static func contrastDetails(for focus: Focus, input: RelationshipCopyInput) -> [String] {
        return switch focus {
        case .lightness: directionalLightPhrases(input.lightShift)
        case .temperature: directionalWarmthPhrases(input.warmthShift)
        case .saturation: directionalSaturationPhrases(input.saturationShift)
        case .neutrality: directionalNeutralPhrases(input.neutralShift)
        case .hue:
            ["色相跨度是当前最主要的差异", "两端主色方向明显分开", "色相距离比明暗差异更醒目"]
        case .affinity:
            ["多组颜色同时保持明显距离", "差异并非来自单一色块", "整体配色没有向同一方向收拢"]
        }
    }

    private static func contrastEndings(_ input: RelationshipCopyInput, archetype: Archetype) -> [String] {
        if input.affinity >= 70 {
            return ["差异被共同底色控制在柔和范围", "张力存在但没有破坏整体统一", "对照更像同一体系里的层次变化"]
        }
        if archetype == .sharedAccent {
            return ["局部共同色让张力仍有落点", "少量呼应色避免两端完全断开", "对照强烈，但仍保留一处连接"]
        }
        if input.affinity < 32 {
            return ["这是一组清晰而直接的色彩分离", "两端各自成立，张力来自距离本身", "对照关系明显强于协调关系"]
        }
        return ["差异与呼应保持相对平衡", "张力清楚但仍能找到共同色", "两端分开，却没有完全失去联系"]
    }

    private static func bridgeTitles(for archetype: Archetype, input: RelationshipCopyInput) -> [String] {
        if archetype == .monochrome { return ["灰阶过渡", "明度成桥", "静色渐行"] }
        if input.affinity >= 76 { return ["顺色而行", "短阶相连", "同色渐行"] }
        if input.affinity < 32 { return ["长阶作桥", "跨色而行", "远色相连"] }
        return ["色阶作桥", "缓慢相连", "中间色承接"]
    }

    private static func bridgeDetails(for focus: Focus, input: RelationshipCopyInput) -> [String] {
        return switch focus {
        case .lightness:
            abs(input.lightShift) < 0.07
                ? ["过渡主要保持相近明度", "色阶无需跨越明显亮度", "两端光阶基本平稳"]
                : directionalLightPhrases(input.lightShift)
        case .temperature:
            abs(input.warmthShift) < 0.07
                ? ["冷暖变化保持平缓", "色温不需要明显转向", "两端温度接近"]
                : directionalWarmthPhrases(input.warmthShift)
        case .saturation:
            abs(input.saturationShift) < 0.07
                ? ["彩度在中间段保持稳定", "浓淡变化较少", "过渡无需明显增减饱和度"]
                : directionalSaturationPhrases(input.saturationShift)
        case .neutrality:
            ["中性色承担了缓冲层", "灰阶颜色让两端更容易衔接", "低彩度区域提供了自然停顿"]
        case .hue:
            ["中间色逐步缩短色相距离", "色相沿连续方向缓慢变化", "桥接重点是平滑转换主色方向"]
        case .affinity:
            ["中间层负责收拢整体色差", "桥接色让分离的主色逐步靠近", "过渡重点是保留连续步幅"]
        }
    }

    private static func bridgeEndings(_ input: RelationshipCopyInput) -> [String] {
        if input.affinity >= 76 {
            return ["只需很短的色阶就能连接", "过渡紧凑而自然", "两端几乎可以直接衔接"]
        }
        if input.affinity >= 48 {
            return ["保留中间层会让连接更平稳", "这条色阶能自然承接两端", "过渡长度适中，关系清楚"]
        }
        return ["需要更多中间层才能避免跳变", "完整色阶比直接拼接更稳妥", "让颜色逐级变化会更自然"]
    }

    private static func directionalLightPhrases(_ shift: Double) -> [String] {
        if abs(shift) < 0.07 {
            return ["两端明度基本相当", "图1与图2处在接近的光阶", "明暗差异保持克制"]
        }
        if shift > 0 {
            return ["图2更明亮，图1保留较深层次", "光阶从图1向图2抬高", "图1偏暗，图2把颜色推向亮部"]
        }
        return ["图1更明亮，图2保留较深层次", "光阶从图1向图2降低", "图2偏暗，图1把颜色留在亮部"]
    }

    private static func directionalWarmthPhrases(_ shift: Double) -> [String] {
        if abs(shift) < 0.07 {
            return ["两端冷暖基本相当", "图1与图2保持接近色温", "温度差异并不突出"]
        }
        if shift > 0 {
            return ["图2偏暖，图1相对偏冷", "色温从图1向图2升高", "图1保留冷色，图2接住暖色"]
        }
        return ["图1偏暖，图2相对偏冷", "色温从图1向图2降低", "图2保留冷色，图1接住暖色"]
    }

    private static func directionalSaturationPhrases(_ shift: Double) -> [String] {
        if abs(shift) < 0.07 {
            return ["两端彩度基本相当", "浓淡程度保持接近", "饱和度没有明显分离"]
        }
        if shift > 0 {
            return ["图2更鲜明，图1相对克制", "彩度从图1向图2增加", "图1偏灰，图2保留更多纯色"]
        }
        return ["图1更鲜明，图2相对克制", "彩度从图1向图2降低", "图2偏灰，图1保留更多纯色"]
    }

    private static func directionalNeutralPhrases(_ shift: Double) -> [String] {
        if abs(shift) < 0.10 {
            return ["两端中性色占比接近", "灰阶分量保持相当", "彩色与中性色的比例相近"]
        }
        if shift > 0 {
            return ["图2含有更多中性色，图1更偏彩色", "灰阶分量从图1向图2增加", "图2更克制，图1保留更多彩色"]
        }
        return ["图1含有更多中性色，图2更偏彩色", "灰阶分量从图1向图2减少", "图1更克制，图2保留更多彩色"]
    }

    private static func stableSeed(for input: RelationshipCopyInput) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        func absorb(_ value: Double) {
            let quantized = UInt64(max(0, min(65_535, Int((value * 65_535).rounded()))))
            hash ^= quantized
            hash &*= 1_099_511_628_211
        }
        for color in input.leftPalette + input.rightPalette {
            absorb(color.red)
            absorb(color.green)
            absorb(color.blue)
            absorb(color.weight)
        }
        absorb(Double(input.affinity) / 100)
        absorb((input.lightShift + 1) / 2)
        absorb((input.warmthShift + 1) / 2)
        absorb((input.saturationShift + 1) / 2)
        return hash
    }

    private struct StablePicker {
        let seed: UInt64

        func pick(_ values: [String], salt: UInt64) -> String {
            guard !values.isEmpty else { return "色彩关系仍在形成" }
            var value = seed &+ salt &* 0x9E3779B97F4A7C15
            value ^= value >> 30
            value &*= 0xBF58476D1CE4E5B9
            value ^= value >> 27
            value &*= 0x94D049BB133111EB
            value ^= value >> 31
            return values[Int(value % UInt64(values.count))]
        }
    }
}
