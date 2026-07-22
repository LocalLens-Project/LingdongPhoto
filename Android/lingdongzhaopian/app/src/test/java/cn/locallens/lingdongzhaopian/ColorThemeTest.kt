package cn.locallens.lingdongzhaopian

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
}
