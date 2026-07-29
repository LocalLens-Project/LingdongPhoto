package cn.locallens.lingdongzhaopian

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.ConfirmationNumber
import androidx.compose.material.icons.outlined.QrCode
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.ViewWeek
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Mode picking moved out of settings so a creation mode is one tap away from the editor, matching
 * the iOS mode grid. The scan card sits in the same grid because verifying a ticket needs no photo.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModeSelectionSheet(
    selectedMode: CreationMode,
    onSelect: (CreationMode) -> Unit,
    onScanTicket: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        containerColor = Color.Transparent,
        scrimColor = Color.Black.copy(alpha = .32f),
    ) {
        Column(
            Modifier
                .fillMaxHeight(.84f)
                .clip(RoundedCornerShape(topStart = 38.dp, topEnd = 38.dp))
                .background(Color(0xFFF2F2F7).copy(alpha = .94f)),
        ) {
            Column(
                Modifier.fillMaxWidth().padding(start = 22.dp, end = 22.dp, top = 22.dp, bottom = 14.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text("选择创作模式", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text(
                    "同一张照片可以随时切换模式，构图、色盘与文案都会保留。",
                    color = Color.Black.copy(alpha = .55f),
                    fontSize = 12.sp,
                    lineHeight = 17.sp,
                )
            }

            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 26.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(CreationMode.entries.size) { index ->
                    val mode = CreationMode.entries[index]
                    ModeCard(mode, selected = mode == selectedMode) { onSelect(mode) }
                }
                item { ScanTicketCard(onScanTicket) }
            }
        }
    }
}

@Composable
private fun ModeCard(mode: CreationMode, selected: Boolean, onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 132.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(if (selected) Color.Black.copy(alpha = .075f) else Color.White)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(42.dp).background(mode.accent.copy(alpha = .38f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(modeIcon(mode), null, Modifier.size(21.dp), tint = Color.Black.copy(alpha = .82f))
            }
            Spacer(Modifier.weight(1f))
            if (selected) Icon(Icons.Default.Check, null, Modifier.size(19.dp), tint = Color(0xFF007AFF))
        }
        Text(mode.title, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        Text(
            mode.subtitle,
            color = Color.Black.copy(alpha = .55f),
            fontSize = 11.sp,
            lineHeight = 14.sp,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun ScanTicketCard(onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 132.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(Color.White)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier.size(42.dp).background(Color(0xFFAADDFF).copy(alpha = .45f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Outlined.QrCodeScanner, null, Modifier.size(21.dp), tint = Color.Black.copy(alpha = .82f))
        }
        Text("扫描验证票根", fontSize = 16.sp, fontWeight = FontWeight.Bold)
        Text(
            "打开相机扫描二维码，在本机查看票根验证结果",
            color = Color.Black.copy(alpha = .55f),
            fontSize = 11.sp,
            lineHeight = 14.sp,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** Bottom strip of the ticket editor:版式 · 凭证类型 · 预览与公开信息. */
@Composable
fun TicketEditorControls(
    state: AppUiState,
    onLayout: (TicketLayoutStyle) -> Unit,
    onCodeStyle: (TicketCodeStyle) -> Unit,
    onOpenStudio: () -> Unit,
    modifier: Modifier = Modifier,
    isLandscape: Boolean = false,
) {
    var layoutMenuExpanded by remember { mutableStateOf(false) }
    Box(modifier.fillMaxWidth()) {
        if (isLandscape) {
            Column(
                Modifier.fillMaxWidth().padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TicketLayoutControl(
                    state = state,
                    expanded = layoutMenuExpanded,
                    onExpandedChange = { layoutMenuExpanded = it },
                    onLayout = onLayout,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    TicketCodeStyle.entries.forEach { style ->
                        TicketCodeControl(
                            style = style,
                            selected = style == state.preferences.ticketCodeStyle,
                            expanded = true,
                            onClick = { onCodeStyle(style) },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
                TicketPlainControl(
                    icon = Icons.Outlined.Visibility,
                    label = "预览与公开信息",
                    onClick = onOpenStudio,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        } else {
            Row(
                Modifier.fillMaxWidth().padding(8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                TicketLayoutControl(
                    state = state,
                    expanded = layoutMenuExpanded,
                    onExpandedChange = { layoutMenuExpanded = it },
                    onLayout = onLayout,
                    modifier = Modifier.weight(1f),
                )
                TicketCodeStyle.entries.forEach { style ->
                    TicketCodeControl(
                        style = style,
                        selected = style == state.preferences.ticketCodeStyle,
                        expanded = false,
                        onClick = { onCodeStyle(style) },
                        modifier = Modifier.width(43.dp),
                    )
                }
                TicketPlainControl(
                    icon = Icons.Outlined.Visibility,
                    label = "预览与公开信息",
                    onClick = onOpenStudio,
                    modifier = Modifier.weight(1.38f),
                )
            }
        }
    }
}

@Composable
private fun TicketLayoutControl(
    state: AppUiState,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onLayout: (TicketLayoutStyle) -> Unit,
    modifier: Modifier,
) {
    Box(modifier) {
        TicketPlainControl(
            icon = Icons.Outlined.ConfirmationNumber,
            label = state.preferences.ticketLayout.label,
            onClick = { onExpandedChange(true) },
            modifier = Modifier.fillMaxWidth(),
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { onExpandedChange(false) },
        ) {
            TicketLayoutStyle.entries.forEach { layout ->
                DropdownMenuItem(
                    text = {
                        Text(
                            layout.label,
                            fontWeight = if (layout == state.preferences.ticketLayout) {
                                FontWeight.Bold
                            } else FontWeight.Normal,
                        )
                    },
                    onClick = {
                        onLayout(layout)
                        onExpandedChange(false)
                    },
                )
            }
        }
    }
}

@Composable
private fun TicketCodeControl(
    style: TicketCodeStyle,
    selected: Boolean,
    expanded: Boolean,
    onClick: () -> Unit,
    modifier: Modifier,
) {
    val foreground = if (selected) Color(0xFF007AFF) else Color.Black.copy(alpha = .72f)
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier
            .height(43.dp)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = if (expanded) 10.dp else 0.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(
            if (style == TicketCodeStyle.Barcode) Icons.Outlined.ViewWeek else Icons.Outlined.QrCode,
            style.shortTitle,
            Modifier.size(18.dp),
            tint = foreground,
        )
        if (expanded) {
            Spacer(Modifier.width(7.dp))
            Text(
                style.shortTitle,
                color = foreground,
                fontSize = 12.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun TicketPlainControl(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier,
) {
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier
            .height(43.dp)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, null, Modifier.size(16.dp), tint = Color.Black.copy(alpha = .76f))
        Spacer(Modifier.width(6.dp))
        Text(
            label,
            color = Color.Black.copy(alpha = .76f),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
        )
    }
}
