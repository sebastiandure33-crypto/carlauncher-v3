package com.rgservice.carlauncher.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rgservice.carlauncher.R
import com.rgservice.carlauncher.core.UiSize
import com.rgservice.carlauncher.data.ThemeMode
import com.rgservice.carlauncher.data.apps.Slot
import com.rgservice.carlauncher.ui.components.CarCard
import com.rgservice.carlauncher.ui.components.CarScreen
import com.rgservice.carlauncher.ui.components.Hairline
import com.rgservice.carlauncher.ui.components.LineIcon
import com.rgservice.carlauncher.ui.components.Txt
import com.rgservice.carlauncher.ui.components.fmtKm
import com.rgservice.carlauncher.ui.theme.CarTheme

/** Lo que muestra Ajustes. */
class SettingsData(
    val size: UiSize,
    val theme: ThemeMode,
    val stats: Boolean,
    val name: String,
    val limit: Int,
    val odo: Int?,
    val slots: Map<Slot, String?>,
    val slotLabel: (String) -> String,
    val locationOk: Boolean,
    val musicOk: Boolean,
    val welcome: Boolean,
    val ignitionOpen: Boolean,
    val isHome: Boolean,
    val overlayOk: Boolean,
    val version: String,
)

class SettingsActions(
    val onBack: () -> Unit,
    val onSize: (UiSize) -> Unit,
    val onTheme: (ThemeMode) -> Unit,
    val onStats: (Boolean) -> Unit,
    val onName: () -> Unit,
    val onLimit: () -> Unit,
    val onOdometer: () -> Unit,
    val onTrip: () -> Unit,
    val onSlot: (Slot) -> Unit,
    val onLocationPermission: () -> Unit,
    val onMusicPermission: () -> Unit,
    val onMusicDiag: () -> Unit,
    val onWelcome: (Boolean) -> Unit,
    val onIgnitionOpen: (Boolean) -> Unit,
    val onHomeApp: () -> Unit,
    val onOverlay: () -> Unit,
    val onPreviewWelcome: () -> Unit,
    val onAndroidSettings: () -> Unit,
)

@Composable
fun SettingsScreen(d: SettingsData, a: SettingsActions) {
    CarScreen(title = "Ajustes", subtitle = "Car Launcher 3 · versión ${d.version}", onBack = a.onBack) {
        Row(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                Group("Pantalla") {
                    Label("Tamaño de letras y botones")
                    Chips(UiSize.entries.map { it.label }, d.size.ordinal) { a.onSize(UiSize.entries[it]) }
                    Label("Modo noche", top = 18)
                    Chips(listOf("Automático (sol)", "Siempre noche", "Siempre día"), d.theme.ordinal) { a.onTheme(ThemeMode.entries[it]) }
                    Line()
                    Toggle("Recuadro de prueba (fps y memoria)", d.stats) { a.onStats(!d.stats) }
                }
                Group("Arranque") {
                    Item("Pantalla de inicio de la radio", if (d.isHome) "Car Launcher 3" else "Otro launcher", warn = !d.isHome, onClick = a.onHomeApp)
                    Line()
                    Toggle("Abrir al dar contacto", d.ignitionOpen) { a.onIgnitionOpen(!d.ignitionOpen) }
                    Line()
                    Item("Permiso para abrirse solo", if (d.overlayOk) "Permitido" else "Recomendado", warn = !d.overlayOk, onClick = a.onOverlay)
                    Line()
                    Toggle("Bienvenida animada", d.welcome) { a.onWelcome(!d.welcome) }
                    Line()
                    Item("Ver bienvenida", "Probar", onClick = a.onPreviewWelcome)
                }
                Group("Conductor") {
                    Item("Nombre", d.name, onClick = a.onName)
                    Line()
                    Item("Aviso de velocidad", if (d.limit == 0) "Sin aviso" else "${d.limit} km/h", onClick = a.onLimit)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                Group("Auto") {
                    Item("Km del tablero", d.odo?.let { "${it.fmtKm()} km" } ?: "Sin cargar", onClick = a.onOdometer)
                    Line()
                    Item("Viaje", "Poner en cero", onClick = a.onTrip)
                }
                Group("Botones de la barra") {
                    Slot.entries.forEachIndexed { i, s ->
                        if (i > 0) Line()
                        Item(s.label, d.slots[s]?.let(d.slotLabel) ?: "Elegir app", onClick = { a.onSlot(s) })
                    }
                }
                Group("Permisos y sistema") {
                    Item("Ubicación (GPS)", if (d.locationOk) "Permitido" else "Falta permitir", warn = !d.locationOk, onClick = a.onLocationPermission)
                    Line()
                    Item("Música (acceso a notificaciones)", if (d.musicOk) "Permitido" else "Falta permitir", warn = !d.musicOk, onClick = a.onMusicPermission)
                    Line()
                    Item("Diagnóstico de música", "Probar botones", onClick = a.onMusicDiag)
                    Line()
                    Item("Ajustes de Android", "Abrir", onClick = a.onAndroidSettings)
                }
            }
        }
    }
}

