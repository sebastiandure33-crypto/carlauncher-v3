package com.rgservice.carlauncher.ui.pages

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.rgservice.carlauncher.R
import com.rgservice.carlauncher.core.MapTileView
import com.rgservice.carlauncher.data.Media
import com.rgservice.carlauncher.data.apps.AppsRepository
import com.rgservice.carlauncher.data.location.GpsFix
import com.rgservice.carlauncher.data.media.MediaRepository
import com.rgservice.carlauncher.data.media.NavInfo
import com.rgservice.carlauncher.ui.components.CarCard
import com.rgservice.carlauncher.ui.components.LineIcon
import com.rgservice.carlauncher.ui.components.Txt
import com.rgservice.carlauncher.ui.theme.CarTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale

/** Lo que necesita la tarjeta derecha. */
class RightData(
    val media: Media,
    val nav: NavInfo?,
    val fix: GpsFix?,
    val fallbackLat: Double,
    val fallbackLon: Double,
    val favs: List<String>,
    val dest: Map<String, String?>,
    val apps: AppsRepository,
    val initialPage: Int,
    val initialZoom: Int,
)

/** Lo que dispara la tarjeta derecha (lo resuelve MainActivity). */
class RightActions(
    val onPage: (Int) -> Unit,
    val onPlayPause: () -> Unit,
    val onNext: () -> Unit,
    val onPrevious: () -> Unit,
    val onOpenMusic: () -> Unit,
    val onMusicPermission: () -> Unit,
    val onMusicDiag: () -> Unit,
    val onOpenMaps: () -> Unit,
    val onNavBanner: (NavInfo) -> Unit,
    val onDest: (key: String, name: String) -> Unit,
    val onDestLong: (key: String, name: String) -> Unit,
    val onZoom: (Int) -> Unit,
    val onFav: (String) -> Unit,
    val onFavLong: (String) -> Unit,
    val onFavAdd: () -> Unit,
)

private val TITLES = listOf("Música", "Mapa", "Accesos")
private val ICONS = listOf(R.drawable.ic_music, R.drawable.ic_mappin, R.drawable.ic_apps)

/**
 * Tarjeta derecha con tres páginas: Música, Mapa y Accesos.
 * Se pasa deslizando de costado o tocando las bolitas de arriba.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun RightCard(d: RightData, a: RightActions, small: Boolean, modifier: Modifier) {
    val c = CarTheme.colors
    val pager = rememberPagerState(initialPage = d.initialPage.coerceIn(0, 2)) { 3 }
    val scope = rememberCoroutineScope()
    LaunchedEffect(pager.currentPage) { a.onPage(pager.currentPage) }

    CarCard(modifier, padding = PaddingValues(start = 20.dp, end = 12.dp, top = 14.dp, bottom = 18.dp)) {
        Column(Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().height(40.dp).padding(start = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                val p = pager.currentPage
                LineIcon(ICONS[p], 20.dp, c.muted)
                Txt(
                    if (p == 0) d.media.source else TITLES[p], 17, c.muted,
                    modifier = Modifier.weight(1f).padding(start = 8.dp),
                )
                for (i in 0..2) {
                    val active = i == pager.currentPage
                    val w by animateDpAsState(if (active) 22.dp else 8.dp, label = "dotw")
                    val col by animateColorAsState(if (active) c.accent else c.tick, label = "dotc")
                    Box(
                        Modifier.size(34.dp, 40.dp).clickable { scope.launch { pager.animateScrollToPage(i) } },
                        contentAlignment = Alignment.Center,
                    ) { Box(Modifier.size(w, 8.dp).clip(CircleShape).background(col)) }
                }
            }
            HorizontalPager(state = pager, modifier = Modifier.weight(1f).fillMaxWidth()) { page ->
                Box(Modifier.fillMaxSize().padding(end = 8.dp, top = 6.dp)) {
                    when (page) {
                        0 -> MusicPage(d.media, small, a)
                        1 -> MapPage(d, a)
                        else -> AppsPage(d, small, a)
                    }
                }
            }
        }
    }
}

/* ------------------------------------------------------------------ Música */

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MusicPage(m: Media, small: Boolean, a: RightActions) {
    val c = CarTheme.colors
    var pos by remember { mutableLongStateOf(0L) }
    LaunchedEffect(m) {
        while (true) {
            pos = MediaRepository.positionNow(m)
            if (!m.playing) break
            delay(500)
        }
    }
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(1f))
        val art = if (small) 120.dp else 170.dp
        Box(
            Modifier.size(art).clip(RoundedCornerShape(24.dp))
                .background(Brush.linearGradient(listOf(Color(0xFF3D7BD9), Color(0xFF101826))))
                .combinedClickable(onClick = a.onOpenMusic, onLongClick = a.onMusicDiag),
            contentAlignment = Alignment.BottomStart,
        ) {
            val bmp = m.art
            if (bmp != null) {
                val img = remember(bmp) { bmp.asImageBitmap() }
                Image(img, contentDescription = "Carátula", contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            } else {
                LineIcon(R.drawable.ic_music, art * 0.32f, Color.White.copy(alpha = 0.35f), Modifier.align(Alignment.Center))
            }
            Equalizer(m.playing, Modifier.padding(12.dp))
        }
        Spacer(Modifier.weight(1f))
        Txt(m.title, 25, weight = FontWeight.Bold, align = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Txt(m.artist, 18, c.muted, align = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 4.dp))
        Spacer(Modifier.weight(1f))
        if (!m.hasPermission) {
            Box(
                Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(16.dp)).background(c.pill)
                    .clickable(onClick = a.onMusicPermission),
                contentAlignment = Alignment.Center,
            ) { Txt("Permitir ver y controlar la música", 17, c.accent, FontWeight.SemiBold) }
        } else if (m.durationMs > 0) {
            val frac = (pos.toFloat() / m.durationMs).coerceIn(0f, 1f)
            Box(Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(c.track)) {
                Box(Modifier.fillMaxWidth(frac).fillMaxHeight().background(c.accent))
            }
            Row(Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Txt(mmss(pos), 15, c.muted, tabular = true, modifier = Modifier.weight(1f))
                Txt(mmss(m.durationMs), 15, c.muted, tabular = true)
            }
        } else {
            Spacer(Modifier.height(28.dp))
        }
        Spacer(Modifier.weight(1f))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            RoundButton(R.drawable.ic_prev, if (small) 58.dp else 66.dp, filled = false, onClick = a.onPrevious)
            RoundButton(if (m.playing) R.drawable.ic_pause else R.drawable.ic_play, if (small) 76.dp else 88.dp, filled = true, onClick = a.onPlayPause)
            RoundButton(R.drawable.ic_next, if (small) 58.dp else 66.dp, filled = false, onClick = a.onNext)
        }
    }
}

