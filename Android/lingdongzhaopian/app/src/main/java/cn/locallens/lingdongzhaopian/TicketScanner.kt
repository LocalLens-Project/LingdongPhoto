package cn.locallens.lingdongzhaopian

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.util.Size
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import kotlinx.coroutines.delay
import java.util.concurrent.Executors

private enum class ScannerState { Preparing, Ready, Denied }

/**
 * In-app ticket scanning.
 *
 * Android has no App Clip equivalent, so the code is decoded and verified entirely inside this
 * app; the camera frames are analysed in memory and never written anywhere.
 */
@Composable
fun TicketScannerDialog(onDismiss: () -> Unit) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false),
    ) {
        TicketScannerScreen(onDismiss)
    }
}

@Composable
private fun TicketScannerScreen(onCancel: () -> Unit) {
    val context = LocalContext.current
    var state by remember {
        mutableStateOf(
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
            ) ScannerState.Ready else ScannerState.Preparing
        )
    }
    var feedback by remember { mutableStateOf<String?>(null) }
    var processing by remember { mutableStateOf(false) }
    var verified by remember { mutableStateOf<TicketPayload?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> state = if (granted) ScannerState.Ready else ScannerState.Denied }

    LaunchedEffect(Unit) {
        if (state == ScannerState.Preparing) permissionLauncher.launch(Manifest.permission.CAMERA)
    }

    LaunchedEffect(feedback) {
        if (feedback != null) {
            delay(2_000)
            feedback = null
            processing = false
        }
    }

    val payload = verified
    if (payload != null) {
        TicketVerificationScreen(payload, onCancel)
        return
    }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        if (state == ScannerState.Ready) {
            CameraPreview { value ->
                if (processing) return@CameraPreview
                processing = true
                if (!TicketEnvelope.looksLikeTicketURL(value)) {
                    feedback = "这不是可验证的灵动照片票根"
                    return@CameraPreview
                }
                runCatching { TicketEnvelope.decode(value) }
                    .onSuccess { verified = it }
                    // A ticket-shaped code that fails to open deserves the specific reason,
                    // e.g. a newer format or contents that were edited after generation.
                    .onFailure { error ->
                        feedback = (error as? TicketEnvelopeException)?.readableMessage
                            ?: "这不是可验证的灵动照片票根"
                    }
            }
            ScannerOverlay(feedback, onCancel)
        } else {
            UnavailableContent(
                state = state,
                onOpenSettings = {
                    context.startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", context.packageName, null),
                        )
                    )
                },
                onCancel = onCancel,
            )
        }
    }
}

