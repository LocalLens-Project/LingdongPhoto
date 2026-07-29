package cn.locallens.lingdongzhaopian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ColorThemeTest {
    @Test
    fun motionCardThemeAlwaysKeepsReadableText() {
        val palettes = listOf(
            listOf(RGBColor(.12f, .20f, .08f), RGBColor(.50f, .62f, .20f)),
            listOf(RGBColor(.93f, .93f, .90f), RGBColor(.88f, .32f, .28f)),
            RGBColor.fallback,
        )
        palettes.forEach { palette ->
            val theme = MotionCardThemeResolver.resolve(palette, List(palette.size) { 100.0 / palette.size })
            assertTrue(theme.foreground.contrastRatio(theme.background) >= 7f)
        }
    }

    @Test
    fun sampledGradientStaysReadableAgainstEveryStop() {
        val palettes = listOf(
            listOf(RGBColor(.12f, .20f, .08f), RGBColor(.50f, .62f, .20f), RGBColor(.86f, .90f, .62f)),
            listOf(RGBColor(.93f, .93f, .90f), RGBColor(.88f, .32f, .28f), RGBColor(.30f, .34f, .52f)),
            // A near-monochrome photo is the case that can collapse into a flat fill.
            listOf(RGBColor(.42f, .43f, .44f), RGBColor(.44f, .45f, .46f), RGBColor(.40f, .41f, .42f)),
            RGBColor.fallback,
        )
        palettes.forEach { palette ->
            val percentages = List(palette.size) { 100.0 / palette.size }
            val theme = MotionCardGradientResolver.resolve(palette, percentages)
            assertEquals(4, theme.colors.size)
            theme.colors.forEach { stop ->
                assertTrue(
                    "gradient stop $stop is unreadable",
                    theme.foreground.contrastRatio(stop) >= 7f,
                )
            }
        }
    }

    @Test
    fun sampledGradientKeepsAVisibleTransitionOnMonochromePhotos() {
        val palette = listOf(RGBColor(.42f, .43f, .44f), RGBColor(.44f, .45f, .46f))
        val theme = MotionCardGradientResolver.resolve(palette, listOf(70.0, 30.0))
        val first = theme.colors.first()
        val last = theme.colors.last()
        val distance = kotlin.math.abs(first.red - last.red) +
            kotlin.math.abs(first.green - last.green) +
            kotlin.math.abs(first.blue - last.blue)
        assertTrue("gradient collapsed into a solid fill", distance > .04f)
    }

    @Test
    fun emptyPaletteStillProducesAUsableGradient() {
        val theme = MotionCardGradientResolver.resolve(emptyList(), emptyList())
        assertEquals(4, theme.colors.size)
        theme.colors.forEach { assertTrue(theme.foreground.contrastRatio(it) >= 7f) }
    }
}
