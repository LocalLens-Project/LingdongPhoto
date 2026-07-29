package cn.locallens.lingdongzhaopian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.zip.Inflater

class TicketEnvelopeTest {
    @Test
    fun ticketURLRoundTripsThroughTheSharedWireFormat() {
        val url = TicketEnvelope.invocationURL(TicketPayload.sample)
        assertTrue(url.startsWith("https://appclip.apple.com/id?p=com.example.lingdongphoto.Clip&t="))
        val decoded = TicketEnvelope.decode(url)
        assertEquals(TicketPayload.sample.compacted(0), decoded)
    }

    /**
     * Apple's `COMPRESSION_ZLIB` emits header-less DEFLATE. Emitting a zlib wrapper here would make
     * every Android ticket fail to open on iPhone, so pin the exact bytes iOS expects.
     */
    @Test
    fun compressedTicketBodyIsHeaderLessDeflate() {
        val url = TicketEnvelope.invocationURL(TicketPayload.sample)
        val token = url.substringAfter("&t=").substringBefore("&c=")
        val envelope = TicketEnvelope.base64URLDecode(token)
        assertNotNull(envelope)
        assertEquals(0x5A.toByte(), envelope!![0])

        val inflater = Inflater(true)
        inflater.setInput(envelope, 1, envelope.size - 1)
        val output = ByteArray(8_192)
        val written = inflater.inflate(output)
        inflater.end()
        val json = String(output, 0, written, Charsets.UTF_8)
        assertTrue(json.startsWith("{"))
        assertTrue(json.contains("\"i\":\"LD-7A2F-19C8\""))
        assertTrue(json.contains("\"v\":1"))
    }

    @Test
    fun uncompressibleTicketsFallBackToThePlainMarker() {
        // A payload whose JSON grows under DEFLATE must still travel, marked as plain.
        val payload = TicketPayload(
            ticketID = "LD-0000-0001",
            fingerprint = "0000000000000001",
            title = "短",
            palette = emptyList(),
        )
        val url = TicketEnvelope.invocationURL(payload)
        val token = url.substringAfter("&t=").substringBefore("&c=")
        val envelope = TicketEnvelope.base64URLDecode(token)!!
        assertTrue(envelope[0] == 0x4A.toByte() || envelope[0] == 0x5A.toByte())
        assertEquals(payload.compacted(0), TicketEnvelope.decode(url))
    }

    @Test
    fun aTamperedTicketIsRejected() {
        val url = TicketEnvelope.invocationURL(TicketPayload.sample)
        val tampered = url.dropLast(1) + if (url.last() == 'a') 'b' else 'a'
        try {
            TicketEnvelope.decode(tampered)
            fail("A ticket with a broken checksum must not verify")
        } catch (error: TicketEnvelopeException) {
            assertEquals(TicketEnvelopeException.CorruptedPayload, error)
        }
    }

    @Test
    fun urlsWithoutATicketPayloadAreNotMistakenForTickets() {
        assertTrue(!TicketEnvelope.looksLikeTicketURL("https://locallens.cn/LingdongPhoto"))
        assertTrue(!TicketEnvelope.looksLikeTicketURL("hello world"))
        assertTrue(TicketEnvelope.looksLikeTicketURL(TicketEnvelope.invocationURL(TicketPayload.sample)))
    }

    @Test
    fun oversizedPublicInformationIsCompactedInsteadOfDropped() {
        val long = "极".repeat(400)
        val payload = TicketPayload.sample.copy(
            title = long,
            subtitle = long,
            message = long,
            place = long,
            device = long,
            lens = long,
            captureSettings = long,
        )
        val url = TicketEnvelope.invocationURL(payload)
        assertTrue(url.toByteArray(Charsets.UTF_8).size <= 2_000)
        val decoded = TicketEnvelope.decode(url)
        assertEquals(payload.ticketID, decoded.ticketID)
        assertTrue(decoded.title.length <= 56)
        assertEquals("极".repeat(TicketPayload.MAX_MESSAGE_LENGTH), decoded.message)
    }

    @Test
    fun messageLimitCountsUnicodeCodePointsWithoutSplittingEmoji() {
        val message = "旅".repeat(79) + "🏞️继续"
        val limited = TicketPayload.limitedMessage(message)
        assertEquals(80, limited.codePointCount(0, limited.length))
        assertEquals("旅".repeat(79) + "🏞", limited)
        assertEquals(limited, TicketPayload.normalizedMessage(limited))
    }

    @Test
    fun barcodeValueIsTwelveDigitsDerivedFromTheTicketIdentity() {
        val value = TicketEnvelope.barcodeValue(TicketPayload.sample)
        assertEquals(12, value.length)
        assertTrue(value.all(Char::isDigit))
        assertEquals(value, TicketEnvelope.barcodeValue(TicketPayload.sample))
    }

    @Test
    fun ticketIdentityIsDerivedFromTheSourceBytes() {
        val signature = TicketPayload.contentSignature("lingdong".toByteArray(), fallback = 7L)
        assertEquals("LD-", TicketPayload.ticketIdentifier(signature).take(3))
        assertEquals(12, TicketPayload.ticketIdentifier(signature).length)
        assertEquals(16, TicketPayload.fingerprintText(signature).length)
        assertEquals(7L, TicketPayload.contentSignature(null, fallback = 7L))
    }
}
