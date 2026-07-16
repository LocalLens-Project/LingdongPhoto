// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ImageIO
import UIKit
import Vision

enum PhotoCategory: String, CaseIterable, Sendable {
    case portrait
    case family
    case dog
    case cat
    case bird
    case wildlife
    case insect
    case flower
    case forest
    case mountain
    case water
    case beach
    case sky
    case sunset
    case snow
    case rain
    case nature
    case city
    case architecture
    case street
    case night
    case food
    case fruit
    case cafe
    case travel
    case sport
    case vehicle
    case music
    case book
    case document
    case celebration
    case farm
    case interior
    case generic

    var displayName: String {
        switch self {
        case .portrait: "人物肖像"
        case .family: "亲友合影"
        case .dog: "狗狗"
        case .cat: "猫咪"
        case .bird: "鸟类"
        case .wildlife: "野生动物"
        case .insect: "昆虫微距"
        case .flower: "花卉与花园"
        case .forest: "森林草木"
        case .mountain: "山野风光"
        case .water: "江河湖海"
        case .beach: "海滩"
        case .sky: "天空云层"
        case .sunset: "日出日落"
        case .snow: "冰雪"
        case .rain: "雨景"
        case .nature: "自然风景"
        case .city: "城市天际线"
        case .architecture: "建筑"
        case .street: "街头记录"
        case .night: "夜景"
        case .food: "美食"
        case .fruit: "水果与丰收"
        case .cafe: "咖啡与甜点"
        case .travel: "旅行见闻"
        case .sport: "运动"
        case .vehicle: "车辆与旅途"
        case .music: "音乐现场"
        case .book: "阅读"
        case .document: "文字或截图"
        case .celebration: "节日庆典"
        case .farm: "田园农场"
        case .interior: "室内空间"
        case .generic: "日常瞬间"
        }
    }
}

struct PhotoSemantic: Equatable, Sendable {
    var primaryCategory: PhotoCategory
    var secondaryCategories: [PhotoCategory]
    var classificationLabels: [String]
    var recognizedText: [String]
    var faceCount: Int
    var signature: UInt64

    nonisolated static let generic = PhotoSemantic(
        primaryCategory: .generic,
        secondaryCategories: [],
        classificationLabels: [],
        recognizedText: [],
        faceCount: 0,
        signature: 0x9E3779B97F4A7C15
    )

    var summary: String {
        var values = [primaryCategory.displayName]
        values.append(contentsOf: secondaryCategories.prefix(2).map(\.displayName))
        return Array(NSOrderedSet(array: values))
            .compactMap { $0 as? String }
            .joined(separator: " · ")
    }

    static func combined(_ semantics: [PhotoSemantic]) -> PhotoSemantic {
        guard let first = semantics.first else { return .generic }
        var categoryCounts: [PhotoCategory: Double] = [:]
        var labels: [String] = []
        var text: [String] = []
        var signature = UInt64(0xCBF29CE484222325)
        var faces = 0
        for semantic in semantics {
            categoryCounts[semantic.primaryCategory, default: 0] += 2
            for category in semantic.secondaryCategories {
                categoryCounts[category, default: 0] += 0.6
            }
            labels.append(contentsOf: semantic.classificationLabels)
            text.append(contentsOf: semantic.recognizedText)
            faces += semantic.faceCount
            signature ^= semantic.signature &+ 0x9E3779B97F4A7C15
            signature = (signature << 13) | (signature >> 51)
        }
        let ordered = categoryCounts.keys.sorted {
            categoryCounts[$0, default: 0] > categoryCounts[$1, default: 0]
        }
        return PhotoSemantic(
            primaryCategory: ordered.first ?? first.primaryCategory,
            secondaryCategories: Array(ordered.dropFirst().prefix(3)),
            classificationLabels: unique(labels, limit: 12),
            recognizedText: unique(text, limit: 6),
            faceCount: faces,
            signature: signature
        )
    }

    private static func unique(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }.prefix(limit).map { $0 }
    }

    nonisolated static func uniqueLabels(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }.prefix(limit).map { $0 }
    }
}

enum PhotoContentAnalyzer {
    nonisolated static func analyze(_ data: Data) async -> PhotoSemantic {
        await Task.detached(priority: .userInitiated) {
            analyzeSynchronously(data)
        }.value
    }

    nonisolated private static func analyzeSynchronously(_ data: Data) -> PhotoSemantic {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .generic
        }

        let classificationRequest = VNClassifyImageRequest()
        let detailClassificationRequest = VNClassifyImageRequest()
        detailClassificationRequest.regionOfInterest = CGRect(x: 0.25, y: 0.28, width: 0.5, height: 0.48)
        let faceRequest = VNDetectFaceRectanglesRequest()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.automaticallyDetectsLanguage = true

