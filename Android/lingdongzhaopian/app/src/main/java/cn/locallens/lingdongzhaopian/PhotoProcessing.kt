package cn.locallens.lingdongzhaopian

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.max

object PhotoProcessor {
    suspend fun load(context: Context, uri: Uri): SelectedPhoto = coroutineScope {
        val bitmapDeferred = async(Dispatchers.IO) { decodeBitmap(context, uri) }
        val metadataDeferred = async(Dispatchers.IO) { readMetadata(context, uri) }
        val motionDeferred = async(Dispatchers.IO) { MotionPhotoExtractor.extract(context, uri) }
        val sizeDeferred = async(Dispatchers.IO) { readSourceSize(context, uri) }
        val bitmap = bitmapDeferred.await()
        val semantic = analyzeSemantic(bitmap)
        val size = sizeDeferred.await()
        SelectedPhoto(
            uri = uri,
            bitmap = bitmap,
            metadata = metadataDeferred.await(),
            semantic = semantic,
            motionVideoFile = motionDeferred.await(),
            sourceWidth = size.first.takeIf { it > 0 } ?: bitmap.width,
            sourceHeight = size.second.takeIf { it > 0 } ?: bitmap.height,
        )
    }

    private fun decodeBitmap(context: Context, uri: Uri): Bitmap {
        val source = ImageDecoder.createSource(context.contentResolver, uri)
        return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            decoder.isMutableRequired = false
            // iOS 的 DeviceRGB 采样会先将 Display-P3 原片转到 sRGB；保持两端色盘输入一致。
            decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
            val longEdge = max(info.size.width, info.size.height)
            if (longEdge > 3000) {
                val scale = 3000f / longEdge
                decoder.setTargetSize((info.size.width * scale).toInt(), (info.size.height * scale).toInt())
            }
        }
    }

    private fun readMetadata(context: Context, uri: Uri): PhotoMetadata {
        return runCatching {
            context.contentResolver.openInputStream(uri)?.use { input ->
                val exif = ExifInterface(input)
                val date = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                    ?: exif.getAttribute(ExifInterface.TAG_DATETIME)
                val captureMillis = date?.let {
                    runCatching {
                        LocalDateTime.parse(it, DateTimeFormatter.ofPattern("yyyy:MM:dd HH:mm:ss"))
                            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                    }.getOrNull()
                }
                val latLong = exif.latLong
                PhotoMetadata(
                    make = exif.getAttribute(ExifInterface.TAG_MAKE)?.trim()?.takeIf(String::isNotEmpty),
                    model = exif.getAttribute(ExifInterface.TAG_MODEL)?.trim()?.takeIf(String::isNotEmpty),
                    lensModel = exif.getAttribute(ExifInterface.TAG_LENS_MODEL)?.trim()?.takeIf(String::isNotEmpty),
                    aperture = exif.getAttributeDouble(ExifInterface.TAG_F_NUMBER, Double.NaN).takeUnless(Double::isNaN),
                    exposureTime = exif.getAttributeDouble(ExifInterface.TAG_EXPOSURE_TIME, Double.NaN).takeUnless(Double::isNaN),
                    iso = exif.getAttributeInt(ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY, 0).takeIf { it > 0 },
                    focalLength = exif.getAttributeDouble(ExifInterface.TAG_FOCAL_LENGTH, Double.NaN).takeUnless(Double::isNaN),
                    captureTimeMillis = captureMillis,
                    latitude = latLong?.getOrNull(0),
                    longitude = latLong?.getOrNull(1),
                )
            }
        }.getOrNull() ?: PhotoMetadata()
    }

    private fun readSourceSize(context: Context, uri: Uri): Pair<Int, Int> = runCatching {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
        options.outWidth to options.outHeight
    }.getOrDefault(0 to 0)

    private suspend fun analyzeSemantic(bitmap: Bitmap): PhotoSemantic {
        // iOS Vision 在微距画面上能稳定返回昆虫标签；ML Kit 的对应置信度略低。
        // 放宽阈值后再由 categoryFor 按优先级归类，保持两端文案选择一致。
        val labeler = ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(.15f).build())
        return try {
            val results = labeler.process(InputImage.fromBitmap(bitmap, 0)).await().sortedByDescending { it.confidence }
            val labels = results.map { it.text }
            PhotoSemantic(categoryFor(labels), labels)
        } catch (_: Exception) {
            PhotoSemantic()
        } finally {
            labeler.close()
        }
    }

    private fun categoryFor(labels: List<String>): String {
        val value = labels.joinToString(" ").lowercase()
        return when {
            listOf("butterfly", "insect", "bee", "dragonfly", "arthropod").any(value::contains) -> "昆虫微距"
            listOf("flower", "flora", "garden", "plant").any(value::contains) -> "花卉与花园"
            listOf("cat", "kitten").any(value::contains) -> "猫咪"
            listOf("dog", "puppy").any(value::contains) -> "狗狗"
            listOf("bird", "feather").any(value::contains) -> "鸟类"
            listOf("coffee", "cafe", "dessert").any(value::contains) -> "咖啡与甜点"
            listOf("food", "dish", "cuisine", "meal").any(value::contains) -> "美食"
            listOf("person", "portrait", "selfie", "face").any(value::contains) -> "人物肖像"
            listOf("beach", "coast", "sea", "ocean").any(value::contains) -> "海滩"
            listOf("mountain", "hill", "valley").any(value::contains) -> "山野风光"
            listOf("forest", "woodland", "tree").any(value::contains) -> "森林草木"
            listOf("building", "architecture").any(value::contains) -> "建筑"
            listOf("city", "skyline", "metropolis").any(value::contains) -> "城市天际线"
            listOf("car", "vehicle", "automobile").any(value::contains) -> "车辆与旅途"
            listOf("snow", "winter", "ice").any(value::contains) -> "冬日雪景"
            listOf("sunset", "sunrise", "dusk", "dawn").any(value::contains) -> "日出日落"
            listOf("night", "moon", "star").any(value::contains) -> "夜色星光"
            listOf("interior", "room", "furniture").any(value::contains) -> "室内空间"
            listOf("document", "text", "paper", "screenshot").any(value::contains) -> "文字或截图"
            else -> "日常瞬间"
        }
    }
}

