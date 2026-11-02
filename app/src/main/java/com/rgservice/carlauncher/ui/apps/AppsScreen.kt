package com.rgservice.carlauncher.ui.apps

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rgservice.carlauncher.data.apps.AppEntry
import com.rgservice.carlauncher.data.apps.AppsRepository
import com.rgservice.carlauncher.ui.components.CarCard
import com.rgservice.carlauncher.ui.components.CarScreen
import com.rgservice.carlauncher.ui.components.Txt
import com.rgservice.carlauncher.ui.theme.CarTheme

/** Todas las apps instaladas. Tocar abre; mantener apretada = opciones. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AppsScreen(apps: AppsRepository, onBack: () -> Unit, onOpen: (String) -> Unit, onLong: (String) -> Unit) {
    val c = CarTheme.colors
    val list by produceState<List<AppEntry>?>(null, apps) { value = apps.all() }
    CarScreen(
        title = "Apps",
        subtitle = list?.let { "${it.size} apps · mantené apretada una para agregarla a Accesos" },
        onBack = onBack,
    ) {
        CarCard(Modifier.weight(1f).fillMaxWidth(), padding = androidx.compose.foundation.layout.PaddingValues(12.dp)) {
            val l = list
            if (l == null) {
                Txt("Buscando apps…", 20, c.muted, modifier = Modifier.align(Alignment.Center))
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(140.dp),
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(l, key = { it.pkg }) { e ->
                        Column(
                            Modifier.clip(RoundedCornerShape(18.dp))
                                .combinedClickable(onClick = { onOpen(e.pkg) }, onLongClick = { onLong(e.pkg) })
                                .padding(vertical = 14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            val icon = remember(e.pkg) { apps.icon(e.pkg) }
                            if (icon != null) Image(icon, contentDescription = null, modifier = Modifier.size(64.dp))
                            else Box(Modifier.size(64.dp).clip(RoundedCornerShape(18.dp)).background(c.pill))
                            Txt(e.label, 16, align = TextAlign.Center, maxLines = 2,
                                modifier = Modifier.fillMaxWidth().padding(top = 8.dp, start = 6.dp, end = 6.dp))
                        }
                    }
                }
            }
        }
    }
}
