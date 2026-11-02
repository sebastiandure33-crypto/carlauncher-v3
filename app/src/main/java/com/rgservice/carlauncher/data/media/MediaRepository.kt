package com.rgservice.carlauncher.data.media

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.KeyEvent
import com.rgservice.carlauncher.data.Media
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Música de cualquier app (Spotify, YouTube Music, la música Bluetooth de la radio…).
 *  - Si la app publica su sesión: título, artista, carátula, progreso y controles reales.
 *  - Si no (algunas apps Bluetooth de radios chinas): igual se controla con las teclas
 *    multimedia, enviadas a la app elegida en el botón "Música" de la barra.
 */
class MediaRepository(private val ctx: Context, private val sp: SharedPreferences) {

    private val msm = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val listener = ComponentName(ctx, CarNotificationListener::class.java)
    private var current: MediaController? = null

    fun hasPermission(): Boolean {
        val s = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners") ?: return false
        return s.contains(ctx.packageName)
    }

    fun updates(): Flow<Media> = callbackFlow {
        val h = Handler(Looper.getMainLooper())
        var ctrl: MediaController? = null
        var registered = false

        var repick: () -> Unit = {}
        fun push() { trySend(build(ctrl)) }

        val cb = object : MediaController.Callback() {
            override fun onPlaybackStateChanged(state: PlaybackState?) {
                // si esta se pausó y otra está sonando, pasa a la otra
                if (state?.state != PlaybackState.STATE_PLAYING) repick() else push()
            }
            override fun onMetadataChanged(metadata: MediaMetadata?) = push()
            override fun onSessionDestroyed() = repick()
        }

        fun choose(list: List<MediaController>): MediaController? =
            list.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
                ?: list.firstOrNull { it.sessionToken == ctrl?.sessionToken }
                ?: list.firstOrNull()

        fun pickFrom(list: List<MediaController>) {
            val next = choose(list)
            if (next?.sessionToken != ctrl?.sessionToken) {
                ctrl?.unregisterCallback(cb)
                ctrl = next
                current = next
                next?.registerCallback(cb, h)
            }
            push()
        }

        fun sessions(): List<MediaController> =
            try { msm.getActiveSessions(listener) } catch (e: SecurityException) { emptyList() }

        repick = { pickFrom(sessions()) }

        val changed = MediaSessionManager.OnActiveSessionsChangedListener { list -> pickFrom(list ?: emptyList()) }

        val loop = launch {
            while (isActive) {
                if (!registered && hasPermission()) {
                    try {
                        msm.addOnActiveSessionsChangedListener(changed, listener, h)
                        registered = true
                    } catch (e: SecurityException) { }
                }
                if (registered) pickFrom(sessions()) else trySend(Media(hasPermission = false))
                delay(3000)
            }
        }
        awaitClose {
            loop.cancel()
            ctrl?.unregisterCallback(cb)
            current = null
            if (registered) try { msm.removeOnActiveSessionsChangedListener(changed) } catch (e: Exception) { }
        }
    }

