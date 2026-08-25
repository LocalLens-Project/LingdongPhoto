// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import Foundation

struct AlbumColor: Codable, Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
    }

    init(_ color: RGBColor) {
        self.init(red: Double(color.red), green: Double(color.green), blue: Double(color.blue))
    }

    var rgb: RGBColor {
        RGBColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue))
    }

    nonisolated static let fallback = [
        AlbumColor(red: 0.20, green: 0.31, blue: 0.25),
        AlbumColor(red: 0.55, green: 0.68, blue: 0.58),
        AlbumColor(red: 0.89, green: 0.82, blue: 0.70)
    ]
}

struct AlbumNormalizedRect: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    nonisolated func rect(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX + bounds.width * x,
            y: bounds.minY + bounds.height * y,
            width: bounds.width * width,
            height: bounds.height * height
        )
    }
}

enum AlbumBookFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case portraitA5
    case square
    case landscapeA4

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portraitA5: "A5 竖版"
        case .square: "方形相簿"
        case .landscapeA4: "A4 横版"
        }
    }

    var shortTitle: String {
        switch self {
        case .portraitA5: "竖版"
        case .square: "方形"
        case .landscapeA4: "横版"
        }
    }

    nonisolated var millimeters: CGSize {
        switch self {
        case .portraitA5: CGSize(width: 148, height: 210)
        case .square: CGSize(width: 210, height: 210)
        case .landscapeA4: CGSize(width: 297, height: 210)
        }
    }

    nonisolated var aspectRatio: CGFloat {
        millimeters.width / millimeters.height
    }
}

enum AlbumTheme: String, Codable, CaseIterable {
    case travel
    case family
    case childhood
    case companion
    case blank

    var title: String {
        switch self {
        case .travel: "旅行"
        case .family: "家庭"
        case .childhood: "儿童"
        case .companion: "动物"
        case .blank: "自定义"
        }
    }

    var symbol: String {
        switch self {
        case .travel: "map"
        case .family: "house"
        case .childhood: "sparkles"
        case .companion: "pawprint"
        case .blank: "square.dashed"
        }
    }
}

enum AlbumDesignStyle: String, Codable, CaseIterable {
    case editorialLetter
    case coastPostcard
    case filmDiary
    case warmNeutral
    case softArch
    case sundayTable
    case littleUniverse
    case rainbowPlay
    case growthNotes
    case quietCompanion
    case playfulPaws
    case trailJournal
    case cleanCanvas
    case studioGrid
    case freeCollage

    var shortTitle: String {
        switch self {
        case .editorialLetter: "编辑部留白"
        case .coastPostcard: "海岸明信片"
        case .filmDiary: "胶片旅行志"
        case .warmNeutral: "暖调日常"
        case .softArch: "柔光拱廊"
        case .sundayTable: "周日手帐"
        case .littleUniverse: "星球成长册"
        case .rainbowPlay: "彩虹游戏场"
        case .growthNotes: "成长刻度"
        case .quietCompanion: "安静肖像"
        case .playfulPaws: "爪印手记"
        case .trailJournal: "散步路线"
        case .cleanCanvas: "纯粹留白"
        case .studioGrid: "设计工作室"
        case .freeCollage: "自由剪贴簿"
        }
    }
}

enum AlbumPageRole: String, Codable {
    case cover
    case content
    case backCover
}

