package cn.locallens.lingdongzhaopian

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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.FormatQuote
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.QrCode
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.ViewWeek
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

private val StudioBackground = Color(0xFFF2F2F7)
private val StudioSecondary = Color.Black.copy(alpha = .55f)
private val StudioDivider = Color.Black.copy(alpha = .085f)
private val SystemBlue = Color(0xFF007AFF)

/**
 * Everything a ticket publishes lives behind this sheet: which credential to print, which fields
 * become public, and how to export the credential on its own.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TicketCodeStudioSheet(
    state: AppUiState,
    onPreferences: (AppPreferences) -> Unit,
    onTicketMessage: (String) -> Unit,
    onSaveCode: (TicketCodeStyle, ExportDestination) -> Unit,
    onDismiss: () -> Unit,
) {
    val preferences = state.preferences
    val payload = state.ticketPayload
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var verificationPreviewShown by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        containerColor = StudioBackground,
        tonalElevation = 0.dp,
        shape = RoundedCornerShape(topStart = 38.dp, topEnd = 38.dp),
    ) {
        Column(Modifier.fillMaxHeight(.94f)) {
            Box(
                Modifier.fillMaxWidth().height(66.dp).background(Color.White.copy(alpha = .80f)),
                contentAlignment = Alignment.Center,
            ) {
                Text("影像票根编码", fontSize = 17.sp, fontWeight = FontWeight.Bold)
                TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterEnd)) {
                    Text("完成", color = SystemBlue, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            LazyColumn(
                Modifier.fillMaxSize().testTag("ticket-studio"),
                contentPadding = PaddingValues(horizontal = 18.dp, vertical = 18.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("选择票根凭证", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            TicketCodeStyle.entries.forEach { style ->
                                CodeStyleCard(
                                    style = style,
                                    selected = style == preferences.ticketCodeStyle,
                                    modifier = Modifier.weight(1f),
                                ) { onPreferences(preferences.copy(ticketCodeStyle = style)) }
                            }
                        }
                    }
                }

                item {
                    CodePreview(
                        payload = payload,
                        style = preferences.ticketCodeStyle,
                        onPreviewVerification = { verificationPreviewShown = true },
                    )
                }

                item {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .background(Color.White, RoundedCornerShape(20.dp))
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(
                            if (preferences.ticketCodeStyle == TicketCodeStyle.Barcode) {
                                Icons.Outlined.ViewWeek
                            } else Icons.Outlined.QrCodeScanner,
                            null,
                            Modifier.size(20.dp),
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Text(
                                if (preferences.ticketCodeStyle == TicketCodeStyle.Barcode) {
                                    "真实可扫描的一维码"
                                } else "与 iPhone 版通用",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                            )
                            Text(
                                preferences.ticketCodeStyle.explanation,
                                color = StudioSecondary,
                                fontSize = 12.sp,
                                lineHeight = 17.sp,
                            )
                            if (preferences.ticketCodeStyle == TicketCodeStyle.VerificationQR) {
                                Text(
                                    "这里生成的二维码可以被 iPhone 版扫描验证；iPhone 生成的票根二维码也能在本机识别。",
                                    color = SystemBlue,
                                    fontSize = 12.sp,
                                    lineHeight = 17.sp,
                                )
                            }
                        }
                    }
                }

                item { HeaderOptions(preferences, onPreferences) }
                item { MessageOptions(state.ticketMessage, onTicketMessage) }
                item { PrivacyOptions(preferences, onPreferences) }

                item {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = { onSaveCode(preferences.ticketCodeStyle, ExportDestination.PhotoLibrary) },
                            modifier = Modifier.fillMaxWidth().height(50.dp),
                            shape = CircleShape,
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Black, contentColor = Color.White),
                        ) {
                            Text("保存编码到系统相册", fontWeight = FontWeight.Bold)
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            OutlinedButton(
                                onClick = { onSaveCode(preferences.ticketCodeStyle, ExportDestination.Files) },
                                modifier = Modifier.weight(1f).height(46.dp),
                                shape = CircleShape,
                            ) { Text("存到文件") }
                            OutlinedButton(
                                onClick = { onSaveCode(preferences.ticketCodeStyle, ExportDestination.Share) },
                                modifier = Modifier.weight(1f).height(46.dp),
                                shape = CircleShape,
                            ) { Text("分享") }
                        }
                    }
                }
            }
        }
    }

    if (verificationPreviewShown) {
        TicketVerificationDialog(payload) { verificationPreviewShown = false }
    }
}

@Composable
private fun MessageOptions(message: String, onMessage: (String) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(24.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            Icon(Icons.Outlined.FormatQuote, null, Modifier.size(20.dp))
            Text("票根寄语", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            Text(
                "${message.codePointCount(0, message.length)}/${TicketPayload.MAX_MESSAGE_LENGTH}",
                color = StudioSecondary,
                fontSize = 12.sp,
            )
        }
        OutlinedTextField(
            value = message,
            onValueChange = onMessage,
            modifier = Modifier.fillMaxWidth().testTag("ticket-message-field"),
            placeholder = { Text("写下一句话，留给以后扫码看到它的人") },
            minLines = 3,
            maxLines = 5,
            shape = RoundedCornerShape(13.dp),
        )
        Text(
            "寄语属于票根公开信息，会写入验证二维码，并显示在扫码后的详情页中。",
            color = StudioSecondary,
            fontSize = 12.sp,
            lineHeight = 17.sp,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TicketMessageEditorSheet(
    message: String,
    onSave: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var draft by remember(message) { mutableStateOf(message) }
    val normalized = TicketPayload.normalizedMessage(draft)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = StudioBackground,
        shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
    ) {
        Column(
            Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, bottom = 30.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text("取消", color = SystemBlue) }
                Spacer(Modifier.weight(1f))
                Text("补充票根寄语", fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                TextButton(
                    onClick = {
                        normalized?.let { value ->
                            scope.launch {
                                sheetState.hide()
                                onSave(value)
                            }
                        }
                    },
                    enabled = normalized != null,
                ) {
                    Text("完成", color = if (normalized == null) StudioSecondary else SystemBlue)
                }
            }
            Text(
                "这句话会作为公开信息写入二维码，任何扫码查看票根详情的人都能看到。",
                color = StudioSecondary,
                fontSize = 13.sp,
                lineHeight = 19.sp,
            )
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = TicketPayload.limitedMessage(it) },
                modifier = Modifier.fillMaxWidth().testTag("ticket-message-editor"),
                placeholder = { Text("写下一句想留给这段旅程的话") },
                minLines = 5,
                maxLines = 8,
                shape = RoundedCornerShape(16.dp),
            )
            Text(
                "${draft.codePointCount(0, draft.length)}/${TicketPayload.MAX_MESSAGE_LENGTH}",
                modifier = Modifier.align(Alignment.End),
                color = StudioSecondary,
                fontSize = 12.sp,
            )
        }
    }
}

@Composable
private fun CodeStyleCard(
    style: TicketCodeStyle,
    selected: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier
            .heightIn(min = 116.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(if (selected) SystemBlue.copy(alpha = .12f) else Color.White)
            .border(
                if (selected) 1.4.dp else 1.dp,
                if (selected) SystemBlue.copy(alpha = .72f) else Color.Black.copy(alpha = .07f),
                RoundedCornerShape(20.dp),
            )
            .clickable(onClick = onClick)
            .padding(15.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                if (style == TicketCodeStyle.Barcode) Icons.Outlined.ViewWeek else Icons.Outlined.QrCode,
                null,
                Modifier.size(21.dp),
            )
            Spacer(Modifier.weight(1f))
            if (selected) Icon(Icons.Outlined.CheckCircle, null, Modifier.size(19.dp), tint = SystemBlue)
        }
        Text(style.title, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        Text(
            if (style == TicketCodeStyle.Barcode) "保存与分享" else "扫码验证",
            color = StudioSecondary,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun CodePreview(payload: TicketPayload, style: TicketCodeStyle, onPreviewVerification: () -> Unit) {
    val bitmap = remember(payload, style) {
        runCatching {
            TicketCodeRenderer.image(
                style = style,
                payload = payload,
                pixelWidth = if (style == TicketCodeStyle.Barcode) 1_200 else 900,
                pixelHeight = if (style == TicketCodeStyle.Barcode) 300 else 900,
                foregroundColor = 0xFF000000.toInt(),
            )
        }.getOrNull()
    }
    Column(
        Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(24.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(style.title, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                Text(
                    payload.ticketID,
                    color = StudioSecondary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace,
                )
            }
            Icon(
                if (bitmap == null) Icons.Outlined.QrCode else Icons.Default.Check,
                if (bitmap == null) "编码生成失败" else "编码生成成功",
                Modifier.size(22.dp),
                tint = if (bitmap == null) Color(0xFFFF8A00) else Color(0xFF2E9E5B),
            )
        }

        if (bitmap == null) {
            Text("无法生成编码，请减少公开字段后重试。", color = StudioSecondary, fontSize = 12.sp)
        } else {
            BoxWithConstraints(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                val targetWidth = minOf(
                    maxWidth,
                    if (style == TicketCodeStyle.Barcode) 320.dp else 300.dp,
                )
                val targetHeight = if (style == TicketCodeStyle.Barcode) {
                    minOf(118.dp, targetWidth / 3f)
                } else {
                    targetWidth
                }
                Image(
                    bitmap.asImageBitmap(),
                    "票根编码预览",
                    modifier = Modifier
                        .width(targetWidth)
                        .height(targetHeight)
                        .clip(RoundedCornerShape(14.dp)),
                    contentScale = ContentScale.Fit,
                    filterQuality = FilterQuality.None,
                )
            }
        }

        if (style == TicketCodeStyle.VerificationQR) {
            OutlinedButton(
                onClick = onPreviewVerification,
                modifier = Modifier.fillMaxWidth().height(46.dp),
                shape = CircleShape,
            ) {
                Icon(Icons.Outlined.Visibility, null, Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("预览扫描后的验证界面", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun HeaderOptions(preferences: AppPreferences, onPreferences: (AppPreferences) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(24.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("票面主标题", fontSize = 16.sp, fontWeight = FontWeight.Bold)

        SegmentedRow(
            options = TicketHeaderMode.entries.map { it.label },
            selected = preferences.ticketHeaderMode.label,
        ) { label ->
            onPreferences(
                preferences.copy(ticketHeaderMode = TicketHeaderMode.entries.first { it.label == label })
            )
        }

        if (preferences.ticketHeaderMode == TicketHeaderMode.Custom) {
            OutlinedTextField(
                value = preferences.ticketCustomHeader,
                onValueChange = { onPreferences(preferences.copy(ticketCustomHeader = it)) },
                placeholder = { Text("可输入标题，也可以留空") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(13.dp),
            )
            Text("留空后，票根左上方不显示主标题。", color = StudioSecondary, fontSize = 12.sp)
        } else {
            SegmentedRow(
                options = TicketCityNameStyle.entries.map { it.label },
                selected = preferences.ticketCityNameStyle.label,
            ) { label ->
                onPreferences(
                    preferences.copy(
                        ticketCityNameStyle = TicketCityNameStyle.entries.first { it.label == label }
                    )
                )
            }
            Text(
                "灵动照片不联网，无法把照片坐标解析为城市名，因此这里会显示 LINGDONG。想要城市标题请改用“自定义”。",
                color = StudioSecondary,
                fontSize = 12.sp,
                lineHeight = 17.sp,
            )
        }
    }
}

@Composable
private fun PrivacyOptions(preferences: AppPreferences, onPreferences: (AppPreferences) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(24.dp))
            .padding(18.dp),
    ) {
        Text("票根公开信息", fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 12.dp))

        PrivacyToggle(Icons.Outlined.FormatQuote, "公开文案", null, preferences.ticketShowCopy) {
            onPreferences(preferences.copy(ticketShowCopy = it))
        }
        HorizontalDivider(color = StudioDivider)
        PrivacyToggle(Icons.Outlined.CalendarMonth, "公开拍摄时间", null, preferences.ticketShowDate) {
            onPreferences(preferences.copy(ticketShowDate = it))
        }
        HorizontalDivider(color = StudioDivider)
        PrivacyToggle(
            Icons.Outlined.LocationOn,
            "公开地点",
            "默认关闭；开启后任何扫描者都可以看到票根中的地点。",
            preferences.ticketShowPlace,
        ) { onPreferences(preferences.copy(ticketShowPlace = it)) }
        HorizontalDivider(color = StudioDivider)
        PrivacyToggle(Icons.Outlined.CameraAlt, "公开设备与镜头", null, preferences.ticketShowDevice) {
            onPreferences(preferences.copy(ticketShowDevice = it))
        }
        HorizontalDivider(color = StudioDivider)
        PrivacyToggle(Icons.Outlined.Tune, "公开拍摄参数", null, preferences.ticketShowParameters) {
            onPreferences(preferences.copy(ticketShowParameters = it))
        }
        HorizontalDivider(color = StudioDivider)
        PrivacyToggle(Icons.Outlined.Palette, "公开照片色盘", null, preferences.ticketShowPalette) {
            onPreferences(preferences.copy(ticketShowPalette = it))
        }

        Text(
            "二维码内容可以被任何扫描者读取，不包含原始照片、相册标识、文件路径或设备序列号。",
            color = StudioSecondary,
            fontSize = 12.sp,
            lineHeight = 17.sp,
            modifier = Modifier.padding(top = 14.dp),
        )
    }
}

@Composable
private fun PrivacyToggle(
    icon: ImageVector,
    title: String,
    subtitle: String?,
    value: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Icon(icon, null, Modifier.size(20.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            subtitle?.let { Text(it, color = StudioSecondary, fontSize = 11.sp, lineHeight = 14.sp) }
        }
        Switch(checked = value, onCheckedChange = onChange)
    }
}

@Composable
private fun SegmentedRow(options: List<String>, selected: String, onSelected: (String) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(11.dp))
            .background(Color.Black.copy(alpha = .06f))
            .padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            Box(
                Modifier
                    .weight(1f)
                    .height(34.dp)
                    .clip(RoundedCornerShape(9.dp))
                    .background(if (isSelected) Color.White else Color.Transparent)
                    .clickable { onSelected(option) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    option,
                    fontSize = 13.sp,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                )
            }
        }
    }
}
