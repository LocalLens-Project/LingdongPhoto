package cn.locallens.lingdongzhaopian

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.security.MessageDigest
import java.util.zip.Deflater
import java.util.zip.Inflater

enum class TicketCodeStyle(val title: String, val shortTitle: String, val explanation: String) {
    Barcode(
        "经典一维码",
        "一维码",
        "显示真实可扫描的票根编号，不包含照片或拍摄隐私，适合保存与分享。",
    ),
    VerificationQR(
        "验证二维码",
        "二维码",
        "扫描后可在灵动照片中查看色盘、拍摄信息与文案，全程在本机完成。",
    ),
}

enum class TicketLayoutStyle(val label: String) {
    Classic("横向经典"),
    Vertical("纵向旅行"),
    Minimal("极简凭证");

    /** Layout hint carried inside the QR so the verification page can replay the same silhouette. */
    val revealLayout: String?
        get() = when (this) {
            Classic -> "c"
            Vertical -> "v"
            Minimal -> null
        }

    val defaultRatio: ArtworkRatio
        get() = if (this == Vertical) ArtworkRatio.ThreeFour else ArtworkRatio.TwentyOneNine
}

enum class TicketHeaderMode(val label: String) { Custom("自定义"), City("照片城市") }
enum class TicketCityNameStyle(val label: String) { Pinyin("拼音"), Chinese("中文") }

data class TicketPaletteEntry(val hex: String, val percentage: Double)

/**
 * Public ticket contents shared through the verification QR code.
 *
 * The JSON keys are deliberately single letters and must stay byte-identical to the iOS
 * `TicketPayload` `CodingKeys`, otherwise codes stop crossing between the two platforms.
 */