@Composable
private fun RoundButton(icon: Int, size: Dp, filled: Boolean, onClick: () -> Unit) {
    val c = CarTheme.colors
    Box(
        Modifier.size(size).clip(CircleShape)
            .background(if (filled) c.accent else c.card)
            .border(1.dp, if (filled) Color.Transparent else c.line, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { LineIcon(icon, size * 0.4f, if (filled) c.onAccent else c.text) }
}

@Composable
private fun Equalizer(playing: Boolean, modifier: Modifier) {
    val t = rememberInfiniteTransition(label = "eq")
    val speeds = intArrayOf(1100, 900, 1300, 1000)
    Row(
        modifier.height(32.dp).clip(RoundedCornerShape(10.dp)).background(Color(0x73000000)).padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        speeds.forEach { ms ->
            val h by t.animateFloat(0.22f, 1f, infiniteRepeatable(tween(ms / 2), RepeatMode.Reverse), label = "b$ms")
            Box(Modifier.width(4.dp).height(18.dp * (if (playing) h else 0.22f)).clip(RoundedCornerShape(2.dp)).background(Color.White))
        }
    }
}

private fun mmss(ms: Long): String {
    val s = (ms / 1000).coerceAtLeast(0)
    return "${s / 60}:${String.format(Locale.US, "%02d", s % 60)}"
}

/* ------------------------------------------------------------------ Mapa */

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MapPage(d: RightData, a: RightActions) {
    val c = CarTheme.colors
    var zoom by remember { mutableIntStateOf(d.initialZoom) }
    val shape = RoundedCornerShape(22.dp)
    Box(Modifier.fillMaxSize().clip(shape).border(1.dp, c.line, shape)) {
        val accent = c.accent.toArgb()
        AndroidView(
            factory = { ctx -> MapTileView(ctx) },
            update = { v ->
                v.darkMap = c.isDark
                v.accent = accent
                v.zoom = zoom
                val f = d.fix
                if (f != null) v.setPosition(f.lat, f.lon, f.bearing, true)
                else v.setPosition(d.fallbackLat, d.fallbackLon, 0f, false)
            },
            onRelease = { it.release() },
            modifier = Modifier.fillMaxSize(),
        )
        // Tocar el mapa abre la app de mapas (la capa no bloquea deslizar de página)
        Box(Modifier.fillMaxSize().clickable(onClick = a.onOpenMaps))

        d.nav?.let { NavBanner(it, Modifier.align(Alignment.TopCenter).padding(10.dp)) { a.onNavBanner(it) } }

        Column(
            Modifier.align(Alignment.CenterEnd).padding(end = 10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            MiniButton("+") { zoom = (zoom + 1).coerceAtMost(18); a.onZoom(zoom) }
            MiniButton("−") { zoom = (zoom - 1).coerceAtLeast(12); a.onZoom(zoom) }
        }

        Row(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MapChip("Casa", R.drawable.ic_mappin, d.dest["destHome"] != null, Modifier.weight(1f),
                onClick = { a.onDest("destHome", "Casa") }, onLong = { a.onDestLong("destHome", "Casa") })
            MapChip("Trabajo", R.drawable.ic_mappin, d.dest["destWork"] != null, Modifier.weight(1f),
                onClick = { a.onDest("destWork", "Trabajo") }, onLong = { a.onDestLong("destWork", "Trabajo") })
            MapChip("Buscar", R.drawable.ic_search, true, Modifier.weight(1f), onClick = a.onOpenMaps, onLong = null)
        }
    }
}

@Composable
private fun NavBanner(n: NavInfo, modifier: Modifier, onClick: () -> Unit) {
    val c = CarTheme.colors
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.card.copy(alpha = 0.95f))
            .border(1.dp, c.line, RoundedCornerShape(18.dp)).clickable(onClick = onClick).padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(c.accent), contentAlignment = Alignment.Center) {
            val icon = n.icon
            if (icon != null) {
                val img = remember(icon) { icon.asImageBitmap() }
                Image(img, contentDescription = null, modifier = Modifier.size(36.dp))
            } else {
                LineIcon(R.drawable.ic_turn, 30.dp, c.onAccent)
            }
        }
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Txt(n.dist, 22, weight = FontWeight.Bold, tabular = true)
            Txt(listOf(n.maneuver, n.street).filter { it.isNotBlank() }.joinToString(" · "), 15, c.muted)
            if (n.eta.isNotBlank()) Txt(n.eta, 14, c.accent)
        }
    }
}

