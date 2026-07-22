package cn.locallens.lingdongzhaopian

import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

enum class CreationMode(
    val title: String,
    val subtitle: String,
    val introSubtitle: String,
    val accent: Color,
) {
    MotionCard(
        "灵动卡片",
        "封存地理与时间的印记，重塑身临其境的沉浸式体验",
        "拒绝平淡的叙事\n让每一段生动的记忆都拥有专属色彩",
        Color(0xFFC2EBAA),
    ),
    ColorPalette(
        "琉璃色盘",
        "在如琉璃般的通透质感中，萃取影像的本源色彩",
        "穿越影像的表象，重现色彩最本真的纯净美学",
        Color(0xFFB8E0BD),
    ),
    Journal(
        "一键手帐",
        "选取 1～5 张照片，自动排版电子手帐",
        "选取 1～5 张照片，自动排版电子手帐",
        Color(0xFFFCC9A0),
    ),
    BubbleStamp(
        "气泡印章",
        "随心而动的有机气泡，捕捉影像跳动的呼吸节奏",
        "记忆像气泡般轻盈跳动",
        Color(0xFFD1ED8C),
    ),
    SpectrumWallpaper(
        "色谱壁纸",
        "拒绝千篇一律，每一次亮屏都是你的专属艺术创作",
        "拒绝千篇一律\n每一次亮屏都是你的专属艺术创作",
        Color(0xFFDBFFD4),
    ),
    PrivacyMosaic(
        "隐私马赛克",
        "手动涂抹或智能识别人脸、车牌、二维码与敏感文字",
        "让隐私留在画面之外\n手动涂抹或智能识别，安心分享每一张照片",
        Color(0xFF9ED6FF),
    );

    val defaultRatio: ArtworkRatio
        get() = if (this == Journal || this == SpectrumWallpaper) ArtworkRatio.NineSixteen else ArtworkRatio.ThreeFour
}

enum class ArtworkRatio(val label: String, val value: Float) {
    Original("原图", .75f), OneOne("1:1", 1f), ThreeFour("3:4", .75f), FourFive("4:5", .8f),
    NineSixteen("9:16", 9f / 16f), SixteenNine("16:9", 16f / 9f);

    fun valueFor(bitmap: Bitmap?): Float = if (this == Original && bitmap != null && bitmap.height > 0) {
        (bitmap.width.toFloat() / bitmap.height.toFloat()).coerceIn(.35f, 2.4f)
    } else value
}

enum class ArtworkTemplateStyle(val label: String) { Classic("经典"), Airy("留白"), Immersive("沉浸") }
enum class JournalLayoutMode(val label: String) { Automatic("自动拼贴"), Magazine("杂志主图"), Filmstrip("纵向胶卷") }
enum class PaletteLayoutMode(val label: String) { Floating("经典浮动"), Compact("紧凑横排") }
enum class ArtworkFontStyle(val label: String) { Rounded("圆体"), Song("宋体"), Serif("衬线"), Monospaced("等宽") }
enum class ExportFormat(val label: String, val extension: String, val mime: String, val detail: String) {
    Jpeg("JPEG", "jpg", "image/jpeg", "兼容性最佳，适合社交平台"),
    Png("PNG", "png", "image/png", "无损画质，文件较大"),
    Heic("HEIC", "heic", "image/heic", "高画质且更节省空间"),
}
enum class ExportResolution(val label: String, val width: Int, val detail: String) {
    Standard("1080P", 1080, "快速导出，适合日常分享"),
    High("2K", 2160, "细节更清晰，适合收藏"),
    Original("原图级", 0, "跟随原片宽度，最高 6000 像素"),
}
enum class MetadataPolicy(val label: String, val detail: String) {
    Preserve("完整保留", "保留拍摄时间、设备、镜头和 GPS"),
    RemoveLocation("移除位置", "保留拍摄信息，但删除 GPS 坐标"),
    RemoveAll("隐私净化", "删除 GPS、设备、镜头和原始拍摄时间"),
}
enum class ExportDestination(val label: String) { PhotoLibrary("相册"), Files("文件"), Share("分享") }
enum class PrivacyBrushMode(val label: String) { Paint("涂抹"), Erase("擦除") }
enum class PrivacyMaskKind(val label: String) { Face("人脸"), LicensePlate("车牌"), QrCode("二维码"), SensitiveText("敏感文字") }

