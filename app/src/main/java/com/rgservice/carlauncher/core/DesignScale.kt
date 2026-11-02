package com.rgservice.carlauncher.core

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

/**
 * Tamaño de pantalla. El diseño se hace para una pantalla de [designHeightDp] dp de alto
 * y se escala para llenar la pantalla real. Menos alto de diseño = todo más grande.
 */
enum class UiSize(val label: String, val designHeightDp: Float) {
    Normal("Normal", 720f),
    Grande("Grande", 640f),
    MuyGrande("Muy grande", 580f),
}

/**
 * Cambia la "densidad" de Compose para que el alto de la pantalla mida exactamente
 * [size].designHeightDp. Todo lo que está adentro (textos, márgenes, íconos) se escala junto,
 * sin parches y respetando el ancho real (las columnas se reparten por proporción).
 */
@Composable
fun DesignScale(size: UiSize, content: @Composable () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val hPx = constraints.maxHeight.toFloat()
        val wPx = constraints.maxWidth.toFloat()
        if (hPx <= 0f || wPx <= 0f) {
            content()
        } else {
            var d = hPx / size.designHeightDp
            // En tamaño Normal, si la pantalla es muy angosta, que entren al menos 1024 dp de ancho
            if (size == UiSize.Normal && wPx / d < 1024f) d = wPx / 1024f
            CompositionLocalProvider(LocalDensity provides Density(density = d, fontScale = 1f)) {
                content()
            }
        }
    }
}
