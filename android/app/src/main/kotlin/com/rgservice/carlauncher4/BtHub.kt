package com.rgservice.carlauncher4

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper

/**
 * Teléfono conectado por Bluetooth (nombre, audio, llamadas y batería si el teléfono la informa).
 * Algunas radios usan su propio Bluetooth (app com.tw.bt y similares) y Android no lo ve:
 * en ese caso se muestra "Bluetooth de la radio" y el botón abre su app.
 */
class BtHub private constructor(private val ctx: Context) {

    companion object {
        @Volatile private var inst: BtHub? = null
        fun get(c: Context): BtHub = inst ?: synchronized(this) {
            inst ?: BtHub(c.applicationContext).also { inst = it }
        }
    }

    val live = Live()
    private val h = Handler(Looper.getMainLooper())
    @Suppress("DEPRECATION")
    private val adapter: BluetoothAdapter? = try { BluetoothAdapter.getDefaultAdapter() } catch (e: Exception) { null }
    // En una radio el teléfono "manda" el audio: la radio es A2DP_SINK (11) y HEADSET_CLIENT (16),
    // no A2DP / HEADSET como un parlante. Se consultan los cuatro.
    private val proxies = HashMap<Int, BluetoothProfile>()
    private val A2DP_SINK = 11
    private val HEADSET_CLIENT = 16

    private val rx = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) { schedule() }
    }

    init {
        val sl = object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                proxies[profile] = proxy
                schedule()
            }
            override fun onServiceDisconnected(profile: Int) {
                proxies.remove(profile)
                schedule()
            }
        }
        for (p in listOf(BluetoothProfile.A2DP, BluetoothProfile.HEADSET, A2DP_SINK, HEADSET_CLIENT)) {
            try { adapter?.getProfileProxy(ctx, sl, p) } catch (e: Exception) { }
        }
        try {
            ctx.registerReceiver(rx, IntentFilter().apply {
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
                addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
                addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
                addAction("android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED")
                addAction("android.bluetooth.headset.profile.action.CONNECTION_STATE_CHANGED")
                addAction("android.bluetooth.a2dp-sink.profile.action.CONNECTION_STATE_CHANGED")
                addAction("android.bluetooth.headsetclient.profile.action.CONNECTION_STATE_CHANGED")
                addAction("android.bluetooth.device.action.BATTERY_LEVEL_CHANGED")
            })
        } catch (e: Exception) { }
        schedule()
    }

    @Volatile private var appPkg: String? = null
    @Volatile private var appText: String? = null

    /** Texto del aviso de la app Bluetooth de la radio (ej.: "Conectado a Galaxy de Seba"). */
    fun appStatus(pkg: String, text: String?) {
        if (text == null && pkg != appPkg) return
        appPkg = pkg
        appText = text
        schedule()
    }

    private val pushTask = Runnable { live.set(info()) }
    private fun schedule() {
        h.removeCallbacks(pushTask)
        h.postDelayed(pushTask, 500)
    }

    fun info(): Map<String, Any?> {
        val on = try { adapter?.isEnabled == true } catch (e: Exception) { false }
        val audio = devices(proxies[BluetoothProfile.A2DP]) + devices(proxies[A2DP_SINK])
        val calls = devices(proxies[BluetoothProfile.HEADSET]) + devices(proxies[HEADSET_CLIENT])
        val d = audio.firstOrNull() ?: calls.firstOrNull() ?: connectedBonded().firstOrNull()
        val name = try { d?.name } catch (e: Exception) { null }
        val battery = try {
            if (d == null) -1 else (d.javaClass.getMethod("getBatteryLevel").invoke(d) as? Int) ?: -1
        } catch (e: Exception) { -1 }
        return mapOf(
            "available" to (adapter != null),
            "on" to on,
            "name" to name,
            "audio" to (d != null && audio.any { it.address == d.address }),
            "calls" to (d != null && calls.any { it.address == d.address }),
            "battery" to battery,
            "appPkg" to appPkg,
            "appText" to appText,
        )
    }

    /** Vinculados que Android marca como conectados (sirve aunque el perfil no se pueda consultar). */
    private fun connectedBonded(): List<BluetoothDevice> = try {
        (adapter?.bondedDevices ?: emptySet()).filter { d ->
            try { d.javaClass.getMethod("isConnected").invoke(d) as? Boolean == true } catch (e: Exception) { false }
        }
    } catch (e: Exception) { emptyList() }

    /** Texto para el diagnóstico. */
    fun diagnostics(): List<String> {
        val out = ArrayList<String>()
        if (adapter == null) { out += "Android no tiene Bluetooth propio (lo maneja un módulo de la radio)"; return out }
        out += "Bluetooth de Android: " + if (try { adapter.isEnabled } catch (e: Exception) { false }) "prendido" else "apagado"
        val names = mapOf(BluetoothProfile.A2DP to "A2DP", BluetoothProfile.HEADSET to "Manos libres", A2DP_SINK to "A2DP receptor", HEADSET_CLIENT to "Manos libres (auto)")
        names.forEach { (p, n) ->
            val px = proxies[p]
            out += "· $n: " + when {
                px == null -> "no disponible"
                else -> devices(px).joinToString { safeName(it) }.ifEmpty { "nada conectado" }
            }
        }
        val bonded = try { adapter.bondedDevices ?: emptySet() } catch (e: Exception) { emptySet() }
        out += "Vinculados: " + bonded.joinToString { safeName(it) + (if (connectedBonded().any { c -> c.address == it.address }) " (conectado)" else "") }.ifEmpty { "ninguno" }
        return out
    }

    private fun safeName(d: BluetoothDevice) = try { d.name ?: d.address } catch (e: Exception) { "?" }

    private fun devices(p: BluetoothProfile?): List<BluetoothDevice> =
        try { p?.connectedDevices ?: emptyList() } catch (e: Exception) { emptyList() }
}
