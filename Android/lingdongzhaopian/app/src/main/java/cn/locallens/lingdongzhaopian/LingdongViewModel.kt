package cn.locallens.lingdongzhaopian

import android.app.Application
import android.content.Context
import android.net.Uri
import androidx.compose.ui.geometry.Offset
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withContext

class LingdongViewModel(application: Application) : AndroidViewModel(application) {
    private val prefs = application.getSharedPreferences("lingdong_preferences", Context.MODE_PRIVATE)
    private val _state = MutableStateFlow(
        AppUiState(
            preferences = readPreferences(),
            noticeAcknowledged = prefs.getBoolean("noticeAcknowledged", false),
        )
    )
    val state: StateFlow<AppUiState> = _state.asStateFlow()
    private var copyVariant = 0
    private var privacyHistory = mutableListOf<Pair<List<PrivacyMask>, List<PrivacyStroke>>>()
    private var motionPlaybackJob: Job? = null

    fun acknowledgeNotice() {
        prefs.edit().putBoolean("noticeAcknowledged", true).apply()
        update { it.copy(noticeAcknowledged = true) }
    }

    fun setMode(mode: CreationMode) {
        if (mode == CreationMode.PrivacyMosaic) stopMotionPreview()
        update {
        it.copy(
            mode = mode,
            ratio = mode.defaultRatio,
            imageScale = 1f,
            imageOffset = Offset.Zero,
            paletteOffset = 0f,
            privacyPainting = false,
        )
        }
    }

    fun setRatio(value: ArtworkRatio) = update { it.copy(ratio = value) }
    fun setTemplate(value: ArtworkTemplateStyle) = setPreferences(state.value.preferences.copy(templateStyle = value))
    fun setJournalLayout(value: JournalLayoutMode) = setPreferences(state.value.preferences.copy(journalLayout = value))
    fun setPaletteLayout(value: PaletteLayoutMode) = setPreferences(state.value.preferences.copy(paletteLayout = value)).also {
        update { current -> current.copy(paletteOffset = 0f) }
    }

    fun loadUris(context: Context, uris: List<Uri>, append: Boolean = false, replaceIndex: Int? = null) {
        if (uris.isEmpty()) return
        stopMotionPreview()
        viewModelScope.launch {
            update { it.copy(isLoading = true, loadingStatus = "正在读取照片…") }
            runCatching {
                val loaded = supervisorScope {
                    uris.take(5).map { uri -> async { PhotoProcessor.load(context, uri) } }.awaitAll()
                }
                val current = state.value
                val photos = when {
                    replaceIndex != null && current.photos.indices.contains(replaceIndex) -> current.photos.toMutableList().apply { this[replaceIndex] = loaded.first() }
                    append && current.mode == CreationMode.Journal -> (current.photos + loaded).take(5)
                    else -> if (current.mode == CreationMode.Journal) loaded.take(5) else loaded.take(1)
                }
                val paletteResult = withContext(Dispatchers.Default) { PaletteExtractor.extract(photos.first().bitmap) }
                copyVariant = 0
                val copy = Copywriter.make(photos.first().semantic, photos.first().metadata, paletteResult.colors)
                update {
                    it.copy(
                        photos = photos,
                        palette = paletteResult.colors,
                        palettePercentages = paletteResult.percentages,
                        artworkCopy = copy,
                        isLoading = false,
                        loadingStatus = "",
                        imageScale = 1f,
                        imageOffset = Offset.Zero,
                        journalTransforms = List(photos.size) { index -> it.journalTransforms.getOrElse(index) { JournalTransform() } },
                        selectedJournalIndex = if (it.mode == CreationMode.Journal) 0 else null,
                        privacyMasks = emptyList(),
                        privacyStrokes = emptyList(),
                        motionPreviewFrames = emptyMap(),
                    )
                }
                val retainedMotionFiles = photos.mapNotNull { it.motionVideoFile?.absolutePath }.toSet()
                current.photos.mapNotNull { it.motionVideoFile }
                    .filter { it.absolutePath !in retainedMotionFiles }
                    .forEach { it.delete() }
                privacyHistory.clear()
            }.onFailure {
                update { state -> state.copy(isLoading = false, loadingStatus = "无法读取这张照片") }
            }
        }
    }

