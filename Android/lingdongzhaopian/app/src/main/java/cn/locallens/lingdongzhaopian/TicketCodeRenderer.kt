package cn.locallens.lingdongzhaopian

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Shader
import android.graphics.Typeface
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.common.BitMatrix
import com.google.zxing.oned.Code128Writer
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import kotlin.math.floor
import kotlin.math.max

/**
 * Draws the two ticket credentials.
 *
 * The QR content is the same App Clip invocation URL iOS produces, so a code created here scans
 * and verifies on iPhone and vice versa.
 */
object TicketCodeRenderer {
    fun image(
        style: TicketCodeStyle,
        payload: TicketPayload,
        baseURLString: String = TicketEnvelope.DEFAULT_BASE_URL,
        pixelWidth: Int,
        pixelHeight: Int,
        foregroundColor: Int,
        backgroundColor: Int? = null,
    ): Bitmap = when (style) {
        TicketCodeStyle.Barcode -> rasterized(
            barcodeMatrix(TicketEnvelope.barcodeValue(payload)),
            pixelWidth,
            pixelHeight,
            horizontalPadding = 30,
            verticalPadding = 22,
            foregroundColor = foregroundColor,
            backgroundColor = backgroundColor,
            stretchesVertically = true,
        )

        TicketCodeStyle.VerificationQR -> rasterized(
            qrMatrix(TicketEnvelope.invocationURL(payload, baseURLString)),
            pixelWidth,
            pixelHeight,
            horizontalPadding = 34,
            verticalPadding = 34,
            foregroundColor = foregroundColor,
            backgroundColor = backgroundColor,
        )
    }

    /** Standalone shareable card holding only the credential — never the photograph itself. */
    fun exportCard(
        style: TicketCodeStyle,
        payload: TicketPayload,
        baseURLString: String = TicketEnvelope.DEFAULT_BASE_URL,
    ): Bitmap {
        val canvasWidth = if (style == TicketCodeStyle.Barcode) 1_600 else 1_260
        val canvasHeight = if (style == TicketCodeStyle.Barcode) 920 else 1_520
        val codeWidth = if (style == TicketCodeStyle.Barcode) 1_260 else 760
        val codeHeight = if (style == TicketCodeStyle.Barcode) 300 else 760

        val paletteColors = payload.palette.take(3).map { ticketColor(it.hex) }
        val baseColor = paletteColors.firstOrNull() ?: 0xFFB8DBC2.toInt()
        val codeColor = if (luminance(baseColor) > .52f) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
        val gradientColors = if (paletteColors.isEmpty()) {
            intArrayOf(
                mixed(baseColor, 0xFFFFFFFF.toInt(), .18f),
                mixed(baseColor, 0xFF000000.toInt(), .08f),
            )
        } else {
            paletteColors.map {
                mixed(it, if (luminance(baseColor) > .52f) 0xFFFFFFFF.toInt() else 0xFF000000.toInt(), .08f)
            }.toIntArray()
        }

        val code = image(
            style = style,
            payload = payload,
            baseURLString = baseURLString,
            pixelWidth = codeWidth,
            pixelHeight = codeHeight,
            foregroundColor = codeColor,
            backgroundColor = null,
        )

        val bitmap = Bitmap.createBitmap(canvasWidth, canvasHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val background = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                canvasWidth.toFloat(),
                canvasHeight.toFloat(),
                if (gradientColors.size >= 2) gradientColors else intArrayOf(gradientColors[0], gradientColors[0]),
                null,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, canvasWidth.toFloat(), canvasHeight.toFloat(), background)

        val title = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = codeColor
            textSize = if (style == TicketCodeStyle.Barcode) 54f else 48f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(style.title, canvasWidth / 2f, 130f + 54f, title)

        val subtitle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(codeColor, .62f)
            textSize = 28f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(payload.ticketID, canvasWidth / 2f, 208f + 30f, subtitle)

        val codeTop = if (style == TicketCodeStyle.Barcode) 330f else 310f
        val destination = Rect(
            (canvasWidth - codeWidth) / 2,
            codeTop.toInt(),
            (canvasWidth - codeWidth) / 2 + codeWidth,
            codeTop.toInt() + codeHeight,
        )
        // The credential is drawn at its native pixel size, so nearest-neighbour keeps the modules
        // crisp instead of blurring their edges.
        canvas.drawBitmap(code, null, destination, Paint())
        code.recycle()

        val note = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(codeColor, .66f)
            textSize = 25f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(
            if (style == TicketCodeStyle.Barcode) "真实票根编号 · 不包含照片与拍摄隐私" else "扫描以查看色盘、拍摄信息与文案",
            canvasWidth / 2f,
            destination.bottom + 54f + 25f,
            note,
        )
        return bitmap
    }

