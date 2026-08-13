package cn.locallens.lingdongzhaopian

import android.graphics.Bitmap
import android.net.Uri
import kotlin.math.abs
import kotlin.math.cbrt
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

enum class RelationshipLens(val label: String) {
    Resonance("共鸣"), Contrast("对照"), Bridge("过渡")
}

data class RelationshipPhoto(
    val uri: Uri,
    val bitmap: Bitmap,
    val sourceWidth: Int,
    val sourceHeight: Int,
) {
    val aspectRatio: Float get() = sourceWidth.toFloat() / sourceHeight.coerceAtLeast(1)
    val isLandscape: Boolean get() = aspectRatio > 1.08f
    val isPortrait: Boolean get() = aspectRatio < .92f
}

data class RelationshipColor(
    val color: RGBColor,
    val weight: Double,
) {
    val hex: String get() = color.hex
    val lightness: Double get() = RelationshipOKLab.from(color).l

    fun mixed(other: RelationshipColor, amount: Double): RelationshipColor {
        val value = amount.coerceIn(0.0, 1.0).toFloat()
        return RelationshipColor(
            RGBColor(
                color.red + (other.color.red - color.red) * value,
                color.green + (other.color.green - color.green) * value,
                color.blue + (other.color.blue - color.blue) * value,
            ),
            weight + (other.weight - weight) * amount,
        )
    }
}

data class RelationshipPair(
    val left: RelationshipColor,
    val right: RelationshipColor,
    val distance: Double,
) {
    val middle: RelationshipColor get() = left.mixed(right, .5)
}

data class RelationshipNarrative(val title: String, val body: String)

data class ColorRelationship(
    val leftPalette: List<RelationshipColor>,
    val rightPalette: List<RelationshipColor>,
    val resonancePairs: List<RelationshipPair>,
    val contrastPairs: List<RelationshipPair>,
    val bridge: List<RelationshipColor>,
    val affinity: Int,
    val lightDifference: Int,
    val temperatureDifference: Int,
    val narratives: Map<RelationshipLens, RelationshipNarrative>,
) {
    fun pairs(lens: RelationshipLens): List<RelationshipPair> = when (lens) {
        RelationshipLens.Resonance -> resonancePairs
        RelationshipLens.Contrast -> contrastPairs
        RelationshipLens.Bridge -> resonancePairs
    }
}

private data class RelationshipOKLab(val l: Double, val a: Double, val b: Double) {
    fun distance(other: RelationshipOKLab): Double {
        val dl = l - other.l
        val da = a - other.a
        val db = b - other.b
        return sqrt(dl * dl + da * da + db * db)
    }

    companion object {
        fun from(color: RGBColor): RelationshipOKLab {
            fun linear(value: Double) = if (value <= .04045) value / 12.92 else ((value + .055) / 1.055).pow(2.4)
            val r = linear(color.red.toDouble())
            val g = linear(color.green.toDouble())
            val b = linear(color.blue.toDouble())
            val ll = cbrt(.4122214708 * r + .5363325363 * g + .0514459929 * b)
            val mm = cbrt(.2119034982 * r + .6806995451 * g + .1073969566 * b)
            val ss = cbrt(.0883024619 * r + .2817188376 * g + .6299787005 * b)
            return RelationshipOKLab(
                .2104542553 * ll + .7936177850 * mm - .0040720468 * ss,
                1.9779984951 * ll - 2.4285922050 * mm + .4505937099 * ss,
                .0259040371 * ll + .7827717662 * mm - .8086757660 * ss,
            )
        }
    }
}

object ColorRelationshipAnalyzer {
    fun analyze(leftBitmap: Bitmap, rightBitmap: Bitmap): ColorRelationship {
        val left = palette(leftBitmap)
        val right = palette(rightBitmap)
        val matched = bestMatches(left, right)
        val resonance = matched.sortedBy { it.distance }
        val allPairs = left.flatMap { l -> right.map { r -> pair(l, r) } }
        val contrast = allPairs.sortedByDescending { it.distance }

        val weightedDistance = matched.sumOf { it.distance * max((it.left.weight + it.right.weight) / 2, .05) } /
            matched.sumOf { max((it.left.weight + it.right.weight) / 2, .05) }.coerceAtLeast(.01)
        val affinity = ((1 - min(weightedDistance / .34, 1.0)) * 100).roundToInt()
        val leftLight = left.sumOf { it.lightness * it.weight }
        val rightLight = right.sumOf { it.lightness * it.weight }
        val leftWarm = warmth(left)
        val rightWarm = warmth(right)
        val lightDifference = (abs(leftLight - rightLight) * 100).roundToInt()
        val temperatureDifference = (abs(leftWarm - rightWarm) * 100).roundToInt()
        val closest = resonance.first()
        val strongest = contrast.first()
        val bridge = (0..6).map { closest.left.mixed(closest.right, it / 6.0) }
        val shared = colorName(closest.middle)
        val leftName = colorName(left.first())
        val rightName = colorName(right.first())
        val contrastLeft = colorName(strongest.left)
        val contrastRight = colorName(strongest.right)

        return ColorRelationship(
            left, right, resonance, contrast, bridge, affinity, lightDifference, temperatureDifference,
            mapOf(
                RelationshipLens.Resonance to resonanceCopy(affinity, lightDifference, temperatureDifference, shared, leftName, rightName),
                RelationshipLens.Contrast to contrastCopy(affinity, lightDifference, temperatureDifference, contrastLeft, contrastRight),
                RelationshipLens.Bridge to bridgeCopy(affinity, lightDifference, temperatureDifference, shared, leftName, rightName),
            ),
        )
    }