data class TicketPayload(
    val version: Int = CURRENT_VERSION,
    val ticketID: String,
    val fingerprint: String,
    val headerTitle: String? = null,
    val title: String,
    val subtitle: String? = null,
    val message: String? = null,
    val captureTime: String? = null,
    val place: String? = null,
    val device: String? = null,
    val lens: String? = null,
    val captureSettings: String? = null,
    val palette: List<TicketPaletteEntry> = emptyList(),
    val revealLayout: String? = null,
) {
    fun toJson(): JSONObject {
        // Keys are inserted in the same sorted order Swift's `.sortedKeys` produces. JSON objects
        // are unordered, so this only keeps the two platforms' bytes comparable while debugging.
        val json = JSONObject()
        json.put("a", JSONArray().apply {
            palette.take(6).forEach { entry ->
                put(JSONObject().put("h", entry.hex).put("p", entry.percentage))
            }
        })
        headerTitle?.let { json.put("b", it) }
        device?.let { json.put("c", it) }
        captureTime?.let { json.put("d", it) }
        captureSettings?.let { json.put("e", it) }
        json.put("f", fingerprint)
        json.put("i", ticketID)
        lens?.let { json.put("l", it) }
        normalizedMessage(message)?.let { json.put("m", it) }
        place?.let { json.put("p", it) }
        revealLayout?.let { json.put("r", it) }
        subtitle?.let { json.put("s", it) }
        json.put("t", title)
        json.put("v", version)
        return json
    }

    fun compacted(level: Int): TicketPayload {
        fun trimmed(value: String?, limit: Int): String? =
            value?.take(limit)?.trim()?.takeIf { it.isNotEmpty() }

        return when (level) {
            0 -> copy(
                headerTitle = trimmed(headerTitle, 24),
                title = trimmed(title, 56) ?: "一张影像票根",
                subtitle = trimmed(subtitle, 72),
                message = normalizedMessage(message),
                captureTime = trimmed(captureTime, 32),
                place = trimmed(place, 40),
                device = trimmed(device, 48),
                lens = trimmed(lens, 64),
                captureSettings = trimmed(captureSettings, 64),
                palette = palette.take(6),
            )

            1 -> copy(
                headerTitle = trimmed(headerTitle, 20),
                title = trimmed(title, 42) ?: "一张影像票根",
                subtitle = trimmed(subtitle, 42),
                message = normalizedMessage(message),
                captureTime = trimmed(captureTime, 24),
                place = trimmed(place, 24),
                device = trimmed(device, 32),
                lens = trimmed(lens, 36),
                captureSettings = trimmed(captureSettings, 40),
                palette = palette.take(6),
            )

            else -> copy(
                headerTitle = trimmed(headerTitle, 16),
                title = trimmed(title, 34) ?: "一张影像票根",
                subtitle = null,
                message = normalizedMessage(message),
                captureTime = trimmed(captureTime, 24),
                place = trimmed(place, 20),
                device = trimmed(device, 28),
                lens = null,
                captureSettings = trimmed(captureSettings, 32),
                palette = palette.take(6),
            )
        }
    }

    companion object {
        const val CURRENT_VERSION = 1
        const val MAX_MESSAGE_LENGTH = 80

        fun limitedMessage(value: String): String {
            val codePointCount = value.codePointCount(0, value.length)
            val end = value.offsetByCodePoints(0, minOf(MAX_MESSAGE_LENGTH, codePointCount))
            return value.substring(0, end)
        }

        fun normalizedMessage(value: String?): String? {
            if (value == null) return null
            return limitedMessage(value).trim().takeIf { it.isNotEmpty() }
        }

        fun fromJson(json: JSONObject): TicketPayload? {
            val ticketID = json.optString("i").takeIf { it.isNotEmpty() } ?: return null
            val fingerprint = json.optString("f").takeIf { it.isNotEmpty() } ?: return null
            val title = json.optString("t").takeIf { it.isNotEmpty() } ?: return null
            if (!json.has("v")) return null
            val entries = json.optJSONArray("a") ?: JSONArray()
            val palette = (0 until entries.length()).mapNotNull { index ->
                entries.optJSONObject(index)?.let { entry ->
                    val hex = entry.optString("h").takeIf { it.isNotEmpty() } ?: return@let null
                    TicketPaletteEntry(hex, entry.optDouble("p", 0.0))
                }
            }
            return TicketPayload(
                version = json.optInt("v", CURRENT_VERSION),
                ticketID = ticketID,
                fingerprint = fingerprint,
                headerTitle = json.optionalString("b"),
                title = title,
                subtitle = json.optionalString("s"),
                message = normalizedMessage(json.optionalString("m")),
                captureTime = json.optionalString("d"),
                place = json.optionalString("p"),
                device = json.optionalString("c"),
                lens = json.optionalString("l"),
                captureSettings = json.optionalString("e"),
                palette = palette,
                revealLayout = json.optionalString("r"),
            )
        }

        private fun JSONObject.optionalString(key: String): String? =
            if (isNull(key)) null else optString(key).takeIf { it.isNotEmpty() }

        fun fingerprintText(signature: Long): String = "%016X".format(signature)

        fun contentSignature(data: ByteArray?, fallback: Long): Long {
            if (data == null || data.isEmpty()) return fallback
            val digest = MessageDigest.getInstance("SHA-256").digest(data)
            var value = 0L
            for (index in 0 until 8) value = (value shl 8) or (digest[index].toLong() and 0xFF)
            return value
        }

        fun ticketIdentifier(signature: Long): String {
            val high = ((signature ushr 32) and 0xFFFF).toInt()
            val low = (signature and 0xFFFF).toInt()
            return "LD-%04X-%04X".format(high, low)
        }

        val sample = TicketPayload(
            ticketID = "LD-7A2F-19C8",
            fingerprint = "7A2F41D819C8A350",
            headerTitle = "DA LI",
            title = "风把远方写进了这一刻",
            subtitle = "A quiet journey, kept in color.",
            message = "愿很多年以后，我们仍然记得海风吹来的方向。",
            captureTime = "2026/07/26, 10:24",
            place = "海边 · 夏日旅途",
            device = "Sony α7R II",
            lens = "FE 24-70mm F2.8 GM",
            captureSettings = "ƒ/4 · 1/320s · ISO 100 · 35mm",
            palette = listOf(
                TicketPaletteEntry("#E9B477", 31.4),
                TicketPaletteEntry("#D97858", 22.8),
                TicketPaletteEntry("#5D7180", 17.6),
                TicketPaletteEntry("#263C48", 12.1),
                TicketPaletteEntry("#F0D8B8", 9.2),
                TicketPaletteEntry("#879B9B", 6.9),
            ),
            revealLayout = TicketLayoutStyle.Classic.revealLayout,
        )
    }
}

sealed class TicketEnvelopeException(val readableMessage: String) : Exception(readableMessage) {
    object InvalidURL : TicketEnvelopeException("这不是有效的影像票根链接。")
    object MissingPayload : TicketEnvelopeException("二维码没有提供影像票根数据。")
    object CorruptedPayload : TicketEnvelopeException("票根内容不完整或已被修改。")
    object UnsupportedVersion : TicketEnvelopeException("这张票根由更新版本生成，请升级后再试。")
    object PayloadTooLarge : TicketEnvelopeException("公开信息过多，无法生成稳定可扫描的二维码。")
}

/**
 * Wire format shared with iOS.
 *
 * `t` carries base64url(marker + body) and `c` the first eight SHA-256 bytes of that envelope in
 * lowercase hex. The compressed body uses raw DEFLATE without a zlib header, because Apple's
 * `COMPRESSION_ZLIB` produces exactly that; adding the two-byte zlib header here would make iOS
 * reject every Android ticket.
 */
