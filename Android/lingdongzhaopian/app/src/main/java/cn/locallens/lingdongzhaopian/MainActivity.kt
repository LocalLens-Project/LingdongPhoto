package cn.locallens.lingdongzhaopian

import android.content.Intent
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.os.SystemClock
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import cn.locallens.lingdongzhaopian.ui.theme.LingdongzhaopianTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity(), SensorEventListener {
    private val viewModel: LingdongViewModel by viewModels()
    private var pendingDocument: ExportedArtwork? = null
    private lateinit var sensorManager: SensorManager
    private var lastShakeAt = 0L

    private val createDocument = registerForActivityResult(
        ActivityResultContracts.CreateDocument("image/*")
    ) { uri ->
        val export = pendingDocument
        pendingDocument = null
        if (uri == null || export == null) return@registerForActivityResult
        lifecycleScope.launch(Dispatchers.IO) {
            val succeeded = ExportManager.writeToUri(this@MainActivity, uri, export)
            withContext(Dispatchers.Main) {
                Toast.makeText(this@MainActivity, if (succeeded) "已导出到文件" else "导出失败", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        receiveSharedImages(intent)
        setContent {
            LingdongzhaopianTheme {
                val state by viewModel.state.collectAsState()
                MainScreen(
                    state = state,
                    viewModel = viewModel,
                    onExport = { bounds -> exportArtwork(findComposeRoot(), bounds) },
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    override fun onPause() {
        sensorManager.unregisterListener(this)
        super.onPause()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER || viewModel.state.value.photos.isEmpty()) return
        val gravity = SensorManager.GRAVITY_EARTH
        val force = kotlin.math.sqrt(
            event.values[0] * event.values[0] + event.values[1] * event.values[1] + event.values[2] * event.values[2]
        ) / gravity
        val now = SystemClock.elapsedRealtime()
        if (force >= 2.65f && now - lastShakeAt > 1_200L) {
            lastShakeAt = now
            viewModel.resetComposition()
            window.decorView.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
            Toast.makeText(this, "已恢复初始视图", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveSharedImages(intent)
    }

    internal fun receiveSharedImages(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND && intent?.action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java).orEmpty()
        } else {
            listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java))
        }
        if (uris.isNotEmpty()) {
            if (uris.size > 1) viewModel.setMode(CreationMode.Journal)
            viewModel.loadUris(this, uris, append = uris.size > 1)
        }
    }

    private fun findComposeRoot(): View {
        val content = findViewById<ViewGroup>(android.R.id.content)
        return content.getChildAt(0) ?: content
    }

    private fun exportArtwork(view: View, bounds: androidx.compose.ui.geometry.Rect) {
        lifecycleScope.launch {
            // 等待导出面板退场，避免遮挡画布截图。
            viewModel.stopMotionPreview()
            viewModel.setExporting(true)
            delay(220)
            val rawState = viewModel.state.value
            val state = if (rawState.mode == CreationMode.PrivacyMosaic && rawState.preferences.metadataPolicy == MetadataPolicy.Preserve) {
                rawState.copy(preferences = rawState.preferences.copy(metadataPolicy = MetadataPolicy.RemoveLocation))
            } else rawState
            val exportsMotionPhoto = state.preferences.supportsMotionPhotos &&
                state.mode != CreationMode.PrivacyMosaic &&
                state.preferences.exportDestination == ExportDestination.PhotoLibrary &&
                state.photos.any { it.isMotionPhoto }
            if (exportsMotionPhoto) Toast.makeText(this@MainActivity, "正在生成 Motion Photo 动态作品…", Toast.LENGTH_LONG).show()
            val exported = runCatching {
                if (exportsMotionPhoto) {
                    MotionPhotoExporter.captureAndEncode(
                        this@MainActivity,
                        view,
                        bounds,
                        state,
                        setFrames = viewModel::setMotionExportFrames,
                        clearFrames = viewModel::clearMotionExportFrames,
                    )
                } else {
                    ExportManager.captureAndEncode(this@MainActivity, view, bounds, state)
                }
            }.getOrElse {
                viewModel.setExporting(false)
                Toast.makeText(this@MainActivity, "生成作品失败：${it.message ?: "请稍后重试"}", Toast.LENGTH_LONG).show()
                return@launch
            }
            viewModel.setExporting(false)
            when (state.preferences.exportDestination) {
                ExportDestination.PhotoLibrary -> {
                    val saved = withContext(Dispatchers.IO) {
                        ExportManager.saveToPhotoLibrary(this@MainActivity, exported)
                    }
                    Toast.makeText(this@MainActivity, if (saved) "已保存到相册" else "保存失败", Toast.LENGTH_SHORT).show()
                }

                ExportDestination.Files -> {
                    pendingDocument = exported
                    createDocument.launch(exported.fileName)
                }

                ExportDestination.Share -> {
                    val uri = FileProvider.getUriForFile(
                        this@MainActivity,
                        "$packageName.files",
                        exported.file,
                    )
                    startActivity(
                        Intent.createChooser(
                            Intent(Intent.ACTION_SEND).apply {
                                type = exported.mime
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            },
                            "分享灵动照片",
                        )
                    )
                }
            }
        }
    }
}
