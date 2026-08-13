package cn.locallens.lingdongzhaopian

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.material.icons.filled.Done
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.MotionPhotosOff
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.ScreenRotation
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Compare
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.AlertDialog
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
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    state: AppUiState,
    viewModel: LingdongViewModel,
    onExport: (androidx.compose.ui.geometry.Rect) -> Unit,
    onExportTicketCode: (TicketCodeStyle, ExportDestination) -> Unit = { _, _ -> },
    onExportRelationship: (androidx.compose.ui.geometry.Rect, ExportDimensions, String) -> Unit = { _, _, _ -> },
    onTicketLandscapeChanged: (Boolean) -> Unit = {},
) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    var settingsShown by remember { mutableStateOf(false) }
    var exportShown by remember { mutableStateOf(false) }
    var copyEditorShown by remember { mutableStateOf(false) }
    var motionCardSamplerShown by remember { mutableStateOf(false) }
    var ticketSamplerShown by remember { mutableStateOf(false) }
    var modeSelectionShown by remember { mutableStateOf(false) }
    var ticketStudioShown by remember { mutableStateOf(false) }
    var ticketMessagePromptShown by remember { mutableStateOf(false) }
    var ticketMessageEditorShown by remember { mutableStateOf(false) }
    var scannerShown by remember { mutableStateOf(false) }
    var albumShown by remember { mutableStateOf(false) }
    var relationshipShown by remember { mutableStateOf(false) }
    var replacementIndex by remember { mutableStateOf<Int?>(null) }
    var canvasBounds by remember { mutableStateOf(androidx.compose.ui.geometry.Rect.Zero) }
    var skippedTicketMessageForCurrentPhoto by remember(state.ticketSessionID) { mutableStateOf(false) }

    fun requestExport() {
        val current = viewModel.state.value
        if (
            current.mode == CreationMode.TravelTicket &&
            TicketPayload.normalizedMessage(current.ticketMessage) == null &&
            !skippedTicketMessageForCurrentPhoto
        ) {
            ticketMessagePromptShown = true
        } else {
            exportShown = true
        }
    }

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

    LaunchedEffect(state.mode, state.photos.isEmpty()) {
        if (state.mode != CreationMode.TravelTicket || state.photos.isEmpty()) {
            onTicketLandscapeChanged(false)
        }
    }

    Box(Modifier.fillMaxSize()) {
        // A ticket export must keep transparent pixels outside its silhouette, and the exporter
        // records the whole view tree, so the ambient wash steps aside for that one frame.
        val hidesAmbient = state.isExporting && state.mode == CreationMode.TravelTicket
        if (!hidesAmbient) {
            AmbientBackground(if (!state.publicGoodsAcknowledged || state.photos.isEmpty()) RGBColor.intro else state.activePalette)
        }
        if (state.publicGoodsAcknowledged) {
            if (relationshipShown) {
                ColorRelationshipScreen(
                    onOpenModeSelection = { modeSelectionShown = true },
                    onClose = { relationshipShown = false },
                    onExport = onExportRelationship,
                )
            } else if (state.photos.isEmpty()) {
                IntroScreen(
                    state,
                    viewModel,
                    onPick = { openPicker() },
                    onScanTicket = { scannerShown = true },
                    onOpenAlbum = { albumShown = true },
                    onOpenRelationship = { relationshipShown = true },
                )
            } else {
                val showsLandscapeTicket = state.mode == CreationMode.TravelTicket &&
                    configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
                if (showsLandscapeTicket) {
                    LandscapeTicketEditor(
                        state = state,
                        viewModel = viewModel,
                        onExitLandscape = { onTicketLandscapeChanged(false) },
                        onAdd = { openPicker() },
                        onSave = ::requestExport,
                        onSettings = { settingsShown = true },
                        onModeSelection = { modeSelectionShown = true },
                        onEditCopy = { copyEditorShown = true },
                        onOpenTicketStudio = { ticketStudioShown = true },
                        onCanvasBounds = { canvasBounds = it },
                    )
                } else {
                    EditorScreen(
                        state = state,
                        viewModel = viewModel,
                        onAdd = { openPicker(append = state.mode == CreationMode.Journal) },
                        onSave = ::requestExport,
                        onSettings = { settingsShown = true },
                        onModeSelection = { modeSelectionShown = true },
                        onEnterTicketLandscape = { onTicketLandscapeChanged(true) },
                        onEditCopy = { copyEditorShown = true },
                        onOpenMotionCardSampler = { motionCardSamplerShown = true },
                        onOpenTicketSampler = { ticketSamplerShown = true },
                        onOpenTicketStudio = { ticketStudioShown = true },
                        onCanvasBounds = { canvasBounds = it },
                        onReplaceJournal = { index -> replacementIndex = index; singlePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                    )
                }
            }
        }
    }

    if (!state.publicGoodsAcknowledged) {
        PublicGoodsCommitmentDialog(
            showsUpdateNext = !state.updateLog200Acknowledged,
            onDismiss = viewModel::acknowledgePublicGoods,
        )
    } else if (!state.updateLog200Acknowledged) {
        Version200UpdateDialog(viewModel::acknowledgeUpdateLog200)
    }

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
                    onRatio = viewModel::setRatio,
                    onPreferences = viewModel::setPreferences,
                    onClose = { settingsShown = false },
                )
            }
        }
    }
    if (modeSelectionShown) {
        ModeSelectionSheet(
            selectedMode = state.mode,
            relationshipSelected = relationshipShown,
            onSelect = { relationshipShown = false; viewModel.setMode(it); modeSelectionShown = false },
            onOpenAlbum = { modeSelectionShown = false; albumShown = true },
            onOpenRelationship = { modeSelectionShown = false; relationshipShown = true },
            onScanTicket = { modeSelectionShown = false; scannerShown = true },
            onDismiss = { modeSelectionShown = false },
        )
    }
    if (ticketStudioShown) {
        TicketCodeStudioSheet(
            state = state,
            onPreferences = viewModel::setPreferences,
            onTicketMessage = viewModel::updateTicketMessage,
            onSaveCode = { style, destination ->
                ticketStudioShown = false
                onExportTicketCode(style, destination)
            },
            onDismiss = { ticketStudioShown = false },
        )
    }
    if (scannerShown) {
        TicketScannerDialog { scannerShown = false }
    }
    if (albumShown) {
        AlbumStudioDialog { albumShown = false }
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
    if (motionCardSamplerShown) {
        state.photos.firstOrNull()?.bitmap?.let { bitmap ->
            MotionCardColorSamplerDialog(
                bitmap = bitmap,
                initialSelection = state.motionCardSamplingRect,
                headerStyle = state.preferences.motionCardHeaderStyle,
                description = "拖动选框选择取色范围，拖动四角可调整大小。此范围只影响灵动卡片顶部背景。",
                onApply = { rect, result ->
                    viewModel.applyMotionCardSampling(rect, result)
                    motionCardSamplerShown = false
                },
                onReset = {
                    viewModel.resetMotionCardSampling()
                    motionCardSamplerShown = false
                },
                onDismiss = { motionCardSamplerShown = false },
            )
        }
    }
    if (ticketSamplerShown) {
        state.photos.firstOrNull()?.bitmap?.let { bitmap ->
            MotionCardColorSamplerDialog(
                bitmap = bitmap,
                initialSelection = state.ticketSamplingRect,
                headerStyle = MotionCardHeaderStyle.Solid,
                description = "拖动选框选择取色范围，拖动四角可调整大小。此范围会用于影像票根的背景与色盘。",
                onApply = { rect, result ->
                    viewModel.applyTicketSampling(rect, result)
                    ticketSamplerShown = false
                },
                onReset = {
                    viewModel.resetTicketSampling()
                    ticketSamplerShown = false
                },
                onDismiss = { ticketSamplerShown = false },
            )
        }
    }
    if (ticketMessagePromptShown) {
        AlertDialog(
            onDismissRequest = { ticketMessagePromptShown = false },
            title = { Text("还没有写下这次的寄语") },
            text = { Text("寄语会显示在影像票根的公开信息中。要在导出前补充吗？") },
            confirmButton = {
                TextButton(
                    onClick = {
                        ticketMessagePromptShown = false
                        ticketMessageEditorShown = true
                    },
                ) { Text("补充寄语") }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = { ticketMessagePromptShown = false }) { Text("取消") }
                    TextButton(
                        onClick = {
                            ticketMessagePromptShown = false
                            skippedTicketMessageForCurrentPhoto = true
                            exportShown = true
                        },
                    ) { Text("直接导出") }
                }
            },
        )
    }
    if (ticketMessageEditorShown) {
        TicketMessageEditorSheet(
            message = state.ticketMessage,
            onSave = { message ->
                viewModel.updateTicketMessage(message)
                skippedTicketMessageForCurrentPhoto = false
                ticketMessageEditorShown = false
                exportShown = true
            },
            onDismiss = { ticketMessageEditorShown = false },
        )
    }
    if (exportShown) {
        ExportCenterDialog(state, viewModel::setPreferences, onExport = { onExport(canvasBounds) }) { exportShown = false }
    }
}

