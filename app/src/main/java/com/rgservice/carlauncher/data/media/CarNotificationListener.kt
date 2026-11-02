package com.rgservice.carlauncher.data.media

import android.app.Notification
import android.app.PendingIntent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Próximo giro que muestra Maps / Waze en su notificación. */
data class NavInfo(
    val pkg: String,
    val appName: String,
    val dist: String,
    val maneuver: String,
    val street: String,
    val eta: String,
    val icon: Bitmap?,
    val intent: PendingIntent?,
)

object LiveNav {
    private val _nav = MutableStateFlow<NavInfo?>(null)
    val nav: StateFlow<NavInfo?> = _nav.asStateFlow()
    internal fun set(n: NavInfo?) { _nav.value = n }
}

/**
 * Con "Acceso a notificaciones" activado:
 *  1) Android deja leer y controlar la música de cualquier app (MediaSession),
 *  2) se lee la notificación de navegación para mostrar el próximo giro en la página Mapa.
 */
class CarNotificationListener : NotificationListenerService() {

    companion object {
        val NAV_PKGS = setOf(
            "com.google.android.apps.maps", "com.waze", "com.here.app.maps",
            "net.osmand", "net.osmand.plus", "com.sygic.aura", "ru.yandex.yandexnavi",
        )
        private val DIST = Regex("""(\d+(?:[.,]\d+)?)\s?(km|m|mi|ft|yd)\b""", RegexOption.IGNORE_CASE)
        private val TRIM = charArrayOf(' ', '·', '-', '–', ',', '•')
    }

    override fun onListenerConnected() {
        try { activeNotifications?.forEach { handle(it) } } catch (e: Exception) { }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try { handle(sbn) } catch (e: Exception) { }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.packageName == LiveNav.nav.value?.pkg) LiveNav.set(null)
    }

    override fun onListenerDisconnected() { LiveNav.set(null) }

    private fun handle(sbn: StatusBarNotification) {
        if (sbn.packageName !in NAV_PKGS) return
        val n = sbn.notification
        if (n.flags and Notification.FLAG_ONGOING_EVENT == 0) return
        val ex = n.extras
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = ex.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        val sub = (ex.getCharSequence(Notification.EXTRA_SUB_TEXT)
            ?: ex.getCharSequence(Notification.EXTRA_INFO_TEXT))?.toString()?.trim().orEmpty()
        if (title.isEmpty() && text.isEmpty()) return

        // Distancia al próximo giro: primero en el título, después al principio del texto
        var dist = ""; var maneuver = title; var street = text
        val inTitle = DIST.find(title)
        if (inTitle != null) {
            dist = inTitle.value
            maneuver = title.removeRange(inTitle.range).trim(*TRIM)
        } else {
            val inText = DIST.find(text)
            if (inText != null && inText.range.first == 0) {
                dist = inText.value
                street = text.removeRange(inText.range).trim(*TRIM)
            }
        }
        if (dist.isEmpty()) { dist = title; maneuver = "" }

        val appName = try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(sbn.packageName, 0)).toString()
        } catch (e: Exception) { "Navegación" }

        LiveNav.set(
            NavInfo(
                pkg = sbn.packageName,
                appName = appName,
                dist = dist,
                maneuver = maneuver,
                street = street,
                eta = sub.split('·', '•', '|').map { it.trim() }.filter { it.isNotEmpty() }.take(2).joinToString(" · "),
                icon = try { n.getLargeIcon()?.loadDrawable(this)?.let { toBitmap(it) } } catch (e: Exception) { null },
                intent = n.contentIntent,
            ),
        )
    }

    private fun toBitmap(d: Drawable): Bitmap? {
        if (d is BitmapDrawable && d.bitmap != null) return d.bitmap
        val w = if (d.intrinsicWidth > 0) d.intrinsicWidth else 96
        val h = if (d.intrinsicHeight > 0) d.intrinsicHeight else 96
        val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, w, h)
        d.draw(Canvas(b))
        return b
    }
}
