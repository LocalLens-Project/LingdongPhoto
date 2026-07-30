package cn.locallens.lingdongzhaopian

import android.graphics.Bitmap
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.max

/**
 * The single source of truth for the visible ticket silhouette.
 *
 * Compose clips the live preview with this outline, and because the exporter re-records the same
 * view tree into a transparent RenderNode, the exported PNG keeps identical alpha in the rounded
 * corners and the punched notch.
 */
class TicketArtworkShape(private val layout: TicketLayoutStyle) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val cornerRadius = when (layout) {
            TicketLayoutStyle.Classic -> max(12f, size.width * .024f)
            TicketLayoutStyle.Vertical -> max(18f, size.width * .060f)
            TicketLayoutStyle.Minimal -> 0f
        }
        val body = Path().apply {
            addRoundRect(
                androidx.compose.ui.geometry.RoundRect(
                    Rect(0f, 0f, size.width, size.height),
                    androidx.compose.ui.geometry.CornerRadius(cornerRadius, cornerRadius),
                )
            )
        }
        if (layout != TicketLayoutStyle.Classic) return Outline.Generic(body)

        val notchDiameter = max(18f, size.height * .20f)
        val centerX = size.width + notchDiameter * .02f
        val notch = Path().apply {
            addOval(
                Rect(
                    centerX - notchDiameter / 2f,
                    size.height / 2f - notchDiameter / 2f,
                    centerX + notchDiameter / 2f,
                    size.height / 2f + notchDiameter / 2f,
                )
            )
        }
        return Outline.Generic(Path().apply { op(body, notch, PathOperation.Difference) })
    }
}

@Composable
fun TravelTicketCanvas(state: AppUiState, exporting: Boolean) {
    when (state.preferences.ticketLayout) {
        TicketLayoutStyle.Classic -> ClassicTravelTicket(state)
        TicketLayoutStyle.Vertical -> VerticalTravelTicket(state)
        TicketLayoutStyle.Minimal -> MinimalTravelTicket(state, exporting)
    }
}

private val AppUiState.ticketColors: List<RGBColor>
    get() = palette.ifEmpty { RGBColor.fallback }

private val AppUiState.darkestTicketColor: RGBColor
    get() = ticketColors.minByOrNull { it.relativeLuminance } ?: RGBColor.fallback[3]

private fun readableForeground(preferred: RGBColor, background: RGBColor): RGBColor {
    if (preferred.contrastRatio(background) >= 4.5f) return preferred
    val black = RGBColor(.035f, .035f, .035f)
    val white = RGBColor(.965f, .965f, .965f)
    return if (black.contrastRatio(background) >= white.contrastRatio(background)) black else white
}