@Composable
private fun MotionCardSamplingControls(
    hasSelection: Boolean,
    onOpen: () -> Unit,
    onReset: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        GlassContainer(
            Modifier.weight(1f).height(44.dp).clickable(onClick = onOpen),
            cornerRadius = 22.dp,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                Icon(Icons.Default.TouchApp, null, Modifier.size(18.dp), tint = Color.Black.copy(alpha = .72f))
                Text(
                    if (hasSelection) "调整取色范围" else "局部取色",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.Black.copy(alpha = .78f),
                )
            }
        }
        if (hasSelection) {
            GlassContainer(
                Modifier.height(44.dp).clickable(onClick = onReset),
                cornerRadius = 22.dp,
            ) {
                Text(
                    "恢复整图",
                    modifier = Modifier.padding(horizontal = 16.dp),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.Black.copy(alpha = .68f),
                )
            }
        }
    }
}

private enum class SamplerCorner { TopLeft, TopRight, BottomLeft, BottomRight }

@Composable
private fun MotionCardColorSamplerDialog(
    bitmap: Bitmap,
    initialSelection: NormalizedColorSampleRect?,
    headerStyle: MotionCardHeaderStyle,
    description: String,
    onApply: (NormalizedColorSampleRect, PaletteResult) -> Unit,
    onReset: () -> Unit,
    onDismiss: () -> Unit,
) {
    var selection by remember(bitmap, initialSelection) {
        mutableStateOf(initialSelection ?: NormalizedColorSampleRect(.15f, .20f, .70f, .60f))
    }
    var preview by remember(bitmap) { mutableStateOf<PaletteResult?>(null) }
    var photoSize by remember { mutableStateOf(IntSize.Zero) }
    val density = LocalDensity.current

    LaunchedEffect(bitmap, selection) {
        delay(120)
        preview = withContext(Dispatchers.Default) { extractLocalPalette(bitmap, selection) }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(
            Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.surface,
        ) {
            Column(Modifier.fillMaxSize().padding(top = 12.dp, bottom = 14.dp)) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = onDismiss) { Text("取消") }
                    Text(
                        "局部取色",
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    TextButton(
                        onClick = {
                            val result = preview ?: extractLocalPalette(bitmap, selection)
                            onApply(selection, result)
                        },
                    ) { Text("应用", fontWeight = FontWeight.Bold) }
                }
                Text(
                    description,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 28.dp, vertical = 8.dp),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = .58f),
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    textAlign = TextAlign.Center,
                )

                BoxWithConstraints(
                    Modifier.fillMaxWidth().weight(1f).padding(horizontal = 18.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    val aspect = bitmap.width.toFloat() / bitmap.height.coerceAtLeast(1)
                    val photoWidth = minOf(maxWidth, maxHeight * aspect)
                    val photoHeight = photoWidth / aspect
                    Box(
                        Modifier
                            .width(photoWidth)
                            .height(photoHeight)
                            .clip(RoundedCornerShape(18.dp))
                            .background(Color.Black)
                            .onSizeChanged { photoSize = it },
                    ) {
                        Image(bitmap.asImageBitmap(), null, Modifier.fillMaxSize())
                        if (photoSize.width > 0 && photoSize.height > 0) {
                            Canvas(Modifier.fillMaxSize()) {
                                val left = selection.left * size.width
                                val top = selection.top * size.height
                                val right = selection.right * size.width
                                val bottom = selection.bottom * size.height
                                val shade = Color.Black.copy(alpha = .52f)
                                drawRect(shade, topLeft = Offset.Zero, size = androidx.compose.ui.geometry.Size(size.width, top))
                                drawRect(shade, topLeft = Offset(0f, bottom), size = androidx.compose.ui.geometry.Size(size.width, size.height - bottom))
                                drawRect(shade, topLeft = Offset(0f, top), size = androidx.compose.ui.geometry.Size(left, bottom - top))
                                drawRect(shade, topLeft = Offset(right, top), size = androidx.compose.ui.geometry.Size(size.width - right, bottom - top))
                                drawRect(
                                    Color.White,
                                    topLeft = Offset(left, top),
                                    size = androidx.compose.ui.geometry.Size(right - left, bottom - top),
                                    style = androidx.compose.ui.graphics.drawscope.Stroke(
                                        width = 2.dp.toPx(),
                                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 7f)),
                                    ),
                                )
                            }

                            val selectionWidth = with(density) { (selection.width * photoSize.width).toDp() }
                            val selectionHeight = with(density) { (selection.height * photoSize.height).toDp() }
                            val selectionX = with(density) { (selection.left * photoSize.width).toDp() }
                            val selectionY = with(density) { (selection.top * photoSize.height).toDp() }
                            Box(
                                Modifier
                                    .offset(selectionX, selectionY)
                                    .size(selectionWidth, selectionHeight)
                                    .pointerInput(photoSize) {
                                        detectDragGestures { change, drag ->
                                            change.consume()
                                            selection = moveSampleRect(
                                                selection,
                                                drag.x / photoSize.width,
                                                drag.y / photoSize.height,
                                            )
                                        }
                                    },
                            )
                            SamplerCorner.entries.forEach { corner ->
                                val pointX = when (corner) {
                                    SamplerCorner.TopLeft, SamplerCorner.BottomLeft -> selection.left
                                    SamplerCorner.TopRight, SamplerCorner.BottomRight -> selection.right
                                }
                                val pointY = when (corner) {
                                    SamplerCorner.TopLeft, SamplerCorner.TopRight -> selection.top
                                    SamplerCorner.BottomLeft, SamplerCorner.BottomRight -> selection.bottom
                                }
                                Box(
                                    Modifier
                                        .offset(
                                            x = with(density) { (pointX * photoSize.width).toDp() - 12.dp },
                                            y = with(density) { (pointY * photoSize.height).toDp() - 12.dp },
                                        )
                                        .size(24.dp)
                                        .background(Color.White, CircleShape)
                                        .border(1.dp, Color.Black.copy(alpha = .22f), CircleShape)
                                        .pointerInput(corner, photoSize) {
                                            detectDragGestures { change, drag ->
                                                change.consume()
                                                selection = resizeSampleRect(
                                                    selection,
                                                    corner,
                                                    drag.x / photoSize.width,
                                                    drag.y / photoSize.height,
                                                )
                                            }
                                        },
                                )
                            }
                        }
                    }
                }

                LocalPalettePreview(preview, headerStyle, Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 14.dp))

                Button(
                    onClick = onReset,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp).height(46.dp),
                    shape = RoundedCornerShape(23.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.onSurface.copy(alpha = .08f),
                        contentColor = MaterialTheme.colorScheme.onSurface.copy(alpha = .76f),
                    ),
                ) { Text("恢复整张照片取色", fontWeight = FontWeight.SemiBold) }
            }
        }
    }
}