    private fun qrMatrix(content: String): BitMatrix = QRCodeWriter().encode(
        content,
        BarcodeFormat.QR_CODE,
        1,
        1,
        mapOf(
            EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M,
            EncodeHintType.CHARACTER_SET to "UTF-8",
            EncodeHintType.MARGIN to 1,
        ),
    )

    private fun barcodeMatrix(content: String): BitMatrix = Code128Writer().encode(
        content,
        BarcodeFormat.CODE_128,
        1,
        1,
        mapOf(EncodeHintType.MARGIN to 12),
    )

    private fun rasterized(
        matrix: BitMatrix,
        targetWidth: Int,
        targetHeight: Int,
        horizontalPadding: Int,
        verticalPadding: Int,
        foregroundColor: Int,
        backgroundColor: Int?,
        stretchesVertically: Boolean = false,
    ): Bitmap {
        val width = max(1, targetWidth)
        val height = max(1, targetHeight)
        val availableWidth = max(1, width - horizontalPadding * 2)
        val availableHeight = max(1, height - verticalPadding * 2)
        val uniformScale = max(
            1f,
            floor(
                minOf(
                    availableWidth.toFloat() / matrix.width,
                    availableHeight.toFloat() / matrix.height,
                )
            ),
        )
        val horizontalScale = if (stretchesVertically) {
            max(1f, floor(availableWidth.toFloat() / matrix.width))
        } else uniformScale
        val verticalScale = if (stretchesVertically) {
            max(1f, floor(availableHeight.toFloat() / matrix.height))
        } else uniformScale

        val drawnWidth = matrix.width * horizontalScale
        val drawnHeight = matrix.height * verticalScale
        val left = (width - drawnWidth) / 2f
        val top = (height - drawnHeight) / 2f

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        backgroundColor?.let { canvas.drawColor(it) }
        val paint = Paint().apply {
            color = foregroundColor
            isAntiAlias = false
            style = Paint.Style.FILL
        }
        for (y in 0 until matrix.height) {
            var x = 0
            while (x < matrix.width) {
                if (!matrix.get(x, y)) {
                    x += 1
                    continue
                }
                var run = 1
                while (x + run < matrix.width && matrix.get(x + run, y)) run += 1
                canvas.drawRect(
                    left + x * horizontalScale,
                    top + y * verticalScale,
                    left + (x + run) * horizontalScale,
                    top + (y + 1) * verticalScale,
                    paint,
                )
                x += run
            }
        }
        return bitmap
    }

    fun ticketColor(hex: String): Int {
        val cleaned = hex.filter { it.isLetterOrDigit() }
        val value = cleaned.toLongOrNull(16) ?: return 0xFF2E6440.toInt()
        return if (cleaned.length == 6) {
            0xFF000000.toInt() or (value.toInt() and 0xFFFFFF)
        } else {
            0xFF2E6440.toInt()
        }
    }

    private fun luminance(color: Int): Float {
        val red = ((color shr 16) and 0xFF) / 255f
        val green = ((color shr 8) and 0xFF) / 255f
        val blue = (color and 0xFF) / 255f
        return red * .299f + green * .587f + blue * .114f
    }

    private fun mixed(color: Int, other: Int, amount: Float): Int {
        val value = amount.coerceIn(0f, 1f)
        fun channel(shift: Int): Int {
            val start = (color shr shift) and 0xFF
            val end = (other shr shift) and 0xFF
            return (start + (end - start) * value).toInt().coerceIn(0, 255)
        }
        return (0xFF shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
    }

    private fun withAlpha(color: Int, alpha: Float): Int =
        ((alpha.coerceIn(0f, 1f) * 255).toInt() shl 24) or (color and 0xFFFFFF)
}
