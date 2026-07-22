package cn.locallens.lingdongzhaopian

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.AspectRatio
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.BlurOn
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Brush
import androidx.compose.material.icons.outlined.BubbleChart
import androidx.compose.material.icons.outlined.CameraRoll
import androidx.compose.material.icons.outlined.CenterFocusStrong
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Copyright
import androidx.compose.material.icons.outlined.Crop
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.FormatColorText
import androidx.compose.material.icons.outlined.FormatQuote
import androidx.compose.material.icons.outlined.FormatSize
import androidx.compose.material.icons.outlined.Gesture
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Keyboard
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.LocationOff
import androidx.compose.material.icons.outlined.MotionPhotosOn
import androidx.compose.material.icons.outlined.OpenInFull
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Percent
import androidx.compose.material.icons.outlined.PhoneIphone
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material.icons.outlined.PrivacyTip
import androidx.compose.material.icons.outlined.ScreenRotation
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Square
import androidx.compose.material.icons.outlined.Tag
import androidx.compose.material.icons.outlined.TextFormat
import androidx.compose.material.icons.outlined.TouchApp
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.Wallpaper
import androidx.compose.material.icons.outlined.Window
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val SettingsBackground = Color(0xFFF2F2F7)
private val SystemBlue = Color(0xFF007AFF)
private val SecondaryText = Color.Black.copy(alpha = .55f)
private val SectionDivider = Color.Black.copy(alpha = .085f)