    fun removeLastJournalPhoto() {
        val current = state.value
        if (current.photos.size <= 1) return
        stopMotionPreview()
        current.photos.last().motionVideoFile?.delete()
        val photos = current.photos.dropLast(1)
        update { it.copy(photos = photos, journalTransforms = it.journalTransforms.take(photos.size), selectedJournalIndex = 0) }
    }

    fun removeJournalPhoto(index: Int) {
        val current = state.value
        if (current.photos.size <= 1 || !current.photos.indices.contains(index)) return
        stopMotionPreview()
        current.photos[index].motionVideoFile?.delete()
        update {
            it.copy(
                photos = it.photos.filterIndexed { itemIndex, _ -> itemIndex != index },
                journalTransforms = it.journalTransforms.filterIndexed { itemIndex, _ -> itemIndex != index },
                selectedJournalIndex = 0,
            )
        }
    }

    fun moveJournalPhoto(from: Int, to: Int) {
        val current = state.value
        if (!current.photos.indices.contains(from) || !current.photos.indices.contains(to) || from == to) return
        val photos = current.photos.moving(from, to)
        val transforms = current.journalTransforms.moving(from, to)
        update { it.copy(photos = photos, journalTransforms = transforms, selectedJournalIndex = to) }
    }

    fun selectJournal(index: Int?) = update { it.copy(selectedJournalIndex = index) }

    fun updateImageTransform(scale: Float? = null, offset: Offset? = null) = update {
        it.copy(
            imageScale = scale?.coerceIn(1f, 4f) ?: it.imageScale,
            imageOffset = offset ?: it.imageOffset,
        )
    }

    fun updateJournalTransform(index: Int, scale: Float? = null, offset: Offset? = null) {
        val current = state.value
        if (!current.journalTransforms.indices.contains(index)) return
        val values = current.journalTransforms.toMutableList()
        val old = values[index]
        values[index] = old.copy(scale = scale?.coerceIn(1f, 4f) ?: old.scale, offset = offset ?: old.offset)
        update { it.copy(journalTransforms = values) }
    }

    fun resetJournalTransform(index: Int) {
        val current = state.value
        if (!current.journalTransforms.indices.contains(index)) return
        val values = current.journalTransforms.toMutableList()
        values[index] = JournalTransform()
        update { it.copy(journalTransforms = values) }
    }

    fun setPaletteOffset(value: Float) = update { it.copy(paletteOffset = value) }
    fun setBubbleScale(value: Float) = update { it.copy(bubbleScale = value.coerceIn(.45f, 2.1f)) }
    fun setTextScale(value: Float) = update { it.copy(textScale = value.coerceIn(.65f, 1.75f)) }
    fun setFontStyle(value: ArtworkFontStyle) = update { it.copy(fontStyle = value) }
    fun cycleFont(direction: Int) = update { current ->
        val styles = ArtworkFontStyle.entries
        val next = (current.fontStyle.ordinal + if (direction >= 0) 1 else styles.size - 1) % styles.size
        current.copy(fontStyle = styles[next])
    }
    fun adjustTextScale(delta: Float) = update { it.copy(textScale = (it.textScale + delta).coerceIn(.65f, 1.75f)) }
    fun setExporting(value: Boolean) = update { it.copy(isExporting = value) }

