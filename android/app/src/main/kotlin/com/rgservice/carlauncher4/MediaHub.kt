package com.rgservice.carlauncher4

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.browse.MediaBrowser
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

    /* ---------------------------------------------- Bluetooth del sistema (AVRCP) */

    /** App Bluetooth elegida en el launcher (ej. com.tw.bt): sus botones se mandan por AVRCP si existe. */
    @Volatile var btApp: String? = null
    @Volatile private var btCtrl: MediaController? = null
    private var btBrowser: MediaBrowser? = null
    private var btTried = 0L
    private var btState = "sin probar"

    /** Servicio con el que Android controla la música del teléfono cuando la radio es receptora. */
    private val btServices = listOf(
        ComponentName("com.android.bluetooth", "com.android.bluetooth.avrcpcontroller.BluetoothMediaBrowserService"),
        ComponentName("com.android.bluetooth", "com.android.bluetooth.a2dpsink.mbs.A2dpMediaBrowserService"),
    )

    private fun exists(c: ComponentName) = try { ctx.packageManager.getServiceInfo(c, 0); true } catch (e: Exception) { false }

    private fun connectBt() {
        if (btBrowser != null || System.currentTimeMillis() - btTried < 30_000L) return
        btTried = System.currentTimeMillis()
        val comp = btServices.firstOrNull { exists(it) }
        if (comp == null) { btState = "no existe en esta radio"; return }
        var b: MediaBrowser? = null
        b = MediaBrowser(ctx, comp, object : MediaBrowser.ConnectionCallback() {
            override fun onConnected() {
                try {
                    val c = MediaController(ctx, b!!.sessionToken)
                    c.registerCallback(object : MediaController.Callback() {
                        override fun onPlaybackStateChanged(state: PlaybackState?) { push() }
                        override fun onMetadataChanged(metadata: MediaMetadata?) { push() }
                        override fun onSessionDestroyed() { btCtrl = null; btBrowser = null; push() }
                    }, h)
                    btCtrl = c
                    btState = "conectado (${comp.className.substringAfterLast('.')})"
                } catch (e: Exception) { btState = "error: ${e.message}" }
                push()
            }
            override fun onConnectionFailed() { btBrowser = null; btCtrl = null; btState = "no acepta la conexión" }
            override fun onConnectionSuspended() { btBrowser = null; btCtrl = null; btState = "desconectado"; push() }
        }, null)
        btBrowser = b
        try { b!!.connect() } catch (e: Exception) { btBrowser = null; btState = "error: ${e.message}" }
    }

    private fun btAlias(pkg: String?) = btCtrl != null && pkg != null && (pkg == btApp || pkg == "com.android.bluetooth")

    var mode: Int
        get() = sp.getInt("mediaMode", 0)
        set(v) { sp.edit().putInt("mediaMode", v).apply() }

    fun hasPermission(): Boolean {
        val s = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners") ?: return false
        return s.contains(ctx.packageName)
    }

    fun refresh() { h.post { tick() } }

    private fun tick() {
        connectBt()
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
        if (btAlias(pkg)) return btCtrl
        if (pkg == null) return btCtrl?.takeIf { playing(it) } ?: current()
        val list = controllers().filter { it.packageName == pkg }
        return list.firstOrNull { playing(it) } ?: list.firstOrNull()
    }

    private fun push() {
        val cur = current()
        if (cur != null && playing(cur)) lastPkg = cur.packageName
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any?>>()
        var currentPkg = cur?.packageName
        // la música del teléfono por AVRCP reemplaza a las sesiones vacías de la app Bluetooth
        val bt = btCtrl
        if (bt != null) {
            val alias = btApp ?: "com.android.bluetooth"
            out.add(describe(bt) + mapOf("pkg" to alias, "label" to "Bluetooth"))
            seen.add(alias)
            seen.add(bt.packageName)
            if (playing(bt) || cur == null || cur.packageName == alias) currentPkg = alias
        }
        // una entrada por app (la que suena primero)
        val list = controllers().sortedByDescending { if (playing(it)) 1 else 0 }
        for (c in list) {
            if (!seen.add(c.packageName)) continue
            out.add(describe(c))
        }
        live.set(mapOf("perm" to true, "sessions" to out, "current" to currentPkg))
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

    /** Por dónde salió el último botón (se ve en el diagnóstico). */
    @Volatile var lastRoute: String = "—"
        private set

    /* ---------------------------------------------- órdenes propias de la app (elegidas en el diagnóstico) */

    private fun actKey(pkg: String, cmd: String) = "act_${pkg}_" + (if (cmd == "play" || cmd == "pause") "toggle" else cmd)

    fun customAction(pkg: String?, cmd: String): String? =
        if (pkg == null) null else sp.getString(actKey(pkg, cmd), null)?.takeIf { it.isNotBlank() }

    fun setCustomAction(pkg: String, cmd: String, action: String?) {
        if (action == null) sp.edit().remove(actKey(pkg, cmd)).apply() else sp.edit().putString(actKey(pkg, cmd), action).apply()
    }

    fun customActions(pkg: String): Map<String, String?> =
        mapOf("toggle" to customAction(pkg, "toggle"), "next" to customAction(pkg, "next"), "prev" to customAction(pkg, "prev"))

    /** Manda una orden como aviso general (la reciben los receptores que la app registró al abrirse). */
    fun sendAction(action: String, pkg: String?) {
        try { ctx.sendBroadcast(Intent(action)) } catch (e: Exception) { }
        lastRoute = "orden $action" + (pkg?.let { " (${label(it)})" } ?: "")
    }

    fun command(cmd: String, pkg: String?, pos: Long?, forceMode: Int? = null) {
        val c = forPkg(pkg)
        val mode = forceMode ?: this.mode
        val custom = customAction(pkg ?: btApp, cmd)
        if (cmd != "seek" && custom != null && (mode == 0 || mode == 7)) {
            sendAction(custom, pkg ?: btApp)
            h.postDelayed({ push() }, 400)
            return
        }
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
                    c != null && (c.playbackState?.actions ?: 0L) != 0L -> { transport(c, cmd); lastRoute = "sesión de ${label(c.packageName)} (automático)" }
                    c == null && target != null -> appKey(code, target)
                    else -> systemKey(code)
                }
                1 -> if (c != null) { transport(c, cmd); lastRoute = "sesión de ${label(c.packageName)} · comando" } else systemKey(code)
                2 -> if (c != null) {
                    c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                    c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_UP, code))
                    lastRoute = "sesión de ${label(c.packageName)} · tecla"
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
                        lastRoute = "${all.size} sesiones de ${label(target!!)}"
                    }
                }
                6 -> musicCommand(cmd, target)
                7 -> systemKey(code) // sin órdenes elegidas para esta app
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
        lastRoute = "tecla del sistema"
    }

    private fun appKey(code: Int, pkg: String) {
        for (action in listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) {
            ctx.sendBroadcast(
                Intent(Intent.ACTION_MEDIA_BUTTON).setPackage(pkg)
                    .putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(action, code)),
            )
        }
        lastRoute = "directo a ${label(pkg)}"
    }

    private val modeNames = listOf("Automático", "Sesión · comando", "Sesión · tecla", "Tecla del sistema", "Directo a la app", "Todas las sesiones", "Orden de música clásica", "Órdenes elegidas de la app")

    /** La orden "musicservicecommand" que escuchan muchas apps de música de radios chinas. */
    private fun musicCommand(cmd: String, pkg: String?) {
        val c = when (cmd) { "next" -> "next"; "prev" -> "previous"; "play" -> "play"; "pause" -> "pause"; else -> "togglepause" }
        val intents = listOf(
            Intent("com.android.music.musicservicecommand").putExtra("command", c),
            Intent("com.android.music.musicservicecommand.$c"),
        )
        for (i in intents) {
            try { ctx.sendBroadcast(Intent(i)) } catch (e: Exception) { }
            if (pkg != null) try { ctx.sendBroadcast(Intent(i).setPackage(pkg)) } catch (e: Exception) { }
        }
        lastRoute = "orden de música clásica ($c)" + (pkg?.let { " a ${label(it)}" } ?: "")
    }

    fun diagnostics(): List<String> {
        val out = ArrayList<String>()
        out += "Permiso de música: " + if (hasPermission()) "sí" else "NO (activalo en Acceso a notificaciones)"
        val list = sessions()
        out += "Bluetooth del sistema (AVRCP): $btState"
        btCtrl?.let { c ->
            val t = c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "sin título"
            out += "· AVRCP: ${if (playing(c)) "sonando" else "en pausa"} — \"$t\""
        }
        out += "Sesiones de música: ${list.size}"
        val byPkg = list.groupBy { it.packageName }
        byPkg.forEach { (pkg, group) ->
            if (group.size <= 2) return@forEach
            val sonando = group.count { playing(it) }
            val sinBotones = group.count { (it.playbackState?.actions ?: 0L) == 0L }
            out += "· ${label(pkg)} ($pkg): ${group.size} sesiones, $sonando sonando, $sinBotones no aceptan botones"
        }
        list.filter { (byPkg[it.packageName]?.size ?: 0) <= 2 }.forEach { c ->
            val ps = c.playbackState
            val st = when (ps?.state) {
                PlaybackState.STATE_PLAYING -> "sonando"
                PlaybackState.STATE_PAUSED -> "en pausa"
                PlaybackState.STATE_STOPPED -> "detenida"
                PlaybackState.STATE_NONE, null -> "sin estado"
                else -> "estado ${ps.state}"
            }
            val acts = ps?.actions ?: 0L
            val can = buildList {
                if (acts and PlaybackState.ACTION_PLAY_PAUSE != 0L || acts and PlaybackState.ACTION_PLAY != 0L) add("play")
                if (acts and PlaybackState.ACTION_PAUSE != 0L) add("pausa")
                if (acts and PlaybackState.ACTION_SKIP_TO_NEXT != 0L) add("siguiente")
                if (acts and PlaybackState.ACTION_SKIP_TO_PREVIOUS != 0L) add("anterior")
            }
            val title = c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)?.take(30) ?: "sin título"
            out += "· ${label(c.packageName)} (${c.packageName}) — $st — acepta: ${can.joinToString().ifEmpty { "nada" }} — \"$title\""
        }
        out += "Modo de botones: ${mode + 1}. ${modeNames.getOrElse(mode) { "?" }} · último botón por: $lastRoute"
        return out
    }
}
