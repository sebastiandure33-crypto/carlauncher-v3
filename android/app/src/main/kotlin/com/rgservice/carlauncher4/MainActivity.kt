package com.rgservice.carlauncher4

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.AudioManager
import android.media.audiofx.AudioEffect
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Puente entre Flutter (la pantalla) y Android (GPS, música, apps, Bluetooth, volumen, brillo). */
class MainActivity : FlutterActivity() {

    private val main = Handler(Looper.getMainLooper())
    private var permResult: MethodChannel.Result? = null
    private lateinit var media: MediaHub
    private lateinit var bt: BtHub

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        TripService.start(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        media = MediaHub.get(applicationContext)
        bt = BtHub.get(applicationContext)
        val m = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(m, "cl4/native").setMethodCallHandler { call, res ->
            try {
                handle(call.method, call.arguments as? Map<*, *>, res)
            } catch (e: Exception) {
                res.error("ERR", e.message, null)
            }
        }
        stream(m, "cl4/gps", LiveGps.live)
        stream(m, "cl4/nav", LiveNav.live)
        stream(m, "cl4/media", media.live)
        stream(m, "cl4/bt", bt.live)
    }

    private fun stream(m: BinaryMessenger, name: String, live: Live) {
        EventChannel(m, name).setStreamHandler(object : EventChannel.StreamHandler {
            private var l: ((Any?) -> Unit)? = null
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val f: (Any?) -> Unit = { v -> main.post { try { events.success(v) } catch (e: Exception) { } } }
                l = f
                live.add(f)
            }
            override fun onCancel(arguments: Any?) {
                l?.let { live.remove(it) }
                l = null
            }
        })
    }

    private fun bg(res: MethodChannel.Result, work: () -> Any?) {
        Thread {
            val v = try { work() } catch (e: Exception) { null }
            main.post { res.success(v) }
        }.start()
    }

    private fun hasLocation() = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun handle(method: String, args: Map<*, *>?, res: MethodChannel.Result) {
        val a: Map<*, *> = args ?: emptyMap<Any, Any>()
        when (method) {
            "hasLocation" -> res.success(hasLocation())
            "requestLocation" -> {
                if (hasLocation()) {
                    TripService.start(this); res.success(true)
                } else {
                    permResult = res
                    requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 7)
                }
            }
            "trip" -> res.success(TripService.snapshot(this))
            "setOdo" -> { TripService.setOdo(this, (a["km"] as Number).toDouble()); res.success(null) }
            "resetTrip" -> { TripService.resetTrip(this); res.success(null) }
            "hasNotifAccess" -> res.success(media.hasPermission())
            "canWriteSettings" -> res.success(Settings.System.canWrite(this))
            "canOverlay" -> res.success(Settings.canDrawOverlays(this))
            "isDefaultHome" -> {
                val r = packageManager.resolveActivity(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), PackageManager.MATCH_DEFAULT_ONLY,
                )
                res.success(r?.activityInfo?.packageName == packageName)
            }
            "apps" -> bg(res) { apps() }
            "appIcon" -> bg(res) { icon(a["pkg"] as String) }
            "appLabel" -> res.success(media.label(a["pkg"] as String))
            "launch" -> res.success(launch(a["pkg"] as String?))
            "open" -> res.success(open(a["what"] as String))
            "navigate" -> res.success(
                navigate((a["lat"] as Number).toDouble(), (a["lon"] as Number).toDouble(), a["pkg"] as String?),
            )
            "openNav" -> res.success(LiveNav.open(this))
            "media" -> {
                media.command(a["cmd"] as String, a["pkg"] as String?, (a["pos"] as? Number)?.toLong())
                res.success(null)
            }
            "mediaArt" -> bg(res) { media.art(a["pkg"] as String?) }
            "mediaRefresh" -> { media.refresh(); res.success(null) }
            "setMediaMode" -> { media.mode = (a["mode"] as Number).toInt(); res.success(null) }
            "volume" -> {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                res.success(mapOf("cur" to am.getStreamVolume(AudioManager.STREAM_MUSIC), "max" to am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)))
            }
            "setVolume" -> {
                // FLAG_SHOW_UI: en muchas radios el cambio pasa por el panel de volumen del fabricante
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val v = (a["v"] as Number).toInt()
                try { am.setStreamVolume(AudioManager.STREAM_MUSIC, v, AudioManager.FLAG_SHOW_UI) } catch (e: Exception) { }
                res.success(am.getStreamVolume(AudioManager.STREAM_MUSIC))
            }
            "volumeStep" -> {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val dir = if ((a["dir"] as Number).toInt() > 0) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
                try { am.adjustStreamVolume(AudioManager.STREAM_MUSIC, dir, AudioManager.FLAG_SHOW_UI) } catch (e: Exception) { }
                main.postDelayed({
                    res.success(mapOf("cur" to am.getStreamVolume(AudioManager.STREAM_MUSIC), "max" to am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)))
                }, 150)
            }
            "brightness" -> res.success(
                try { Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS) } catch (e: Exception) { -1 },
            )
            "setBrightness" -> res.success(setBrightness((a["v"] as Number).toInt().coerceIn(5, 255)))
            "launchReturn" -> res.success(launchReturn(a["pkg"] as String?, (a["delay"] as? Number)?.toLong() ?: 2000L))
            "diag" -> {
                @Suppress("UNCHECKED_CAST")
                val pkgs = (a["pkgs"] as? List<String>) ?: emptyList()
                bg(res) { diagnostics(pkgs) }
            }
            "mediaTest" -> {
                media.command(a["cmd"] as String, a["pkg"] as String?, null, (a["mode"] as Number).toInt())
                res.success(media.lastRoute)
            }
            "watch" -> {
                @Suppress("UNCHECKED_CAST")
                CarNotificationListener.watch = ((a["pkgs"] as? List<String>) ?: emptyList()).toSet()
                media.btApp = a["music"] as? String
                res.success(null)
            }
            "btInfo" -> res.success(bt.info())
            "wifiInfo" -> {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                val info = try { wm.connectionInfo } catch (e: Exception) { null }
                @Suppress("DEPRECATION")
                val ssid = info?.ssid?.trim('"')?.takeIf { it.isNotBlank() && it != "<unknown ssid>" }
                @Suppress("DEPRECATION")
                val connected = (info?.networkId ?: -1) != -1
                res.success(mapOf("on" to wm.isWifiEnabled, "connected" to connected, "ssid" to ssid))
            }
            "filesDir" -> res.success(filesDir.absolutePath)
            "setIgnOpen" -> { Prefs.of(this).edit().putBoolean("ignOpen", a["v"] as Boolean).apply(); res.success(null) }
            else -> res.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7) {
            val ok = hasLocation()
            if (ok) TripService.start(this)
            permResult?.success(ok)
            permResult = null
        }
    }

    /* ------------------------------------------------------------ apps */

    private fun apps(): List<Map<String, String>> {
        val pm = packageManager
        val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val list = pm.queryIntentActivities(i, 0)
        val seen = HashSet<String>()
        return list.mapNotNull { r ->
            val p = r.activityInfo.packageName
            if (p == packageName || !seen.add(p)) null
            else mapOf("pkg" to p, "label" to r.loadLabel(pm).toString())
        }.sortedBy { it["label"]!!.lowercase() }
    }

    private fun icon(pkg: String): ByteArray? {
        val d = packageManager.getApplicationIcon(pkg)
        val size = 128
        val b = toBitmap(d, size)
        val out = ByteArrayOutputStream()
        b.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    private fun toBitmap(d: Drawable, size: Int): Bitmap {
        if (d is BitmapDrawable && d.bitmap != null) return Bitmap.createScaledBitmap(d.bitmap, size, size, true)
        val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, size, size)
        d.draw(Canvas(b))
        return b
    }

    private fun launch(pkg: String?): Boolean {
        if (pkg.isNullOrEmpty()) return false
        return try {
            val i = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) { false }
    }

    /**
     * Brillo: si hay permiso cambia el de todo el sistema (y la ventana sigue al sistema);
     * si no, cambia al menos el de esta pantalla. Devuelve "system", "window" o "none".
     */
    private fun setBrightness(v: Int): String {
        var mode = "window"
        if (Settings.System.canWrite(this)) {
            try {
                Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
                Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, v)
                mode = "system"
            } catch (e: Exception) { }
        }
        return try {
            val lp = window.attributes
            lp.screenBrightness = if (mode == "system") WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE else v / 255f
            window.attributes = lp
            mode
        } catch (e: Exception) { if (mode == "system") mode else "none" }
    }

    /**
     * Abre una app (radio, música Bluetooth) para que empiece a sonar y a los [delay] ms
     * vuelve al launcher, así el audio sigue de fondo sin perder la pantalla de inicio.
     */
    private fun launchReturn(pkg: String?, delay: Long): Boolean {
        if (!launch(pkg)) return false
        main.postDelayed({
            try {
                val back = Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                startActivity(back)
            } catch (e: Exception) { }
        }, delay.coerceIn(500L, 8000L))
        return true
    }

    private fun diagnostics(pkgs: List<String>): List<String> {
        val out = ArrayList<String>()
        out += "— Música —"
        out += media.diagnostics()
        out += "Servicios de música navegables: " + VendorProbe.browsers(this).joinToString()
        out += "— Bluetooth —"
        val b = bt.info()
        out += "Teléfono visto por Android: " + ((b["name"] as? String) ?: "ninguno (puede ser un módulo Bluetooth propio de la radio)")
        out += bt.diagnostics()
        out += "Aviso de la app Bluetooth: " + ((b["appText"] as? String)?.takeIf { it.isNotBlank() } ?: "ninguno")
        out += "Apps vigiladas: " + CarNotificationListener.watch.joinToString().ifEmpty { "ninguna" }
        out += "— Volumen y brillo —"
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        out += "Volumen música: ${am.getStreamVolume(AudioManager.STREAM_MUSIC)} de ${am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)}"
        out += "Permiso de brillo: " + if (Settings.System.canWrite(this)) "sí" else "NO (solo cambia esta pantalla)"
        out += "Brillo del sistema: " + try { Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS) } catch (e: Exception) { "?" }
        out += "Android ${Build.VERSION.RELEASE} · ${Build.MANUFACTURER} ${Build.MODEL} · ${Build.DISPLAY}"
        out += "— Ajustes del Bluetooth de la radio —"
        out += VendorProbe.settings(this)
        for (p in pkgs.distinct()) {
            out += "— Órdenes que acepta ${media.label(p)} ($p) —"
            out += VendorProbe.actions(this, p)
        }
        return out
    }

    private fun start(i: Intent): Boolean = try {
        startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true
    } catch (e: Exception) { false }

    private fun open(what: String): Boolean = when (what) {
        "bt" -> start(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
        "wifi" -> start(Intent(Settings.ACTION_WIFI_SETTINGS))
        "android" -> start(Intent(Settings.ACTION_SETTINGS))
        "home" -> start(Intent(Settings.ACTION_HOME_SETTINGS)) || start(Intent(Settings.ACTION_SETTINGS))
        "notif" -> start(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
        "write" -> start(Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:$packageName")))
        "overlay" -> start(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
        "location" -> start(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
        "appInfo" -> start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        "eq" -> start(
            Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL)
                .putExtra(AudioEffect.EXTRA_AUDIO_SESSION, 0)
                .putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                .putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC),
        )
        else -> false
    }

    /** Navegar a un destino con la app elegida (Maps por defecto, Waze si es la elegida). */
    private fun navigate(lat: Double, lon: Double, pkg: String?): Boolean {
        if (pkg == "com.waze") {
            if (start(Intent(Intent.ACTION_VIEW, Uri.parse("https://waze.com/ul?ll=$lat,$lon&navigate=yes")).setPackage("com.waze"))) return true
        }
        val g = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=$lat,$lon"))
        g.setPackage(pkg ?: "com.google.android.apps.maps")
        if (start(g)) return true
        return start(Intent(Intent.ACTION_VIEW, Uri.parse("geo:$lat,$lon?q=$lat,$lon")))
    }
}