@Composable
fun SettingsScreen(
    state: AppUiState,
    onMode: (CreationMode) -> Unit,
    onRatio: (ArtworkRatio) -> Unit,
    onPreferences: (AppPreferences) -> Unit,
    @Suppress("UNUSED_PARAMETER") onClose: () -> Unit,
) {
    Column(Modifier.fillMaxSize().background(SettingsBackground)) {
        Box(
            Modifier.fillMaxWidth().height(66.dp).background(Color.White.copy(alpha = .82f)),
            contentAlignment = Alignment.Center,
        ) {
            Text("设置", fontSize = 17.sp, fontWeight = FontWeight.Bold)
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            item {
                SettingsSection("模式选择") {
                    CreationMode.entries.forEachIndexed { index, mode ->
                        ModeRow(mode, selected = state.mode == mode, onClick = { onMode(mode) })
                        if (index < CreationMode.entries.lastIndex) SettingsDivider()
                    }
                }
            }

            item {
                SettingsSection("免费承诺") {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("灵动照片", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                            Text(
                                "完全免费",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.border(1.dp, Color.Black.copy(alpha = .65f), CircleShape)
                                    .padding(horizontal = 8.dp, vertical = 3.dp),
                            )
                        }
                        Text("无试用期、无订阅、无内购、无隐藏收费", fontSize = 14.sp)
                        Box(
                            Modifier.fillMaxWidth().height(48.dp).background(Color.Black, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("永久免费 · 谨防被骗", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            item {
                SettingsSection("界面选项") {
                    SettingsSwitchRow(
                        Icons.Outlined.TextFormat,
                        "显示应用标题",
                        "控制编辑界面左上角是否显示“灵动照片”，不影响导出作品。",
                        state.preferences.showAppTitle,
                    ) { onPreferences(state.preferences.copy(showAppTitle = it)) }
                }
            }

            item {
                SettingsSection("琉璃色盘选项") {
                    EnumRow(Icons.Outlined.Window, "排版模式", state.preferences.paletteLayout.label, PaletteLayoutMode.entries.map { it.label }) { label ->
                        onPreferences(state.preferences.copy(paletteLayout = PaletteLayoutMode.entries.first { it.label == label }))
                    }
                    SettingsDivider()
                    TipRow(Icons.Outlined.Info, "Android 13+ 使用 GPU 液态折射；不支持运行时着色器的设备自动使用兼容磨砂效果。导出时也会按下方开关生成玻璃质感。")
                    SettingsDivider()
                    TipRow(Icons.Outlined.TouchApp, "拖动色盘可调整其上下位置")
                    SettingsDivider()
                    RatioRow(state, onRatio)
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.MotionPhotosOn, "支持动态照片", null, state.preferences.supportsMotionPhotos) {
                        onPreferences(state.preferences.copy(supportsMotionPhotos = it))
                    }
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.Tag, "显示颜色值", null, state.preferences.showHexValues) {
                        onPreferences(state.preferences.copy(showHexValues = it))
                    }
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.Percent, "显示颜色占比", "关闭后，琉璃色盘将不再显示各颜色所占百分比。", state.preferences.showPalettePercentages) {
                        onPreferences(state.preferences.copy(showPalettePercentages = it))
                    }
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.FormatColorText, "用颜色名称替换颜色码", "将颜色代码替换为极具文学气息的自然命名。", state.preferences.useLiteraryColorNames) {
                        onPreferences(state.preferences.copy(useLiteraryColorNames = it))
                    }
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.Square, "导出图保留色盘背景", null, state.preferences.preservePaletteBackground) {
                        onPreferences(state.preferences.copy(preservePaletteBackground = it))
                    }
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.BlurOn, "保存的图片应用液态玻璃质感", "关闭后导出为更轻量的经典磨砂面板。", state.preferences.applyLiquidGlassOnExport) {
                        onPreferences(state.preferences.copy(applyLiquidGlassOnExport = it))
                    }
                }
            }

            item {
                SettingsSection("灵动卡片操作技巧") {
                    TemplateRow(state, onPreferences)
                    SettingsDivider()
                    RatioRow(state, onRatio)
                    SettingsDivider()
                    TipRow(Icons.Outlined.OpenInFull, "拖拽图片调整构图，双指捏合缩放")
                    SettingsDivider()
                    TipRow(Icons.Outlined.Keyboard, "点击文字即可直接编辑")
                    SettingsDivider()
                    TipRow(Icons.Outlined.TextFormat, "切换字体：在文字上方空白处左右滑动")
                    SettingsDivider()
                    TipRow(Icons.Outlined.FormatSize, "调节大小：在文字下方空白处左右滑动")
                    SettingsDivider()
                    TipRow(Icons.Outlined.ScreenRotation, "晃动手机以恢复卡片初始视图")
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.FormatQuote, "总是显示意境文案", "即使图片存在位置信息，也优先显示根据画面内容与色彩生成的意境文案。", state.preferences.showMoodCopy) {
                        onPreferences(state.preferences.copy(showMoodCopy = it))
                    }
                }
            }

            item {
                SettingsSection("气泡印章操作技巧") {
                    TemplateRow(state, onPreferences)
                    SettingsDivider()
                    RatioRow(state, onRatio)
                    SettingsDivider()
                    TipRow(Icons.Outlined.OpenInFull, "拖拽图片调整构图，双指捏合缩放")
                    SettingsDivider()
                    TipRow(Icons.Outlined.Keyboard, "点击标题即可编辑（拍摄参数不可编辑）")
                    SettingsDivider()
                    TipRow(Icons.Outlined.TextFormat, "切换字体：在文字上方空白处左右滑动")
                    SettingsDivider()
                    TipRow(Icons.Outlined.FormatSize, "调节大小：在文字下方空白处左右滑动")
                    SettingsDivider()
                    TipRow(Icons.Outlined.BubbleChart, "调节气泡大小：在气泡左侧空白区域上下滑动")
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.PhoneIphone, "显示手机和相机信息", null, state.preferences.showDeviceInfo) {
                        onPreferences(state.preferences.copy(showDeviceInfo = it))
                    }
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.BubbleChart, "显示气泡", null, state.preferences.showBubbles) {
                        onPreferences(state.preferences.copy(showBubbles = it))
                    }
                }
            }

            item {
                SettingsSection("一键手帐选项") {
                    TipRow(Icons.Outlined.Info, "使用顶部加号继续添加，选中缩略图后可替换、重排或删除；点击 Emoji 或文案可直接编辑")
                    SettingsDivider()
                    EnumRow(Icons.Outlined.GridView, "拼图模板", state.preferences.journalLayout.label, JournalLayoutMode.entries.map { it.label }) { label ->
                        onPreferences(state.preferences.copy(journalLayout = JournalLayoutMode.entries.first { it.label == label }))
                    }
                    SettingsDivider()
                    RatioRow(state, onRatio)
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.MotionPhotosOn, "支持动态照片", null, state.preferences.supportsMotionPhotos) {
                        onPreferences(state.preferences.copy(supportsMotionPhotos = it))
                    }
                    SettingsDivider()
                    SettingsSwitchRow(Icons.Outlined.Square, "淡雅背景色", null, state.preferences.gentleBackground) {
                        onPreferences(state.preferences.copy(gentleBackground = it))
                    }
                }
            }

            item {
                SettingsSection("色谱壁纸选项") {
                    TipRow(Icons.Outlined.Info, "生成的壁纸仅适配当前设备尺寸")
                    SettingsDivider()
                    TipRow(Icons.Outlined.Copyright, "本应用完全免费；版权所有，禁止商业转售")
                }
            }

            item {
                SettingsSection("隐私马赛克选项") {
                    TipRow(Icons.Outlined.Brush, "进入“手动涂抹”后，单指用于添加或擦除马赛克；完成后恢复拖动照片")
                    SettingsDivider()
                    TipRow(Icons.Outlined.VisibilityOff, "智能识别会在本机检测人脸、车牌、二维码及手机号、地址、证件号等敏感文字")
                    SettingsDivider()
                    TipRow(Icons.Outlined.PrivacyTip, "点击自动识别区域可关闭遮挡，再次点击即可恢复；手动画笔可切换为橡皮擦")
                    SettingsDivider()
                    TipRow(Icons.Outlined.BlurOn, "导出使用明确的强模糊像素马赛克，不使用可能看清原内容的透明玻璃遮挡")
                    SettingsDivider()
                    TipRow(Icons.Outlined.CameraRoll, "为避免后续动态帧泄露隐私，隐私马赛克仅支持静态导出")
                    SettingsDivider()
                    TipRow(Icons.Outlined.LocationOff, "保存前可选择移除 GPS 位置信息，形成完整的隐私导出")
                }
            }

            item {
                Column(
                    Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text("版本 1.0.0 (Build 1)", color = SecondaryText, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    Text("灵动照片 · 完全免费", color = SecondaryText, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    Text("本开源项目由专注隐私的 LocalLens Project 发起", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun ModeRow(mode: CreationMode, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 18.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(modeIcon(mode), null, Modifier.size(19.dp).widthIn(min = 34.dp), tint = Color.Black.copy(alpha = .86f))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(mode.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                if (mode == CreationMode.Journal || mode == CreationMode.PrivacyMosaic) {
                    Text(
                        "新",
                        color = Color.White,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.background(Color.Red, CircleShape).padding(horizontal = 6.dp, vertical = 3.dp),
                    )
                }
            }
            Text(mode.subtitle, color = SecondaryText, fontSize = 11.sp, lineHeight = 14.sp, maxLines = 2)
        }
        if (selected) Icon(Icons.Default.Check, null, Modifier.size(18.dp), tint = SystemBlue)
    }
}

private fun modeIcon(mode: CreationMode): ImageVector = when (mode) {
    CreationMode.MotionCard -> Icons.Outlined.MotionPhotosOn
    CreationMode.ColorPalette -> Icons.Outlined.Palette
    CreationMode.Journal -> Icons.Outlined.BookmarkBorder
    CreationMode.BubbleStamp -> Icons.Outlined.Verified
    CreationMode.SpectrumWallpaper -> Icons.Outlined.Layers
    CreationMode.PrivacyMosaic -> Icons.Outlined.VisibilityOff
}

@Composable
private fun SettingsSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            title,
            color = SecondaryText,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 20.dp),
        )
        Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(28.dp))) { content() }
    }
}