object Copywriter {
    fun make(semantic: PhotoSemantic, metadata: PhotoMetadata, palette: List<RGBColor>, variant: Int = 0): ArtworkCopy {
        val options = when (semantic.category) {
            "昆虫微距" -> listOf(
                ArtworkCopy("微观世界正在闪光 · 小生命也很辽阔", "Small Wings Great Wonder · Nature in Miniature", "Small Wings, Great Wonder", "🦋  🌿\n✨  🌸"),
                ArtworkCopy("在一朵花的时间里，遇见飞翔", "A Tiny Journey Through the Garden", "A Tiny Garden Journey", "🌼  🦋\n☀️  🍃"),
            )
            "花卉与花园" -> listOf(
                ArtworkCopy("花开不是答案，是季节写下的回声", "Where the Garden Keeps the Light", "The Garden Keeps the Light", "🌸  🌿\n☀️  ✨"),
                ArtworkCopy("风经过花园，颜色便有了呼吸", "Colors Begin to Breathe", "Colors Begin to Breathe", "🌺  🍃\n🤍  📷"),
            )
            "人物肖像" -> listOf(ArtworkCopy("光落在脸上，故事留在眼里", "A Portrait Made of Light", "A Portrait Made of Light", "🤍  ✨\n📷  🌿"))
            "猫咪" -> listOf(ArtworkCopy("柔软占领了今天", "A Soft Little Universe", "A Soft Little Universe", "🐈  🤍\n☀️  ✨"))
            "狗狗" -> listOf(ArtworkCopy("快乐有了毛茸茸的形状", "Joy Has Four Paws", "Joy Has Four Paws", "🐕  🌿\n✨  🤍"))
            "美食" -> listOf(ArtworkCopy("把日常煮成值得记住的味道", "A Taste Worth Remembering", "A Taste Worth Remembering", "🍽️  ✨\n🥢  🤍"))
            "咖啡与甜点" -> listOf(
                ArtworkCopy("甜度与光，都在今日刚刚好", "A Little Pause, Perfectly Sweet", "A Perfectly Sweet Pause", "☕  🍰\n✨  🤍"),
                ArtworkCopy("把忙碌暂停在一杯香气里", "Slow Down for Something Good", "Something Good, Slowly", "☕  🤎\n🌿  ✨"),
            )
            "海滩" -> listOf(ArtworkCopy("海风把远方写成蓝色", "Where the Horizon Turns Blue", "The Horizon Turns Blue", "🌊  ☀️\n🐚  🤍"))
            "山野风光" -> listOf(ArtworkCopy("向山里走，把心交给风", "A Quiet Way Into the Wild", "Into the Quiet Wild", "⛰️  🌿\n☁️  ✨"))
            "森林草木" -> listOf(ArtworkCopy("深绿之处，时间慢了下来", "Time Slows Beneath the Trees", "Beneath the Trees", "🌲  🌿\n✨  🤍"))
            "建筑" -> listOf(ArtworkCopy("线条沉默，空间自有回声", "Geometry Holding the Light", "Geometry and Light", "🏙️  📐\n✨  🤍"))
            "城市天际线" -> listOf(ArtworkCopy("城市向上生长，灯光向夜色展开", "The City Keeps Glowing", "The City Keeps Glowing", "🌃  🏙️\n✨  📷"))
            "车辆与旅途" -> listOf(ArtworkCopy("把路放在前方，把风景留在心里", "The Road Opens Ahead", "The Road Opens Ahead", "🚗  🛣️\n☀️  ✨"))
            "冬日雪景" -> listOf(ArtworkCopy("世界轻轻安静，雪替时间留白", "Winter Writes in White", "Winter Writes in White", "❄️  🤍\n✨  ☕"))
            "日出日落" -> listOf(ArtworkCopy("天光缓慢，今日与温柔重逢", "The Sky Turns Gentle", "The Sky Turns Gentle", "🌅  ✨\n☁️  🧡"))
            "夜色星光" -> listOf(ArtworkCopy("夜色很深，光仍然有回音", "A Small Light in the Night", "Light in the Night", "🌙  ⭐\n✨  📷"))
            else -> listOf(
                ArtworkCopy("光影途经此刻，时间有了温度", "A Moment Held in Light", "A Moment Held in Light", "✨  📷\n🌿  🤍"),
                ArtworkCopy("把平凡的一秒，留成自己的风景", "Keep the Ordinary Close", "Keep the Ordinary Close", "☀️  🍃\n🤍  📷"),
            )
        }
        return options[variant.mod(options.size)]
    }
}