@Composable
private fun Group(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column {
        Txt(title, 17, CarTheme.colors.muted, FontWeight.SemiBold, modifier = Modifier.padding(start = 8.dp, bottom = 10.dp))
        CarCard(Modifier.fillMaxWidth(), padding = PaddingValues(horizontal = 20.dp, vertical = 12.dp)) {
            Column(Modifier.fillMaxWidth(), content = content)
        }
    }
}

@Composable
private fun Label(t: String, top: Int = 6) {
    Txt(t, 17, CarTheme.colors.muted, modifier = Modifier.padding(top = top.dp, bottom = 10.dp))
}

@Composable
private fun Line() { Hairline(Modifier.padding(vertical = 4.dp).fillMaxWidth().height(1.dp)) }

@Composable
private fun Item(title: String, value: String, warn: Boolean = false, onClick: () -> Unit) {
    val c = CarTheme.colors
    Row(
        Modifier.fillMaxWidth().height(62.dp).clip(RoundedCornerShape(14.dp)).clickable(onClick = onClick).padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Txt(title, 19, weight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Txt(value, 18, if (warn) c.warn else c.muted, tabular = true, modifier = Modifier.padding(start = 12.dp))
        LineIcon(R.drawable.ic_chevron, 20.dp, c.muted, Modifier.padding(start = 8.dp))
    }
}

@Composable
private fun Toggle(title: String, on: Boolean, onClick: () -> Unit) {
    val c = CarTheme.colors
    Row(
        Modifier.fillMaxWidth().height(62.dp).clip(RoundedCornerShape(14.dp)).clickable(onClick = onClick).padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Txt(title, 19, weight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Box(
            Modifier.size(58.dp, 34.dp).clip(RoundedCornerShape(17.dp)).background(if (on) c.accent else c.track).padding(4.dp),
            contentAlignment = if (on) Alignment.CenterEnd else Alignment.CenterStart,
        ) { Box(Modifier.size(26.dp).clip(CircleShape).background(if (on) c.onAccent else c.muted)) }
    }
}

@Composable
private fun Chips(options: List<String>, selected: Int, onPick: (Int) -> Unit) {
    val c = CarTheme.colors
    Row(Modifier.fillMaxWidth().padding(bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        options.forEachIndexed { i, t ->
            val on = i == selected
            val shape = RoundedCornerShape(16.dp)
            Box(
                Modifier.weight(1f).height(54.dp).clip(shape)
                    .background(if (on) c.pill else Color.Transparent)
                    .border(1.dp, if (on) c.accent else c.line, shape)
                    .clickable { onPick(i) },
                contentAlignment = Alignment.Center,
            ) { Txt(t, 17, if (on) c.accent else c.text, FontWeight.SemiBold) }
        }
    }
}
