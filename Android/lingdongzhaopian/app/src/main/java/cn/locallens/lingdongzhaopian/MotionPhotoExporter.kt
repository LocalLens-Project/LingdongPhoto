package cn.locallens.lingdongzhaopian

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.view.View
import androidx.compose.ui.geometry.Rect
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.coroutines.resume
import kotlin.math.roundToInt

object MotionPhotoExporter {
    private const val frameRate = 12
    private const val maxDurationUs = 3_000_000L

    suspend fun captureAndEncode(
        context: Context,
        view: View,
        bounds: Rect,
        state: AppUiState,
        setFrames: (Map<Int, Bitmap>) -> Unit,
        clearFrames: () -> Unit,
        onProgress: (Float) -> Unit = {},
    ): ExportedArtwork {
        require(state.mode != CreationMode.PrivacyMosaic)
        val sourceFiles = state.photos.mapIndexedNotNull { index, photo ->
            photo.motionVideoFile?.takeIf(File::isFile)?.let { index to it }
        }
        require(sourceFiles.isNotEmpty()) { "未找到 Motion Photo 动态片段" }
        require(bounds.width > 0 && bounds.height > 0)

        val stillDimensions = exportDimensions(
            state.preferences.exportResolution,
            state.photos.firstOrNull()?.sourceWidth ?: 1080,
            bounds.width / bounds.height,
        )
        val still = ExportManager.renderArtwork(view, bounds, stillDimensions)
        val jpegState = state.copy(preferences = state.preferences.copy(exportFormat = ExportFormat.Jpeg))
        val encodedStill = withContext(Dispatchers.IO) { ExportManager.encode(context, still, jpegState) }
        still.recycle()

        val sources = withContext(Dispatchers.IO) {
            sourceFiles.mapNotNull { (index, file) -> runCatching { index to MotionFrameSource(file) }.getOrNull() }
        }
        require(sources.isNotEmpty()) { "无法解码 Motion Photo 动态片段" }
        val durationUs = sources.maxOf { it.second.durationUs }.coerceAtMost(maxDurationUs)
        val frameCount = ((durationUs * frameRate + 999_999L) / 1_000_000L).toInt().coerceAtLeast(2)
        val videoWidth = stillDimensions.width.coerceAtMost(1080).coerceAtLeast(360).andEven()
        val videoHeight = (videoWidth / (bounds.width / bounds.height)).roundToInt().coerceAtLeast(2).andEven()
        val videoFile = File(context.cacheDir, "lingdong-motion-${System.nanoTime()}.mp4")
        var retainedFrames: Collection<Bitmap> = emptyList()

        try {
            AvcBitmapEncoder(videoFile, videoWidth, videoHeight, frameRate).use { encoder ->
                repeat(frameCount) { frameIndex ->
                    val timeUs = frameIndex * 1_000_000L / frameRate
                    val frames = withContext(Dispatchers.IO) {
                        sources.mapNotNull { (index, source) ->
                            source.frameAt(timeUs.coerceAtMost(source.durationUs - 1), maxEdge = 1800)?.let { index to it }
                        }.toMap()
                    }
                    setFrames(frames)
                    awaitRedraw(view)
                    retainedFrames.forEach { if (!it.isRecycled) it.recycle() }
                    val rendered = ExportManager.renderArtwork(view, bounds, ExportDimensions(videoWidth, videoHeight))
                    encoder.writeFrame(rendered, frameIndex * 1_000_000L / frameRate)
                    rendered.recycle()
                    retainedFrames = frames.values
                    onProgress((frameIndex + 1f) / frameCount)
                }
                encoder.finish()
            }
        } finally {
            clearFrames()
            awaitRedraw(view)
            retainedFrames.forEach { if (!it.isRecycled) it.recycle() }
            sources.forEach { (_, source) -> source.close() }
        }

        val containerVideo = withContext(Dispatchers.IO) {
            remuxWithSourceAudio(videoFile, sourceFiles.first().second, durationUs, context.cacheDir)
        }
        val combined = withContext(Dispatchers.IO) {
            MotionPhotoContainer.embed(encodedStill.bytes, containerVideo.readBytes(), presentationTimestampUs = durationUs / 2)
        }
        if (containerVideo != videoFile) containerVideo.delete()
        videoFile.delete()
        encodedStill.file.delete()
        val timestamp = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneId.systemDefault()).format(Instant.now())
        val fileName = "灵动照片-$timestamp-Motion.jpg"
        val file = File(context.cacheDir, fileName).apply { writeBytes(combined) }
        return ExportedArtwork(file, combined, fileName, "image/jpeg")
    }

    private suspend fun awaitRedraw(view: View) = suspendCancellableCoroutine { continuation ->
        view.postOnAnimation {
            view.postOnAnimation {
                if (continuation.isActive) continuation.resume(Unit)
            }
        }
    }

    private fun Int.andEven(): Int = if (this % 2 == 0) this else this - 1

    internal fun remuxWithSourceAudio(video: File, source: File, durationUs: Long, cacheDir: File): File {
        val audioProbe = MediaExtractor()
        val audioTrack = try {
            audioProbe.setDataSource(source.absolutePath)
            (0 until audioProbe.trackCount).firstOrNull {
                audioProbe.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return video
        } catch (_: Throwable) {
            return video
        } finally {
            audioProbe.release()
        }

        val remuxed = File(cacheDir, "lingdong-motion-audio-${System.nanoTime()}.mp4")
        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        return try {
            videoExtractor.setDataSource(video.absolutePath)
            audioExtractor.setDataSource(source.absolutePath)
            val videoTrack = (0 until videoExtractor.trackCount).first {
                videoExtractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
            }
            videoExtractor.selectTrack(videoTrack)
            audioExtractor.selectTrack(audioTrack)
            muxer = MediaMuxer(remuxed.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val outputVideoTrack = muxer.addTrack(videoExtractor.getTrackFormat(videoTrack))
            val outputAudioTrack = muxer.addTrack(audioExtractor.getTrackFormat(audioTrack))
            muxer.start()
            copyTrack(videoExtractor, muxer, outputVideoTrack, durationUs)
            copyTrack(audioExtractor, muxer, outputAudioTrack, durationUs)
            muxer.stop()
            muxer.release()
            muxer = null
            remuxed
        } catch (_: Throwable) {
            runCatching { muxer?.stop() }
            muxer?.release()
            remuxed.delete()
            video
        } finally {
            videoExtractor.release()
            audioExtractor.release()
        }
    }

    private fun copyTrack(extractor: MediaExtractor, muxer: MediaMuxer, outputTrack: Int, durationUs: Long) {
        val buffer = ByteBuffer.allocate(4 * 1024 * 1024)
        val info = MediaCodec.BufferInfo()
        var firstPresentationTimeUs = -1L
        while (true) {
            buffer.clear()
            val size = extractor.readSampleData(buffer, 0)
            if (size < 0) break
            val sampleTime = extractor.sampleTime
            if (firstPresentationTimeUs < 0) firstPresentationTimeUs = sampleTime.coerceAtLeast(0)
            val normalizedTime = (sampleTime - firstPresentationTimeUs).coerceAtLeast(0)
            if (normalizedTime > durationUs) break
            var codecFlags = 0
            if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) {
                codecFlags = codecFlags or MediaCodec.BUFFER_FLAG_KEY_FRAME
            }
            if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME != 0) {
                codecFlags = codecFlags or MediaCodec.BUFFER_FLAG_PARTIAL_FRAME
            }
            info.set(0, size, normalizedTime, codecFlags)
            muxer.writeSampleData(outputTrack, buffer, info)
            if (!extractor.advance()) break
        }
    }
}

