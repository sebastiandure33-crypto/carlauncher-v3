package com.rgservice.carlauncher.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rgservice.carlauncher.R
import com.rgservice.carlauncher.ui.theme.CarTheme

/** Pantalla secundaria: fondo, botón volver, título y acciones a la derecha. */
@Composable
fun CarScreen(
    title: String,
    subtitle: String?,
    onBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    val c = CarTheme.colors
    Box(
        Modifier.fillMaxSize().background(c.ground)
            .background(Brush.radialGradient(listOf(c.glow, Color.Transparent), radius = 1400f)),
    ) {
        Column(Modifier.fillMaxSize().padding(28.dp)) {
            Row(Modifier.fillMaxWidth().height(64.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(56.dp).clip(CircleShape).background(c.card).border(1.dp, c.line, CircleShape)
                        .clickable(onClick = onBack),
                    contentAlignment = Alignment.Center,
                ) { LineIcon(R.drawable.ic_back, 26.dp, c.text) }
                Column(Modifier.weight(1f).padding(start = 18.dp)) {
                    Txt(title, 32, weight = FontWeight.Bold)
                    if (subtitle != null) Txt(subtitle, 17, c.muted, tabular = true)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically, content = actions)
            }
            Spacer(Modifier.height(22.dp))
            content()
        }
    }
}

/** Botón píldora (principal = relleno con el acento). */
@Composable
fun PillButton(text: String, icon: Int?, primary: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = CarTheme.colors
    val shape = RoundedCornerShape(28.dp)
    Row(
        modifier.height(56.dp).clip(shape)
            .background(if (primary) c.accent else c.card)
            .border(1.dp, if (primary) Color.Transparent else c.line, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 22.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) LineIcon(icon, 22.dp, if (primary) c.onAccent else c.accent, Modifier.padding(end = 10.dp))
        Txt(text, 19, if (primary) c.onAccent else c.accent, FontWeight.SemiBold)
    }
}
