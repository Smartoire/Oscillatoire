package com.smartoire.brainwave.ui

// A half-circle gauge with a needle, as in the design reference: 0 at the left, 100 at the right.

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

@Composable
fun ScoreGauge(value: Float, tint: Color, modifier: Modifier = Modifier) {
    // The needle and arc glide to each new value instead of jumping.
    val animated by animateFloatAsState(targetValue = value.coerceIn(0f, 100f), animationSpec = tween(900), label = "gauge")
    val score = animated
    Canvas(modifier = modifier.fillMaxWidth().height(74.dp)) {
        val stroke = 12.dp.toPx()
        val radius = minOf((size.width - stroke) / 2f, size.height - stroke / 2f)
        val center = Offset(size.width / 2f, size.height - stroke / 2f)
        val topLeft = Offset(center.x - radius, center.y - radius)
        val box = Size(radius * 2f, radius * 2f)
        // Three state zones along the arc: low (0 to 35), steady (36 to 64) and high (65 to 100).
        // The zone the score is in is bright; the others are faint, so the state reads at a glance.
        val low = Color(0xFFE57373)
        val steady = Color(0xFFF6C453)
        val lowOn = score <= 35f
        val highOn = score >= 65f
        fun zone(from: Float, to: Float, colour: Color, on: Boolean) {
            drawArc(
                colour.copy(alpha = if (on) 0.95f else 0.22f),
                180f + 180f * from / 100f, 180f * (to - from) / 100f, false, topLeft, box,
                style = Stroke(stroke, cap = StrokeCap.Butt),
            )
        }
        zone(0f, 35f, low, lowOn)
        zone(35f, 65f, steady, !lowOn && !highOn)
        zone(65f, 100f, tint, highOn)
        // The needle moves from the left (0) to the right (100) across the zones.
        val angle = Math.PI * (1.0 - score / 100.0)
        val tip = Offset(center.x + (radius * 0.85f * cos(angle)).toFloat(), center.y - (radius * 0.85f * sin(angle)).toFloat())
        drawLine(Color.White, center, tip, strokeWidth = 3.dp.toPx(), cap = StrokeCap.Round)
        drawCircle(Color.White, radius = 5.dp.toPx(), center = center)
    }
}
