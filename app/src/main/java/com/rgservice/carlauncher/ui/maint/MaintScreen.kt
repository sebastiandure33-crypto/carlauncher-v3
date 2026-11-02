package com.rgservice.carlauncher.ui.maint

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import com.rgservice.carlauncher.data.maint.DateRow
import com.rgservice.carlauncher.data.maint.KmRow
import com.rgservice.carlauncher.data.maint.MaintSnapshot
import com.rgservice.carlauncher.data.maint.Maintenance
import com.rgservice.carlauncher.ui.components.CarCard
import com.rgservice.carlauncher.ui.components.CarScreen
import com.rgservice.carlauncher.ui.components.LineIcon
import com.rgservice.carlauncher.ui.components.PillButton
import com.rgservice.carlauncher.ui.components.Txt
import com.rgservice.carlauncher.ui.components.fmtKm
import com.rgservice.carlauncher.ui.theme.CarTheme
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Lo que dispara la pantalla de mantenimiento. */
class MaintActions(
    val onBack: () -> Unit,
    val onOdometer: () -> Unit,
    val onAdd: () -> Unit,
    val onChangedNow: (String) -> Unit,
    val onSticker: (String) -> Unit,
    val onMore: (String) -> Unit,
    val onDate: (String) -> Unit,
    val onClearDate: (String) -> Unit,
)

/** Pieza → (video de entrada, video en bucle). Los ítems propios y las fechas muestran el auto entero. */
private val CLIPS = mapOf(
    "oil" to (R.raw.holo_oil_in to R.raw.holo_oil_loop),
    "gear" to (R.raw.holo_gear_in to R.raw.holo_gear_loop),
    "air" to (R.raw.holo_air_in to R.raw.holo_air_loop),
    "tires" to (R.raw.holo_tires_in to R.raw.holo_tires_loop),
    "brakes" to (R.raw.holo_brakes_in to R.raw.holo_brakes_loop),
    "belt" to (R.raw.holo_belt_in to R.raw.holo_belt_loop),
)

// El visor es siempre oscuro, como el holograma
private val vGround = Color(0xFF0B0D10)
private val vText = Color(0xFFF3F5F7)
private val vMuted = Color(0xFF9BA5B1)
private val vAmber = Color(0xFFFFB547)
private val vWarn = Color(0xFFFF7A59)

private val dateFmt = SimpleDateFormat("d MMM yyyy", Locale("es"))
private fun fmtDate(ms: Long) = dateFmt.format(Date(ms)).replace(".", "")

/**
 * Mantenimiento: a la izquierda el visor holográfico (la cámara va a la pieza elegida),
 * a la derecha la lista de ítems por km y de vencimientos.
 */
