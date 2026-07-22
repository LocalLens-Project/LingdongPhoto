package cn.locallens.lingdongzhaopian

import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.BitmapShader
import android.graphics.DashPathEffect
import android.graphics.Shader
import android.graphics.Typeface
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.max
import kotlin.math.abs
import kotlin.math.roundToInt

@Composable
fun ArtworkCanvas(
    state: AppUiState,
    modifier: Modifier = Modifier,
    exporting: Boolean = false,
    onPaletteOffset: (Float) -> Unit = {},
    onTogglePrivacyMask: (Int) -> Unit = {},
    onCycleFont: (Int) -> Unit = {},
    onAdjustTextScale: (Float) -> Unit = {},
    onBubbleScale: (Float) -> Unit = {},
) {
    val corner = when (state.mode) {
        CreationMode.BubbleStamp -> 0.dp
        CreationMode.SpectrumWallpaper -> 28.dp
        else -> 22.dp
    }
    Box(
        modifier = modifier
            .testTag("artwork-${state.mode.name}")
            .clip(RoundedCornerShape(if (exporting) 0.dp else corner))
            .background(Color.White.copy(alpha = .12f)),
    ) {
        when (state.mode) {
            CreationMode.MotionCard -> MotionCardCanvas(state, onCycleFont, onAdjustTextScale)
            CreationMode.ColorPalette -> ColorPaletteCanvas(state, exporting, onPaletteOffset)
            CreationMode.Journal -> JournalCanvas(state, onCycleFont, onAdjustTextScale)
            CreationMode.BubbleStamp -> BubbleStampCanvas(state, onCycleFont, onAdjustTextScale, onBubbleScale)
            CreationMode.SpectrumWallpaper -> SpectrumWallpaperCanvas(state)
            CreationMode.PrivacyMosaic -> PrivacyMosaicCanvas(state, exporting, onTogglePrivacyMask)
        }
    }
}

@Composable
private fun MotionCardCanvas(state: AppUiState, onCycleFont: (Int) -> Unit, onAdjustTextScale: (Float) -> Unit) {
    val photo = state.bitmapAt(0)
    val theme = MotionCardThemeResolver.resolve(state.palette, state.palettePercentages)
    when (state.preferences.templateStyle) {
        ArtworkTemplateStyle.Immersive -> Box(Modifier.fillMaxSize()) {
            ArtworkPhoto(photo, state, Modifier.fillMaxSize())
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(listOf(Color.Transparent, Color.Transparent, Color.Black.copy(alpha = .74f)))
                )
            )
            Column(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth()
                    .splitHorizontalTextGesture(onCycleFont, onAdjustTextScale)
                    .padding(horizontal = 34.dp, vertical = 30.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(state.artworkCopy.title, color = Color.White.copy(alpha = .96f), fontSize = (15 * state.textScale).sp, fontWeight = FontWeight.SemiBold, fontFamily = state.artworkFontFamily, textAlign = TextAlign.Center)
                Text(state.photos.firstOrNull()?.metadata?.captureTimeText ?: "记录这一刻", color = Color.White.copy(alpha = .90f), fontSize = 8.sp)
            }
        }
        ArtworkTemplateStyle.Classic, ArtworkTemplateStyle.Airy -> Column(Modifier.fillMaxSize()) {
            val header = if (state.preferences.templateStyle == ArtworkTemplateStyle.Airy) .34f else .43f
            Box(
                Modifier.fillMaxWidth().weight(header).background(theme.background.color),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.splitHorizontalTextGesture(onCycleFont, onAdjustTextScale).padding(horizontal = 20.dp),
                ) {
                    Text(
                        state.artworkCopy.title,
                        color = theme.foreground.color,
                        fontSize = (12 * state.textScale).sp,
                        lineHeight = (15 * state.textScale).sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = state.artworkFontFamily,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                    )
                    Text(
                        state.photos.firstOrNull()?.metadata?.captureTimeText ?: "记录这一刻",
                        color = theme.foreground.color.copy(alpha = .92f),
                        fontSize = 8.sp,
                    )
                }
            }
            ArtworkPhoto(photo, state, Modifier.fillMaxWidth().weight(1f - header))
        }
    }
}

