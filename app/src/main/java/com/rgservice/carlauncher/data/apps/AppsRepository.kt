package com.rgservice.carlauncher.data.apps

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.LruCache
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.core.graphics.drawable.toBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.util.Locale

data class AppEntry(val pkg: String, val label: String)

/** Botón de la barra que abre una app elegible (mantené apretado para cambiarla). */
enum class Slot(val key: String, val label: String, val default: String?) {
    Nav("slot_nav", "Mapas", "com.google.android.apps.maps"),
    Music("slot_music", "Música", null),
    Radio("slot_radio", "Radio", null),
    Phone("slot_phone", "Teléfono", null),
}

/** Apps instaladas, accesos favoritos, botones de la barra y destinos Casa/Trabajo. */
class AppsRepository(private val ctx: Context, private val sp: SharedPreferences) {

    private val pm = ctx.packageManager
    private val icons = LruCache<String, ImageBitmap>(64)

    private val _favs = MutableStateFlow(loadFavs())
    val favs: StateFlow<List<String>> = _favs.asStateFlow()

    private val _slots = MutableStateFlow(loadSlots())
    val slots: StateFlow<Map<Slot, String?>> = _slots.asStateFlow()

    private val _dest = MutableStateFlow(loadDest())
    /** "destHome"/"destWork" → dirección o "lat,lon". */
    val dest: StateFlow<Map<String, String?>> = _dest.asStateFlow()

    fun installed(pkg: String?) = pkg != null && pm.getLaunchIntentForPackage(pkg) != null

    /* ------------------------------------------------ abrir */

    fun launch(pkg: String?): Boolean {
        val i = pkg?.let { pm.getLaunchIntentForPackage(it) } ?: return false
        return try {
            ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)); true
        } catch (e: Exception) { false }
    }

    fun start(i: Intent): Boolean = try { ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true } catch (e: Exception) { false }

    /** Navega con la app de mapas elegida (Google Maps directo; otras por "geo:"). */
    fun navigateTo(dest: String): Boolean {
        val nav = _slots.value[Slot.Nav]
        val gm = "com.google.android.apps.maps"
        val i = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=" + Uri.encode(dest)))
        if (nav == gm && installed(gm)) i.setPackage(gm)
        if (start(i)) return true
        val geo = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(dest)))
        if (nav != null && installed(nav)) geo.setPackage(nav)
        return start(geo) || start(Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(dest))))
    }

    /* ------------------------------------------------ datos de las apps */

    fun label(pkg: String): String = try {
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) { pkg.substringAfterLast('.') }

    fun icon(pkg: String): ImageBitmap? {
        icons.get(pkg)?.let { return it }
        return try {
            pm.getApplicationIcon(pkg).toBitmap(96, 96).asImageBitmap().also { icons.put(pkg, it) }
        } catch (e: Exception) { null }
    }

    suspend fun all(): List<AppEntry> = withContext(Dispatchers.IO) {
        val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        pm.queryIntentActivities(i, 0)
            .map { it.activityInfo.packageName }
            .filter { it != ctx.packageName }
            .distinct()
            .map { AppEntry(it, label(it)) }
            .sortedBy { it.label.lowercase(Locale("es")) }
    }

    /* ------------------------------------------------ barra */

    private fun loadSlots(): Map<Slot, String?> = Slot.entries.associateWith { s ->
        sp.getString(s.key, null) ?: s.default?.takeIf { installed(it) }
    }

    fun setSlot(s: Slot, pkg: String) {
        sp.edit().putString(s.key, pkg).apply()
        _slots.value = loadSlots()
    }

    /* ------------------------------------------------ accesos (hasta 6) */

    private fun loadFavs(): List<String> {
        val s = sp.getString("favs", null)
        if (s == null) {
            val known = listOf(
                "com.google.android.apps.maps", "com.waze", "com.spotify.music",
                "com.google.android.apps.youtube.music", "com.google.android.youtube", "com.whatsapp",
            )
            return known.filter { installed(it) }.take(6)
        }
        return s.split(",").filter { it.isNotBlank() && installed(it) }
    }

    private fun saveFavs(l: List<String>) {
        sp.edit().putString("favs", l.distinct().take(6).joinToString(",")).apply()
        _favs.value = loadFavs()
    }

    fun addFav(pkg: String) = saveFavs(_favs.value + pkg)
    fun removeFav(pkg: String) = saveFavs(_favs.value - pkg)
    fun replaceFav(old: String, pkg: String) = saveFavs(_favs.value.map { if (it == old) pkg else it })

    /* ------------------------------------------------ Casa / Trabajo */

    private fun loadDest() = mapOf("destHome" to sp.getString("destHome", null), "destWork" to sp.getString("destWork", null))

    fun setDest(key: String, v: String?) {
        if (v.isNullOrBlank()) sp.edit().remove(key).apply() else sp.edit().putString(key, v.trim()).apply()
        _dest.value = loadDest()
    }
}
