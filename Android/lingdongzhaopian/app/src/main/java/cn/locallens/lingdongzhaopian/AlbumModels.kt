package cn.locallens.lingdongzhaopian

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import java.io.File
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

enum class AlbumBookFormat(val label: String, val shortLabel: String, val ratio: Float, val pageWidth: Int, val pageHeight: Int) {
    Portrait("A5 竖版", "竖版", 148f / 210f, 1240, 1754),
    Square("方形相簿", "方形", 1f, 1600, 1600),
    Landscape("A4 横版", "横版", 297f / 210f, 1754, 1240),
}

enum class AlbumThemeSpec(val title: String, val symbol: String) {
    Travel("旅行", "地图"),
    Family("家庭", "家"),
    Childhood("儿童", "闪光"),
    Companion("动物", "爪印"),
    Blank("自定义", "画布"),
}

enum class AlbumPageLayout(val title: String, val slotCount: Int) {
    CoverWindow("封面窗景", 1),
    HeroBottom("主图留白", 1),
    SplitPair("双图对照", 2),
    EditorialThree("杂志三图", 3),
    GridSix("六格印象", 6),
    PortraitStory("人物故事", 3),
    WorkFeature("作品展示", 1),
    FullBleed("满版影像", 1),
    Collage("自由拼贴", 3),
    QuotePhoto("图文寄语", 1),
    OceanPoster("海报双页", 2),
    CinematicSea("电影海岸", 3),
    VerticalTravelogue("竖排游记", 2),
    PostcardScrapbook("明信片剪贴", 3),
    TornPaperJourney("撕纸旅途", 3),
    ColorAtlas("色彩地图", 6),
    ClippedMemoir("票据手记", 3),
    GalleryWindow("窗景画廊", 4),
    Freeform("空白画布", 1),
    BackCover("封底", 0),
}

data class AlbumTemplateSpec(
    val id: String,
    val theme: AlbumThemeSpec,
    val title: String,
    val subtitle: String,
    val detail: String,
    val defaultFormat: AlbumBookFormat,
    val colors: List<Color>,
    val layouts: List<AlbumPageLayout>,
)

object AlbumTemplateCatalog {
    private fun template(
        id: String,
        theme: AlbumThemeSpec,
        title: String,
        subtitle: String,
        detail: String,
        format: AlbumBookFormat,
        colors: List<Long>,
        layouts: List<AlbumPageLayout>,
    ) = AlbumTemplateSpec(id, theme, title, subtitle, detail, format, colors.map(::Color), layouts)

