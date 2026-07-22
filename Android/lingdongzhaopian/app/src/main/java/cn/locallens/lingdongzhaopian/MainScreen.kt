package cn.locallens.lingdongzhaopian

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Done
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.MotionPhotosOff
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    state: AppUiState,
    viewModel: LingdongViewModel,
    onExport: (androidx.compose.ui.geometry.Rect) -> Unit,
) {
    val context = LocalContext.current
    var settingsShown by remember { mutableStateOf(false) }
    var exportShown by remember { mutableStateOf(false) }
    var copyEditorShown by remember { mutableStateOf(false) }
    var replacementIndex by remember { mutableStateOf<Int?>(null) }
    var canvasBounds by remember { mutableStateOf(androidx.compose.ui.geometry.Rect.Zero) }

    val singlePicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri?.let { viewModel.loadUris(context, listOf(it), replaceIndex = replacementIndex) }
        replacementIndex = null
    }
    val multiPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(5)) { uris ->
        viewModel.loadUris(context, uris, append = state.photos.isNotEmpty())
    }
    fun openPicker(append: Boolean = false) {
        if (state.mode == CreationMode.Journal && (append || state.photos.isEmpty())) {
            multiPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        } else {
            singlePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
    }

    Box(Modifier.fillMaxSize()) {
        AmbientBackground(if (!state.noticeAcknowledged || state.photos.isEmpty()) RGBColor.intro else state.palette)
        if (state.noticeAcknowledged) {
            if (state.photos.isEmpty()) {
                IntroScreen(state, viewModel, onPick = { openPicker() })
            } else {
                EditorScreen(
                    state = state,
                    viewModel = viewModel,
                    onAdd = { openPicker(append = state.mode == CreationMode.Journal) },
                    onSave = { exportShown = true },
                    onSettings = { settingsShown = true },
                    onEditCopy = { copyEditorShown = true },
                    onCanvasBounds = { canvasBounds = it },
                    onReplaceJournal = { index -> replacementIndex = index; singlePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                )
            }
        }
    }

    if (!state.noticeAcknowledged) FreeNoticeDialog(viewModel::acknowledgeNotice)

    if (settingsShown) {
        val settingsSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { settingsShown = false },
            sheetState = settingsSheetState,
            dragHandle = null,
            containerColor = Color.Transparent,
        ) {
            Box(Modifier.fillMaxHeight(.94f).clip(RoundedCornerShape(topStart = 38.dp, topEnd = 38.dp))) {
                SettingsScreen(
                    state,
                    onMode = { viewModel.setMode(it); settingsShown = false },
                    onRatio = viewModel::setRatio,
                    onPreferences = viewModel::setPreferences,
                    onClose = { settingsShown = false },
                )
            }
        }
    }
    if (copyEditorShown) {
        CopyEditorDialog(
            state = state,
            onSave = viewModel::updateCopy,
            onRegenerate = viewModel::regenerateCopy,
            onFontStyle = viewModel::setFontStyle,
            onTextScale = viewModel::setTextScale,
            onBubbleScale = viewModel::setBubbleScale,
            onDismiss = { copyEditorShown = false },
        )
    }
    if (exportShown) {
        ExportCenterDialog(state, viewModel::setPreferences, onExport = { onExport(canvasBounds) }) { exportShown = false }
    }
}

@Composable
private fun AmbientBackground(palette: List<RGBColor>) {
    val colors = if (palette.isEmpty()) RGBColor.fallback else palette
    Box(
        Modifier.fillMaxSize().background(
            Brush.linearGradient(
                listOf(
                    colors[0].adjusted(.18f, .08f).color,
                    colors.getOrElse(1) { colors[0] }.adjusted(.08f).color,
                    colors.getOrElse(2) { colors[0] }.adjusted(.12f).color,
                )
            )
        )
    ) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(
                Brush.radialGradient(
                    0f to colors.getOrElse(3) { colors[0] }.color.copy(alpha = .42f),
                    .56f to colors.getOrElse(3) { colors[0] }.color.copy(alpha = .42f),
                    1f to Color.Transparent,
                    center = Offset(size.width * .16f, size.height * .80f),
                    radius = size.width * .69f,
                )
            )
            val upper = colors.getOrElse(2) { colors[0] }.adjusted(.22f).color
            drawRect(
                Brush.radialGradient(
                    0f to upper.copy(alpha = .55f),
                    .58f to upper.copy(alpha = .55f),
                    1f to Color.Transparent,
                    center = Offset(size.width * .92f, size.height * .22f),
                    radius = size.width * .59f,
                )
            )
        }
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.White.copy(alpha = .18f), Color.Transparent, Color.Black.copy(alpha = .07f)))))
    }
}

