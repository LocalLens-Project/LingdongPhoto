package cn.locallens.lingdongzhaopian

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
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
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Compare
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.SwapHoriz
import androidx.compose.material.icons.outlined.SwapVert
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.max
import kotlin.math.roundToInt

private enum class RelationshipExportKind { Comparison, Full }
private enum class RelationshipExportQuality(val label: String) { HD("高清"), Original("原图级") }
private data class RelationshipExportRequest(val kind: RelationshipExportKind, val quality: RelationshipExportQuality, val id: Int)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ColorRelationshipScreen(
    onOpenModeSelection: () -> Unit,
    onClose: () -> Unit,
    onExport: (Rect, ExportDimensions, String) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var photos by remember { mutableStateOf<List<RelationshipPhoto>>(emptyList()) }
    var relationship by remember { mutableStateOf<ColorRelationship?>(null) }
    var lens by remember { mutableStateOf(RelationshipLens.Resonance) }
    var loading by remember { mutableStateOf(false) }
    var settingsShown by remember { mutableStateOf(false) }
    var exportShown by remember { mutableStateOf(false) }
    var includesLabels by remember { mutableStateOf(true) }
    var exportQuality by remember { mutableStateOf(RelationshipExportQuality.HD) }
    var comparisonBounds by remember { mutableStateOf(Rect.Zero) }
    var fullBounds by remember { mutableStateOf(Rect.Zero) }
    var exportRequest by remember { mutableStateOf<RelationshipExportRequest?>(null) }
    var requestID by remember { mutableIntStateOf(0) }
    var savedVisible by remember { mutableStateOf(false) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(2)) { uris ->
        if (uris.size != 2) {
            if (uris.isNotEmpty()) Toast.makeText(context, "请选择两张照片", Toast.LENGTH_SHORT).show()
            return@rememberLauncherForActivityResult
        }
        scope.launch {
            loading = true
            val loaded = withContext(Dispatchers.IO) { uris.mapNotNull { RelationshipStaticPhotoLoader.load(context, it) } }
            if (loaded.size == 2) {
                photos.forEach { if (!it.bitmap.isRecycled) it.bitmap.recycle() }
                photos = loaded
                relationship = withContext(Dispatchers.Default) {
                    ColorRelationshipAnalyzer.analyze(loaded[0].bitmap, loaded[1].bitmap)
                }
            } else {
                loaded.forEach { if (!it.bitmap.isRecycled) it.bitmap.recycle() }
                Toast.makeText(context, "有一张照片无法读取", Toast.LENGTH_SHORT).show()
            }
            loading = false
        }
    }
    fun openPicker() = picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))

    BackHandler(onBack = onClose)

    LaunchedEffect(exportRequest) {
        val request = exportRequest ?: return@LaunchedEffect
        delay(260)
        val bounds = if (request.kind == RelationshipExportKind.Comparison) comparisonBounds else fullBounds
        if (bounds.width <= 0 || bounds.height <= 0) return@LaunchedEffect
        val aspect = bounds.width / bounds.height
        val dimensions = relationshipExportDimensions(photos, aspect, request.kind, request.quality)
        onExport(bounds, dimensions, if (request.kind == RelationshipExportKind.Comparison) "色彩关系-对比图" else "色彩关系-完整作品")
        savedVisible = true
        // Keep the export-only label state alive while MainActivity records the GPU display list.
        delay(520)
        exportRequest = null
        delay(1450)
        savedVisible = false
    }

    val palette = relationship?.let { it.leftPalette + it.rightPalette }.orEmpty()
    Box(Modifier.fillMaxSize()) {
        RelationshipAmbientBackground(palette)

        if (photos.size == 2 && relationship != null) {
            val current = relationship!!
            Column(Modifier.fillMaxSize().padding(top = 22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                RelationshipToolbar(
                    onMode = onOpenModeSelection,
                    onAdd = ::openPicker,
                    onDownload = { exportShown = true },
                    onSettings = { settingsShown = true },
                )
                Spacer(Modifier.height(18.dp))
                BoxWithConstraints(Modifier.fillMaxWidth().weight(1f)) {
                    val canvasWidth = maxWidth - 32.dp
                    Column(
                        Modifier
                            .width(canvasWidth)
                            .align(Alignment.TopCenter)
                            .onGloballyPositioned { fullBounds = it.boundsInRoot() },
                    ) {
                        RelationshipMedia(
                            photos = photos,
                            relationship = current,
                            lens = lens,
                            showLabels = includesLabels || exportRequest?.kind != RelationshipExportKind.Comparison,
                            modifier = Modifier.onGloballyPositioned { comparisonBounds = it.boundsInRoot() },
                        )
                        RelationshipCopyBlock(current, lens)
                    }
                }
                GlassContainer(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp).height(48.dp).clickable { settingsShown = true },
                    cornerRadius = 24.dp,
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(Icons.Outlined.AutoAwesome, null, Modifier.size(18.dp), tint = Color.Black.copy(alpha = .78f))
                        Text("观察方式：${lens.label}", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
                Spacer(Modifier.height(18.dp))
            }
        } else {
            RelationshipWelcome(onOpenModeSelection, { settingsShown = true }, ::openPicker)
        }

        if (loading) {
            Column(
                Modifier.align(Alignment.Center).clip(RoundedCornerShape(20.dp)).background(Color.Black.copy(alpha = .72f)).padding(22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CircularProgressIndicator(Modifier.size(26.dp), color = Color.White, strokeWidth = 2.dp)
                Text("正在寻找两张照片的共同色…", color = Color.White, fontSize = 12.sp)
            }
        }

        AnimatedVisibility(
            visible = savedVisible,
            modifier = Modifier.align(Alignment.TopCenter).padding(top = 72.dp),
            enter = fadeIn() + scaleIn(initialScale = .86f, animationSpec = spring()),
            exit = fadeOut() + scaleOut(targetScale = .86f),
        ) {
            GlassContainer(Modifier.height(42.dp), cornerRadius = 21.dp) {
                Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    Icon(Icons.Default.Check, null, Modifier.size(17.dp))
                    Text("已开始保存到照片", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }

    if (settingsShown) {
        val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { settingsShown = false }, sheetState = sheet, dragHandle = null,
            containerColor = Color(0xFFF2F2F7).copy(alpha = .97f), shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
        ) {
            RelationshipSettings(
                lens = lens,
                hasPhotos = photos.size == 2,
                onLens = { lens = it },
                onChoose = { settingsShown = false; openPicker() },
                onSwap = {
                    if (photos.size == 2) {
                        photos = listOf(photos[1], photos[0])
                        relationship = ColorRelationshipAnalyzer.analyze(photos[0].bitmap, photos[1].bitmap)
                    }
                    settingsShown = false
                },
            )
        }
    }

    if (exportShown) {
        val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { exportShown = false }, sheetState = sheet, dragHandle = null,
            containerColor = Color(0xFFF2F2F7).copy(alpha = .97f), shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
        ) {
            RelationshipExportOptions(
                includesLabels = includesLabels,
                quality = exportQuality,
                onLabels = { includesLabels = it },
                onQuality = { exportQuality = it },
                onExport = { kind ->
                    requestID += 1
                    exportRequest = RelationshipExportRequest(kind, exportQuality, requestID)
                    exportShown = false
                },
            )
        }
    }
}

@Composable
private fun RelationshipToolbar(onMode: () -> Unit, onAdd: () -> Unit, onDownload: () -> Unit, onSettings: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("灵动照片", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            RelationshipCircleButton(Icons.Default.GridView, "模式", onMode)
            RelationshipCircleButton(Icons.Default.Add, "选择两张照片", onAdd)
            RelationshipCircleButton(Icons.Default.ArrowDownward, "导出", onDownload)
            RelationshipCircleButton(Icons.Outlined.Settings, "设置", onSettings)
        }
    }
}

@Composable
private fun RelationshipCircleButton(icon: androidx.compose.ui.graphics.vector.ImageVector, description: String, onClick: () -> Unit) {
    GlassContainer(Modifier.size(48.dp).clickable(onClick = onClick), cornerRadius = 24.dp) {
        Icon(icon, description, Modifier.size(23.dp), tint = Color.Black.copy(alpha = .88f))
    }
}

@Composable
private fun RelationshipWelcome(onMode: () -> Unit, onSettings: () -> Unit, onPick: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(top = 22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("灵动照片", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = .94f))
            Spacer(Modifier.weight(1f))
            RelationshipCircleButton(Icons.Default.GridView, "模式", onMode)
            Spacer(Modifier.width(8.dp))
            RelationshipCircleButton(Icons.Outlined.Settings, "设置", onSettings)
        }
        Spacer(Modifier.weight(1f))
        Icon(Icons.Outlined.Compare, null, Modifier.size(54.dp), tint = Color.White.copy(alpha = .9f))
        Spacer(Modifier.height(40.dp))
        Text("色彩关系", fontFamily = FontFamily.Serif, fontSize = 26.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = .95f))
        Text("选择两张照片\n看看色彩如何在它们之间相遇", Modifier.padding(top = 10.dp), color = Color.White.copy(alpha = .48f), fontSize = 13.sp, lineHeight = 20.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(48.dp))
        GlassContainer(Modifier.size(112.dp).clickable(onClick = onPick), cornerRadius = 56.dp) {
            Icon(Icons.Default.Add, "选择两张照片", Modifier.size(36.dp), tint = Color.White.copy(alpha = .92f))
        }
        Spacer(Modifier.weight(2f))
    }
}