object PrivacyDetector {
    suspend fun detect(bitmap: Bitmap): List<PrivacyMask> = coroutineScope {
        val input = InputImage.fromBitmap(bitmap, 0)
        val faceDeferred = async {
            val detector = FaceDetection.getClient(
                FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE).build()
            )
            try {
                detector.process(input).await().map { face ->
                    normalizedMask(PrivacyMaskKind.Face, face.boundingBox.left, face.boundingBox.top, face.boundingBox.right, face.boundingBox.bottom, bitmap, .10f)
                }
            } finally { detector.close() }
        }
        val barcodeDeferred = async {
            val scanner = BarcodeScanning.getClient()
            try {
                scanner.process(input).await().mapNotNull { barcode ->
                    barcode.boundingBox?.let { box ->
                        normalizedMask(
                            if (barcode.format == Barcode.FORMAT_QR_CODE) PrivacyMaskKind.QrCode else PrivacyMaskKind.SensitiveText,
                            box.left, box.top, box.right, box.bottom, bitmap, .08f,
                        )
                    }
                }
            } finally { scanner.close() }
        }
        val textDeferred = async {
            val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            try {
                recognizer.process(input).await().textBlocks.flatMap { block ->
                    block.lines.mapNotNull { line ->
                        val compact = line.text.replace(" ", "")
                        if (!SensitiveTextClassifier.isSensitive(compact)) return@mapNotNull null
                        val box = line.boundingBox ?: return@mapNotNull null
                        val kind = if (SensitiveTextClassifier.isLicensePlate(compact)) PrivacyMaskKind.LicensePlate else PrivacyMaskKind.SensitiveText
                        normalizedMask(kind, box.left, box.top, box.right, box.bottom, bitmap, .06f)
                    }
                }
            } finally { recognizer.close() }
        }
        listOf(faceDeferred, barcodeDeferred, textDeferred).awaitAll().flatten().distinctBy {
            listOf(it.kind, (it.left * 50).toInt(), (it.top * 50).toInt(), (it.right * 50).toInt(), (it.bottom * 50).toInt())
        }
    }

    private fun normalizedMask(kind: PrivacyMaskKind, left: Int, top: Int, right: Int, bottom: Int, bitmap: Bitmap, padding: Float): PrivacyMask {
        val xPad = (right - left) * padding
        val yPad = (bottom - top) * padding
        return PrivacyMask(
            kind,
            ((left - xPad) / bitmap.width).coerceIn(0f, 1f),
            ((top - yPad) / bitmap.height).coerceIn(0f, 1f),
            ((right + xPad) / bitmap.width).coerceIn(0f, 1f),
            ((bottom + yPad) / bitmap.height).coerceIn(0f, 1f),
        )
    }

}

object SensitiveTextClassifier {
    private val plate = Regex("[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼][A-Z][A-Z0-9]{5,6}")
    private val ocrTolerantPlate = Regex("(?:^|[^A-Z0-9])[A-Z]{1,2}[A-Z0-9]{5,6}(?:$|[^A-Z0-9])")
    private val phone = Regex("(?:\\+?86)?1[3-9]\\d{9}")
    private val idCard = Regex("\\d{17}[0-9Xx]")
    private val account = Regex("\\d{12,19}")
    private val email = Regex("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", RegexOption.IGNORE_CASE)

    fun isLicensePlate(value: String): Boolean {
        val normalized = value.replace(" ", "").uppercase()
        return plate.containsMatchIn(normalized) || ocrTolerantPlate.containsMatchIn(normalized)
    }
    fun isSensitive(value: String): Boolean {
        val compact = value.replace(" ", "")
        return isLicensePlate(compact) || phone.containsMatchIn(compact) || idCard.containsMatchIn(compact) ||
            account.matches(compact) || email.containsMatchIn(compact)
    }
}
