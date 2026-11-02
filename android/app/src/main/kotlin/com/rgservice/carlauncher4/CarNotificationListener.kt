package com.rgservice.carlauncher4

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Con "Acceso a notificaciones" activado:
 *  1) Android deja leer y controlar la música de cualquier app (MediaSession, ver MediaHub),
 *  2) se lee la notificación de navegación para mostrar el próximo giro en el inicio.
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
        try { MediaHub.get(applicationContext).refresh() } catch (e: Exception) { }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try { handle(sbn) } catch (e: Exception) { }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.packageName == LiveNav.pkg) LiveNav.set(null, null, null)
    }

    override fun onListenerDisconnected() { LiveNav.set(null, null, null) }

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

        var dist = ""
        var maneuver = title
        var street = text
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

        val eta = sub.split('·', '•', '|').map { it.trim() }.filter { it.isNotEmpty() }.take(2).joinToString(" · ")
        LiveNav.set(
            sbn.packageName,
            mapOf(
                "pkg" to sbn.packageName,
                "app" to appName,
                "dist" to dist,
                "maneuver" to maneuver,
                "street" to street,
                "eta" to eta,
            ),
            n.contentIntent,
        )
    }
}