data class RGBColor(val red: Float, val green: Float, val blue: Float) {
    val color: Color get() = Color(red.coerceIn(0f, 1f), green.coerceIn(0f, 1f), blue.coerceIn(0f, 1f))
    val hex: String get() = "#%02X%02X%02X".format((red * 255).toInt(), (green * 255).toInt(), (blue * 255).toInt())
    val luminance: Float get() = red * .299f + green * .587f + blue * .114f
    val relativeLuminance: Float
        get() {
            fun linear(component: Float) = if (component <= .04045f) component / 12.92f else ((component + .055f) / 1.055f).pow(2.4f)
            return .2126f * linear(red) + .7152f * linear(green) + .0722f * linear(blue)
        }
    fun contrastRatio(other: RGBColor): Float {
        val lighter = max(relativeLuminance, other.relativeLuminance)
        val darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + .05f) / (darker + .05f)
    }
    fun adjusted(brightness: Float = 0f, saturation: Float = 0f): RGBColor {
        val average = (red + green + blue) / 3f
        val factor = 1 + saturation
        return RGBColor(
            (average + (red - average) * factor + brightness).coerceIn(0f, 1f),
            (average + (green - average) * factor + brightness).coerceIn(0f, 1f),
            (average + (blue - average) * factor + brightness).coerceIn(0f, 1f),
        )
    }

    companion object {
        val fallback = listOf(
            RGBColor(.78f, .91f, .48f), RGBColor(.34f, .53f, .31f), RGBColor(.91f, .95f, .64f),
            RGBColor(.18f, .32f, .18f), RGBColor(.66f, .76f, .37f), RGBColor(.93f, .87f, .54f),
        )
        val intro = listOf(
            RGBColor(.18f, .39f, .24f), RGBColor(.14f, .31f, .21f), RGBColor(.24f, .45f, .28f),
            RGBColor(.10f, .24f, .18f), RGBColor(.26f, .48f, .30f), RGBColor(.13f, .30f, .21f),
        )
    }
}

data class PaletteResult(val colors: List<RGBColor>, val percentages: List<Double>)
data class ArtworkCopy(
    val title: String = "正在理解这一刻",
    val subtitle: String = "A Moment Taking Shape",
    val journalCaption: String = "A Moment Taking Shape",
    val emojis: String = "✨  📷\n🌿  🤍",
)

data class PhotoMetadata(
    val make: String? = null,
    val model: String? = null,
    val lensModel: String? = null,
    val aperture: Double? = null,
    val exposureTime: Double? = null,
    val iso: Int? = null,
    val focalLength: Double? = null,
    val captureTimeMillis: Long? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
) {
    val captureTimeText: String
        get() = captureTimeMillis?.let {
            DateTimeFormatter.ofPattern("yyyy/MM/dd, HH:mm")
                .withZone(ZoneId.systemDefault()).format(Instant.ofEpochMilli(it))
        } ?: "记录这一刻"
    val deviceLine: String?
        get() = listOfNotNull(make, model).distinct().joinToString(" ").ifBlank { null }
    val cameraLine: String?
        get() {
            val values = buildList {
                lensModel?.let(::add)
                aperture?.let { add("ƒ/${"%.1f".format(it)}") }
                exposureTime?.let { add(if (it < 1) "1/${(1 / it).toInt()}s" else "${"%.1f".format(it)}s") }
                iso?.let { add("ISO $it") }
                focalLength?.let { add("${"%.1f".format(it)}mm") }
            }
            return values.joinToString(" · ").ifBlank { null }
        }
}