    private fun build(c: MediaController?): Media {
        if (c == null) return Media(hasPermission = true)
        val md = c.metadata
        val ps = c.playbackState
        val label = appLabel(c.packageName)
        val title = md?.getString(MediaMetadata.METADATA_KEY_TITLE)?.takeIf { it.isNotBlank() }
        return Media(
            source = label,
            title = title ?: if (ps?.state == PlaybackState.STATE_PLAYING) "Reproduciendo" else "En pausa",
            artist = md?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: md?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: "",
            playing = ps?.state == PlaybackState.STATE_PLAYING,
            positionMs = ps?.position ?: 0L,
            positionAt = ps?.lastPositionUpdateTime ?: 0L,
            speed = ps?.playbackSpeed ?: 1f,
            durationMs = md?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L,
            art = md?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: md?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: md?.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON),
            pkg = c.packageName,
            hasPermission = true,
            hasSession = true,
        )
    }

    private fun appLabel(pkg: String): String = try {
        val pm = ctx.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) { "Música" }

    /* ------------------------------------------------------------ controles */

    /**
     * Cómo se mandan los botones (se elige en el diagnóstico de música):
     *  0 Automático: comando a la sesión que suena si declara que acepta botones; si no, tecla del sistema.
     *  1 Sesión · comando: transportControls de la sesión que suena (sin importar lo que declare).
     *  2 Sesión · tecla: KeyEvent multimedia directo a esa sesión (dispatchMediaButtonEvent).
     *  3 Tecla del sistema: AudioManager.dispatchMediaKeyEvent (Android elige la app).
     *  4 Directo a la app: broadcast ACTION_MEDIA_BUTTON al paquete que suena (o al de "Música").
     *  5 Todas las sesiones de la app: comando a cada sesión de ese paquete (algunas radios, como
     *    la app Bluetooth com.tw.bt, publican varias y solo una obedece). Play/pausa es seguro
     *    (pause/play explícitos); siguiente/anterior podría saltar dos si obedecen dos.
     */
    var mode: Int
        get() = sp.getInt("mediaMode", 0)
        set(v) { sp.edit().putInt("mediaMode", v).apply() }

    companion object Routes {
        val NAMES = listOf("Automático", "Sesión · comando", "Sesión · tecla", "Tecla del sistema", "Directo a la app", "Todas las sesiones")

        /** Posición actual estimada (entre una actualización y otra de la app). */
        fun positionNow(m: Media): Long {
            var pos = m.positionMs
            if (m.playing && m.positionAt > 0) pos += ((SystemClock.elapsedRealtime() - m.positionAt) * m.speed).toLong()
            return if (m.durationMs > 0) pos.coerceIn(0L, m.durationMs) else pos.coerceAtLeast(0L)
        }
    }

    /** Por dónde salió el último botón (se ve en el diagnóstico). */
    var lastRoute: String = "—"
        private set

    private enum class Cmd(val code: Int) {
        PlayPause(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE), Next(KeyEvent.KEYCODE_MEDIA_NEXT), Prev(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
    }

    fun playPause() = send(Cmd.PlayPause)
    fun next() = send(Cmd.Next)
    fun previous() = send(Cmd.Prev)

    private fun sessions(): List<MediaController> =
        try { msm.getActiveSessions(listener) } catch (e: SecurityException) { emptyList() }

    private fun command(c: MediaController, cmd: Cmd) {
        val t = c.transportControls
        when (cmd) {
            Cmd.PlayPause -> if (c.playbackState?.state == PlaybackState.STATE_PLAYING) t.pause() else t.play()
            Cmd.Next -> t.skipToNext()
            Cmd.Prev -> t.skipToPrevious()
        }
    }

    private fun send(cmd: Cmd) {
        val c = current
        val label = c?.let { appLabel(it.packageName) } ?: ""
        try {
            when (mode) {
                0 -> if (c != null && c.playbackState?.state == PlaybackState.STATE_PLAYING && (c.playbackState?.actions ?: 0L) != 0L) {
                    command(c, cmd); lastRoute = "sesión de $label (automático)"
                } else systemKey(cmd.code)
                1 -> if (c != null) { command(c, cmd); lastRoute = "sesión de $label · comando" } else systemKey(cmd.code)
                2 -> if (c != null) {
                    c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_DOWN, cmd.code))
                    c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_UP, cmd.code))
                    lastRoute = "sesión de $label · tecla"
                } else systemKey(cmd.code)
                3 -> systemKey(cmd.code)
                4 -> appKey(cmd.code, c?.packageName ?: sp.getString("slot_music", null))
                5 -> {
                    val pkg = c?.packageName
                    val all = if (pkg != null) sessions().filter { it.packageName == pkg } else emptyList()
                    if (all.isEmpty()) systemKey(cmd.code)
                    else {
                        val playing = c?.playbackState?.state == PlaybackState.STATE_PLAYING
                        all.forEach { s ->
                            try {
                                when (cmd) {
                                    Cmd.PlayPause -> if (playing) s.transportControls.pause() else s.transportControls.play()
                                    else -> command(s, cmd)
                                }
                            } catch (e: Exception) { }
                        }
                        lastRoute = "${all.size} sesiones de $label"
                    }
                }
                else -> systemKey(cmd.code)
            }
        } catch (e: Exception) {
            systemKey(cmd.code)
        }
    }

    private fun systemKey(code: Int) {
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
        lastRoute = "tecla del sistema"
    }

    private fun appKey(code: Int, pkg: String?) {
        if (pkg == null) { systemKey(code); lastRoute = "tecla del sistema (no hay app)"; return }
        for (action in listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) {
            ctx.sendBroadcast(Intent(Intent.ACTION_MEDIA_BUTTON).setPackage(pkg).putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(action, code)))
        }
        lastRoute = "directo a ${appLabel(pkg)} ($pkg)"
    }

    /** Abre la app que está sonando (o la elegida para Música). */
    fun openPlayingApp(): String? = current?.packageName ?: sp.getString("slot_music", null)

    /** Texto para el diagnóstico de música. */
    fun diagnostics(): List<String> {
        val out = ArrayList<String>()
        out += "Permiso de música: " + if (hasPermission()) "sí" else "NO (activalo en Ajustes)"
        val list = try { msm.getActiveSessions(listener) } catch (e: SecurityException) { emptyList() }
        out += "Apps con sesión de música: ${list.size}"
        list.forEach { c ->
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
            val mark = if (c.sessionToken == current?.sessionToken) "▶ " else "· "
            val title = c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)?.take(24) ?: "sin título"
            out += "$mark${appLabel(c.packageName)} (${c.packageName}) — $st — acepta: ${can.joinToString().ifEmpty { "nada" }} — \"$title\""
        }
        out += "App de Música de la barra: " + (sp.getString("slot_music", null)?.let { "${appLabel(it)} ($it)" } ?: "sin elegir")
        out += "Modo: ${mode + 1}. ${NAMES.getOrElse(mode) { "?" }} · último botón por: $lastRoute"
        return out
    }

}