@Composable
private fun ClassicTravelTicket(state: AppUiState) {
    val payload = state.ticketPayload
    val dominant = state.ticketColors[0]
    val brightness = when {
        dominant.relativeLuminance < .18f -> .10f
        dominant.relativeLuminance < .48f -> .26f
        else -> -.06f
    }
    val background = dominant.adjusted(brightness, -.38f)
    val foreground = readableForeground(state.darkestTicketColor, background)

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val ticketWidth = maxWidth
        val ticketHeight = maxHeight
        val contentInset = maxOf(8.dp, ticketWidth * .026f)
        val stubWidth = ticketWidth *
            if (state.preferences.ticketCodeStyle == TicketCodeStyle.VerificationQR) .335f else .285f

        ArtworkPhotoLayer(state, Modifier.fillMaxSize())

        TicketScallopedPanel(
            color = background.color,
            scallopCount = 7,
            modifier = Modifier.width(stubWidth).fillMaxHeight(),
        )

        val codeMaxWidth = stubWidth - contentInset * 1.85f
        val codeMaxHeight = if (state.preferences.ticketCodeStyle == TicketCodeStyle.Barcode) {
            ticketHeight * .24f
        } else {
            ticketHeight * .43f
        }
        val reservedCodeHeight = if (state.preferences.ticketCodeStyle == TicketCodeStyle.Barcode) {
            minOf(codeMaxHeight, codeMaxWidth / 3f)
        } else {
            minOf(codeMaxWidth, codeMaxHeight)
        }

        Box(
            Modifier
                .width(stubWidth)
                .fillMaxHeight()
                .padding(horizontal = contentInset * .80f, vertical = contentInset * .80f),
        ) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(bottom = reservedCodeHeight + maxOf(3.dp, ticketHeight * .014f)),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(maxOf(1.dp, ticketHeight * .006f)),
            ) {
                payload.headerTitle?.takeIf { it.isNotEmpty() }?.let { header ->
                    Text(
                        header,
                        color = foreground.color,
                        fontSize = maxOf(9f, ticketWidth.value * .027f).sp,
                        lineHeight = maxOf(11f, ticketWidth.value * .032f).sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = maxOf(.6f, ticketWidth.value * .003f).sp,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                Text(
                    payload.title,
                    color = foreground.color.copy(alpha = .72f),
                    fontSize = maxOf(7f, ticketWidth.value * .014f * state.textScale).sp,
                    lineHeight = maxOf(8f, ticketWidth.value * .016f * state.textScale).sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = state.ticketFontFamily,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Clip,
                    modifier = Modifier.fillMaxWidth(),
                )

                payload.subtitle?.takeIf { it.isNotBlank() }?.let { subtitle ->
                    Text(
                        subtitle,
                        color = foreground.color.copy(alpha = .60f),
                        fontSize = maxOf(6f, ticketWidth.value * .0115f).sp,
                        lineHeight = maxOf(7f, ticketWidth.value * .013f).sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        overflow = TextOverflow.Clip,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                Column(
                    Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(maxOf(1.dp, ticketHeight * .005f)),
                ) {
                    val detailSize = maxOf(6f, ticketWidth.value * .0108f).sp
                    payload.captureTime?.let {
                        Text(
                            it,
                            color = foreground.color.copy(alpha = .70f),
                            fontSize = detailSize,
                            lineHeight = maxOf(7f, ticketWidth.value * .013f).sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Text(
                        "NO.${payload.ticketID.removePrefix("LD-")}",
                        color = foreground.color.copy(alpha = .70f),
                        fontSize = detailSize,
                        lineHeight = maxOf(7f, ticketWidth.value * .013f).sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.Monospace,
                        maxLines = 1,
                    )
                    Text(
                        payload.fingerprint.takeLast(8),
                        color = foreground.color.copy(alpha = .70f),
                        fontSize = detailSize,
                        lineHeight = maxOf(7f, ticketWidth.value * .013f).sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.Monospace,
                        maxLines = 1,
                    )
                }
            }

            TicketCodeImage(
                payload = payload,
                style = state.preferences.ticketCodeStyle,
                foreground = foreground,
                maxWidth = codeMaxWidth,
                maxHeight = codeMaxHeight,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

@Composable
private fun VerticalTravelTicket(state: AppUiState) {
    val payload = state.ticketPayload
    val dominant = state.ticketColors[0]
    val background = dominant.adjusted(
        when {
            dominant.relativeLuminance < .18f -> .10f
            dominant.relativeLuminance < .48f -> .24f
            else -> -.05f
        },
        -.30f,
    )
    val foreground = readableForeground(state.darkestTicketColor, background)
    val systemFontScale = LocalDensity.current.fontScale.coerceAtLeast(.1f)

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val width = maxWidth
        val height = maxHeight
        val heightToWidth = if (width.value > 0f) height.value / width.value else 1f
        val ultraCompact = heightToWidth < .62f
        val compact = heightToWidth < .96f
        val showsVerificationQR = state.preferences.ticketCodeStyle == TicketCodeStyle.VerificationQR

        // "Original" can produce a landscape 4:3, 16:9 or even 21:9 canvas. The old fixed 52/48
        // split left too little room for metadata, especially when a square QR code was selected.
        // Reserve the information panel from the ticket's own aspect ratio instead of the device
        // screen, then scale every internal element from that panel's actual height.
        val photoFraction = when {
            ultraCompact -> .38f
            compact && showsVerificationQR -> .43f
            compact -> .47f
            else -> .52f
        }
        val panelHeight = height * (1f - photoFraction)
        val panelPadding = when {
            ultraCompact -> maxOf(5.dp, width * .018f)
            compact -> maxOf(7.dp, width * .030f)
            else -> maxOf(12.dp, width * .050f)
        }
        val panelContentHeight = (panelHeight - panelPadding * 2f).coerceAtLeast(1.dp)
        val titleScale = state.textScale.coerceAtMost(
            when {
                ultraCompact -> 1.08f
                compact -> 1.22f
                else -> 1.55f
            }
        )
        val titleSize = when {
            ultraCompact -> maxOf(7f, width.value * .028f)
            compact -> maxOf(9f, width.value * .042f)
            else -> maxOf(11f, width.value * .050f)
        } * titleScale
        val subtitleSize = when {
            ultraCompact -> maxOf(5.5f, width.value * .018f)
            compact -> maxOf(6.5f, width.value * .022f)
            else -> maxOf(7f, width.value * .025f)
        }
        val titleMaxLines = if (compact) 1 else 2
        val subtitleMaxLines = if (compact) 1 else 2
        val titleSpacing = when {
            ultraCompact -> 1.dp
            compact -> 2.dp
            else -> 5.dp
        }
        val rowSpacing = when {
            ultraCompact -> 5.dp
            compact -> 7.dp
            else -> 10.dp
        }
        val codeMaxWidth = width * when {
            ultraCompact -> .19f
            compact -> .24f
            else -> .30f
        }
        val codeMaxHeight = if (showsVerificationQR) {
            panelContentHeight * when {
                ultraCompact -> .40f
                compact -> .43f
                else -> .48f
            }
        } else {
            minOf(height * .10f, panelContentHeight * .34f)
        }
        val infoTitleSize = when {
            ultraCompact -> 5f
            compact -> 6f
            else -> 7f
        }
        val infoValueSize = when {
            ultraCompact -> 6.5f
            compact -> 7.5f
            else -> 9f
        }
        val infoLineHeight = when {
            ultraCompact -> 7.5f
            compact -> 9f
            else -> 11f
        }
        val infoMaxLines = if (ultraCompact) 1 else 2
        val infoSpacing = when {
            ultraCompact -> 1.dp
            compact -> 2.dp
            else -> 3.dp
        }
        val paletteDotSize = when {
            ultraCompact -> 6.dp
            compact -> 8.dp
            else -> 10.dp
        }
        val ticketIDSize = when {
            ultraCompact -> 5.5f
            compact -> 6.5f
            else -> maxOf(7f, width.value * .024f)
        }
        val photoInset = when {
            ultraCompact -> maxOf(4.dp, width * .018f)
            compact -> maxOf(6.dp, width * .026f)
            else -> maxOf(9.dp, width * .040f)
        }

        Column(Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxWidth().height(height * photoFraction)) {
                ArtworkPhotoLayer(state, Modifier.fillMaxSize())
                Text(
                    payload.ticketID,
                    color = Color.White.copy(alpha = .90f),
                    // Artwork typography is part of the exported design and must not grow with the
                    // user's Android accessibility font scale.
                    fontSize = (ticketIDSize / systemFontScale).sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier.align(Alignment.TopEnd).padding(photoInset),
                )
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .background(background.color)
                    .padding(panelPadding),
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(rowSpacing),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(titleSpacing)) {
                        Text(
                            payload.title,
                            color = foreground.color,
                            fontSize = (titleSize / systemFontScale).sp,
                            lineHeight = (titleSize * 1.16f / systemFontScale).sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = state.ticketFontFamily,
                            maxLines = titleMaxLines,
                            overflow = TextOverflow.Ellipsis,
                        )
                        payload.subtitle?.let {
                            Text(
                                it,
                                color = foreground.color.copy(alpha = .60f),
                                fontSize = (subtitleSize / systemFontScale).sp,
                                lineHeight = (subtitleSize * 1.22f / systemFontScale).sp,
                                fontWeight = FontWeight.Medium,
                                maxLines = subtitleMaxLines,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }

                    TicketCodeImage(
                        payload = payload,
                        style = state.preferences.ticketCodeStyle,
                        foreground = foreground,
                        maxWidth = codeMaxWidth,
                        maxHeight = codeMaxHeight,
                    )
                }

                HorizontalDivider(color = foreground.color.copy(alpha = .18f))

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(rowSpacing)) {
                    TicketInfoLabel(
                        title = "DATE",
                        value = payload.captureTime ?: "未记录",
                        foreground = foreground.color,
                        modifier = Modifier.weight(1f),
                        titleFontSize = (infoTitleSize / systemFontScale).sp,
                        valueFontSize = (infoValueSize / systemFontScale).sp,
                        valueLineHeight = (infoLineHeight / systemFontScale).sp,
                        maxLines = infoMaxLines,
                        spacing = infoSpacing,
                    )
                    TicketInfoLabel(
                        title = "CAMERA",
                        value = payload.device ?: "未公开",
                        foreground = foreground.color,
                        modifier = Modifier.weight(1f),
                        titleFontSize = (infoTitleSize / systemFontScale).sp,
                        valueFontSize = (infoValueSize / systemFontScale).sp,
                        valueLineHeight = (infoLineHeight / systemFontScale).sp,
                        maxLines = infoMaxLines,
                        spacing = infoSpacing,
                    )
                }

                TicketPaletteDots(state.ticketColors, paletteDotSize)
            }
        }
    }
}

@Composable
private fun MinimalTravelTicket(state: AppUiState, exporting: Boolean) {
    val payload = state.ticketPayload
    val dominant = state.ticketColors[0]
    val panelBackground = dominant.adjusted(
        if (dominant.relativeLuminance < .30f) .14f else -.18f,
        -.12f,
    )
    val panelForeground = readableForeground(state.darkestTicketColor, panelBackground)

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val width = maxWidth
        val height = maxHeight
        ArtworkPhotoLayer(state, Modifier.fillMaxSize())
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0f to Color.Transparent,
                    .5f to Color.Transparent,
                    .78f to panelBackground.color.copy(alpha = .10f),
                    1f to panelBackground.color.copy(alpha = .76f),
                )
            )
        )

        Row(
            Modifier
                .align(Alignment.BottomCenter)
                .padding(maxOf(10.dp, width * .026f))
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(maxOf(14.dp, width * .038f)))
                .background(panelBackground.color.copy(alpha = if (exporting) .88f else .78f))
                .border(
                    1.dp,
                    panelForeground.color.copy(alpha = .18f),
                    androidx.compose.foundation.shape.RoundedCornerShape(maxOf(14.dp, width * .038f)),
                )
                .padding(maxOf(14.dp, width * .040f)),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(maxOf(10.dp, width * .028f)),
        ) {
            Column(
                Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(maxOf(4.dp, height * .014f)),
            ) {
                Text(
                    payload.title,
                    color = panelForeground.color,
                    fontSize = maxOf(12f, width.value * .036f * state.textScale).sp,
                    lineHeight = maxOf(14f, width.value * .042f * state.textScale).sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = state.ticketFontFamily,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                listOfNotNull(payload.place, payload.captureTime).takeIf { it.isNotEmpty() }?.let { details ->
                    Text(
                        details.joinToString("  ·  "),
                        color = panelForeground.color.copy(alpha = .70f),
                        fontSize = maxOf(6f, width.value * .014f).sp,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Text(
                    payload.ticketID,
                    color = panelForeground.color.copy(alpha = .58f),
                    fontSize = maxOf(6f, width.value * .013f).sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace,
                    maxLines = 1,
                )
            }

            TicketCodeImage(
                payload = payload,
                style = state.preferences.ticketCodeStyle,
                foreground = panelForeground,
                maxWidth = width * .30f,
                maxHeight = height * if (state.preferences.ticketCodeStyle == TicketCodeStyle.Barcode) .22f else .50f,
            )
        }
    }
}

@Composable
fun TicketCodeImage(
    payload: TicketPayload,
    style: TicketCodeStyle,
    foreground: RGBColor,
    maxWidth: Dp,
    maxHeight: Dp,
    modifier: Modifier = Modifier,
) {
    val targetWidth = if (style == TicketCodeStyle.Barcode) {
        maxWidth
    } else {
        minOf(maxWidth, maxHeight)
    }
    val targetHeight = if (style == TicketCodeStyle.Barcode) {
        minOf(maxHeight, maxWidth / 3f)
    } else {
        targetWidth
    }
    val argb = foreground.color.toArgb()
    val bitmap = remember(payload, style, argb) {
        runCatching {
            TicketCodeRenderer.image(
                style = style,
                payload = payload,
                pixelWidth = if (style == TicketCodeStyle.Barcode) 1_200 else 900,
                pixelHeight = if (style == TicketCodeStyle.Barcode) 400 else 900,
                foregroundColor = argb,
            )
        }.getOrNull()
    }
    if (bitmap == null) {
        Box(
            modifier.width(targetWidth).height(targetHeight),
            contentAlignment = Alignment.Center,
        ) {
            Text("编码生成失败", color = Color(0xFFFF8A00), fontSize = 7.sp, fontWeight = FontWeight.Bold)
        }
        return
    }
    Image(
        bitmap.asImageBitmap(),
        if (style == TicketCodeStyle.Barcode) "真实一维票根码" else "灵动照片验证二维码",
        modifier = modifier.width(targetWidth).height(targetHeight),
        contentScale = ContentScale.Fit,
        filterQuality = FilterQuality.None,
    )
}

@Composable
private fun TicketScallopedPanel(color: Color, scallopCount: Int, modifier: Modifier) {
    Canvas(modifier) {
        val count = max(1, scallopCount)
        val step = size.height / count
        // Adjacent circles meet exactly, forming one uninterrupted perforated edge.
        val radius = step * .50f
        drawRect(color, size = Size(size.width - radius, size.height))
        repeat(count) { index ->
            val centerY = (index + .5f) * step
            drawCircle(color, radius, Offset(size.width - radius, centerY))
        }
    }
}

@Composable
private fun TicketInfoLabel(
    title: String,
    value: String,
    foreground: Color,
    modifier: Modifier,
    titleFontSize: TextUnit = 7.sp,
    valueFontSize: TextUnit = 9.sp,
    valueLineHeight: TextUnit = 11.sp,
    maxLines: Int = 2,
    spacing: Dp = 3.dp,
) {
    Column(
        modifier,
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) {
        Text(
            title,
            color = foreground.copy(alpha = .46f),
            fontSize = titleFontSize,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        )
        Text(
            value,
            color = foreground,
            fontSize = valueFontSize,
            lineHeight = valueLineHeight,
            fontWeight = FontWeight.SemiBold,
            maxLines = maxLines,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun TicketPaletteDots(colors: List<RGBColor>, dotSize: Dp = 10.dp) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(maxOf(3.dp, dotSize * .50f)),
    ) {
        colors.take(6).forEach { color ->
            Box(
                Modifier
                    .size(dotSize)
                    .background(color.color, CircleShape)
                    .border(.6.dp, Color.White.copy(alpha = .42f), CircleShape)
            )
        }
    }
}

@Composable
private fun ArtworkPhotoLayer(state: AppUiState, modifier: Modifier) {
    val bitmap: Bitmap? = state.bitmapAt(0)
    if (bitmap == null) {
        Box(modifier.background(Color.White.copy(alpha = .24f)), contentAlignment = Alignment.Center) {
            Text("照片", color = Color.White.copy(alpha = .66f), fontSize = 18.sp)
        }
        return
    }
    CoverPhoto(bitmap, JournalTransform(state.imageScale, state.imageOffset), modifier)
}

private val AppUiState.ticketFontFamily: FontFamily
    get() = when (fontStyle) {
        ArtworkFontStyle.Rounded -> FontFamily.SansSerif
        ArtworkFontStyle.Song, ArtworkFontStyle.Serif -> FontFamily.Serif
        ArtworkFontStyle.Monospaced -> FontFamily.Monospace
    }