object TicketEnvelope {
    const val PAYLOAD_KEY = "t"
    const val CHECKSUM_KEY = "c"
    const val DEFAULT_BASE_URL = "https://appclip.apple.com/id?p=com.example.lingdongphoto.Clip"

    private const val MAXIMUM_URL_LENGTH = 2_000
    private const val COMPRESSED_MARKER: Byte = 0x5A
    private const val PLAIN_MARKER: Byte = 0x4A

    fun invocationURL(payload: TicketPayload, baseURLString: String = DEFAULT_BASE_URL): String {
        val base = runCatching { URI(baseURLString.trim()) }.getOrNull()
        if (base == null || base.scheme?.lowercase() != "https" || base.host.isNullOrEmpty()) {
            throw TicketEnvelopeException.InvalidURL
        }
        val trimmedBase = baseURLString.trim()
        val prefix = trimmedBase.substringBefore('?')
        val retainedQuery = trimmedBase.substringAfter('?', "")
            .split('&')
            .filter { it.isNotEmpty() }
            .filterNot {
                val name = it.substringBefore('=')
                name == PAYLOAD_KEY || name == CHECKSUM_KEY
            }

        for (level in 0..2) {
            val (token, checksum) = encodedPayload(payload.compacted(level))
            val query = retainedQuery + listOf("$PAYLOAD_KEY=$token", "$CHECKSUM_KEY=$checksum")
            val candidate = "$prefix?${query.joinToString("&")}"
            if (candidate.toByteArray(Charsets.UTF_8).size <= MAXIMUM_URL_LENGTH) return candidate
        }
        throw TicketEnvelopeException.PayloadTooLarge
    }

    fun decode(value: String): TicketPayload {
        val items = queryItems(value) ?: throw TicketEnvelopeException.InvalidURL
        val token = items[PAYLOAD_KEY]
        val checksum = items[CHECKSUM_KEY]
        if (token.isNullOrEmpty() || checksum.isNullOrEmpty()) throw TicketEnvelopeException.MissingPayload

        val envelope = base64URLDecode(token) ?: throw TicketEnvelopeException.CorruptedPayload
        if (checksumValue(envelope) != checksum.lowercase()) throw TicketEnvelopeException.CorruptedPayload
        val body = decodedPayloadData(envelope) ?: throw TicketEnvelopeException.CorruptedPayload
        val payload = runCatching { TicketPayload.fromJson(JSONObject(String(body, Charsets.UTF_8))) }
            .getOrNull() ?: throw TicketEnvelopeException.CorruptedPayload
        if (payload.version != TicketPayload.CURRENT_VERSION) throw TicketEnvelopeException.UnsupportedVersion
        return payload
    }

    fun looksLikeTicketURL(value: String): Boolean {
        val items = queryItems(value) ?: return false
        return items.containsKey(PAYLOAD_KEY) || items.containsKey(CHECKSUM_KEY)
    }

    /**
     * Reads the query manually instead of going through `android.net.Uri`, so the wire format stays
     * verifiable from plain JVM unit tests and `+` is never mistaken for a space.
     */
    private fun queryItems(value: String): Map<String, String>? {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return null
        val separator = trimmed.indexOf('?')
        if (separator < 0) return null
        val query = trimmed.substring(separator + 1).substringBefore('#')
        if (query.isEmpty()) return null
        val items = LinkedHashMap<String, String>()
        query.split('&').forEach { pair ->
            if (pair.isEmpty()) return@forEach
            val name = percentDecoded(pair.substringBefore('='))
            if (name.isEmpty() || items.containsKey(name)) return@forEach
            items[name] = percentDecoded(pair.substringAfter('=', ""))
        }
        return items
    }

    private fun percentDecoded(value: String): String {
        if ('%' !in value) return value
        val output = java.io.ByteArrayOutputStream(value.length)
        var index = 0
        while (index < value.length) {
            val character = value[index]
            val hex = if (character == '%' && index + 2 < value.length) {
                value.substring(index + 1, index + 3).toIntOrNull(16)
            } else null
            if (hex != null) {
                output.write(hex)
                index += 3
            } else {
                output.write(character.toString().toByteArray(Charsets.UTF_8))
                index += 1
            }
        }
        return String(output.toByteArray(), Charsets.UTF_8)
    }

    /**
     * Keeps the visible credential compact enough to stay scannable inside the narrow ticket stub.
     * An even-length numeric value lets Code 128 use its dense Code Set C.
     */
    fun barcodeValue(payload: TicketPayload): String {
        val source = "${payload.ticketID}|${payload.fingerprint}".toByteArray(Charsets.UTF_8)
        val digest = MessageDigest.getInstance("SHA-256").digest(source)
        var value = 0L
        for (index in 0 until 8) value = (value shl 8) or (digest[index].toLong() and 0xFF)
        return "%012d".format(java.lang.Long.remainderUnsigned(value, 1_000_000_000_000L))
    }

