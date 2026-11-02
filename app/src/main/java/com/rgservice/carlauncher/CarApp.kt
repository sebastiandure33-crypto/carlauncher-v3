package com.rgservice.carlauncher

import android.app.Application
import com.rgservice.carlauncher.data.Prefs

/**
 * Red de seguridad: si la app se cierra por un error varias veces seguidas (por ejemplo
 * siendo la pantalla de inicio), la próxima vez abre el selector de pantalla de inicio de
 * Android para poder volver al launcher original.
 */
class CarApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val prev = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            try {
                val sp = Prefs.of(this)
                val now = System.currentTimeMillis()
                val recent = (sp.getString("crashes", "") ?: "").split(",")
                    .mapNotNull { it.toLongOrNull() }.filter { now - it < 120_000 }
                sp.edit().putString("crashes", (recent + now).joinToString(","))
                    .putString("lastCrash", e.toString().take(300)).commit()
            } catch (x: Exception) { }
            prev?.uncaughtException(t, e)
        }
    }

    companion object {
        /** ¿Hubo 3 o más cierres por error en los últimos 2 minutos? (y limpia el contador) */
        fun tooManyCrashes(app: Application): Boolean {
            val sp = Prefs.of(app)
            val now = System.currentTimeMillis()
            val n = (sp.getString("crashes", "") ?: "").split(",").mapNotNull { it.toLongOrNull() }.count { now - it < 120_000 }
            if (n >= 3) { sp.edit().remove("crashes").apply(); return true }
            return false
        }
    }
}
