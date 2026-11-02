package com.rgservice.carlauncher.ui.home

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.rgservice.carlauncher.R
import com.rgservice.carlauncher.core.HoloVideoView
import com.rgservice.carlauncher.data.HomeState
import com.rgservice.carlauncher.data.apps.Slot
import com.rgservice.carlauncher.ui.pages.RightActions
import com.rgservice.carlauncher.ui.pages.RightCard
import com.rgservice.carlauncher.ui.pages.RightData
import com.rgservice.carlauncher.data.ThemeMode
import com.rgservice.carlauncher.data.Weather
import com.rgservice.carlauncher.ui.components.CarCard
import com.rgservice.carlauncher.ui.components.Dock
import com.rgservice.carlauncher.ui.components.DockItem
import com.rgservice.carlauncher.ui.components.Hairline
import com.rgservice.carlauncher.ui.components.LineIcon
import com.rgservice.carlauncher.ui.components.MaintGauge
import com.rgservice.carlauncher.ui.components.Txt
import com.rgservice.carlauncher.ui.components.fmt1
import com.rgservice.carlauncher.ui.components.fmtKm
import com.rgservice.carlauncher.ui.theme.CarTheme
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Acciones que dispara la pantalla de inicio (las resuelve MainActivity). */
class HomeActions(
    val onCycleTheme: () -> Unit,
    val onSettings: () -> Unit,
    val onApps: () -> Unit,
    val onMaint: () -> Unit,
    val onToggleStats: () -> Unit,
    val onComingSoon: (String) -> Unit,
    val onGauge: (String) -> Unit,
    val onOdometer: () -> Unit,
    val onName: () -> Unit,
    val onLimit: () -> Unit,
    val onTrip: () -> Unit,
    val onSlot: (Slot) -> Unit,
    val onSlotLong: (Slot) -> Unit,
    val onBluetooth: () -> Unit,
)

/**
 * Pantalla de inicio. Se adapta sola al alto disponible:
 *  - alto normal: todo,
 *  - más chico (Grande): el clima pasa a la línea de la fecha,
 *  - mucho más chico (Muy grande): sin dibujo del auto y medidores más chicos.
 */
@Composable
fun HomeScreen(state: HomeState, right: RightData, rightActions: RightActions, actions: HomeActions) {
    val c = CarTheme.colors
    Box(
        Modifier
            .fillMaxSize()
            .background(c.ground)
            .background(Brush.radialGradient(listOf(c.glow, Color.Transparent), radius = 1400f)),
    ) {
        BoxWithConstraints(Modifier.fillMaxSize().padding(28.dp)) {
            val compact = maxHeight < 600.dp          // Grande
            val veryCompact = maxHeight < 540.dp      // Muy grande
            Column(Modifier.fillMaxSize()) {
                Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    VehicleCard(state, actions, showCar = !veryCompact, modifier = Modifier.weight(372f).fillMaxHeight())
                    CenterColumn(state, compact, veryCompact, actions, Modifier.weight(452f).fillMaxHeight())
                    RightCard(right, rightActions, small = veryCompact, modifier = Modifier.weight(400f).fillMaxHeight())
                }
                Spacer(Modifier.height(20.dp))
                Dock(
                    left = listOf(
                        slotItem(R.drawable.ic_nav, Slot.Nav, actions),
                        slotItem(R.drawable.ic_music, Slot.Music, actions),
                        slotItem(R.drawable.ic_radio, Slot.Radio, actions),
                        slotItem(R.drawable.ic_phone, Slot.Phone, actions),
                        DockItem(R.drawable.ic_bt, "Bluetooth", onClick = actions.onBluetooth),
                        DockItem(
                            if (state.theme == ThemeMode.Day) R.drawable.ic_sun else R.drawable.ic_moon,
                            when (state.theme) { ThemeMode.Auto -> "Noche auto"; ThemeMode.Night -> "Noche"; ThemeMode.Day -> "Día" },
                            active = state.dark,
                        ) { actions.onCycleTheme() },
                    ),
                    right = listOf(
                        DockItem(R.drawable.ic_apps, "Apps", onClick = actions.onApps),
                        DockItem(R.drawable.ic_settings, "Ajustes", onClick = actions.onSettings),
                    ),
                )
            }
        }
    }
}

/* ------------------------------------------------------------------ Columna 1: vehículo */

