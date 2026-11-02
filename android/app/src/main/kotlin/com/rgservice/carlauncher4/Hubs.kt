package com.rgservice.carlauncher4

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import java.util.concurrent.CopyOnWriteArrayList

/** Valor "en vivo" que se reenvía a Flutter por un EventChannel. Guarda el último valor. */
class Live {
    private val listeners = CopyOnWriteArrayList<(Any?) -> Unit>()
    @Volatile var last: Any? = null
        private set

    fun set(v: Any?) {
        last = v
        listeners.forEach { it(v) }
    }

    fun add(l: (Any?) -> Unit) {
        listeners.add(l)
        last?.let { l(it) }
    }

    fun remove(l: (Any?) -> Unit) { listeners.remove(l) }
}

object Prefs {
    const val FILE = "cl4"
    fun of(c: Context): SharedPreferences = c.getSharedPreferences(FILE, Context.MODE_PRIVATE)
}

/** Última lectura del GPS (la escribe TripService). */
object LiveGps {
    val live = Live()
    fun update(speedKmh: Float, lat: Double, lon: Double, bearing: Float) {
        live.set(
            mapOf(
                "speed" to speedKmh.toDouble(),
                "lat" to lat,
                "lon" to lon,
                "bearing" to bearing.toDouble(),
                "at" to System.currentTimeMillis(),
            ),
        )
    }
    fun clear() = live.set(mapOf("off" to true))
}

/** Próximo giro de Maps / Waze (lo escribe CarNotificationListener). */
object LiveNav {
    val live = Live()
    @Volatile var pkg: String? = null
    @Volatile var intent: PendingIntent? = null

    fun set(p: String?, data: Map<String, Any?>?, i: PendingIntent?) {
        pkg = p; intent = i
        live.set(data ?: mapOf("none" to true))
    }

    /** Abre la app de navegación en la pantalla del viaje. */
    fun open(c: Context): Boolean {
        try {
            intent?.send()
            return true
        } catch (e: Exception) { }
        val p = pkg ?: return false
        return try {
            val i = c.packageManager.getLaunchIntentForPackage(p) ?: return false
            c.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) { false }
    }
}
