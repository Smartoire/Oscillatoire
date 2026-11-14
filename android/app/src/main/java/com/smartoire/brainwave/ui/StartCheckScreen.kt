package com.smartoire.brainwave.ui

// Port of App/StartCheckView.swift: connection, battery, each sensor and head movement, then Start.
// Styled like the Mind page. The sensors are drawn on a head outline, so a bad contact shows where it is.

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.smartoire.brainwave.R
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.kit.Electrode
import com.smartoire.brainwave.muse.MuseState

/// Movement limit from Capture.movementLimit in the kit (0.15 g).
private const val MOVEMENT_LIMIT = 0.15
private val okColour = Color(0xFF34C759)
private val warnColour = Color(0xFFF6C453)
private val badColour = Color(0xFFFF6B6B)

/// The headband curve, from the left temple over the forehead to the right temple, in head units (-1..1).
private val band = arrayOf(Offset(-0.78f, 0.2f), Offset(-0.8f, -1.0f), Offset(0.8f, -1.0f), Offset(0.78f, 0.2f))

/// A point on the headband curve for t in 0..1 (cubic Bezier).
private fun bandAt(t: Float): Offset {
    val u = 1 - t
    val a = u * u * u; val b = 3 * u * u * t; val c = 3 * u * t * t; val d = t * t * t
    return Offset(
        a * band[0].x + b * band[1].x + c * band[2].x + d * band[3].x,
        a * band[0].y + b * band[1].y + c * band[2].y + d * band[3].y,
    )
}

/// Where each sensor sits along the headband: TP9 left temple, AF7 left forehead, AF8 right forehead, TP10 right temple.
private fun spot(e: Electrode): Offset = when (e) {
    Electrode.TP9 -> bandAt(0.12f)
    Electrode.AF7 -> bandAt(0.36f)
    Electrode.AF8 -> bandAt(0.64f)
    Electrode.TP10 -> bandAt(0.88f)
}

@Composable
fun StartCheckScreen(state: MuseState, onStart: () -> Unit) {
    val sensorsOk = Electrode.entries.all { (state.contact[it] ?: 4.0) <= 2.0 }
    val still = (state.movement ?: 0.0) <= MOVEMENT_LIMIT
    val connected = state.status.startsWith("Connected") || state.status == "Demo headband"
    val canStart = connected && sensorsOk && still

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 40.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // A fixed-height summary, so the text changing does not move the cards below it.
        Column(modifier = Modifier.fillMaxWidth().height(84.dp).card().padding(16.dp), verticalArrangement = Arrangement.Center) {
            Text(
                if (canStart) stringResource(R.string.start_ok) else stringResource(R.string.start_unlock),
                style = MaterialTheme.typography.bodyLarge,
                color = if (canStart) okColour else MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = if (canStart) FontWeight.Bold else null,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            CheckCard(stringResource(R.string.start_connected), if (connected) state.status else stringResource(R.string.start_checking), connected, Modifier.weight(1f))
            CheckCard(
                stringResource(R.string.start_battery),
                state.battery?.let { if (it >= 15) "${it.toInt()}%" else stringResource(R.string.start_charge, it.toInt()) } ?: stringResource(R.string.start_checking),
                (state.battery ?: 0.0) >= 15,
                Modifier.weight(1f),
            )
        }
        // The head, seen from above, with each sensor where it sits. A bad contact shows as a red dot in that place.
        Column(modifier = Modifier.fillMaxWidth().card().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Sensors", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth())
            HeadSensors(state, Modifier.fillMaxWidth().height(230.dp).padding(top = 8.dp))
            Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Electrode.entries.forEach { e ->
                    val (text, colour) = contactText(state.contact[e])
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(e.label, fontWeight = FontWeight.Bold, color = colour)
                        Text(text, style = MaterialTheme.typography.labelSmall, color = colour)
                    }
                }
            }
            Text(
                if (still) stringResource(R.string.start_head_still) else stringResource(R.string.start_head_move),
                style = MaterialTheme.typography.bodyMedium,
                color = if (still) okColour else badColour,
                modifier = Modifier.padding(top = 10.dp),
            )
        }
        // The big play button: greyed until everything is ready.
        Box(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape)
                    .background(
                        if (canStart) Brush.linearGradient(listOf(Color(0xFFF6A36B), Color(0xFFE94E89)))
                        else Brush.linearGradient(listOf(Color.Gray.copy(alpha = 0.4f), Color.Gray.copy(alpha = 0.4f))),
                    )
                    .clickable(enabled = canStart, onClick = onStart),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.PlayArrow, contentDescription = stringResource(R.string.start_start), tint = Color.White, modifier = Modifier.size(56.dp))
            }
        }
    }
}

/// A head seen from the front-top, with the headband across it and a pad for each sensor.
/// Green is good contact, amber is weak, red is off, grey is not read yet.
@Composable
private fun HeadSensors(state: MuseState, modifier: Modifier) {
    Canvas(modifier = modifier) {
        val c = Offset(size.width / 2, size.height / 2)
        val r = minOf(size.width, size.height) * 0.36f
        fun p(o: Offset) = Offset(c.x + o.x * r, c.y + o.y * r)
        val outline = Color.Gray.copy(alpha = 0.55f)
        // Head: an oval with a nose at the front and an ear on each side.
        drawCircle(outline, radius = r, center = c, style = Stroke(width = 3f))
        val nose = Path().apply {
            moveTo(c.x - 0.16f * r, c.y - 0.97f * r)
            lineTo(c.x, c.y - 1.16f * r)
            lineTo(c.x + 0.16f * r, c.y - 0.97f * r)
        }
        drawPath(nose, outline, style = Stroke(width = 3f))
        listOf(-1f, 1f).forEach { side ->
            drawOval(outline, topLeft = Offset(c.x + side * r - 0.06f * r, c.y - 0.18f * r), size = Size(0.14f * r, 0.36f * r), style = Stroke(width = 3f))
        }
        // The headband: a thick curve across the head, through the four sensor positions.
        val arc = Path().apply {
            val s0 = p(band[0]); moveTo(s0.x, s0.y)
            val c1 = p(band[1]); val c2 = p(band[2]); val e0 = p(band[3])
            cubicTo(c1.x, c1.y, c2.x, c2.y, e0.x, e0.y)
        }
        drawPath(arc, Color(0xFF3A3F52), style = Stroke(width = 0.16f * r, cap = StrokeCap.Round))
        // A pad at each sensor, coloured by its contact.
        Electrode.entries.forEach { e ->
            val at = p(spot(e))
            drawCircle(contactColour(state.contact[e]), radius = 0.13f * r, center = at)
            drawCircle(Color.White.copy(alpha = 0.8f), radius = 0.13f * r, center = at, style = Stroke(width = 2f))
        }
    }
}

private fun contactColour(q: Double?): Color = when {
    q == null -> Color.Gray
    q <= 1.0 -> okColour
    q <= 2.0 -> warnColour
    else -> badColour
}

private fun contactText(q: Double?): Pair<String, Color> = when {
    q == null -> "Checking…" to Color.Gray
    q <= 1.0 -> "Good" to okColour
    q <= 2.0 -> "Weak" to warnColour
    else -> "Off: adjust" to badColour
}

/// A rounded card with a title and a value, green when that check passes.
@Composable
private fun CheckCard(title: String, value: String, ok: Boolean, modifier: Modifier) {
    Column(modifier = modifier.card().padding(14.dp)) {
        Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = if (ok) okColour else badColour,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}
