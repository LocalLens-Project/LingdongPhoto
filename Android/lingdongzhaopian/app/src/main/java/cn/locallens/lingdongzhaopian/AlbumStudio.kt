package cn.locallens.lingdongzhaopian

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.LinearGradient as AndroidLinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.DriveFileMove
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.PictureAsPdf
import androidx.compose.material.icons.outlined.Print
import androidx.compose.material.icons.outlined.TextFields
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withContext

private enum class AlbumScreen { Library, Themes, Variants, Editor }
private enum class AlbumSourceKind { Photo, Work }
private enum class AlbumPdfKind(val title: String, val detail: String) {
    PrintReady("印刷 PDF", "逐页输出，包含 3 mm 出血，适合交付打印"),
    Digital("电子版 PDF", "逐页输出预览中的实际页面，不添加背景或左右拼版"),
}

private data class AlbumPlacement(val pageIndex: Int?, val slotIndex: Int?, val kind: AlbumSourceKind)
private data class AlbumFrame(val x: Float, val y: Float, val width: Float, val height: Float, val rotation: Float = 0f)

@Composable
fun AlbumStudioDialog(onClose: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember { AlbumProjectStore(context) }
    var screen by remember { mutableStateOf(AlbumScreen.Library) }
    var selectedTheme by remember { mutableStateOf(AlbumThemeSpec.Travel) }
    var selectedTemplateId by remember { mutableStateOf(AlbumTemplateCatalog.featured(selectedTheme).id) }
    var selectedFormat by remember { mutableStateOf(AlbumTemplateCatalog.featured(selectedTheme).defaultFormat) }
    var activeProjectId by remember { mutableStateOf<String?>(null) }
    var selectedPage by remember { mutableIntStateOf(0) }
    var sourceChooser by remember { mutableStateOf(false) }
    var placement by remember { mutableStateOf(AlbumPlacement(null, null, AlbumSourceKind.Photo)) }
    var loading by remember { mutableStateOf(false) }
    var previewShown by remember { mutableStateOf(false) }
    var textEditorShown by remember { mutableStateOf(false) }
    var addPageShown by remember { mutableStateOf(false) }
    var pageOptionsShown by remember { mutableStateOf(false) }
    var exportShown by remember { mutableStateOf(false) }
    var exportKind by remember { mutableStateOf(AlbumPdfKind.PrintReady) }
    var exporting by remember { mutableStateOf(false) }
    var deleteCandidate by remember { mutableStateOf<AlbumProjectData?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(30)) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        val projectId = activeProjectId ?: return@rememberLauncherForActivityResult
        scope.launch {
            loading = true
            val bitmaps = supervisorScope {
                uris.map { uri -> async { runCatching { PhotoProcessor.load(context, uri).bitmap }.getOrNull() } }.awaitAll().filterNotNull()
            }
            val paths = withContext(Dispatchers.IO) { store.importBitmaps(projectId, bitmaps, placement.kind.name.lowercase()) }
            store.placeAssets(projectId, paths, placement.pageIndex, placement.slotIndex)
            loading = false
            if (paths.isEmpty()) Toast.makeText(context, "无法读取所选内容", Toast.LENGTH_SHORT).show()
        }
    }

    val documentLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        val project = activeProjectId?.let(store::project)
        if (uri == null || project == null) {
            exporting = false
            return@rememberLauncherForActivityResult
        }
        scope.launch {
            val success = withContext(Dispatchers.IO) { AlbumPdfRenderer.write(context, uri, project, store, exportKind) }
            exporting = false
            exportShown = false
            Toast.makeText(context, if (success) "影像相簿 PDF 已导出" else "相簿导出失败", Toast.LENGTH_SHORT).show()
        }
    }

    fun launchPicker(kind: AlbumSourceKind, page: Int? = null, slot: Int? = null) {
        placement = AlbumPlacement(page, slot, kind)
        sourceChooser = false
        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
    }

    BackHandler(onBack = onClose)
    Surface(Modifier.fillMaxSize(), color = Color(0xFF0E1110)) {
        when (screen) {
            AlbumScreen.Library -> AlbumLibraryScreen(
                store = store,
                onClose = onClose,
                onCreate = { screen = AlbumScreen.Themes },
                onOpen = { project -> activeProjectId = project.id; selectedPage = 0; screen = AlbumScreen.Editor },
                onDelete = { deleteCandidate = it },
            )
            AlbumScreen.Themes -> AlbumThemeScreen(
                selected = selectedTheme,
                onSelect = { theme ->
                    selectedTheme = theme
                    val featured = AlbumTemplateCatalog.featured(theme)
                    selectedTemplateId = featured.id
                    selectedFormat = featured.defaultFormat
                },
                onBack = { screen = AlbumScreen.Library },
                onNext = { screen = AlbumScreen.Variants },
            )
            AlbumScreen.Variants -> AlbumVariantScreen(
                theme = selectedTheme,
                selectedTemplateId = selectedTemplateId,
                selectedFormat = selectedFormat,
                onTemplate = { template -> selectedTemplateId = template.id; selectedFormat = template.defaultFormat },
                onFormat = { selectedFormat = it },
                onBack = { screen = AlbumScreen.Themes },
                onCreate = {
                    val project = store.create(AlbumTemplateCatalog.find(selectedTemplateId), selectedFormat)
                    activeProjectId = project.id
                    selectedPage = 0
                    screen = AlbumScreen.Editor
                },
            )
            AlbumScreen.Editor -> {
                val project = activeProjectId?.let(store::project)
                if (project == null) screen = AlbumScreen.Library else AlbumEditorScreen(
                    project = project,
                    store = store,
                    selectedPage = selectedPage.coerceIn(0, project.pages.lastIndex.coerceAtLeast(0)),
                    loading = loading,
                    onSelectPage = { selectedPage = it },
                    onBack = { screen = AlbumScreen.Library },
                    onPreview = { previewShown = true },
                    onExport = { exportShown = true },
                    onBatchImport = { placement = AlbumPlacement(null, null, AlbumSourceKind.Photo); sourceChooser = true },
                    onSlot = { page, slot -> placement = AlbumPlacement(page, slot, AlbumSourceKind.Photo); sourceChooser = true },
                    onRemoveSlot = { page, slot -> store.removeAsset(project.id, page, slot) },
                    onText = { textEditorShown = true },
                    onAddPage = { addPageShown = true },
                    onPageOptions = { pageOptionsShown = true },
                )
            }
        }
    }

    val activeProject = activeProjectId?.let(store::project)
    if (sourceChooser) AlbumSourceDialog(
        onDismiss = { sourceChooser = false },
        onPhoto = { launchPicker(AlbumSourceKind.Photo, placement.pageIndex, placement.slotIndex) },
        onWork = { launchPicker(AlbumSourceKind.Work, placement.pageIndex, placement.slotIndex) },
    )
    if (previewShown && activeProject != null) AlbumPreviewDialog(activeProject, store, selectedPage) { previewShown = false }
    if (textEditorShown && activeProject != null) AlbumTextEditorDialog(activeProject, selectedPage, onDismiss = { textEditorShown = false }) { title, subtitle, caption ->
        val pages = activeProject.pages.toMutableList()
        if (pages.indices.contains(selectedPage)) pages[selectedPage] = pages[selectedPage].copy(caption = caption)
        store.update(activeProject.copy(title = title, subtitle = subtitle, pages = pages))
        textEditorShown = false
    }
    if (addPageShown && activeProject != null) AlbumAddPageDialog(onDismiss = { addPageShown = false }) { layout ->
        store.addPage(activeProject.id, layout, selectedPage)
        selectedPage = ((store.project(activeProject.id)?.pages?.size ?: 2) - 2).coerceAtLeast(1)
        addPageShown = false
    }
    if (pageOptionsShown && activeProject != null) AlbumPageOptionsDialog(
        project = activeProject,
        pageIndex = selectedPage,
        onDismiss = { pageOptionsShown = false },
        onMove = { delta -> store.movePage(activeProject.id, selectedPage, delta); selectedPage = (selectedPage + delta).coerceIn(0, activeProject.pages.lastIndex); pageOptionsShown = false },
        onDuplicate = { store.duplicatePage(activeProject.id, selectedPage); selectedPage += 1; pageOptionsShown = false },
        onDelete = { store.deletePage(activeProject.id, selectedPage); selectedPage = selectedPage.coerceAtMost(activeProject.pages.lastIndex - 1); pageOptionsShown = false },
    )
    if (exportShown && activeProject != null) AlbumExportDialog(
        project = activeProject,
        selected = exportKind,
        exporting = exporting,
        onSelect = { exportKind = it },
        onDismiss = { if (!exporting) exportShown = false },
        onExport = {
            exporting = true
            documentLauncher.launch("${activeProject.title.ifBlank { "影像相簿" }}.pdf")
        },
    )
    if (deleteCandidate != null) AlbumDeleteDialog(deleteCandidate!!, onDismiss = { deleteCandidate = null }) {
        store.delete(deleteCandidate!!.id)
        deleteCandidate = null
    }
}