@Composable
private fun RelationshipMedia(
    photos: List<RelationshipPhoto>, relationship: ColorRelationship, lens: RelationshipLens,
    showLabels: Boolean, modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val width = maxWidth
        val stacked = photos.all { it.isLandscape }
        val bothPortrait = photos.all { it.isPortrait }
        val leftWidth = if (stacked) width else if (bothPortrait) width / 2 else width * if (photos[0].isPortrait) .44f else .56f
        val rightWidth = if (stacked) width else width - leftWidth
        val firstHeight = if (stacked) width / photos[0].aspectRatio else leftWidth / photos[0].aspectRatio
        val secondHeight = if (stacked) width / photos[1].aspectRatio else rightWidth / photos[1].aspectRatio
        val mediaHeight = if (stacked) firstHeight + secondHeight else maxOf(firstHeight, secondHeight)
        val glassHeight = 100.dp
        val glassWidth = width * .84f
        val glassLeft = (width - glassWidth) / 2
        val glassCenterY = if (stacked) firstHeight else mediaHeight * .86f
        val glassTop = (glassCenterY - glassHeight / 2).coerceIn(0.dp, mediaHeight - glassHeight)

        Box(Modifier.fillMaxWidth().height(mediaHeight)) {
            RelationshipPhotoLayout(
                photos, stacked, leftWidth, rightWidth, firstHeight, secondHeight, mediaHeight,
                relationship.leftPalette.first().color.color,
                relationship.rightPalette.first().color.color,
            )

            PaletteRefractedBackdrop(
                Modifier.offset(x = glassLeft, y = glassTop).width(glassWidth).height(glassHeight).clip(RoundedCornerShape(22.dp)),
            ) {
                Box(
                    Modifier.wrapContentSize(Alignment.TopStart, unbounded = true)
                        .offset { IntOffset(-glassLeft.roundToPx(), -glassTop.roundToPx()) }
                        .requiredSize(width, mediaHeight),
                ) {
                    RelationshipPhotoLayout(
                        photos, stacked, leftWidth, rightWidth, firstHeight, secondHeight, mediaHeight,
                        relationship.leftPalette.first().color.color,
                        relationship.rightPalette.first().color.color,
                    )
                }
            }
            RelationshipGlassContent(
                relationship, lens,
                Modifier.offset(x = glassLeft, y = glassTop).width(glassWidth).height(glassHeight)
                    .paletteClearGlassSurface(relationship.resonancePairs.first().middle.color.color),
            )

            if (showLabels) {
                PhotoIndex("01", Modifier.align(Alignment.TopStart).padding(14.dp))
                if (stacked) {
                    PhotoIndex("02", Modifier.align(Alignment.BottomStart).padding(14.dp))
                } else {
                    PhotoIndex("02", Modifier.offset(x = leftWidth).padding(14.dp))
                }
            }
        }
    }
}