@Suppress("DEPRECATION")
internal class AvcBitmapEncoder(
    private val output: File,
    private val width: Int,
    private val height: Int,
    private val frameRate: Int,
) : AutoCloseable {
    private val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private val colorFormat: Int
    private val muxer: MediaMuxer
    private val bufferInfo = MediaCodec.BufferInfo()
    private var trackIndex = -1
    private var muxerStarted = false
    private var finished = false

    init {
        val capabilities = codec.codecInfo.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
        colorFormat = when {
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar in capabilities.colorFormats ->
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar in capabilities.colorFormats ->
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
            else -> MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
        }
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
            setInteger(MediaFormat.KEY_BIT_RATE, (width * height * 4).coerceAtLeast(2_000_000))
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    suspend fun writeFrame(bitmap: Bitmap, presentationTimeUs: Long) {
        val yuv = withContext(Dispatchers.Default) { bitmapToYuv420(bitmap, width, height, colorFormat) }
        var inputIndex: Int
        do {
            inputIndex = codec.dequeueInputBuffer(10_000)
            if (inputIndex < 0) {
                drain(endOfStream = false)
                delay(1)
            }
        } while (inputIndex < 0)
        codec.getInputBuffer(inputIndex)!!.apply { clear(); put(yuv) }
        codec.queueInputBuffer(inputIndex, 0, yuv.size, presentationTimeUs, 0)
        drain(endOfStream = false)
    }

    fun finish() {
        if (finished) return
        var inputIndex: Int
        do {
            inputIndex = codec.dequeueInputBuffer(10_000)
            if (inputIndex < 0) drain(endOfStream = false)
        } while (inputIndex < 0)
        codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(endOfStream = true)
        finished = true
    }

    private fun drain(endOfStream: Boolean) {
        var idle = 0
        while (true) {
            val outputIndex = codec.dequeueOutputBuffer(bufferInfo, if (endOfStream) 20_000 else 0)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream || idle++ > 100) return
                }
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    check(!muxerStarted)
                    trackIndex = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                outputIndex >= 0 -> {
                    val buffer = codec.getOutputBuffer(outputIndex) ?: error("无法读取编码缓冲区")
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) bufferInfo.size = 0
                    if (bufferInfo.size > 0) {
                        check(muxerStarted)
                        buffer.position(bufferInfo.offset)
                        buffer.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(trackIndex, buffer, bufferInfo)
                    }
                    val eos = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    codec.releaseOutputBuffer(outputIndex, false)
                    if (eos) return
                }
            }
        }
    }

    override fun close() {
        runCatching { if (!finished) finish() }
        runCatching { codec.stop() }
        codec.release()
        if (muxerStarted) runCatching { muxer.stop() }
        muxer.release()
    }
}