@Composable
private fun SettingsSwitchRow(icon: ImageVector, title: String, subtitle: String?, value: Boolean, onChange: (Boolean) -> Unit) {
    SettingRow(icon, title, subtitle) { Switch(checked = value, onCheckedChange = onChange) }
}

@Composable
private fun SettingRow(icon: ImageVector, title: String, subtitle: String? = null, trailing: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(icon, null, Modifier.size(18.dp).widthIn(min = 34.dp), tint = Color.Black.copy(alpha = .82f))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, fontSize = 14.sp)
            subtitle?.let { Text(it, color = SecondaryText, fontSize = 11.sp, lineHeight = 14.sp) }
        }
        Spacer(Modifier.width(0.dp))
        trailing()
    }
}

@Composable
private fun TipRow(icon: ImageVector, text: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(icon, null, Modifier.size(18.dp).widthIn(min = 34.dp), tint = Color.Black.copy(alpha = .82f))
        Text(text, fontSize = 13.sp, lineHeight = 17.sp, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun EnumRow(icon: ImageVector, title: String, selected: String, options: List<String>, onSelected: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        SettingRow(icon, title) {
            Box {
                Text(
                    selected,
                    color = SystemBlue,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.clickable { expanded = true }.padding(vertical = 8.dp),
                )
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    options.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option, fontWeight = if (option == selected) FontWeight.SemiBold else FontWeight.Normal) },
                            trailingIcon = { if (option == selected) Icon(Icons.Default.Check, null, Modifier.size(17.dp), tint = SystemBlue) },
                            onClick = { onSelected(option); expanded = false },
                        )
                    }
                }
            }
        }
        if (!expanded) Box(Modifier.matchParentSize().clickable { expanded = true })
    }
}

