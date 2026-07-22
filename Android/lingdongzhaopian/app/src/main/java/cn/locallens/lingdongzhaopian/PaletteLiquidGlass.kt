package cn.locallens.lingdongzhaopian

import android.graphics.RenderEffect as AndroidRenderEffect
import android.graphics.RuntimeShader
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp

/**
 * Recreates the optical part of iOS 26's clear glass for the palette panel.
 *
 * The duplicated artwork is rendered into an off-screen layer, then the AGSL
 * shader magnifies it, bends it continuously at the rounded edge and separates
 * the RGB samples slightly.  Keeping the edge field continuous is important:
 * repeated decorative "lens" cells read as a mechanical wave pattern rather
 * than the environment-driven highlights of Apple's clear material.
 */
@Composable
internal fun PaletteRefractedBackdrop(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    BoxWithConstraints(modifier) {
        val density = LocalDensity.current
        val widthPx = with(density) { maxWidth.toPx() }
        val heightPx = with(density) { maxHeight.toPx() }
        val radiusPx = with(density) { 22.dp.toPx() }
        // Clear glass is primarily a lens, not a frosted card. Keep only enough
        // optical softening to suppress GPU sampling stair-steps at the rim.
        val blurPx = with(density) { 2.35.dp.toPx() }
        val shape = remember { RoundedCornerShape(22.dp) }
        val effect = remember(widthPx, heightPx, radiusPx, blurPx) {
            RuntimeShader(PALETTE_CLEAR_GLASS_SHADER).run {
                setFloatUniform("size", widthPx, heightPx)
                setFloatUniform("cornerRadius", radiusPx)
                val refraction = AndroidRenderEffect.createRuntimeShaderEffect(this, "content")
                val opticalSoftening = AndroidRenderEffect.createBlurEffect(
                    blurPx,
                    blurPx,
                    android.graphics.Shader.TileMode.CLAMP,
                )
                AndroidRenderEffect.createChainEffect(refraction, opticalSoftening)
                    .asComposeRenderEffect()
            }
        }

        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer {
                    compositingStrategy = CompositingStrategy.Offscreen
                    renderEffect = effect
                    clip = true
                    this.shape = shape
                },
            content = content,
        )
    }
}

/** Highlights and inset rims are intentionally separate from the refraction. */
internal fun Modifier.paletteClearGlassSurface(accent: Color): Modifier = drawWithContent {
    val radius = 22.dp.toPx()
    val outsideStroke = 1.15.dp.toPx()

    drawContent()

    // Native clear glass adds only a very light wash over the refracted image.
    drawRoundRect(
        brush = Brush.linearGradient(
            listOf(Color.White.copy(alpha = .065f), accent.copy(alpha = .018f), Color.White.copy(alpha = .022f)),
            start = Offset.Zero,
            end = Offset(size.width, size.height),
        ),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius),
    )

    // Match the iOS palettePanelOutline: one continuous environmental rim. A
    // repeated/swept highlight reads as the white scallops reported by the user.
    drawRoundRect(
        brush = Brush.linearGradient(
            listOf(
                Color.White.copy(alpha = .58f),
                accent.copy(alpha = .34f),
                Color.White.copy(alpha = .12f),
            ),
            start = Offset.Zero,
            end = Offset(size.width, size.height),
        ),
        topLeft = Offset(outsideStroke, outsideStroke),
        size = Size(size.width - outsideStroke * 2f, size.height - outsideStroke * 2f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius - outsideStroke),
        style = Stroke(outsideStroke),
    )
}

private const val PALETTE_CLEAR_GLASS_SHADER = """
    uniform shader content;
    uniform float2 size;
    uniform float cornerRadius;

    float roundedBoxSdf(float2 point) {
        float2 halfSize = size * 0.5 - float2(2.0);
        float2 q = abs(point - size * 0.5) - (halfSize - float2(cornerRadius));
        return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - cornerRadius;
    }

    float safeSign(float value) {
        return value < 0.0 ? -1.0 : 1.0;
    }

    float2 safeNormalize(float2 value, float2 fallback) {
        float valueLength = length(value);
        return valueLength > 0.001 ? value / valueLength : fallback;
    }

    float2 roundedBoxGradient(float2 point, float radius) {
        float2 center = size * 0.5;
        float2 local = point - center;
        float2 halfSize = size * 0.5 - float2(2.0);
        float2 corner = abs(local) - (halfSize - float2(radius));
        if (corner.x >= 0.0 || corner.y >= 0.0) {
            float2 outside = max(corner, float2(0.0));
            float outsideLength = length(outside);
            if (outsideLength > 0.001) {
                return sign(local) * outside / outsideLength;
            }
        }
        float useX = step(corner.y, corner.x);
        return float2(useX * safeSign(local.x), (1.0 - useX) * safeSign(local.y));
    }

    float sphericalProfile(float x) {
        float safeX = clamp(x, 0.0, 1.0);
        return 1.0 - sqrt(max(0.0, 1.0 - safeX * safeX));
    }

    half4 main(float2 point) {
        float signedDistance = roundedBoxSdf(point);
        float insideDistance = max(-signedDistance, 0.0);
        float refractionHeight = min(72.0, min(size.x, size.y) * 0.27);

        // Both reference implementations model the meniscus with a spherical
        // profile. The untouched centre is what separates clear glass from blur.
        if (insideDistance >= refractionHeight) {
            half4 centerColor = content.eval(point);
            half centerLuma = dot(centerColor.rgb, half3(0.2126, 0.7152, 0.0722));
            centerColor.rgb = mix(half3(centerLuma), centerColor.rgb, half(1.035));
            return centerColor;
        }

        float2 center = size * 0.5;
        float2 shapeGradient = roundedBoxGradient(point, min(cornerRadius * 1.5, min(size.x, size.y) * 0.5));
        float2 depthGradient = safeNormalize(point - center, shapeGradient);
        float2 lensGradient = safeNormalize(shapeGradient + depthGradient * 0.10, shapeGradient);
        float profile = sphericalProfile(1.0 - insideDistance / refractionHeight);
        float refractionAmount = -118.0;
        float bend = profile * refractionAmount;
        float2 refractedPoint = clamp(point + lensGradient * bend, float2(1.0), size - float2(1.0));

        // Dispersion follows the curved corners and fades to zero along the axes;
        // this prevents a bright repeated band across the straight top/bottom edge.
        float2 normalized = (point - center) / max(center, float2(1.0));
        float dispersionIntensity = normalized.x * normalized.y * 0.075;
        float2 separation = lensGradient * bend * dispersionIntensity;
        half4 redSample = content.eval(clamp(refractedPoint + separation, float2(1.0), size - float2(1.0)));
        half4 greenSample = content.eval(refractedPoint);
        half4 blueSample = content.eval(clamp(refractedPoint - separation, float2(1.0), size - float2(1.0)));
        half3 rgb = half3(redSample.r, greenSample.g, blueSample.b);

        half luminance = dot(rgb, half3(0.2126, 0.7152, 0.0722));
        rgb = mix(half3(luminance), rgb, half(1.055));
        return half4(rgb, greenSample.a);
    }
"""
