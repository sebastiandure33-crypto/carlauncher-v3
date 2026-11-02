package com.rgservice.carlauncher4

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.KeyEvent
import java.io.ByteArrayOutputStream

/**
 * Música de cualquier app (la app Bluetooth de la radio, Spotify, la radio FM si publica sesión…).
 * Envía a Flutter la lista de sesiones activas y recibe los botones.
 *
 * Cómo se mandan los botones (Ajustes › Audio › Modo de botones), igual que en Car Launcher 3:
 *  0 Automático: comando a la sesión de esa app si acepta botones; si no hay sesión, tecla directa a la app.
 *  1 Sesión · comando   2 Sesión · tecla   3 Tecla del sistema   4 Directo a la app
 *  5 Todas las sesiones de la app (radios como com.tw.bt publican varias y solo una obedece).
 */
class MediaHub private constructor(private val ctx: Context) {

    companion object {
        @Volatile private var inst: MediaHub? = null
        fun get(c: Context): MediaHub = inst ?: synchronized(this) {
            inst ?: MediaHub(c.applicationContext).also { inst = it }
        }
    }

    val live = Live()
    private val sp = Prefs.of(ctx)
    private val msm = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val listener = ComponentName(ctx, CarNotificationListener::class.java)
    private val h = Handler(Looper.getMainLooper())
    private var registered = false
    private var lastPkg: String? = null

    private class Reg(val ctrl: MediaController, val cb: MediaController.Callback)
    private val regs = LinkedHashMap<MediaSession.Token, Reg>()

    private val changed = MediaSessionManager.OnActiveSessionsChangedListener { list -> update(list ?: emptyList()) }

    private val loop = object : Runnable {
        override fun run() {
            tick()
            h.postDelayed(this, 3000)
        }
    }

    init { h.post(loop) }

    var mode: Int
        get() = sp.getInt("mediaMode", 0)
        set(v) { sp.edit().putInt("mediaMode", v).apply() }

    fun hasPermission(): Boolean {
        val s = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners") ?: return false
        return s.contains(ctx.packageName)
    }

    fun refresh() { h.post { tick() } }

    private fun tick() {
        if (!registered && hasPermission()) {
            try {
                msm.addOnActiveSessionsChangedListener(changed, listener, h)
                registered = true
            } catch (e: SecurityException) { } catch (e: Exception) { }
        }
        if (registered) update(sessions())
        else live.set(mapOf("perm" to false, "sessions" to emptyList<Any>(), "current" to null))
    }

    private fun sessions(): List<MediaController> =
        try { msm.getActiveSessions(listener) } catch (e: SecurityException) { emptyList() } catch (e: Exception) { emptyList() }

    private fun update(list: List<MediaController>) {
        val tokens = list.map { it.sessionToken }.toSet()
        val gone = regs.keys.filter { it !in tokens }
        gone.forEach { t -> regs.remove(t)?.let { r -> try { r.ctrl.unregisterCallback(r.cb) } catch (e: Exception) { } } }
        val ordered = LinkedHashMap<MediaSession.Token, Reg>()
        list.forEach { c ->
            val old = regs[c.sessionToken]
            if (old != null) {
                ordered[c.sessionToken] = old
            } else {
                val cb = object : MediaController.Callback() {
                    override fun onPlaybackStateChanged(state: PlaybackState?) { push() }
                    override fun onMetadataChanged(metadata: MediaMetadata?) { push() }
                    override fun onSessionDestroyed() { h.post { update(sessions()) } }
                }
                try { c.registerCallback(cb, h) } catch (e: Exception) { }
                ordered[c.sessionToken] = Reg(c, cb)
            }
        }
        regs.clear()
        regs.putAll(ordered)
        push()
    }

    private fun controllers(): List<MediaController> = regs.values.map { it.ctrl }

    private fun playing(c: MediaController) = c.playbackState?.state == PlaybackState.STATE_PLAYING

    private fun current(): MediaController? {
        val list = controllers()
        return list.firstOrNull { playing(it) }
            ?: list.firstOrNull { it.packageName == lastPkg }
            ?: list.firstOrNull()
    }

    /** La sesión de una app (la que suena, si tiene varias). */
    private fun forPkg(pkg: String?): MediaController? {
        if (pkg == null) return current()
        val list = controllers().filter { it.packageName == pkg }
        return list.firstOrNull { playing(it) } ?: list.firstOrNull()
    }

