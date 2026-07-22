package cn.locallens.lingdongzhaopian

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.ColorSpace
import android.graphics.HardwareBufferRenderer
import android.graphics.PorterDuff
import android.graphics.RenderNode
import android.hardware.HardwareBuffer
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.view.View
import androidx.compose.ui.geometry.Rect
import androidx.exifinterface.media.ExifInterface
import androidx.heifwriter.HeifWriter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asExecutor
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.Duration
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class ExportedArtwork(val file: File, val bytes: ByteArray, val fileName: String, val mime: String)

object ExportManager {
    suspend fun captureAndEncode(context: Context, view: View, bounds: Rect, state: AppUiState): ExportedArtwork {
        require(bounds.width > 0f && bounds.height > 0f) { "作品画布尺寸无效" }
        val dimensions = exportDimensions(
            state.preferences.exportResolution,
            state.photos.firstOrNull()?.sourceWidth ?: 1080,
            bounds.width / bounds.height,
        )
        val rendered = renderArtwork(view, bounds, dimensions)
        return withContext(Dispatchers.IO) { encode(context, rendered, state) }.also { rendered.recycle() }
    }

    /**
     * Redraws Compose directly into the requested target bitmap. Text, vector shapes and source photos
     * are rasterized at output resolution; this intentionally does not upscale a screen capture.
     */
    suspend fun renderArtwork(view: View, bounds: Rect, dimensions: ExportDimensions): Bitmap =
        withContext(Dispatchers.Main.immediate) {
            require(dimensions.width > 0 && dimensions.height > 0)
            require(bounds.width > 0f && bounds.height > 0f)
            renderArtworkWithGpu(view, bounds, dimensions)
        }

