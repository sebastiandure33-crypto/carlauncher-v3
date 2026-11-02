package com.rgservice.carlauncher.data.location

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import com.rgservice.carlauncher.data.Prefs

/**
 * Servicio en primer plano que lee la antena GPS (funciona sin internet):
 *  - velocidad en vivo,
 *  - viaje actual (km, tiempo en movimiento, promedio),
 *  - suma los km recorridos al odómetro del tablero que cargaste.
 *
 * Cuidado con la radio: al sacar el contacto (pantalla apagada) suelta el GPS para que
 * pueda entrar en reposo, y al volver espera 3 s a que termine de despertar.
 */
class TripService : Service(), LocationListener {

    companion object {
        /** 20 min sin moverse = el próximo movimiento empieza un viaje nuevo. */
        const val NEW_TRIP_AFTER_MS = 20 * 60 * 1000L

        private var lastOpen = 0L

        /**
         * Al dar contacto trae el launcher al frente (opción "Abrir al dar contacto").
         * Lo permite Android 10 porque el servicio de notificaciones está activo o porque
         * se dio el permiso "Mostrar sobre otras apps".
         */
        fun openLauncher(c: Context) {
            if (!Prefs.of(c).getBoolean("ignOpen", true)) return
            val now = System.currentTimeMillis()
            if (now - lastOpen < 10_000) return
            lastOpen = now
            try {
                val i = c.packageManager.getLaunchIntentForPackage(c.packageName) ?: return
                c.startActivity(
                    i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        .putExtra("ign", true),
                )
            } catch (e: Exception) { }
        }

        fun start(c: Context) {
            if (c.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
            try { c.startForegroundService(Intent(c, TripService::class.java)) } catch (e: Exception) { }
        }
    }

    private lateinit var sp: SharedPreferences
    private var last: Location? = null
    private var gpsOn = false
    private var lastLatSave = 0L
    private val h = Handler(Looper.getMainLooper())
    private var wakeTask: Runnable? = null

    private val screenRx = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            when (i.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    wakeTask?.let { h.removeCallbacks(it) }; wakeTask = null
                    stopGps()
                }
                Intent.ACTION_SCREEN_ON -> {
                    wakeTask?.let { h.removeCallbacks(it) }
                    // Espera 3 s a que la radio termine de despertar antes de usar GPS o abrir algo
                    val r = Runnable {
                        if ((getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive) {
                            startGps()
                            openLauncher(c)
                        }
                    }
                    wakeTask = r
                    h.postDelayed(r, 3000)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        sp = Prefs.of(this)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(NotificationChannel("trip", "Recorrido", NotificationManager.IMPORTANCE_LOW))
        val n = Notification.Builder(this, "trip")
            .setContentTitle("Car Launcher")
            .setContentText("Registrando recorrido por GPS")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .build()
        startForeground(1, n)
        try {
            registerReceiver(screenRx, IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON); addAction(Intent.ACTION_SCREEN_OFF)
            })
        } catch (e: Exception) { }
        startGps()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // por si el permiso se dio después (solo con la pantalla prendida)
        if ((getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive) startGps()
        return START_STICKY
    }

    private fun startGps() {
        if (gpsOn) return
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
        try {
            (getSystemService(Context.LOCATION_SERVICE) as LocationManager)
                .requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, this, Looper.getMainLooper())
            gpsOn = true
        } catch (e: Exception) { }
    }

    private fun stopGps() {
        try { (getSystemService(Context.LOCATION_SERVICE) as LocationManager).removeUpdates(this) } catch (e: Exception) { }
        gpsOn = false
        last = null
        LiveGps.clear()
    }

    override fun onDestroy() {
        wakeTask?.let { h.removeCallbacks(it) }
        try { unregisterReceiver(screenRx) } catch (e: Exception) { }
        stopGps()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onLocationChanged(l: Location) {
        if (l.hasAccuracy() && l.accuracy > 40f) return // descarta lecturas imprecisas
        val prev = last
        last = l
        val now = System.currentTimeMillis()
        val ed = sp.edit()
        var dirty = false

        // Ubicación para clima y modo noche: como mucho una vez por minuto
        if (now - lastLatSave > 60_000L) {
            lastLatSave = now
            ed.putString("lat", l.latitude.toString()).putString("lon", l.longitude.toString())
            dirty = true
        }

        var speed = if (l.hasSpeed()) l.speed else 0f // m/s
        if (prev != null) {
            val d = prev.distanceTo(l)
            val dtMs = l.time - prev.time
            if (!l.hasSpeed() && dtMs > 0) speed = d / (dtMs / 1000f)
            // Solo cuenta si realmente se mueve (> ~5 km/h) y sin saltos raros
            if (speed > 1.5f && d < 500f) {
                var tripM = sp.getFloat("tripM", 0f)
                var tripMove = sp.getLong("tripMoveMs", 0L)
                if (now - sp.getLong("lastMove", 0L) > NEW_TRIP_AFTER_MS) {
                    tripM = 0f; tripMove = 0L
                    ed.putLong("tripStart", now)
                }
                tripM += d
                tripMove += dtMs.coerceIn(0L, 10_000L)
                ed.putFloat("tripM", tripM).putLong("tripMoveMs", tripMove).putLong("lastMove", now)
                val odo = sp.getFloat("odoKm", -1f)
                if (odo >= 0f) ed.putFloat("odoKm", odo + d / 1000f)
                dirty = true
            }
        }
        if (speed < 0.8f) speed = 0f // parado: evita que "baile" 1-2 km/h
        LiveGps.update(GpsFix(speed * 3.6f, l.latitude, l.longitude, if (l.hasBearing()) l.bearing else 0f, now))
        if (dirty) ed.apply()
    }

    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
}

/** Al prender la radio arranca el GPS (el launcher se abre solo por ser la pantalla de inicio). */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (i.action == Intent.ACTION_BOOT_COMPLETED) TripService.start(c)
    }
}
