package cn.locallens.lingdongzhaopian

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

fun Modifier.liquidGlass(
    shape: Shape,
    tint: Color = Color.White,
    clear: Boolean = true,
    shadowElevation: Dp = 14.dp,
): Modifier = this
    .shadow(shadowElevation, shape, ambientColor = Color.Black.copy(alpha = .12f), spotColor = Color.Black.copy(alpha = .16f))
    .clip(shape)
    .background(
        Brush.linearGradient(
            colors = if (clear) listOf(
                tint.copy(alpha = .20f),
                Color.White.copy(alpha = .09f),
                tint.copy(alpha = .11f),
                Color.Black.copy(alpha = .055f),
            ) else listOf(tint.copy(alpha = .34f), Color.White.copy(alpha = .15f), tint.copy(alpha = .20f)),
            start = Offset.Zero,
            end = Offset.Infinite,
        ),
        shape,
    )
    .border(
        BorderStroke(
            1.dp,
            Brush.linearGradient(
                listOf(Color.White.copy(alpha = .82f), tint.copy(alpha = .34f), Color.White.copy(alpha = .11f)),
            ),
        ),
        shape,
    )
    .drawWithContent {
        drawContent()
        drawArc(
            brush = Brush.sweepGradient(listOf(Color.White.copy(alpha = .42f), Color.Transparent, Color.White.copy(alpha = .10f))),
            startAngle = 198f,
            sweepAngle = 134f,
            useCenter = false,
            topLeft = Offset(size.width * .08f, size.height * .08f),
            size = Size(size.width * .84f, size.height * .84f),
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.dp.toPx()),
        )
        drawOval(
            brush = Brush.radialGradient(
                listOf(Color.White.copy(alpha = .15f), Color.Transparent),
                center = Offset(size.width * .30f, size.height * .16f),
                radius = size.minDimension * .72f,
            ),
            alpha = .55f,
        )
    }

@Composable
fun LiquidIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    size: Dp = 48.dp,
    tint: Color = Color.White,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        if (pressed) .88f else 1f,
        animationSpec = spring(dampingRatio = .64f, stiffness = 540f),
        label = "liquid-button-scale",
    )
    IconButton(
        onClick = onClick,
        enabled = enabled,
        interactionSource = interaction,
        colors = IconButtonDefaults.iconButtonColors(contentColor = Color.Black.copy(alpha = .87f)),
        modifier = modifier
            .size(size)
            .graphicsLayer {
                scaleX = scale
                scaleY = if (pressed) scale * .96f else scale
                rotationZ = if (pressed) -1.2f else 0f
                alpha = if (enabled) 1f else .28f
            }
            .liquidGlass(CircleShape, tint = tint, clear = true, shadowElevation = 10.dp),
    ) {
        Icon(icon, contentDescription, modifier = Modifier.size(size * .43f))
    }
}

@Composable
fun GlassContainer(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 26.dp,
    tint: Color = Color.White,
    clear: Boolean = true,
    contentAlignment: Alignment = Alignment.Center,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = modifier.liquidGlass(RoundedCornerShape(cornerRadius), tint, clear),
        contentAlignment = contentAlignment,
        content = content,
    )
}