@Composable
private fun LocalPalettePreview(result: PaletteResult?, headerStyle: MotionCardHeaderStyle, modifier: Modifier = Modifier) {
    if (result == null) {
        Box(modifier.height(62.dp), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
        }
        return
    }
    val colors = result.colors.ifEmpty { RGBColor.fallback }
    val theme = remember(colors, result.percentages) { MotionCardThemeResolver.resolve(colors, result.percentages) }
    val gradient = remember(colors, result.percentages) { MotionCardGradientResolver.resolve(colors, result.percentages) }
    Row(
        modifier
            .height(62.dp)
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = .06f), RoundedCornerShape(16.dp))
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .weight(1f)
                .fillMaxHeight()
                .clip(RoundedCornerShape(11.dp))
                .then(
                    if (headerStyle == MotionCardHeaderStyle.SampledGradient) {
                        Modifier.background(Brush.horizontalGradient(gradient.colors.map { it.color }))
                    } else Modifier.background(theme.background.color)
                ),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            colors.take(4).forEach { color -> Box(Modifier.size(15.dp).background(color.color, CircleShape)) }
        }
    }
}

private fun moveSampleRect(rect: NormalizedColorSampleRect, dx: Float, dy: Float): NormalizedColorSampleRect =
    rect.copy(
        left = (rect.left + dx).coerceIn(0f, 1f - rect.width),
        top = (rect.top + dy).coerceIn(0f, 1f - rect.height),
    )