@Composable
private fun BoxScope.RelationshipPhotoLayout(
    photos: List<RelationshipPhoto>, stacked: Boolean,
    leftWidth: androidx.compose.ui.unit.Dp, rightWidth: androidx.compose.ui.unit.Dp,
    firstHeight: androidx.compose.ui.unit.Dp, secondHeight: androidx.compose.ui.unit.Dp,
    mediaHeight: androidx.compose.ui.unit.Dp,
    firstBg: Color,
    secondBg: Color,
) {
    if (stacked) {
        PhotoCell(photos[0].bitmap, firstBg, Modifier.fillMaxWidth().height(firstHeight).align(Alignment.TopCenter))
        PhotoCell(photos[1].bitmap, secondBg, Modifier.fillMaxWidth().height(secondHeight).align(Alignment.BottomCenter))
    } else {
        PhotoCell(photos[0].bitmap, firstBg, Modifier.width(leftWidth).height(mediaHeight).align(Alignment.CenterStart))
        PhotoCell(photos[1].bitmap, secondBg, Modifier.width(rightWidth).height(mediaHeight).align(Alignment.CenterEnd))
    }
}

@Composable
private fun PhotoCell(bitmap: Bitmap, background: Color, modifier: Modifier) {
    Box(modifier.background(background), contentAlignment = Alignment.Center) {
        Image(bitmap.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = androidx.compose.ui.layout.ContentScale.Fit)
    }
}