    private fun encodedPayload(payload: TicketPayload): Pair<String, String> {
        val json = payload.toJson().toString().toByteArray(Charsets.UTF_8)
        val compressed = deflate(json)
        val envelope = if (compressed != null && compressed.size < json.size) {
            byteArrayOf(COMPRESSED_MARKER) + compressed
        } else {
            byteArrayOf(PLAIN_MARKER) + json
        }
        return base64URLEncode(envelope) to checksumValue(envelope)
    }

    private fun decodedPayloadData(envelope: ByteArray): ByteArray? {
        val marker = envelope.firstOrNull() ?: return null
        val body = envelope.copyOfRange(1, envelope.size)
        return when (marker) {
            COMPRESSED_MARKER -> inflate(body)
            PLAIN_MARKER -> body
            // Tickets generated before compact transport was introduced stored raw JSON.
            else -> envelope
        }
    }

    private fun deflate(data: ByteArray): ByteArray? {
        if (data.isEmpty()) return null
        val deflater = Deflater(Deflater.DEFAULT_COMPRESSION, true)
        return try {
            deflater.setInput(data)
            deflater.finish()
            val output = ByteArray(data.size * 2 + 64)
            var total = 0
            while (!deflater.finished() && total < output.size) {
                val written = deflater.deflate(output, total, output.size - total)
                if (written == 0) break
                total += written
            }
            if (!deflater.finished() || total == 0) null else output.copyOf(total)
        } catch (_: Throwable) {
            null
        } finally {
            deflater.end()
        }
    }

    private fun inflate(data: ByteArray): ByteArray? {
        if (data.isEmpty()) return null
        // Apple emits header-less DEFLATE; still accept a zlib wrapper so tickets produced by other
        // tooling remain readable.
        return rawInflate(data, nowrap = true) ?: rawInflate(data, nowrap = false)
    }

    private fun rawInflate(data: ByteArray, nowrap: Boolean): ByteArray? {
        val inflater = Inflater(nowrap)
        return try {
            inflater.setInput(data)
            val builder = java.io.ByteArrayOutputStream(data.size * 4)
            val chunk = ByteArray(4_096)
            while (!inflater.finished()) {
                val written = inflater.inflate(chunk)
                if (written == 0) {
                    if (inflater.needsInput() || inflater.needsDictionary()) break
                } else {
                    builder.write(chunk, 0, written)
                }
                if (builder.size() > 64 * 1_024) break
            }
            builder.toByteArray().takeIf { it.isNotEmpty() && inflater.finished() }
        } catch (_: Throwable) {
            null
        } finally {
            inflater.end()
        }
    }

    private fun checksumValue(data: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(data)
        return digest.take(8).joinToString("") { "%02x".format(it) }
    }

    private const val BASE64_URL_ALPHABET =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    internal fun base64URLEncode(data: ByteArray): String {
        val builder = StringBuilder((data.size + 2) / 3 * 4)
        var index = 0
        while (index < data.size) {
            val remaining = data.size - index
            val b0 = data[index].toInt() and 0xFF
            val b1 = if (remaining > 1) data[index + 1].toInt() and 0xFF else 0
            val b2 = if (remaining > 2) data[index + 2].toInt() and 0xFF else 0
            builder.append(BASE64_URL_ALPHABET[b0 ushr 2])
            builder.append(BASE64_URL_ALPHABET[((b0 and 0x03) shl 4) or (b1 ushr 4)])
            if (remaining > 1) builder.append(BASE64_URL_ALPHABET[((b1 and 0x0F) shl 2) or (b2 ushr 6)])
            if (remaining > 2) builder.append(BASE64_URL_ALPHABET[b2 and 0x3F])
            index += 3
        }
        return builder.toString()
    }

    internal fun base64URLDecode(value: String): ByteArray? {
        val output = java.io.ByteArrayOutputStream(value.length * 3 / 4 + 3)
        var buffer = 0
        var bits = 0
        for (character in value) {
            if (character == '=') continue
            val digit = BASE64_URL_ALPHABET.indexOf(
                when (character) {
                    '+' -> '-'
                    '/' -> '_'
                    else -> character
                }
            )
            if (digit < 0) return null
            buffer = (buffer shl 6) or digit
            bits += 6
            if (bits >= 8) {
                bits -= 8
                output.write((buffer ushr bits) and 0xFF)
            }
        }
        return output.toByteArray().takeIf { it.isNotEmpty() }
    }
}
