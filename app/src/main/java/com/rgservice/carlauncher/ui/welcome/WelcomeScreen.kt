package com.rgservice.carlauncher.ui.welcome

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.rgservice.carlauncher.R
import com.rgservice.carlauncher.core.HoloVideoView
import com.rgservice.carlauncher.data.maint.MaintSnapshot
import com.rgservice.carlauncher.ui.components.Txt
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val wGround = Color(0xFF0B0D10)
private val wText = Color(0xFFF3F5F7)
private val wMuted = Color(0xFFC9D0D8)
private val wAccent = Color(0xFF6FB1FF)
private val wWarn = Color(0xFFFF7A59)

/**
 * Bienvenida al arrancar (unos 5 s, siempre oscura como el holograma):
 * el auto aparece en holograma, saludo tipeado y un chequeo rápido con datos reales.
 * Tocar en cualquier lado la saltea.
 */
@Composable
fun WelcomeScreen(name: String, maint: MaintSnapshot, onDone: () -> Unit) {
    val done by rememberUpdatedState(onDone)
    val hello = "Hola, $name"
    val greeting = remember {
        val h = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        when { h < 12 -> "Buenos días. Buen viaje."; h < 19 -> "Buenas tardes. Buen viaje."; else -> "Buenas noches. Manejá con cuidado." }
    }
    val checks = remember(maint) {
        val oil = maint.km.firstOrNull { it.id == "oil" }
        val tires = maint.km.firstOrNull { it.id == "tires" }
        val docs = maint.dates.count { it.warn }
        listOf(
            if (oil?.warn == true) "Aceite de motor: cambiar pronto" to true else "Aceite de motor en orden" to false,
            if (tires?.warn == true) "Neumáticos: rotación pendiente" to true else "Neumáticos en orden" to false,
            if (docs > 0) "Documentos: $docs por vencer" to true else "Documentos al día" to false,
        )
    }

    var typed by remember { mutableIntStateOf(0) }
    val kicker = remember { Animatable(0f) }
    val sub = remember { Animatable(0f) }
    val rows = remember { List(3) { Animatable(0f) } }
    val bar = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        coroutineScope {
            launch { delay(1100); kicker.animateTo(1f, tween(500)) }
            launch { delay(1200); bar.animateTo(1f, tween(3400, easing = LinearEasing)) }
            launch {
                delay(1400)
                for (i in 1..hello.length) { typed = i; delay(55) }
                delay(100)
                sub.animateTo(1f, tween(450, easing = FastOutSlowInEasing))
            }
            launch {
                delay(1400L + hello.length * 55L + 450)
                rows.forEach { launch { it.animateTo(1f, tween(420, easing = FastOutSlowInEasing)) }; delay(260) }
            }
        }
    }
    LaunchedEffect(Unit) { delay(5000); done() }

    Box(
        Modifier.fillMaxSize().background(wGround)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { done() },
    ) {
        AndroidView(
            factory = { ctx -> HoloVideoView(ctx).apply { play(R.raw.holo_intro, 0, null) } },
            onRelease = { it.stop() },
            modifier = Modifier.align(Alignment.CenterEnd).fillMaxHeight().aspectRatio(16f / 9f),
        )
        Box(
            Modifier.fillMaxHeight().fillMaxWidth(0.6f)
                .background(Brush.horizontalGradient(listOf(Color(0xF00B0D10), Color(0xA00B0D10), Color.Transparent))),
        )
        Column(Modifier.align(Alignment.CenterStart).padding(start = 64.dp).width(560.dp)) {
            Txt("CAR LAUNCHER", 16, wAccent, FontWeight.SemiBold, modifier = Modifier.alpha(kicker.value))
            val cursor = if (typed in 1 until hello.length) "▍" else ""
            Txt(hello.take(typed) + cursor, 64, wText, FontWeight.Bold, modifier = Modifier.padding(top = 6.dp))
            Txt(greeting, 24, wMuted,
                modifier = Modifier.alpha(sub.value).offset(y = ((1f - sub.value) * 14f).dp).padding(top = 4.dp))
            Column(Modifier.padding(top = 26.dp)) {
                checks.forEachIndexed { i, (txt, bad) ->
                    val a = rows[i].value
                    Row(
                        Modifier.height(36.dp).alpha(a).offset(x = ((1f - a) * -16f).dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.size(10.dp).clip(CircleShape).background(if (bad) wWarn else wAccent))
                        Txt(txt, 20, if (bad) wWarn else wMuted, FontWeight.Medium, modifier = Modifier.padding(start = 12.dp))
                    }
                }
            }
            Box(Modifier.padding(top = 26.dp).width(260.dp).height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color(0xFF272D36))) {
                Box(Modifier.fillMaxWidth(bar.value).fillMaxHeight().background(wAccent))
            }
        }
    }
}