enum AlbumPageLayout: String, Codable, CaseIterable, Identifiable {
    case coverWindow
    case heroBottom
    case stackThree
    case gridSix
    case portraitStory
    case splitPair
    case editorialThree
    case workFeature
    case fullBleed
    case collage
    case quotePhoto
    case oceanPoster
    case cinematicSea
    case verticalTravelogue
    case postcardScrapbook
    case tornPaperJourney
    case colorAtlas
    case clippedMemoir
    case galleryWindow
    case freeform
    case backCover

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coverWindow: "封面窗景"
        case .heroBottom: "主图留白"
        case .stackThree: "三段叙事"
        case .gridSix: "六格印象"
        case .portraitStory: "人物故事"
        case .splitPair: "双图对照"
        case .editorialThree: "杂志三图"
        case .workFeature: "作品展示"
        case .fullBleed: "满版影像"
        case .collage: "自由拼贴"
        case .quotePhoto: "图文寄语"
        case .oceanPoster: "海报双页"
        case .cinematicSea: "电影海岸"
        case .verticalTravelogue: "竖排游记"
        case .postcardScrapbook: "明信片剪贴"
        case .tornPaperJourney: "撕纸旅途"
        case .colorAtlas: "色彩地图"
        case .clippedMemoir: "票据手记"
        case .galleryWindow: "窗景画廊"
        case .freeform: "空白画布"
        case .backCover: "封底"
        }
    }

    var symbol: String {
        switch self {
        case .coverWindow: "book.closed"
        case .heroBottom: "rectangle.bottomhalf.inset.filled"
        case .stackThree: "rectangle.grid.1x2"
        case .gridSix: "square.grid.3x2"
        case .portraitStory: "person.crop.rectangle"
        case .splitPair: "rectangle.split.2x1"
        case .editorialThree: "rectangle.3.group"
        case .workFeature: "photo.artframe"
        case .fullBleed: "rectangle.inset.filled"
        case .collage: "square.on.square"
        case .quotePhoto: "quote.bubble"
        case .oceanPoster: "rectangle.split.2x1.fill"
        case .cinematicSea: "film.stack"
        case .verticalTravelogue: "text.justify.leading"
        case .postcardScrapbook: "photo.stack"
        case .tornPaperJourney: "doc.richtext"
        case .colorAtlas: "square.grid.3x3.middle.filled"
        case .clippedMemoir: "paperclip"
        case .galleryWindow: "rectangle.grid.2x2"
        case .freeform: "square.dashed"
        case .backCover: "book.closed.fill"
        }
    }
}

enum AlbumAssetKind: String, Codable {
    case photo
    case work

    var title: String {
        switch self {
        case .photo: "系统照片"
        case .work: "灵动作品"
        }
    }
}

enum AlbumSlotExpectation: String, Codable {
    case any
    case photo
    case work

    var placeholderTitle: String {
        switch self {
        case .any: "添加内容"
        case .photo: "添加照片"
        case .work: "添加灵动作品"
        }
    }
}

enum AlbumImageFit: String, Codable {
    case fill
    case fit
}

struct AlbumAsset: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: AlbumAssetKind
    var workKind: String?
    var fileName: String
    var thumbnailFileName: String
    var pixelWidth: Int
    var pixelHeight: Int
    var importedAt: Date
    var captureDate: Date?
    var colors: [AlbumColor]

    nonisolated var aspectRatio: CGFloat {
        guard pixelHeight > 0 else { return 1 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }

    /// Archived image tickets are already complete compositions. Cropping or
    /// moving their pixels would damage the ticket structure and QR layout.
    var locksContentTransform: Bool {
        kind == .work && workKind == CreationMode.travelTicket.rawValue
    }
}

struct AlbumSlot: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var frame: AlbumNormalizedRect
    var expectation: AlbumSlotExpectation
    var assetID: UUID?
    var fit: AlbumImageFit
    var cornerRadius: Double
    var rotation: Double
    var zIndex: Int
    /// Optional fields keep projects created before content transforms decodable.
    var contentScale: Double?
    var contentOffsetX: Double?
    var contentOffsetY: Double?

    init(
        id: UUID = UUID(),
        frame: AlbumNormalizedRect,
        expectation: AlbumSlotExpectation = .any,
        assetID: UUID? = nil,
        fit: AlbumImageFit = .fill,
        cornerRadius: Double = 0,
        rotation: Double = 0,
        zIndex: Int = 0,
        contentScale: Double? = nil,
        contentOffsetX: Double? = nil,
        contentOffsetY: Double? = nil
    ) {
        self.id = id
        self.frame = frame
        self.expectation = expectation
        self.assetID = assetID
        self.fit = fit
        self.cornerRadius = cornerRadius
        self.rotation = rotation
        self.zIndex = zIndex
        self.contentScale = contentScale
        self.contentOffsetX = contentOffsetX
        self.contentOffsetY = contentOffsetY
    }

    nonisolated var resolvedContentScale: Double { max(1, contentScale ?? 1) }
    nonisolated var resolvedContentOffsetX: Double { contentOffsetX ?? 0 }
    nonisolated var resolvedContentOffsetY: Double { contentOffsetY ?? 0 }
}

enum AlbumTextStyle: String, Codable {
    case coverTitle
    case coverSubtitle
    case headline
    case body
    case caption
    case quote
    case pageNumber
}

enum AlbumTextAlignment: String, Codable, Sendable {
    case leading
    case center
    case trailing
}

enum AlbumPageFontStyle: String, Codable, CaseIterable, Identifiable {
    case template
    case modern
    case songti
    case rounded
    case handwritten
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .template: "跟随模板"
        case .modern: "现代黑体"
        case .songti: "典雅宋体"
        case .rounded: "柔和圆体"
        case .handwritten: "手写楷体"
        case .monospaced: "档案等宽"
        }
    }

    var sample: String {
        switch self {
        case .template: "模板"
        case .modern: "远方"
        case .songti: "山海"
        case .rounded: "日常"
        case .handwritten: "手记"
        case .monospaced: "2026"
        }
    }
}

