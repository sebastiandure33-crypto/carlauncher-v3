package com.rgservice.carlauncher.data.maint

import android.content.SharedPreferences
import com.rgservice.carlauncher.data.Gauge
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/** Fila de un ítem por km, lista para mostrar. */
data class KmRow(
    val id: String,
    val name: String,
    val custom: Boolean,
    val remaining: Int?,     // null = sin cargar
    val interval: Int,
    val next: Int?,
    val warn: Boolean,
) {
    val fraction: Float get() = if (remaining != null && interval > 0) (remaining.toFloat() / interval).coerceIn(0f, 1f) else 0f
}

/** Fila de un vencimiento por fecha. */
data class DateRow(
    val id: String,
    val name: String,
    val custom: Boolean,
    val dateMs: Long?,       // null = sin fecha
    val days: Int?,          // días que faltan (negativo = vencido)
    val warn: Boolean,
)

/** Todo el mantenimiento de una vez (para la pantalla Mantenimiento). */
data class MaintSnapshot(
    val odo: Int? = null,
    val km: List<KmRow> = emptyList(),
    val dates: List<DateRow> = emptyList(),
) {
    val warnings: Int get() = km.count { it.warn } + dates.count { it.warn }
}

/**
 * Mantenimiento por el km del tablero (lo que se lee en el auto, sin cuentas):
 *  - odoKm        = km que marca el tablero (lo cargás una vez; el GPS le va sumando),
 *  - next_<id>    = km del tablero en que toca el próximo cambio,
 *  - int_<id>     = cada cuántos km se cambia,
 *  - last_<id>    = km del tablero del último cambio (si se conoce).
 * Vencimientos: d_<id> = fecha en milisegundos.
 * Ítems propios: listas JSON "customKm" y "customDates".
 */
class Maintenance(private val sp: SharedPreferences) {

    data class Item(val id: String, val name: String, val defInterval: Int, val presets: List<Int>, val custom: Boolean = false)
    data class DateItem(val id: String, val name: String, val custom: Boolean = false)