@Composable
private fun PhotoIndex(value: String, modifier: Modifier) {
    Box(modifier.clip(RoundedCornerShape(18.dp)).background(Color.Black.copy(alpha = .31f)).padding(horizontal = 14.dp, vertical = 7.dp)) {
        Text(value, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
    }
}

@Composable
private fun RelationshipGlassContent(relationship: ColorRelationship, lens: RelationshipLens, modifier: Modifier) {
    val pairs = when (lens) {
        RelationshipLens.Resonance -> relationship.resonancePairs.take(4)
        RelationshipLens.Contrast -> relationship.contrastPairs.take(4)
        RelationshipLens.Bridge -> (0..3).map { index ->
            val start = relationship.bridge[index]
            val end = relationship.bridge[index + 3]
            RelationshipPair(start, end, 0.0)
        }
    }
    val backgroundLight = pairs.flatMap { listOf(it.left.lightness, it.right.lightness) }.average()
    val foreground = if (backgroundLight > .62) Color.Black.copy(alpha = .76f) else Color.White.copy(alpha = .90f)
    Row(modifier.padding(horizontal = 16.dp, vertical = 13.dp), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
        pairs.forEach { pair ->
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy((-5).dp)) {
                    Box(Modifier.size(27.dp).background(pair.left.color.color, CircleShape))
                    Box(Modifier.size(27.dp).background(pair.right.color.color, CircleShape))
                }
                Text(pair.middle.hex, color = foreground, fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
            }
        }
    }
}

@Composable
private fun RelationshipCopyBlock(relationship: ColorRelationship, lens: RelationshipLens) {
    val copy = relationship.narratives.getValue(lens)
    Column(Modifier.fillMaxWidth().padding(start = 28.dp, end = 28.dp, top = 34.dp, bottom = 20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(copy.title, fontFamily = FontFamily.Serif, fontSize = 27.sp, fontWeight = FontWeight.Bold, color = Color.Black.copy(alpha = .82f))
            Spacer(Modifier.weight(1f))
            Text(lens.label, Modifier.clip(CircleShape).background(Color.Black.copy(alpha = .08f)).padding(horizontal = 16.dp, vertical = 9.dp), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.Black.copy(alpha = .67f))
        }
        Text(copy.body, Modifier.padding(top = 11.dp), fontSize = 14.sp, lineHeight = 21.sp, fontWeight = FontWeight.Medium, color = Color.Black.copy(alpha = .76f))
        Row(Modifier.fillMaxWidth().padding(top = 15.dp)) {
            Metric("色彩亲近", relationship.affinity, Modifier.weight(1f))
            Metric("明暗距离", relationship.lightDifference, Modifier.weight(1f))
            Metric("冷暖距离", relationship.temperatureDifference, Modifier.weight(1f))
        }
    }
}