@Composable
private fun SettingsDivider() {
    HorizontalDivider(Modifier.padding(start = 68.dp), color = SectionDivider)
}

@Composable
private fun RatioRow(state: AppUiState, onRatio: (ArtworkRatio) -> Unit) {
    EnumRow(Icons.Outlined.AspectRatio, "图片比例", state.ratio.label, ArtworkRatio.entries.map { it.label }) { label ->
        onRatio(ArtworkRatio.entries.first { it.label == label })
    }
}

@Composable
private fun TemplateRow(state: AppUiState, onPreferences: (AppPreferences) -> Unit) {
    EnumRow(Icons.Outlined.Crop, "作品模板", state.preferences.templateStyle.label, ArtworkTemplateStyle.entries.map { it.label }) { label ->
        onPreferences(state.preferences.copy(templateStyle = ArtworkTemplateStyle.entries.first { it.label == label }))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CopyEditorDialog(
    state: AppUiState,
    onSave: (ArtworkCopy) -> Unit,
    onRegenerate: () -> Unit,
    @Suppress("UNUSED_PARAMETER") onFontStyle: (ArtworkFontStyle) -> Unit,
    @Suppress("UNUSED_PARAMETER") onTextScale: (Float) -> Unit,
    @Suppress("UNUSED_PARAMETER") onBubbleScale: (Float) -> Unit,
    onDismiss: () -> Unit,
) {
    var title by remember(state.artworkCopy) { mutableStateOf(state.artworkCopy.title) }
    var subtitle by remember(state.artworkCopy) { mutableStateOf(state.artworkCopy.subtitle) }
    var emojis by remember(state.artworkCopy) { mutableStateOf(state.artworkCopy.emojis) }
    var caption by remember(state.artworkCopy) { mutableStateOf(state.artworkCopy.journalCaption) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    fun commit() = onSave(ArtworkCopy(title, subtitle, caption, emojis))

    ModalBottomSheet(
        onDismissRequest = { commit(); onDismiss() },
        sheetState = sheetState,
        dragHandle = null,
        containerColor = SettingsBackground,
        shape = RoundedCornerShape(topStart = 38.dp, topEnd = 38.dp),
    ) {
        Column(Modifier.fillMaxHeight(.94f)) {
            SheetHeader("编辑作品文字", actionTitle = "完成") { commit(); onDismiss() }
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 18.dp),
                verticalArrangement = Arrangement.spacedBy(22.dp),
            ) {
                item {
                    FormSection("系统识别") {
                        val semantic = state.photos.firstOrNull()?.semantic
                        FormInformationRow(Icons.Outlined.CenterFocusStrong, semantic?.category ?: "日常瞬间", FontWeight.SemiBold)
                        semantic?.labels?.take(3)?.takeIf { it.isNotEmpty() }?.let { labels ->
                            SettingsDivider()
                            Text("画面内容：${labels.joinToString(" · ")}", color = SecondaryText, fontSize = 12.sp, modifier = Modifier.padding(16.dp))
                        }
                        SettingsDivider()
                        Row(
                            Modifier.fillMaxWidth().clickable(onClick = onRegenerate).padding(16.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Outlined.AutoAwesome, null, Modifier.size(19.dp), tint = SystemBlue)
                            Text("换一组智能文案与 Emoji", color = SystemBlue, fontSize = 14.sp)
                        }
                        SettingsDivider()
                        Text("由 Android ML Kit 在本机识别画面，不会上传照片。", color = SecondaryText, fontSize = 12.sp, modifier = Modifier.padding(16.dp))
                    }
                }
                if (state.mode == CreationMode.MotionCard || state.mode == CreationMode.BubbleStamp) {
                    item { EditorFieldSection("标题", "输入标题", title) { title = it } }
                }
                if (state.mode == CreationMode.BubbleStamp) {
                    item { EditorFieldSection("英文副标题", "输入副标题", subtitle) { subtitle = it } }
                }
                if (state.mode == CreationMode.Journal) {
                    item { EditorFieldSection("Emoji", "输入 Emoji", emojis) { emojis = it } }
                    item { EditorFieldSection("手帐文案", "输入文案", caption) { caption = it } }
                }
                item {
                    FormSection(null) {
                        Text("所有文字只用于本次作品，不会上传到网络。", color = SecondaryText, fontSize = 12.sp, modifier = Modifier.padding(16.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun EditorFieldSection(title: String, placeholder: String, value: String, onValueChange: (String) -> Unit) {
    FormSection(title) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder) },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            minLines = 1,
            maxLines = 4,
            shape = RoundedCornerShape(12.dp),
        )
    }
}

@Composable
private fun FormSection(title: String?, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        title?.let { Text(it, color = SecondaryText, fontSize = 13.sp, modifier = Modifier.padding(start = 16.dp)) }
        Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(16.dp))) { content() }
    }
}

@Composable
private fun FormInformationRow(icon: ImageVector, text: String, weight: FontWeight = FontWeight.Normal) {
    Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, Modifier.size(19.dp))
        Text(text, fontSize = 14.sp, fontWeight = weight)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExportCenterDialog(state: AppUiState, onPreferences: (AppPreferences) -> Unit, onExport: () -> Unit, onDismiss: () -> Unit) {
    val p = state.preferences
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val hasMotionExport = state.mode != CreationMode.PrivacyMosaic && p.supportsMotionPhotos && state.photos.any { it.isMotionPhoto }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        containerColor = SettingsBackground,
        tonalElevation = 0.dp,
        shape = RoundedCornerShape(topStart = 38.dp, topEnd = 38.dp),
    ) {
        Column(Modifier.fillMaxHeight(.94f)) {
            SheetHeader("导出作品", actionTitle = "取消", actionAtStart = true, onAction = onDismiss)
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 18.dp, vertical = 18.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                item {
                    ExportSection("保存位置") {
                        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                            ExportDestination.entries.forEach { destination ->
                                DestinationButton(destination, selected = p.exportDestination == destination, Modifier.weight(1f)) {
                                    onPreferences(p.copy(exportDestination = destination))
                                }
                            }
                        }
                    }
                }
                item {
                    ExportSection("画质与格式") {
                        ExportPickerRow(Icons.Outlined.OpenInFull, "输出尺寸", p.exportResolution.label, ExportResolution.entries.map { it.label }) { label ->
                            onPreferences(p.copy(exportResolution = ExportResolution.entries.first { it.label == label }))
                        }
                        HorizontalDivider(color = SectionDivider)
                        ExportPickerRow(Icons.Outlined.Description, "图片格式", p.exportFormat.label, ExportFormat.entries.map { it.label }) { label ->
                            onPreferences(p.copy(exportFormat = ExportFormat.entries.first { it.label == label }))
                        }
                        Text("${p.exportResolution.detail} · ${p.exportFormat.detail}", color = SecondaryText, fontSize = 11.sp)
                    }
                }
                item {
                    ExportSection("元数据隐私") {
                        MetadataPolicy.entries.forEach { policy ->
                            MetadataPolicyRow(policy, selected = p.metadataPolicy == policy) { onPreferences(p.copy(metadataPolicy = policy)) }
                        }
                    }
                }
                if (hasMotionExport) {
                    item {
                        Row(Modifier.padding(horizontal = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Outlined.MotionPhotosOn, null, Modifier.size(17.dp), tint = SecondaryText)
                            Text(
                                if (p.exportDestination == ExportDestination.PhotoLibrary) "保存到相册时将保留 Motion Photo；动态作品使用 JPEG 封面。" else "文件与系统分享导出静态成品；保存到相册可保留 Motion Photo。",
                                color = SecondaryText,
                                fontSize = 11.sp,
                                lineHeight = 15.sp,
                            )
                        }
                    }
                }
                item {
                    Button(
                        onClick = { onDismiss(); onExport() },
                        modifier = Modifier.fillMaxWidth().height(56.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Black, contentColor = Color.White),
                        contentPadding = PaddingValues(horizontal = 18.dp),
                    ) {
                        Icon(destinationIcon(p.exportDestination), null, Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(exportTitle(p.exportDestination), fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

@Composable
private fun SheetHeader(title: String, actionTitle: String, actionAtStart: Boolean = false, onAction: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().height(66.dp).background(Color.White.copy(alpha = .80f)),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold)
        TextButton(onClick = onAction, modifier = Modifier.align(if (actionAtStart) Alignment.CenterStart else Alignment.CenterEnd)) {
            Text(actionTitle, color = SystemBlue, fontSize = 15.sp, fontWeight = if (actionAtStart) FontWeight.Normal else FontWeight.SemiBold)
        }
    }
}

@Composable
private fun ExportSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, color = SecondaryText, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 14.dp))
        Column(
            Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(25.dp)).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) { content() }
    }
}