private fun resizeSampleRect(
    rect: NormalizedColorSampleRect,
    corner: SamplerCorner,
    dx: Float,
    dy: Float,
): NormalizedColorSampleRect {
    val minimum = .12f
    var left = rect.left
    var top = rect.top
    var right = rect.right
    var bottom = rect.bottom
    when (corner) {
        SamplerCorner.TopLeft -> {
            left = (left + dx).coerceIn(0f, right - minimum)
            top = (top + dy).coerceIn(0f, bottom - minimum)
        }
        SamplerCorner.TopRight -> {
            right = (right + dx).coerceIn(left + minimum, 1f)
            top = (top + dy).coerceIn(0f, bottom - minimum)
        }
        SamplerCorner.BottomLeft -> {
            left = (left + dx).coerceIn(0f, right - minimum)
            bottom = (bottom + dy).coerceIn(top + minimum, 1f)
        }
        SamplerCorner.BottomRight -> {
            right = (right + dx).coerceIn(left + minimum, 1f)
            bottom = (bottom + dy).coerceIn(top + minimum, 1f)
        }
    }
    return NormalizedColorSampleRect(left, top, right - left, bottom - top)
}

private fun extractLocalPalette(bitmap: Bitmap, rect: NormalizedColorSampleRect): PaletteResult {
    val left = (rect.left.coerceIn(0f, 1f) * bitmap.width).roundToInt().coerceIn(0, bitmap.width - 1)
    val top = (rect.top.coerceIn(0f, 1f) * bitmap.height).roundToInt().coerceIn(0, bitmap.height - 1)
    val right = (rect.right.coerceIn(0f, 1f) * bitmap.width).roundToInt().coerceIn(left + 1, bitmap.width)
    val bottom = (rect.bottom.coerceIn(0f, 1f) * bitmap.height).roundToInt().coerceIn(top + 1, bitmap.height)
    val crop = Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
    return try {
        PaletteExtractor.extract(crop)
    } finally {
        if (crop !== bitmap && !crop.isRecycled) crop.recycle()
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
private fun IntroScreen(
    state: AppUiState,
    viewModel: LingdongViewModel,
    onPick: () -> Unit,
    onScanTicket: () -> Unit,
    onOpenAlbum: () -> Unit,
    onOpenRelationship: () -> Unit,
) {
    val albumPage = CreationMode.entries.size
    val relationshipPage = albumPage + 1
    val scanPage = albumPage + 2
    val pageCount = CreationMode.entries.size + 3
    val pagerState = rememberPagerState(initialPage = state.mode.ordinal, pageCount = { pageCount })
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.settledPage }.distinctUntilChanged().collect { page ->
            val mode = CreationMode.entries.getOrNull(page) ?: return@collect
            if (mode != state.mode) viewModel.setMode(mode)
        }
    }
    LaunchedEffect(state.mode) {
        if (pagerState.currentPage < CreationMode.entries.size &&
            pagerState.currentPage != state.mode.ordinal
        ) {
            pagerState.animateScrollToPage(state.mode.ordinal)
        }
    }
    HorizontalPager(pagerState, Modifier.fillMaxSize()) { page ->
        val mode = CreationMode.entries.getOrNull(page)
        IntroPage(
            title = when (page) { albumPage -> "影像相簿"; relationshipPage -> "色彩关系"; scanPage -> "扫描验证票根"; else -> mode?.title.orEmpty() },
            subtitle = when (page) {
                albumPage -> "把散落的影像装订成书\n整本预览后导出可打印 PDF"
                relationshipPage -> "选择两张照片\n看看色彩如何在它们之间相遇"
                scanPage -> "打开相机扫描影像票根上的验证二维码\n无需先添加照片"
                else -> mode?.introSubtitle.orEmpty()
            },
            icon = when (page) { albumPage -> Icons.Default.GridView; relationshipPage -> Icons.Outlined.Compare; scanPage -> Icons.Outlined.QrCodeScanner; else -> mode?.let(::modeIcon) ?: Icons.Default.GridView },
            accent = when (page) { albumPage -> Color(0xFFA8D7B6); relationshipPage -> Color(0xFFD9B0A9); scanPage -> Color(0xFFABE0FF); else -> mode?.accent ?: Color.White },
            showsBadge = mode == CreationMode.Journal,
            actionIcon = when (page) { albumPage -> Icons.Default.GridView; relationshipPage -> Icons.Outlined.Compare; scanPage -> Icons.Outlined.QrCodeScanner; else -> Icons.Default.Add },
            actionDescription = when (page) { albumPage -> "打开影像相簿"; relationshipPage -> "打开色彩关系"; scanPage -> "扫描验证票根"; else -> "为${mode?.title.orEmpty()}选择照片" },
            isBusy = mode != null && state.isLoading,
            loadingStatus = if (mode != null) state.loadingStatus else "",
            selectedPage = pagerState.currentPage,
            pageCount = pageCount,
            onAction = when (page) { albumPage -> onOpenAlbum; relationshipPage -> onOpenRelationship; scanPage -> onScanTicket; else -> onPick },
        )
    }
}