@Composable
private fun IntroScreen(state: AppUiState, viewModel: LingdongViewModel, onPick: () -> Unit) {
    val pagerState = rememberPagerState(initialPage = state.mode.ordinal, pageCount = { CreationMode.entries.size })
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.settledPage }.distinctUntilChanged().collect { page ->
            val mode = CreationMode.entries[page]
            if (mode != state.mode) viewModel.setMode(mode)
        }
    }
    LaunchedEffect(state.mode) {
        if (pagerState.currentPage != state.mode.ordinal) pagerState.animateScrollToPage(state.mode.ordinal)
    }
    HorizontalPager(pagerState, Modifier.fillMaxSize()) { page ->
        val mode = CreationMode.entries[page]
        Column(
            Modifier.fillMaxSize().padding(horizontal = 24.dp).offset(y = 34.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            ModeGlyph(mode)
            Spacer(Modifier.height(48.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(mode.title, color = Color.White.copy(alpha = .94f), fontSize = 24.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium)
                if (mode == CreationMode.Journal) Box(Modifier.padding(start = 7.dp).size(8.dp).background(Color(0xFFFF4F7B), CircleShape))
            }
            Text(mode.introSubtitle, color = Color.White.copy(alpha = .34f), fontSize = 13.sp, textAlign = TextAlign.Center, lineHeight = 21.sp, modifier = Modifier.padding(top = 10.dp))
            Row(Modifier.padding(top = 18.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CreationMode.entries.forEach { item -> Box(Modifier.size(if (item == state.mode) 6.dp else 5.dp).background(Color.White.copy(alpha = if (item == state.mode) 1f else .25f), CircleShape)) }
            }
            Box(
                Modifier.padding(top = 30.dp).size(112.dp).liquidGlass(CircleShape, tint = Color.White, clear = true, shadowElevation = 18.dp).clickable(enabled = !state.isLoading, onClick = onPick),
                contentAlignment = Alignment.Center,
            ) {
                if (state.isLoading) CircularProgressIndicator(color = Color.White.copy(alpha = .88f), strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                else Icon(Icons.Default.Add, "为${mode.title}选择照片", tint = Color.White.copy(alpha = .93f), modifier = Modifier.size(36.dp))
            }
            if (state.isLoading && state.loadingStatus.isNotEmpty()) Text(state.loadingStatus, color = Color.White.copy(alpha = .55f), fontSize = 11.sp, modifier = Modifier.padding(top = 12.dp))
        }
    }
}

@Composable
private fun ModeGlyph(mode: CreationMode) {
    Box(Modifier.size(98.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(66.dp).offset(y = (-16).dp).background(mode.accent.copy(alpha = .72f), CircleShape))
        Box(Modifier.size(66.dp).background(Color.White.copy(alpha = .30f), CircleShape))
        Box(Modifier.size(66.dp).offset(y = 16.dp).background(Color.Black.copy(alpha = .46f), CircleShape).shadow(12.dp, CircleShape))
    }
}

@Composable
private fun EditorScreen(
    state: AppUiState,
    viewModel: LingdongViewModel,
    onAdd: () -> Unit,
    onSave: () -> Unit,
    onSettings: () -> Unit,
    onEditCopy: () -> Unit,
    onCanvasBounds: (androidx.compose.ui.geometry.Rect) -> Unit,
    onReplaceJournal: (Int) -> Unit,
) {
    val haptics = LocalHapticFeedback.current
    BoxWithConstraints(Modifier.fillMaxSize().padding(top = 94.dp)) {
        val ratio = state.ratio.valueFor(state.photos.firstOrNull()?.bitmap)
        val availableWidth = maxWidth - 32.dp
        val reserve = when (state.mode) {
            CreationMode.PrivacyMosaic -> 330.dp
            CreationMode.Journal -> 245.dp
            else -> 128.dp
        }
        val canvasWidth = when (state.mode) {
            CreationMode.SpectrumWallpaper -> minOf(maxWidth - 96.dp, maxWidth * .686f)
            else -> minOf(availableWidth, (maxHeight - reserve) * ratio)
        }.coerceAtLeast(if (maxWidth > 340.dp) 280.dp else maxWidth - 24.dp)
        val canvasHeight = canvasWidth / ratio
        val showsMotionPlayback = state.mode != CreationMode.PrivacyMosaic &&
            state.preferences.supportsMotionPhotos &&
            state.photos.any { it.isMotionPhoto }

        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("灵动照片", fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f), color = Color.Black.copy(alpha = if (state.preferences.showAppTitle) 1f else 0f))
                LiquidIconButton(Icons.Default.Add, "添加照片", { haptics.performHapticFeedback(HapticFeedbackType.LongPress); onAdd() }, enabled = state.mode != CreationMode.Journal || state.photos.size < 5)
                if (state.mode == CreationMode.Journal && state.photos.size > 1) LiquidIconButton(Icons.Default.Remove, "移除照片", viewModel::removeLastJournalPhoto)
                LiquidIconButton(Icons.Default.ArrowDownward, "保存照片", { haptics.performHapticFeedback(HapticFeedbackType.LongPress); onSave() })
                LiquidIconButton(Icons.Outlined.Settings, "设置", { haptics.performHapticFeedback(HapticFeedbackType.LongPress); onSettings() })
            }
            if (showsMotionPlayback) {
                Row(
                    Modifier.width(canvasWidth).padding(top = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    LiquidIconButton(
                        Icons.Default.PlayCircle,
                        if (state.isMotionPlaying) "正在播放动态照片" else "播放动态照片",
                        onClick = {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            viewModel.playMotionPreview()
                        },
                        enabled = !state.isMotionPlaying,
                        size = 44.dp,
                    )
                    GlassContainer(
                        Modifier.height(44.dp).clickable(enabled = !state.isMotionPlaying) { viewModel.playMotionPreview() },
                        cornerRadius = 22.dp,
                    ) {
                        Text(
                            if (state.isMotionPlaying) "正在播放动态照片" else "点击即可预览动态照片",
                            modifier = Modifier.padding(horizontal = 16.dp),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.Black.copy(alpha = .68f),
                        )
                    }
                }
            }
            val gestureModifier = canvasGestureModifier(state, viewModel, onEditCopy, canvasWidth, canvasHeight)
            ArtworkCanvas(
                state,
                exporting = state.isExporting,
                modifier = Modifier
                    .padding(top = if (showsMotionPlayback) 12.dp else 20.dp)
                    .width(canvasWidth)
                    .height(canvasHeight)
                    .onGloballyPositioned { onCanvasBounds(it.boundsInRoot()) }
                    .then(gestureModifier)
                    .shadow(22.dp, RoundedCornerShape(22.dp), ambientColor = Color.Black.copy(alpha = .12f)),
                onPaletteOffset = viewModel::setPaletteOffset,
                onTogglePrivacyMask = viewModel::togglePrivacyMask,
                onCycleFont = { direction -> haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.cycleFont(direction) },
                onAdjustTextScale = { delta -> haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.adjustTextScale(delta) },
                onBubbleScale = viewModel::setBubbleScale,
            )
            if (state.mode == CreationMode.PrivacyMosaic) {
                PrivacyControls(state, viewModel, Modifier.padding(horizontal = 18.dp, vertical = 12.dp))
            }
            if (state.mode == CreationMode.Journal) {
                JournalControls(state, viewModel, onReplaceJournal, Modifier.padding(horizontal = 18.dp, vertical = 10.dp))
            }
            Spacer(Modifier.weight(1f))
        }
    }
}

@Composable
private fun canvasGestureModifier(
    state: AppUiState,
    viewModel: LingdongViewModel,
    onEditCopy: () -> Unit,
    width: androidx.compose.ui.unit.Dp,
    height: androidx.compose.ui.unit.Dp,
): Modifier {
    val density = LocalDensity.current
    val widthPx = with(density) { width.toPx() }
    val heightPx = with(density) { height.toPx() }
    if (state.mode == CreationMode.PrivacyMosaic && state.privacyPainting) {
        var strokePoints by remember { mutableStateOf(emptyList<Offset>()) }
        return Modifier.pointerInput(state.privacyBrushMode, state.privacyStrokes.size) {
            detectDragGestures(
                onDragStart = { point ->
                    viewModel.beginPrivacyEdit()
                    val normalized = privacyNormalizedPoint(point, widthPx, heightPx, state)
                    strokePoints = normalized?.let(::listOf) ?: emptyList()
                    if (normalized != null && state.privacyBrushMode == PrivacyBrushMode.Erase) viewModel.erasePrivacyAt(normalized)
                },
                onDrag = { change, _ ->
                    change.consume()
                    val normalized = privacyNormalizedPoint(change.position, widthPx, heightPx, state)
                    if (normalized != null) {
                        if (state.privacyBrushMode == PrivacyBrushMode.Paint) strokePoints = strokePoints + normalized else viewModel.erasePrivacyAt(normalized)
                    }
                },
                onDragEnd = {
                    if (state.privacyBrushMode == PrivacyBrushMode.Paint && strokePoints.isNotEmpty()) viewModel.appendPrivacyStroke(strokePoints)
                    strokePoints = emptyList()
                },
            )
        }
    }
    val transformState = rememberTransformableState { zoom, pan, _ ->
        if (state.mode == CreationMode.Journal && state.selectedJournalIndex != null) {
            val index = state.selectedJournalIndex
            val old = state.journalTransforms.getOrElse(index) { JournalTransform() }
            viewModel.updateJournalTransform(index, old.scale * zoom, old.offset + pan)
        } else {
            val scale = (state.imageScale * zoom).coerceIn(1f, 4f)
            val offset = if (state.mode == CreationMode.PrivacyMosaic) {
                val horizontalLimit = (widthPx * (scale - 1f) / 2f).coerceAtLeast(0f)
                val verticalLimit = (heightPx * (scale - 1f) / 2f).coerceAtLeast(0f)
                val proposed = state.imageOffset + pan
                Offset(
                    proposed.x.coerceIn(-horizontalLimit, horizontalLimit),
                    proposed.y.coerceIn(-verticalLimit, verticalLimit),
                )
            } else state.imageOffset + pan
            viewModel.updateImageTransform(scale, offset)
        }
    }
    return Modifier
        .then(
            if (state.mode == CreationMode.MotionCard || state.mode == CreationMode.BubbleStamp || state.mode == CreationMode.Journal) {
                Modifier.semantics {
                    onClick(label = "编辑作品文字") {
                        onEditCopy()
                        true
                    }
                }
            } else Modifier
        )
        .transformable(transformState)
        .pointerInput(state.mode, state.privacyMasks) {
            detectTapGestures(
                onDoubleTap = { viewModel.resetComposition() },
                onTap = { point ->
                    if (state.mode == CreationMode.PrivacyMosaic) {
                        val normalized = privacyNormalizedPoint(point, widthPx, heightPx, state) ?: return@detectTapGestures
                        state.privacyMasks.indexOfFirst {
                            normalized.x in it.left..it.right && normalized.y in it.top..it.bottom
                        }.takeIf { it >= 0 }?.let(viewModel::togglePrivacyMask)
                    } else {
                        when (state.mode) {
                            CreationMode.MotionCard -> if (point.y < heightPx * .43f) onEditCopy()
                            CreationMode.BubbleStamp -> if (point.y > widthPx * .91f) onEditCopy()
                            CreationMode.Journal -> {
                                val journalIndex = journalIndexAt(
                                    point,
                                    widthPx,
                                    heightPx,
                                    state.photos.size.coerceAtMost(5),
                                    state.preferences.journalLayout,
                                    with(density) { 3.dp.toPx() },
                                )
                                if (journalIndex != null) viewModel.selectJournal(journalIndex)
                                else if (point.y < heightPx * .28f || point.y > heightPx * .68f) onEditCopy()
                            }
                            else -> Unit
                        }
                    }
                },
            )
        }
}

private fun privacyNormalizedPoint(point: Offset, widthPx: Float, heightPx: Float, state: AppUiState): Offset? {
    val bitmap = state.photos.firstOrNull()?.bitmap ?: return null
    if (bitmap.width <= 0 || bitmap.height <= 0 || widthPx <= 0f || heightPx <= 0f) return null
    val scale = state.imageScale.coerceIn(1f, 4f)
    val horizontalLimit = (widthPx * (scale - 1f) / 2f).coerceAtLeast(0f)
    val verticalLimit = (heightPx * (scale - 1f) / 2f).coerceAtLeast(0f)
    val offset = Offset(
        state.imageOffset.x.coerceIn(-horizontalLimit, horizontalLimit),
        state.imageOffset.y.coerceIn(-verticalLimit, verticalLimit),
    )
    val center = Offset(widthPx / 2f, heightPx / 2f)
    val untransformed = Offset(
        (point.x - center.x - offset.x) / scale + center.x,
        (point.y - center.y - offset.y) / scale + center.y,
    )
    val fitScale = minOf(widthPx / bitmap.width, heightPx / bitmap.height)
    val contentWidth = bitmap.width * fitScale
    val contentHeight = bitmap.height * fitScale
    val left = (widthPx - contentWidth) / 2f
    val top = (heightPx - contentHeight) / 2f
    if (untransformed.x !in left..(left + contentWidth) || untransformed.y !in top..(top + contentHeight)) return null
    return Offset(
        ((untransformed.x - left) / contentWidth).coerceIn(0f, 1f),
        ((untransformed.y - top) / contentHeight).coerceIn(0f, 1f),
    )
}

private fun journalIndexAt(
    point: Offset,
    canvasWidth: Float,
    canvasHeight: Float,
    count: Int,
    layout: JournalLayoutMode,
    spacing: Float,
): Int? {
    if (count <= 0) return null
    val gridWidth = canvasWidth * .50f
    val gridHeight = canvasHeight * .505f
    val gridLeft = (canvasWidth - gridWidth) * .50f
    val gridTop = (canvasHeight - gridHeight) * .50f
    val local = Offset(point.x - gridLeft, point.y - gridTop)
    if (local.x !in 0f..gridWidth || local.y !in 0f..gridHeight) return null

    fun frame(left: Float, top: Float, width: Float, height: Float) =
        androidx.compose.ui.geometry.Rect(left, top, left + width, top + height)
    val frames = when {
        layout == JournalLayoutMode.Filmstrip -> {
            val cellHeight = (gridHeight - spacing * (count - 1)) / count
            List(count) { frame(0f, (cellHeight + spacing) * it, gridWidth, cellHeight) }
        }
        layout == JournalLayoutMode.Magazine && count > 1 -> {
            val heroHeight = gridHeight * .62f
            val remaining = count - 1
            val rowHeight = gridHeight - heroHeight - spacing
            val rowWidth = (gridWidth - spacing * (remaining - 1)) / remaining
            listOf(frame(0f, 0f, gridWidth, heroHeight)) + List(remaining) {
                frame((rowWidth + spacing) * it, heroHeight + spacing, rowWidth, rowHeight)
            }
        }
        count == 1 -> listOf(frame(0f, 0f, gridWidth, gridHeight))
        count == 2 -> {
            val cellHeight = (gridHeight - spacing) / 2f
            List(2) { frame(0f, (cellHeight + spacing) * it, gridWidth, cellHeight) }
        }
        count == 3 -> {
            val leftWidth = gridWidth * .58f
            val rightWidth = gridWidth - leftWidth - spacing
            val rightHeight = (gridHeight - spacing) / 2f
            listOf(
                frame(0f, 0f, leftWidth, gridHeight),
                frame(leftWidth + spacing, 0f, rightWidth, rightHeight),
                frame(leftWidth + spacing, rightHeight + spacing, rightWidth, rightHeight),
            )
        }
        count == 4 -> {
            val cellWidth = (gridWidth - spacing) / 2f
            val cellHeight = (gridHeight - spacing) / 2f
            List(4) { frame((cellWidth + spacing) * (it % 2), (cellHeight + spacing) * (it / 2), cellWidth, cellHeight) }
        }
        else -> {
            val topHeight = gridHeight * .56f
            val bottomHeight = gridHeight - topHeight - spacing
            val topWidth = (gridWidth - spacing) / 2f
            val bottomWidth = (gridWidth - spacing * 2f) / 3f
            List(5) {
                if (it < 2) frame((topWidth + spacing) * it, 0f, topWidth, topHeight)
                else frame((bottomWidth + spacing) * (it - 2), topHeight + spacing, bottomWidth, bottomHeight)
            }
        }
    }
    return frames.indexOfFirst { it.contains(local) }.takeIf { it >= 0 }
}

@Composable
private fun PrivacyControls(state: AppUiState, viewModel: LingdongViewModel, modifier: Modifier) {
    val disabledCount = state.privacyMasks.count { !it.enabled }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GlassContainer(Modifier.weight(1f).height(48.dp).clickable(onClick = viewModel::togglePrivacyPainting), cornerRadius = 24.dp) {
                Row(verticalAlignment = Alignment.CenterVertically) { Icon(if (state.privacyPainting) Icons.Default.Done else Icons.Default.TouchApp, null); Spacer(Modifier.width(8.dp)); Text(if (state.privacyPainting) "完成涂抹" else "手动涂抹", fontWeight = FontWeight.SemiBold) }
            }
            GlassContainer(Modifier.weight(1f).height(48.dp).clickable(enabled = !state.privacyDetecting, onClick = viewModel::detectPrivacy), cornerRadius = 24.dp) {
                if (state.privacyDetecting) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp) else Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.VisibilityOff, null); Spacer(Modifier.width(8.dp)); Text("智能识别", fontWeight = FontWeight.SemiBold) }
            }
        }
        if (state.privacyPainting) {
            GlassContainer(Modifier.fillMaxWidth().height(42.dp), cornerRadius = 21.dp, contentAlignment = Alignment.CenterStart) {
                Row(Modifier.padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    PrivacyBrushMode.entries.forEach { mode ->
                        Text(mode.label, color = if (state.privacyBrushMode == mode) Color.White else Color.Black.copy(alpha = .66f), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.background(if (state.privacyBrushMode == mode) Color.Black.copy(alpha = .78f) else Color.Transparent, CircleShape).clickable { viewModel.setPrivacyBrushMode(mode) }.padding(horizontal = 14.dp, vertical = 8.dp))
                    }
                    Spacer(Modifier.weight(1f)); Text("单指${state.privacyBrushMode.label}", color = Color.Gray, fontSize = 10.sp)
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GlassContainer(Modifier.weight(1f).height(46.dp), cornerRadius = 23.dp) {
                Row(Modifier.padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.GridView, null, Modifier.size(17.dp))
                    Slider(
                        state.privacyStrength,
                        viewModel::setPrivacyStrength,
                        Modifier.weight(1f),
                        colors = SliderDefaults.colors(
                            thumbColor = Color.Black.copy(alpha = .84f),
                            activeTrackColor = Color.Black.copy(alpha = .90f),
                            inactiveTrackColor = Color.Black.copy(alpha = .14f),
                        ),
                    )
                    Text(if (state.privacyStrength < .34f) "细" else if (state.privacyStrength < .68f) "中" else "强", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
            }
            LiquidIconButton(Icons.AutoMirrored.Filled.Undo, "撤销", viewModel::undoPrivacy, enabled = state.privacyMasks.isNotEmpty() || state.privacyStrokes.isNotEmpty(), size = 44.dp)
        }
        if (state.privacyMasks.isNotEmpty()) {
            Text(
                "已识别 ${state.privacyMasks.size} 处 · 点击区域可关闭或恢复" + if (disabledCount > 0) "（已关闭 $disabledCount 处）" else "",
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = Color.Black.copy(alpha = .58f),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        if (state.photos.any { it.isMotionPhoto }) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.MotionPhotosOff, null, Modifier.size(14.dp), tint = Color(0xFFFF8A00))
                Spacer(Modifier.width(5.dp))
                Text("隐私遮挡后仅支持静态导出", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFFFF8A00))
            }
        }
    }
}