@Suppress("DEPRECATION")
private fun bitmapToYuv420(bitmap: Bitmap, width: Int, height: Int, colorFormat: Int): ByteArray {
    val scaled = if (bitmap.width == width && bitmap.height == height) bitmap else Bitmap.createScaledBitmap(bitmap, width, height, true)
    val pixels = IntArray(width * height)
    scaled.getPixels(pixels, 0, width, 0, 0, width, height)
    if (scaled !== bitmap) scaled.recycle()
    val frameSize = width * height
    val output = ByteArray(frameSize * 3 / 2)
    var yIndex = 0
    var uIndex = frameSize
    var vIndex = frameSize + frameSize / 4
    var uvIndex = frameSize
    val semiPlanar = colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
    for (y in 0 until height) {
        for (x in 0 until width) {
            val color = pixels[y * width + x]
            val red = color shr 16 and 0xff
            val green = color shr 8 and 0xff
            val blue = color and 0xff
            output[yIndex++] = (((77 * red + 150 * green + 29 * blue) shr 8).coerceIn(0, 255)).toByte()
            if (y % 2 == 0 && x % 2 == 0) {
                val u = (((-43 * red - 85 * green + 128 * blue) shr 8) + 128).coerceIn(0, 255).toByte()
                val v = (((128 * red - 107 * green - 21 * blue) shr 8) + 128).coerceIn(0, 255).toByte()
                if (semiPlanar) {
                    output[uvIndex++] = u
                    output[uvIndex++] = v
                } else {
                    output[uIndex++] = u
                    output[vIndex++] = v
                }
            }
        }
    }
    return output
}