    fun playMotionPreview() {
        val current = state.value
        if (current.isMotionPlaying || current.mode == CreationMode.PrivacyMosaic || !current.preferences.supportsMotionPhotos) return
        val sources = current.photos.mapIndexedNotNull { index, photo ->
            photo.motionVideoFile?.takeIf { it.isFile }?.let { index to it }
        }
        if (sources.isEmpty()) return
        motionPlaybackJob?.cancel()
        motionPlaybackJob = viewModelScope.launch {
            val decoders = withContext(Dispatchers.IO) {
                sources.mapNotNull { (index, file) -> runCatching { index to MotionFrameSource(file) }.getOrNull() }
            }
            if (decoders.isEmpty()) return@launch
            update { it.copy(isMotionPlaying = true) }
            try {
                val durationUs = decoders.maxOf { it.second.durationUs }.coerceAtMost(4_000_000L)
                val frameIntervalUs = 83_333L
                var timeUs = 0L
                while (timeUs < durationUs) {
                    val frames = withContext(Dispatchers.IO) {
                        decoders.mapNotNull { (index, decoder) ->
                            decoder.frameAt(timeUs.coerceAtMost(decoder.durationUs - 1))?.let { index to it }
                        }.toMap()
                    }
                    val previous = state.value.motionPreviewFrames
                    update { it.copy(motionPreviewFrames = frames) }
                    delay(84)
                    previous.values.filter { old -> frames.values.none { it === old } }.forEach { if (!it.isRecycled) it.recycle() }
                    timeUs += frameIntervalUs
                }
            } finally {
                decoders.forEach { (_, decoder) -> decoder.close() }
                val previous = state.value.motionPreviewFrames
                update { it.copy(isMotionPlaying = false, motionPreviewFrames = emptyMap()) }
                delay(32)
                previous.values.forEach { if (!it.isRecycled) it.recycle() }
            }
        }
    }

    fun stopMotionPreview() {
        motionPlaybackJob?.cancel()
        motionPlaybackJob = null
        update { it.copy(isMotionPlaying = false, motionPreviewFrames = emptyMap()) }
    }

    fun setMotionExportFrames(frames: Map<Int, android.graphics.Bitmap>) = update {
        it.copy(motionPreviewFrames = frames, isMotionPlaying = false)
    }

    fun clearMotionExportFrames() = update { it.copy(motionPreviewFrames = emptyMap(), isMotionPlaying = false) }

    fun updateCopy(value: ArtworkCopy) = update { it.copy(artworkCopy = value) }
    fun regenerateCopy() {
        val current = state.value
        val photo = current.photos.firstOrNull() ?: return
        copyVariant++
        update { it.copy(artworkCopy = Copywriter.make(photo.semantic, photo.metadata, it.palette, copyVariant)) }
    }

    fun resetComposition() = update {
        it.copy(
            imageScale = 1f, imageOffset = Offset.Zero, paletteOffset = 0f, bubbleScale = 1f,
            textScale = 1f, fontStyle = ArtworkFontStyle.Rounded,
            journalTransforms = List(it.photos.size) { JournalTransform() },
        )
    }

    fun togglePrivacyPainting() = update { it.copy(privacyPainting = !it.privacyPainting) }
    fun setPrivacyBrushMode(value: PrivacyBrushMode) = update { it.copy(privacyBrushMode = value) }
    fun setPrivacyStrength(value: Float) = update { it.copy(privacyStrength = value.coerceIn(0f, 1f)) }

    fun beginPrivacyEdit() {
        val current = state.value
        privacyHistory += current.privacyMasks to current.privacyStrokes
        if (privacyHistory.size > 24) privacyHistory.removeAt(0)
    }

    fun appendPrivacyStroke(points: List<Offset>, width: Float = .085f) = update {
        it.copy(privacyStrokes = it.privacyStrokes + PrivacyStroke(points, width))
    }

    fun erasePrivacyAt(point: Offset, radius: Float = .075f) = update { current ->
        current.copy(privacyStrokes = current.privacyStrokes.filter { stroke -> stroke.points.none { (it - point).getDistance() < radius } })
    }

    fun togglePrivacyMask(index: Int) = update { current ->
        if (!current.privacyMasks.indices.contains(index)) current else current.copy(
            privacyMasks = current.privacyMasks.mapIndexed { itemIndex, mask -> if (itemIndex == index) mask.copy(enabled = !mask.enabled) else mask }
        )
    }

    fun detectPrivacy() {
        val bitmap = state.value.photos.firstOrNull()?.bitmap ?: return
        viewModelScope.launch {
            beginPrivacyEdit()
            update { it.copy(privacyDetecting = true) }
            val result = runCatching { PrivacyDetector.detect(bitmap) }.getOrDefault(emptyList())
            update { it.copy(privacyDetecting = false, privacyMasks = result) }
        }
    }

