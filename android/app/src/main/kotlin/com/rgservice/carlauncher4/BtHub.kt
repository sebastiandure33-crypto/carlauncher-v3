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
    private var a2dp: BluetoothProfile? = null
    private var hfp: BluetoothProfile? = null

    private val rx = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) { schedule() }
    }

    init {
        val sl = object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                if (profile == BluetoothProfile.A2DP) a2dp = proxy else hfp = proxy
                schedule()
            }
            override fun onServiceDisconnected(profile: Int) {
                if (profile == BluetoothProfile.A2DP) a2dp = null else hfp = null
                schedule()
            }
        }
        try { adapter?.getProfileProxy(ctx, sl, BluetoothProfile.A2DP) } catch (e: Exception) { }
        try { adapter?.getProfileProxy(ctx, sl, BluetoothProfile.HEADSET) } catch (e: Exception) { }
        try {
            ctx.registerReceiver(rx, IntentFilter().apply {
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
                addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
                addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
                addAction("android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED")
                addAction("android.bluetooth.headset.profile.action.CONNECTION_STATE_CHANGED")
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
        val audio = devices(a2dp)
        val calls = devices(hfp)
        val d = audio.firstOrNull() ?: calls.firstOrNull()
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

    private fun devices(p: BluetoothProfile?): List<BluetoothDevice> =
        try { p?.connectedDevices ?: emptyList() } catch (e: Exception) { emptyList() }
}