@Composable
private fun IntroPage(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    accent: Color,
    showsBadge: Boolean,
    actionIcon: androidx.compose.ui.graphics.vector.ImageVector,
    actionDescription: String,
    isBusy: Boolean,
    loadingStatus: String,
    selectedPage: Int,
    pageCount: Int,
    onAction: () -> Unit,
) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp).offset(y = 34.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        ModeGlyph(icon, accent)
        Spacer(Modifier.height(48.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, color = Color.White.copy(alpha = .94f), fontSize = 24.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium)
            if (showsBadge) Box(Modifier.padding(start = 7.dp).size(8.dp).background(Color(0xFFFF4F7B), CircleShape))
        }
        Text(subtitle, color = Color.White.copy(alpha = .34f), fontSize = 13.sp, textAlign = TextAlign.Center, lineHeight = 21.sp, modifier = Modifier.padding(top = 10.dp))
        Row(Modifier.padding(top = 18.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(pageCount) { index ->
                val current = index == selectedPage
                Box(
                    Modifier
                        .size(if (current) 6.dp else 5.dp)
                        .background(Color.White.copy(alpha = if (current) 1f else .25f), CircleShape)
                )
            }
        }
        Box(
            Modifier.padding(top = 30.dp).size(112.dp).liquidGlass(CircleShape, tint = Color.White, clear = true, shadowElevation = 18.dp).clickable(enabled = !isBusy, onClick = onAction),
            contentAlignment = Alignment.Center,
        ) {
            if (isBusy) CircularProgressIndicator(color = Color.White.copy(alpha = .88f), strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
            else Icon(actionIcon, actionDescription, tint = Color.White.copy(alpha = .93f), modifier = Modifier.size(36.dp))
        }
        if (isBusy && loadingStatus.isNotEmpty()) Text(loadingStatus, color = Color.White.copy(alpha = .55f), fontSize = 11.sp, modifier = Modifier.padding(top = 12.dp))
    }
}

/**
 * Each mode now shows its own symbol instead of the three identical green circles, so the intro
 * pager tells the modes apart at a glance.
 */
@Composable
private fun ModeGlyph(icon: androidx.compose.ui.graphics.vector.ImageVector, accent: Color) {
    Box(Modifier.size(98.dp), contentAlignment = Alignment.Center) {
        Icon(icon, null, Modifier.size(62.dp), tint = accent.copy(alpha = .94f))
    }
}

@Composable
private fun EditorScreen(
    state: AppUiState,
    viewModel: LingdongViewModel,
    onAdd: () -> Unit,
    onSave: () -> Unit,
    onSettings: () -> Unit,
    onModeSelection: () -> Unit,
    onEnterTicketLandscape: () -> Unit,
    onEditCopy: () -> Unit,
    onOpenMotionCardSampler: () -> Unit,
    onOpenTicketSampler: () -> Unit,
    onOpenTicketStudio: () -> Unit,
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
            CreationMode.TravelTicket -> 270.dp
            CreationMode.MotionCard -> if (state.preferences.templateStyle == ArtworkTemplateStyle.Immersive) 128.dp else 184.dp
            else -> 128.dp
        }
        val canvasWidth = when (state.mode) {
            CreationMode.SpectrumWallpaper -> minOf(maxWidth - 96.dp, maxWidth * .686f)
            else -> minOf(availableWidth, (maxHeight - reserve) * ratio)
        }.coerceAtLeast(
            when {
                state.mode == CreationMode.MotionCard && state.preferences.templateStyle != ArtworkTemplateStyle.Immersive -> {
                    if (maxWidth > 340.dp) 260.dp else maxWidth - 48.dp
                }
                maxWidth > 340.dp -> 280.dp
                else -> maxWidth - 24.dp
            }
        )
        val canvasHeight = canvasWidth / ratio
        val showsMotionPlayback = state.mode != CreationMode.PrivacyMosaic &&
            state.mode != CreationMode.TravelTicket &&
            state.preferences.supportsMotionPhotos &&
            state.photos.any { it.isMotionPhoto }

        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("灵动照片", fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f), color = Color.Black.copy(alpha = if (state.preferences.showAppTitle) 1f else 0f))
                if (state.mode == CreationMode.TravelTicket) {
                    LiquidIconButton(
                        Icons.Default.ScreenRotation,
                        "横屏预览",
                        {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            onEnterTicketLandscape()
                        },
                    )
                }
                LiquidIconButton(Icons.Default.GridView, "选择创作模式", { haptics.performHapticFeedback(HapticFeedbackType.LongPress); onModeSelection() })
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
            val isTicket = state.mode == CreationMode.TravelTicket
            if (isTicket) Spacer(Modifier.weight(1f))
            ArtworkCanvas(
                state,
                exporting = state.isExporting,
                modifier = Modifier
                    .padding(top = if (isTicket) 0.dp else if (showsMotionPlayback) 12.dp else 20.dp)
                    .width(canvasWidth)
                    .height(canvasHeight)
                    .onGloballyPositioned { onCanvasBounds(it.boundsInRoot()) }
                    .then(gestureModifier)
                    // A drop shadow would print a rectangular halo around the ticket's cut-outs.
                    .then(
                        if (isTicket) Modifier
                        else Modifier.shadow(22.dp, RoundedCornerShape(22.dp), ambientColor = Color.Black.copy(alpha = .12f))
                    ),
                onPaletteOffset = viewModel::setPaletteOffset,
                onTogglePrivacyMask = viewModel::togglePrivacyMask,
                onCycleFont = { direction -> haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.cycleFont(direction) },
                onAdjustTextScale = { delta -> haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.adjustTextScale(delta) },
                onBubbleScale = viewModel::setBubbleScale,
            )
            if (state.mode == CreationMode.MotionCard && state.preferences.templateStyle != ArtworkTemplateStyle.Immersive) {
                MotionCardSamplingControls(
                    hasSelection = state.motionCardSamplingRect != null,
                    onOpen = onOpenMotionCardSampler,
                    onReset = viewModel::resetMotionCardSampling,
                    modifier = Modifier.width(canvasWidth).padding(top = 12.dp),
                )
            }
            if (isTicket) {
                MotionCardSamplingControls(
                    hasSelection = state.ticketSamplingRect != null,
                    onOpen = onOpenTicketSampler,
                    onReset = viewModel::resetTicketSampling,
                    modifier = Modifier.width(canvasWidth).padding(top = 10.dp),
                )
            }
            if (state.mode == CreationMode.PrivacyMosaic) {
                PrivacyControls(state, viewModel, Modifier.padding(horizontal = 18.dp, vertical = 12.dp))
            }
            if (state.mode == CreationMode.Journal) {
                JournalControls(state, viewModel, onReplaceJournal, Modifier.padding(horizontal = 18.dp, vertical = 10.dp))
            }
            if (isTicket) {
                TicketEditorControls(
                    state = state,
                    onLayout = viewModel::setTicketLayout,
                    onWidth = viewModel::setTicketCanvasWidth,
                    onCodeStyle = viewModel::setTicketCodeStyle,
                    onOpenStudio = onOpenTicketStudio,
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
                )
            }
            Spacer(Modifier.weight(1f))
        }
    }
}