@Composable
private fun ColorPaletteCanvas(state: AppUiState, exporting: Boolean, onPaletteOffset: (Float) -> Unit) {
    val bitmap = state.bitmapAt(0)
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val canvasWidth = maxWidth
        val canvasHeight = maxHeight
        ArtworkPhoto(bitmap, state, Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .05f)))
        val compact = state.preferences.paletteLayout == PaletteLayoutMode.Compact
        val panelWidth = maxWidth * .90f
        // Keep the same responsive bounds as iOS. Compact is 19% of the canvas height,
        // not 20% of its width; the old value cut off both text rows on tall canvases.
        val proposedPanelHeight = maxHeight * if (compact) .19f else .38f
        val panelHeight = proposedPanelHeight.coerceIn(
            panelWidth * if (compact) .20f else .50f,
            panelWidth * if (compact) .34f else .82f,
        )
        val basePadding = 15.dp
        val panelTop = basePadding
        val panelLeft = canvasWidth * .05f
        val density = LocalDensity.current
        val maximumPaletteTravelPx = with(density) {
            (canvasHeight - panelHeight - basePadding * 2).toPx()
        }.coerceAtLeast(0f)
        val minimumPaletteOffset = 0f
        val maximumPaletteOffset = maximumPaletteTravelPx
        val latestPaletteOffset = rememberUpdatedState(state.paletteOffset)
        val latestPaletteOffsetHandler = rememberUpdatedState(onPaletteOffset)
        Box(
            Modifier
                .align(Alignment.TopCenter)
                .padding(vertical = basePadding)
                .offset { IntOffset(0, state.paletteOffset.roundToInt()) }
                .fillMaxWidth(.90f)
                .height(panelHeight)
                .pointerInput(
                    maximumPaletteTravelPx,
                    state.preferences.paletteLayout,
                ) {
                    var gestureOffset = 0f
                    detectDragGestures(
                        onDragStart = {
                            gestureOffset = latestPaletteOffset.value.coerceIn(
                                minimumPaletteOffset,
                                maximumPaletteOffset,
                            )
                        },
                        onDrag = { change, amount ->
                            change.consume()
                            gestureOffset = (gestureOffset + amount.y).coerceIn(
                                minimumPaletteOffset,
                                maximumPaletteOffset,
                            )
                            latestPaletteOffsetHandler.value(gestureOffset)
                        },
                    )
                }
                .shadow(15.dp, RoundedCornerShape(22.dp), ambientColor = Color.Black.copy(alpha = .15f))
                .clip(RoundedCornerShape(22.dp)),
        ) {
            if (bitmap != null && !(exporting && !state.preferences.preservePaletteBackground)) {
                PaletteRefractedBackdrop(Modifier.fillMaxSize()) {
                    Box(
                        modifier = Modifier
                            .wrapContentSize(Alignment.TopStart, unbounded = true)
                            .offset {
                                IntOffset(
                                    -with(density) { panelLeft.roundToPx() },
                                    -with(density) { panelTop.roundToPx() } - state.paletteOffset.roundToInt(),
                                )
                            }
                            .requiredSize(canvasWidth, canvasHeight),
                    ) {
                        CoverPhoto(
                            bitmap,
                            JournalTransform(state.imageScale, state.imageOffset),
                            Modifier.fillMaxSize(),
                        )
                    }
                }
            }
            Box(
                Modifier.fillMaxSize()
                    .then(
                        when {
                            exporting && !state.preferences.preservePaletteBackground -> Modifier
                            exporting && !state.preferences.applyLiquidGlassOnExport -> Modifier
                                .background(Color.White.copy(alpha = .34f))
                                .border(
                                    1.dp,
                                    Brush.linearGradient(listOf(Color.White.copy(alpha = .72f), Color.White.copy(alpha = .12f))),
                                    RoundedCornerShape(22.dp),
                                )
                            else -> Modifier.paletteClearGlassSurface(state.palette.firstOrNull()?.color ?: Color.White)
                        }
                    )
                    .padding(horizontal = 12.dp, vertical = 11.dp)
            ) {
                if (compact) {
                    Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                        state.palette.take(6).forEachIndexed { index, color ->
                            PaletteSwatch(state, index, color, panelWidth, compact = true, modifier = Modifier.weight(1f))
                        }
                    }
                } else {
                    val visiblePalette = state.palette.take(6).mapIndexed { index, color -> index to color }
                    val rows = when (visiblePalette.size) {
                        in 0..3 -> listOf(visiblePalette)
                        4 -> visiblePalette.chunked(2)
                        else -> visiblePalette.chunked(3)
                    }
                    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.SpaceEvenly) {
                        rows.forEach { row ->
                            Row(Modifier.fillMaxWidth().weight(1f), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                                row.forEach { (index, color) ->
                                    PaletteSwatch(
                                        state,
                                        index,
                                        color,
                                        panelWidth,
                                        compact = false,
                                        modifier = Modifier.weight(1f),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PaletteSwatch(
    state: AppUiState,
    index: Int,
    color: RGBColor,
    referenceWidth: Dp,
    compact: Boolean,
    modifier: Modifier = Modifier,
) {
    val fontScale = LocalDensity.current.fontScale.coerceAtLeast(.5f)
    val hexFontSize = ((if (compact) 6f else 9f) / fontScale).sp
    val percentageFontSize = ((if (compact) 5.6f else 8f) / fontScale).sp
    Column(
        modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (compact) 2.dp else 4.dp, Alignment.CenterVertically),
    ) {
        Box(
            Modifier
                .size(referenceWidth * if (compact) .09f else .14f)
                .shadow(6.dp, CircleShape)
                .background(color.color, CircleShape)
        )
        if (state.preferences.showHexValues || state.preferences.useLiteraryColorNames) {
            Text(
                if (state.preferences.useLiteraryColorNames) LiteraryColorCatalog.name(color) else color.hex,
                color = Color.White.copy(alpha = .94f),
                fontSize = hexFontSize,
                lineHeight = hexFontSize * 1.15f,
                fontWeight = if (state.preferences.useLiteraryColorNames) FontWeight.SemiBold else FontWeight.Normal,
                fontFamily = if (state.preferences.useLiteraryColorNames) FontFamily.Default else FontFamily.Monospace,
                textAlign = TextAlign.Center,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Visible,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        if (state.preferences.showPalettePercentages) {
            Text(
                "%.1f%%".format(state.palettePercentages.getOrElse(index) { 0.0 }),
                color = Color.White.copy(alpha = .82f),
                fontSize = percentageFontSize,
                lineHeight = percentageFontSize * 1.15f,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Visible,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun JournalCanvas(state: AppUiState, onCycleFont: (Int) -> Unit, onAdjustTextScale: (Float) -> Unit) {
    val base = state.palette.getOrElse(3) { state.palette.lastOrNull() ?: RGBColor.fallback[3] }
        .adjusted(if (state.preferences.gentleBackground) .18f else -.24f, if (state.preferences.gentleBackground) -.22f else .18f)
    BoxWithConstraints(Modifier.fillMaxSize().background(base.color)) {
        Text(
            state.artworkCopy.emojis,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.TopCenter)
                .offset(y = maxHeight * .13f)
                .horizontalStepGesture(onCycleFont),
        )
        JournalGrid(
            state,
            Modifier
                .align(Alignment.Center)
                .width(maxWidth * .50f)
                .height(maxHeight * .505f)
                .shadow(16.dp),
        )
        Text(
            state.artworkCopy.journalCaption,
            fontSize = (8 * state.textScale).sp,
            color = if (base.luminance > .58f) Color.Black.copy(alpha = .62f) else Color.White.copy(alpha = .76f),
            fontStyle = FontStyle.Italic,
            fontFamily = state.artworkFontFamily,
            modifier = Modifier.align(Alignment.BottomCenter)
                .horizontalStepGesture { direction -> onAdjustTextScale(if (direction > 0) .10f else -.10f) }
                .offset(y = -(maxHeight * .22f)),
        )
    }
}

@Composable
private fun JournalGrid(state: AppUiState, modifier: Modifier) {
    BoxWithConstraints(modifier.clip(RoundedCornerShape(2.dp))) {
        val count = state.photos.size.coerceAtMost(5)
        val spacing = 3.dp
        val frames = remember(count, maxWidth, maxHeight, state.preferences.journalLayout) {
            journalFrames(count, maxWidth, maxHeight, state.preferences.journalLayout, spacing)
        }
        state.photos.take(5).forEachIndexed { index, photo ->
            val frame = frames[index]
            val transform = state.journalTransforms.getOrElse(index) { JournalTransform() }
            Box(
                modifier = Modifier
                    .offset(frame.x, frame.y)
                    .size(frame.width, frame.height)
                    .clipToBounds(),
            ) {
                CoverPhoto(
                    state.bitmapAt(index) ?: photo.bitmap,
                    transform,
                    Modifier.fillMaxSize(),
                )
            }
            if (state.selectedJournalIndex == index) {
                Box(Modifier.offset(frame.x, frame.y).size(frame.width, frame.height).border(2.dp, Color.White, RoundedCornerShape(2.dp)))
            }
        }
    }
}

private data class DpFrame(val x: Dp, val y: Dp, val width: Dp, val height: Dp)

private fun journalFrames(count: Int, width: Dp, height: Dp, layout: JournalLayoutMode, spacing: Dp): List<DpFrame> {
    if (count <= 0) return emptyList()
    if (layout == JournalLayoutMode.Filmstrip) {
        val h = (height - spacing * (count - 1)) / count
        return List(count) { DpFrame(0.dp, (h + spacing) * it, width, h) }
    }
    if (layout == JournalLayoutMode.Magazine && count > 1) {
        val hero = height * .62f
        val remaining = count - 1
        val rowH = height - hero - spacing
        val rowW = (width - spacing * (remaining - 1)) / remaining
        return listOf(DpFrame(0.dp, 0.dp, width, hero)) + List(remaining) { DpFrame((rowW + spacing) * it, hero + spacing, rowW, rowH) }
    }
    return when (count) {
        1 -> listOf(DpFrame(0.dp, 0.dp, width, height))
        2 -> {
            val h = (height - spacing) / 2
            List(2) { DpFrame(0.dp, (h + spacing) * it, width, h) }
        }
        3 -> {
            val left = width * .58f
            val right = width - left - spacing
            val rightH = (height - spacing) / 2
            listOf(DpFrame(0.dp, 0.dp, left, height), DpFrame(left + spacing, 0.dp, right, rightH), DpFrame(left + spacing, rightH + spacing, right, rightH))
        }
        4 -> {
            val w = (width - spacing) / 2
            val h = (height - spacing) / 2
            List(4) { DpFrame((w + spacing) * (it % 2), (h + spacing) * (it / 2), w, h) }
        }
        else -> {
            val topH = height * .56f
            val bottomH = height - topH - spacing
            val topW = (width - spacing) / 2
            val bottomW = (width - spacing * 2) / 3
            List(5) {
                if (it < 2) DpFrame((topW + spacing) * it, 0.dp, topW, topH)
                else DpFrame((bottomW + spacing) * (it - 2), topH + spacing, bottomW, bottomH)
            }
        }
    }
}

@Composable
private fun BubbleStampCanvas(
    state: AppUiState,
    onCycleFont: (Int) -> Unit,
    onAdjustTextScale: (Float) -> Unit,
    onBubbleScale: (Float) -> Unit,
) {
    val photo = state.photos.firstOrNull()
    val lightest = state.palette.maxByOrNull { it.relativeLuminance } ?: RGBColor.fallback[2]
    val darkest = state.palette.minByOrNull { it.relativeLuminance } ?: RGBColor.fallback[3]
    if (state.preferences.templateStyle == ArtworkTemplateStyle.Immersive) {
        Box(Modifier.fillMaxSize()) {
            ArtworkPhoto(state.bitmapAt(0), state, Modifier.fillMaxSize())
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Transparent, Color.Black.copy(alpha = .76f)))))
            StampInfo(
                state,
                photo?.metadata,
                Color.White,
                onCycleFont,
                onAdjustTextScale,
                onBubbleScale,
                Modifier.align(Alignment.BottomCenter).padding(horizontal = 34.dp, vertical = 30.dp),
            )
        }
        return
    }
    val light = state.preferences.templateStyle == ArtworkTemplateStyle.Airy
    val background = if (light) lightest.adjusted(.15f, -.18f) else darkest.adjusted(-.06f, .12f)
    val preferred = if (light) darkest.adjusted(-.08f, .04f) else lightest.adjusted(.18f, -.04f)
    val black = RGBColor(.035f, .035f, .035f)
    val white = RGBColor(.965f, .965f, .965f)
    val foreground = if (preferred.contrastRatio(background) >= 4.5f) preferred else if (black.contrastRatio(background) >= white.contrastRatio(background)) black else white
    BoxWithConstraints(Modifier.fillMaxSize().background(background.color)) {
        val side = minOf(
            maxWidth - if (light) 52.dp else 32.dp,
            maxHeight * if (maxWidth > maxHeight) .60f else .76f,
        )
        val infoHorizontalPadding = maxWidth * if (light) .16f else .13f
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            ArtworkPhoto(state.bitmapAt(0), state, Modifier.padding(top = if (light) 26.dp else 16.dp).size(side))
            StampInfo(
                state,
                photo?.metadata,
                foreground.color,
                onCycleFont,
                onAdjustTextScale,
                onBubbleScale,
                Modifier.weight(1f).fillMaxWidth().padding(horizontal = infoHorizontalPadding),
            )
        }
    }
}

@Composable
private fun StampInfo(
    state: AppUiState,
    metadata: PhotoMetadata?,
    foreground: Color,
    onCycleFont: (Int) -> Unit,
    onAdjustTextScale: (Float) -> Unit,
    onBubbleScale: (Float) -> Unit,
    modifier: Modifier,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            Modifier.size((34 * state.bubbleScale).dp)
                .bubbleScaleGesture(state.bubbleScale, onBubbleScale)
                .background(if (state.preferences.showBubbles) foreground else Color.Transparent, CircleShape)
        )
        Column(
            Modifier.weight(1f).splitHorizontalTextGesture(onCycleFont, onAdjustTextScale),
            verticalArrangement = Arrangement.spacedBy((-1).dp),
        ) {
            Text(state.artworkCopy.title, color = foreground, fontSize = (11 * state.textScale).sp, lineHeight = (12 * state.textScale).sp, fontWeight = FontWeight.Bold, fontFamily = state.artworkFontFamily, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(state.artworkCopy.subtitle, color = foreground.copy(alpha = .72f), fontSize = (7 * state.textScale).sp, lineHeight = (8 * state.textScale).sp, fontWeight = FontWeight.SemiBold, fontFamily = state.artworkFontFamily)
            if (state.preferences.showDeviceInfo) {
                metadata?.deviceLine?.let { Text(it, color = foreground.copy(alpha = .46f), fontSize = 6.sp, lineHeight = 7.sp) }
                metadata?.cameraLine?.let { Text(it, color = foreground.copy(alpha = .36f), fontSize = 5.sp, lineHeight = 6.sp) }
            }
        }
    }
}

@Composable
private fun SpectrumWallpaperCanvas(state: AppUiState) {
    val c0 = state.palette.getOrElse(2) { state.palette.lastOrNull() ?: RGBColor.fallback[2] }.adjusted(.18f, -.18f)
    val c1 = state.palette.firstOrNull()?.adjusted(.10f, -.34f) ?: RGBColor.fallback.first()
    var target by remember(state.photos.firstOrNull()?.uri) { mutableFloatStateOf(0f) }
    LaunchedEffect(state.photos.firstOrNull()?.uri, state.mode) { target = 1f }
    val progress by animateFloatAsState(target, tween(1_250), label = "wallpaper-generation")
    val blurPhase = (progress / .56f).coerceIn(0f, 1f)
    val gradientPhase = ((progress - .48f) / .38f).coerceIn(0f, 1f)
    Box(Modifier.fillMaxSize().background(c0.color)) {
        state.bitmapAt(0)?.let {
            ArtworkPhoto(it, state, Modifier.fillMaxSize().blur((34 * blurPhase).dp))
        }
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(c0.color.copy(alpha = .85f), Color.White.copy(alpha = .88f), Color.White.copy(alpha = .92f), c1.color.copy(alpha = .86f)))
            ).graphicsLayer { alpha = gradientPhase }
        )
    }
}

@Composable
private fun PrivacyMosaicCanvas(state: AppUiState, exporting: Boolean, onTogglePrivacyMask: (Int) -> Unit) {
    val bitmap = state.bitmapAt(0) ?: return
    val pixelated = remember(bitmap, state.privacyStrength) { pixelateBitmap(bitmap, state.privacyStrength) }
    Canvas(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .88f))) {
        drawIntoCanvas { composeCanvas ->
            val canvas = composeCanvas.nativeCanvas
            val baseScale = minOf(size.width / bitmap.width, size.height / bitmap.height)
            val scale = baseScale * state.imageScale
            val horizontalLimit = (size.width * (state.imageScale - 1f) / 2f).coerceAtLeast(0f)
            val verticalLimit = (size.height * (state.imageScale - 1f) / 2f).coerceAtLeast(0f)
            val imageOffset = Offset(
                state.imageOffset.x.coerceIn(-horizontalLimit, horizontalLimit),
                state.imageOffset.y.coerceIn(-verticalLimit, verticalLimit),
            )
            val left = (size.width - bitmap.width * scale) / 2 + imageOffset.x
            val top = (size.height - bitmap.height * scale) / 2 + imageOffset.y
            val matrix = Matrix().apply { postScale(scale, scale); postTranslate(left, top) }
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            canvas.drawBitmap(bitmap, matrix, paint)
            val path = Path()
            state.privacyMasks.filter { it.enabled }.forEach { mask ->
                val rect = RectF(
                    left + mask.left * bitmap.width * scale,
                    top + mask.top * bitmap.height * scale,
                    left + mask.right * bitmap.width * scale,
                    top + mask.bottom * bitmap.height * scale,
                )
                path.addRoundRect(rect, 12f, 12f, Path.Direction.CW)
            }
            state.privacyStrokes.forEach { stroke ->
                if (stroke.points.isNotEmpty()) {
                    val strokePath = Path().apply {
                        moveTo(stroke.points.first().x * size.width, stroke.points.first().y * size.height)
                        stroke.points.drop(1).forEach { lineTo(it.x * size.width, it.y * size.height) }
                    }
                    val shader = BitmapShader(pixelated, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
                        setLocalMatrix(matrix)
                    }
                    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        strokeWidth = stroke.normalizedWidth * minOf(size.width, size.height)
                        strokeCap = Paint.Cap.ROUND
                        strokeJoin = Paint.Join.ROUND
                        this.shader = shader
                    }
                    canvas.drawPath(strokePath, strokePaint)
                }
            }
            if (!path.isEmpty) {
                val save = canvas.save()
                canvas.clipPath(path)
                canvas.drawBitmap(pixelated, matrix, paint)
                canvas.restoreToCount(save)
            }
            if (!exporting) {
                state.privacyMasks.forEach { mask ->
                    val rect = RectF(
                        left + mask.left * bitmap.width * scale,
                        top + mask.top * bitmap.height * scale,
                        left + mask.right * bitmap.width * scale,
                        top + mask.bottom * bitmap.height * scale,
                    )
                    val guideColor = if (mask.enabled) 0xE6FFFFFF.toInt() else 0xF2FF8A00.toInt()
                    paint.style = Paint.Style.STROKE
                    paint.strokeWidth = (if (mask.enabled) 1.4.dp else 2.dp).toPx()
                    paint.color = guideColor
                    paint.pathEffect = if (mask.enabled) null else DashPathEffect(
                        floatArrayOf(5.dp.toPx(), 4.dp.toPx()),
                        0f,
                    )
                    canvas.drawRoundRect(rect, minOf(12.dp.toPx(), rect.height() * .22f), minOf(12.dp.toPx(), rect.height() * .22f), paint)
                    paint.pathEffect = null

                    val badgeCenter = Offset(rect.left + 3.dp.toPx(), rect.top + 3.dp.toPx())
                    paint.style = Paint.Style.FILL
                    paint.color = if (mask.enabled) 0xEBFFFFFF.toInt() else 0xFFFF8A00.toInt()
                    canvas.drawCircle(badgeCenter.x, badgeCenter.y, 10.dp.toPx(), paint)
                    paint.color = if (mask.enabled) android.graphics.Color.BLACK else android.graphics.Color.WHITE
                    paint.typeface = Typeface.DEFAULT_BOLD
                    paint.textSize = 8.dp.toPx()
                    paint.textAlign = Paint.Align.CENTER
                    val badge = if (!mask.enabled) "×" else when (mask.kind) {
                        PrivacyMaskKind.Face -> "脸"
                        PrivacyMaskKind.LicensePlate -> "车"
                        PrivacyMaskKind.QrCode -> "码"
                        PrivacyMaskKind.SensitiveText -> "文"
                    }
                    val textY = badgeCenter.y - (paint.ascent() + paint.descent()) / 2f
                    canvas.drawText(badge, badgeCenter.x, textY, paint)
                }
            }
        }
    }
}