@Composable
private fun MiniButton(text: String, onClick: () -> Unit) {
    val c = CarTheme.colors
    Box(
        Modifier.size(48.dp).clip(CircleShape).background(c.card.copy(alpha = 0.95f)).border(1.dp, c.line, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Txt(text, 26, weight = FontWeight.SemiBold) }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MapChip(label: String, icon: Int, set: Boolean, modifier: Modifier, onClick: () -> Unit, onLong: (() -> Unit)?) {
    val c = CarTheme.colors
    val shape = RoundedCornerShape(24.dp)
    Row(
        modifier.height(48.dp).clip(shape).background(c.card.copy(alpha = 0.95f)).border(1.dp, c.line, shape)
            .combinedClickable(onClick = onClick, onLongClick = onLong),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LineIcon(icon, 18.dp, if (set) c.accent else c.muted)
        Txt(label, 16, c.text, FontWeight.SemiBold, modifier = Modifier.padding(start = 6.dp))
    }
}

/* ------------------------------------------------------------------ Accesos */

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun AppsPage(d: RightData, small: Boolean, a: RightActions) {
    val c = CarTheme.colors
    val cells: List<String?> = d.favs.take(6) + if (d.favs.size < 6) listOf(null) else emptyList()
    val cols = if (small) 2 else 3
    Box(Modifier.fillMaxSize()) {
        val rows = cells.chunked(cols)
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.SpaceEvenly) {
            rows.forEach { row ->
                Row(Modifier.fillMaxWidth()) {
                    row.forEach { pkg ->
                        Column(
                            Modifier.weight(1f).clip(RoundedCornerShape(18.dp))
                                .combinedClickable(
                                    onClick = { if (pkg != null) a.onFav(pkg) else a.onFavAdd() },
                                    onLongClick = pkg?.let { { a.onFavLong(it) } },
                                )
                                .padding(vertical = 10.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            if (pkg != null) {
                                val icon = remember(pkg) { d.apps.icon(pkg) }
                                if (icon != null) Image(icon, contentDescription = null, modifier = Modifier.size(62.dp))
                                else Box(Modifier.size(62.dp).clip(RoundedCornerShape(18.dp)).background(c.pill))
                                Txt(remember(pkg) { d.apps.label(pkg) }, 16, align = TextAlign.Center,
                                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp, start = 4.dp, end = 4.dp))
                            } else {
                                Box(Modifier.size(62.dp).clip(RoundedCornerShape(18.dp)).background(c.pill), contentAlignment = Alignment.Center) {
                                    LineIcon(R.drawable.ic_plus, 28.dp, c.accent)
                                }
                                Txt("Agregar", 16, c.accent, align = TextAlign.Center,
                                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
                            }
                        }
                    }
                    repeat(cols - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            Txt("Mantené apretada una app para cambiarla o quitarla", 14, c.muted, align = TextAlign.Center,
                modifier = Modifier.fillMaxWidth())
        }
    }
}
