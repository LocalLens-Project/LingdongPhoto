package cn.locallens.lingdongzhaopian

import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

/**
 * Bridges the Kotlin and Swift ticket implementations through files on disk.
 *
 * `/tmp/xplat/android-url.txt` is handed to a Swift harness built from the iOS `TicketPayload.swift`,
 * and `/tmp/xplat/ios-url.txt` is what that harness produced. The test writes its side
 * unconditionally and only asserts on the iOS side when the harness has already run, so it stays
 * green on machines without Xcode.
 */
class CrossPlatformTicketBridgeTest {
    private val directory = File("/tmp/xplat")

    @Test
    fun writesAnAndroidTicketURLForTheSwiftHarness() {
        directory.mkdirs()
        val url = TicketEnvelope.invocationURL(TicketPayload.sample)
        File(directory, "android-url.txt").writeText(url)
        assertEquals(TicketPayload.sample.compacted(0), TicketEnvelope.decode(url))
    }

    @Test
    fun decodesATicketURLProducedByTheIOSImplementation() {
        val file = File(directory, "ios-url.txt")
        assumeTrue("Swift harness output missing", file.isFile)
        val payload = TicketEnvelope.decode(file.readText().trim())
        val expected = TicketPayload.sample.compacted(0)
        assertEquals(expected.ticketID, payload.ticketID)
        assertEquals(expected.fingerprint, payload.fingerprint)
        assertEquals(expected.headerTitle, payload.headerTitle)
        assertEquals(expected.title, payload.title)
        assertEquals(expected.subtitle, payload.subtitle)
        assertEquals(expected.captureTime, payload.captureTime)
        assertEquals(expected.place, payload.place)
        assertEquals(expected.device, payload.device)
        assertEquals(expected.lens, payload.lens)
        assertEquals(expected.captureSettings, payload.captureSettings)
        assertEquals(expected.revealLayout, payload.revealLayout)
        assertEquals(expected.palette, payload.palette)
    }
}