struct AlbumTextBlock: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var frame: AlbumNormalizedRect
    var style: AlbumTextStyle
    var alignment: AlbumTextAlignment
    var isEditable: Bool

    init(
        id: UUID = UUID(),
        text: String,
        frame: AlbumNormalizedRect,
        style: AlbumTextStyle,
        alignment: AlbumTextAlignment = .leading,
        isEditable: Bool = true
    ) {
        self.id = id
        self.text = text
        self.frame = frame
        self.style = style
        self.alignment = alignment
        self.isEditable = isEditable
    }
}

struct AlbumPage: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var role: AlbumPageRole
    var layout: AlbumPageLayout
    var slots: [AlbumSlot]
    var textBlocks: [AlbumTextBlock]
    var tintStrength: Double
    /// Page-scoped typography. Nil means the template's original typography.
    var fontStyle: AlbumPageFontStyle?

    init(
        id: UUID = UUID(),
        role: AlbumPageRole = .content,
        layout: AlbumPageLayout,
        slots: [AlbumSlot],
        textBlocks: [AlbumTextBlock] = [],
        tintStrength: Double = 0.05,
        fontStyle: AlbumPageFontStyle? = nil
    ) {
        self.id = id
        self.role = role
        self.layout = layout
        self.slots = slots
        self.textBlocks = textBlocks
        self.tintStrength = tintStrength
        self.fontStyle = fontStyle
    }

    var filledSlotCount: Int { slots.lazy.filter { $0.assetID != nil }.count }
    var emptySlotCount: Int { slots.count - filledSlotCount }
    nonisolated var resolvedFontStyle: AlbumPageFontStyle { fontStyle ?? .template }
}

struct AlbumProject: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var subtitle: String
    var theme: AlbumTheme
    /// Optional so projects created before the multi-template update remain decodable.
    var designStyle: AlbumDesignStyle?
    var format: AlbumBookFormat
    var createdAt: Date
    var modifiedAt: Date
    var pages: [AlbumPage]
    var assets: [AlbumAsset]
    var palette: [AlbumColor]

    var emptySlotCount: Int {
        pages.reduce(0) { $0 + $1.emptySlotCount }
    }

    var filledSlotCount: Int {
        pages.reduce(0) { $0 + $1.filledSlotCount }
    }

    nonisolated var resolvedDesignStyle: AlbumDesignStyle {
        designStyle ?? AlbumTemplateCatalog.defaultStyle(for: theme)
    }
}

struct AlbumTemplateDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let theme: AlbumTheme
    let title: String
    let subtitle: String
    let detail: String
    let defaultFormat: AlbumBookFormat
    let colors: [AlbumColor]
    let style: AlbumDesignStyle
    let layouts: [AlbumPageLayout]
}

