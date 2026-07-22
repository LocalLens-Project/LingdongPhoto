package cn.locallens.lingdongzhaopian

import android.content.Intent
import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.media.MediaMetadataRetriever
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.view.ViewGroup
import android.app.Application
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.size
import androidx.compose.ui.unit.dp
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.click
import androidx.compose.ui.test.swipe
import androidx.compose.ui.Modifier
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.core.app.ApplicationProvider
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.io.FileOutputStream

@RunWith(AndroidJUnit4::class)
class AppInstrumentedTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Before
    fun dismissNotice() {
        val nodes = composeRule.onAllNodesWithText("我知道了").fetchSemanticsNodes()
        if (nodes.isNotEmpty()) composeRule.onNodeWithText("我知道了").performClick()
    }

    @Test
    fun introOpensWithPhotoPickerAction() {
        composeRule.onNodeWithContentDescription("为灵动卡片选择照片").assertIsDisplayed()
    }

    @Test
    fun sharedImageRendersEveryCreationMode() {
        shareImage(createTestJpeg("all-modes.jpg"))
        waitForEditor()
        CreationMode.entries.forEach { mode ->
            composeRule.onNodeWithContentDescription("设置").performClick()
            composeRule.waitUntil(5_000) { composeRule.onAllNodesWithText(mode.title).fetchSemanticsNodes().isNotEmpty() }
            composeRule.onNodeWithText(mode.title).performClick()
            composeRule.waitForIdle()
            composeRule.onNodeWithTag("artwork-${mode.name}").assertIsDisplayed()
        }
    }

    @Test
    fun paletteExtractionReturnsSixColorsAndOneHundredPercent() {
        val colors = intArrayOf(
            0xff829531.toInt(), 0xff637322.toInt(), 0xff425119.toInt(),
            0xffa7bc4e.toInt(), 0xff27310f.toInt(), 0xffb76a40.toInt(),
        )
        val pixels = IntArray(96 * 96) { index -> colors[(index % 96) / 16] }
        val bitmap = Bitmap.createBitmap(pixels, 96, 96, Bitmap.Config.ARGB_8888)
        val result = PaletteExtractor.extract(bitmap)
        assertEquals(6, result.colors.size)
        assertEquals(6, result.percentages.size)
        assertTrue(kotlin.math.abs(result.percentages.sum() - 100.0) < .01)
        bitmap.recycle()
    }

    @Test
    fun paletteExtractionDoesNotInventMissingColors() {
        val colors = intArrayOf(
            0xffba6549.toInt(),
            0xff405a74.toInt(),
            0xffd4b45a.toInt(),
            0xff426c51.toInt(),
        )
        val pixels = IntArray(96 * 96) { index -> colors[(index % 96) / 24] }
        val bitmap = Bitmap.createBitmap(pixels, 96, 96, Bitmap.Config.ARGB_8888)
        val result = PaletteExtractor.extract(bitmap)
        assertEquals(4, result.colors.size)
        assertEquals(4, result.percentages.size)
        assertTrue(kotlin.math.abs(result.percentages.sum() - 100.0) < .01)
        bitmap.recycle()
    }

    @Test
    fun compactPaletteShowsEveryHexAndPercentage() {
        val bitmap = Bitmap.createBitmap(512, 768, Bitmap.Config.ARGB_8888).apply {
            eraseColor(Color.rgb(88, 110, 142))
        }
        val percentages = listOf(41.7, 29.9, 11.4, 6.3, 5.7, 5.0)
        val state = AppUiState(
            mode = CreationMode.ColorPalette,
            photos = listOf(SelectedPhoto(Uri.EMPTY, bitmap)),
            palette = RGBColor.fallback,
            palettePercentages = percentages,
            preferences = AppPreferences(
                paletteLayout = PaletteLayoutMode.Compact,
                showHexValues = true,
                showPalettePercentages = true,
            ),
        )
        composeRule.activityRule.scenario.onActivity { activity ->
            activity.setContent {
                ArtworkCanvas(state, Modifier.size(360.dp, 480.dp))
            }
        }
        composeRule.waitForIdle()
        RGBColor.fallback.forEach { composeRule.onNodeWithText(it.hex).assertIsDisplayed() }
        percentages.forEach { composeRule.onNodeWithText("%.1f%%".format(it)).assertIsDisplayed() }
    }

    @Test
    fun jpegPngAndHeicEncodersProduceDecodableFiles() {
        val bitmap = Bitmap.createBitmap(320, 480, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.rgb(72, 116, 84)) }
        val photo = SelectedPhoto(Uri.EMPTY, bitmap, sourceWidth = 320, sourceHeight = 480)
        ExportFormat.entries.forEach { format ->
            val state = AppUiState(
                photos = listOf(photo),
                preferences = AppPreferences(exportFormat = format, metadataPolicy = MetadataPolicy.RemoveAll),
            )
            val exported = ExportManager.encode(composeRule.activity, bitmap, state)
            assertEquals(format.mime, exported.mime)
            assertTrue(exported.file.length() > 256)
            assertTrue(BitmapFactory.decodeFile(exported.file.absolutePath)?.let { decoded ->
                val valid = decoded.width == 320 && decoded.height == 480
                decoded.recycle()
                valid
            } == true)
            exported.file.delete()
        }
        bitmap.recycle()
    }

    @Test
    fun metadataPoliciesAreAppliedForEveryExportFormat() {
        val bitmap = Bitmap.createBitmap(320, 480, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.rgb(90, 132, 102)) }
        val metadata = PhotoMetadata(
            make = "LocalLens-Test", model = "Virtual Camera", lensModel = "Test Lens",
            aperture = 2.8, exposureTime = .01, iso = 100, focalLength = 35.0,
            captureTimeMillis = 1_735_689_600_000L, latitude = 31.2304, longitude = 121.4737,
        )
        val photo = SelectedPhoto(Uri.EMPTY, bitmap, metadata = metadata)
        ExportFormat.entries.forEach { format ->
            MetadataPolicy.entries.forEach { policy ->
                val state = AppUiState(
                    photos = listOf(photo),
                    preferences = AppPreferences(exportFormat = format, metadataPolicy = policy),
                )
                val exported = ExportManager.encode(composeRule.activity, bitmap, state)
                val exif = ExifInterface(exported.file)
                if (policy == MetadataPolicy.RemoveAll) {
                    assertTrue(exif.getAttribute(ExifInterface.TAG_MAKE).isNullOrEmpty())
                    assertTrue(exif.latLong == null)
                } else {
                    assertEquals("$format/$policy", "LocalLens-Test", exif.getAttribute(ExifInterface.TAG_MAKE))
                    assertEquals("$format/$policy", "Virtual Camera", exif.getAttribute(ExifInterface.TAG_MODEL))
                    if (policy == MetadataPolicy.Preserve) assertTrue("$format/$policy", exif.latLong != null)
                    else assertTrue("$format/$policy", exif.latLong == null)
                }
                exported.file.delete()
            }
        }
        bitmap.recycle()
    }

    @Test
    fun everyFormatCanSaveToLibraryFileProviderAndDocumentUri() {
        val resolver = composeRule.activity.contentResolver
        val bitmap = Bitmap.createBitmap(240, 320, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.rgb(64, 110, 78)) }
        val photo = SelectedPhoto(Uri.EMPTY, bitmap)
        ExportFormat.entries.forEach { format ->
            val state = AppUiState(photos = listOf(photo), preferences = AppPreferences(exportFormat = format))
            val exported = ExportManager.encode(composeRule.activity, bitmap, state)

            assertTrue(ExportManager.saveToPhotoLibrary(composeRule.activity, exported))
            resolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Images.Media._ID),
                "${MediaStore.Images.Media.DISPLAY_NAME} = ?",
                arrayOf(exported.fileName),
                "${MediaStore.Images.Media.DATE_ADDED} DESC",
            )?.use { cursor ->
                assertTrue(cursor.moveToFirst())
                val uri = Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cursor.getLong(0).toString())
                assertTrue(resolver.openInputStream(uri)?.use { it.readBytes().isNotEmpty() } == true)
                resolver.delete(uri, null, null)
            } ?: throw AssertionError("无法查询相册导出")

            val shareUri = FileProvider.getUriForFile(composeRule.activity, "${composeRule.activity.packageName}.files", exported.file)
            assertEquals(exported.bytes.size, resolver.openInputStream(shareUri)?.use { it.readBytes().size })
            val shareIntent = Intent(Intent.ACTION_SEND).apply { type = exported.mime; putExtra(Intent.EXTRA_STREAM, shareUri) }
            assertTrue(composeRule.activity.packageManager.queryIntentActivities(shareIntent, 0).isNotEmpty())

            val documentUri = resolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, "document-${exported.fileName}")
                    put(MediaStore.Downloads.MIME_TYPE, exported.mime)
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/灵动照片测试")
                },
            ) ?: throw AssertionError("无法创建文档 URI")
            assertTrue(ExportManager.writeToUri(composeRule.activity, documentUri, exported))
            assertEquals(exported.bytes.size, resolver.openInputStream(documentUri)?.use { it.readBytes().size })
            resolver.delete(documentUri, null, null)
            exported.file.delete()
        }
        bitmap.recycle()
    }

    @Test
    fun paletteCanvasRedrawsDirectlyAtTwoKResolution() = runBlocking {
        shareImage(createTestJpeg("high-resolution.jpg"))
        waitForEditor()
        composeRule.onNodeWithContentDescription("设置").performClick()
        composeRule.onNodeWithText(CreationMode.ColorPalette.title).performClick()
        composeRule.waitForIdle()
        val bounds = composeRule.onNodeWithTag("artwork-${CreationMode.ColorPalette.name}").fetchSemanticsNode().boundsInRoot
        val root = composeRule.activity.findViewById<ViewGroup>(android.R.id.content).getChildAt(0)
        val rendered = ExportManager.renderArtwork(root, bounds, ExportDimensions(2160, 2880))
        assertEquals(2160, rendered.width)
        assertEquals(2880, rendered.height)
        val samples = intArrayOf(
            rendered.getPixel(100, 100), rendered.getPixel(1080, 1440), rendered.getPixel(2050, 2700),
        )
        assertTrue(samples.distinct().size > 1)
        rendered.recycle()
    }

    @Test
    fun avcEncoderAndMotionContainerRoundTripOnDevice() {
        runBlocking {
            val mp4 = File(composeRule.activity.cacheDir, "motion-test.mp4")
            AvcBitmapEncoder(mp4, 320, 480, 12).use { encoder ->
                repeat(6) { index ->
                    val bitmap = Bitmap.createBitmap(320, 480, Bitmap.Config.ARGB_8888).apply {
                        eraseColor(if (index % 2 == 0) Color.rgb(88, 142, 96) else Color.rgb(220, 184, 112))
                    }
                    encoder.writeFrame(bitmap, index * 1_000_000L / 12)
                    bitmap.recycle()
                }
                encoder.finish()
            }
            assertTrue(mp4.length() > 1_024)
            val retriever = MediaMetadataRetriever().apply { setDataSource(mp4.absolutePath) }
            assertEquals("320", retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH))
            assertEquals("480", retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT))
            assertTrue(retriever.getFrameAtTime(100_000)?.let { it.recycle(); true } == true)
            retriever.release()

            val jpeg = createTestJpeg("motion-cover.jpg").readBytes()
            val combined = MotionPhotoContainer.embed(jpeg, mp4.readBytes(), 250_000)
            assertEquals(mp4.length().toInt(), MotionPhotoContainer.videoRange(combined)?.length)
            mp4.delete()
        }
    }

    @Test
    fun motionPhotoRemuxPreservesSourceAudioTrack() {
        runBlocking {
            val video = File(composeRule.activity.cacheDir, "audio-remux-video.mp4")
            AvcBitmapEncoder(video, 320, 480, 12).use { encoder ->
                repeat(8) { index ->
                    val bitmap = Bitmap.createBitmap(320, 480, Bitmap.Config.ARGB_8888).apply {
                        eraseColor(Color.rgb(70 + index * 5, 120, 88))
                    }
                    encoder.writeFrame(bitmap, index * 1_000_000L / 12)
                    bitmap.recycle()
                }
                encoder.finish()
            }
            val audio = File(composeRule.activity.cacheDir, "audio-remux-source.mp4")
            createSilentAac(audio)
            val remuxed = MotionPhotoExporter.remuxWithSourceAudio(video, audio, 650_000L, composeRule.activity.cacheDir)
            val extractor = MediaExtractor().apply { setDataSource(remuxed.absolutePath) }
            val mimes = (0 until extractor.trackCount).mapNotNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) }
            assertTrue(mimes.any { it.startsWith("video/") })
            assertTrue(mimes.any { it.startsWith("audio/") })
            extractor.release()
            if (remuxed != video) remuxed.delete()
            video.delete()
            audio.delete()
        }
    }

    @Test
    fun appIsRegisteredAsSingleAndMultipleImageShareTarget() {
        val manager = composeRule.activity.packageManager
        listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE).forEach { action ->
            val matches = manager.queryIntentActivities(
                Intent(action).apply { type = "image/jpeg" },
                android.content.pm.PackageManager.MATCH_DEFAULT_ONLY,
            )
            assertTrue(matches.any { it.activityInfo.packageName == composeRule.activity.packageName })
        }
    }

    @Test
    fun allPreferencesPersistAcrossViewModelRecreation() {
        val application = ApplicationProvider.getApplicationContext<Application>()
        val first = LingdongViewModel(application)
        val original = first.state.value.preferences
        val expected = AppPreferences(
            showAppTitle = false,
            showHexValues = false,
            showPalettePercentages = false,
            showDeviceInfo = false,
            showBubbles = false,
            gentleBackground = false,
            useLiteraryColorNames = true,
            preservePaletteBackground = false,
            applyLiquidGlassOnExport = false,
            showMoodCopy = true,
            supportsMotionPhotos = false,
            paletteLayout = PaletteLayoutMode.Compact,
            templateStyle = ArtworkTemplateStyle.Immersive,
            journalLayout = JournalLayoutMode.Filmstrip,
            exportFormat = ExportFormat.Heic,
            exportResolution = ExportResolution.Original,
            metadataPolicy = MetadataPolicy.RemoveAll,
            exportDestination = ExportDestination.Share,
        )
        try {
            first.setPreferences(expected)
            val recreated = LingdongViewModel(application)
            assertEquals(expected, recreated.state.value.preferences)
        } finally {
            first.setPreferences(original)
        }
    }

    @Test
    fun textEditorAndPrivacyPaintingDetectionWorkThroughUi() {
        val fixture = createTestJpeg("privacy-ui.jpg")
        shareImage(fixture)
        waitForEditor()
        val motionCanvas = composeRule.onNodeWithTag("artwork-${CreationMode.MotionCard.name}")
        val motionBounds = motionCanvas.fetchSemanticsNode().boundsInRoot
        motionCanvas.performTouchInput {
            click(Offset(motionBounds.width * .5f, motionBounds.height * .15f))
        }
        composeRule.waitUntil(5_000) {
            composeRule.onAllNodesWithText("编辑作品文字", useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithText("编辑作品文字", useUnmergedTree = true).assertIsDisplayed()
        composeRule.onNodeWithText("完成").performClick()

        composeRule.onNodeWithContentDescription("设置").performClick()
        composeRule.onNodeWithText(CreationMode.PrivacyMosaic.title).performClick()
        composeRule.onNodeWithText("手动涂抹").performClick()
        val privacyCanvas = composeRule.onNodeWithTag("artwork-${CreationMode.PrivacyMosaic.name}")
        val privacyBounds = privacyCanvas.fetchSemanticsNode().boundsInRoot
        privacyCanvas.performTouchInput {
            swipe(Offset(privacyBounds.width * .25f, privacyBounds.height * .30f), Offset(privacyBounds.width * .72f, privacyBounds.height * .68f), 650)
        }
        composeRule.onNodeWithContentDescription("撤销").performClick()
        composeRule.onNodeWithText("完成涂抹").performClick()
        composeRule.onNodeWithText("智能识别").performClick()
        composeRule.waitUntil(20_000) {
            composeRule.onAllNodesWithText("已识别", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test
    fun multipleSharedImagesOpenJournalWithAllPhotos() {
        val files = List(6) { createTestJpeg("journal-$it.jpg") }
        composeRule.activityRule.scenario.onActivity { activity ->
            val uris = ArrayList(files.map { FileProvider.getUriForFile(activity, "${activity.packageName}.files", it) })
            activity.receiveSharedImages(
                Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                    type = "image/jpeg"
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            )
        }
        waitForEditor()
        composeRule.onNodeWithTag("artwork-${CreationMode.Journal.name}").assertIsDisplayed()
        repeat(5) { composeRule.onNodeWithContentDescription("手帐照片 ${it + 1}").assertIsDisplayed() }
        assertTrue(composeRule.onAllNodesWithContentDescription("手帐照片 6").fetchSemanticsNodes().isEmpty())
        composeRule.onNodeWithText("自动拼贴").performClick()
        composeRule.onNodeWithText("杂志主图").assertIsDisplayed().performClick()
        composeRule.onNodeWithText("杂志主图").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("手帐照片 2").performClick()
        composeRule.onNodeWithContentDescription("照片操作").performClick()
        composeRule.onNodeWithText("恢复构图").assertIsDisplayed().performClick()
        composeRule.onNodeWithContentDescription("照片操作").performClick()
        composeRule.onNodeWithText("删除这张").performClick()
        assertTrue(composeRule.onAllNodesWithContentDescription("手帐照片 5").fetchSemanticsNodes().isEmpty())
    }

    @Test
    fun motionPhotoLoadsPreviewsAndExportsDynamicContainer() {
        val motionSource = createMotionPhoto("motion-source.jpg")
        shareImage(motionSource)
        waitForEditor()
        composeRule.waitUntil(20_000) {
            runCatching { composeRule.onNodeWithContentDescription("播放动态照片").fetchSemanticsNode() }.isSuccess
        }
        composeRule.onNodeWithContentDescription("播放动态照片").performClick()
        composeRule.waitUntil(8_000) {
            runCatching { composeRule.onNodeWithContentDescription("正在播放动态照片").fetchSemanticsNode() }.isSuccess
        }

        val existingIds = motionPhotoIds()
        composeRule.onNodeWithContentDescription("保存照片").performClick()
        composeRule.onNodeWithText("保存到系统相册").performClick()
        var exported: Pair<Uri, ByteArray>? = null
        composeRule.waitUntil(45_000) {
            exported = newestMotionPhoto(existingIds)
            exported != null
        }
        val result = requireNotNull(exported)
        assertTrue(MotionPhotoContainer.videoRange(result.second)?.length ?: 0 > 1_024)
        assertTrue(composeRule.activity.contentResolver.openInputStream(result.first)?.use(BitmapFactory::decodeStream)?.let {
            val valid = it.width == 1080 && it.height == 1440
            it.recycle()
            valid
        } == true)
        composeRule.activity.contentResolver.delete(result.first, null, null)
    }

    @Test
    fun privacyDetectorFindsQrCodeAndSensitiveTextFixtures() = runBlocking {
        val matrix = MultiFormatWriter().encode("https://example.test/privacy", BarcodeFormat.QR_CODE, 512, 512)
        val qrPixels = IntArray(512 * 512) { index -> if (matrix[index % 512, index / 512]) Color.BLACK else Color.WHITE }
        val qr = Bitmap.createBitmap(qrPixels, 512, 512, Bitmap.Config.ARGB_8888)
        val qrMasks = PrivacyDetector.detect(qr)
        assertTrue(qrMasks.any { it.kind == PrivacyMaskKind.QrCode })
        qr.recycle()

        val text = Bitmap.createBitmap(1200, 520, Bitmap.Config.ARGB_8888)
        Canvas(text).apply {
            drawColor(Color.WHITE)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; textSize = 94f }
            drawText("手机号 13812345678", 45f, 175f, paint)
            drawText("京A12345", 45f, 350f, paint)
        }
        val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
        val recognizedText = try { recognizer.process(InputImage.fromBitmap(text, 0)).await().text } finally { recognizer.close() }
        val textMasks = PrivacyDetector.detect(text)
        assertTrue("OCR=$recognizedText masks=$textMasks", textMasks.any { it.kind == PrivacyMaskKind.SensitiveText })
        assertTrue("OCR=$recognizedText masks=$textMasks", textMasks.any { it.kind == PrivacyMaskKind.LicensePlate })
        text.recycle()
    }

    private fun createTestJpeg(name: String): File {
        val bitmap = Bitmap.createBitmap(480, 640, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(480 * 640) { index ->
            val x = index % 480
            val y = index / 480
            Color.rgb(48 + x * 160 / 480, 72 + y * 140 / 640, 64 + (x + y) * 90 / 1120)
        }
        bitmap.setPixels(pixels, 0, 480, 0, 0, 480, 640)
        return File(composeRule.activity.cacheDir, name).also { file ->
            FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 96, it) }
            bitmap.recycle()
        }
    }

    private fun createMotionPhoto(name: String): File = runBlocking {
        val mp4 = File(composeRule.activity.cacheDir, "$name.mp4")
        AvcBitmapEncoder(mp4, 320, 480, 12).use { encoder ->
            repeat(12) { index ->
                val bitmap = Bitmap.createBitmap(320, 480, Bitmap.Config.ARGB_8888).apply {
                    eraseColor(Color.rgb(50 + index * 8, 118 + index * 4, 82 + index * 5))
                }
                encoder.writeFrame(bitmap, index * 1_000_000L / 12)
                bitmap.recycle()
            }
            encoder.finish()
        }
        val combined = MotionPhotoContainer.embed(createTestJpeg("$name-cover.jpg").readBytes(), mp4.readBytes(), 500_000)
        mp4.delete()
        File(composeRule.activity.cacheDir, name).apply { writeBytes(combined) }
    }

    private fun createSilentAac(file: File) {
        val sampleRate = 44_100
        val totalSamples = sampleRate / 2
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 64_000)
        }
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val info = MediaCodec.BufferInfo()
        var track = -1
        var muxerStarted = false
        var samplesQueued = 0
        var inputFinished = false
        var outputFinished = false
        while (!outputFinished) {
            if (!inputFinished) {
                val inputIndex = codec.dequeueInputBuffer(10_000)
                if (inputIndex >= 0) {
                    val remaining = totalSamples - samplesQueued
                    val samples = minOf(1_024, remaining)
                    val input = codec.getInputBuffer(inputIndex)!!.apply { clear() }
                    val bytes = samples * 2
                    repeat(bytes) { input.put(0) }
                    val flags = if (samples == 0) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0
                    codec.queueInputBuffer(inputIndex, 0, bytes, samplesQueued * 1_000_000L / sampleRate, flags)
                    samplesQueued += samples
                    if (samples == 0) inputFinished = true
                }
            }
            when (val outputIndex = codec.dequeueOutputBuffer(info, 10_000)) {
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                else -> if (outputIndex >= 0) {
                    val buffer = codec.getOutputBuffer(outputIndex)!!
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (info.size > 0) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                    }
                    outputFinished = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    codec.releaseOutputBuffer(outputIndex, false)
                }
            }
        }
        codec.stop()
        codec.release()
        if (muxerStarted) muxer.stop()
        muxer.release()
    }

    private fun motionPhotoIds(): Set<Long> {
        val ids = mutableSetOf<Long>()
        composeRule.activity.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Images.Media._ID),
            "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ?",
            arrayOf("%-Motion.jpg"),
            null,
        )?.use { cursor -> while (cursor.moveToNext()) ids += cursor.getLong(0) }
        return ids
    }

    private fun newestMotionPhoto(excluding: Set<Long>): Pair<Uri, ByteArray>? {
        composeRule.activity.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Images.Media._ID),
            "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ?",
            arrayOf("%-Motion.jpg"),
            "${MediaStore.Images.Media.DATE_ADDED} DESC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                if (id !in excluding) {
                    val uri = Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toString())
                    val bytes = composeRule.activity.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: continue
                    return uri to bytes
                }
            }
        }
        return null
    }

    private fun shareImage(file: File) {
        composeRule.activityRule.scenario.onActivity { activity ->
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
            activity.receiveSharedImages(
                Intent(Intent.ACTION_SEND).apply {
                    type = "image/jpeg"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            )
        }
    }

    private fun waitForEditor() {
        composeRule.waitUntil(20_000) {
            composeRule.onAllNodesWithText("灵动照片").fetchSemanticsNodes().isNotEmpty() &&
                runCatching { composeRule.onNodeWithContentDescription("保存照片").fetchSemanticsNode() }.isSuccess
        }
    }
}
