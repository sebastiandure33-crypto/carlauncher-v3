package com.rgservice.carlauncher.data

/** Todo lo que muestra la pantalla de inicio. La interfaz solo dibuja este estado. */
data class HomeState(
    val name: String = "conductor",
    val gpsOk: Boolean = false,
    val speedKmh: Int? = null,          // null = sin GPS
    val speedLimit: Int = 80,           // 0 = aviso desactivado
    val trip: Trip = Trip(),
    val weather: Weather? = null,
    val odoKm: Int? = null,             // km del tablero (null = sin cargar)
    val oil: Gauge = Gauge("oil", "Aceite motor", -1, 5000, null),
    val gear: Gauge = Gauge("gear", "Aceite caja", -1, 40000, null),
    val maintWarnings: Int = 0,         // ítems de mantenimiento en alerta (km o fecha)
    val dark: Boolean = true,
    val theme: ThemeMode = ThemeMode.Auto,
) {
    val overLimit: Boolean get() = speedLimit > 0 && (speedKmh ?: 0) > speedLimit
}

data class Trip(val km: Double = 0.0, val minutes: Int = 0, val avgKmh: Int = 0)

data class Weather(
    val tempC: Int,
    val description: String,
    val maxC: Int,
    val minC: Int,
    val humidity: Int,
    val windKmh: Int,
    val code: Int = 0,                // código Open-Meteo (para el ícono)
    val updatedAgo: String? = null,   // "hace 2 h" cuando viene de la memoria (sin internet)
)

/** Un ítem de mantenimiento por km. remainingKm = -1 si todavía no se cargó. */
data class Gauge(val id: String, val name: String, val remainingKm: Int, val intervalKm: Int, val nextAtKm: Int?) {
    val configured: Boolean get() = remainingKm >= 0
    val warn: Boolean get() = remainingKm in 0..500
    val fraction: Float get() = if (configured && intervalKm > 0) (remainingKm.toFloat() / intervalKm).coerceIn(0f, 1f) else 0f
}

/** Lo que está sonando. positionMs vale en el instante positionAt (reloj elapsedRealtime). */
data class Media(
    val source: String = "Música",
    val title: String = "Sin reproducción",
    val artist: String = "Poné música en el celular o en la radio",
    val playing: Boolean = false,
    val positionMs: Long = 0,
    val positionAt: Long = 0,
    val speed: Float = 1f,
    val durationMs: Long = 0,
    val art: android.graphics.Bitmap? = null,
    val pkg: String? = null,
    val hasPermission: Boolean = true,
    val hasSession: Boolean = false,
)

/** Modo noche: automático por la salida y puesta del sol, o fijo. */
enum class ThemeMode(val label: String) { Auto("Auto"), Night("Noche"), Day("Día") }
