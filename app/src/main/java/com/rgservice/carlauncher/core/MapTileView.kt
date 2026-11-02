package com.rgservice.carlauncher.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.LruCache
import android.view.View
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Mapa chico con tu posición (calles de OpenStreetMap).
 * Las calles se descargan solo con internet y quedan guardadas en la radio:
 * después se ven sin conexión. La posición sale de la antena GPS.
 * No toma toques: los maneja Compose por encima (así se puede deslizar de página).
 */
class MapTileView(ctx: Context) : View(ctx) {

    var zoom = 16
        set(v) { field = v.coerceIn(12, 18); invalidate() }
    var darkMap = false
        set(v) { if (field != v) { field = v; tilePaint.colorFilter = if (v) darkFilter else null; invalidate() } }
    var accent = 0xFF6FB1FF.toInt()
        set(v) { if (field != v) { field = v; invalidate() } }

    private var lat = -25.35
    private var lon = -57.45
    private var bearing = 0f
    private var hasFix = false
    private val k = resources.displayMetrics.density
    private val cache = LruCache<String, Bitmap>(48)
    private val inFlight = HashSet<String>()
    private val failedAt = HashMap<String, Long>()
    private val exec = Executors.newFixedThreadPool(2)
    private val tilePaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val gridPaint = Paint().apply { color = 0x22888888; style = Paint.Style.STROKE; strokeWidth = 1f }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xCC000000.toInt() }
    private val textBg = Paint().apply { color = 0x99FFFFFF.toInt() }
    private val rect = RectF()
    private val path = Path()
    private val darkFilter = ColorMatrixColorFilter(floatArrayOf(
        -0.85f, 0f, 0f, 0f, 225f,
        0f, -0.85f, 0f, 0f, 230f,
        0f, 0f, -0.80f, 0f, 245f,
        0f, 0f, 0f, 1f, 0f,
    ))

    init { isClickable = false; isFocusable = false }

    fun setPosition(la: Double, lo: Double, br: Float, fix: Boolean) {
        if (Math.abs(la - lat) < 1e-6 && Math.abs(lo - lon) < 1e-6 && br == bearing && fix == hasFix) return
        lat = la; lon = lo; bearing = br; hasFix = fix
        invalidate()
    }

    private fun tileFile(z: Int, x: Int, y: Int) = File(context.filesDir, "tiles/$z/$x/$y.png")

    private fun request(z: Int, x: Int, y: Int) {
        val key = "$z/$x/$y"
        if (key in inFlight) return
        val f = failedAt[key]
        if (f != null && System.currentTimeMillis() - f < 60_000) return
        inFlight.add(key)
        exec.execute {
            var bmp: Bitmap? = null
            try {
                val file = tileFile(z, x, y)
                if (!file.exists()) {
                    val c = URL("https://tile.openstreetmap.org/$z/$x/$y.png").openConnection() as HttpURLConnection
                    c.setRequestProperty("User-Agent", "CarLauncher3/3.0 (launcher personal de auto)")
                    c.connectTimeout = 6000; c.readTimeout = 8000
                    if (c.responseCode == 200) {
                        file.parentFile?.mkdirs()
                        val tmp = File(file.path + ".tmp")
                        c.inputStream.use { i -> tmp.outputStream().use { o -> i.copyTo(o) } }
                        tmp.renameTo(file)
                    }
                    c.disconnect()
                }
                if (file.exists()) bmp = BitmapFactory.decodeFile(file.path)
            } catch (e: Exception) { }
            post {
                inFlight.remove(key)
                if (bmp != null) { cache.put(key, bmp); invalidate() } else failedAt[key] = System.currentTimeMillis()
            }
        }
    }

    override fun onDraw(c: Canvas) {
        val w = width.toFloat(); val h = height.toFloat()
        if (w <= 0 || h <= 0) return
        val n = 1 shl zoom
        val t = 256f * k * 0.85f
        val latR = Math.toRadians(lat)
        val wx = (lon + 180.0) / 360.0 * n
        val wy = (1.0 - Math.log(Math.tan(latR) + 1.0 / Math.cos(latR)) / Math.PI) / 2.0 * n
        val cx = w / 2f; val cy = h * 0.55f
        val x0 = Math.floor(wx - cx / t).toInt(); val x1 = Math.floor(wx + (w - cx) / t).toInt()
        val y0 = Math.floor(wy - cy / t).toInt(); val y1 = Math.floor(wy + (h - cy) / t).toInt()
        for (tx in x0..x1) for (ty in y0..y1) {
            if (ty < 0 || ty >= n) continue
            val xx = ((tx % n) + n) % n
            val left = cx + ((tx - wx) * t).toFloat(); val top = cy + ((ty - wy) * t).toFloat()
            rect.set(left, top, left + t, top + t)
            val key = "$zoom/$xx/$ty"
            val b = cache.get(key)
            if (b != null) c.drawBitmap(b, null, rect, tilePaint)
            else { c.drawRect(rect, gridPaint); request(zoom, xx, ty) }
        }
        // Posición
        dotPaint.color = (accent and 0x00FFFFFF) or 0x40000000
        c.drawCircle(cx, cy, 22f * k, dotPaint)
        if (hasFix) {
            c.save(); c.rotate(bearing, cx, cy)
            path.reset()
            path.moveTo(cx, cy - 14f * k); path.lineTo(cx + 10f * k, cy + 10f * k)
            path.lineTo(cx, cy + 5f * k); path.lineTo(cx - 10f * k, cy + 10f * k); path.close()
            dotPaint.color = accent; c.drawPath(path, dotPaint)
            ringPaint.color = 0xFFFFFFFF.toInt(); ringPaint.strokeWidth = 2f * k; c.drawPath(path, ringPaint)
            c.restore()
        } else {
            dotPaint.color = 0xFF9BA5B1.toInt(); c.drawCircle(cx, cy, 8f * k, dotPaint)
        }
        // Atribución obligatoria de OpenStreetMap
        textPaint.textSize = 11f * k
        val s = "© OpenStreetMap"
        val tw = textPaint.measureText(s)
        c.drawRect(w - tw - 10f * k, h - 16f * k, w, h, textBg)
        c.drawText(s, w - tw - 5f * k, h - 4f * k, textPaint)
    }

    fun release() { exec.shutdownNow() }
}