        let requests: [[VNRequest]] = [
            [classificationRequest],
            [detailClassificationRequest],
            [faceRequest, textRequest]
        ]
        for requestGroup in requests {
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform(requestGroup)
            } catch {
#if DEBUG
                print("VISION_ANALYSIS_ERROR: \(error.localizedDescription)")
#endif
            }
        }

        let fullObservations = Array((classificationRequest.results ?? [])
            .filter { $0.confidence >= 0.008 }
            .prefix(36))
        let detailObservations = Array((detailClassificationRequest.results ?? [])
            .filter { $0.confidence >= 0.008 }
            .prefix(36))
        let faces = faceRequest.results?.count ?? 0
        let recognizedText = (textRequest.results ?? [])
            .compactMap { $0.topCandidates(1).first }
            .filter { $0.confidence >= 0.25 }
            .map(\.string)
            .filter {
                $0.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count >= 2
            }

        var scores: [PhotoCategory: Double] = [:]
        func score(_ observations: [VNClassificationObservation], regionWeight: Double) {
            for observation in observations {
                let label = observation.identifier.lowercased()
                for category in PhotoCategory.allCases where category != .generic {
                    let keywordHits = keywords[category, default: []].filter { matches(label: label, keyword: $0) }
                    if !keywordHits.isEmpty {
                        let specificity = 1 + min(Double(keywordHits.map(\.count).max() ?? 0) / 18, 0.65)
                        scores[category, default: 0] += Double(observation.confidence)
                            * specificity
                            * regionWeight
                            * categoryWeight(category)
                    }
                }
            }
        }
        score(fullObservations, regionWeight: 1)
        score(detailObservations, regionWeight: 1.08)

        if faces >= 2 {
            scores[.family, default: 0] += 1.35 + Double(min(faces, 8)) * 0.08
        } else if faces == 1 {
            scores[.portrait, default: 0] += 1.25
        }
        if recognizedText.count >= 5 {
            scores[.document, default: 0] += 0.72
        } else if recognizedText.count >= 2 {
            scores[.document, default: 0] += 0.24
        }

        let ordered = scores.keys.sorted { scores[$0, default: 0] > scores[$1, default: 0] }
        let primary = ordered.first.flatMap { scores[$0, default: 0] >= 0.08 ? $0 : nil } ?? .generic
        return PhotoSemantic(
            primaryCategory: primary,
            secondaryCategories: Array(ordered.dropFirst().prefix(3)),
            classificationLabels: PhotoSemantic.uniqueLabels(
                (detailObservations + fullObservations).map(\.identifier),
                limit: 14
            ),
            recognizedText: Array(recognizedText.prefix(6)),
            faceCount: faces,
            signature: signature(for: data)
        )
    }

    nonisolated private static func matches(label: String, keyword: String) -> Bool {
        if keyword.contains(" ") || keyword.contains("-") { return label.contains(keyword) }
        let tokens = label.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return tokens.contains(keyword)
    }

    nonisolated private static func categoryWeight(_ category: PhotoCategory) -> Double {
        switch category {
        case .insect: 1.65
        case .dog, .cat, .bird: 1.45
        case .flower: 1.35
        case .portrait, .family: 1.3
        case .wildlife, .fruit, .cafe, .music, .book, .celebration: 1.18
        case .nature: 0.55
        case .document: 0.82
        default: 1
        }
    }

    nonisolated private static func signature(for data: Data) -> UInt64 {
        var hash = UInt64(0xCBF29CE484222325)
        let strideSize = max(1, data.count / 2_048)
        var index = 0
        while index < data.count {
            hash ^= UInt64(data[index])
            hash &*= 0x100000001B3
            index += strideSize
        }
        return hash
    }

    nonisolated private static let keywords: [PhotoCategory: [String]] = [
        .portrait: ["person", "portrait", "selfie", "human", "face", "fashion"],
        .family: ["group", "people", "family", "friends", "wedding", "party"],
        .dog: ["dog", "puppy", "canine", "retriever", "terrier", "poodle", "husky"],
        .cat: ["cat", "kitten", "feline", "tabby", "siamese"],
        .bird: ["bird", "duck", "goose", "swan", "eagle", "owl", "parrot", "pigeon"],
        .wildlife: ["wildlife", "deer", "horse", "elephant", "lion", "tiger", "bear", "monkey", "rabbit"],
        .insect: ["insect", "arthropod", "arthropods", "butterfly", "bee", "dragonfly", "ladybug", "moth", "beetle"],
        .flower: ["flower", "floral", "blossom", "rose", "tulip", "sunflower", "snapdragon", "petunia", "daisy", "zinnia", "bouquet", "garden", "petal"],
        .forest: ["forest", "tree", "woodland", "bamboo", "jungle", "grove", "moss", "fern"],
        .mountain: ["mountain", "hill", "cliff", "valley", "canyon", "peak", "hiking", "trail"],
        .water: ["ocean", "sea", "lake", "river", "pond", "waterfall", "underwater", "swimming", "harbor"],
        .beach: ["beach", "coast", "shore", "sand", "seaside", "wave", "surfing"],
        .sky: ["sky", "cloud", "rainbow", "aerial", "airplane wing"],
        .sunset: ["sunset", "sunrise", "dawn", "dusk", "twilight", "golden hour"],
        .snow: ["snow", "winter", "ice", "frost", "ski", "glacier"],
        .rain: ["rain", "rainy", "umbrella", "puddle", "storm", "lightning"],
        .nature: ["nature", "landscape", "outdoor", "scenery", "grass", "meadow", "vegetation", "plant"],
        .city: ["city", "skyline", "downtown", "metropolis", "urban", "skyscraper"],
        .architecture: ["architecture", "building", "bridge", "church", "temple", "tower", "castle", "monument"],
        .street: ["street", "road", "alley", "sidewalk", "crosswalk", "market", "traffic"],
        .night: ["night", "neon", "moon", "star", "firefly", "nightscape"],
        .food: ["food", "meal", "dish", "cuisine", "breakfast", "lunch", "dinner", "restaurant", "cooking"],
        .fruit: ["fruit", "watermelon", "apple", "orange", "banana", "berry", "grape", "peach", "melon", "harvest"],
        .cafe: ["coffee", "cafe", "tea", "cake", "dessert", "pastry", "bakery", "latte"],
        .travel: ["travel", "vacation", "tourism", "landmark", "luggage", "hotel", "airport", "sightseeing"],
        .sport: ["sport", "fitness", "running", "cycling", "basketball", "football", "soccer", "tennis", "baseball", "workout"],
        .vehicle: ["car", "vehicle", "train", "bus", "bicycle", "motorcycle", "boat", "airplane", "subway"],
        .music: ["music", "concert", "stage", "guitar", "piano", "violin", "microphone", "performance"],
        .book: ["book", "reading", "library", "notebook", "magazine", "writing"],
        .document: ["document", "text", "screenshot", "screen", "receipt", "menu", "poster", "sign", "diagram"],
        .celebration: ["celebration", "birthday", "festival", "fireworks", "balloon", "gift", "lantern", "christmas"],
        .farm: ["farm", "field", "crop", "cattle", "sheep", "barn", "rural", "agriculture", "vegetable"],
        .interior: ["interior", "room", "home", "furniture", "bedroom", "kitchen", "office", "museum"],
        .generic: []
    ]
}

