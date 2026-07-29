package cn.locallens.lingdongzhaopian

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.ConfirmationNumber
import androidx.compose.material.icons.outlined.FormatQuote
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.PanTool
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.delay

@Composable
fun TicketVerificationDialog(payload: TicketPayload, onClose: () -> Unit) {
    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false),
    ) {
        TicketVerificationScreen(payload, onClose)
    }
}

/**
 * Local mirror of the iOS App Clip verification page. Nothing here reaches the network or the photo
 * library: every value comes from the scanned code itself.
 */
@Composable
fun TicketVerificationScreen(payload: TicketPayload, onClose: () -> Unit) {
    val colors = remember(payload) {
        payload.palette
            .map { RGBColor.fromHex(TicketCodeRenderer.ticketColor(it.hex)) }
            .ifEmpty { listOf(RGBColor(.20f, .45f, .37f), RGBColor(.30f, .32f, .62f), RGBColor(.42f, .78f, .68f)) }
    }
    var revealed by remember(payload) { mutableStateOf(payload.revealLayout == null) }
    LaunchedEffect(payload) {
        if (payload.revealLayout != null) {
            delay(1_500)
            revealed = true
        }
    }
    val contentAlpha by animateFloatAsState(if (revealed) 1f else 0f, tween(420), label = "ticket-reveal")

    Box(Modifier.fillMaxSize()) {
        TicketAmbientBackground(colors)

        LazyColumn(
            Modifier.fillMaxSize().graphicsLayer { alpha = contentAlpha },
            contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 30.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            item { VerificationHeader(onClose) }
            item { HeroTicket(payload) }
            payload.message?.let { message -> item { MessagePanel(message) } }
            if (payload.palette.isNotEmpty()) item { PalettePanel(payload, colors) }
            item { MetadataPanel(payload) }
            item { PrivacyPanel() }
        }

        if (!revealed) {
            TicketRevealLayer(payload.revealLayout ?: "c", colors)
        }
    }
}

@Composable
private fun VerificationHeader(onClose: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            Modifier
                .size(46.dp)
                .background(Color.White.copy(alpha = .13f), CircleShape)
                .border(1.dp, Color.White.copy(alpha = .18f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Outlined.ConfirmationNumber, null, Modifier.size(20.dp), tint = Color.White)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("灵动照片", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text("影像票根 · 本地验证", color = Color.White.copy(alpha = .64f), fontSize = 12.sp)
        }
        Box(
            Modifier
                .size(42.dp)
                .background(Color.White.copy(alpha = .12f), CircleShape)
                .border(1.dp, Color.White.copy(alpha = .16f), CircleShape)
                .clickable(onClick = onClose),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Close, "关闭验证页面", Modifier.size(16.dp), tint = Color.White)
        }
    }
}