@Composable
private fun LandscapeTicketEditor(
    state: AppUiState,
    viewModel: LingdongViewModel,
    onExitLandscape: () -> Unit,
    onAdd: () -> Unit,
    onSave: () -> Unit,
    onSettings: () -> Unit,
    onModeSelection: () -> Unit,
    onEditCopy: () -> Unit,
    onOpenTicketStudio: () -> Unit,
    onCanvasBounds: (androidx.compose.ui.geometry.Rect) -> Unit,
) {
    BackHandler(onBack = onExitLandscape)
    val haptics = LocalHapticFeedback.current
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        val ratio = state.ratio.valueFor(state.photos.firstOrNull()?.bitmap)
        val controlsWidth = minOf(270.dp, maxOf(220.dp, maxWidth * .27f))
        val previewAreaWidth = (maxWidth - controlsWidth - 14.dp).coerceAtLeast(320.dp)
        val previewAreaHeight = (maxHeight - 56.dp).coerceAtLeast(190.dp)
        val canvasWidth = minOf(previewAreaWidth, previewAreaHeight * ratio)
        val canvasHeight = canvasWidth / ratio
        val gestureModifier = canvasGestureModifier(
            state,
            viewModel,
            onEditCopy,
            canvasWidth,
            canvasHeight,
        )

        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                Modifier.fillMaxWidth().height(48.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                GlassContainer(
                    Modifier
                        .width(112.dp)
                        .height(42.dp)
                        .clickable {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            onExitLandscape()
                        },
                    cornerRadius = 21.dp,
                ) {
                    Row(
                        Modifier.padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(7.dp),
                    ) {
                        Icon(Icons.Default.ScreenRotation, null, Modifier.size(17.dp))
                        Text("返回竖屏", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text("影像票根", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Text(
                        "手动横屏预览",
                        color = Color.Black.copy(alpha = .50f),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
                Spacer(Modifier.weight(1f))
                LiquidIconButton(
                    Icons.Default.GridView,
                    "选择创作模式",
                    {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onModeSelection()
                    },
                    size = 42.dp,
                )
                LiquidIconButton(
                    Icons.Default.Add,
                    "添加照片",
                    {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onAdd()
                    },
                    size = 42.dp,
                )
                LiquidIconButton(
                    Icons.Default.ArrowDownward,
                    "保存照片",
                    {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onSave()
                    },
                    size = 42.dp,
                )
                LiquidIconButton(
                    Icons.Outlined.Settings,
                    "设置",
                    {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onSettings()
                    },
                    size = 42.dp,
                )
            }

            Row(
                Modifier.fillMaxWidth().weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Box(
                    Modifier
                        .width(previewAreaWidth)
                        .fillMaxHeight(),
                    contentAlignment = Alignment.Center,
                ) {
                    ArtworkCanvas(
                        state,
                        exporting = state.isExporting,
                        modifier = Modifier
                            .width(canvasWidth)
                            .height(canvasHeight)
                            .onGloballyPositioned { onCanvasBounds(it.boundsInRoot()) }
                            .then(gestureModifier),
                        onPaletteOffset = viewModel::setPaletteOffset,
                        onTogglePrivacyMask = viewModel::togglePrivacyMask,
                        onCycleFont = { direction ->
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            viewModel.cycleFont(direction)
                        },
                        onAdjustTextScale = { delta ->
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            viewModel.adjustTextScale(delta)
                        },
                        onBubbleScale = viewModel::setBubbleScale,
                    )
                }

                TicketEditorControls(
                    state = state,
                    onLayout = viewModel::setTicketLayout,
                    onWidth = viewModel::setTicketCanvasWidth,
                    onCodeStyle = viewModel::setTicketCodeStyle,
                    onOpenStudio = onOpenTicketStudio,
                    modifier = Modifier.width(controlsWidth),
                    isLandscape = true,
                )
            }
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
            // A 21:9 ticket can exactly consume a landscape photo's horizontal pixels at 1x.
            // Give a deliberate horizontal drag a small amount of overscan so it always changes
            // the composition instead of appearing broken on wide Android displays.
            val horizontalTicketPan = state.mode == CreationMode.TravelTicket &&
                state.preferences.ticketLayout == TicketLayoutStyle.Classic &&
                abs(pan.x) > .5f
            val minimumScale = if (horizontalTicketPan) 1.12f else 1f
            val scale = (state.imageScale * zoom).coerceIn(minimumScale, 4f)
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
            if (state.mode == CreationMode.MotionCard ||
                state.mode == CreationMode.BubbleStamp ||
                state.mode == CreationMode.Journal ||
                state.mode == CreationMode.TravelTicket
            ) {
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
                            CreationMode.TravelTicket -> {
                                val hitsText = when (state.preferences.ticketLayout) {
                                    TicketLayoutStyle.Classic -> point.x < widthPx * .44f
                                    TicketLayoutStyle.Vertical -> point.y > heightPx * .50f
                                    TicketLayoutStyle.Minimal -> point.y > heightPx * .58f
                                }
                                if (hitsText) onEditCopy()
                            }
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
private fun PublicGoodsCommitmentDialog(
    showsUpdateNext: Boolean,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current

    fun copyValue(label: String, value: String, success: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText(label, value))
        Toast.makeText(context, success, Toast.LENGTH_SHORT).show()
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            dismissOnBackPress = false,
            dismissOnClickOutside = false,
            usePlatformDefaultWidth = false,
        ),
    ) {
        Box(
            Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(.88f)
                    .widthIn(max = 520.dp)
                    .shadow(28.dp, RoundedCornerShape(32.dp)),
                shape = RoundedCornerShape(32.dp),
                color = Color(0xFFF9F9F7),
                tonalElevation = 0.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    Column(
                        Modifier
                            .weight(1f)
                            .verticalScroll(rememberScrollState())
                            .padding(start = 24.dp, end = 24.dp, top = 27.dp, bottom = 18.dp),
                        verticalArrangement = Arrangement.spacedBy(22.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Text(
                                "灵动照片 · 开源项目",
                                color = Color.Black.copy(alpha = .52f),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Text(
                                "致力于纯粹的数字公共品",
                                color = Color(0xFF171717),
                                fontSize = 27.sp,
                                lineHeight = 34.sp,
                                fontWeight = FontWeight.Bold,
                            )
                            Text(
                                "透明、开放，并以长期维护为目标。",
                                color = Color.Black.copy(alpha = .58f),
                                fontSize = 14.sp,
                                lineHeight = 21.sp,
                            )
                        }

                        Column(verticalArrangement = Arrangement.spacedBy(17.dp)) {
                            UpdateLogItem(
                                number = 1,
                                title = "开放，而非设立围墙",
                                detail = "灵动照片不仅是一款照片创作工具，也是一个透明、开放、持续维护的开源项目。项目不依靠出售用户数据或设置付费墙维持运行。",
                            )
                            UpdateLogItem(
                                number = 2,
                                title = "持续的维护与托管",
                                detail = "Wenzhou Dulan Network Technology Co., Ltd. 为项目持续提供资金、研发资源与托管支持，让团队可以专注于长期维护、隐私保护与体验改进，减少短期商业变现对产品方向的影响。",
                            )
                            UpdateLogItem(
                                number = 3,
                                title = "本地处理与开源守护",
                                detail = "项目源代码持续公开；照片识别、色彩分析与作品渲染均在设备本地完成。稳定的资源支持保障长期迭代，开源机制守护用户的知情权与创作自由。",
                            )
                            PublicGoodsContactRow(
                                icon = Icons.Outlined.People,
                                title = "QQ 用户交流群",
                                value = "群号 1050047342",
                                detail = "遇到问题或想交流时欢迎加入",
                            ) { copyValue("QQ 用户交流群", "1050047342", "群号已复制，请在 QQ 中搜索添加") }
                            PublicGoodsContactRow(
                                icon = Icons.Outlined.Email,
                                title = "客服邮箱",
                                value = "help@locallens.cn",
                                detail = "有问题或建议可随时邮件联系",
                            ) { copyValue("客服邮箱", "help@locallens.cn", "邮箱已复制") }
                        }
                    }

                    Box(
                        Modifier
                            .fillMaxWidth()
                            .background(Color(0xFFF9F9F7))
                            .padding(start = 22.dp, end = 22.dp, top = 10.dp, bottom = 16.dp),
                    ) {
                        Button(
                            onClick = onDismiss,
                            modifier = Modifier.fillMaxWidth().height(52.dp),
                            shape = CircleShape,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF171717),
                                contentColor = Color.White,
                            ),
                        ) {
                            Text(
                                if (showsUpdateNext) "查看更新内容" else "开始使用",
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PublicGoodsContactRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    value: String,
    detail: String,
    onCopy: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color.Black.copy(alpha = .045f))
            .clickable(onClick = onCopy)
            .padding(14.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Icon(icon, null, Modifier.size(24.dp), tint = Color.Black.copy(alpha = .76f))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, color = Color(0xFF171717), fontSize = 15.sp, fontWeight = FontWeight.Bold)
            Text("$value · $detail", color = Color.Black.copy(alpha = .57f), fontSize = 12.sp, lineHeight = 18.sp)
        }
        Text("复制", color = Color(0xFF007AFF), fontSize = 12.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun Version200UpdateDialog(onDismiss: () -> Unit) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            dismissOnBackPress = false,
            dismissOnClickOutside = false,
            usePlatformDefaultWidth = false,
        ),
    ) {
        Box(
            Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(.88f)
                    .widthIn(max = 520.dp)
                    .shadow(28.dp, RoundedCornerShape(32.dp)),
                shape = RoundedCornerShape(32.dp),
                color = Color(0xFFF9F9F7),
                tonalElevation = 0.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    Column(
                        Modifier
                            .weight(1f)
                            .verticalScroll(rememberScrollState())
                            .padding(start = 24.dp, end = 24.dp, top = 27.dp, bottom = 18.dp),
                        verticalArrangement = Arrangement.spacedBy(22.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Text(
                                "灵动照片 2.0.0（Build 202608）",
                                color = Color.Black.copy(alpha = .52f),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Text(
                                "让每一张照片拥有更多表达",
                                color = Color(0xFF171717),
                                fontSize = 27.sp,
                                lineHeight = 34.sp,
                                fontWeight = FontWeight.Bold,
                            )
                            Text(
                                "本次更新新增灵动卡片与影像票根局部取色、影像票根时光胶囊文案、横向票根宽度选择、影像相簿与色彩关系功能，并带来部分界面优化与稳定性提升。Android 端影像素描因机型众多、适配较难，暂缓上线，可随时关注官网与 GitHub。",
                                color = Color.Black.copy(alpha = .58f),
                                fontSize = 14.sp,
                                lineHeight = 21.sp,
                            )
                        }

                        Column(verticalArrangement = Arrangement.spacedBy(17.dp)) {
                            UpdateLogItem(
                                number = 1,
                                title = "灵动卡片与影像票根新增“局部取色”",
                                detail = "可框选照片中的指定区域单独提取颜色，生成更精准的背景与色盘效果，也可以随时调整选区或恢复整图取色。",
                            )
                            UpdateLogItem(
                                number = 2,
                                title = "影像票根新增“时光胶囊”文案",
                                detail = "扫描票根时可选择“时光胶囊”叙事风格，并区分“写给未来的我”与“分享给朋友”两种视角。",
                            )
                            UpdateLogItem(
                                number = 3,
                                title = "横向票根新增宽度选择",
                                detail = "横向经典版式新增紧凑、标准、海报三档宽度，适配日常分享与收藏展示等不同场景。",
                            )
                            UpdateLogItem(
                                number = 4,
                                title = "新增“影像相簿”功能",
                                detail = "选择模板与成书尺寸，加入普通照片或灵动作品，整本预览后可直接生成可打印 PDF 文件。",
                            )
                            UpdateLogItem(
                                number = 5,
                                title = "新增“色彩关系”功能",
                                detail = "一次选择两张照片，从共鸣、对照与过渡三种方式观察共同色、色彩距离和连接色阶。支持自适应双图布局、液态玻璃色带，以及高清或原图级对比图与完整作品导出。Motion Photo 在此功能中只读取系统提供的静态画面。",
                            )
                            UpdateLogItem(
                                number = 6,
                                title = "影像素描暂缓上线",
                                detail = "Android 端影像素描因机型众多、适配较难，暂缓上线，可随时关注官网与 GitHub。",
                            )
                            UpdateLogItem(
                                number = 7,
                                title = "部分界面优化与稳定性提升",
                                detail = "优化部分界面细节与交互体验，修复若干已知问题，提升整体运行稳定性。",
                            )
                        }
                    }

                    Box(
                        Modifier
                            .fillMaxWidth()
                            .background(Color(0xFFF9F9F7))
                            .padding(start = 22.dp, end = 22.dp, top = 10.dp, bottom = 16.dp),
                    ) {
                        Button(
                            onClick = onDismiss,
                            modifier = Modifier.fillMaxWidth().height(52.dp),
                            shape = CircleShape,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF171717),
                                contentColor = Color.White,
                            ),
                        ) {
                            Text("下一步", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun UpdateLogItem(number: Int, title: String, detail: String) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Box(
            Modifier.size(30.dp).background(Color.Black.copy(alpha = .065f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                number.toString(),
                color = Color.Black.copy(alpha = .78f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        Column(
            Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                title,
                color = Color(0xFF171717),
                fontSize = 16.sp,
                lineHeight = 22.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                detail,
                color = Color.Black.copy(alpha = .57f),
                fontSize = 13.sp,
                lineHeight = 20.sp,
            )
        }
    }
}