@Composable
private fun ScannerOverlay(feedback: String?, onCancel: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text("扫描验证票根", color = Color.White, fontSize = 20.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
                Text("二维码仅在本机解析", color = Color.White.copy(alpha = .66f), fontSize = 12.sp)
            }
            Box(
                Modifier
                    .size(44.dp)
                    .background(Color.White.copy(alpha = .14f), CircleShape)
                    .border(1.dp, Color.White.copy(alpha = .20f), CircleShape)
                    .clickable(onClick = onCancel),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Close, "关闭扫码", Modifier.size(16.dp), tint = Color.White)
            }
        }

        Spacer(Modifier.weight(1f))

        Box(Modifier.align(Alignment.CenterHorizontally).size(278.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                drawRoundRect(
                    color = if (feedback == null) Color.White.copy(alpha = .92f) else Color(0xFFFF8A00),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(30.dp.toPx(), 30.dp.toPx()),
                    style = Stroke(
                        width = 3.dp.toPx(),
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(18.dp.toPx(), 9.dp.toPx())),
                    ),
                )
            }
            Icon(
                Icons.Outlined.QrCodeScanner,
                null,
                Modifier.size(54.dp).align(Alignment.Center),
                tint = Color.White.copy(alpha = .16f),
            )
        }

        Spacer(Modifier.weight(1f))

        Column(
            Modifier
                .fillMaxWidth()
                .background(Color.Black.copy(alpha = .46f), RoundedCornerShape(22.dp))
                .border(1.dp, Color.White.copy(alpha = .16f), RoundedCornerShape(22.dp))
                .padding(horizontal = 22.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            AnimatedVisibility(feedback != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                ) {
                    Icon(Icons.Outlined.Warning, null, Modifier.size(17.dp), tint = Color(0xFFFF8A00))
                    Text(
                        feedback.orEmpty(),
                        color = Color(0xFFFF8A00),
                        fontSize = 14.sp,
                        fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                    )
                }
            }
            if (feedback == null) {
                Text(
                    "将票根二维码置于取景框内",
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                )
            }
            Text(
                "不会拍照、保存画面或读取系统相册",
                color = Color.White.copy(alpha = .64f),
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun UnavailableContent(state: ScannerState, onOpenSettings: () -> Unit, onCancel: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            if (state == ScannerState.Denied) Icons.Outlined.CameraAlt else Icons.Outlined.QrCodeScanner,
            null,
            Modifier.size(58.dp),
            tint = Color.White,
        )
        Spacer(Modifier.height(22.dp))
        Text(
            if (state == ScannerState.Denied) "没有相机权限" else "正在准备相机",
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            if (state == ScannerState.Denied) {
                "请允许“灵动照片”访问相机后再扫描票根二维码。"
            } else "首次使用时，系统会询问是否允许访问相机。",
            color = Color.White.copy(alpha = .66f),
            fontSize = 14.sp,
            lineHeight = 20.sp,
            textAlign = TextAlign.Center,
        )
        if (state == ScannerState.Denied) {
            Spacer(Modifier.height(22.dp))
            Box(
                Modifier
                    .background(Color.White, CircleShape)
                    .clickable(onClick = onOpenSettings)
                    .padding(horizontal = 26.dp, vertical = 12.dp),
            ) {
                Text("前往系统设置", color = Color.Black, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold)
            }
        }
        Spacer(Modifier.height(26.dp))
        Box(
            Modifier
                .border(1.dp, Color.White.copy(alpha = .40f), CircleShape)
                .clickable(onClick = onCancel)
                .padding(horizontal = 26.dp, vertical = 12.dp),
        ) {
            Text("返回模式选择", color = Color.White)
        }
    }
}

@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
@Composable
private fun CameraPreview(onRecognized: (String) -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val latestHandler by rememberUpdatedState(onRecognized)
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER } }

    DisposableEffect(previewView) {
        val executor = Executors.newSingleThreadExecutor()
        val scanner = BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
        )
        var provider: ProcessCameraProvider? = null
        var lastValue: String? = null
        var lastRecognizedAt = 0L

        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            provider = runCatching { future.get() }.getOrNull() ?: return@addListener
            val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
            val analysis = ImageAnalysis.Builder()
                .setResolutionSelector(
                    ResolutionSelector.Builder()
                        .setResolutionStrategy(
                            ResolutionStrategy(Size(1280, 720), ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER)
                        )
                        .build()
                )
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            analysis.setAnalyzer(executor) { proxy ->
                val image = proxy.image
                if (image == null) {
                    proxy.close()
                    return@setAnalyzer
                }
                scanner.process(InputImage.fromMediaImage(image, proxy.imageInfo.rotationDegrees))
                    .addOnSuccessListener { barcodes ->
                        val value = barcodes.firstNotNullOfOrNull { it.rawValue }
                        val now = System.currentTimeMillis()
                        if (value != null && (value != lastValue || now - lastRecognizedAt > 2_000)) {
                            lastValue = value
                            lastRecognizedAt = now
                            ContextCompat.getMainExecutor(context).execute { latestHandler(value) }
                        }
                    }
                    .addOnCompleteListener { proxy.close() }
            }
            runCatching {
                provider?.unbindAll()
                provider?.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
            }
        }, ContextCompat.getMainExecutor(context))

        onDispose {
            runCatching { provider?.unbindAll() }
            scanner.close()
            executor.shutdown()
        }
    }

    AndroidView({ previewView }, Modifier.fillMaxSize())
}
