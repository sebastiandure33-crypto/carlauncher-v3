package com.rgservice.carlauncher.data.location

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Última lectura del GPS. La escribe TripService y la lee la pantalla (mismo proceso). */
data class GpsFix(val speedKmh: Float, val lat: Double, val lon: Double, val bearing: Float, val atMs: Long)

object LiveGps {
    /** Pasado este tiempo sin lecturas se considera "Sin GPS" (túnel, techo, antena). */
    const val STALE_MS = 8_000L

    private val _fix = MutableStateFlow<GpsFix?>(null)
    val fix: StateFlow<GpsFix?> = _fix.asStateFlow()

    fun update(f: GpsFix) { _fix.value = f }
    fun clear() { _fix.value = null }
}
