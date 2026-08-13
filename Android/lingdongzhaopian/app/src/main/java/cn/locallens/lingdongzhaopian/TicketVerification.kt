package cn.locallens.lingdongzhaopian

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.AccessTime
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.delay
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

@Composable
fun TicketVerificationDialog(payload: TicketPayload, onClose: () -> Unit) {
    TicketVerificationDialog(
        VerifiedTicket(payload, TicketSealValidation.Unsigned),
        onClose,
    )
}

@Composable
fun TicketVerificationDialog(ticket: VerifiedTicket, onClose: () -> Unit) {
    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false),
    ) {
        TicketVerificationScreen(ticket, onClose)
    }
}

/**
 * Local mirror of the iOS App Clip verification page. Nothing here reaches the network or the photo
 * library: every value comes from the scanned code itself.
 */
@Composable
fun TicketVerificationScreen(payload: TicketPayload, onClose: () -> Unit) {
    TicketVerificationScreen(
        VerifiedTicket(payload, TicketSealValidation.Unsigned),
        onClose,
    )
}

@Composable
fun TicketVerificationScreen(ticket: VerifiedTicket, onClose: () -> Unit) {
    val payload = ticket.payload
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
            item { VerificationHeader(payload.style == "e", onClose) }
            item { HeroTicket(payload, ticket.sealValidation) }
            if (payload.style == "e") item { TimeCapsulePanel(payload) }
            payload.message?.let { message -> item { MessagePanel(message, payload.style == "e", payload.narrative != "shared") } }
            if (payload.palette.isNotEmpty()) item { PalettePanel(payload, colors) }
            item { MetadataPanel(payload) }
            item { SealPanel(ticket.sealValidation) }
            item { PrivacyPanel() }
        }

        if (!revealed) {
            TicketRevealLayer(payload.revealLayout ?: "c", colors)
        }
    }
}