    val templates = listOf(
        template("travel-editorial", AlbumThemeSpec.Travel, "远方来信", "极简旅行画册", "留白、时间线与宽幅票根共同记录一段旅程", AlbumBookFormat.Portrait, listOf(0xFF346457, 0xFFAAD0A3, 0xFFE3CFAA), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.OceanPoster, AlbumPageLayout.CinematicSea, AlbumPageLayout.VerticalTravelogue, AlbumPageLayout.TornPaperJourney, AlbumPageLayout.WorkFeature, AlbumPageLayout.QuotePhoto, AlbumPageLayout.BackCover)),
        template("travel-postcard", AlbumThemeSpec.Travel, "海岸邮局", "清透明信片画册", "蓝调纸张、邮戳和横向照片，让海边与城市像一组寄出的信", AlbumBookFormat.Landscape, listOf(0xFF387DA3, 0xFFB3D6E0, 0xFFEFD4A1), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.CinematicSea, AlbumPageLayout.VerticalTravelogue, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.ColorAtlas, AlbumPageLayout.GalleryWindow, AlbumPageLayout.WorkFeature, AlbumPageLayout.BackCover)),
        template("travel-film", AlbumThemeSpec.Travel, "漫游胶片", "电影感旅途记录", "胶片编号、黑色细框与连续画面，适合夜景、公路和城市漫游", AlbumBookFormat.Portrait, listOf(0xFF1F2729, 0xFF7A6145, 0xFFD18C4F), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.CinematicSea, AlbumPageLayout.GalleryWindow, AlbumPageLayout.ClippedMemoir, AlbumPageLayout.FullBleed, AlbumPageLayout.VerticalTravelogue, AlbumPageLayout.WorkFeature, AlbumPageLayout.BackCover)),
        template("family-warmth", AlbumThemeSpec.Family, "日常相聚", "温暖家庭影集", "用柔和色块、双图与生活片段收藏共同的日常", AlbumBookFormat.Square, listOf(0xFF945947, 0xFFE3B08A, 0xFFF2E0C5), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.ClippedMemoir, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.ColorAtlas, AlbumPageLayout.QuotePhoto, AlbumPageLayout.Collage, AlbumPageLayout.HeroBottom, AlbumPageLayout.BackCover)),
        template("family-arches", AlbumThemeSpec.Family, "家的形状", "柔光拱廊影集", "奶油纸色、柔和拱形与亲密双人照，突出拥抱和生活细节", AlbumBookFormat.Square, listOf(0xFFAA856E, 0xFFDBBDA6, 0xFFF2E8D6), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.QuotePhoto, AlbumPageLayout.GalleryWindow, AlbumPageLayout.PortraitStory, AlbumPageLayout.ClippedMemoir, AlbumPageLayout.ColorAtlas, AlbumPageLayout.HeroBottom, AlbumPageLayout.BackCover)),
        template("family-sunday", AlbumThemeSpec.Family, "周日餐桌", "生活剪贴手帐", "便签、胶带感叠放和暖色照片，收藏饭桌旁最松弛的日常", AlbumBookFormat.Portrait, listOf(0xFF616D4F, 0xFFC49163, 0xFFEFD19E), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.ClippedMemoir, AlbumPageLayout.HeroBottom, AlbumPageLayout.ColorAtlas, AlbumPageLayout.QuotePhoto, AlbumPageLayout.WorkFeature, AlbumPageLayout.BackCover)),
        template("childhood-spark", AlbumThemeSpec.Childhood, "小小宇宙", "儿童成长记录", "轻快网格与成长标记，为每一次变化留下位置", AlbumBookFormat.Square, listOf(0xFF4D8CAE, 0xFFF5BA73, 0xFFEB949E), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.HeroBottom, AlbumPageLayout.ColorAtlas, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.PortraitStory, AlbumPageLayout.QuotePhoto, AlbumPageLayout.WorkFeature, AlbumPageLayout.BackCover)),
        template("childhood-rainbow", AlbumThemeSpec.Childhood, "彩虹练习册", "明快儿童影集", "圆角画框、彩虹弧线与大胆色块，适合游戏、生日和亲子时刻", AlbumBookFormat.Square, listOf(0xFF4FA3D1, 0xFFFAB83D, 0xFFF26175), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.ColorAtlas, AlbumPageLayout.FullBleed, AlbumPageLayout.ClippedMemoir, AlbumPageLayout.GalleryWindow, AlbumPageLayout.QuotePhoto, AlbumPageLayout.BackCover)),
        template("childhood-growth", AlbumThemeSpec.Childhood, "成长刻度", "年度成长档案", "日期、刻度与规整网格适合按月份记录身高、第一次和作品", AlbumBookFormat.Portrait, listOf(0xFF3B738C, 0xFFA6C6A3, 0xFFF0AD85), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.HeroBottom, AlbumPageLayout.ColorAtlas, AlbumPageLayout.VerticalTravelogue, AlbumPageLayout.PortraitStory, AlbumPageLayout.WorkFeature, AlbumPageLayout.QuotePhoto, AlbumPageLayout.BackCover)),
        template("pet-companion", AlbumThemeSpec.Companion, "与你相伴", "动物陪伴相簿", "大幅肖像、细节拼贴与轻松注脚记录陪伴", AlbumBookFormat.Portrait, listOf(0xFF4F4F45, 0xFFA89E7D, 0xFFE6DBB8), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.PortraitStory, AlbumPageLayout.GalleryWindow, AlbumPageLayout.ColorAtlas, AlbumPageLayout.QuotePhoto, AlbumPageLayout.ClippedMemoir, AlbumPageLayout.FullBleed, AlbumPageLayout.BackCover)),
        template("pet-playful", AlbumThemeSpec.Companion, "毛茸日记", "轻松爪印画册", "圆润标题、爪印和不规则拼贴，记录打滚、睡觉和搞怪瞬间", AlbumBookFormat.Square, listOf(0xFF407884, 0xFFE89B5C, 0xFFF0D69F), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.ColorAtlas, AlbumPageLayout.PortraitStory, AlbumPageLayout.QuotePhoto, AlbumPageLayout.GalleryWindow, AlbumPageLayout.WorkFeature, AlbumPageLayout.BackCover)),
        template("pet-trail", AlbumThemeSpec.Companion, "一起散步", "户外陪伴日志", "路线虚线、自然绿色与宽幅风景，适合公园、山野和海边散步", AlbumBookFormat.Landscape, listOf(0xFF335E4A, 0xFF7DA374, 0xFFD1BF8C), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.FullBleed, AlbumPageLayout.OceanPoster, AlbumPageLayout.VerticalTravelogue, AlbumPageLayout.TornPaperJourney, AlbumPageLayout.ColorAtlas, AlbumPageLayout.QuotePhoto, AlbumPageLayout.BackCover)),
        template("blank-studio", AlbumThemeSpec.Blank, "留白画布", "自定义影像书", "从空白页面开始，自由加入照片与灵动作品", AlbumBookFormat.Portrait, listOf(0xFF334F40, 0xFF8CAD94, 0xFFE3D1B3), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.Freeform, AlbumPageLayout.Freeform, AlbumPageLayout.Freeform, AlbumPageLayout.Freeform, AlbumPageLayout.Freeform, AlbumPageLayout.Freeform, AlbumPageLayout.BackCover)),
        template("blank-grid", AlbumThemeSpec.Blank, "编辑工作室", "理性网格画册", "细网格、编号和多种杂志版式，适合作品集与摄影项目", AlbumBookFormat.Portrait, listOf(0xFF2E383D, 0xFF91A6AB, 0xFFE0E0D6), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.EditorialThree, AlbumPageLayout.CinematicSea, AlbumPageLayout.GalleryWindow, AlbumPageLayout.ColorAtlas, AlbumPageLayout.WorkFeature, AlbumPageLayout.Freeform, AlbumPageLayout.BackCover)),
        template("blank-collage", AlbumThemeSpec.Blank, "自由剪贴簿", "随性空画布", "纸胶带、旋转卡片与自由页混排，适合完全按照自己的方式装订", AlbumBookFormat.Square, listOf(0xFF665770, 0xFFBF919E, 0xFFE8C79C), listOf(AlbumPageLayout.CoverWindow, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.Freeform, AlbumPageLayout.ClippedMemoir, AlbumPageLayout.TornPaperJourney, AlbumPageLayout.WorkFeature, AlbumPageLayout.Freeform, AlbumPageLayout.BackCover)),
    )

    val addableLayouts = AlbumPageLayout.entries.filter { it != AlbumPageLayout.CoverWindow && it != AlbumPageLayout.BackCover }

    fun templates(theme: AlbumThemeSpec) = templates.filter { it.theme == theme }
    fun featured(theme: AlbumThemeSpec) = templates(theme).first()
    fun find(id: String) = templates.firstOrNull { it.id == id } ?: templates.first()
}