    companion object {
        const val WARN_KM = 500
        const val WARN_DAYS = 30
        val ITEMS = listOf(
            Item("oil", "Aceite motor", 5000, listOf(3000, 5000, 7500, 10000)),
            Item("gear", "Aceite caja", 40000, listOf(20000, 30000, 40000, 60000)),
            Item("air", "Filtro de aire", 15000, listOf(10000, 15000, 20000, 30000)),
            Item("tires", "Rotación de neumáticos", 10000, listOf(5000, 8000, 10000, 15000)),
            Item("brakes", "Pastillas de freno", 20000, listOf(15000, 20000, 30000, 40000)),
            Item("belt", "Correa de distribución", 60000, listOf(40000, 50000, 60000, 100000)),
        )
        val DATES = listOf(
            DateItem("ins", "Seguro del auto"),
            DateItem("hab", "Habilitación"),
            DateItem("rev", "Revisión técnica"),
            DateItem("lic", "Licencia de conducir"),
        )

        fun daysUntil(millis: Long): Int {
            fun day(ms: Long) = Calendar.getInstance().apply {
                timeInMillis = ms
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            return Math.round((day(millis) - day(System.currentTimeMillis())) / 86_400_000.0).toInt()
        }

        fun leftText(days: Int): String = when {
            days < 0 -> "Vencido"
            days == 0 -> "Hoy"
            days == 1 -> "Mañana"
            days < 60 -> "en $days días"
            days < 365 -> "en ${days / 30} meses"
            days < 730 -> "en 1 año"
            else -> "en ${days / 365} años"
        }
    }

    /* ------------------------------------------------ listas */

    private fun arr(key: String): JSONArray = try { JSONArray(sp.getString(key, "[]")) } catch (e: Exception) { JSONArray() }

    fun kmItems(): List<Item> {
        val out = ArrayList(ITEMS)
        val a = arr("customKm")
        for (i in 0 until a.length()) {
            val o = a.optJSONObject(i) ?: continue
            val def = o.optInt("def", 10000)
            out.add(Item(o.optString("id"), o.optString("name"), def, listOf(def / 2, def, def * 2), custom = true))
        }
        return out
    }

    fun dateItems(): List<DateItem> {
        val out = ArrayList(DATES)
        val a = arr("customDates")
        for (i in 0 until a.length()) {
            val o = a.optJSONObject(i) ?: continue
            out.add(DateItem(o.optString("id"), o.optString("name"), custom = true))
        }
        return out
    }

    fun item(id: String): Item = kmItems().firstOrNull { it.id == id } ?: ITEMS[0]
    fun dateItem(id: String): DateItem = dateItems().firstOrNull { it.id == id } ?: DATES[0]

    /* ------------------------------------------------ km */

    fun hasOdo() = sp.getFloat("odoKm", -1f) >= 0f
    fun odo(): Int? = sp.getFloat("odoKm", -1f).takeIf { it >= 0f }?.let { Math.round(it) }
    fun next(id: String): Int? = sp.getInt("next_$id", -1).takeIf { it >= 0 }
    fun last(id: String): Int? = sp.getInt("last_$id", -1).takeIf { it >= 0 }
    fun interval(id: String): Int = sp.getInt("int_$id", item(id).defInterval)

    /** Corrige el km del tablero (los "próximo cambio" no se mueven: son km fijos del tablero). */
    fun setOdo(km: Int) { sp.edit().putFloat("odoKm", km.toFloat()).apply() }

    /** "Lo cambié hoy": próximo = tablero + intervalo. */
    fun changedNow(id: String) {
        val o = odo() ?: return
        sp.edit().putInt("last_$id", o).putInt("next_$id", o + interval(id)).apply()
    }

    /** "El próximo cambio es a los X km" (lo que dice el sticker del taller). */
    fun setNext(id: String, km: Int) { sp.edit().putInt("next_$id", km).remove("last_$id").apply() }

    /** Cambia el intervalo. Si se sabe cuándo fue el último cambio, recalcula el próximo. */
    fun setInterval(id: String, km: Int) {
        val ed = sp.edit().putInt("int_$id", km)
        last(id)?.let { ed.putInt("next_$id", it + km) }
        ed.apply()
    }

    fun remaining(id: String): Int? {
        val o = odo() ?: return null
        val n = next(id) ?: return null
        return (n - o).coerceAtLeast(0)
    }

    fun gauge(id: String): Gauge {
        val it = item(id)
        return Gauge(id, it.name, remaining(id) ?: -1, interval(id), next(id))
    }

    /* ------------------------------------------------ fechas */

    fun date(id: String): Long? = sp.getLong("d_$id", -1L).takeIf { it > 0 }
    fun setDate(id: String, ms: Long?) {
        if (ms == null) sp.edit().remove("d_$id").apply() else sp.edit().putLong("d_$id", ms).apply()
    }

    /* ------------------------------------------------ ítems propios */

    /** Agrega un ítem propio y devuelve su id. */
    fun addKm(name: String, interval: Int): String {
        val id = "c" + System.currentTimeMillis()
        val a = arr("customKm").put(JSONObject().put("id", id).put("name", name).put("def", interval))
        val ed = sp.edit().putString("customKm", a.toString()).putInt("int_$id", interval)
        odo()?.let { ed.putInt("next_$id", it + interval).putInt("last_$id", it) }
        ed.apply()
        return id
    }

    fun addDate(name: String): String {
        val id = "c" + System.currentTimeMillis()
        val a = arr("customDates").put(JSONObject().put("id", id).put("name", name))
        sp.edit().putString("customDates", a.toString()).apply()
        return id
    }

    fun remove(id: String) {
        val ed = sp.edit()
        for (key in listOf("customKm", "customDates")) {
            val a = arr(key); val b = JSONArray()
            for (i in 0 until a.length()) { val o = a.optJSONObject(i) ?: continue; if (o.optString("id") != id) b.put(o) }
            ed.putString(key, b.toString())
        }
        ed.remove("int_$id").remove("next_$id").remove("last_$id").remove("d_$id").apply()
    }

    /* ------------------------------------------------ todo junto */

    fun snapshot(): MaintSnapshot = MaintSnapshot(
        odo = odo(),
        km = kmItems().map { it ->
            val rem = remaining(it.id)
            KmRow(it.id, it.name, it.custom, rem, interval(it.id), next(it.id), rem != null && rem <= WARN_KM)
        },
        dates = dateItems().map { d ->
            val ms = date(d.id)
            val days = ms?.let { daysUntil(it) }
            DateRow(d.id, d.name, d.custom, ms, days, days != null && days <= WARN_DAYS)
        },
    )
}