@Composable
private fun JournalControls(state: AppUiState, viewModel: LingdongViewModel, onReplace: (Int) -> Unit, modifier: Modifier) {
    val haptics = LocalHapticFeedback.current
    val density = LocalDensity.current
    val reorderThreshold = with(density) { 52.dp.toPx() }
    var layoutMenuExpanded by remember { mutableStateOf(false) }
    var photoMenuExpanded by remember { mutableStateOf(false) }
    GlassContainer(modifier.fillMaxWidth(), cornerRadius = 24.dp, contentAlignment = Alignment.TopStart) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("单图构图", color = Color.Gray, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                Box {
                    Text(
                        state.preferences.journalLayout.label,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .clip(CircleShape)
                            .clickable { layoutMenuExpanded = true }
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                    )
                    DropdownMenu(
                        expanded = layoutMenuExpanded,
                        onDismissRequest = { layoutMenuExpanded = false },
                    ) {
                        JournalLayoutMode.entries.forEach { layout ->
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        layout.label,
                                        fontWeight = if (layout == state.preferences.journalLayout) FontWeight.Bold else FontWeight.Normal,
                                    )
                                },
                                onClick = {
                                    viewModel.setJournalLayout(layout)
                                    layoutMenuExpanded = false
                                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                },
                            )
                        }
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.weight(1f).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    state.photos.forEachIndexed { index, photo ->
                        val selected = state.selectedJournalIndex == index
                        Image(
                            (state.bitmapAt(index) ?: photo.bitmap).asImageBitmap(),
                            "手帐照片 ${index + 1}",
                            contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                            modifier = Modifier
                                .size(48.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .border(
                                    if (selected) 2.5.dp else 1.dp,
                                    Color.White.copy(alpha = if (selected) 1f else .24f),
                                    RoundedCornerShape(12.dp),
                                )
                                .pointerInput(photo.uri, state.photos.size) {
                                    var activeIndex = index
                                    var travel = 0f
                                    detectDragGesturesAfterLongPress(
                                        onDragStart = {
                                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                            viewModel.selectJournal(activeIndex)
                                        },
                                        onDrag = { change, amount ->
                                            change.consume()
                                            travel += amount.x
                                            while (travel >= reorderThreshold && activeIndex < state.photos.lastIndex) {
                                                viewModel.moveJournalPhoto(activeIndex, activeIndex + 1)
                                                activeIndex++
                                                travel -= reorderThreshold
                                                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                            }
                                            while (travel <= -reorderThreshold && activeIndex > 0) {
                                                viewModel.moveJournalPhoto(activeIndex, activeIndex - 1)
                                                activeIndex--
                                                travel += reorderThreshold
                                                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                            }
                                        },
                                    )
                                }
                                .clickable { viewModel.selectJournal(index) },
                        )
                    }
                }
                state.selectedJournalIndex?.takeIf { it in state.photos.indices }?.let { index ->
                    Box {
                        LiquidIconButton(
                            Icons.Default.MoreHoriz,
                            "照片操作",
                            { photoMenuExpanded = true },
                            size = 44.dp,
                        )
                        DropdownMenu(
                            expanded = photoMenuExpanded,
                            onDismissRequest = { photoMenuExpanded = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text("替换这张") },
                                onClick = { photoMenuExpanded = false; onReplace(index) },
                            )
                            DropdownMenuItem(
                                text = { Text("恢复构图") },
                                onClick = { photoMenuExpanded = false; viewModel.resetJournalTransform(index) },
                            )
                            if (state.photos.size > 1) {
                                DropdownMenuItem(
                                    text = { Text("删除这张", color = Color(0xFFB3261E)) },
                                    onClick = { photoMenuExpanded = false; viewModel.removeJournalPhoto(index) },
                                )
                            }
                        }
                    }
                }
            }
            Text("点击选择后在画布上拖动或双指缩放；长按缩略图可拖拽排序", color = Color.Gray, fontSize = 10.sp)
        }
    }
}

