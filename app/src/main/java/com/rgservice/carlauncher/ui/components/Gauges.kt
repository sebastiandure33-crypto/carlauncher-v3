package com.rgservice.carlauncher.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import com.rgservice.carlauncher.data.Gauge
import com.rgservice.carlauncher.ui.theme.CarTheme
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Medidor de arco de 270° con marcas (como en el diseño).
 * Se dibuja animado al aparecer y late suave cuando está en alerta.
 */
@Composable
fun ArcGauge(
    fraction: Float,
    color: Color,
    size: Dp,
    warn: Boolean,
    modifier: Modifier = Modifier,
    center: @Composable () -> Unit,
) {
    val c = CarTheme.colors
    val anim = remember { Animatable(0f) }
    LaunchedEffect(fraction) {
        anim.animateTo(fraction, tween(durationMillis = 1300, easing = FastOutSlowInEasing))
    }
    val pulse = if (warn) {
        val t = rememberInfiniteTransition(label = "pulse")
        t.animateFloat(1f, 0.45f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "a").value
    } else 1f

    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val s = min(this.size.width, this.size.height)
            val k = s / 176f
            val cx = this.size.width / 2f
            val cy = this.size.height / 2f
            // 28 marcas cada 10°
            for (i in 0..27) {
                val a = Math.toRadians(135.0 + i * 10.0)
                val r1 = 77.5f * k
                val r2 = 82.5f * k
                drawLine(
                    c.tick,
                    Offset(cx + r1 * cos(a).toFloat(), cy + r1 * sin(a).toFloat()),
                    Offset(cx + r2 * cos(a).toFloat(), cy + r2 * sin(a).toFloat()),
                    strokeWidth = 1.7f * k,
                )
            }
            val r = 66f * k
            val tl = Offset(cx - r, cy - r)
            val sz = Size(2 * r, 2 * r)
            drawArc(c.track, 135f, 270f, false, tl, sz, style = Stroke(10f * k, cap = StrokeCap.Round))
            val sweep = 270f * anim.value
            if (sweep > 0.5f) {
                // brillo barato: un trazo más ancho y transparente debajo
                drawArc(color.copy(alpha = 0.18f * pulse), 135f, sweep, false, tl, sz, style = Stroke(20f * k, cap = StrokeCap.Round))
                drawArc(color.copy(alpha = pulse), 135f, sweep, false, tl, sz, style = Stroke(10f * k, cap = StrokeCap.Round))
            }
        }
        Box(Modifier.alpha(if (warn) pulse else 1f)) { center() }
    }
}

/** Medidor de un ítem de mantenimiento con su nombre debajo. */
@Composable
fun MaintGauge(g: Gauge, ringSize: Dp, modifier: Modifier = Modifier) {
    val c = CarTheme.colors
    val color = if (g.warn) c.warn else c.accent
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        ArcGauge(fraction = g.fraction, color = color, size = ringSize, warn = g.warn) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Txt(
                    if (g.configured) g.remainingKm.fmtKm() else "—",
                    size = (ringSize.value * 0.175f).toInt().coerceAtLeast(18),
                    color = if (g.warn) c.warn else c.text,
                    weight = FontWeight.SemiBold,
                    tabular = true,
                )
                Txt("km restantes", 15, c.muted)
            }
        }
        Txt(g.name, 21, weight = FontWeight.SemiBold, modifier = Modifier)
        val sub = when {
            !g.configured -> "Tocá para configurar"
            g.remainingKm == 0 -> "¡Cambiar ahora!"
            g.warn -> "Cambiar pronto"
            g.nextAtKm != null -> "Próximo: ${g.nextAtKm.fmtKm()} km"
            else -> "Cada ${g.intervalKm.fmtKm()} km"
        }
        Txt(sub, 16, if (g.warn) c.warn else c.muted)
    }
}
