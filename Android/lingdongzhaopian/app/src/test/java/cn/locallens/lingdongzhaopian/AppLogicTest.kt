package cn.locallens.lingdongzhaopian

import androidx.compose.ui.geometry.Offset
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AppLogicTest {
    @Test
    fun coverPhotoPlacementAlwaysCoversViewportAfterExtremeDragging() {
        listOf(
            Triple(4032 to 3024, 1080f to 1440f, JournalTransform(offset = Offset(9_000f, -9_000f))),
            Triple(3024 to 4032, 1080f to 620f, JournalTransform(scale = 2.4f, offset = Offset(-20_000f, 20_000f))),
            Triple(1200 to 800, 420f to 420f, JournalTransform(scale = 1.25f, offset = Offset(500f, 500f))),
        ).forEach { (source, viewport, transform) ->
            val placement = coverPhotoPlacement(
                source.first,
                source.second,
                viewport.first,
                viewport.second,
                transform,
            )
            assertTrue(placement.left <= .001f)
            assertTrue(placement.top <= .001f)
            assertTrue(placement.left + placement.width >= viewport.first - .001f)
            assertTrue(placement.top + placement.height >= viewport.second - .001f)
        }
    }

    @Test
    fun coverPhotoPlacementKeepsUnusedAxisCentered() {
        val placement = coverPhotoPlacement(
            sourceWidth = 900,
            sourceHeight = 1600,
            viewportWidth = 600f,
            viewportHeight = 600f,
            transform = JournalTransform(offset = Offset(0f, 300f)),
        )
        assertEquals(0f, placement.left, .001f)
        assertEquals(0f, placement.offset.x, .001f)
        assertTrue(placement.offset.y > 0f)
    }

    @Test
    fun journalItemsMoveInBothDirectionsWithoutLoss() {
        val values = listOf("A", "B", "C", "D")
        assertEquals(listOf("B", "C", "A", "D"), values.moving(0, 2))
        assertEquals(listOf("A", "D", "B", "C"), values.moving(3, 1))
        assertEquals(values, values.moving(-1, 2))
        assertEquals(values, values.moving(1, 8))
    }

    @Test
    fun everyExportResolutionUsesRequestedAspectRatio() {
        assertEquals(ExportDimensions(1080, 1440), exportDimensions(ExportResolution.Standard, 4032, .75f))
        assertEquals(ExportDimensions(2160, 3840), exportDimensions(ExportResolution.High, 4032, 9f / 16f))
        assertEquals(ExportDimensions(4032, 5040), exportDimensions(ExportResolution.Original, 4032, .8f))
        assertEquals(6000, exportDimensions(ExportResolution.Original, 12_000, 1f).width)
        assertEquals(1080, exportDimensions(ExportResolution.Original, 640, 1f).width)
    }

    @Test
    fun sensitiveTextClassifierCoversAllAdvertisedKinds() {
        assertTrue(SensitiveTextClassifier.isLicensePlate("京A12345"))
        assertTrue(SensitiveTextClassifier.isLicensePlate("RA12345"))
        assertTrue(SensitiveTextClassifier.isSensitive("13812345678"))
        assertTrue(SensitiveTextClassifier.isSensitive("11010519491231002X"))
        assertTrue(SensitiveTextClassifier.isSensitive("6222021234567890"))
        assertTrue(SensitiveTextClassifier.isSensitive("hello@example.com"))
        assertFalse(SensitiveTextClassifier.isSensitive("今天的天气很好"))
    }

    @Test
    fun motionPhotoRoundTripKeepsAppendedVideo() {
        val jpeg = byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0xff.toByte(), 0xd9.toByte())
        val mp4 = minimalMp4()
        val combined = MotionPhotoContainer.embed(jpeg, mp4, 500_000)
        val range = MotionPhotoContainer.videoRange(combined)
        assertNotNull(range)
        assertEquals(mp4.size, range!!.length)
        assertArrayEquals(mp4, MotionPhotoContainer.videoBytes(combined))
        val text = combined.toString(Charsets.ISO_8859_1)
        assertTrue(text.contains("GCamera:MotionPhoto=\"1\""))
        assertTrue(text.contains("GCamera:MicroVideoOffset=\"${mp4.size}\""))
    }

    @Test
    fun ordinaryJpegIsNotMisclassifiedAsMotionPhoto() {
        val jpeg = byteArrayOf(0xff.toByte(), 0xd8.toByte(), 1, 2, 3, 4, 0xff.toByte(), 0xd9.toByte())
        assertNull(MotionPhotoContainer.videoRange(jpeg))
    }

    private fun minimalMp4(): ByteArray = byteArrayOf(
        0, 0, 0, 16, 'f'.code.toByte(), 't'.code.toByte(), 'y'.code.toByte(), 'p'.code.toByte(),
        'i'.code.toByte(), 's'.code.toByte(), 'o'.code.toByte(), 'm'.code.toByte(), 0, 0, 0, 0,
    )
}