    fun undoPrivacy() {
        val snapshot = privacyHistory.removeLastOrNull() ?: return
        update { it.copy(privacyMasks = snapshot.first, privacyStrokes = snapshot.second) }
    }

    fun setPreferences(value: AppPreferences) {
        persistPreferences(value)
        update { it.copy(preferences = value) }
    }

    private fun readPreferences() = AppPreferences(
        showAppTitle = prefs.getBoolean("showAppTitle", true),
        showHexValues = prefs.getBoolean("showHexValues", true),
        showPalettePercentages = prefs.getBoolean("showPalettePercentages", true),
        showDeviceInfo = prefs.getBoolean("showDeviceInfo", true),
        showBubbles = prefs.getBoolean("showBubbles", true),
        gentleBackground = prefs.getBoolean("gentleBackground", true),
        useLiteraryColorNames = prefs.getBoolean("useLiteraryColorNames", false),
        preservePaletteBackground = prefs.getBoolean("preservePaletteBackground", true),
        applyLiquidGlassOnExport = prefs.getBoolean("applyLiquidGlassOnExport", true),
        showMoodCopy = prefs.getBoolean("showMoodCopy", false),
        supportsMotionPhotos = prefs.getBoolean("supportsMotionPhotos", true),
        paletteLayout = enumValueOrDefault(prefs.getString("paletteLayout", null), PaletteLayoutMode.Floating),
        templateStyle = enumValueOrDefault(prefs.getString("templateStyle", null), ArtworkTemplateStyle.Classic),
        journalLayout = enumValueOrDefault(prefs.getString("journalLayout", null), JournalLayoutMode.Automatic),
        exportFormat = enumValueOrDefault(prefs.getString("exportFormat", null), ExportFormat.Jpeg),
        exportResolution = enumValueOrDefault(prefs.getString("exportResolution", null), ExportResolution.Standard),
        metadataPolicy = enumValueOrDefault(prefs.getString("metadataPolicy", null), MetadataPolicy.RemoveLocation),
        exportDestination = enumValueOrDefault(prefs.getString("exportDestination", null), ExportDestination.PhotoLibrary),
    )

    private inline fun <reified T : Enum<T>> enumValueOrDefault(raw: String?, default: T): T =
        runCatching { enumValueOf<T>(raw ?: "") }.getOrDefault(default)

    private fun persistPreferences(value: AppPreferences) {
        prefs.edit()
            .putBoolean("showAppTitle", value.showAppTitle)
            .putBoolean("showHexValues", value.showHexValues)
            .putBoolean("showPalettePercentages", value.showPalettePercentages)
            .putBoolean("showDeviceInfo", value.showDeviceInfo)
            .putBoolean("showBubbles", value.showBubbles)
            .putBoolean("gentleBackground", value.gentleBackground)
            .putBoolean("useLiteraryColorNames", value.useLiteraryColorNames)
            .putBoolean("preservePaletteBackground", value.preservePaletteBackground)
            .putBoolean("applyLiquidGlassOnExport", value.applyLiquidGlassOnExport)
            .putBoolean("showMoodCopy", value.showMoodCopy)
            .putBoolean("supportsMotionPhotos", value.supportsMotionPhotos)
            .putString("paletteLayout", value.paletteLayout.name)
            .putString("templateStyle", value.templateStyle.name)
            .putString("journalLayout", value.journalLayout.name)
            .putString("exportFormat", value.exportFormat.name)
            .putString("exportResolution", value.exportResolution.name)
            .putString("metadataPolicy", value.metadataPolicy.name)
            .putString("exportDestination", value.exportDestination.name)
            .apply()
    }

    private inline fun update(transform: (AppUiState) -> AppUiState) {
        _state.value = transform(_state.value)
    }

    override fun onCleared() {
        stopMotionPreview()
        state.value.photos.mapNotNull { it.motionVideoFile }.forEach { it.delete() }
        super.onCleared()
    }
}
