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
     * Cómo se mandan los botones:
     *  0 Automático: a la app que está sonando (si publica su sesión); si no, tecla del sistema
 *    (Android la manda a la última app que reprodujo).
     *  1 Tecla del sistema: Android se la da a la última app que reprodujo (sirve para Bluetooth).
     *  2 Directo a la app de "Música" de la barra (para apps Bluetooth que solo escuchan así).
     */
    var mode: Int
        get() = sp.getInt("mediaMode", 0)
        set(v) { sp.edit().putInt("mediaMode", v).apply() }

    /** Por dónde salió el último botón (se ve en el diagnóstico). */
    var lastRoute: String = "—"
        private set

    fun playPause() = send(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE) { c ->
        if (c.playbackState?.state == PlaybackState.STATE_PLAYING) c.transportControls.pause() else c.transportControls.play()
    }
    fun next() = send(KeyEvent.KEYCODE_MEDIA_NEXT) { it.transportControls.skipToNext() }
    fun previous() = send(KeyEvent.KEYCODE_MEDIA_PREVIOUS) { it.transportControls.skipToPrevious() }

    private fun send(code: Int, viaSession: (MediaController) -> Unit) {
        val c = current
        when {
            // Solo si esa app está sonando: si está quieta puede ser una sesión vieja y la música
            // real (por ejemplo Bluetooth) no publica sesión; ahí la tecla del sistema es más segura.
            mode == 0 && c != null && c.playbackState?.state == PlaybackState.STATE_PLAYING -> {
                try { viaSession(c); lastRoute = "sesión de ${appLabel(c.packageName)}" } catch (e: Exception) { systemKey(code) }
            }
            mode == 2 -> appKey(code)
            else -> systemKey(code)
        }
    }

    private fun systemKey(code: Int) {
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
        lastRoute = "tecla del sistema"
    }

    private fun appKey(code: Int) {
        val pkg = sp.getString("slot_music", null)
        if (pkg == null) { systemKey(code); lastRoute = "tecla del sistema (no hay app de Música elegida)"; return }
        try {
            for (action in listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) {
                ctx.sendBroadcast(Intent(Intent.ACTION_MEDIA_BUTTON).setPackage(pkg).putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(action, code)))
            }
            lastRoute = "directo a ${appLabel(pkg)}"
        } catch (e: Exception) { systemKey(code) }
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
            out += "$mark${appLabel(c.packageName)} (${c.packageName}) — $st — acepta: ${can.joinToString().ifEmpty { "nada" }}"
        }
        out += "App de Música de la barra: " + (sp.getString("slot_music", null)?.let { "${appLabel(it)} ($it)" } ?: "sin elegir")
        out += "Último botón enviado por: $lastRoute"
        return out
    }

    /** Posición actual estimada (entre una actualización y otra de la app). */
    companion object {
        fun positionNow(m: Media): Long {
            var pos = m.positionMs
            if (m.playing && m.positionAt > 0) pos += ((SystemClock.elapsedRealtime() - m.positionAt) * m.speed).toLong()
            return if (m.durationMs > 0) pos.coerceIn(0L, m.durationMs) else pos.coerceAtLeast(0L)
        }
    }
}
