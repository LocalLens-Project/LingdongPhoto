package cn.locallens.lingdongzhaopian

import android.graphics.Bitmap
import kotlin.math.cbrt
import kotlin.math.ln
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.sin
import kotlin.math.pow

private data class OKLab(val l: Double, val a: Double, val b: Double) {
    fun distanceSquared(other: OKLab): Double {
        val dl = l - other.l
        val da = a - other.a
        val db = b - other.b
        return dl * dl + da * da + db * db
    }

    companion object {
        fun from(color: RGBColor): OKLab {
            fun linear(value: Double) = if (value <= .04045) value / 12.92 else ((value + .055) / 1.055).pow(2.4)
            val r = linear(color.red.toDouble())
            val g = linear(color.green.toDouble())
            val b = linear(color.blue.toDouble())
            val ll = cbrt(.4122214708 * r + .5363325363 * g + .0514459929 * b)
            val mm = cbrt(.2119034982 * r + .6806995451 * g + .1073969566 * b)
            val ss = cbrt(.0883024619 * r + .2817188376 * g + .6299787005 * b)
            return OKLab(
                .2104542553 * ll + .7936177850 * mm - .0040720468 * ss,
                1.9779984951 * ll - 2.4285922050 * mm + .4505937099 * ss,
                .0259040371 * ll + .7827717662 * mm - .8086757660 * ss,
            )
        }
    }
}

object PaletteExtractor {
    private data class Point(val color: RGBColor, val lab: OKLab, val weight: Double)

    fun extract(bitmap: Bitmap, colorCount: Int = 6): PaletteResult {
        // CoreGraphics .high 在大幅缩小时使用 Lanczos 级别的重采样。
        // Android 默认的双线性缩放会将同一张照片分到不同色簇，因此在此对齐 iOS。
        val sample = lanczosScale(bitmap, 96, 96)
        val pixels = IntArray(96 * 96)
        sample.getPixels(pixels, 0, 96, 0, 0, 96, 96)
        if (sample !== bitmap) sample.recycle()

        data class Bucket(var r: Double = 0.0, var g: Double = 0.0, var b: Double = 0.0, var count: Double = 0.0)
        val buckets = HashMap<Int, Bucket>()
        for (pixel in pixels) {
            val alpha = pixel ushr 24 and 0xff
            if (alpha <= 16) continue
            val r = (pixel ushr 16 and 0xff) / 255.0
            val g = (pixel ushr 8 and 0xff) / 255.0
            val b = (pixel and 0xff) / 255.0
            val key = ((r * 31).toInt() shl 10) or ((g * 31).toInt() shl 5) or (b * 31).toInt()
            val bucket = buckets.getOrPut(key) { Bucket() }
            bucket.r += r; bucket.g += g; bucket.b += b; bucket.count++
        }
        val points = buckets.values.map {
            val color = RGBColor((it.r / it.count).toFloat(), (it.g / it.count).toFloat(), (it.b / it.count).toFloat())
            Point(color, OKLab.from(color), it.count)
        }
        if (points.isEmpty()) return PaletteResult(RGBColor.fallback.take(colorCount), List(colorCount) { 100.0 / colorCount })

        val count = minOf(colorCount, points.size)
        val centers = mutableListOf(points.maxBy { it.weight }.lab)
        while (centers.size < count) {
            centers += points.maxBy { point ->
                (centers.minOf { point.lab.distanceSquared(it) }) * (ln(point.weight + 2) / ln(2.0))
            }.lab
        }
        repeat(18) {
            val lSums = DoubleArray(count)
            val aSums = DoubleArray(count)
            val bSums = DoubleArray(count)
            val weights = DoubleArray(count)
            points.forEach { point ->
                val cluster = centers.indices.minBy { point.lab.distanceSquared(centers[it]) }
                lSums[cluster] += point.lab.l * point.weight
                aSums[cluster] += point.lab.a * point.weight
                bSums[cluster] += point.lab.b * point.weight
                weights[cluster] += point.weight
            }
            var movement = 0.0
            centers.indices.forEach { index ->
                if (weights[index] > 0) {
                    val updated = OKLab(lSums[index] / weights[index], aSums[index] / weights[index], bSums[index] / weights[index])
                    movement = maxOf(movement, centers[index].distanceSquared(updated))
                    centers[index] = updated
                }
            }
            if (movement < .0000001) return@repeat
        }

        val weights = DoubleArray(count)
        val rSums = DoubleArray(count)
        val gSums = DoubleArray(count)
        val bSums = DoubleArray(count)
        points.forEach { point ->
            val cluster = centers.indices.minBy { point.lab.distanceSquared(centers[it]) }
            weights[cluster] += point.weight
            rSums[cluster] += point.color.red * point.weight
            gSums[cluster] += point.color.green * point.weight
            bSums[cluster] += point.color.blue * point.weight
        }
        val total = weights.sum().coerceAtLeast(1.0)
        val sorted = weights.indices.filter { weights[it] > 0 }.sortedByDescending { weights[it] }
        val colors = sorted.map { RGBColor((rSums[it] / weights[it]).toFloat(), (gSums[it] / weights[it]).toFloat(), (bSums[it] / weights[it]).toFloat()) }.toMutableList()
        val percentages = sorted.map { kotlin.math.round(weights[it] / total * 1000) / 10.0 }.toMutableList()
        if (percentages.isNotEmpty()) {
            val largest = percentages.indices.maxBy { percentages[it] }
            percentages[largest] += kotlin.math.round((100.0 - percentages.sum()) * 10) / 10.0
        }
        return PaletteResult(colors.take(colorCount), percentages.take(colorCount))
    }