@Composable
private fun VehicleCard(s: HomeState, actions: HomeActions, showCar: Boolean, modifier: Modifier) {
    val c = CarTheme.colors
    CarCard(modifier, padding = PaddingValues(28.dp)) {
        Column(Modifier.fillMaxSize()) {
            Txt("Hola, ${s.name}", 30, weight = FontWeight.Bold, modifier = Modifier.clickable(onClick = actions.onName))
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Txt(greeting(), 18, c.muted, modifier = Modifier.weight(1f))
                GpsPill(s.gpsOk)
            }
            Spacer(Modifier.weight(1f))
            if (showCar) {
                CarPicture(Modifier.fillMaxWidth().widthIn(max = 316.dp).aspectRatio(316f / 178f).align(Alignment.CenterHorizontally))
                Spacer(Modifier.weight(1f))
            }
            Row(Modifier.clickable(onClick = actions.onLimit), verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f), verticalAlignment = Alignment.Bottom) {
                    Txt(s.speedKmh?.toString() ?: "--", 84, if (s.overLimit) c.warn else c.text, FontWeight.Medium, tabular = true, lineHeight = 1f)
                    Txt("km/h", 20, c.muted, modifier = Modifier.padding(start = 10.dp, bottom = 12.dp))
                }
                if (s.speedLimit > 0) {
                    Box(
                        Modifier.size(58.dp).border(4.dp, if (s.overLimit) c.warn else c.line, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Txt(s.speedLimit.toString(), 21, if (s.overLimit) c.warn else c.muted, FontWeight.Bold, tabular = true)
                    }
                }
            }
            Hairline(Modifier.padding(top = 16.dp).fillMaxWidth().height(1.dp))
            Row(Modifier.padding(top = 16.dp).clickable(onClick = actions.onTrip)) {
                Stat("${s.trip.km.fmt1()} km", "Viaje", Modifier.weight(1f))
                Stat(minutesText(s.trip.minutes), "Tiempo", Modifier.weight(1f))
                Stat("${s.trip.avgKmh} km/h", "Promedio", Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun Stat(value: String, label: String, modifier: Modifier) {
    Column(modifier) {
        Txt(value, 22, weight = FontWeight.SemiBold, tabular = true)
        Txt(label, 15, CarTheme.colors.muted)
    }
}

@Composable
private fun GpsPill(ok: Boolean) {
    val c = CarTheme.colors
    val t = rememberInfiniteTransition(label = "gps")
    val a by t.animateFloat(0.5f, 0f, infiniteRepeatable(tween(2000), RepeatMode.Restart), label = "ripple")
    Row(
        Modifier.height(30.dp).clip(RoundedCornerShape(15.dp)).background(c.pill).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(contentAlignment = Alignment.Center) {
            if (ok) Box(Modifier.size(20.dp).alpha(a).background(c.accent, CircleShape))
            Box(Modifier.size(8.dp).alpha(if (ok) 1f else 0.4f).background(c.accent, CircleShape))
        }
        Txt(if (ok) "GPS" else "Sin GPS", 15, c.muted, FontWeight.Medium, modifier = Modifier.padding(start = 4.dp))
    }
}

/** En tema oscuro: holograma en video (lo decodifica el hardware). En tema claro: imagen fija. */
@Composable
private fun CarPicture(modifier: Modifier) {
    val c = CarTheme.colors
    if (c.isDark) {
        AndroidView(
            factory = { ctx -> HoloVideoView(ctx).apply { play(0, R.raw.holo_home) } },
            modifier = modifier,
            onRelease = { it.stop() },
        )
    } else {
        Image(
            painter = painterResource(R.drawable.auto3d),
            contentDescription = "Tu auto",
            contentScale = ContentScale.Fit,
            modifier = modifier.padding(horizontal = 12.dp, vertical = 18.dp),
        )
    }
}

/* ------------------------------------------------------------------ Columna 2: hora, clima, mantenimiento */

@Composable
private fun CenterColumn(s: HomeState, compact: Boolean, veryCompact: Boolean, actions: HomeActions, modifier: Modifier) {
    val c = CarTheme.colors
    Column(modifier) {
        Clock(onLongPress = actions.onToggleStats)
        if (compact) {
            s.weather?.let { Txt("${it.tempC}° · ${it.description}", 19, c.muted, modifier = Modifier.align(Alignment.CenterHorizontally)) }
        } else {
            s.weather?.let { WeatherStrip(it, s.dark, Modifier.padding(top = 16.dp)) }
        }
        CarCard(
            Modifier.padding(top = 16.dp).weight(1f).fillMaxWidth(),
            padding = PaddingValues(start = 24.dp, end = 24.dp, top = 12.dp, bottom = 18.dp),
        ) {
            Column(Modifier.fillMaxSize()) {
                Row(Modifier.fillMaxWidth().height(40.dp), verticalAlignment = Alignment.CenterVertically) {
                    Txt(
                        if (s.odoKm != null) "Mantenimiento · tablero ${s.odoKm.fmtKm()} km" else "Mantenimiento",
                        17, c.muted, tabular = true,
                        modifier = Modifier.weight(1f).clickable(onClick = actions.onOdometer),
                    )
                    Txt(
                        if (s.maintWarnings > 0) "Ver todo · ${s.maintWarnings} ⚠" else "Ver todo", 17,
                        if (s.maintWarnings > 0) c.warn else c.accent, FontWeight.SemiBold,
                        modifier = Modifier.clickable(onClick = actions.onMaint).padding(8.dp),
                    )
                }
                val ring: Dp = if (veryCompact) 118.dp else 156.dp
                Row(Modifier.weight(1f).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    MaintGauge(s.oil, ring, Modifier.weight(1f).clickable { actions.onGauge(s.oil.id) })
                    Hairline(Modifier.width(1.dp).fillMaxHeight(0.85f))
                    MaintGauge(s.gear, ring, Modifier.weight(1f).clickable { actions.onGauge(s.gear.id) })
                }
            }
        }
    }
}

@Composable
private fun Clock(onLongPress: () -> Unit) {
    val c = CarTheme.colors
    var now by remember { mutableStateOf(Date()) }
    LaunchedEffect(Unit) {
        while (true) { now = Date(); delay(1000L - System.currentTimeMillis() % 1000L) }
    }
    val t = rememberInfiniteTransition(label = "colon")
    val colon by t.animateFloat(1f, 0.2f, infiniteRepeatable(tween(1000), RepeatMode.Reverse), label = "c")
    val hh = SimpleDateFormat("HH", Locale.US).format(now)
    val mm = SimpleDateFormat("mm", Locale.US).format(now)
    val date = SimpleDateFormat("EEEE, d 'de' MMMM", Locale("es")).format(now)
    Column(
        Modifier.fillMaxWidth().pointerInput(Unit) { detectTapGestures(onLongPress = { onLongPress() }) },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Txt(hh, 88, weight = FontWeight.Medium, tabular = true, lineHeight = 1f)
            Txt(":", 88, weight = FontWeight.Medium, modifier = Modifier.alpha(colon).padding(horizontal = 3.dp).padding(bottom = 10.dp), lineHeight = 1f)
            Txt(mm, 88, weight = FontWeight.Medium, tabular = true, lineHeight = 1f)
        }
        Txt(date, 21, c.muted)
    }
}

@Composable
private fun WeatherStrip(w: Weather, dark: Boolean, modifier: Modifier) {
    val c = CarTheme.colors
    CarCard(modifier.fillMaxWidth().height(72.dp), radius = 22.dp, padding = PaddingValues(horizontal = 20.dp)) {
        Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            LineIcon(weatherIcon(w.code, dark), 34.dp, c.accent)
            Txt("${w.tempC}°", 40, weight = FontWeight.Medium, modifier = Modifier.padding(start = 14.dp), lineHeight = 1f)
            Column(Modifier.weight(1f).padding(start = 14.dp)) {
                Txt(if (w.updatedAgo != null) "${w.description} · ${w.updatedAgo}" else w.description, 17)
                Txt("Máx ${w.maxC}° · Mín ${w.minC}°", 15, c.muted, tabular = true)
            }
            Column(horizontalAlignment = Alignment.End) {
                Txt("${w.humidity}%", 15, c.muted, tabular = true)
                Txt("${w.windKmh} km/h", 15, c.muted, tabular = true)
            }
        }
    }
}

/* ------------------------------------------------------------------ utilidades */

/** Botón de la barra que abre una app; mantenido = elegir otra. */
private fun slotItem(icon: Int, s: Slot, a: HomeActions) =
    DockItem(icon, s.label, onLongClick = { a.onSlotLong(s) }, onClick = { a.onSlot(s) })

private fun weatherIcon(code: Int, night: Boolean) = when {
    code == 0 -> if (night) R.drawable.ic_moon else R.drawable.ic_sun
    code <= 2 -> R.drawable.ic_cloud_sun
    code == 3 -> R.drawable.ic_cloud
    code == 45 || code == 48 -> R.drawable.ic_fog
    code in 51..67 || code in 80..82 -> R.drawable.ic_rain
    code in 71..77 -> R.drawable.ic_snow
    code >= 95 -> R.drawable.ic_storm
    else -> R.drawable.ic_cloud_sun
}

private fun greeting(): String {
    val hr = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
    return when { hr < 12 -> "Buenos días"; hr < 19 -> "Buenas tardes"; else -> "Buenas noches" }
}

private fun minutesText(m: Int) = if (m >= 60) "${m / 60} h ${String.format(Locale.US, "%02d", m % 60)}" else "$m min"