@Composable
fun MaintScreen(m: MaintSnapshot, initialSel: String?, onSelect: (String) -> Unit, a: MaintActions) {
    val c = CarTheme.colors
    var sel by remember {
        mutableStateOf(
            initialSel
                ?: m.km.firstOrNull { it.warn }?.let { "km:${it.id}" }
                ?: "km:oil",
        )
    }
    LaunchedEffect(sel) { onSelect(sel) }
    val kmSel = m.km.firstOrNull { "km:${it.id}" == sel }
    val dateSel = m.dates.firstOrNull { "date:${it.id}" == sel }

    CarScreen(
        title = "Mantenimiento",
        subtitle = m.odo?.let { "Tu auto: ${it.fmtKm()} km (tablero)" } ?: "Cargá los km del tablero para empezar",
        onBack = a.onBack,
        actions = {
            PillButton("Agregar", R.drawable.ic_plus, primary = false, onClick = a.onAdd)
            PillButton(if (m.odo != null) "Km del tablero" else "Cargar km del tablero", R.drawable.ic_gauge,
                primary = m.odo == null, onClick = a.onOdometer)
        },
    ) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val listW = if (maxWidth < 1100.dp) 340.dp else 400.dp
            Row(Modifier.fillMaxSize()) {
                Column(Modifier.weight(1f).fillMaxHeight()) {
                    Box(Modifier.weight(1f).fillMaxWidth()) {
                        Viewer(kmSel, dateSel, sel, Modifier.align(Alignment.TopCenter).aspectRatio(16f / 9f))
                    }
                    Row(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (kmSel != null) {
                            PillButton("✔  Lo cambié hoy", null, primary = true, Modifier.weight(1.2f)) { a.onChangedNow(kmSel.id) }
                            PillButton("Sticker del taller", null, primary = false, Modifier.weight(1f)) { a.onSticker(kmSel.id) }
                            PillButton("Más…", null, primary = false, Modifier.weight(0.6f)) { a.onMore(kmSel.id) }
                        } else if (dateSel != null) {
                            PillButton(if (dateSel.dateMs != null) "Cambiar fecha" else "Elegir fecha", R.drawable.ic_calendar,
                                primary = true, Modifier.weight(1f)) { a.onDate(dateSel.id) }
                            if (dateSel.dateMs != null && !dateSel.custom) {
                                PillButton("Quitar fecha", null, primary = false, Modifier.weight(1f)) { a.onClearDate(dateSel.id) }
                            }
                        }
                    }
                }
                CarCard(
                    Modifier.padding(start = 24.dp).width(listW).fillMaxHeight(),
                    padding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                ) {
                    LazyColumn(Modifier.fillMaxSize()) {
                        item { Section("Por kilómetros") }
                        items(m.km, key = { "km:" + it.id }) { r ->
                            KmItemRow(r, selected = sel == "km:${r.id}") { sel = "km:${r.id}" }
                        }
                        item { Section("Vencimientos") }
                        items(m.dates, key = { "date:" + it.id }) { r ->
                            DateItemRow(r, selected = sel == "date:${r.id}") { sel = "date:${r.id}" }
                        }
                    }
                }
            }
        }
    }
}

/* ------------------------------------------------------------------ visor */

@Composable
private fun Viewer(km: KmRow?, date: DateRow?, sel: String, modifier: Modifier) {
    val shape = RoundedCornerShape(26.dp)
    var player by remember { mutableStateOf<HoloVideoView?>(null) }
    val clip = km?.let { CLIPS[it.id] }
    LaunchedEffect(player, sel) {
        val p = player ?: return@LaunchedEffect
        if (clip != null) p.play(clip.first, clip.second) else p.play(0, R.raw.holo_overview)
    }
    // El texto aparece cuando la cámara llega a la pieza
    val capAlpha = remember { Animatable(0f) }
    val capX = remember { Animatable(-16f) }
    LaunchedEffect(sel) {
        capAlpha.snapTo(0f); capX.snapTo(-16f)
        delay(if (clip != null) 900 else 250)
        coroutineScope {
            launch { capAlpha.animateTo(1f, tween(500, easing = FastOutSlowInEasing)) }
            launch { capX.animateTo(0f, tween(500, easing = FastOutSlowInEasing)) }
        }
    }

    Box(modifier.clip(shape).background(vGround).border(1.dp, CarTheme.colors.line, shape)) {
        AndroidView(
            factory = { ctx -> HoloVideoView(ctx).also { player = it } },
            onRelease = { it.stop() },
            modifier = Modifier.fillMaxSize(),
        )
        // sombra a la izquierda para que el texto se lea sobre el video
        Box(
            Modifier.fillMaxHeight().fillMaxWidth(0.55f)
                .background(Brush.horizontalGradient(listOf(Color(0xE00B0D10), Color(0x8C0B0D10), Color.Transparent))),
        )
        Column(Modifier.padding(start = 32.dp, top = 28.dp).offset(x = capX.value.dp).alpha(capAlpha.value).width(400.dp)) {
            when {
                km != null -> {
                    val big = if (km.remaining != null) "${km.remaining.fmtKm()} km" else "Sin configurar"
                    val sub = if (km.next != null) "Próximo a los ${km.next.fmtKm()} km"
                        else if (km.id == "tires") "Rotación cada ${km.interval.fmtKm()} km" else "Cambio cada ${km.interval.fmtKm()} km"
                    Caption(km.name, sub, big, if (km.warn) vWarn else vAmber, if (km.remaining != null) km.fraction else null)
                }
                date != null -> {
                    val big = if (date.days != null) Maintenance.leftText(date.days).replaceFirstChar { it.uppercase() } else "Sin fecha"
                    val sub = date.dateMs?.let { "Vence el ${fmtDate(it)}" } ?: "Elegí la fecha de vencimiento"
                    Caption(date.name, sub, big, if (date.warn) vWarn else vAmber, null)
                }
            }
        }
    }
}