    private fun palette(bitmap: Bitmap): List<RelationshipColor> {
        val result = PaletteExtractor.extract(bitmap, 5)
        val total = result.percentages.sum().takeIf { it > 0 } ?: 100.0
        return result.colors.take(5).mapIndexed { index, color ->
            RelationshipColor(color, result.percentages.getOrElse(index) { 100.0 / 5 } / total)
        }.let { values -> if (values.size == 5) values else values + List(5 - values.size) { values.last() } }
    }

    private fun pair(left: RelationshipColor, right: RelationshipColor) = RelationshipPair(
        left, right, RelationshipOKLab.from(left.color).distance(RelationshipOKLab.from(right.color)),
    )

    private fun bestMatches(left: List<RelationshipColor>, right: List<RelationshipColor>): List<RelationshipPair> {
        var best = right.indices.toList()
        var bestCost = Double.MAX_VALUE
        permutations(right.indices.toList()).forEach { order ->
            val cost = left.indices.sumOf { index ->
                val candidate = pair(left[index], right[order[index]])
                candidate.distance * (.45 + (candidate.left.weight + candidate.right.weight) / 2)
            }
            if (cost < bestCost) { bestCost = cost; best = order }
        }
        return left.indices.map { pair(left[it], right[best[it]]) }
    }

    private fun permutations(values: List<Int>): List<List<Int>> = if (values.size <= 1) listOf(values) else
        values.indices.flatMap { index ->
            val rest = values.toMutableList()
            val head = rest.removeAt(index)
            permutations(rest).map { listOf(head) + it }
        }

    private fun warmth(palette: List<RelationshipColor>) = palette.sumOf {
        ((it.color.red - it.color.blue + 1) / 2.0) * it.weight
    }

    private fun resonanceCopy(a: Int, l: Int, t: Int, shared: String, left: String, right: String): RelationshipNarrative {
        val title = when {
            a >= 84 && l <= 10 -> "同频"
            a >= 68 -> "遥相呼应"
            t <= 12 -> "温度相认"
            else -> "微妙共振"
        }
        val body = when {
            a >= 84 -> "$shared 构成两端最稳定的共同色，图 1 的$left 与图 2 的$right 在相近光线里彼此回应。"
            l <= 12 -> "两张照片保留着接近的明暗呼吸，$shared 让原本不同的画面自然相认。"
            t <= 12 -> "冷暖方向十分接近，$left 与$right 之间留着一条安静而清晰的共同线索。"
            else -> "它们没有完全相同，却由$shared 建立起稳定的联系，让差异停在舒服的距离。"
        }
        return RelationshipNarrative(title, body)
    }

    private fun contrastCopy(a: Int, l: Int, t: Int, left: String, right: String): RelationshipNarrative {
        val title = when {
            t >= 52 -> "冷暖对望"
            l >= 38 -> "明暗分野"
            a <= 25 -> "两种声部"
            else -> "张力相见"
        }
        val body = when {
            t >= 52 -> "图 1 的$left 留下温度，图 2 的$right 接住冷色，最远的色差成为画面的停顿。"
            l >= 38 -> "一张向光，一张向影；$left 与$right 把明暗差异变成清晰的视觉节奏。"
            a <= 25 -> "两套色彩各自成立，$left 与$right 的距离让它们像两个声部一样相互衬托。"
            else -> "相近之中仍保留对照，$left 与$right 让两张照片的个性同时被看见。"
        }
        return RelationshipNarrative(title, body)
    }

    private fun bridgeCopy(a: Int, l: Int, t: Int, shared: String, left: String, right: String): RelationshipNarrative {
        val title = when {
            a >= 78 -> "一线相连"
            l >= 36 -> "穿过光影"
            t >= 45 -> "温度渐变"
            else -> "色彩渡口"
        }
        val body = when {
            l >= 36 -> "从图 1 的$left 穿过$shared，再抵达图 2 的$right，亮度差被拆成一段自然过渡。"
            t >= 45 -> "$shared 是冷暖之间的停靠点，让$left 到$right 的变化不再突然。"
            a >= 78 -> "共同色已经足够接近，只需沿着$shared 轻轻过渡，两张照片便连成同一段色彩叙事。"
            else -> "$shared 像一座小小的渡口，把图 1 的$left 和图 2 的$right 接到同一条路径上。"
        }
        return RelationshipNarrative(title, body)
    }

    private fun colorName(value: RelationshipColor): String {
        val c = value.color
        val maximum = max(c.red, max(c.green, c.blue))
        val minimum = min(c.red, min(c.green, c.blue))
        val chroma = maximum - minimum
        if (value.lightness < .18) return "墨色"
        if (value.lightness > .82 && chroma < .12) return "月白"
        if (chroma < .10) return if (value.lightness > .52) "雾灰" else "岩灰"
        var hue = when (maximum) {
            c.red -> ((c.green - c.blue) / chroma % 6) * 60
            c.green -> ((c.blue - c.red) / chroma + 2) * 60
            else -> ((c.red - c.green) / chroma + 4) * 60
        }
        if (hue < 0) hue += 360
        return when (hue) {
            in 0f..<18f, in 345f..360f -> "朱砂"
            in 18f..<45f -> "陶橙"
            in 45f..<72f -> "麦金"
            in 72f..<155f -> "苔绿"
            in 155f..<200f -> "雨青"
            in 200f..<255f -> "暮蓝"
            in 255f..<300f -> "藤紫"
            else -> "胭脂"
        }
    }
}