@Composable
private fun HeroTicket(payload: TicketPayload) {
    TicketGlassPanel(cornerRadius = 30.dp, padding = 22.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(
                    Modifier
                        .background(Color.White.copy(alpha = .15f), CircleShape)
                        .padding(horizontal = 12.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(Icons.Outlined.Verified, null, Modifier.size(14.dp), tint = Color.White)
                    Text("票根信息完整", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.weight(1f))
                Text(
                    payload.ticketID,
                    color = Color.White.copy(alpha = .62f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Text(payload.title, color = Color.White, fontSize = 26.sp, lineHeight = 32.sp, fontWeight = FontWeight.Bold)
                payload.subtitle?.let {
                    Text(it, color = Color.White.copy(alpha = .68f), fontSize = 14.sp, lineHeight = 20.sp)
                }
            }

            Text(
                "照片指纹 ${payload.fingerprint}",
                color = Color.White.copy(alpha = .58f),
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun MessagePanel(message: String) {
    TicketGlassPanel(cornerRadius = 26.dp, padding = 20.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(13.dp)) {
            PanelTitle(Icons.Outlined.FormatQuote, "票根寄语")
            Text(
                message,
                color = Color.White,
                fontSize = 17.sp,
                lineHeight = 25.sp,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

@Composable
private fun PalettePanel(payload: TicketPayload, colors: List<RGBColor>) {
    TicketGlassPanel(cornerRadius = 26.dp, padding = 20.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(15.dp)) {
            PanelTitle(Icons.Outlined.Palette, "照片色盘")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                payload.palette.forEachIndexed { index, entry ->
                    Column(
                        Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(7.dp),
                    ) {
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(58.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(colors.getOrElse(index) { colors.first() }.color)
                                .border(1.dp, Color.White.copy(alpha = .22f), RoundedCornerShape(12.dp))
                        )
                        Text(
                            entry.hex,
                            color = Color.White,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.SemiBold,
                            fontFamily = FontFamily.Monospace,
                            maxLines = 1,
                        )
                        Text(
                            "%.1f%%".format(entry.percentage),
                            color = Color.White.copy(alpha = .58f),
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MetadataPanel(payload: TicketPayload) {
    val values = listOfNotNull(
        payload.captureTime?.let { Triple(Icons.Outlined.CalendarMonth, "拍摄时间", it) },
        payload.place?.let { Triple(Icons.Outlined.LocationOn, "地点", it) },
        payload.device?.let { Triple(Icons.Outlined.CameraAlt, "拍摄设备", it) },
        payload.lens?.let { Triple(Icons.Outlined.CameraAlt, "镜头", it) },
        payload.captureSettings?.let { Triple(Icons.Outlined.Tune, "拍摄参数", it) },
    )
    TicketGlassPanel(cornerRadius = 26.dp, padding = 20.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(15.dp)) {
            PanelTitle(Icons.Outlined.CameraAlt, "拍摄信息")
            if (values.isEmpty()) {
                Text("这张票根没有公开拍摄信息", color = Color.White.copy(alpha = .58f), fontSize = 14.sp)
            } else {
                values.chunked(2).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { (icon, label, value) ->
                            Column(
                                Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(17.dp))
                                    .background(Color.White.copy(alpha = .08f))
                                    .padding(13.dp),
                                verticalArrangement = Arrangement.spacedBy(5.dp),
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                                ) {
                                    Icon(icon, null, Modifier.size(12.dp), tint = Color.White.copy(alpha = .52f))
                                    Text(label, color = Color.White.copy(alpha = .52f), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                }
                                Text(
                                    value,
                                    color = Color.White,
                                    fontSize = 14.sp,
                                    lineHeight = 18.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun PrivacyPanel() {
    TicketGlassPanel(cornerRadius = 24.dp, padding = 18.dp) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Icon(Icons.Outlined.PanTool, null, Modifier.size(18.dp), tint = Color.White.copy(alpha = .80f))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("不读取相册，不上传照片", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text(
                    "此页面只解析二维码中由发送者主动公开的数据，所有展示与校验均在本机完成。",
                    color = Color.White.copy(alpha = .60f),
                    fontSize = 12.sp,
                    lineHeight = 17.sp,
                )
            }
        }
    }
}

@Composable
private fun PanelTitle(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, null, Modifier.size(18.dp), tint = Color.White)
        Text(title, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun TicketGlassPanel(cornerRadius: androidx.compose.ui.unit.Dp, padding: androidx.compose.ui.unit.Dp, content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(cornerRadius))
            .background(
                Brush.linearGradient(
                    listOf(Color.White.copy(alpha = .16f), Color.White.copy(alpha = .07f)),
                )
            )
            .border(
                1.dp,
                Brush.linearGradient(listOf(Color.White.copy(alpha = .34f), Color.White.copy(alpha = .08f))),
                RoundedCornerShape(cornerRadius),
            )
            .padding(padding),
    ) { content() }
}

@Composable
private fun TicketAmbientBackground(colors: List<RGBColor>) {
    Box(
        Modifier
            .fillMaxSize()
            // The gradient's later stops are translucent, so an opaque base keeps whatever opened
            // this page — a sheet or the camera preview — from showing through.
            .background(Color.Black)
            .background(
                Brush.linearGradient(
                    listOf(
                        colors[0].color,
                        colors.getOrElse(1) { colors[0] }.color.copy(alpha = .82f),
                        Color.Black.copy(alpha = .92f),
                    )
                )
            )
    ) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(
                Brush.radialGradient(
                    0f to colors.getOrElse(2) { colors[0] }.color.copy(alpha = .60f),
                    1f to Color.Transparent,
                    center = Offset(size.width * .08f, size.height * .76f),
                    radius = size.width * .86f,
                )
            )
            drawRect(
                Brush.radialGradient(
                    0f to colors.getOrElse(3) { colors[0] }.color.copy(alpha = .40f),
                    1f to Color.Transparent,
                    center = Offset(size.width * .92f, size.height * .25f),
                    radius = size.width * .66f,
                )
            )
        }
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(Color.White.copy(alpha = .09f), Color.Transparent, Color.Black.copy(alpha = .20f))
                )
            )
        )
    }
}

/** Blank ticket that grows into the page, mirroring the iOS reveal transition. */
@Composable
private fun TicketRevealLayer(layout: String, colors: List<RGBColor>) {
    var appeared by remember { mutableStateOf(false) }
    var expanded by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(100)
        appeared = true
        delay(420)
        expanded = true
    }
    val entrance by animateFloatAsState(if (appeared) 1f else 0f, tween(320), label = "ticket-entrance")
    val progress by animateFloatAsState(if (expanded) 1f else 0f, tween(1_020), label = "ticket-progress")

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val horizontalProgress = ((progress - .70f) / .30f).coerceIn(0f, 1f)
        val initialWidth = minOf(maxWidth * .70f, 318.dp)
        val initialHeight = minOf(
            maxHeight * if (layout == "c") .36f else .44f,
            if (layout == "c") 365.dp else 430.dp,
        )
        val width = initialWidth + (maxWidth + 6.dp - initialWidth) * horizontalProgress
        val height = initialHeight + (maxHeight + 8.dp - initialHeight) * progress
        val detail = 1f - horizontalProgress
        val primary = colors[0]
        val secondary = colors.getOrElse(1) { primary }
        val tertiary = colors.getOrElse(2) { secondary }
        val dividerFraction = if (layout == "c") .35f else .54f

        Box(
            Modifier
                .align(Alignment.Center)
                .graphicsLayer {
                    alpha = entrance
                    scaleX = .82f + .18f * entrance
                    scaleY = .82f + .18f * entrance
                    // Keeps the punched notches from clearing the page behind the ticket.
                    compositingStrategy = CompositingStrategy.Offscreen
                }
                .width(width)
                .height(height)
                .clip(RoundedCornerShape(32.dp * detail)),
        ) {
            Box(
                Modifier.fillMaxSize().background(
                    Brush.linearGradient(
                        listOf(
                            secondary.color.copy(alpha = .98f),
                            tertiary.color.copy(alpha = .90f),
                            primary.color.copy(alpha = .96f),
                        )
                    )
                )
            )
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(height * dividerFraction)
                    .background(
                        Brush.linearGradient(
                            listOf(primary.color.copy(alpha = .98f), secondary.color.copy(alpha = .88f))
                        )
                    )
            )
            Canvas(Modifier.fillMaxSize()) {
                // The punched notches are carved out of the finished ticket, not painted over it.
                val notchRadius = minOf(size.width, size.height) * .058f * detail
                if (notchRadius <= .2f) return@Canvas
                val dividerY = size.height * dividerFraction
                drawCircle(Color.Black, notchRadius, Offset(0f, dividerY), blendMode = BlendMode.Clear)
                drawCircle(Color.Black, notchRadius, Offset(size.width, dividerY), blendMode = BlendMode.Clear)
            }
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(
                        listOf(Color.White.copy(alpha = .15f), Color.Transparent, Color.Black.copy(alpha = .12f))
                    )
                )
            )
        }
    }
}

@Composable
fun TicketVerificationErrorScreen(message: String, onClose: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(listOf(Color(0xFF1A1C24), Color.Black))
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Box(
                Modifier
                    .size(82.dp)
                    .background(Color.White.copy(alpha = .10f), CircleShape)
                    .border(1.dp, Color.White.copy(alpha = .16f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.ConfirmationNumber, null, Modifier.size(36.dp), tint = Color.White.copy(alpha = .84f))
            }
            Text("无法验证影像票根", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(
                message,
                color = Color.White.copy(alpha = .62f),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                textAlign = TextAlign.Center,
            )
            Box(
                Modifier
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = .14f))
                    .clickable(onClick = onClose)
                    .padding(horizontal = 28.dp, vertical = 12.dp),
            ) {
                Text("返回", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

internal fun RGBColor.Companion.fromHex(argb: Int): RGBColor = RGBColor(
    ((argb shr 16) and 0xFF) / 255f,
    ((argb shr 8) and 0xFF) / 255f,
    (argb and 0xFF) / 255f,
)