private fun pixelateBitmap(bitmap: Bitmap, strength: Float): Bitmap {
    val block = (8 + strength * 34).roundToInt().coerceAtLeast(4)
    val width = (bitmap.width / block).coerceAtLeast(1)
    val height = (bitmap.height / block).coerceAtLeast(1)
    val small = Bitmap.createScaledBitmap(bitmap, width, height, true)
    return Bitmap.createScaledBitmap(small, bitmap.width, bitmap.height, false).also { small.recycle() }
}

@Composable
private fun ArtworkPhoto(bitmap: Bitmap?, state: AppUiState, modifier: Modifier) {
    if (bitmap == null) {
        Box(modifier.background(Color.White.copy(alpha = .24f)), contentAlignment = Alignment.Center) {
            Text("照片", color = Color.White.copy(alpha = .66f), fontSize = 18.sp)
        }
        return
    }
    CoverPhoto(bitmap, JournalTransform(state.imageScale, state.imageOffset), modifier)
}

internal data class CoverPhotoPlacement(
    val left: Float,
    val top: Float,
    val width: Float,
    val height: Float,
    val offset: Offset,
)

internal fun coverPhotoPlacement(
    sourceWidth: Int,
    sourceHeight: Int,
    viewportWidth: Float,
    viewportHeight: Float,
    transform: JournalTransform,
): CoverPhotoPlacement {
    if (sourceWidth <= 0 || sourceHeight <= 0 || viewportWidth <= 0f || viewportHeight <= 0f) {
        return CoverPhotoPlacement(0f, 0f, 0f, 0f, Offset.Zero)
    }
    val baseScale = max(viewportWidth / sourceWidth, viewportHeight / sourceHeight)
    val appliedScale = transform.scale.coerceIn(1f, 4f)
    val drawnWidth = sourceWidth * baseScale * appliedScale
    val drawnHeight = sourceHeight * baseScale * appliedScale
    val maximumX = ((drawnWidth - viewportWidth) / 2f).coerceAtLeast(0f)
    val maximumY = ((drawnHeight - viewportHeight) / 2f).coerceAtLeast(0f)
    val offset = Offset(
        transform.offset.x.coerceIn(-maximumX, maximumX),
        transform.offset.y.coerceIn(-maximumY, maximumY),
    )
    return CoverPhotoPlacement(
        left = (viewportWidth - drawnWidth) / 2f + offset.x,
        top = (viewportHeight - drawnHeight) / 2f + offset.y,
        width = drawnWidth,
        height = drawnHeight,
        offset = offset,
    )
}