    private data class ResampleWeights(val indices: IntArray, val weights: FloatArray)

    private fun lanczosScale(source: Bitmap, targetWidth: Int, targetHeight: Int): Bitmap {
        if (source.width == targetWidth && source.height == targetHeight) return source.copy(Bitmap.Config.ARGB_8888, false)
        val sourcePixels = IntArray(source.width * source.height)
        source.getPixels(sourcePixels, 0, source.width, 0, 0, source.width, source.height)
        val horizontalWeights = buildWeights(source.width, targetWidth)
        val verticalWeights = buildWeights(source.height, targetHeight)
        val horizontal = FloatArray(source.height * targetWidth * 3)
        for (y in 0 until source.height) {
            for (x in 0 until targetWidth) {
                val table = horizontalWeights[x]
                var red = 0f
                var green = 0f
                var blue = 0f
                table.indices.forEachIndexed { position, sourceX ->
                    val color = sourcePixels[y * source.width + sourceX]
                    val weight = table.weights[position]
                    red += ((color ushr 16) and 0xff) * weight
                    green += ((color ushr 8) and 0xff) * weight
                    blue += (color and 0xff) * weight
                }
                val index = (y * targetWidth + x) * 3
                horizontal[index] = red
                horizontal[index + 1] = green
                horizontal[index + 2] = blue
            }
        }
        val output = IntArray(targetWidth * targetHeight)
        for (y in 0 until targetHeight) {
            val table = verticalWeights[y]
            for (x in 0 until targetWidth) {
                var red = 0f
                var green = 0f
                var blue = 0f
                table.indices.forEachIndexed { position, sourceY ->
                    val index = (sourceY * targetWidth + x) * 3
                    val weight = table.weights[position]
                    red += horizontal[index] * weight
                    green += horizontal[index + 1] * weight
                    blue += horizontal[index + 2] * weight
                }
                output[y * targetWidth + x] = (0xff shl 24) or
                    (red.toInt().coerceIn(0, 255) shl 16) or
                    (green.toInt().coerceIn(0, 255) shl 8) or
                    blue.toInt().coerceIn(0, 255)
            }
        }
        return Bitmap.createBitmap(output, targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
    }

    private fun buildWeights(sourceSize: Int, targetSize: Int): List<ResampleWeights> {
        val scale = targetSize.toDouble() / sourceSize
        val filterScale = minOf(1.0, scale)
        val support = 3.0 / filterScale
        return List(targetSize) { target ->
            val center = (target + .5) / scale - .5
            val start = ceil(center - support).toInt()
            val end = floor(center + support).toInt()
            val merged = linkedMapOf<Int, Double>()
            for (sample in start..end) {
                val distance = (sample - center) * filterScale
                val weight = lanczos(distance) * filterScale
                if (abs(weight) > 1e-9) {
                    val clamped = sample.coerceIn(0, sourceSize - 1)
                    merged[clamped] = (merged[clamped] ?: 0.0) + weight
                }
            }
            val sum = merged.values.sum().takeUnless { abs(it) < 1e-12 } ?: 1.0
            ResampleWeights(
                indices = merged.keys.toIntArray(),
                weights = merged.values.map { (it / sum).toFloat() }.toFloatArray(),
            )
        }
    }

    private fun lanczos(value: Double): Double {
        val distance = abs(value)
        if (distance < 1e-9) return 1.0
        if (distance >= 3.0) return 0.0
        val angle = PI * value
        return (sin(angle) / angle) * (sin(angle / 3.0) / (angle / 3.0))
    }
}

object LiteraryColorCatalog {
    private val swatches = listOf(
        "玄夜" to 0x101214, "乌金" to 0x1B1B1F, "墨黛" to 0x24242A, "鸦青" to 0x313541,
        "苍墨" to 0x3B4443, "远山黛" to 0x4A5257, "烟栗" to 0x605455, "烟雨灰" to 0x81878A,
        "银鼠" to 0xAAA7A2, "素绡" to 0xD8D5CF, "月白" to 0xF1F5F3, "云絮" to 0xFBF7F1,
        "胭脂" to 0x9D2933, "朱砂" to 0xD94A3D, "绯红" to 0xC83C4A, "茜草" to 0xB7474D,
        "海棠" to 0xDB6B73, "桃夭" to 0xF2A6A0, "樱粉" to 0xF4C3C2, "梅染" to 0x8E4A62, "酡颜" to 0xC77878,
        "赭石" to 0x8A4B2D, "杏子" to 0xF2B36D, "橘柚" to 0xE9883D, "琥珀" to 0xC77B30,
        "桂皮" to 0x9A6446, "栗壳" to 0x6F4E3D, "驼绒" to 0xB69B7C, "蜜蜡" to 0xE2A95A,
        "秋香" to 0xD8B24A, "缃叶" to 0xF1D79A, "鹅黄" to 0xF3DC75, "苍黄" to 0xA99445,
        "麦秆" to 0xD6C184, "金桂" to 0xD8A737, "豆蔻黄" to 0xE8E1B4, "青柠" to 0xA8C928, "嫩蕊" to 0xD4E157,
        "竹青" to 0x4F7A5A, "柳芽" to 0xA8C879, "豆绿" to 0x86B88A, "松花" to 0xB7C8A5,
        "松柏" to 0x315C47, "青苔" to 0x647A55, "翡翠" to 0x2F8C69, "荷叶" to 0x607F61,
        "薄荷" to 0xA6D8B4, "艾绿" to 0x8BA888, "芭蕉" to 0x6AAF45, "葱青" to 0x2FB36C,
        "青瓷" to 0x6FA9A3, "水碧" to 0xA2D4CF, "天水碧" to 0x8FD3D6, "湖蓝" to 0x4FA4B8,
        "鸭卵青" to 0xC1D5CE, "石青" to 0x3B7F84, "孔雀蓝" to 0x197C88,
        "黛蓝" to 0x35536B, "晴山" to 0x8AAFC7, "群青" to 0x35599A, "靛青" to 0x2F477A,
        "霁蓝" to 0x4A77B5, "月影蓝" to 0x6F839B, "瓷蓝" to 0x2D6F9F, "海天" to 0x75B9D1, "缥色" to 0xB4CFDA,
        "紫苑" to 0x76528B, "雪青" to 0xB6A7CC, "藕荷" to 0xC4A0B6, "绛紫" to 0x713B5F,
        "藤萝" to 0x9A7BA8, "丁香" to 0xB59CB7, "木槿" to 0xA35C7A, "葡萄" to 0x5E3F66,
        "暮云紫" to 0x6E627B, "烟紫" to 0x8A788C,
    ).map { (name, hex) ->
        val color = RGBColor(((hex shr 16) and 0xff) / 255f, ((hex shr 8) and 0xff) / 255f, (hex and 0xff) / 255f)
        Triple(name, color, OKLab.from(color))
    }