private struct CopyLexicon {
    let chineseLeads: [String]
    let chineseTails: [String]
    let englishLeads: [String]
    let englishTails: [String]
    let emojiSets: [String]
}

enum PhotoCopywriter {
    static func makeCopy(
        semantic: PhotoSemantic,
        metadata: PhotoMetadata,
        palette: [RGBColor],
        preferMoodCopy: Bool,
        variant: Int
    ) -> ArtworkCopy {
        let category = resolvedCategory(semantic.primaryCategory, palette: palette)
        let lexicon = lexicon(for: category)
        let seed = semantic.signature &+ UInt64(max(variant, 0)) &* 0x9E3779B97F4A7C15
        let chineseLead = lexicon.chineseLeads[index(seed, salt: 11, count: lexicon.chineseLeads.count)]
        let chineseTail = lexicon.chineseTails[index(seed, salt: 29, count: lexicon.chineseTails.count)]
        let englishLead = lexicon.englishLeads[index(seed, salt: 47, count: lexicon.englishLeads.count)]
        let englishTail = lexicon.englishTails[index(seed, salt: 71, count: lexicon.englishTails.count)]
        let emojiSets = matchingEmojiSets(for: semantic) ?? lexicon.emojiSets
        let emoji = emojiSets[index(seed, salt: 97, count: emojiSets.count)]
        let moodTitle = "\(chineseLead) · \(chineseTail)"
        let title = (!preferMoodCopy && metadata.hasLocation)
            ? "\(metadata.displayTitle) · \(chineseTail)"
            : moodTitle
        let english = "\(englishLead) · \(englishTail)"
        return ArtworkCopy(
            title: title,
            subtitle: english,
            journalCaption: english,
            emojis: emoji
        )
    }

    private static func resolvedCategory(_ category: PhotoCategory, palette: [RGBColor]) -> PhotoCategory {
        guard category == .generic, let dominant = palette.first else { return category }
        if dominant.green > dominant.red * 1.12 { return .nature }
        if dominant.blue > dominant.red * 1.16 { return .sky }
        if dominant.red > dominant.green * 1.22 { return .celebration }
        return .generic
    }

    private static func index(_ seed: UInt64, salt: UInt64, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var value = seed ^ (salt &* 0xD6E8FEB86659FD93)
        value ^= value >> 32
        value &*= 0xA24BAED4963EE407
        value ^= value >> 29
        return Int(value % UInt64(count))
    }