data class AlbumPageData(
    val id: String = UUID.randomUUID().toString(),
    val layout: AlbumPageLayout,
    val assets: List<String?> = List(layout.slotCount) { null },
    val caption: String = "把沿途遇见的风与光，留在这一页。",
)

data class AlbumAssetData(
    val path: String,
    val kind: String = "photo",
    val pixelWidth: Int,
    val pixelHeight: Int,
    val colors: List<Long>,
)

data class AlbumProjectData(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val subtitle: String,
    val templateId: String,
    val format: AlbumBookFormat,
    val createdAt: Long = System.currentTimeMillis(),
    val modifiedAt: Long = System.currentTimeMillis(),
    val pages: List<AlbumPageData>,
    val assets: List<AlbumAssetData> = emptyList(),
    val palette: List<Long> = emptyList(),
) {
    val filledCount get() = pages.sumOf { page -> page.assets.count { it != null } }
    val emptyCount get() = pages.sumOf { page -> page.assets.count { it == null } }
}

class AlbumProjectStore(private val context: Context) {
    val projects = mutableStateListOf<AlbumProjectData>()
    private val prefs = context.getSharedPreferences("lingdong_albums", Context.MODE_PRIVATE)
    private val root = File(context.filesDir, "LingdongAlbums").apply { mkdirs() }

    init {
        projects.addAll(loadProjects())
    }

    fun create(template: AlbumTemplateSpec, format: AlbumBookFormat): AlbumProjectData {
        val project = AlbumProjectData(
            title = template.title,
            subtitle = template.subtitle,
            templateId = template.id,
            format = format,
            pages = template.layouts.map { AlbumPageData(layout = it) },
            palette = template.colors.map { it.toArgb().toLong() and 0xffffffffL },
        )
        projects.add(0, project)
        save()
        return project
    }

    fun project(id: String) = projects.firstOrNull { it.id == id }

    fun update(project: AlbumProjectData) {
        val index = projects.indexOfFirst { it.id == project.id }
        if (index < 0) return
        projects[index] = project.copy(modifiedAt = System.currentTimeMillis())
        save()
    }

    fun delete(id: String) {
        projects.removeAll { it.id == id }
        File(root, id).deleteRecursively()
        save()
    }