    fun name(color: RGBColor): String {
        val target = OKLab.from(color)
        return swatches.minByOrNull { target.distanceSquared(it.third) }?.first ?: "烟雨灰"
    }
}

data class MotionCardTheme(val background: RGBColor, val foreground: RGBColor)

object MotionCardThemeResolver {
    fun resolve(colors: List<RGBColor>, percentages: List<Double>): MotionCardTheme {
        val entries = (if (colors.isEmpty()) RGBColor.fallback else colors).mapIndexed { index, color -> color to percentages.getOrElse(index) { 0.0 } }
        val weighted = if (entries.any { it.second > 0 }) entries.filter { it.second > 0 } else entries.map { it.first to 1.0 }
        val strongest = weighted.maxOfOrNull { it.second } ?: 1.0
        val candidates = weighted.filter { (color, weight) ->
            val span = maxOf(color.red, color.green, color.blue) - minOf(color.red, color.green, color.blue)
            val neutralExtreme = (color.relativeLuminance >= .84f && span < .10f) ||
                (color.relativeLuminance <= .025f && span < .08f)
            !neutralExtreme && weight >= maxOf(1.5, strongest * .04) &&
                (span >= .075 || weight >= strongest * .18)
        }
        val anchor = (candidates.ifEmpty { weighted }).maxByOrNull { (color, weight) ->
            weight + (maxOf(color.red, color.green, color.blue) - minOf(color.red, color.green, color.blue)).coerceAtMost(.8f) * 10
        }?.first ?: RGBColor.fallback.first()

        val black = RGBColor(.025f, .025f, .028f)
        val white = RGBColor(.975f, .975f, .97f)

        val dark = anchor.relativeLuminance < .12f
        var background = if (dark) {
            anchor.mixed(RGBColor(.965f, .965f, .95f), .13f)
        } else if (anchor.relativeLuminance > .76f) {
            val toned = anchor.mixed(black, .075f)
            if (toned.chromaSpan < .035f && toned.relativeLuminance > .82f) RGBColor(.91f, .905f, .885f) else toned
        } else {
            anchor.mixed(RGBColor(.965f, .965f, .95f), if (anchor.relativeLuminance < .30f) .62f else .50f)
        }
        repeat(16) {
            val contrast = if (dark) white.contrastRatio(background) else black.contrastRatio(background)
            if (contrast < 7f) background = background.mixed(if (dark) black else white, .10f)
        }
        val preferred = anchor.mixed(if (dark) white else black, if (dark) .88f else .82f)
        val foreground = if (preferred.contrastRatio(background) >= 7f) preferred
        else if (black.contrastRatio(background) >= white.contrastRatio(background)) black else white
        return MotionCardTheme(background, foreground)
    }

    private val RGBColor.chromaSpan: Float
        get() = maxOf(red, green, blue) - minOf(red, green, blue)

    private fun RGBColor.mixed(other: RGBColor, amount: Float): RGBColor {
        val value = amount.coerceIn(0f, 1f)
        return RGBColor(
            red + (other.red - red) * value,
            green + (other.green - green) * value,
            blue + (other.blue - blue) * value,
        )
    }
}
