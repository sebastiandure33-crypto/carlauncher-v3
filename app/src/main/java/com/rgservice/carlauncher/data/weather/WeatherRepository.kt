package com.rgservice.carlauncher.data.weather

import android.content.SharedPreferences
import com.rgservice.carlauncher.data.Prefs
import com.rgservice.carlauncher.data.Weather
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.roundToInt

/**
 * Clima de Open-Meteo (gratis, sin clave). Se guarda el último en memoria:
 * sin internet se muestra ese, con la aclaración "hace 2 h".
 */
class WeatherRepository(private val sp: SharedPreferences) {

    private companion object {
        const val REFRESH_MS = 15 * 60 * 1000L
        const val RETRY_MS = 2 * 60 * 1000L
        const val SHOW_AGE_AFTER_MS = 30 * 60 * 1000L
    }

    /** Emite el clima al empezar y lo renueva solo mientras la pantalla esté visible. */
    fun updates(): Flow<Weather?> = flow {
        while (true) {
            val age = System.currentTimeMillis() - sp.getLong("wxAt", 0L)
            if (age in 0 until REFRESH_MS) {
                emit(cached())
                delay(REFRESH_MS - age)
                continue
            }
            val fresh = fetch()
            if (fresh != null) {
                emit(fresh)
                delay(REFRESH_MS)
            } else {
                emit(cached())
                delay(RETRY_MS)
            }
        }
    }.flowOn(Dispatchers.IO)

    private fun fetch(): Weather? = try {
        val u = "https://api.open-meteo.com/v1/forecast?latitude=${Prefs.lat(sp)}&longitude=${Prefs.lon(sp)}" +
            "&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m" +
            "&daily=temperature_2m_max,temperature_2m_min&timezone=auto"
        val c = URL(u).openConnection() as HttpURLConnection
        c.connectTimeout = 8000; c.readTimeout = 8000
        val text = try { c.inputStream.bufferedReader().readText() } finally { c.disconnect() }
        val j = JSONObject(text)
        val cur = j.getJSONObject("current")
        val d = j.getJSONObject("daily")
        val code = cur.getInt("weather_code")
        val o = JSONObject()
            .put("temp", cur.getDouble("temperature_2m").roundToInt())
            .put("code", code)
            .put("max", d.getJSONArray("temperature_2m_max").getDouble(0).roundToInt())
            .put("min", d.getJSONArray("temperature_2m_min").getDouble(0).roundToInt())
            .put("hum", cur.getInt("relative_humidity_2m"))
            .put("wind", cur.getDouble("wind_speed_10m").roundToInt())
        sp.edit().putString("wx", o.toString()).putLong("wxAt", System.currentTimeMillis()).apply()
        parse(o, null)
    } catch (e: Exception) { null }

    fun cached(): Weather? {
        val s = sp.getString("wx", null) ?: return null
        return try {
            val age = System.currentTimeMillis() - sp.getLong("wxAt", 0L)
            val mins = age / 60000
            val ago = when {
                age < SHOW_AGE_AFTER_MS -> null
                mins < 60 -> "hace $mins min"
                mins < 48 * 60 -> "hace ${mins / 60} h"
                else -> "hace ${mins / 1440} días"
            }
            parse(JSONObject(s), ago)
        } catch (e: Exception) { null }
    }

    private fun parse(o: JSONObject, ago: String?) = Weather(
        tempC = o.getInt("temp"),
        description = describe(o.getInt("code")),
        maxC = o.getInt("max"),
        minC = o.getInt("min"),
        humidity = o.getInt("hum"),
        windKmh = o.getInt("wind"),
        code = o.getInt("code"),
        updatedAgo = ago,
    )

    private fun describe(c: Int) = when {
        c == 0 -> "Despejado"
        c <= 2 -> "Parcialmente nublado"
        c == 3 -> "Nublado"
        c == 45 || c == 48 -> "Niebla"
        c in 51..67 -> "Lluvia"
        c in 71..77 -> "Nieve"
        c in 80..82 -> "Chubascos"
        c >= 95 -> "Tormenta"
        else -> "Variable"
    }
}
