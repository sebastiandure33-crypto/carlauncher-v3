package com.rgservice.carlauncher.ui.home

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.rgservice.carlauncher.core.UiSize
import com.rgservice.carlauncher.data.CarRepository
import com.rgservice.carlauncher.data.HomeState
import com.rgservice.carlauncher.data.Media
import com.rgservice.carlauncher.data.apps.AppsRepository
import com.rgservice.carlauncher.data.maint.MaintSnapshot
import com.rgservice.carlauncher.data.media.MediaRepository
import com.rgservice.carlauncher.data.Prefs
import com.rgservice.carlauncher.data.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn

/** Datos reales para la pantalla de inicio + preferencias de la interfaz. */
class HomeViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = Prefs.of(app)
    val repo = CarRepository(prefs)
    val music = MediaRepository(app, prefs)
    val apps = AppsRepository(app, prefs)

    /** Música: solo escucha mientras la pantalla está visible. */
    val media: StateFlow<Media> = music.updates()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), Media(hasPermission = music.hasPermission()))

    val maint: StateFlow<MaintSnapshot> = repo.maintenance()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), MaintSnapshot())

    /** Último ítem elegido en Mantenimiento ("km:oil", "date:ins"…). */
    var maintSel: String? = null

    fun setSize(s: UiSize) {
        _size.value = s
        prefs.edit().putInt("size", s.ordinal).apply()
    }

    fun setStats(on: Boolean) {
        _showStats.value = on
        prefs.edit().putBoolean("stats", on).apply()
    }

    var welcomeOn: Boolean
        get() = prefs.getBoolean("welcome", true)
        set(v) { prefs.edit().putBoolean("welcome", v).apply() }
    var ignitionOpen: Boolean
        get() = prefs.getBoolean("ignOpen", true)
        set(v) { prefs.edit().putBoolean("ignOpen", v).apply() }

    val initialPage: Int get() = prefs.getInt("page", 0)
    val mapZoom: Int get() = prefs.getInt("mapZoom", 16)
    fun savePage(p: Int) = prefs.edit().putInt("page", p).apply()
    fun saveZoom(z: Int) = prefs.edit().putInt("mapZoom", z).apply()
    fun lastLat() = Prefs.lat(prefs)
    fun lastLon() = Prefs.lon(prefs)

    private val _size = MutableStateFlow(UiSize.entries[prefs.getInt("size", 0).coerceIn(0, UiSize.entries.size - 1)])
    private val _showStats = MutableStateFlow(prefs.getBoolean("stats", false))

    val size: StateFlow<UiSize> = _size.asStateFlow()
    val showStats: StateFlow<Boolean> = _showStats.asStateFlow()

    // Mientras la pantalla no se ve (contacto apagado, otra app) deja de calcular a los 5 s.
    val state: StateFlow<HomeState> = repo.states()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), repo.initial())

    /** Modo noche: Auto (por el sol) → Noche → Día → Auto. Devuelve el nuevo. */
    fun cycleTheme(): ThemeMode {
        val next = ThemeMode.entries[(repo.themeMode().ordinal + 1) % ThemeMode.entries.size]
        repo.setTheme(next)
        return next
    }

    /** Etapa 1-2: el botón Tamaño va pasando por los tamaños (en la etapa 4 pasa a Ajustes). */
    fun nextSize() {
        val next = UiSize.entries[(_size.value.ordinal + 1) % UiSize.entries.size]
        _size.value = next
        prefs.edit().putInt("size", next.ordinal).apply()
    }

    fun toggleStats() {
        _showStats.value = !_showStats.value
        prefs.edit().putBoolean("stats", _showStats.value).apply()
    }
}
