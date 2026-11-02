package com.rgservice.carlauncher.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rgservice.carlauncher.ui.theme.Barlow
import com.rgservice.carlauncher.ui.theme.CarTheme

/** Tarjeta base del diseño: fondo, borde fino y esquinas de 28 dp. */
@Composable
fun CarCard(
    modifier: Modifier = Modifier,
    radius: Dp = 28.dp,
    padding: PaddingValues = PaddingValues(24.dp),
    borderColor: Color? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    val c = CarTheme.colors
    val shape = RoundedCornerShape(radius)
    Box(
        modifier
            .clip(shape)
            .background(c.card, shape)
            .border(1.dp, borderColor ?: c.line, shape)
            .padding(padding),
        content = content,
    )
}

/** Texto con la tipografía Barlow. size en sp (con la escala del diseño, 1 sp = 1 dp). */
@Composable
fun Txt(
    text: String,
    size: Int,
    color: Color = CarTheme.colors.text,
    weight: FontWeight = FontWeight.Normal,
    modifier: Modifier = Modifier,
    align: TextAlign? = null,
    maxLines: Int = 1,
    tabular: Boolean = false,
    lineHeight: Float = 1.15f,
) {
    Text(
        text = text,
        modifier = modifier,
        color = color,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
        textAlign = align,
        style = TextStyle(
            fontFamily = Barlow,
            fontWeight = weight,
            fontSize = size.sp,
            lineHeight = (size * lineHeight).sp,
            fontFeatureSettings = if (tabular) "tnum" else null,
        ),
    )
}

/** Ícono de línea (los mismos del diseño), teñido del color pedido. */
@Composable
fun LineIcon(res: Int, size: Dp, tint: Color = CarTheme.colors.text, modifier: Modifier = Modifier) {
    Icon(painter = painterResource(res), contentDescription = null, tint = tint, modifier = modifier.size(size))
}

/** Separador horizontal o vertical de 1 dp. */
@Composable
fun Hairline(modifier: Modifier) {
    Box(modifier.background(CarTheme.colors.line))
}

fun Int.fmtKm(): String = String.format(java.util.Locale.US, "%,d", this).replace(',', '.')
fun Double.fmt1(): String = String.format(java.util.Locale.US, "%.1f", this).replace('.', ',')
