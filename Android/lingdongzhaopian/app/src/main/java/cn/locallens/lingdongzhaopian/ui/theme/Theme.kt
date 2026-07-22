package cn.locallens.lingdongzhaopian.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF171719),
    secondary = Color(0xFF65656A),
    tertiary = Color(0xFFFF4F7B),
    background = Color.Transparent,
    surface = Color(0xFFF7F7F9),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onBackground = Color(0xFF161619),
    onSurface = Color(0xFF161619),
)

@Composable
fun LingdongzhaopianTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = Typography,
        content = content,
    )
}
