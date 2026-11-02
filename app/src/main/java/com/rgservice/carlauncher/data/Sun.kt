package com.rgservice.carlauncher.data

import java.util.Calendar
import java.util.TimeZone
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin
import kotlin.math.tan

/** Salida y puesta del sol (cálculo NOAA simplificado, funciona sin internet). */
object Sun {
    private fun rad(d: Double) = Math.toRadians(d)
    private fun deg(r: Double) = Math.toDegrees(r)
    private fun norm(v: Double, m: Double): Double { var x = v % m; if (x < 0) x += m; return x }

    private fun utcHours(dayOfYear: Int, lat: Double, lon: Double, rising: Boolean): Double? {
        val lngHour = lon / 15.0
        val t = dayOfYear + ((if (rising) 6.0 else 18.0) - lngHour) / 24.0
        val m = 0.9856 * t - 3.289
        val l = norm(m + 1.916 * sin(rad(m)) + 0.020 * sin(rad(2 * m)) + 282.634, 360.0)
        var ra = norm(deg(atan(0.91764 * tan(rad(l)))), 360.0)
        ra += floor(l / 90.0) * 90.0 - floor(ra / 90.0) * 90.0
        ra /= 15.0
        val sinDec = 0.39782 * sin(rad(l))
        val cosDec = cos(asin(sinDec))
        val cosH = (cos(rad(90.833)) - sinDec * sin(rad(lat))) / (cosDec * cos(rad(lat)))
        if (cosH > 1 || cosH < -1) return null
        val h = (if (rising) 360.0 - deg(acos(cosH)) else deg(acos(cosH))) / 15.0
        val tt = h + ra - 0.06571 * t - 6.622
        return norm(tt - lngHour, 24.0)
    }

    /** (amanecer, atardecer) en milisegundos para el día de [cal]. */
    fun times(lat: Double, lon: Double, cal: Calendar = Calendar.getInstance()): Pair<Long, Long>? {
        val doy = cal.get(Calendar.DAY_OF_YEAR)
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH), 0, 0, 0)
        }.timeInMillis
        val noon = (cal.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 12); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        fun fix(ms: Long): Long {
            var x = ms
            while (x - noon > 12 * 3_600_000L) x -= 86_400_000L
            while (noon - x > 12 * 3_600_000L) x += 86_400_000L
            return x
        }
        val r = utcHours(doy, lat, lon, true) ?: return null
        val s = utcHours(doy, lat, lon, false) ?: return null
        return Pair(fix(utc + (r * 3_600_000).toLong()), fix(utc + (s * 3_600_000).toLong()))
    }

    /** ¿Es de noche ahora en esa ubicación? Si no se puede calcular, usa 19 a 7 h. */
    fun isNight(lat: Double, lon: Double, now: Long = System.currentTimeMillis()): Boolean {
        val cal = Calendar.getInstance().apply { timeInMillis = now }
        val t = times(lat, lon, cal) ?: run {
            val h = cal.get(Calendar.HOUR_OF_DAY); return h >= 19 || h < 7
        }
        return now < t.first || now >= t.second
    }
}
