package com.rgservice.carlauncher.data

import android.content.Context
import android.content.SharedPreferences

/** Un solo archivo de preferencias para toda la app. */
object Prefs {
    const val FILE = "cl3"
    // Ubicación por defecto (zona de Asunción) hasta que el GPS dé la primera posición
    const val DEFAULT_LAT = -25.35
    const val DEFAULT_LON = -57.45

    fun of(c: Context): SharedPreferences = c.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun lat(sp: SharedPreferences) = sp.getString("lat", null)?.toDoubleOrNull() ?: DEFAULT_LAT
    fun lon(sp: SharedPreferences) = sp.getString("lon", null)?.toDoubleOrNull() ?: DEFAULT_LON
}