    private fun push() {
        val cur = current()
        if (cur != null && playing(cur)) lastPkg = cur.packageName
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any?>>()
        // una entrada por app (la que suena primero)
        val list = controllers().sortedByDescending { if (playing(it)) 1 else 0 }
        for (c in list) {
            if (!seen.add(c.packageName)) continue
            out.add(describe(c))
        }
        live.set(mapOf("perm" to true, "sessions" to out, "current" to cur?.packageName))
    }

    private fun describe(c: MediaController): Map<String, Any?> {
        val md = c.metadata
        val ps = c.playbackState
        val title = md?.getString(MediaMetadata.METADATA_KEY_TITLE)?.takeIf { it.isNotBlank() }
            ?: md?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
        val artist = md?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: md?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE) ?: ""
        val album = md?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
        val posAtWall = if ((ps?.lastPositionUpdateTime ?: 0L) > 0L)
            System.currentTimeMillis() - (SystemClock.elapsedRealtime() - ps!!.lastPositionUpdateTime) else 0L
        val hasArt = md?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART) != null ||
            md?.getBitmap(MediaMetadata.METADATA_KEY_ART) != null ||
            md?.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON) != null
        return mapOf(
            "pkg" to c.packageName,
            "label" to label(c.packageName),
            "title" to (title ?: ""),
            "artist" to artist,
            "album" to album,
            "playing" to playing(c),
            "pos" to (ps?.position ?: 0L),
            "posAt" to posAtWall,
            "speed" to (ps?.playbackSpeed ?: 1f).toDouble(),
            "dur" to (md?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
            "canSeek" to ((ps?.actions ?: 0L) and PlaybackState.ACTION_SEEK_TO != 0L),
            "artKey" to if (hasArt) "${c.packageName}|${title}|${album}" else null,
        )
    }

    private val labels = HashMap<String, String>()
    fun label(pkg: String): String = labels.getOrPut(pkg) {
        try {
            val pm = ctx.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: Exception) { pkg }
    }

    /** Carátula de la app, en JPEG (o null). */
    fun art(pkg: String?): ByteArray? {
        val c = forPkg(pkg) ?: return null
        val md = c.metadata ?: return null
        val bmp = md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: md.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: md.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON) ?: return null
        return try {
            val max = 512
            val scaled = if (bmp.width > max || bmp.height > max) {
                val s = max.toFloat() / maxOf(bmp.width, bmp.height)
                Bitmap.createScaledBitmap(bmp, (bmp.width * s).toInt().coerceAtLeast(1), (bmp.height * s).toInt().coerceAtLeast(1), true)
            } else bmp
            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 88, out)
            out.toByteArray()
        } catch (e: Exception) { null }
    }

    /* ------------------------------------------------------------ botones */

    fun command(cmd: String, pkg: String?, pos: Long?) {
        val c = forPkg(pkg)
        if (cmd == "seek") {
            try { c?.transportControls?.seekTo(pos ?: 0L) } catch (e: Exception) { }
            return
        }
        val code = when (cmd) {
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
        }
        val target = pkg ?: c?.packageName
        try {
            when (mode) {
                0 -> when {
                    c != null && (c.playbackState?.actions ?: 0L) != 0L -> transport(c, cmd)
                    c == null && target != null -> appKey(code, target)
                    else -> systemKey(code)
                }
                1 -> if (c != null) transport(c, cmd) else systemKey(code)
                2 -> if (c != null) {
                    c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                    c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_UP, code))
                } else systemKey(code)
                3 -> systemKey(code)
                4 -> if (target != null) appKey(code, target) else systemKey(code)
                5 -> {
                    val all = if (target != null) controllers().filter { it.packageName == target } else emptyList()
                    if (all.isEmpty()) systemKey(code) else {
                        val isPlaying = c != null && playing(c)
                        all.forEach { s ->
                            try {
                                if (cmd == "toggle") { if (isPlaying) s.transportControls.pause() else s.transportControls.play() }
                                else transport(s, cmd)
                            } catch (e: Exception) { }
                        }
                    }
                }
                else -> systemKey(code)
            }
        } catch (e: Exception) {
            systemKey(code)
        }
        h.postDelayed({ push() }, 400)
    }

    private fun transport(c: MediaController, cmd: String) {
        val t = c.transportControls
        when (cmd) {
            "next" -> t.skipToNext()
            "prev" -> t.skipToPrevious()
            "play" -> t.play()
            "pause" -> t.pause()
            else -> if (playing(c)) t.pause() else t.play()
        }
    }

    private fun systemKey(code: Int) {
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
    }

    private fun appKey(code: Int, pkg: String) {
        for (action in listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) {
            ctx.sendBroadcast(
                Intent(Intent.ACTION_MEDIA_BUTTON).setPackage(pkg)
                    .putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(action, code)),
            )
        }
    }
}