@Composable
private fun DestinationButton(destination: ExportDestination, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.height(70.dp).clip(RoundedCornerShape(18.dp))
            .background(if (selected) Color.Black.copy(alpha = .78f) else Color.Transparent)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(destinationIcon(destination), null, Modifier.size(18.dp), tint = if (selected) Color.White else Color.Black.copy(alpha = .72f))
        Spacer(Modifier.height(7.dp))
        Text(destination.label, color = if (selected) Color.White else Color.Black.copy(alpha = .72f), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ExportPickerRow(icon: ImageVector, title: String, selected: String, options: List<String>, onSelected: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().height(40.dp).clickable { expanded = true },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, Modifier.size(18.dp).widthIn(min = 28.dp))
        Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Box {
            Text(selected, color = SystemBlue, fontSize = 14.sp, modifier = Modifier.padding(8.dp))
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option) },
                        trailingIcon = { if (option == selected) Icon(Icons.Default.Check, null, Modifier.size(17.dp), tint = SystemBlue) },
                        onClick = { onSelected(option); expanded = false },
                    )
                }
            }
        }
    }
}

@Composable
private fun MetadataPolicyRow(policy: MetadataPolicy, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(17.dp))
            .background(if (selected) Color.Black.copy(alpha = .075f) else Color.Transparent)
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(metadataIcon(policy), null, Modifier.size(18.dp).widthIn(min = 28.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(policy.label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Text(policy.detail, color = SecondaryText, fontSize = 10.sp, lineHeight = 13.sp)
        }
        Icon(if (selected) Icons.Outlined.CheckCircle else Icons.Outlined.Circle, null, Modifier.size(20.dp), tint = if (selected) SystemBlue else SecondaryText)
    }
}

private fun destinationIcon(destination: ExportDestination): ImageVector = when (destination) {
    ExportDestination.PhotoLibrary -> Icons.Outlined.PhotoLibrary
    ExportDestination.Files -> Icons.Outlined.Folder
    ExportDestination.Share -> Icons.Outlined.Share
}

private fun metadataIcon(policy: MetadataPolicy): ImageVector = when (policy) {
    MetadataPolicy.Preserve -> Icons.Outlined.Info
    MetadataPolicy.RemoveLocation -> Icons.Outlined.LocationOff
    MetadataPolicy.RemoveAll -> Icons.Outlined.PrivacyTip
}

private fun exportTitle(destination: ExportDestination): String = when (destination) {
    ExportDestination.PhotoLibrary -> "保存到系统相册"
    ExportDestination.Files -> "导出到文件"
    ExportDestination.Share -> "打开系统分享"
}