    /**
     * Compose runtime shaders and RenderEffects are skipped when a View is redrawn into a software
     * Bitmap Canvas. Record the same View tree into a RenderNode and render it to a GPU buffer so
     * exported palette glass uses the exact AGSL path shown in the editor.
     */
    private suspend fun renderArtworkWithGpu(view: View, bounds: Rect, dimensions: ExportDimensions): Bitmap {
        val usage = HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE or HardwareBuffer.USAGE_GPU_COLOR_OUTPUT
        check(HardwareBuffer.isSupported(dimensions.width, dimensions.height, HardwareBuffer.RGBA_8888, 1, usage)) {
            "设备不支持所选导出尺寸的 GPU 画布"
        }
        val buffer = HardwareBuffer.create(
            dimensions.width,
            dimensions.height,
            HardwareBuffer.RGBA_8888,
            1,
            usage,
        )
        val renderNode = RenderNode("lingdong-artwork-export").apply {
            setPosition(0, 0, dimensions.width, dimensions.height)
            setClipToBounds(true)
        }
        val canvas = renderNode.beginRecording(dimensions.width, dimensions.height)
        try {
            canvas.drawColor(android.graphics.Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            canvas.clipRect(0, 0, dimensions.width, dimensions.height)
            canvas.scale(dimensions.width / bounds.width, dimensions.height / bounds.height)
            canvas.translate(-bounds.left, -bounds.top)
            view.draw(canvas)
        } catch (error: Throwable) {
            buffer.close()
            throw error
        } finally {
            renderNode.endRecording()
        }

        return suspendCancellableCoroutine { continuation ->
            val renderer = HardwareBufferRenderer(buffer).apply { setContentRoot(renderNode) }
            continuation.invokeOnCancellation {
                renderer.close()
                buffer.close()
                renderNode.discardDisplayList()
            }
            try {
                renderer.obtainRenderRequest()
                    .setColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
                    // Never run this callback inline on Android's shared render thread: waiting
                    // on its fence there deadlocks the GPU completion that signals the same fence.
                    .draw(Dispatchers.IO.asExecutor()) { result ->
                        try {
                            check(result.status == HardwareBufferRenderer.RenderResult.SUCCESS) {
                                "GPU 导出失败（状态 ${result.status}）"
                            }
                            result.fence.use { fence ->
                                check(fence.await(Duration.ofSeconds(8))) { "GPU 导出等待超时" }
                            }
                            val hardwareBitmap = Bitmap.wrapHardwareBuffer(
                                buffer,
                                ColorSpace.get(ColorSpace.Named.SRGB),
                            ) ?: error("无法读取 GPU 导出画布")
                            val softwareBitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
                                ?: error("无法生成导出图片")
                            if (continuation.isActive) continuation.resume(softwareBitmap) else softwareBitmap.recycle()
                        } catch (error: Throwable) {
                            if (continuation.isActive) continuation.resumeWithException(error)
                        } finally {
                            renderer.close()
                            buffer.close()
                            renderNode.discardDisplayList()
                        }
                    }
            } catch (error: Throwable) {
                renderer.close()
                buffer.close()
                renderNode.discardDisplayList()
                if (continuation.isActive) continuation.resumeWithException(error)
            }
        }
    }

    suspend fun renderArtwork(view: View, bounds: Rect, width: Int): Bitmap = renderArtwork(
        view,
        bounds,
        ExportDimensions(width, (width / (bounds.width / bounds.height)).toInt().coerceAtLeast(1)),
    )

    internal fun encode(context: Context, bitmap: Bitmap, state: AppUiState): ExportedArtwork {
        val format = state.preferences.exportFormat
        val timestamp = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneId.systemDefault()).format(Instant.now())
        val fileName = "灵动照片-$timestamp.${format.extension}"
        val file = File(context.cacheDir, fileName)
        when (format) {
            ExportFormat.Jpeg -> FileOutputStream(file).use { check(bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)) }
            ExportFormat.Png -> FileOutputStream(file).use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            ExportFormat.Heic -> {
                val exifBlock = makeExifBlock(context, state.photos.firstOrNull()?.metadata, state.preferences.metadataPolicy)
                val writer = HeifWriter.Builder(file.absolutePath, bitmap.width, bitmap.height, HeifWriter.INPUT_MODE_BITMAP)
                    .setQuality(95).setMaxImages(1).build()
                writer.start()
                writer.addBitmap(bitmap)
                exifBlock?.let { writer.addExifData(0, it, 0, it.size) }
                // stop() finalizes the HEIF muxer and releases the writer's resources.
                writer.stop(8_000_000)
            }
        }
        if (format != ExportFormat.Heic) {
            applyMetadata(file, state.photos.firstOrNull()?.metadata, state.preferences.metadataPolicy)
        }
        return ExportedArtwork(file, file.readBytes(), fileName, format.mime)
    }

    /** HeifWriter expects an APP1 payload beginning with `Exif\0\0`, not an entire JPEG segment. */
    private fun makeExifBlock(context: Context, metadata: PhotoMetadata?, policy: MetadataPolicy): ByteArray? {
        if (metadata == null || policy == MetadataPolicy.RemoveAll) return null
        val file = File(context.cacheDir, "exif-template-${System.nanoTime()}.jpg")
        return runCatching {
            val pixel = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            FileOutputStream(file).use { check(pixel.compress(Bitmap.CompressFormat.JPEG, 90, it)) }
            pixel.recycle()
            applyMetadata(file, metadata, policy)
            extractExifBlock(file.readBytes())
        }.getOrNull().also { file.delete() }
    }

    internal fun extractExifBlock(jpeg: ByteArray): ByteArray? {
        if (jpeg.size < 4 || jpeg[0] != 0xff.toByte() || jpeg[1] != 0xd8.toByte()) return null
        var offset = 2
        while (offset + 4 <= jpeg.size && jpeg[offset] == 0xff.toByte()) {
            val marker = jpeg[offset + 1].toInt() and 0xff
            if (marker == 0xd9 || marker == 0xda) return null
            val segmentLength = ((jpeg[offset + 2].toInt() and 0xff) shl 8) or (jpeg[offset + 3].toInt() and 0xff)
            if (segmentLength < 2 || offset + 2 + segmentLength > jpeg.size) return null
            val payloadStart = offset + 4
            val payloadLength = segmentLength - 2
            if (marker == 0xe1 && payloadLength >= 6 &&
                jpeg.copyOfRange(payloadStart, payloadStart + 6).contentEquals(byteArrayOf('E'.code.toByte(), 'x'.code.toByte(), 'i'.code.toByte(), 'f'.code.toByte(), 0, 0))
            ) {
                return jpeg.copyOfRange(payloadStart, payloadStart + payloadLength)
            }
            offset += 2 + segmentLength
        }
        return null
    }

    private fun applyMetadata(file: File, metadata: PhotoMetadata?, policy: MetadataPolicy) {
        if (metadata == null || policy == MetadataPolicy.RemoveAll) return
        runCatching {
            val exif = ExifInterface(file)
            metadata.make?.let { exif.setAttribute(ExifInterface.TAG_MAKE, it) }
            metadata.model?.let { exif.setAttribute(ExifInterface.TAG_MODEL, it) }
            metadata.lensModel?.let { exif.setAttribute(ExifInterface.TAG_LENS_MODEL, it) }
            metadata.captureTimeMillis?.let {
                val formatted = DateTimeFormatter.ofPattern("yyyy:MM:dd HH:mm:ss").withZone(ZoneId.systemDefault()).format(Instant.ofEpochMilli(it))
                exif.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, formatted)
            }
            metadata.aperture?.let { exif.setAttribute(ExifInterface.TAG_F_NUMBER, it.toString()) }
            metadata.exposureTime?.let { exif.setAttribute(ExifInterface.TAG_EXPOSURE_TIME, it.toString()) }
            metadata.iso?.let { exif.setAttribute(ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY, it.toString()) }
            metadata.focalLength?.let { exif.setAttribute(ExifInterface.TAG_FOCAL_LENGTH, "${(it * 1000).toInt()}/1000") }
            if (policy == MetadataPolicy.Preserve && metadata.latitude != null && metadata.longitude != null) exif.setLatLong(metadata.latitude, metadata.longitude)
            exif.saveAttributes()
        }
    }

    fun saveToPhotoLibrary(context: Context, exported: ExportedArtwork): Boolean {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, exported.fileName)
            put(MediaStore.Images.Media.MIME_TYPE, exported.mime)
            put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/灵动照片")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return false
        return runCatching {
            context.contentResolver.openOutputStream(uri)?.use { it.write(exported.bytes) } ?: error("无法写入")
            values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
            true
        }.getOrElse {
            context.contentResolver.delete(uri, null, null)
            false
        }
    }

    fun writeToUri(context: Context, destination: Uri, exported: ExportedArtwork): Boolean = runCatching {
        context.contentResolver.openOutputStream(destination, "w")?.use { it.write(exported.bytes) }
            ?: error("无法写入目标文件")
        true
    }.getOrDefault(false)
}