@Composable
private fun Caption(title: String, sub: String, big: String, color: Color, fraction: Float?) {
    Txt(title, 30, vText, FontWeight.SemiBold)
    Txt(sub, 18, vMuted, tabular = true)
    Txt(big, 44, color, FontWeight.SemiBold, tabular = true, modifier = Modifier.padding(top = 8.dp))
    if (fraction != null) {
        Box(Modifier.padding(top = 10.dp).width(220.dp).height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color(0xFF272D36))) {
            Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(color))
        }
    }
}

/* ------------------------------------------------------------------ lista */

@Composable
private fun Section(t: String) {
    Txt(t, 16, CarTheme.colors.muted, FontWeight.SemiBold, modifier = Modifier.padding(start = 12.dp, top = 12.dp, bottom = 6.dp))
}

@Composable
private fun KmItemRow(r: KmRow, selected: Boolean, onClick: () -> Unit) {
    val c = CarTheme.colors
    Row(
        Modifier.fillMaxWidth().height(66.dp).clip(RoundedCornerShape(16.dp))
            .background(if (selected) c.pill else Color.Transparent)
            .clickable(onClick = onClick).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f).padding(end = 14.dp)) {
            Txt(r.name, 18, weight = FontWeight.SemiBold)
            Box(Modifier.padding(top = 7.dp).fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(c.track)) {
                Box(Modifier.fillMaxWidth(r.fraction).fillMaxHeight().background(if (r.warn) c.warn else c.accent))
            }
        }
        Txt(
            if (r.remaining != null) "${r.remaining.fmtKm()} km" else "Configurar", 17,
            if (r.warn) c.warn else if (r.remaining != null) c.text else c.accent, FontWeight.SemiBold, tabular = true,
            modifier = Modifier.alpha(if (r.warn) pulse() else 1f),
        )
    }
}

@Composable
private fun DateItemRow(r: DateRow, selected: Boolean, onClick: () -> Unit) {
    val c = CarTheme.colors
    val color = if (r.warn) c.warn else c.accent
    Row(
        Modifier.fillMaxWidth().height(66.dp).clip(RoundedCornerShape(16.dp))
            .background(if (selected) c.pill else Color.Transparent)
            .clickable(onClick = onClick).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LineIcon(R.drawable.ic_calendar, 22.dp, color)
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Txt(r.name, 18, weight = FontWeight.SemiBold)
            Txt(r.dateMs?.let { fmtDate(it) } ?: "Sin fecha", 14, c.muted)
        }
        Box(
            Modifier.height(30.dp).clip(RoundedCornerShape(15.dp)).background(color.copy(alpha = 0.12f))
                .alpha(if (r.warn) pulse() else 1f).padding(horizontal = 12.dp),
            contentAlignment = Alignment.Center,
        ) { Txt(r.days?.let { Maintenance.leftText(it) } ?: "Configurar", 15, color, FontWeight.SemiBold) }
    }
}

@Composable
private fun pulse(): Float {
    val t = rememberInfiniteTransition(label = "pulse")
    return t.animateFloat(1f, 0.45f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "a").value
}