@Composable
private fun VerificationHeader(emotional: Boolean, onClose: () -> Unit) {
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
            Text(if (emotional) "影像票根 · 时光胶囊" else "影像票根 · 本地验证", color = Color.White.copy(alpha = .64f), fontSize = 12.sp)
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
private fun HeroTicket(payload: TicketPayload, validation: TicketSealValidation) {
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
                    val valid = validation is TicketSealValidation.Valid
                    val invalid = validation is TicketSealValidation.Invalid
                    Icon(
                        Icons.Outlined.Verified,
                        null,
                        Modifier.size(14.dp),
                        tint = if (invalid) Color(0xFFFF6B6B) else Color.White,
                    )
                    Text(
                        when {
                            valid -> "设备封印有效"
                            invalid -> "设备封印已失效"
                            else -> "公开信息完整"
                        },
                        color = if (invalid) Color(0xFFFF6B6B) else Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                    )
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
                if (payload.style == "e") "时光印记 ${payload.fingerprint}" else "照片指纹 ${payload.fingerprint}",
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
private fun SealPanel(validation: TicketSealValidation) {
    val title: String
    val description: String
    val tint: Color
    when (validation) {
        TicketSealValidation.Unsigned -> {
            title = "这张票根没有设备封印"
            description = "仍可查看公开信息，但无法判断生成后是否被重新改写。较早版本生成的票根也会显示为未封印。"
            tint = Color.White.copy(alpha = .78f)
        }
        is TicketSealValidation.Valid -> {
            title = if (validation.origin.hardwareBacked) "设备封印通过" else "签名校验通过"
            val source = when (validation.origin) {
                TicketSealOrigin.AppleSecureEnclave -> "票根标记为由 iPhone 安全隔区中的设备密钥盖章"
                TicketSealOrigin.AndroidHardware -> "票根标记为由 Android 设备的硬件密钥盖章"
                TicketSealOrigin.AndroidSoftware -> "票根标记为由 Android 软件保护的设备密钥盖章"
                TicketSealOrigin.SimulatorTest -> "这是模拟器测试签名，不代表真实硬件保护"
                TicketSealOrigin.Unknown -> "票根标记为由兼容的 P-256 设备密钥盖章"
            }
            description = "$source，公开信息从盖章后没有发生变化。密钥编号 ${validation.keyID}。"
            tint = Color(0xFF39D66F)
        }
        is TicketSealValidation.Invalid -> {
            title = "设备封印没有通过"
            description = "票根的公开信息或签名已发生变化。你仍可查看内容，但不要把它当作原始票根。"
            tint = Color(0xFFFF6B6B)
        }
    }
    TicketGlassPanel(cornerRadius = 24.dp, padding = 18.dp) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(contentAlignment = Alignment.BottomEnd) {
                LingdongLiquidGlassIcon(Modifier.size(28.dp))
                DeviceBrandBadge(
                    deviceType = sealDeviceType(validation),
                    modifier = Modifier.offset(x = 2.dp, y = 2.dp),
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(title, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text(description, color = Color.White.copy(alpha = .62f), fontSize = 12.sp, lineHeight = 17.sp)
            }
        }
    }
}

private fun sealDeviceType(validation: TicketSealValidation): String = when (validation) {
    TicketSealValidation.Unsigned -> "unsigned"
    is TicketSealValidation.Invalid -> "invalid"
    is TicketSealValidation.Valid -> when (validation.origin) {
        TicketSealOrigin.AppleSecureEnclave -> "apple"
        TicketSealOrigin.AndroidHardware, TicketSealOrigin.AndroidSoftware -> "android"
        TicketSealOrigin.SimulatorTest, TicketSealOrigin.Unknown -> "unknown"
    }
}

@Composable
private fun TimeCapsulePanel(payload: TicketPayload) {
    val selfPerspective = payload.narrative != "shared"
    val captureText = ticketRelativeTime(payload.captureTime)
    val captureToSeal = ticketDaysBetween(payload.captureTime, payload.sealedAt)
    val headline = when {
        captureText != null && selfPerspective && (captureToSeal == null || captureToSeal <= 0) -> "🕰️ 这是一段${captureText}的回忆"
        captureText != null && selfPerspective -> "🕰️ ${captureText}的光影，由你封存成这枚票根"
        captureText != null && !selfPerspective && (captureToSeal == null || captureToSeal <= 0) -> "🌿 这是${captureText}留下的一段光影"
        captureText != null -> "🌿 ${captureText}的光影，被创作者封存于此"
        selfPerspective -> "🕰️ 一段由你封存的回忆"
        else -> "🌿 一段创作者封存的光影"
    }
    val subtitle = if (selfPerspective) {
        if (captureToSeal != null && captureToSeal > 0) "那一刻的光、色与心情，被后来的你亲手封存于此。" else "这张票根由你亲手封存，记录了那一刻的光、色与心情。"
    } else {
        if (captureToSeal != null && captureToSeal > 0) "创作者在那一刻按下快门，后来的 TA 将这段色彩与时间凝固于此。" else "创作者在那一刻按下快门，让这段色彩与时间凝固于此。"
    }
    TicketGlassPanel(cornerRadius = 26.dp, padding = 20.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            PanelTitle(Icons.Outlined.AccessTime, "时光胶囊")
            Text(headline, color = Color.White, fontSize = 18.sp, lineHeight = 25.sp, fontWeight = FontWeight.Bold)
            Text(subtitle, color = Color.White.copy(alpha = .62f), fontSize = 12.sp, lineHeight = 18.sp)
            payload.captureTime?.let { Text("拍摄于 $it", color = Color.White.copy(alpha = .58f), fontSize = 12.sp) }
            payload.place?.let { Text(it, color = Color.White.copy(alpha = .58f), fontSize = 12.sp) }
        }
    }
}

private val ticketTimeFormatter = DateTimeFormatter.ofPattern("yyyy/MM/dd, HH:mm")

private fun ticketParsedTime(value: String?): LocalDateTime? =
    value?.let { runCatching { LocalDateTime.parse(it, ticketTimeFormatter) }.getOrNull() }

private fun ticketDaysBetween(start: String?, end: String?): Long? {
    val first = ticketParsedTime(start) ?: return null
    val second = ticketParsedTime(end) ?: return null
    return ChronoUnit.DAYS.between(first.toLocalDate(), second.toLocalDate())
}

private fun ticketRelativeTime(value: String?): String? {
    val date = ticketParsedTime(value)?.toLocalDate() ?: return null
    val days = ChronoUnit.DAYS.between(date, java.time.LocalDate.now())
    return when {
        days <= 0 -> "今天"
        days == 1L -> "昨天"
        days < 30 -> "$days 天前"
        days < 365 -> "${days / 30} 个月前"
        days % 365 < 30 -> "${days / 365} 年前"
        else -> "${days / 365} 年 ${days % 365 / 30} 个月前"
    }
}

@Composable
private fun MessagePanel(message: String, emotional: Boolean, selfPerspective: Boolean) {
    TicketGlassPanel(cornerRadius = 26.dp, padding = 20.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(13.dp)) {
            PanelTitle(
                Icons.Outlined.FormatQuote,
                if (emotional) if (selfPerspective) "写给过去的备忘" else "创作者留下的寄语" else "票根寄语",
            )
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
            PanelTitle(Icons.Outlined.CameraAlt, if (payload.style == "e") "影像档案" else "拍摄信息")
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

@Composable
private fun LingdongLiquidGlassIcon(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val designSize = 100f
        val scale = size.minDimension / designSize
        val cx = size.width / 2f
        val lensW = 80f * scale
        val lensH = 45f * scale
        val lensX = (size.width - lensW) / 2f

        drawGlassLens(
            x = lensX, y = cx - lensH / 2f + 20f * scale,
            w = lensW, h = lensH,
            colors = listOf(Color(red = 0.2f, green = 0.8f, blue = 0.6f), Color(red = 0.0f, green = 0.4f, blue = 0.3f)),
            waveOpacity = 0.4f,
        )
        drawGlassLens(
            x = lensX, y = cx - lensH / 2f,
            w = lensW, h = lensH,
            colors = listOf(Color(red = 0.5f, green = 0.9f, blue = 0.4f), Color(red = 0.1f, green = 0.6f, blue = 0.4f)),
            waveOpacity = 0.5f,
        )
        drawGlassLens(
            x = lensX, y = cx - lensH / 2f - 20f * scale,
            w = lensW, h = lensH,
            colors = listOf(Color(red = 0.9f, green = 0.95f, blue = 0.3f), Color(red = 0.4f, green = 0.8f, blue = 0.2f)),
            waveOpacity = 0.6f,
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawGlassLens(
    x: Float,
    y: Float,
    w: Float,
    h: Float,
    colors: List<Color>,
    waveOpacity: Float,
) {
    drawOval(
        color = Color.Black.copy(alpha = 0.18f),
        topLeft = Offset(x = x, y = y + h * 0.22f),
        size = Size(width = w, height = h),
    )

    drawOval(
        brush = Brush.linearGradient(
            colors = colors,
            start = Offset(x = x, y = y),
            end = Offset(x = x + w, y = y + h),
        ),
        topLeft = Offset(x = x, y = y),
        size = Size(width = w, height = h),
    )

    val wavePath = Path().apply {
        moveTo(x, y + h * 0.6f)
        cubicTo(
            x1 = x + w * 0.35f, y1 = y + h * 0.8f,
            x2 = x + w * 0.65f, y2 = y + h * 0.2f,
            x3 = x + w, y3 = y + h * 0.4f,
        )
        lineTo(x + w, y)
        lineTo(x, y)
        close()
    }
    val ovalClipPath = Path().apply {
        addOval(Rect(left = x, top = y, right = x + w, bottom = y + h))
    }
    clipPath(path = ovalClipPath) {
        drawPath(
            path = wavePath,
            brush = Brush.verticalGradient(
                colors = listOf(Color.White.copy(alpha = waveOpacity), Color.Transparent),
                startY = y,
                endY = y + h,
            ),
        )
    }

    drawOval(
        brush = Brush.verticalGradient(
            colors = listOf(Color.Transparent, Color.White.copy(alpha = 0.6f)),
            startY = y,
            endY = y + h,
        ),
        style = Stroke(width = 1.5.dp.toPx()),
        topLeft = Offset(x = x, y = y),
        size = Size(width = w, height = h),
    )

    drawOval(
        brush = Brush.verticalGradient(
            colors = listOf(Color.White.copy(alpha = 0.9f), Color.Transparent),
            startY = y,
            endY = y + h,
        ),
        style = Stroke(width = 1.5.dp.toPx()),
        topLeft = Offset(x = x, y = y),
        size = Size(width = w, height = h),
    )

    drawCircle(
        color = Color.White,
        radius = 2.dp.toPx(),
        center = Offset(x = x + w * 0.75f, y = y + h * 0.1f),
    )
}

@Composable
private fun DeviceBrandBadge(deviceType: String, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.size(14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(14.dp)
                .shadow(
                    elevation = 1.2.dp,
                    shape = CircleShape,
                    ambientColor = Color.Black.copy(alpha = 0.18f),
                    spotColor = Color.Black.copy(alpha = 0.18f),
                )
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.72f))
                .border(
                    width = 0.5.dp,
                    color = Color.White.copy(alpha = 0.5f),
                    shape = CircleShape,
                ),
        )

        when (deviceType) {
            "apple" -> Image(
                painter = painterResource(R.drawable.ic_badge_apple),
                contentDescription = "Apple",
                modifier = Modifier.size(8.dp),
            )

            "android" -> Image(
                painter = painterResource(R.drawable.ic_badge_android),
                contentDescription = "Android",
                modifier = Modifier.size(8.dp),
            )

            "unsigned" -> Image(
                painter = painterResource(R.drawable.ic_badge_xmark),
                contentDescription = "Unsigned",
                modifier = Modifier.size(7.dp),
            )

            "invalid" -> Image(
                painter = painterResource(R.drawable.ic_badge_invalid),
                contentDescription = "Invalid seal",
                modifier = Modifier.size(8.dp),
            )

            else -> {
                Text(
                    text = "?",
                    style = TextStyle(
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Black,
                        color = Color.Black,
                    ),
                )
            }
        }
    }
}
