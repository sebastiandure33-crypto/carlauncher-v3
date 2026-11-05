package com.rgservice.carlauncher4

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import org.xmlpull.v1.XmlPullParser

/**
 * Para el diagnóstico: qué órdenes acepta la app Bluetooth / radio del fabricante.
 * Lee su AndroidManifest (público para cualquier app) y lista las acciones de sus
 * receptores y servicios, que es por donde suelen recibir play / siguiente.
 */
object VendorProbe {
    private const val NS = "http://schemas.android.com/apk/res/android"

    fun actions(c: Context, pkg: String, max: Int = 60): List<String> {
        val pc = try { c.createPackageContext(pkg, 0) } catch (e: Exception) { return listOf("$pkg: no instalada") }
        val am = pc.assets
        for (cookie in 1..12) {
            val p = try { am.openXmlResourceParser(cookie, "AndroidManifest.xml") } catch (e: Exception) { continue }
            try {
                val out = ArrayList<String>()
                var isThis = false
                var comp = ""
                var kind = ""
                var ev = p.eventType
                while (ev != XmlPullParser.END_DOCUMENT) {
                    if (ev == XmlPullParser.START_TAG) {
                        when (p.name) {
                            "manifest" -> isThis = p.getAttributeValue(null, "package") == pkg
                            "receiver", "service", "activity", "provider" -> {
                                kind = p.name
                                comp = (p.getAttributeValue(NS, "name") ?: "?").substringAfterLast('.')
                            }
                            "action" -> {
                                val a = p.getAttributeValue(NS, "name") ?: ""
                                if (kind != "activity" && a.isNotEmpty()) out += "$kind $comp ← $a"
                            }
                        }
                        if (p.name == "manifest" && !isThis) break
                    }
                    ev = p.next()
                }
                if (isThis) return if (out.isEmpty()) listOf("$pkg: sin receptores ni servicios") else out.distinct().take(max)
            } catch (e: Exception) {
            } finally {
                p.close()
            }
        }
        return listOf("$pkg: no se pudo leer el manifiesto")
    }

    /** Servicios de música navegables (MediaBrowserService) instalados. */
    fun browsers(c: Context): List<String> = try {
        @Suppress("DEPRECATION")
        c.packageManager.queryIntentServices(Intent("android.media.browse.MediaBrowserService"), PackageManager.GET_RESOLVED_FILTER)
            .map { "${it.serviceInfo.packageName}/${it.serviceInfo.name.substringAfterLast('.')}" }
            .ifEmpty { listOf("ninguno") }
    } catch (e: Exception) { listOf("error: ${e.message}") }

    /** Ajustes del sistema que parecen del Bluetooth de la radio (nombre del teléfono, estado). */
    fun settings(c: Context): List<String> {
        val out = ArrayList<String>()
        for ((name, uri) in listOf("system" to Settings.System.CONTENT_URI, "global" to Settings.Global.CONTENT_URI)) {
            try {
                c.contentResolver.query(uri, arrayOf("name", "value"), null, null, null)?.use { cur ->
                    while (cur.moveToNext()) {
                        val k = cur.getString(0) ?: continue
                        val v = cur.getString(1) ?: ""
                        if (Regex("bt|blue|phone|a2dp|avrcp|tw_", RegexOption.IGNORE_CASE).containsMatchIn(k)) out += "$name.$k = ${v.take(40)}"
                    }
                }
            } catch (e: Exception) { }
        }
        return out.take(30).ifEmpty { listOf("ninguno") }
    }
}

/**
 * Busca, dentro del código de la app (classes.dex), textos que parecen órdenes (intent actions)
 * de música: las apps de estas radios las registran mientras corren y no figuran en el manifiesto.
 */
object DexProbe {
    private val RUN = Regex("""[A-Za-z][A-Za-z0-9_.]{7,90}""")
    private val ACTIONISH = Regex("""^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+){2,}$""")
    private val KEYS = Regex("next|prev|play|pause|music|media|key|ctrl|control|cmd|command|bt|blue|seek|tune|radio|fm|vol|mode|source", RegexOption.IGNORE_CASE)
    private val CLASSY = Regex("(Activity|Service|Receiver|Fragment|View|Adapter|Manager|Helper|Utils?|Impl|Listener|Callback|Provider|Exception|Dialog|Layout|Holder|Binder|Stub|Proxy|Interface)$")

    fun candidates(c: Context, pkg: String, max: Int = 120): List<String> {
        val ai = try { c.packageManager.getApplicationInfo(pkg, 0) } catch (e: Exception) { return emptyList() }
        val found = LinkedHashSet<String>()
        try {
            java.util.zip.ZipFile(ai.sourceDir).use { z ->
                val dexes = z.entries().toList().filter { it.name.matches(Regex("classes\\d*\\.dex")) }
                for (e in dexes) {
                    val bytes = z.getInputStream(e).use { it.readBytes() }
                    val text = String(bytes, Charsets.ISO_8859_1)
                    for (m in RUN.findAll(text)) {
                        var s = m.value
                        // en el dex cada texto va precedido por su largo (1 byte), que a veces es una letra
                        if (s.isNotEmpty() && s[0].code == s.length - 1) s = s.substring(1)
                        s = s.trimEnd('.')
                        if (!ACTIONISH.matches(s)) continue
                        val last = s.substringAfterLast('.')
                        if (CLASSY.containsMatchIn(last)) continue
                        if (s.startsWith("java.") || s.startsWith("javax.") || s.startsWith("kotlin.") || s.startsWith("androidx.")) continue
                        if (s.startsWith("android.") && !s.contains("MEDIA_BUTTON") && !s.contains("musicservicecommand")) continue
                        if (!KEYS.containsMatchIn(s)) continue
                        // las órdenes suelen terminar en MAYÚSCULAS o tener "action"
                        if (!(last == last.uppercase() || s.contains("action", true) || s.contains("cmd", true) || s.contains("command", true))) continue
                        found.add(s)
                        if (found.size >= max) return found.toList()
                    }
                }
            }
        } catch (e: Exception) { }
        return found.toList()
    }
}