    private static func matchingEmojiSets(for semantic: PhotoSemantic) -> [String]? {
        let labels = semantic.classificationLabels.joined(separator: " ").lowercased()
        if labels.contains("butterfly") {
            return ["🦋  🌸\n🌿  ✨", "🦋  🌺\n☀️  🍃", "🌼  🦋\n🫧  💛", "🦋  🌷\n🌱  📷"]
        }
        if labels.contains("bee") {
            return ["🐝  🌼\n🍯  ☀️", "🐝  🌻\n🌿  ✨", "🌸  🐝\n💛  🍃", "🐝  🌺\n🫧  📷"]
        }
        if labels.contains("dragonfly") {
            return ["🪷  💧\n✨  🌿", "🌾  🫧\n💚  ✨", "💧  🍃\n☀️  📷", "🪷  🌱\n🫧  💫"]
        }
        if labels.contains("ladybug") {
            return ["🐞  🍃\n🌷  ✨", "🐞  🌱\n☀️  🌼", "🍀  🐞\n🫧  💛", "🐞  🌸\n🌿  📷"]
        }
        return nil
    }

    private static func lexicon(for category: PhotoCategory) -> CopyLexicon {
        var result: CopyLexicon!
        @discardableResult
        func make(_ leads: [String], _ tails: [String], _ english: [String], _ endings: [String], _ emojis: [String]) -> CopyLexicon {
            let lexicon = CopyLexicon(chineseLeads: leads, chineseTails: tails, englishLeads: english, englishTails: endings, emojiSets: emojis)
            result = lexicon
            return lexicon
        }

        switch category {
        case .portrait:
            make(["眉眼含光", "笑意落在风里", "与真实的自己相逢", "这一刻恰好动人"], ["此刻正好", "自在便是答案", "温柔自有力量", "光为你停留"], ["A Portrait in Light", "The Beauty of Being", "A Quiet Confidence", "This Is Your Moment"], ["Softly and Truly", "Held by the Light", "Exactly as You Are", "A Story in One Gaze"], ["✨  📷\n🤍  🌿", "☀️  🫶\n📸  ✨", "🌙  🤍\n🪞  💫", "🌼  📷\n🫧  🤍"])
        case .family:
            make(["欢笑围坐", "把团圆装进口袋", "熟悉的人就在身旁", "岁月因相聚温暖"], ["人间值得", "好在我们一起", "爱有回声", "日子有了名字"], ["Together Is Home", "A Table Full of Laughter", "Where Love Gathers", "Our Favorite People"], ["Memories We Keep", "Always Close at Heart", "The Warmest Place", "A Day to Remember"], ["🏡  🫶\n✨  📷", "👨‍👩‍👧‍👦  🤍\n🎈  ✨", "🥰  🍲\n🏠  📸", "🌼  🤝\n💛  📷"])
        case .dog:
            make(["快乐长着毛茸茸的尾巴", "小狗奔向今天", "风里都是撒欢的声音", "忠诚有一双亮眼睛"], ["陪伴从不缺席", "每一步都算数", "世界立刻柔软", "好心情正在摇尾巴"], ["Paws into Happiness", "A Very Good Day", "Life with a Loyal Friend", "Joy on Four Paws"], ["Always by Your Side", "Running into the Sun", "Love without Conditions", "Tail Wags Included"], ["🐶  🐾\n🦴  ☀️", "🐕  🌿\n✨  🎾", "🐾  🤎\n📷  🦴", "🐶  🫧\n🌼  🐾"])
        case .cat:
            make(["猫咪把午后按成静音", "柔软占领了窗边", "小小宇宙正在打盹", "胡须收藏了好奇心"], ["慵懒也是正事", "今日适合被治愈", "安静自有分量", "世界先停一停"], ["A Cat-Sized Universe", "Soft Paws and Sunlight", "The Art of Doing Nothing", "Whiskers in the Window"], ["A Perfectly Quiet Day", "Curiosity at Rest", "Home Feels Softer", "Small Moment Big Comfort"], ["🐱  🐾\n🧶  ☀️", "🐈  🪟\n🌿  ✨", "😺  🫧\n🤍  🐾", "🐈‍⬛  🌙\n✨  🧶"])
        case .bird:
            make(["羽翼掠过天光", "风托起轻盈的方向", "一声清鸣穿过远方", "天空写下自由"], ["去往更辽阔处", "云知道答案", "自由从不设限", "远方正在招手"], ["Wings across the Sky", "A Song above the Trees", "Born for the Open Air", "Where the Wind Leads"], ["Freedom in Flight", "A Feathered Horizon", "Light as a Wish", "Beyond the Quiet Blue"], ["🐦  ☁️\n🪶  ✨", "🦢  🌊\n🤍  🪶", "🦅  ⛰️\n☀️  🌬️", "🦜  🌿\n🎶  ✨"])
        case .wildlife:
            make(["野性在远处呼吸", "与万物交换目光", "荒野保留真实的心跳", "生命自有它的疆域"], ["敬畏每一次相遇", "世界远比想象辽阔", "不惊扰便是温柔", "自然从不沉默"], ["Wild at Heart", "A Glimpse of the Untamed", "Life beyond the Trail", "Eyes of the Wilderness"], ["Nature in Its Own Time", "A Rare Encounter", "The World Still Runs Free", "Respect the Distance"], ["🦌  🌲\n🍃  ✨", "🐘  🌿\n☀️  🐾", "🦊  🍂\n🌙  ✨", "🐎  ⛰️\n🌾  💨"])
        case .insect:
            make(["微小翅膀盛着整个春天", "花间来了一位轻客", "微观世界正在闪光", "一只蝴蝶借走了风"], ["轻盈落在此刻", "万物皆有奇迹", "小生命也很辽阔", "春意忽然有了形状"], ["A Tiny World in Flight", "Butterfly among the Blooms", "Small Wings Great Wonder", "A Visitor in the Garden"], ["Light as the Morning", "Nature in Miniature", "A Moment of Metamorphosis", "Where Petals Meet Wings"], ["🦋  🌸\n🌿  ✨", "🐝  🌼\n🍯  ☀️", "🐞  🍃\n🌷  ✨", "🪲  🌱\n🔍  💫"])
        case .flower:
            make(["花影轻摇", "春色漫过取景框", "一园芬芳正在醒来", "花开替日子作答"], ["风把香气写成诗", "万物明亮而自由", "今日份浪漫盛放", "生活自有花期"], ["A Garden Full of Light", "Petals in the Afternoon", "Where the Flowers Wake", "Blooming into the Day"], ["Carried by a Soft Breeze", "Color Finds Its Voice", "Every Season Has Its Bloom", "A Little Wild and Beautiful"], ["🌸  🌿\n🦋  ✨", "🌺  ☀️\n🌱  📷", "🌼  🍃\n🐝  💛", "🌷  🫧\n🌿  🤍"])
        case .forest:
            make(["树影收拢喧嚣", "沿着青苔走进深绿", "森林把风调成低声", "草木正在交换秘密"], ["心也慢慢安静", "深呼吸便抵达远方", "绿意没有尽头", "光从叶隙落下"], ["Into the Deep Green", "Whispers beneath the Trees", "A Forest Breathing Slowly", "Where the Moss Remembers"], ["Light through the Leaves", "Quiet beyond the Trail", "The Green Goes On", "A Place to Breathe"], ["🌲  🍃\n🌿  ✨", "🌳  🪵\n🍄  ☀️", "🎋  💚\n💨  🌱", "🌿  🫧\n🦌  🍂"])
        case .mountain:
            make(["山脊接住远风", "向高处借一片辽阔", "群山把沉默铺开", "脚步越过云的边界"], ["心有自己的海拔", "远方近在脚下", "天地教人从容", "每一步都有回响"], ["Higher than Yesterday", "Mountains beyond the Mist", "A Trail into the Distance", "Where the Peaks Begin"], ["The View Was Worth It", "Breathing above the Clouds", "A Quiet Kind of Vast", "Step by Step into Wonder"], ["⛰️  🥾\n☁️  ✨", "🏔️  🌲\n💨  ☀️", "🧗  🪨\n🌤️  🎒", "⛰️  🦅\n🌿  📷"])
        case .water:
            make(["水光把时间揉碎", "一池清澈收藏天色", "潮声缓缓靠岸", "河流带走匆忙"], ["心事随波舒展", "蓝色没有边界", "世界变得透明", "远方在水面发亮"], ["Light upon the Water", "The Tide Knows the Way", "Blue without an Ending", "A River Carrying Time"], ["Drifting into Calm", "Reflections of the Sky", "Where the Waves Rest", "A Clearer Kind of Day"], ["🌊  💧\n☀️  ✨", "🫧  🐟\n💙  🌿", "🏞️  🚣\n☁️  💦", "🌊  🐚\n✨  🤍"])
        case .beach:
            make(["海风把夏天吹近", "浪花追上脚印", "沙滩留住一整个下午", "去海边交换好心情"], ["今天只听潮声", "自由有咸咸的味道", "快乐正在靠岸", "把烦恼交给海浪"], ["Meet Me by the Sea", "Salt Air and Bare Feet", "A Day Written in Waves", "Summer along the Shore"], ["Nothing but Blue", "Happiness Comes in Tides", "Footprints toward the Sun", "Let the Ocean Keep It"], ["🏖️  🌊\n🐚  ☀️", "🌴  🥥\n🕶️  🌊", "⛱️  🫧\n🐠  💙", "🌅  🏄\n🌊  ✨"])
        case .sky:
            make(["云把天空写得很轻", "抬头遇见无边蓝", "一朵云路过今天", "风在高处整理光线"], ["心也跟着开阔", "自由就在头顶", "日子忽然透明", "把愿望交给云层"], ["An Open Sky above Us", "Clouds Passing Softly", "Blue beyond Measure", "Looking Up Changes Everything"], ["Room to Breathe", "A Wish in the Clouds", "Light without Borders", "The Day Turns Clear"], ["☁️  💙\n🫧  ✨", "🌤️  🕊️\n💨  🤍", "🌈  ☁️\n☀️  ✨", "🛫  ☁️\n💙  🌬️"])
        case .sunset:
            make(["晚霞把今天温柔收尾", "落日慢慢沉进金色", "黄昏把云烧成诗", "天边点亮最后一盏灯"], ["这一刻不必赶路", "余晖自有答案", "告别也可以很美", "把温柔留给夜晚"], ["The Last Light of Day", "Sunset in Slow Motion", "A Sky Set on Gold", "Dusk Holds the Horizon"], ["Stay for the Afterglow", "A Beautiful Kind of Goodbye", "Evening Turns to Poetry", "Before the Stars Arrive"], ["🌅  ☁️\n🧡  ✨", "🌇  💛\n🌙  🫧", "☀️  🌊\n🧡  🕊️", "🌆  ✨\n🍂  🤍"])
        case .snow:
            make(["白色覆盖了喧闹", "雪把世界按下慢放", "冬日落满柔软的光", "脚印写进新雪"], ["安静也会发亮", "寒冷里藏着浪漫", "世界洁白如初", "呼吸变成小小云朵"], ["A World Made Quiet", "Snowfall in Soft Focus", "Winter Writes in White", "Footprints into Morning"], ["Cold Air Warm Heart", "Everything Starts Again", "Silence Shines Here", "A Softer Kind of Winter"], ["❄️  🤍\n☃️  ✨", "🏔️  🧣\n❄️  ☕️", "⛷️  🌨️\n🩵  ✨", "🌲  ❄️\n🧤  🤍"])
        case .rain:
            make(["雨声洗亮了街道", "一场雨把时间放慢", "水滴在窗上写信", "城市披上朦胧滤镜"], ["潮湿也有温柔", "等天晴也等自己", "今日适合慢一点", "心事落地成涟漪"], ["Rain Changes the Rhythm", "Letters on the Window", "A City Washed Clean", "Puddles Hold the Sky"], ["Slow Down and Listen", "Soft Weather Soft Heart", "Waiting for the Clear", "A Quiet Rainy Chapter"], ["🌧️  ☂️\n💧  ✨", "🌦️  🪟\n☕️  🤍", "☔️  💦\n🌿  🫧", "⛈️  🌙\n💙  📷"])
        case .nature:
            make(["野风漫过草木", "自然把答案写在光里", "沿着绿色慢慢出发", "万物在此刻舒展"], ["日子恢复呼吸", "心向辽阔生长", "风景无需旁白", "自由落在每片叶上"], ["Back to the Open Air", "Nature Needs No Caption", "A Landscape Breathing", "Where the Wild Light Grows"], ["Let the Day Unfold", "Room for the Heart", "Green in Every Direction", "A Moment Made of Earth"], ["🌿  ☀️\n🍃  ✨", "🌱  🏞️\n💚  ☁️", "🌾  💨\n🦋  📷", "🍀  🌤️\n🫧  🤍"])
        case .city:
            make(["高楼切开天光", "城市脉搏正在加速", "霓虹与玻璃交换倒影", "在人潮里收藏坐标"], ["每扇窗都有故事", "生活向前发亮", "喧闹也有秩序", "远方藏在街角"], ["The City Keeps Moving", "Windows Full of Stories", "A Skyline in Motion", "Finding Light Downtown"], ["Every Corner Has a Pulse", "Built from a Thousand Lives", "Between Glass and Sky", "Urban Days Urban Dreams"], ["🏙️  🚇\n✨  📷", "🌆  🚦\n🏢  💫", "🌃  🚕\n💡  🖤", "🏙️  ☁️\n🚶  ✨"])
        case .architecture:
            make(["线条把空间写成秩序", "建筑收藏了时间", "光沿着结构缓慢移动", "一座空间有自己的呼吸"], ["细节值得停留", "美藏在比例之间", "岁月落进砖石", "仰望便读懂设计"], ["Lines Shape the Silence", "Architecture Holds Time", "Built for the Light", "Geometry Becomes a Place"], ["Details Worth Looking Up For", "A Story in Stone", "Space with a Memory", "Where Form Finds Meaning"], ["🏛️  📐\n✨  🪨", "🏰  ☁️\n🕰️  📷", "🌉  🌊\n💡  ✨", "⛩️  🍃\n🤍  📐"])
        case .street:
            make(["街角正在发生故事", "把日常留在路上", "人间烟火穿过镜头", "一条街有无数种生活"], ["走慢一点就会看见", "偶遇就是惊喜", "平凡也有光", "城市从脚步开始"], ["Stories around the Corner", "Street Life in One Frame", "Walking into the Everyday", "The Road Keeps a Diary"], ["Ordinary and Alive", "A Small Urban Encounter", "Every Step Finds a Scene", "Life between the Crossings"], ["🚶  🏙️\n📷  ✨", "🚦  🛵\n☀️  🥤", "🛣️  🎒\n💨  📸", "🏮  🥢\n🌆  ✨"])
        case .night:
            make(["夜色把光点亮", "星河落进城市边缘", "月亮替今天值夜", "黑夜收藏所有微光"], ["安静也璀璨", "晚风知道心事", "梦从此刻出发", "越夜越接近自己"], ["Lights after Dark", "The Moon Keeps Watch", "A Night Full of Sparks", "When the City Glows"], ["Quiet but Never Empty", "Stars beyond the Noise", "Midnight Has Its Own Color", "Dreams Begin Here"], ["🌙  ✨\n🌃  💫", "🌌  ⭐️\n🖤  🌙", "🏙️  💡\n🌙  📷", "🌠  🫧\n💙  ✨"])
        case .food:
            make(["香气先抵达镜头", "认真吃饭就是认真生活", "一餐一饭自有温度", "味道替今天留下记号"], ["人间烟火最治愈", "快乐可以被端上桌", "好胃口拥抱好日子", "这一口值得纪念"], ["Made to Be Savored", "A Table Full of Comfort", "Good Food Good Mood", "A Delicious Little Memory"], ["Happiness on a Plate", "Every Bite Tells a Story", "Warmth Served Fresh", "Taste the Moment"], ["🍽️  😋\n🥢  ✨", "🍜  🥟\n🌶️  🥤", "🥘  🥗\n🤎  📷", "🍱  🍵\n✨  🫶"])
        case .fruit:
            make(["盛夏结成清甜果实", "一篮丰收装满颜色", "果香把日子变得明亮", "自然递来一份甜"], ["清爽正在发生", "生活有滋有味", "成熟自有回甘", "快乐可以很简单"], ["A Basket Full of Summer", "Fresh from the Season", "Colors of the Harvest", "Sweetness Grown in Sunlight"], ["Juicy Bright and Simple", "Nature Serves Dessert", "A Taste of the Good Days", "Ripe with Happiness"], ["🍉  🍈\n☀️  🌿", "🍓  🍒\n🧺  ✨", "🍊  🍋\n🌱  💛", "🍎  🍇\n🌾  📷"])
        case .cafe:
            make(["咖啡香把时间调慢", "甜点替午后加一勺快乐", "杯沿盛着片刻松弛", "在香气里暂停一下"], ["慢慢喝也慢慢生活", "今日甜度刚刚好", "留白是一种享受", "温暖握在手心"], ["Coffee and a Little Time", "A Sweet Pause", "Slow Sips Soft Hours", "Afternoon Served Warm"], ["Just the Right Amount of Sweet", "A Table for Taking It Easy", "Comfort in Every Cup", "Let the World Wait"], ["☕️  🥐\n🤎  ✨", "🍰  🍓\n🫖  🌸", "🧋  🧁\n🫧  💛", "🍵  📖\n🌿  🤍"])
        case .travel:
            make(["把坐标写进故事", "下一站正在展开", "行李装着未知的风", "陌生风景成为新记忆"], ["出发本身就是答案", "世界等着被看见", "远方让日常发光", "走过便拥有"], ["Postcard from the Road", "The Next Stop Awaits", "A New Place New Story", "Miles into Memory"], ["Go Where Curiosity Leads", "The World Is Still Wide", "Departure Is an Answer", "Collected along the Way"], ["🧳  ✈️\n🗺️  ✨", "🚞  🎒\n🏞️  📷", "🛫  ☁️\n🌍  💙", "🚗  🧭\n☀️  🥤"])
        case .sport:
            make(["汗水把目标照亮", "身体记得每一次坚持", "速度追上心跳", "热爱正在全力以赴"], ["再一步就更靠近", "努力从不辜负", "能量持续上线", "为自己赢一次"], ["Built by Every Rep", "Chasing the Next Mile", "Stronger than Yesterday", "Play with All Your Heart"], ["Effort Becomes Energy", "One More Step Forward", "The Work Shows", "Move Believe Repeat"], ["🏃  💨\n🔥  ⌚️", "🏀  💪\n⚡️  🏆", "🚴  🌤️\n🥤  ✨", "⚽️  👟\n💚  🔥"])
        case .vehicle:
            make(["车轮把风景向后翻页", "沿着公路去见远方", "旅程从发动声开始", "轨道延伸出新的可能"], ["目的地交给好奇心", "一路向前便有答案", "风在窗外并肩", "出发永远年轻"], ["Roads Made for Going", "The Journey Starts Here", "Windows Full of Distance", "Motion toward Somewhere New"], ["Let the Route Surprise You", "Forward Feels Good", "Miles and Open Skies", "A Ride Worth Remembering"], ["🚗  🛣️\n💨  ☀️", "🚆  🪟\n🎒  ✨", "🏍️  🧤\n⚡️  🌄", "🚲  🌿\n☁️  📷"])
        case .music:
            make(["旋律穿过人群", "灯光为节拍发亮", "这一晚只跟随音乐", "声音把记忆重新点燃"], ["心跳与节奏同频", "热爱无需静音", "余音仍在发光", "现场永远不可复制"], ["Louder than the Night", "Music in Every Light", "A Stage Full of Feeling", "When the Chorus Hits"], ["Heartbeats in Rhythm", "One Night One Sound", "The Echo Stays", "Live and Unrepeatable"], ["🎵  🎤\n✨  🖤", "🎸  🔥\n🎶  🤘", "🎹  🌙\n🎼  💫", "🎧  💜\n🎵  ⚡️"])
        case .book:
            make(["翻页声让世界安静", "在文字里借住片刻", "一本书打开另一重远方", "故事从纸页缓慢生长"], ["阅读使时间有了深度", "心在字里行间散步", "安静自成宇宙", "答案也许在下一页"], ["Between the Pages", "A Quiet World of Words", "Stories Open Doors", "Reading into the Distance"], ["Time Well Spent", "A Mind Wandering Gently", "The Next Page Knows", "Silence with a Story"], ["📖  ☕️\n🤎  ✨", "📚  🪟\n🌿  🤍", "✍️  📝\n💡  📖", "📕  🍂\n🫖  🌙"])
        case .document:
            make(["信息被认真收进这一页", "让重点清晰可见", "一张图保存必要线索", "把复杂整理成明白"], ["记录让事情有迹可循", "细节不会被遗漏", "需要时随时回看", "清楚本身就是效率"], ["Saved for Reference", "Details in One Frame", "A Clear Record", "Information Worth Keeping"], ["Ready When Needed", "Nothing Important Missed", "Organized and Visible", "A Useful Little Capture"], ["📄  🔖\n✍️  💡", "📱  🗂️\n✅  ✨", "🧾  📌\n🔍  📝", "💻  📊\n🗒️  💡"])
        case .celebration:
            make(["快乐升起彩色气球", "这一刻值得举杯", "灯火与笑声同时绽放", "把祝福写进热闹里"], ["好日子正在发生", "欢喜要大声收藏", "愿望都有回音", "今夜只负责闪耀"], ["A Reason to Celebrate", "Joy in Full Color", "Let the Good Times Glow", "A Night Made for Cheers"], ["Wishes in the Air", "Keep This Happiness", "Lights Laughter Love", "A Memory with Sparkles"], ["🎉  🎈\n🥳  ✨", "🎂  🎁\n🕯️  💛", "🎆  🥂\n💫  🎊", "🏮  🧧\n✨  ❤️"])
        case .farm:
            make(["土地把季节酿成熟", "田野交出丰收答卷", "风吹过一片踏实", "日子在泥土里生长"], ["每一份收成都有来处", "朴素自有力量", "生活结出真实果实", "阳光没有被辜负"], ["Grown by Sun and Time", "Fields Full of Promise", "The Honest Work of Seasons", "Harvest under Open Skies"], ["Rooted in the Earth", "Every Crop Has a Story", "Simple Strong and Real", "A Season Well Tended"], ["🌾  🚜\n☀️  🌱", "🥬  🧺\n🌿  💚", "🐄  🏡\n🌤️  🌾", "🍅  🥕\n🧑‍🌾  ✨"])
        case .interior:
            make(["光在房间里找到位置", "空间安放了日常", "一室温柔慢慢展开", "家的形状藏在细节里"], ["舒适就是最好的设计", "生活在此落脚", "安静有了归处", "每个角落都很用心"], ["A Room Made for Living", "Light Finds Its Place", "Details Make a Home", "Space to Feel at Ease"], ["Comfort by Design", "Every Corner Has a Purpose", "Quiet Lives Here", "Home in the Small Things"], ["🏠  🪴\n🛋️  ✨", "🪟  ☀️\n🕯️  🤍", "🛏️  📚\n☕️  🌿", "🪞  🫧\n🏡  💛"])
        case .generic:
            make(["日常被光轻轻碰了一下", "这一刻值得被留下", "时间在这里停半拍", "普通一天也有闪光"], ["记忆从此有了形状", "生活正在认真发生", "后来想起仍会微笑", "此刻就是答案"], ["A Moment Worth Keeping", "Light Found the Everyday", "A Small Piece of Today", "Life as It Happened"], ["Saved with Care", "Ordinary and Beautiful", "A Memory Takes Shape", "This Moment Matters"], ["📷  ✨\n🌿  🤍", "☀️  🫧\n📸  💛", "🌼  🕰️\n✨  🤍", "🍃  💫\n📷  🌙"])
        }
        return result
    }
}
