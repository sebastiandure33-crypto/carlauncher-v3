package com.rgservice.carlauncher.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.rgservice.carlauncher.R

/** Paleta del diseño: pocos colores, un acento y uno de alerta. */
@Immutable
data class CarColors(
    val ground: Color,
    val card: Color,
    val card2: Color,
    val line: Color,
    val text: Color,
    val muted: Color,
    val accent: Color,
    val onAccent: Color,
    val warn: Color,
    val track: Color,
    val tick: Color,
    val pill: Color,
    val glow: Color,
    val isDark: Boolean,
)

val DarkColors = CarColors(
    ground = Color(0xFF0B0D10),
    card = Color(0xFF15181D),
    card2 = Color(0xFF1D2128),
    line = Color(0xFF272C34),
    text = Color(0xFFF3F5F7),
    muted = Color(0xFF9BA5B1),
    accent = Color(0xFF6FB1FF),
    onAccent = Color(0xFF0B0E12),
    warn = Color(0xFFFF7A59),
    track = Color(0xFF272D36),
    tick = Color(0xFF3A414B),
    pill = Color(0x246FB1FF),
    glow = Color(0x266FB1FF),
    isDark = true,
)

val LightColors = CarColors(
    ground = Color(0xFFE6E9ED),
    card = Color(0xFFFBFCFD),
    card2 = Color(0xFFEEF1F5),
    line = Color(0xFFD8DDE4),
    text = Color(0xFF10141A),
    muted = Color(0xFF4F5A69),   // un poco más oscuro que antes: se lee mejor a pleno sol
    accent = Color(0xFF1B66E0),
    onAccent = Color(0xFFFFFFFF),
    warn = Color(0xFFC2361A),
    track = Color(0xFFE1E5EB),
    tick = Color(0xFFC3CAD3),
    pill = Color(0x1A1B66E0),
    glow = Color(0x1F1B66E0),
    isDark = false,
)

val Barlow = FontFamily(
    Font(R.font.barlow_regular, FontWeight.Normal),
    Font(R.font.barlow_medium, FontWeight.Medium),
    Font(R.font.barlow_semibold, FontWeight.SemiBold),
    Font(R.font.barlow_bold, FontWeight.Bold),
)

val LocalCarColors = staticCompositionLocalOf { DarkColors }

/** Acceso corto a los colores: CarTheme.colors.accent */
object CarTheme {
    val colors: CarColors
        @Composable get() = LocalCarColors.current
}

@Composable
fun CarLauncherTheme(dark: Boolean, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalCarColors provides if (dark) DarkColors else LightColors) {
        content()
    }
}