@Composable
private fun CoverPhoto(bitmap: Bitmap, transform: JournalTransform, modifier: Modifier) {
    val paint = remember(bitmap) {
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true }
    }
    Canvas(modifier.clipToBounds()) {
        val placement = coverPhotoPlacement(
            bitmap.width,
            bitmap.height,
            size.width,
            size.height,
            transform,
        )
        drawIntoCanvas { canvas ->
            canvas.nativeCanvas.drawBitmap(
                bitmap,
                null,
                RectF(
                    placement.left,
                    placement.top,
                    placement.left + placement.width,
                    placement.top + placement.height,
                ),
                paint,
            )
        }
    }
}

private val AppUiState.artworkFontFamily: FontFamily
    get() = when (fontStyle) {
        ArtworkFontStyle.Rounded -> FontFamily.SansSerif
        ArtworkFontStyle.Song, ArtworkFontStyle.Serif -> FontFamily.Serif
        ArtworkFontStyle.Monospaced -> FontFamily.Monospace
    }

private fun Modifier.splitHorizontalTextGesture(
    onCycleFont: (Int) -> Unit,
    onAdjustTextScale: (Float) -> Unit,
): Modifier = pointerInput(onCycleFont, onAdjustTextScale) {
    var total = Offset.Zero
    var editsFont = true
    detectDragGestures(
        onDragStart = { point ->
            total = Offset.Zero
            editsFont = point.y < size.height * .50f
        },
        onDrag = { change, dragAmount ->
            change.consume()
            total += dragAmount
        },
        onDragEnd = {
            if (abs(total.x) > abs(total.y) && abs(total.x) > 24.dp.toPx()) {
                val direction = if (total.x > 0) 1 else -1
                if (editsFont) onCycleFont(direction)
                else onAdjustTextScale(if (direction > 0) .10f else -.10f)
            }
        },
    )
}

private fun Modifier.horizontalStepGesture(onStep: (Int) -> Unit): Modifier = pointerInput(onStep) {
    var total = Offset.Zero
    detectDragGestures(
        onDragStart = { total = Offset.Zero },
        onDrag = { change, dragAmount -> change.consume(); total += dragAmount },
        onDragEnd = {
            if (abs(total.x) > abs(total.y) && abs(total.x) > 22.dp.toPx()) {
                onStep(if (total.x > 0) 1 else -1)
            }
        },
    )
}

private fun Modifier.bubbleScaleGesture(initialScale: Float, onScale: (Float) -> Unit): Modifier =
    pointerInput(initialScale, onScale) {
        var startScale = initialScale
        var totalY = 0f
        detectDragGestures(
            onDragStart = { startScale = initialScale; totalY = 0f },
            onDrag = { change, dragAmount ->
                change.consume()
                totalY += dragAmount.y
                onScale((startScale - totalY / 150.dp.toPx()).coerceIn(.45f, 2.1f))
            },
        )
    }