@Composable
private fun FreeNoticeDialog(onDismiss: () -> Unit) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Box(
            Modifier.fillMaxSize().padding(horizontal = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            Surface(
                modifier = Modifier.fillMaxWidth().widthIn(max = 330.dp).shadow(26.dp, RoundedCornerShape(32.dp)),
                shape = RoundedCornerShape(32.dp),
                color = Color(0xFFF9F9F7),
                tonalElevation = 0.dp,
            ) {
                Column(
                    Modifier
                        .background(
                            Brush.verticalGradient(
                                listOf(Color.White, Color(0xFFF4F4F1)),
                            )
                        )
                        .padding(26.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(17.dp),
                ) {
                    Box(
                        Modifier
                            .size(68.dp)
                            .background(Color.Black.copy(alpha = .055f), CircleShape)
                            .border(1.dp, Color.White, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Default.Check, null, Modifier.size(34.dp), tint = Color.Black.copy(alpha = .82f))
                    }
                    Text("灵动照片 · 完全免费", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color(0xFF171717))
                    Text(
                        "本应用不收取任何订阅或功能费用。\n谨防付费下载、代购或订阅骗局。",
                        color = Color.Black.copy(alpha = .58f),
                        fontSize = 14.sp,
                        textAlign = TextAlign.Center,
                        lineHeight = 21.sp,
                    )
                    Button(
                        onClick = onDismiss,
                        modifier = Modifier.fillMaxWidth().height(50.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF171717), contentColor = Color.White),
                    ) {
                        Text("我知道了", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
