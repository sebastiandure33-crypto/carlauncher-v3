package com.rgservice.carlauncher.data

import android.content.SharedPreferences
import com.rgservice.carlauncher.data.location.GpsFix
import com.rgservice.carlauncher.data.location.LiveGps
import com.rgservice.carlauncher.data.location.TripService
import com.rgservice.carlauncher.data.maint.MaintSnapshot
import com.rgservice.carlauncher.data.maint.Maintenance
import com.rgservice.carlauncher.data.weather.WeatherRepository
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.onStart
import kotlin.math.roundToInt

/**
 * Junta todo lo real en un solo estado para la pantalla:
 * GPS en vivo + lo guardado (viaje, tablero, mantenimiento, nombre) + clima + hora.
 */
class CarRepository(private val sp: SharedPreferences) {

    val maint = Maintenance(sp)
    private val weather = WeatherRepository(sp)

    /** Avisa cada vez que cambia algo guardado (el servicio de GPS escribe ahí). */
    private fun prefChanges(): Flow<Unit> = callbackFlow {
        val l = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> trySend(Unit) }
        sp.registerOnSharedPreferenceChangeListener(l)
        awaitClose { sp.unregisterOnSharedPreferenceChangeListener(l) }
    }.onStart { emit(Unit) }

    /** Pulso cada 2 s: detecta GPS perdido y cambia el modo noche a la hora justa. */
    private val ticker: Flow<Long> = flow {
        while (true) { emit(System.currentTimeMillis()); delay(2000) }
    }

    fun states(): Flow<HomeState> =
        combine(LiveGps.fix, prefChanges(), weather.updates().onStart { emit(weather.cached()) }, ticker) { fix, _, wx, now ->
            build(fix, wx, now)
        }

    /** Estado inicial (sin esperar nada) para que el primer cuadro ya tenga el tema correcto. */
    fun initial(): HomeState = build(null, weather.cached(), System.currentTimeMillis())

    private fun build(fix: GpsFix?, wx: Weather?, now: Long): HomeState {
        val live = fix?.takeIf { now - it.atMs < LiveGps.STALE_MS }
        val mode = themeMode()
        return HomeState(
            name = sp.getString("name", null)?.takeIf { it.isNotBlank() } ?: "conductor",
            gpsOk = live != null,
            speedKmh = live?.speedKmh?.roundToInt(),
            speedLimit = sp.getInt("limit", 80),
            trip = trip(),
            weather = wx,
            odoKm = maint.odo(),
            oil = maint.gauge("oil"),
            gear = maint.gauge("gear"),
            maintWarnings = maint.snapshot().warnings,
            dark = isDark(mode, now),
            theme = mode,
        )
    }

    /** Mantenimiento completo; se recalcula cuando cambia algo guardado (y cada minuto por las fechas). */
    fun maintenance(): Flow<MaintSnapshot> =
        combine(prefChanges(), flow { while (true) { emit(Unit); delay(60_000) } }) { _, _ -> maint.snapshot() }

    private fun trip(): Trip {
        val km = sp.getFloat("tripM", 0f) / 1000.0
        val moveMs = sp.getLong("tripMoveMs", 0L)
        val hours = moveMs / 3_600_000.0
        val avg = if (hours > 0.01) (km / hours).roundToInt() else 0
        return Trip(km, (moveMs / 60_000L).toInt(), avg)
    }

    fun themeMode(): ThemeMode =
        ThemeMode.entries.getOrNull(sp.getInt("theme", 0)) ?: ThemeMode.Auto

    private fun isDark(mode: ThemeMode, now: Long) = when (mode) {
        ThemeMode.Night -> true
        ThemeMode.Day -> false
        ThemeMode.Auto -> Sun.isNight(Prefs.lat(sp), Prefs.lon(sp), now)
    }

    /* ------------------------------------------------ cambios que pide el usuario */

    fun setName(v: String) = sp.edit().putString("name", v.trim()).apply()
    fun setLimit(v: Int) = sp.edit().putInt("limit", v).apply()
    fun setTheme(m: ThemeMode) = sp.edit().putInt("theme", m.ordinal).apply()

    /** Pone el viaje en cero a mano. */
    fun resetTrip() = sp.edit().putFloat("tripM", 0f).putLong("tripMoveMs", 0L)
        .putLong("lastMove", System.currentTimeMillis() - TripService.NEW_TRIP_AFTER_MS - 1).apply()
}