    fun importBitmaps(projectId: String, bitmaps: List<Bitmap>, kind: String): List<String> {
        val project = project(projectId) ?: return emptyList()
        val folder = File(root, projectId).apply { mkdirs() }
        val imported = bitmaps.mapNotNull { bitmap ->
            runCatching {
                val file = File(folder, "${UUID.randomUUID()}.png")
                file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                AlbumAssetData(
                    path = file.absolutePath,
                    kind = kind,
                    pixelWidth = bitmap.width,
                    pixelHeight = bitmap.height,
                    colors = PaletteExtractor.extract(bitmap, 4).colors.map { it.color.toArgb().toLong() and 0xffffffffL },
                )
            }.getOrNull()
        }
        if (imported.isNotEmpty()) update(project.copy(assets = project.assets + imported))
        return imported.map(AlbumAssetData::path)
    }

    fun placeAssets(projectId: String, paths: List<String>, pageIndex: Int? = null, slotIndex: Int? = null) {
        val project = project(projectId) ?: return
        val pages = project.pages.map { it.copy(assets = it.assets.toMutableList()) }.toMutableList()
        var remaining = paths.toMutableList()
        if (pageIndex != null && slotIndex != null && pages.indices.contains(pageIndex) && pages[pageIndex].assets.indices.contains(slotIndex) && remaining.isNotEmpty()) {
            val assets = pages[pageIndex].assets.toMutableList()
            assets[slotIndex] = remaining.removeAt(0)
            pages[pageIndex] = pages[pageIndex].copy(assets = assets)
        }
        for (page in pages.indices) {
            if (remaining.isEmpty()) break
            val assets = pages[page].assets.toMutableList()
            for (slot in assets.indices) {
                if (remaining.isEmpty()) break
                if (assets[slot] == null) assets[slot] = remaining.removeAt(0)
            }
            pages[page] = pages[page].copy(assets = assets)
        }
        update(recalculatePalette(project.copy(pages = pages)))
    }

    fun removeAsset(projectId: String, pageIndex: Int, slotIndex: Int) {
        val project = project(projectId) ?: return
        if (!project.pages.indices.contains(pageIndex)) return
        val pages = project.pages.toMutableList()
        val assets = pages[pageIndex].assets.toMutableList()
        if (!assets.indices.contains(slotIndex)) return
        assets[slotIndex] = null
        pages[pageIndex] = pages[pageIndex].copy(assets = assets)
        update(recalculatePalette(project.copy(pages = pages)))
    }

    fun addPage(projectId: String, layout: AlbumPageLayout, after: Int) {
        val project = project(projectId) ?: return
        val pages = project.pages.toMutableList()
        pages.add(pages.lastIndex.coerceAtLeast(1), AlbumPageData(layout = layout))
        update(project.copy(pages = pages))
    }

    fun duplicatePage(projectId: String, index: Int) {
        val project = project(projectId) ?: return
        if (index <= 0 || index >= project.pages.lastIndex) return
        val pages = project.pages.toMutableList()
        pages.add(index + 1, pages[index].copy(id = UUID.randomUUID().toString()))
        update(project.copy(pages = pages))
    }

    fun movePage(projectId: String, index: Int, delta: Int) {
        val project = project(projectId) ?: return
        val destination = index + delta
        if (index <= 0 || index >= project.pages.lastIndex || destination <= 0 || destination >= project.pages.lastIndex) return
        val pages = project.pages.toMutableList()
        val page = pages.removeAt(index)
        pages.add(destination, page)
        update(project.copy(pages = pages))
    }

    fun deletePage(projectId: String, index: Int) {
        val project = project(projectId) ?: return
        if (project.pages.size <= 3 || index <= 0 || index >= project.pages.lastIndex) return
        val pages = project.pages.toMutableList().apply { removeAt(index) }
        update(recalculatePalette(project.copy(pages = pages)))
    }

    fun bitmap(path: String?): Bitmap? = path?.let { BitmapFactory.decodeFile(it) }

    private fun recalculatePalette(project: AlbumProjectData): AlbumProjectData {
        val used = project.pages.flatMap(AlbumPageData::assets).filterNotNull().toSet()
        val candidates = project.assets.filter { it.path in used }.flatMap { it.colors.take(2) }
        if (candidates.isEmpty()) return project
        val selected = mutableListOf(candidates.first())
        while (selected.size < minOf(3, candidates.size)) {
            val next = candidates.filterNot(selected::contains).maxByOrNull { candidate ->
                selected.minOf { chosen -> colorDistance(candidate, chosen) }
            } ?: break
            selected += next
        }
        return project.copy(palette = selected)
    }

