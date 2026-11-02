package com.rgservice.carlauncher.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rgservice.carlauncher.ui.theme.CarTheme

data class DockItem(
    val icon: Int,
    val label: String,
    val active: Boolean = false,
    val onLongClick: (() -> Unit)? = null,
    val onClick: () -> Unit,
)

/**
 * Barra de abajo. Cada botón es una columna centrada: el ícono y el texto
 * comparten siempre el mismo eje (lo que antes se veía desfasado).
 */
@Composable
fun Dock(left: List<DockItem>, right: List<DockItem>, modifier: Modifier = Modifier) {
    val c = CarTheme.colors
    CarCard(modifier.fillMaxWidth().height(80.dp), padding = androidx.compose.foundation.layout.PaddingValues(horizontal = 10.dp)) {
        Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            left.forEach { DockButton(it, Modifier.weight(1f)) }
            Spacer(Modifier.padding(horizontal = 6.dp).width(1.dp).height(44.dp).background(c.line))
            right.forEach { DockButton(it, Modifier.weight(1f)) }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun DockButton(item: DockItem, modifier: Modifier) {
    val c = CarTheme.colors
    val tint = if (item.active) c.accent else c.text
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier
            .fillMaxHeight()
            .padding(vertical = 8.dp, horizontal = 4.dp)
            .clip(shape)
            .background(if (item.active) c.pill else Color.Transparent, shape)
            .combinedClickable(role = Role.Button, onClickLabel = item.label, onLongClick = item.onLongClick, onClick = item.onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        LineIcon(item.icon, 28.dp, tint)
        Txt(
            item.label, 15,
            color = if (item.active) c.accent else c.muted,
            align = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
        )
    }
}
