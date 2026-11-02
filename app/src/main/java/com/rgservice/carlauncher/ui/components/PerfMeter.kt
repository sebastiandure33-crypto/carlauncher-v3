package com.rgservice.carlauncher.ui.components

import android.app.ActivityManager
import android.content.Context
import android.os.Process
import android.os.SystemClock
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext

/**
 * Medidor de rendimiento para probar en la radio (etapa 1):
 *  - arranque: desde que Android abre la app hasta el primer cuadro dibujado,
 *  - fps: cuadros por segundo reales,
 *  - memoria que usa la app.
 * Mantené apretada la hora para mostrarlo u ocultarlo.
 */
@Composable
fun PerfMeter(modifier: Modifier = Modifier, onClick: () -> Unit) {
    val ctx = LocalContext.current
    var startupMs by remember { mutableLongStateOf(-1L) }
    var fps by remember { mutableIntStateOf(0) }
    var memMb by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        withFrameNanos { }
        if (StartupClock.firstFrameMs < 0) {
            StartupClock.firstFrameMs = SystemClock.uptimeMillis() - Process.getStartUptimeMillis()
        }
        startupMs = StartupClock.firstFrameMs
    }
    LaunchedEffect(Unit) {
        var frames = 0
        var t0 = 0L
        while (isActive) {
            withFrameNanos { now ->
                if (t0 == 0L) t0 = now
                frames++
                if (now - t0 >= 1_000_000_000L) { fps = frames; frames = 0; t0 = now }
            }
        }
    }
    LaunchedEffect(Unit) {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        while (isActive) {
            memMb = withContext(Dispatchers.Default) {
                try { am.getProcessMemoryInfo(intArrayOf(Process.myPid()))[0].totalPss / 1024 } catch (e: Exception) { 0 }
            }
            delay(3000)
        }
    }
    val txt = buildString {
        append("Prueba · arranque ")
        append(if (startupMs >= 0) String.format(java.util.Locale.US, "%.1f s", startupMs / 1000f) else "…")
        append(" · $fps fps · $memMb MB")
    }
    Txt(
        txt, 14, Color.White, tabular = true,
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xB3000000))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

/** Guarda el tiempo de arranque una sola vez por proceso. */
object StartupClock { var firstFrameMs: Long = -1L }