@Composable
private fun AlbumBackdrop(colors: List<Color>, content: @Composable () -> Unit) {
    val resolved = colors.ifEmpty { listOf(Color(0xFF263E32), Color(0xFF172539), Color(0xFF0C1110)) }
    Box(Modifier.fillMaxSize().background(Brush.linearGradient(resolved + Color(0xFF0B100E)))) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .18f)))
        content()
    }
}

@Composable
private fun AlbumLibraryScreen(
    store: AlbumProjectStore,
    onClose: () -> Unit,
    onCreate: () -> Unit,
    onOpen: (AlbumProjectData) -> Unit,
    onDelete: (AlbumProjectData) -> Unit,
) {
    val template = store.projects.firstOrNull()?.let { AlbumTemplateCatalog.find(it.templateId) }
    val colors = store.projects.firstOrNull()?.resolvedPalette(template?.colors.orEmpty()) ?: template?.colors.orEmpty()
    AlbumBackdrop(colors) {
        Column(Modifier.fillMaxSize()) {
            AlbumTopBar("影像相簿", "在本地装订、翻阅与打印", Icons.Default.Close, onClose, Icons.Default.Add, onCreate)
            if (store.projects.isEmpty()) {
                Column(Modifier.fillMaxSize().padding(horizontal = 34.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    Box(Modifier.width(130.dp).aspectRatio(.76f).rotate(4f).background(Color.White, RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.AutoStories, null, Modifier.size(42.dp), tint = Color.Black.copy(alpha = .55f))
                    }
                    Spacer(Modifier.height(28.dp))
                    Text("把散落的影像装订成书", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text("选择模板，加入普通照片或灵动作品\n整本预览后可直接生成印刷 PDF", color = Color.White.copy(alpha = .62f), textAlign = TextAlign.Center, lineHeight = 22.sp, modifier = Modifier.padding(vertical = 12.dp))
                    Button(onClick = onCreate, colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = .16f), contentColor = Color.White), modifier = Modifier.height(54.dp)) {
                        Icon(Icons.Default.Add, null)
                        Spacer(Modifier.width(8.dp))
                        Text("创建第一本相簿", fontWeight = FontWeight.Bold)
                    }
                }
            } else {
                LazyVerticalGrid(GridCells.Fixed(2), contentPadding = PaddingValues(18.dp), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    items(store.projects, key = { it.id }) { project ->
                        Column {
                            Surface(
                                Modifier.fillMaxWidth().aspectRatio(.76f).clickable { onOpen(project) },
                                color = Color.White.copy(alpha = .10f),
                                shape = RoundedCornerShape(22.dp),
                                border = androidx.compose.foundation.BorderStroke(1.dp, Color.White.copy(alpha = .30f)),
                            ) {
                                AlbumPageCanvas(project, project.pages.first(), store, false, {})
                            }
                            Row(Modifier.fillMaxWidth().padding(top = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(project.title, color = Color.White, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    Text("${project.pages.size} 页 · ${project.filledCount} 个内容", color = Color.White.copy(alpha = .55f), fontSize = 11.sp)
                                }
                                IconButton(onClick = { onDelete(project) }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Delete, "删除相簿", tint = Color.White.copy(alpha = .75f), modifier = Modifier.size(17.dp)) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AlbumThemeScreen(selected: AlbumThemeSpec, onSelect: (AlbumThemeSpec) -> Unit, onBack: () -> Unit, onNext: () -> Unit) {
    val featured = AlbumTemplateCatalog.featured(selected)
    AlbumBackdrop(featured.colors) {
        Column(Modifier.fillMaxSize()) {
            AlbumTopBar("选择相簿主题", "每个主题均提供 3 套原创版式", Icons.Default.Close, onBack)
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(start = 18.dp, end = 18.dp, bottom = 10.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                items(AlbumThemeSpec.entries) { theme ->
                    val item = AlbumTemplateCatalog.featured(theme)
                    val active = theme == selected
                    Surface(
                        Modifier.fillMaxWidth().clickable { onSelect(theme) },
                        shape = RoundedCornerShape(26.dp),
                        color = Color.White.copy(alpha = if (active) .16f else .08f),
                        border = androidx.compose.foundation.BorderStroke(if (active) 2.dp else 1.dp, Color.White.copy(alpha = if (active) .72f else .25f)),
                    ) {
                        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            TemplateStack(AlbumTemplateCatalog.templates(theme))
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text("${theme.symbol}  ${theme.title}", color = Color.White.copy(alpha = .62f), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                Text(item.title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                                Text("3 套版式 · ${item.subtitle}", color = Color.White.copy(alpha = .68f), fontSize = 12.sp)
                                Text(item.detail, color = Color.White.copy(alpha = .48f), fontSize = 11.sp, maxLines = 2)
                            }
                            Text(if (active) "✓" else "›", color = Color.White.copy(alpha = if (active) 1f else .42f), fontSize = 27.sp)
                        }
                    }
                }
            }
            Box(
                Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = 14.dp, vertical = 10.dp)
                    .background(Color(0xE6292E2B), RoundedCornerShape(30.dp))
                    .padding(14.dp),
            ) {
                Button(onClick = onNext, modifier = Modifier.fillMaxWidth().height(58.dp), colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = .20f), contentColor = Color.White)) {
                    Icon(Icons.Outlined.GridView, null)
                    Spacer(Modifier.width(10.dp))
                    Text("进入“${featured.title}”模板选择", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun AlbumVariantScreen(
    theme: AlbumThemeSpec,
    selectedTemplateId: String,
    selectedFormat: AlbumBookFormat,
    onTemplate: (AlbumTemplateSpec) -> Unit,
    onFormat: (AlbumBookFormat) -> Unit,
    onBack: () -> Unit,
    onCreate: () -> Unit,
) {
    val selected = AlbumTemplateCatalog.find(selectedTemplateId)
    AlbumBackdrop(selected.colors) {
        Column(Modifier.fillMaxSize()) {
            AlbumTopBar("${theme.title}模板", "挑选最适合这本相簿的视觉版式", Icons.AutoMirrored.Filled.ArrowBack, onBack)
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(start = 18.dp, end = 18.dp, bottom = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                items(AlbumTemplateCatalog.templates(theme)) { template ->
                    val active = template.id == selectedTemplateId
                    Surface(
                        Modifier.fillMaxWidth().clickable { onTemplate(template) },
                        shape = RoundedCornerShape(22.dp),
                        color = Color.White.copy(alpha = if (active) .17f else .08f),
                        border = androidx.compose.foundation.BorderStroke(if (active) 2.dp else 1.dp, Color.White.copy(alpha = if (active) .75f else .25f)),
                    ) {
                        Column(Modifier.padding(10.dp)) {
                            TemplateMiniature(template, Modifier.fillMaxWidth().aspectRatio(.78f))
                            Row(Modifier.fillMaxWidth().padding(top = 9.dp), verticalAlignment = Alignment.Top) {
                                Column(Modifier.weight(1f)) {
                                    Text(template.title, color = Color.White, fontWeight = FontWeight.Bold)
                                    Text(template.subtitle, color = Color.White.copy(alpha = .58f), fontSize = 11.sp)
                                }
                                Text(if (active) "✓" else "○", color = Color.White.copy(alpha = if (active) 1f else .45f), fontSize = 20.sp)
                            }
                        }
                    }
                }
            }
            Column(Modifier.fillMaxWidth().background(Color(0xE62A2E2C), RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp)).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AlbumBookFormat.entries.forEach { format ->
                        val active = format == selectedFormat
                        Box(Modifier.weight(1f).height(42.dp).background(if (active) Color.White.copy(alpha = .20f) else Color.Transparent, RoundedCornerShape(22.dp)).border(1.dp, Color.White.copy(alpha = if (active) .70f else .24f), RoundedCornerShape(22.dp)).clickable { onFormat(format) }, contentAlignment = Alignment.Center) {
                            Text(format.shortLabel, color = Color.White, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
                Button(onClick = onCreate, modifier = Modifier.fillMaxWidth().height(56.dp), colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = .20f), contentColor = Color.White)) {
                    Icon(Icons.Outlined.Book, null)
                    Spacer(Modifier.width(8.dp))
                    Text("使用“${selected.title}”创建", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun AlbumEditorScreen(
    project: AlbumProjectData,
    store: AlbumProjectStore,
    selectedPage: Int,
    loading: Boolean,
    onSelectPage: (Int) -> Unit,
    onBack: () -> Unit,
    onPreview: () -> Unit,
    onExport: () -> Unit,
    onBatchImport: () -> Unit,
    onSlot: (Int, Int) -> Unit,
    onRemoveSlot: (Int, Int) -> Unit,
    onText: () -> Unit,
    onAddPage: () -> Unit,
    onPageOptions: () -> Unit,
) {
    val template = AlbumTemplateCatalog.find(project.templateId)
    val page = project.pages[selectedPage]
    AlbumBackdrop(project.resolvedPalette(template.colors)) {
        Column(Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回相簿列表", tint = Color.White) }
                Column(Modifier.weight(1f)) {
                    Text(project.title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${project.format.label} · 自动保存", color = Color.White.copy(alpha = .55f), fontSize = 11.sp)
                }
                IconButton(onClick = onPreview) { Icon(Icons.Outlined.AutoStories, "整本横屏预览", tint = Color.White) }
                IconButton(onClick = onExport) { Icon(Icons.Outlined.Print, "导出或打印相簿", tint = Color.White) }
            }
            BoxWithConstraints(Modifier.fillMaxWidth().weight(1f).padding(horizontal = 18.dp, vertical = 8.dp), contentAlignment = Alignment.Center) {
                val width = minOf(maxWidth, maxHeight * project.format.ratio)
                Box(Modifier.width(width).aspectRatio(project.format.ratio).shadow(22.dp, RoundedCornerShape(8.dp))) {
                    AlbumPageCanvas(project, page, store, true) { slot ->
                        if (page.assets.getOrNull(slot) == null) onSlot(selectedPage, slot) else onRemoveSlot(selectedPage, slot)
                    }
                    Text(if (selectedPage == 0) "封面" else "第 ${selectedPage + 1} 页", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(10.dp).background(Color.White.copy(alpha = .16f), RoundedCornerShape(20.dp)).padding(horizontal = 10.dp, vertical = 6.dp))
                }
            }
            Text(page.layout.title, color = Color.White.copy(alpha = .62f), fontSize = 12.sp, modifier = Modifier.align(Alignment.CenterHorizontally).padding(bottom = 8.dp))
            LazyRow(contentPadding = PaddingValues(horizontal = 18.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.height(84.dp)) {
                items(project.pages.indices.toList()) { index ->
                    val selected = index == selectedPage
                    Surface(
                        Modifier.width(54.dp).aspectRatio(project.format.ratio).clickable { onSelectPage(index) },
                        color = Color.White.copy(alpha = .12f),
                        shape = RoundedCornerShape(7.dp),
                        border = androidx.compose.foundation.BorderStroke(if (selected) 2.dp else 1.dp, if (selected) Color.White else Color.White.copy(alpha = .25f)),
                    ) { AlbumPageCanvas(project, project.pages[index], store, false, {}) }
                }
            }
            Row(Modifier.fillMaxWidth().padding(14.dp).background(Color.White.copy(alpha = .10f), RoundedCornerShape(26.dp)).padding(vertical = 8.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                AlbumEditorAction(Icons.Outlined.AddPhotoAlternate, if (loading) "导入中" else "批量导入", Modifier.testTag("album-add-photos"), enabled = !loading, onClick = onBatchImport)
                AlbumEditorAction(Icons.Outlined.TextFields, "文字", onClick = onText)
                AlbumEditorAction(Icons.Outlined.ContentCopy, "加页", onClick = onAddPage)
                AlbumEditorAction(Icons.Default.MoreHoriz, "页面", onClick = onPageOptions)
            }
        }
    }
}

@Composable
private fun AlbumEditorAction(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    Column(modifier.clip(RoundedCornerShape(15.dp)).clickable(enabled = enabled, onClick = onClick).padding(horizontal = 10.dp, vertical = 6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, tint = Color.White, modifier = Modifier.size(25.dp))
        Text(label, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}

private fun AlbumProjectData.resolvedPalette(fallback: List<Color>): List<Color> =
    palette.map(::Color).ifEmpty { fallback }

private fun AlbumProjectData.pageColors(page: AlbumPageData): List<Color> {
    val paths = page.assets.filterNotNull().toSet()
    return assets.filter { it.path in paths }.flatMap { it.colors.take(2) }.take(4).map(::Color)
}

private fun AlbumProjectData.backgroundColors(page: AlbumPageData, fallback: List<Color>): List<Color> {
    val paper = albumPaperColor(templateId)
    val projectColors = resolvedPalette(fallback)
    if (page.layout == AlbumPageLayout.CoverWindow || page.layout == AlbumPageLayout.BackCover) return projectColors
    val local = pageColors(page)
    if (local.isNotEmpty()) {
        val strength = if (page.layout == AlbumPageLayout.WorkFeature) .30f else .19f
        return local.take(3).mapIndexed { index, color -> lerp(paper, color, strength * (1f - index * .18f)) } + paper
    }
    return listOf(lerp(paper, projectColors.firstOrNull() ?: paper, .10f), paper)
}

private fun albumPaperColor(templateId: String): Color = when {
    templateId == "travel-postcard" -> Color(0xFFF6FAFA)
    templateId == "travel-film" -> Color(0xFFF4F1E9)
    templateId.startsWith("family-") -> Color(0xFFFBF4E8)
    templateId.startsWith("childhood-") -> Color(0xFFFBFAF2)
    templateId.startsWith("pet-") -> Color(0xFFF7F6ED)
    templateId == "blank-grid" -> Color(0xFFF3F5F3)
    else -> Color(0xFFFBFAF5)
}

@Composable
private fun AlbumPageCanvas(project: AlbumProjectData, page: AlbumPageData, store: AlbumProjectStore, editing: Boolean, onSlot: (Int) -> Unit) {
    val template = AlbumTemplateCatalog.find(project.templateId)
    val backgroundColors = project.backgroundColors(page, template.colors)
    BoxWithConstraints(Modifier.fillMaxSize().background(Brush.linearGradient(backgroundColors))) {
        val compact = maxWidth < 90.dp
        val frames = albumFrames(page.layout)
        frames.forEachIndexed { index, frame ->
            val path = page.assets.getOrNull(index)
            val bitmap = remember(path) { store.bitmap(path) }
            Box(
                Modifier.offset(maxWidth * frame.x, maxHeight * frame.y).width(maxWidth * frame.width).height(maxHeight * frame.height).rotate(frame.rotation).clip(RoundedCornerShape(if (page.layout == AlbumPageLayout.FullBleed) 0.dp else 5.dp)).background(Color.Black.copy(alpha = .20f)).then(if (editing) Modifier.clickable { onSlot(index) } else Modifier),
                contentAlignment = Alignment.Center,
            ) {
                if (bitmap != null) Image(bitmap.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = if (page.layout == AlbumPageLayout.WorkFeature) ContentScale.Fit else ContentScale.Crop)
                else if (editing && !compact) Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(if (page.layout == AlbumPageLayout.WorkFeature) Icons.Outlined.Image else Icons.Outlined.AddPhotoAlternate, null, tint = Color.White.copy(alpha = .72f), modifier = Modifier.size(20.dp))
                    Text(if (page.layout == AlbumPageLayout.WorkFeature) "添加灵动作品" else "添加照片", color = Color.White.copy(alpha = .82f), fontSize = 8.sp)
                }
            }
        }
        if (!compact) {
            when {
                page.layout == AlbumPageLayout.CoverWindow -> {
                    Text(project.title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Serif, modifier = Modifier.align(Alignment.TopCenter).padding(top = maxHeight * .09f))
                    Text(project.subtitle, color = Color.White.copy(alpha = .76f), fontSize = 9.sp, textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = maxHeight * .09f))
                }
                page.layout == AlbumPageLayout.BackCover -> Text(project.title, color = Color.White.copy(alpha = .90f), fontSize = 15.sp, fontFamily = FontFamily.Serif, modifier = Modifier.align(Alignment.Center))
                else -> {
                    Text(if (page.layout == AlbumPageLayout.WorkFeature) "灵动作品" else page.layout.title, color = Color.White.copy(alpha = .94f), fontSize = 13.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.TopStart).padding(14.dp))
                    Text(page.caption, color = Color.White.copy(alpha = .72f), fontSize = 7.sp, modifier = Modifier.align(Alignment.BottomStart).padding(14.dp).fillMaxWidth(.72f))
                }
            }
        }
    }
}

private fun albumFrames(layout: AlbumPageLayout): List<AlbumFrame> = when (layout) {
    AlbumPageLayout.CoverWindow -> listOf(AlbumFrame(.28f, .27f, .44f, .34f))
    AlbumPageLayout.HeroBottom -> listOf(AlbumFrame(.07f, .38f, .86f, .50f))
    AlbumPageLayout.SplitPair, AlbumPageLayout.OceanPoster -> listOf(AlbumFrame(.04f, .12f, .44f, .72f), AlbumFrame(.52f, .16f, .44f, .72f))
    AlbumPageLayout.EditorialThree, AlbumPageLayout.CinematicSea -> listOf(AlbumFrame(.06f, .17f, .55f, .45f), AlbumFrame(.65f, .17f, .29f, .22f), AlbumFrame(.65f, .43f, .29f, .22f))
    AlbumPageLayout.GridSix, AlbumPageLayout.ColorAtlas -> List(6) { index -> AlbumFrame(.07f + (index % 2) * .46f, .16f + (index / 2) * .24f, .40f, .20f) }
    AlbumPageLayout.PortraitStory -> listOf(AlbumFrame(.07f, .14f, .49f, .67f), AlbumFrame(.62f, .18f, .30f, .22f), AlbumFrame(.62f, .46f, .30f, .22f))
    AlbumPageLayout.WorkFeature -> listOf(AlbumFrame(.08f, .26f, .84f, .46f))
    AlbumPageLayout.FullBleed -> listOf(AlbumFrame(0f, 0f, 1f, 1f))
    AlbumPageLayout.Collage, AlbumPageLayout.PostcardScrapbook, AlbumPageLayout.TornPaperJourney, AlbumPageLayout.ClippedMemoir -> listOf(AlbumFrame(.08f, .17f, .55f, .38f, -3f), AlbumFrame(.48f, .43f, .43f, .31f, 3f), AlbumFrame(.13f, .65f, .34f, .22f, -1f))
    AlbumPageLayout.QuotePhoto -> listOf(AlbumFrame(.08f, .12f, .84f, .53f))
    AlbumPageLayout.VerticalTravelogue -> listOf(AlbumFrame(.10f, .17f, .36f, .62f), AlbumFrame(.54f, .22f, .36f, .62f))
    AlbumPageLayout.GalleryWindow -> listOf(AlbumFrame(.07f, .17f, .40f, .30f), AlbumFrame(.53f, .17f, .40f, .30f), AlbumFrame(.07f, .52f, .40f, .30f), AlbumFrame(.53f, .52f, .40f, .30f))
    AlbumPageLayout.Freeform -> listOf(AlbumFrame(.16f, .24f, .68f, .52f))
    AlbumPageLayout.BackCover -> emptyList()
}

@Composable
private fun AlbumPreviewDialog(project: AlbumProjectData, store: AlbumProjectStore, initialPage: Int, onClose: () -> Unit) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    val virtualPageCount = project.pages.size + 1 + if ((project.pages.size + 1).isEven()) 0 else 1
    val spreadCount = virtualPageCount / 2
    var spread by remember { mutableIntStateOf(((initialPage + 1) / 2).coerceIn(0, spreadCount - 1)) }
    BackHandler(onBack = onClose)
    DisposableEffect(activity) {
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        onDispose { activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT }
    }
    AlbumBackdrop(project.resolvedPalette(AlbumTemplateCatalog.find(project.templateId).colors)) {
        Column(Modifier.fillMaxSize().padding(18.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onClose, modifier = Modifier.background(Color.White.copy(alpha = .15f), CircleShape)) { Icon(Icons.Default.Close, "关闭预览", tint = Color.White) }
                Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                    Text(project.title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text("整本预览 · ${project.pages.size} 页", color = Color.White.copy(alpha = .55f), fontSize = 12.sp)
                }
                Text("${spread + 1} / $spreadCount", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.background(Color.White.copy(alpha = .14f), RoundedCornerShape(22.dp)).padding(horizontal = 14.dp, vertical = 10.dp))
            }
            Row(Modifier.fillMaxWidth().weight(1f).padding(vertical = 14.dp), horizontalArrangement = Arrangement.spacedBy(0.dp), verticalAlignment = Alignment.CenterVertically) {
                repeat(2) { side ->
                    val projectIndex = spread * 2 + side - 1
                    Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = if (side == 0) Alignment.CenterEnd else Alignment.CenterStart) {
                        if (project.pages.indices.contains(projectIndex)) {
                            Box(Modifier.fillMaxHeight(.90f).aspectRatio(project.format.ratio).shadow(24.dp)) {
                                AlbumPageCanvas(project, project.pages[projectIndex], store, false, {})
                            }
                        }
                    }
                }
            }
            Row(Modifier.align(Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                OutlinedButton(onClick = { spread-- }, enabled = spread > 0, colors = albumOutlinedButtonColors(), border = albumOutlinedButtonBorder(spread > 0)) { Text("上一跨页") }
                OutlinedButton(onClick = { spread++ }, enabled = spread < spreadCount - 1, colors = albumOutlinedButtonColors(), border = albumOutlinedButtonBorder(spread < spreadCount - 1)) { Text("下一跨页") }
            }
        }
    }
}

private fun Int.isEven() = this % 2 == 0

private fun Context.findActivity(): Activity? {
    var current = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return current as? Activity
}

@Composable
private fun AlbumSourceDialog(onDismiss: () -> Unit, onPhoto: () -> Unit, onWork: () -> Unit) {
    AlbumSheetDialog("选择内容来源", "照片与灵动作品都只在本机处理", onDismiss) {
        AlbumSheetButton(Icons.Outlined.AddPhotoAlternate, "系统照片", "从系统相册选择普通照片", onPhoto)
        AlbumSheetButton(Icons.Outlined.Image, "灵动作品", "选择已导出的卡片、票根、色盘或手帐", onWork)
    }
}

@Composable
private fun AlbumTextEditorDialog(project: AlbumProjectData, pageIndex: Int, onDismiss: () -> Unit, onSave: (String, String, String) -> Unit) {
    var title by remember { mutableStateOf(project.title) }
    var subtitle by remember { mutableStateOf(project.subtitle) }
    var caption by remember { mutableStateOf(project.pages[pageIndex].caption) }
    AlbumSheetDialog(if (pageIndex == 0) "编辑封面文字" else "编辑本页文字", if (pageIndex == 0) "相簿名称只在封面修改" else "修改仅作用于当前页面", onDismiss) {
        if (pageIndex == 0) {
            OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text("相簿名称") }, singleLine = true, colors = albumTextFieldColors())
            OutlinedTextField(subtitle, { subtitle = it }, Modifier.fillMaxWidth(), label = { Text("副标题") }, singleLine = true, colors = albumTextFieldColors())
        }
        OutlinedTextField(caption, { caption = it }, Modifier.fillMaxWidth(), label = { Text("本页文字") }, minLines = 2, colors = albumTextFieldColors())
        Button(onClick = { onSave(title, subtitle, caption) }, modifier = Modifier.fillMaxWidth().height(52.dp), colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = .18f), contentColor = Color.White)) { Text("保存文字", fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun AlbumAddPageDialog(onDismiss: () -> Unit, onSelect: (AlbumPageLayout) -> Unit) {
    AlbumSheetDialog("添加页面", "选择新页面的视觉版式", onDismiss) {
        LazyVerticalGrid(GridCells.Fixed(2), modifier = Modifier.fillMaxWidth().height(360.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(AlbumTemplateCatalog.addableLayouts) { layout ->
                OutlinedButton(onClick = { onSelect(layout) }, modifier = Modifier.height(58.dp), colors = albumOutlinedButtonColors(), border = albumOutlinedButtonBorder(true)) { Text(layout.title) }
            }
        }
    }
}

@Composable
private fun AlbumPageOptionsDialog(project: AlbumProjectData, pageIndex: Int, onDismiss: () -> Unit, onMove: (Int) -> Unit, onDuplicate: () -> Unit, onDelete: () -> Unit) {
    val isContent = pageIndex > 0 && pageIndex < project.pages.lastIndex
    AlbumSheetDialog("页面操作", "${project.pages[pageIndex].layout.title} · 第 ${pageIndex + 1} 页", onDismiss) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(onClick = { onMove(-1) }, enabled = isContent && pageIndex > 1, modifier = Modifier.weight(1f), colors = albumOutlinedButtonColors(), border = albumOutlinedButtonBorder(isContent && pageIndex > 1)) { Text("向前移动") }
            OutlinedButton(onClick = { onMove(1) }, enabled = isContent && pageIndex < project.pages.lastIndex - 1, modifier = Modifier.weight(1f), colors = albumOutlinedButtonColors(), border = albumOutlinedButtonBorder(isContent && pageIndex < project.pages.lastIndex - 1)) { Text("向后移动") }
        }
        AlbumSheetButton(Icons.Outlined.ContentCopy, "复制本页", "保留版式、文字与已放入的内容", onDuplicate, enabled = isContent)
        AlbumSheetButton(Icons.Default.Delete, "删除本页", "封面和封底始终保留，相簿至少保留一张内容页", onDelete, enabled = isContent && project.pages.size > 3)
    }
}

@Composable
private fun AlbumExportDialog(project: AlbumProjectData, selected: AlbumPdfKind, exporting: Boolean, onSelect: (AlbumPdfKind) -> Unit, onDismiss: () -> Unit, onExport: () -> Unit) {
    val lowResolutionCount = project.lowResolutionCount()
    AlbumSheetDialog("导出整本相簿", "${project.format.label} · ${project.pages.size} 页", onDismiss) {
        AlbumPdfKind.entries.forEach { kind ->
            Surface(
                Modifier.fillMaxWidth().clickable { onSelect(kind) },
                color = Color.White.copy(alpha = if (selected == kind) .18f else .08f),
                shape = RoundedCornerShape(22.dp),
            ) {
                Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(if (kind == AlbumPdfKind.PrintReady) Icons.Outlined.Print else Icons.Outlined.Description, null, tint = Color.White)
                    Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
                        Text(kind.title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        Text(kind.detail, color = Color.White.copy(alpha = .60f), fontSize = 11.sp)
                    }
                    Text(if (selected == kind) "✓" else "○", color = Color.White.copy(alpha = if (selected == kind) 1f else .45f), fontSize = 22.sp)
                }
            }
        }
        if (project.emptyCount > 0) Text("仍有 ${project.emptyCount} 个空位；导出时会保持留白，不会显示加号。", color = Color(0xFFFF9E42), fontSize = 12.sp)
        if (lowResolutionCount > 0) Text("有 ${lowResolutionCount} 张图片用于大幅打印时可能不够清晰。", color = Color(0xFFFF9E42), fontSize = 12.sp)
        Button(onClick = onExport, enabled = !exporting, modifier = Modifier.fillMaxWidth().height(58.dp).testTag("album-export-pdf"), colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = .18f), contentColor = Color.White, disabledContainerColor = Color.White.copy(alpha = .08f), disabledContentColor = Color.White.copy(alpha = .38f))) {
            if (exporting) CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp) else Icon(Icons.Outlined.PictureAsPdf, null)
            Spacer(Modifier.width(10.dp))
            Text(if (exporting) "正在装订…" else "生成${selected.title}", fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun albumTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    disabledTextColor = Color.White.copy(alpha = .35f),
    cursorColor = Color.White,
    focusedLabelColor = Color.White,
    unfocusedLabelColor = Color.White.copy(alpha = .58f),
    disabledLabelColor = Color.White.copy(alpha = .32f),
    focusedBorderColor = Color.White.copy(alpha = .82f),
    unfocusedBorderColor = Color.White.copy(alpha = .42f),
    disabledBorderColor = Color.White.copy(alpha = .20f),
)

@Composable
private fun albumOutlinedButtonColors() = ButtonDefaults.outlinedButtonColors(
    contentColor = Color.White,
    disabledContentColor = Color.White.copy(alpha = .28f),
)

@Composable
private fun albumOutlinedButtonBorder(enabled: Boolean) = BorderStroke(1.dp, Color.White.copy(alpha = if (enabled) .58f else .20f))

private fun AlbumProjectData.lowResolutionCount(): Int {
    val printPixelWidth = when (format) {
        AlbumBookFormat.Portrait -> 148f / 25.4f * 300f
        AlbumBookFormat.Square -> 210f / 25.4f * 300f
        AlbumBookFormat.Landscape -> 297f / 25.4f * 300f
    }
    val assetByPath = assets.associateBy { it.path }
    val lowResolutionPaths = mutableSetOf<String>()
    pages.forEach { page ->
        albumFrames(page.layout).forEachIndexed { index, frame ->
            val path = page.assets.getOrNull(index) ?: return@forEachIndexed
            val asset = assetByPath[path] ?: return@forEachIndexed
            if (asset.pixelWidth < printPixelWidth * frame.width * .72f) lowResolutionPaths += path
        }
    }
    return lowResolutionPaths.size
}

@Composable
private fun AlbumDeleteDialog(project: AlbumProjectData, onDismiss: () -> Unit, onDelete: () -> Unit) {
    AlbumSheetDialog("删除《${project.title}》？", "相簿项目及其中保存的本地图片会被删除，此操作无法撤销。", onDismiss) {
        Button(onClick = onDelete, modifier = Modifier.fillMaxWidth().height(52.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFB3261E))) { Text("删除相簿", fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun AlbumSheetDialog(title: String, subtitle: String, onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .45f)).clickable(onClick = onDismiss), contentAlignment = Alignment.BottomCenter) {
            Surface(Modifier.fillMaxWidth().clickable(enabled = false) {}, color = Color(0xFF252A28), shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp)) {
                Column(Modifier.padding(20.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(13.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(title, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                            Text(subtitle, color = Color.White.copy(alpha = .55f), fontSize = 12.sp)
                        }
                        IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, "关闭", tint = Color.White) }
                    }
                    content()
                    Spacer(Modifier.height(8.dp))
                }
            }
        }
    }
}

@Composable
private fun AlbumSheetButton(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, detail: String, onClick: () -> Unit, enabled: Boolean = true) {
    Surface(Modifier.fillMaxWidth().clickable(enabled = enabled, onClick = onClick), color = Color.White.copy(alpha = if (enabled) .09f else .04f), shape = RoundedCornerShape(20.dp)) {
        Row(Modifier.padding(17.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = Color.White.copy(alpha = if (enabled) 1f else .35f), modifier = Modifier.size(27.dp))
            Column(Modifier.padding(start = 14.dp)) {
                Text(title, color = Color.White.copy(alpha = if (enabled) 1f else .35f), fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Text(detail, color = Color.White.copy(alpha = if (enabled) .55f else .25f), fontSize = 11.sp)
            }
        }
    }
}

@Composable
private fun AlbumTopBar(title: String, subtitle: String, leading: androidx.compose.ui.graphics.vector.ImageVector, onLeading: () -> Unit, trailing: androidx.compose.ui.graphics.vector.ImageVector? = null, onTrailing: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onLeading, modifier = Modifier.background(Color.White.copy(alpha = .12f), CircleShape)) { Icon(leading, null, tint = Color.White) }
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(title, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(subtitle, color = Color.White.copy(alpha = .55f), fontSize = 12.sp)
        }
        if (trailing != null && onTrailing != null) IconButton(onClick = onTrailing, modifier = Modifier.background(Color.White.copy(alpha = .12f), CircleShape)) { Icon(trailing, null, tint = Color.White) }
    }
}

@Composable
private fun TemplateStack(templates: List<AlbumTemplateSpec>) {
    Box(Modifier.width(120.dp).height(122.dp), contentAlignment = Alignment.Center) {
        templates.take(3).forEachIndexed { index, template -> TemplateMiniature(template, Modifier.width(76.dp).height(104.dp).offset(x = ((index - 1) * 17).dp).rotate((index - 1) * 5f)) }
    }
}

@Composable
private fun TemplateMiniature(template: AlbumTemplateSpec, modifier: Modifier = Modifier) {
    Box(modifier.clip(RoundedCornerShape(12.dp)).background(Brush.linearGradient(template.colors)).border(1.dp, Color.White.copy(alpha = .42f), RoundedCornerShape(12.dp))) {
        Text(template.title, color = Color.White.copy(alpha = .92f), fontSize = 10.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.TopCenter).padding(top = 16.dp))
        when (template.theme) {
            AlbumThemeSpec.Travel -> Box(Modifier.align(Alignment.Center).fillMaxWidth(.62f).fillMaxHeight(.42f).background(Color.White.copy(alpha = .88f)).border(3.dp, Color.Black.copy(alpha = .65f)))
            AlbumThemeSpec.Family -> Box(Modifier.align(Alignment.Center).fillMaxWidth(.58f).fillMaxHeight(.46f).background(Color.White.copy(alpha = .88f), RoundedCornerShape(50)))
            AlbumThemeSpec.Childhood -> Box(Modifier.align(Alignment.Center).size(42.dp).background(Color.White.copy(alpha = .85f), RoundedCornerShape(10.dp)))
            AlbumThemeSpec.Companion -> Box(Modifier.align(Alignment.Center).fillMaxWidth(.62f).fillMaxHeight(.42f).background(Color.White.copy(alpha = .88f)))
            AlbumThemeSpec.Blank -> Box(Modifier.align(Alignment.Center).fillMaxWidth(.56f).fillMaxHeight(.36f).rotate(-5f).background(Color.White.copy(alpha = .88f)))
        }
    }
}

private object AlbumPdfRenderer {
    fun write(context: Context, uri: Uri, project: AlbumProjectData, store: AlbumProjectStore, kind: AlbumPdfKind): Boolean = runCatching {
        val document = PdfDocument()
        try {
            project.pages.forEachIndexed { index, page -> drawPage(document, project, page, index, store, kind) }
            context.contentResolver.openOutputStream(uri, "w")?.use(document::writeTo) ?: error("无法创建文件")
        } finally {
            document.close()
        }
    }.isSuccess

    private fun drawPage(document: PdfDocument, project: AlbumProjectData, page: AlbumPageData, index: Int, store: AlbumProjectStore, kind: AlbumPdfKind) {
        val bleed = if (kind == AlbumPdfKind.PrintReady) 36 else 0
        val width = project.format.pageWidth + bleed * 2
        val height = project.format.pageHeight + bleed * 2
        val pdfPage = document.startPage(PdfDocument.PageInfo.Builder(width, height, index + 1).create())
        val canvas = pdfPage.canvas
        canvas.translate(bleed.toFloat(), bleed.toFloat())
        val template = AlbumTemplateCatalog.find(project.templateId)
        val backgroundColors = project.backgroundColors(page, template.colors).map(Color::toArgb).toIntArray()
        val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = AndroidLinearGradient(
                0f,
                0f,
                project.format.pageWidth.toFloat(),
                project.format.pageHeight.toFloat(),
                backgroundColors,
                null,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, project.format.pageWidth.toFloat(), project.format.pageHeight.toFloat(), backgroundPaint)
        val frames = albumFrames(page.layout)
        frames.forEachIndexed { slot, frame ->
            val bitmap = store.bitmap(page.assets.getOrNull(slot)) ?: return@forEachIndexed
            val destination = Rect(
                (project.format.pageWidth * frame.x).toInt(),
                (project.format.pageHeight * frame.y).toInt(),
                (project.format.pageWidth * (frame.x + frame.width)).toInt(),
                (project.format.pageHeight * (frame.y + frame.height)).toInt(),
            )
            drawCenterCrop(canvas, bitmap, destination)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD) }
        if (page.layout == AlbumPageLayout.CoverWindow) {
            paint.textAlign = Paint.Align.CENTER
            paint.textSize = project.format.pageWidth * .065f
            canvas.drawText(project.title, project.format.pageWidth / 2f, project.format.pageHeight * .15f, paint)
            paint.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
            paint.textSize = project.format.pageWidth * .022f
            canvas.drawText(project.subtitle, project.format.pageWidth / 2f, project.format.pageHeight * .90f, paint)
        } else if (page.layout != AlbumPageLayout.BackCover) {
            paint.textAlign = Paint.Align.LEFT
            paint.textSize = project.format.pageWidth * .035f
            canvas.drawText(page.layout.title, project.format.pageWidth * .07f, project.format.pageHeight * .10f, paint)
            paint.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
            paint.textSize = project.format.pageWidth * .016f
            canvas.drawText(page.caption.take(36), project.format.pageWidth * .07f, project.format.pageHeight * .92f, paint)
        }
        document.finishPage(pdfPage)
    }

    private fun drawCenterCrop(canvas: Canvas, bitmap: Bitmap, destination: Rect) {
        val sourceRatio = bitmap.width.toFloat() / bitmap.height.coerceAtLeast(1)
        val targetRatio = destination.width().toFloat() / destination.height().coerceAtLeast(1)
        val source = if (sourceRatio > targetRatio) {
            val width = (bitmap.height * targetRatio).toInt()
            Rect((bitmap.width - width) / 2, 0, (bitmap.width + width) / 2, bitmap.height)
        } else {
            val height = (bitmap.width / targetRatio).toInt()
            Rect(0, (bitmap.height - height) / 2, bitmap.width, (bitmap.height + height) / 2)
        }
        canvas.drawBitmap(bitmap, source, RectF(destination), Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
    }
}