enum AlbumTemplateCatalog: Sendable {
    nonisolated static let templates: [AlbumTemplateDescriptor] = [
        AlbumTemplateDescriptor(
            id: "travel-editorial",
            theme: .travel,
            title: "远方来信",
            subtitle: "极简旅行画册",
            detail: "留白、时间线与宽幅票根共同记录一段旅程",
            defaultFormat: .portraitA5,
            colors: [
                AlbumColor(red: 0.20, green: 0.39, blue: 0.34),
                AlbumColor(red: 0.67, green: 0.78, blue: 0.64),
                AlbumColor(red: 0.89, green: 0.81, blue: 0.66)
            ],
            style: .editorialLetter,
            layouts: [.coverWindow, .oceanPoster, .cinematicSea, .verticalTravelogue, .tornPaperJourney, .workFeature, .quotePhoto, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "travel-postcard",
            theme: .travel,
            title: "海岸邮局",
            subtitle: "清透明信片画册",
            detail: "蓝调纸张、邮戳和横向照片，让海边与城市像一组寄出的信",
            defaultFormat: .landscapeA4,
            colors: [
                AlbumColor(red: 0.22, green: 0.49, blue: 0.64),
                AlbumColor(red: 0.70, green: 0.84, blue: 0.88),
                AlbumColor(red: 0.94, green: 0.83, blue: 0.63)
            ],
            style: .coastPostcard,
            layouts: [.coverWindow, .cinematicSea, .verticalTravelogue, .postcardScrapbook, .colorAtlas, .galleryWindow, .workFeature, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "travel-film",
            theme: .travel,
            title: "漫游胶片",
            subtitle: "电影感旅途记录",
            detail: "胶片编号、黑色细框与连续画面，适合夜景、公路和城市漫游",
            defaultFormat: .portraitA5,
            colors: [
                AlbumColor(red: 0.12, green: 0.15, blue: 0.16),
                AlbumColor(red: 0.48, green: 0.38, blue: 0.27),
                AlbumColor(red: 0.82, green: 0.55, blue: 0.31)
            ],
            style: .filmDiary,
            layouts: [.coverWindow, .cinematicSea, .galleryWindow, .clippedMemoir, .fullBleed, .verticalTravelogue, .workFeature, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "family-warmth",
            theme: .family,
            title: "日常相聚",
            subtitle: "温暖家庭影集",
            detail: "用柔和色块、双图与生活片段收藏共同的日常",
            defaultFormat: .square,
            colors: [
                AlbumColor(red: 0.58, green: 0.35, blue: 0.28),
                AlbumColor(red: 0.89, green: 0.69, blue: 0.54),
                AlbumColor(red: 0.95, green: 0.88, blue: 0.77)
            ],
            style: .warmNeutral,
            layouts: [.coverWindow, .clippedMemoir, .postcardScrapbook, .colorAtlas, .quotePhoto, .collage, .heroBottom, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "family-arches",
            theme: .family,
            title: "家的形状",
            subtitle: "柔光拱廊影集",
            detail: "奶油纸色、柔和拱形与亲密双人照，突出拥抱和生活细节",
            defaultFormat: .square,
            colors: [
                AlbumColor(red: 0.67, green: 0.52, blue: 0.43),
                AlbumColor(red: 0.86, green: 0.74, blue: 0.65),
                AlbumColor(red: 0.95, green: 0.91, blue: 0.84)
            ],
            style: .softArch,
            layouts: [.coverWindow, .quotePhoto, .galleryWindow, .portraitStory, .clippedMemoir, .colorAtlas, .heroBottom, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "family-sunday",
            theme: .family,
            title: "周日餐桌",
            subtitle: "生活剪贴手帐",
            detail: "便签、胶带感叠放和暖色照片，收藏饭桌旁最松弛的日常",
            defaultFormat: .portraitA5,
            colors: [
                AlbumColor(red: 0.38, green: 0.43, blue: 0.31),
                AlbumColor(red: 0.77, green: 0.57, blue: 0.39),
                AlbumColor(red: 0.93, green: 0.82, blue: 0.62)
            ],
            style: .sundayTable,
            layouts: [.coverWindow, .postcardScrapbook, .clippedMemoir, .heroBottom, .colorAtlas, .quotePhoto, .workFeature, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "childhood-spark",
            theme: .childhood,
            title: "小小宇宙",
            subtitle: "儿童成长记录",
            detail: "轻快网格与成长标记，为每一次变化留下位置",
            defaultFormat: .square,
            colors: [
                AlbumColor(red: 0.30, green: 0.55, blue: 0.68),
                AlbumColor(red: 0.96, green: 0.73, blue: 0.45),
                AlbumColor(red: 0.92, green: 0.58, blue: 0.62)
            ],
            style: .littleUniverse,
            layouts: [.coverWindow, .heroBottom, .colorAtlas, .postcardScrapbook, .portraitStory, .quotePhoto, .workFeature, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "childhood-rainbow",
            theme: .childhood,
            title: "彩虹练习册",
            subtitle: "明快儿童影集",
            detail: "圆角画框、彩虹弧线与大胆色块，适合游戏、生日和亲子时刻",
            defaultFormat: .square,
            colors: [
                AlbumColor(red: 0.31, green: 0.64, blue: 0.82),
                AlbumColor(red: 0.98, green: 0.72, blue: 0.24),
                AlbumColor(red: 0.95, green: 0.38, blue: 0.46)
            ],
            style: .rainbowPlay,
            layouts: [.coverWindow, .postcardScrapbook, .colorAtlas, .fullBleed, .clippedMemoir, .galleryWindow, .quotePhoto, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "childhood-growth",
            theme: .childhood,
            title: "成长刻度",
            subtitle: "年度成长档案",
            detail: "日期、刻度与规整网格适合按月份记录身高、第一次和作品",
            defaultFormat: .portraitA5,
            colors: [
                AlbumColor(red: 0.23, green: 0.45, blue: 0.55),
                AlbumColor(red: 0.65, green: 0.78, blue: 0.64),
                AlbumColor(red: 0.94, green: 0.68, blue: 0.52)
            ],
            style: .growthNotes,
            layouts: [.coverWindow, .heroBottom, .colorAtlas, .verticalTravelogue, .portraitStory, .workFeature, .quotePhoto, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "pet-companion",
            theme: .companion,
            title: "与你相伴",
            subtitle: "动物陪伴相簿",
            detail: "大幅肖像、细节拼贴与轻松注脚记录陪伴",
            defaultFormat: .portraitA5,
            colors: [
                AlbumColor(red: 0.31, green: 0.31, blue: 0.27),
                AlbumColor(red: 0.66, green: 0.62, blue: 0.49),
                AlbumColor(red: 0.90, green: 0.86, blue: 0.72)
            ],
            style: .quietCompanion,
            layouts: [.coverWindow, .portraitStory, .galleryWindow, .colorAtlas, .quotePhoto, .clippedMemoir, .fullBleed, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "pet-playful",
            theme: .companion,
            title: "毛茸日记",
            subtitle: "轻松爪印画册",
            detail: "圆润标题、爪印和不规则拼贴，记录打滚、睡觉和搞怪瞬间",
            defaultFormat: .square,
            colors: [
                AlbumColor(red: 0.25, green: 0.47, blue: 0.52),
                AlbumColor(red: 0.91, green: 0.61, blue: 0.36),
                AlbumColor(red: 0.94, green: 0.84, blue: 0.62)
            ],
            style: .playfulPaws,
            layouts: [.coverWindow, .postcardScrapbook, .colorAtlas, .portraitStory, .quotePhoto, .galleryWindow, .workFeature, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "pet-trail",
            theme: .companion,
            title: "一起散步",
            subtitle: "户外陪伴日志",
            detail: "路线虚线、自然绿色与宽幅风景，适合公园、山野和海边散步",
            defaultFormat: .landscapeA4,
            colors: [
                AlbumColor(red: 0.20, green: 0.37, blue: 0.29),
                AlbumColor(red: 0.49, green: 0.64, blue: 0.45),
                AlbumColor(red: 0.82, green: 0.75, blue: 0.55)
            ],
            style: .trailJournal,
            layouts: [.coverWindow, .fullBleed, .oceanPoster, .verticalTravelogue, .tornPaperJourney, .colorAtlas, .quotePhoto, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "blank-studio",
            theme: .blank,
            title: "留白画布",
            subtitle: "自定义影像书",
            detail: "从空白页面开始，自由加入照片与灵动作品",
            defaultFormat: .portraitA5,
            colors: AlbumColor.fallback,
            style: .cleanCanvas,
            layouts: [.coverWindow, .freeform, .freeform, .freeform, .freeform, .freeform, .freeform, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "blank-grid",
            theme: .blank,
            title: "编辑工作室",
            subtitle: "理性网格画册",
            detail: "细网格、编号和多种杂志版式，适合作品集与摄影项目",
            defaultFormat: .portraitA5,
            colors: [
                AlbumColor(red: 0.18, green: 0.22, blue: 0.24),
                AlbumColor(red: 0.57, green: 0.65, blue: 0.67),
                AlbumColor(red: 0.88, green: 0.88, blue: 0.84)
            ],
            style: .studioGrid,
            layouts: [.coverWindow, .editorialThree, .cinematicSea, .galleryWindow, .colorAtlas, .workFeature, .freeform, .backCover]
        ),
        AlbumTemplateDescriptor(
            id: "blank-collage",
            theme: .blank,
            title: "自由剪贴簿",
            subtitle: "随性空画布",
            detail: "纸胶带、旋转卡片与自由页混排，适合完全按照自己的方式装订",
            defaultFormat: .square,
            colors: [
                AlbumColor(red: 0.40, green: 0.34, blue: 0.44),
                AlbumColor(red: 0.75, green: 0.57, blue: 0.62),
                AlbumColor(red: 0.91, green: 0.78, blue: 0.61)
            ],
            style: .freeCollage,
            layouts: [.coverWindow, .postcardScrapbook, .freeform, .clippedMemoir, .tornPaperJourney, .workFeature, .freeform, .backCover]
        )
    ]

    nonisolated static func templates(for theme: AlbumTheme) -> [AlbumTemplateDescriptor] {
        templates.filter { $0.theme == theme }
    }

    nonisolated static func featuredTemplate(for theme: AlbumTheme) -> AlbumTemplateDescriptor {
        templates(for: theme).first ?? templates[0]
    }

    nonisolated static func defaultStyle(for theme: AlbumTheme) -> AlbumDesignStyle {
        featuredTemplate(for: theme).style
    }

    static let addableLayouts: [AlbumPageLayout] = [
        .heroBottom, .splitPair, .editorialThree, .gridSix,
        .oceanPoster, .cinematicSea, .verticalTravelogue, .postcardScrapbook,
        .tornPaperJourney, .colorAtlas, .clippedMemoir, .galleryWindow,
        .workFeature, .quotePhoto, .fullBleed, .freeform
    ]

    static func makeProject(
        from descriptor: AlbumTemplateDescriptor,
        format: AlbumBookFormat,
        now: Date = .now
    ) -> AlbumProject {
        AlbumProject(
            id: UUID(),
            title: descriptor.title.appLocalized,
            subtitle: descriptor.subtitle.appLocalized,
            theme: descriptor.theme,
            designStyle: descriptor.style,
            format: format,
            createdAt: now,
            modifiedAt: now,
            pages: initialPages(for: descriptor),
            assets: [],
            palette: descriptor.colors
        )
    }

    static func makePage(
        layout: AlbumPageLayout,
        theme: AlbumTheme,
        pageNumber: Int
    ) -> AlbumPage {
        let headline = (theme == .blank ? "写下这一页" : defaultSectionTitle(theme, pageNumber))
            .appLocalized
        let caption = defaultCaption(theme).appLocalized
        switch layout {
        case .coverWindow:
            return AlbumPage(
                role: .cover,
                layout: layout,
                slots: [slot(0.28, 0.27, 0.44, 0.34, .photo, fit: .fill, radius: 0.012)],
                textBlocks: [
                    text(headline, 0.10, 0.08, 0.80, 0.12, .coverTitle, .center),
                    text(caption, 0.14, 0.82, 0.72, 0.08, .coverSubtitle, .center)
                ],
                tintStrength: 0.64
            )
        case .heroBottom:
            return AlbumPage(
                layout: layout,
                slots: [slot(0.07, 0.39, 0.86, 0.52, .photo)],
                textBlocks: [
                    text(headline, 0.08, 0.10, 0.78, 0.12, .headline),
                    text(caption, 0.08, 0.24, 0.66, 0.08, .caption)
                ]
            )
        case .stackThree:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.17, 0.09, 0.66, 0.23, .photo),
                    slot(0.17, 0.385, 0.66, 0.23, .photo),
                    slot(0.17, 0.68, 0.66, 0.23, .photo)
                ],
                textBlocks: [pageNumberText(pageNumber)]
            )
        case .gridSix:
            var slots: [AlbumSlot] = []
            for row in 0..<3 {
                for column in 0..<2 {
                    slots.append(slot(
                        0.09 + Double(column) * 0.43,
                        0.19 + Double(row) * 0.235,
                        0.38,
                        0.19,
                        .photo,
                        radius: 0.006
                    ))
                }
            }
            return AlbumPage(
                layout: layout,
                slots: slots,
                textBlocks: [
                    text(headline, 0.09, 0.07, 0.72, 0.08, .headline),
                    pageNumberText(pageNumber)
                ]
            )
        case .portraitStory:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.08, 0.12, 0.47, 0.75, .photo),
                    slot(0.61, 0.17, 0.30, 0.22, .photo),
                    slot(0.61, 0.48, 0.30, 0.22, .photo)
                ],
                textBlocks: [
                    text(headline, 0.60, 0.77, 0.31, 0.08, .headline),
                    pageNumberText(pageNumber)
                ]
            )
        case .splitPair:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.07, 0.14, 0.40, 0.66, .photo),
                    slot(0.53, 0.20, 0.40, 0.66, .photo)
                ],
                textBlocks: [
                    text(headline, 0.07, 0.84, 0.66, 0.07, .headline),
                    pageNumberText(pageNumber)
                ]
            )
        case .editorialThree:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.07, 0.10, 0.55, 0.47, .photo),
                    slot(0.67, 0.10, 0.26, 0.25, .photo),
                    slot(0.67, 0.41, 0.26, 0.25, .photo)
                ],
                textBlocks: [
                    text(headline, 0.07, 0.67, 0.48, 0.09, .headline),
                    text(caption, 0.07, 0.78, 0.70, 0.08, .caption),
                    pageNumberText(pageNumber)
                ]
            )
        case .workFeature:
            return AlbumPage(
                layout: layout,
                slots: [slot(0.08, 0.27, 0.84, 0.46, .work, fit: .fit, radius: 0.008)],
                textBlocks: [
                    text("灵动作品", 0.08, 0.10, 0.64, 0.09, .headline),
                    text("将票根、色盘、卡片或手帐装订进来", 0.08, 0.76, 0.75, 0.08, .caption),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.10
            )
        case .fullBleed:
            return AlbumPage(
                layout: layout,
                slots: [slot(0, 0, 1, 1, .photo)],
                textBlocks: [
                    text(headline, 0.08, 0.80, 0.74, 0.10, .coverTitle)
                ],
                tintStrength: 0
            )
        case .collage:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.08, 0.10, 0.58, 0.42, .any, radius: 0.008, rotation: -2, z: 0),
                    slot(0.48, 0.39, 0.44, 0.34, .any, radius: 0.008, rotation: 3, z: 2),
                    slot(0.13, 0.63, 0.35, 0.25, .any, radius: 0.008, rotation: -1, z: 1)
                ],
                textBlocks: [
                    text(headline, 0.55, 0.15, 0.36, 0.13, .headline, .trailing),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.12
            )
        case .quotePhoto:
            return AlbumPage(
                layout: layout,
                slots: [slot(0.08, 0.08, 0.84, 0.55, .photo)],
                textBlocks: [
                    text("“\(caption)”", 0.13, 0.69, 0.74, 0.14, .quote, .center),
                    pageNumberText(pageNumber)
                ]
            )
        case .oceanPoster:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.00, 0.00, 0.50, 1.00, .photo),
                    slot(0.50, 0.00, 0.50, 1.00, .photo)
                ],
                textBlocks: [
                    text(headline, 0.07, 0.08, 0.36, 0.10, .headline),
                    text(caption, 0.07, 0.72, 0.36, 0.12, .caption),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.06
            )
        case .cinematicSea:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.07, 0.07, 0.34, 0.20, .photo),
                    slot(0.59, 0.07, 0.34, 0.20, .photo),
                    slot(0.07, 0.34, 0.86, 0.58, .photo)
                ],
                textBlocks: [
                    text("STAY WITH ME", 0.42, 0.08, 0.16, 0.08, .caption, .center),
                    text(headline, 0.10, 0.78, 0.46, 0.08, .headline),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.08
            )
        case .verticalTravelogue:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.04, 0.30, 0.47, 0.62, .photo),
                    slot(0.65, 0.10, 0.29, 0.19, .photo),
                    slot(0.65, 0.38, 0.29, 0.19, .photo),
                    slot(0.65, 0.66, 0.29, 0.19, .photo)
                ],
                textBlocks: [
                    text(caption, 0.54, 0.09, 0.07, 0.76, .body, .center),
                    text(headline, 0.05, 0.08, 0.40, 0.12, .headline),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.05
            )
        case .postcardScrapbook:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.31, 0.20, 0.48, 0.53, .photo, radius: 0.008, rotation: -2, z: 2),
                    slot(0.06, 0.12, 0.25, 0.22, .photo, rotation: -5, z: 1),
                    slot(0.70, 0.08, 0.24, 0.23, .photo, rotation: 4, z: 1),
                    slot(0.07, 0.67, 0.25, 0.20, .photo, rotation: 3, z: 1),
                    slot(0.71, 0.68, 0.23, 0.20, .photo, rotation: -4, z: 1)
                ],
                textBlocks: [
                    text("POSTCARDS", 0.28, 0.05, 0.50, 0.12, .coverTitle, .center),
                    text(caption, 0.24, 0.84, 0.56, 0.08, .caption, .center),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.18
            )
        case .tornPaperJourney:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.00, 0.00, 0.40, 1.00, .photo),
                    slot(0.48, 0.11, 0.22, 0.25, .photo, rotation: -2, z: 1),
                    slot(0.70, 0.17, 0.25, 0.22, .photo, rotation: 3, z: 2),
                    slot(0.48, 0.57, 0.47, 0.31, .photo, rotation: -1, z: 1)
                ],
                textBlocks: [
                    text(headline, 0.48, 0.42, 0.44, 0.09, .headline),
                    text(caption, 0.48, 0.50, 0.42, 0.08, .caption),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.10
            )
        case .colorAtlas:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.08, 0.09, 0.38, 0.22, .photo),
                    slot(0.57, 0.06, 0.34, 0.29, .photo),
                    slot(0.12, 0.40, 0.30, 0.22, .photo),
                    slot(0.48, 0.37, 0.42, 0.29, .photo),
                    slot(0.18, 0.70, 0.35, 0.22, .photo),
                    slot(0.63, 0.72, 0.25, 0.18, .photo)
                ],
                textBlocks: [
                    text("深蓝 / 浅蓝 / 透明", 0.42, 0.91, 0.48, 0.04, .caption, .trailing),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.08
            )
        case .clippedMemoir:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.04, 0.05, 0.46, 0.88, .photo, rotation: -1),
                    slot(0.59, 0.20, 0.32, 0.23, .photo),
                    slot(0.59, 0.49, 0.32, 0.23, .photo),
                    slot(0.59, 0.78, 0.32, 0.16, .photo)
                ],
                textBlocks: [
                    text(headline, 0.57, 0.06, 0.35, 0.10, .coverTitle, .center),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.07
            )
        case .galleryWindow:
            return AlbumPage(
                layout: layout,
                slots: [
                    slot(0.08, 0.13, 0.36, 0.68, .photo),
                    slot(0.56, 0.13, 0.36, 0.68, .photo)
                ],
                textBlocks: [
                    text(headline, 0.09, 0.84, 0.82, 0.07, .headline, .center),
                    pageNumberText(pageNumber)
                ],
                tintStrength: 0.05
            )
        case .freeform:
            return AlbumPage(
                layout: layout,
                slots: [],
                textBlocks: [pageNumberText(pageNumber)],
                tintStrength: 0.02
            )
        case .backCover:
            return AlbumPage(
                role: .backCover,
                layout: layout,
                slots: [],
                textBlocks: [
                    text("LINGDONG PHOTO", 0.15, 0.47, 0.70, 0.05, .coverSubtitle, .center)
                ],
                tintStrength: 0.52
            )
        }
    }

    private static func initialPages(for descriptor: AlbumTemplateDescriptor) -> [AlbumPage] {
        var pages = descriptor.layouts.enumerated().map { index, layout in
            makePage(layout: layout, theme: descriptor.theme, pageNumber: index + 1)
        }
        for pageIndex in pages.indices {
            for blockIndex in pages[pageIndex].textBlocks.indices
            where pages[pageIndex].textBlocks[blockIndex].isEditable {
                pages[pageIndex].textBlocks[blockIndex].text =
                    pages[pageIndex].textBlocks[blockIndex].text.appLocalized
            }
        }
        if !pages.isEmpty, !pages[0].textBlocks.isEmpty {
            pages[0].textBlocks[0].text = descriptor.title.appLocalized
        }
        return pages
    }

    private static func slot(
        _ x: Double,
        _ y: Double,
        _ width: Double,
        _ height: Double,
        _ expectation: AlbumSlotExpectation,
        fit: AlbumImageFit = .fill,
        radius: Double = 0,
        rotation: Double = 0,
        z: Int = 0
    ) -> AlbumSlot {
        AlbumSlot(
            frame: AlbumNormalizedRect(x, y, width, height),
            expectation: expectation,
            fit: fit,
            cornerRadius: radius,
            rotation: rotation,
            zIndex: z
        )
    }

    private static func text(
        _ value: String,
        _ x: Double,
        _ y: Double,
        _ width: Double,
        _ height: Double,
        _ style: AlbumTextStyle,
        _ alignment: AlbumTextAlignment = .leading,
        editable: Bool = true
    ) -> AlbumTextBlock {
        AlbumTextBlock(
            text: value,
            frame: AlbumNormalizedRect(x, y, width, height),
            style: style,
            alignment: alignment,
            isEditable: editable
        )
    }

    private static func pageNumberText(_ number: Int) -> AlbumTextBlock {
        text(String(format: "%02d", number), 0.84, 0.93, 0.08, 0.025, .pageNumber, .trailing, editable: false)
    }

    private static func defaultSectionTitle(_ theme: AlbumTheme, _ page: Int) -> String {
        switch theme {
        case .travel: ["出发", "沿途", "抵达", "风景之间"][page % 4]
        case .family: ["一起生活", "寻常日子", "家的片段", "相聚"][page % 4]
        case .childhood: ["今天又长大一点", "小小发现", "闪亮时刻", "新的第一次"][page % 4]
        case .companion: ["与你相伴", "柔软日常", "一起散步", "回家的方向"][page % 4]
        case .blank: "写下这一页"
        }
    }

    private static func defaultCaption(_ theme: AlbumTheme) -> String {
        switch theme {
        case .travel: "把沿途遇见的风与光，留在这一页。"
        case .family: "平常的日子，因为我们在一起而有了形状。"
        case .childhood: "那些看似微小的变化，都是成长留下的光。"
        case .companion: "陪伴不说话，却把每一天都变得柔软。"
        case .blank: "点击文字，写下这一页的故事。"
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
