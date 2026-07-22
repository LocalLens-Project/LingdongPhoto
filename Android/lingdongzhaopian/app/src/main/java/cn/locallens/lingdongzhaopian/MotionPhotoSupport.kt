package cn.locallens.lingdongzhaopian

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.Closeable
import java.io.File
import java.nio.charset.StandardCharsets
import java.util.UUID
import kotlin.math.max
import kotlin.math.roundToInt

data class MotionPhotoRange(val start: Int, val length: Int)

/** Parser and writer for the JPEG + appended MP4 Motion Photo container used by Android galleries. */
object MotionPhotoContainer {
    private val offsetPattern = Regex("(?:MicroVideoOffset|MotionPhotoOffset)=\\\"(\\d+)\\\"")
    private val itemPattern = Regex(
        "Item:Mime=\\\"video/mp4\\\"[^>]*Item:Semantic=\\\"MotionPhoto\\\"[^>]*Item:Length=\\\"(\\d+)\\\"|" +
            "Item:Semantic=\\\"MotionPhoto\\\"[^>]*Item:Mime=\\\"video/mp4\\\"[^>]*Item:Length=\\\"(\\d+)\\\"",
    )

    fun videoRange(bytes: ByteArray): MotionPhotoRange? {
        if (bytes.size < 16) return null
        val searchable = bytes.toString(StandardCharsets.ISO_8859_1)
        val declaredLength = offsetPattern.find(searchable)?.groupValues?.getOrNull(1)?.toIntOrNull()
            ?: itemPattern.find(searchable)?.groupValues?.drop(1)?.firstNotNullOfOrNull(String::toIntOrNull)
        if (declaredLength != null && declaredLength in 12 until bytes.size) {
            val declaredStart = bytes.size - declaredLength
            findFtypBoxStart(bytes, declaredStart, minOf(bytes.size, declaredStart + 64))?.let {
                return MotionPhotoRange(it, bytes.size - it)
            }
        }

        val markedMotionPhoto = searchable.contains("MotionPhoto=\"1\"") ||
            searchable.contains("MicroVideo=\"1\"") || searchable.contains("Semantic=\"MotionPhoto\"")
        if (!markedMotionPhoto) return null
        return findFtypBoxStart(bytes, 2, bytes.size)?.let { MotionPhotoRange(it, bytes.size - it) }
    }

    fun videoBytes(bytes: ByteArray): ByteArray? = videoRange(bytes)?.let { range ->
        bytes.copyOfRange(range.start, range.start + range.length)
    }

    fun embed(jpeg: ByteArray, mp4: ByteArray, presentationTimestampUs: Long = 0): ByteArray {
        require(jpeg.size >= 2 && jpeg[0] == 0xff.toByte() && jpeg[1] == 0xd8.toByte()) { "JPEG 数据无效" }
        require(mp4.size >= 12 && findFtypBoxStart(mp4, 0, minOf(mp4.size, 64)) != null) { "MP4 数据无效" }
        val xmp = xmpPacket(mp4.size, presentationTimestampUs)
        val namespace = "http://ns.adobe.com/xap/1.0/\u0000".toByteArray(StandardCharsets.UTF_8)
        val payload = namespace + xmp.toByteArray(StandardCharsets.UTF_8)
        require(payload.size + 2 <= 0xffff) { "Motion Photo XMP 过大" }
        val segmentLength = payload.size + 2
        val app1 = byteArrayOf(
            0xff.toByte(), 0xe1.toByte(),
            (segmentLength ushr 8).toByte(), segmentLength.toByte(),
        ) + payload
        return ByteArray(jpeg.size + app1.size + mp4.size).also { output ->
            jpeg.copyInto(output, 0, 0, 2)
            app1.copyInto(output, 2)
            jpeg.copyInto(output, 2 + app1.size, 2)
            mp4.copyInto(output, jpeg.size + app1.size)
        }
    }

    private fun xmpPacket(videoLength: Int, presentationTimestampUs: Long): String =
        """<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description rdf:about="" xmlns:GCamera="http://ns.google.com/photos/1.0/camera/" xmlns:Container="http://ns.google.com/photos/1.0/container/" xmlns:Item="http://ns.google.com/photos/1.0/container/item/" GCamera:MotionPhoto="1" GCamera:MotionPhotoVersion="1" GCamera:MotionPhotoPresentationTimestampUs="$presentationTimestampUs" GCamera:MicroVideo="1" GCamera:MicroVideoVersion="1" GCamera:MicroVideoOffset="$videoLength"><Container:Directory><rdf:Seq><rdf:li rdf:parseType="Resource"><Container:Item Item:Mime="image/jpeg" Item:Semantic="Primary" Item:Length="0" Item:Padding="0"/></rdf:li><rdf:li rdf:parseType="Resource"><Container:Item Item:Mime="video/mp4" Item:Semantic="MotionPhoto" Item:Length="$videoLength" Item:Padding="0"/></rdf:li></rdf:Seq></Container:Directory></rdf:Description></rdf:RDF></x:xmpmeta>"""

    private fun findFtypBoxStart(bytes: ByteArray, start: Int, endExclusive: Int): Int? {
        val lower = start.coerceAtLeast(4)
        val upper = (endExclusive - 4).coerceAtMost(bytes.size - 4)
        for (index in upper downTo lower) {
            if (bytes[index] == 'f'.code.toByte() && bytes[index + 1] == 't'.code.toByte() &&
                bytes[index + 2] == 'y'.code.toByte() && bytes[index + 3] == 'p'.code.toByte()
            ) {
                val boxStart = index - 4
                val size = ((bytes[boxStart].toInt() and 0xff) shl 24) or
                    ((bytes[boxStart + 1].toInt() and 0xff) shl 16) or
                    ((bytes[boxStart + 2].toInt() and 0xff) shl 8) or
                    (bytes[boxStart + 3].toInt() and 0xff)
                if (size >= 8 && boxStart + size <= bytes.size) return boxStart
            }
        }
        return null
    }
}

object MotionPhotoExtractor {
    suspend fun extract(context: Context, uri: Uri): File? = withContext(Dispatchers.IO) {
        runCatching {
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return@runCatching null
            val video = MotionPhotoContainer.videoBytes(bytes) ?: return@runCatching null
            File(context.cacheDir, "motion-source-${UUID.randomUUID()}.mp4").apply { writeBytes(video) }
        }.getOrNull()
    }
}

class MotionFrameSource(file: File) : Closeable {
    private val retriever = MediaMetadataRetriever().apply { setDataSource(file.absolutePath) }
    val durationUs: Long = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
        ?.toLongOrNull()?.times(1_000L)?.coerceAtLeast(1L) ?: 3_000_000L

    fun frameAt(timeUs: Long, maxEdge: Int = 1400): Bitmap? {
        val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
        val scale = if (max(width, height) > maxEdge && width > 0 && height > 0) maxEdge.toFloat() / max(width, height) else 1f
        val targetWidth = (width * scale).roundToInt().coerceAtLeast(1)
        val targetHeight = (height * scale).roundToInt().coerceAtLeast(1)
        return if (width > 0 && height > 0) {
            retriever.getScaledFrameAtTime(timeUs.coerceIn(0, durationUs - 1), MediaMetadataRetriever.OPTION_CLOSEST, targetWidth, targetHeight)
        } else {
            retriever.getFrameAtTime(timeUs.coerceIn(0, durationUs - 1), MediaMetadataRetriever.OPTION_CLOSEST)
        }
    }

    override fun close() = retriever.release()
}