@Composable
private fun Metric(title: String, value: Int, modifier: Modifier) {
    Column(modifier) {
        Text(title, fontSize = 10.sp, color = Color.Black.copy(alpha = .43f))
        Text("%02d".format(value.coerceIn(0, 99)), fontSize = 20.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = Color.Black.copy(alpha = .80f))
    }
}

@Composable
private fun RelationshipSettings(
    lens: RelationshipLens, hasPhotos: Boolean, onLens: (RelationshipLens) -> Unit, onChoose: () -> Unit, onSwap: () -> Unit,
) {
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("色彩关系", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text("选择观察方式", fontSize = 12.sp, color = Color.Black.copy(alpha = .5f))
        RelationshipLens.entries.forEach { item ->
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(if (item == lens) Color.White else Color.Black.copy(alpha = .035f)).clickable { onLens(item) }.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(if (item == RelationshipLens.Contrast) Icons.Outlined.Compare else if (item == RelationshipLens.Bridge) Icons.Outlined.SwapVert else Icons.Outlined.AutoAwesome, null, Modifier.size(21.dp))
                Column(Modifier.weight(1f).padding(start = 13.dp)) {
                    Text(item.label, fontWeight = FontWeight.Bold)
                    Text(when (item) {
                        RelationshipLens.Resonance -> "寻找两张照片最接近、最容易彼此回应的颜色"
                        RelationshipLens.Contrast -> "观察两张照片距离最远、张力最明显的颜色"
                        RelationshipLens.Bridge -> "生成一条从图 1 逐渐走向图 2 的过渡路径"
                    }, fontSize = 11.sp, lineHeight = 16.sp, color = Color.Black.copy(alpha = .52f))
                }
                if (item == lens) Icon(Icons.Default.Check, null, tint = Color(0xFF007AFF))
            }
        }
        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White).padding(16.dp)) {
            Text("色条中每一组颜色，左边来自图 1，右边来自图 2。HEX 是这一组中间色的数值。", fontSize = 12.sp, lineHeight = 18.sp, color = Color.Black.copy(alpha = .62f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            TextButton(onClick = onChoose, Modifier.weight(1f).background(Color.White, RoundedCornerShape(18.dp))) { Text(if (hasPhotos) "重新选择" else "选择两张照片") }
            if (hasPhotos) TextButton(onClick = onSwap, Modifier.weight(1f).background(Color.White, RoundedCornerShape(18.dp))) {
                Icon(Icons.Outlined.SwapHoriz, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text("交换图 1 / 图 2")
            }
        }
        Spacer(Modifier.height(18.dp))
    }
}

@Composable
private fun RelationshipExportOptions(
    includesLabels: Boolean, quality: RelationshipExportQuality,
    onLabels: (Boolean) -> Unit, onQuality: (RelationshipExportQuality) -> Unit,
    onExport: (RelationshipExportKind) -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("保存色彩关系", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(15.dp)).background(Color.Black.copy(alpha = .055f)).padding(3.dp)) {
            RelationshipExportQuality.entries.forEach { item ->
                Box(Modifier.weight(1f).height(38.dp).clip(RoundedCornerShape(12.dp)).background(if (quality == item) Color.White else Color.Transparent).clickable { onQuality(item) }, contentAlignment = Alignment.Center) {
                    Text(item.label, fontSize = 13.sp, fontWeight = if (quality == item) FontWeight.Bold else FontWeight.Medium)
                }
            }
        }
        Text(if (quality == RelationshipExportQuality.HD) "画布宽度最高 2400 px，适合日常保存与分享" else "按两张静态原图像素生成，画布最长边最高 8192 px", fontSize = 11.sp, color = Color.Black.copy(alpha = .5f))
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text("显示 01 / 02", fontWeight = FontWeight.SemiBold); Text("仅影响对比图，完整作品始终保留编号", fontSize = 11.sp, color = Color.Black.copy(alpha = .48f)) }
            Switch(includesLabels, onCheckedChange = onLabels)
        }
        ExportChoice("保存对比图", "只保存两张照片与交界处的液态玻璃色条", Icons.Outlined.Compare) { onExport(RelationshipExportKind.Comparison) }
        ExportChoice("保存完整作品", "保存照片、色条、关系文案与三项距离", Icons.Outlined.Tune) { onExport(RelationshipExportKind.Full) }
        Text("应用内预览与导出使用相同构图。对比图只截取照片区域，不附加取色背景。", fontSize = 11.sp, lineHeight = 16.sp, color = Color.Black.copy(alpha = .48f))
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun ExportChoice(title: String, detail: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White).clickable(onClick = onClick).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, Modifier.size(24.dp)); Column(Modifier.padding(start = 13.dp)) { Text(title, fontWeight = FontWeight.Bold); Text(detail, fontSize = 11.sp, color = Color.Black.copy(alpha = .5f)) }
    }
}

