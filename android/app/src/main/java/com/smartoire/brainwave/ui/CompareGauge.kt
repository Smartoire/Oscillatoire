package com.smartoire.brainwave.ui

// The Compare gauge: a half circle with the left half in the first area's colour and the right half in the second's.
// The needle starts at the top (90 degrees) when the areas are level, and swings toward the area that is more active.

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.sin

/// [firstShare] is the share of time the first area was higher, 0..1. 0.5 is level and points straight up.
@Composable
fun CompareGauge(firstShare: Float, firstColour: Color, secondColour: Color, modifier: Modifier = Modifier) {
    val share by animateFloatAsState(targetValue = firstShare.coerceIn(0f, 1f), animationSpec = tween(900), label = "compareGauge")
    Canvas(modifier = modifier.fillMaxWidth().height(90.dp)) {
        val stroke = 12.dp.toPx()
        val radius = minOf((size.width - stroke) / 2f, size.height - stroke / 2f)
        val center = Offset(size.width / 2f, size.height - stroke / 2f)
        val topLeft = Offset(center.x - radius, center.y - radius)
        val box = Size(radius * 2f, radius * 2f)
        // Compose angles run clockwise from 3 o'clock, so the top half is 180 to 360. Left half first colour, right half second.
        drawArc(firstColour.copy(alpha = 0.85f), 180f, 90f, false, topLeft, box, style = Stroke(stroke, cap = StrokeCap.Butt))
        drawArc(secondColour.copy(alpha = 0.85f), 270f, 90f, false, topLeft, box, style = Stroke(stroke, cap = StrokeCap.Butt))
        // The needle: 180 degrees when the first area is always higher, 0 when the second is, 90 when level.
        val angle = Math.PI * (1.0 - share.toDouble())
        val tip = Offset(center.x + (radius * 0.85f * cos(angle)).toFloat(), center.y - (radius * 0.85f * sin(angle)).toFloat())
        drawLine(Color.White, center, tip, strokeWidth = 3.dp.toPx(), cap = StrokeCap.Round)
        drawCircle(Color.White, radius = 5.dp.toPx(), center = center)
    }
}