data class PhotoSemantic(val category: String = "日常瞬间", val labels: List<String> = emptyList())
data class SelectedPhoto(
    val uri: Uri,
    val bitmap: Bitmap,
    val metadata: PhotoMetadata = PhotoMetadata(),
    val semantic: PhotoSemantic = PhotoSemantic(),
    val motionVideoFile: File? = null,
    val sourceWidth: Int = bitmap.width,
    val sourceHeight: Int = bitmap.height,
) {
    val isMotionPhoto: Boolean get() = motionVideoFile?.isFile == true
}
data class JournalTransform(val scale: Float = 1f, val offset: Offset = Offset.Zero)
data class PrivacyMask(
    val kind: PrivacyMaskKind,
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
    val enabled: Boolean = true,
)
data class PrivacyStroke(val points: List<Offset>, val normalizedWidth: Float = .085f)

data class AppPreferences(
    val showAppTitle: Boolean = true,
    val showHexValues: Boolean = true,
    val showPalettePercentages: Boolean = true,
    val showDeviceInfo: Boolean = true,
    val showBubbles: Boolean = true,
    val gentleBackground: Boolean = true,
    val useLiteraryColorNames: Boolean = false,
    val preservePaletteBackground: Boolean = true,
    val applyLiquidGlassOnExport: Boolean = true,
    val showMoodCopy: Boolean = false,
    val supportsMotionPhotos: Boolean = true,
    val paletteLayout: PaletteLayoutMode = PaletteLayoutMode.Floating,
    val templateStyle: ArtworkTemplateStyle = ArtworkTemplateStyle.Classic,
    val journalLayout: JournalLayoutMode = JournalLayoutMode.Automatic,
    val exportFormat: ExportFormat = ExportFormat.Jpeg,
    val exportResolution: ExportResolution = ExportResolution.Standard,
    val metadataPolicy: MetadataPolicy = MetadataPolicy.RemoveLocation,
    val exportDestination: ExportDestination = ExportDestination.PhotoLibrary,
)

data class AppUiState(
    val mode: CreationMode = CreationMode.MotionCard,
    val ratio: ArtworkRatio = ArtworkRatio.ThreeFour,
    val photos: List<SelectedPhoto> = emptyList(),
    val palette: List<RGBColor> = RGBColor.fallback,
    val palettePercentages: List<Double> = List(6) { 0.0 },
    val artworkCopy: ArtworkCopy = ArtworkCopy(),
    val preferences: AppPreferences = AppPreferences(),
    val isLoading: Boolean = false,
    val loadingStatus: String = "",
    val imageScale: Float = 1f,
    val imageOffset: Offset = Offset.Zero,
    val paletteOffset: Float = 0f,
    val bubbleScale: Float = 1f,
    val textScale: Float = 1f,
    val fontStyle: ArtworkFontStyle = ArtworkFontStyle.Rounded,
    val journalTransforms: List<JournalTransform> = emptyList(),
    val selectedJournalIndex: Int? = null,
    val privacyMasks: List<PrivacyMask> = emptyList(),
    val privacyStrokes: List<PrivacyStroke> = emptyList(),
    val privacyBrushMode: PrivacyBrushMode = PrivacyBrushMode.Paint,
    val privacyStrength: Float = .62f,
    val privacyPainting: Boolean = false,
    val privacyDetecting: Boolean = false,
    val motionPreviewFrames: Map<Int, Bitmap> = emptyMap(),
    val isMotionPlaying: Boolean = false,
    val isExporting: Boolean = false,
    val noticeAcknowledged: Boolean = false,
)

fun AppUiState.bitmapAt(index: Int): Bitmap? =
    motionPreviewFrames[index] ?: photos.getOrNull(index)?.bitmap

fun <T> List<T>.moving(from: Int, to: Int): List<T> {
    if (from !in indices || to !in indices || from == to) return this
    return toMutableList().apply { add(to, removeAt(from)) }
}

data class ExportDimensions(val width: Int, val height: Int)

fun exportDimensions(resolution: ExportResolution, sourceWidth: Int, aspectRatio: Float): ExportDimensions {
    val width = when (resolution) {
        ExportResolution.Standard -> ExportResolution.Standard.width
        ExportResolution.High -> ExportResolution.High.width
        ExportResolution.Original -> sourceWidth.coerceIn(1080, 6000)
    }
    return ExportDimensions(width, (width / aspectRatio.coerceAtLeast(.01f)).roundToInt().coerceAtLeast(1))
}