@Composable
private fun RelationshipAmbientBackground(palette: List<RelationshipColor>) {
    val colors = palette.map { it.color }.ifEmpty { RGBColor.intro }
    Canvas(Modifier.fillMaxSize().background(colors[0].adjusted(.18f).color)) {
        drawRect(Brush.linearGradient(listOf(colors[0].adjusted(.18f).color, colors.getOrElse(5) { colors[0] }.adjusted(.13f).color), Offset.Zero, Offset(size.width, size.height)))
        drawCircle(colors.getOrElse(2) { colors[0] }.color.copy(alpha = .32f), radius = size.width * .72f, center = Offset(size.width * .92f, size.height * .22f))
        drawCircle(colors.getOrElse(7) { colors[0] }.color.copy(alpha = .24f), radius = size.width * .78f, center = Offset(size.width * .08f, size.height * .86f))
        drawRect(Brush.verticalGradient(listOf(Color.White.copy(alpha = .18f), Color.Transparent, Color.Black.copy(alpha = .07f))))
    }
}

private fun relationshipExportDimensions(
    photos: List<RelationshipPhoto>, aspect: Float, kind: RelationshipExportKind, quality: RelationshipExportQuality,
): ExportDimensions {
    val width = if (quality == RelationshipExportQuality.HD) 2400 else {
        val stacked = photos.all { it.isLandscape }
        val sourceCanvasWidth = if (stacked) photos.maxOf { it.sourceWidth } else photos.sumOf { it.sourceWidth }
        val estimated = if (kind == RelationshipExportKind.Full) (sourceCanvasWidth * 1.04).roundToInt() else sourceCanvasWidth
        val maxWidthForLongEdge = if (aspect >= 1f) 8192 else (8192 * aspect).roundToInt()
        estimated.coerceAtMost(maxWidthForLongEdge).coerceAtLeast(1080)
    }
    return ExportDimensions(width, (width / aspect.coerceAtLeast(.05f)).roundToInt().coerceAtLeast(1))
}

private object RelationshipStaticPhotoLoader {
    fun load(context: Context, uri: Uri): RelationshipPhoto? = runCatching {
        var sourceWidth = 0
        var sourceHeight = 0
        val bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { decoder, info, _ ->
            sourceWidth = info.size.width
            sourceHeight = info.size.height
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val longest = max(sourceWidth, sourceHeight)
            if (longest > 2600) {
                val scale = 2600f / longest
                decoder.setTargetSize((sourceWidth * scale).roundToInt().coerceAtLeast(1), (sourceHeight * scale).roundToInt().coerceAtLeast(1))
            }
            decoder.isMutableRequired = false
        }
        RelationshipPhoto(uri, bitmap, sourceWidth.coerceAtLeast(bitmap.width), sourceHeight.coerceAtLeast(bitmap.height))
    }.getOrNull()
}