    private fun colorDistance(left: Long, right: Long): Double {
        val red = ((left shr 16 and 0xff) - (right shr 16 and 0xff)).toDouble()
        val green = ((left shr 8 and 0xff) - (right shr 8 and 0xff)).toDouble()
        val blue = ((left and 0xff) - (right and 0xff)).toDouble()
        return red * red + green * green + blue * blue
    }

    private fun save() {
        val array = JSONArray()
        projects.forEach { project -> array.put(project.toJson()) }
        prefs.edit().putString("projects_v2", array.toString()).apply()
    }

    private fun loadProjects(): List<AlbumProjectData> = runCatching {
        val array = JSONArray(prefs.getString("projects_v2", "[]"))
        List(array.length()) { index -> array.getJSONObject(index).toProject() }
    }.getOrDefault(emptyList())
}

private fun AlbumProjectData.toJson() = JSONObject().apply {
    put("id", id)
    put("title", title)
    put("subtitle", subtitle)
    put("template", templateId)
    put("format", format.name)
    put("created", createdAt)
    put("modified", modifiedAt)
    put("palette", JSONArray().apply { palette.forEach(::put) })
    put("assetData", JSONArray().apply {
        assets.forEach { asset ->
            put(JSONObject().apply {
                put("path", asset.path)
                put("kind", asset.kind)
                put("width", asset.pixelWidth)
                put("height", asset.pixelHeight)
                put("colors", JSONArray().apply { asset.colors.forEach(::put) })
            })
        }
    })
    put("pages", JSONArray().apply {
        pages.forEach { page ->
            put(JSONObject().apply {
                put("id", page.id)
                put("layout", page.layout.name)
                put("caption", page.caption)
                put("assets", JSONArray().apply { page.assets.forEach { put(it ?: JSONObject.NULL) } })
            })
        }
    })
}

private fun JSONObject.toProject(): AlbumProjectData {
    val pagesJson = getJSONArray("pages")
    val pages = List(pagesJson.length()) { index ->
        val page = pagesJson.getJSONObject(index)
        val layout = runCatching { AlbumPageLayout.valueOf(page.getString("layout")) }.getOrDefault(AlbumPageLayout.Freeform)
        val assetsJson = page.optJSONArray("assets") ?: JSONArray()
        val assets = List(layout.slotCount) { slot ->
            if (slot < assetsJson.length() && !assetsJson.isNull(slot)) assetsJson.optString(slot).takeIf(String::isNotBlank) else null
        }
        AlbumPageData(page.optString("id", UUID.randomUUID().toString()), layout, assets, page.optString("caption", "把沿途遇见的风与光，留在这一页。"))
    }
    val templateId = getString("template")
    val assetJson = optJSONArray("assetData") ?: JSONArray()
    val storedAssets = List(assetJson.length()) { index ->
        val item = assetJson.getJSONObject(index)
        val colorJson = item.optJSONArray("colors") ?: JSONArray()
        AlbumAssetData(
            path = item.getString("path"),
            kind = item.optString("kind", "photo"),
            pixelWidth = item.optInt("width", 1),
            pixelHeight = item.optInt("height", 1),
            colors = List(colorJson.length()) { colorJson.getLong(it) },
        )
    }
    val usedPaths = pages.flatMap(AlbumPageData::assets).filterNotNull().distinct()
    val knownPaths = storedAssets.map(AlbumAssetData::path).toSet()
    val migratedAssets = usedPaths.filterNot(knownPaths::contains).mapNotNull { path ->
        BitmapFactory.decodeFile(path)?.let { bitmap ->
            AlbumAssetData(
                path = path,
                pixelWidth = bitmap.width,
                pixelHeight = bitmap.height,
                colors = PaletteExtractor.extract(bitmap, 4).colors.map { it.color.toArgb().toLong() and 0xffffffffL },
            )
        }
    }
    val paletteJson = optJSONArray("palette") ?: JSONArray()
    val fallbackPalette = AlbumTemplateCatalog.find(templateId).colors.map { it.toArgb().toLong() and 0xffffffffL }
    return AlbumProjectData(
        id = getString("id"),
        title = getString("title"),
        subtitle = optString("subtitle"),
        templateId = templateId,
        format = runCatching { AlbumBookFormat.valueOf(getString("format")) }.getOrDefault(AlbumBookFormat.Portrait),
        createdAt = optLong("created", System.currentTimeMillis()),
        modifiedAt = optLong("modified", System.currentTimeMillis()),
        pages = pages,
        assets = storedAssets + migratedAssets,
        palette = if (paletteJson.length() > 0) List(paletteJson.length()) { paletteJson.getLong(it) } else fallbackPalette,
    )
}
