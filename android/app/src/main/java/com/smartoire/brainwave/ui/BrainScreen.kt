package com.smartoire.brainwave.ui

// Port of App/MapScreen.swift and App/TopomapView.swift: the brain from above, shaded by activity.
// Everyday view shows overall activity; advanced view adds the band picker and the sensor cards.

import androidx.compose.ui.res.stringResource
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.R
import com.smartoire.brainwave.kit.Band
import com.smartoire.brainwave.kit.BrainRegion
import com.smartoire.brainwave.kit.Capture
import com.smartoire.brainwave.kit.Electrode
import com.smartoire.brainwave.kit.ScoreTracker
import com.smartoire.brainwave.kit.Topomap
import kotlin.math.roundToInt
import kotlin.math.sqrt

private const val ASPECT = 768f / 618f   // the brain image's height / width
private const val HEAT_SIZE = 192        // pixels across the activity image

// Left-to-right marks keep the numbers in order when the line is right-to-left.
private val bandRanges = listOf("‎1–4 Hz", "‎4–8 Hz", "‎7.5–13 Hz", "‎13–30 Hz", "‎30–44 Hz")
/// What each band means, read from the resources.
@Composable
private fun bandMeaning(band: Band): String = stringResource(
    when (band) {
        Band.DELTA -> R.string.band_desc_delta
        Band.THETA -> R.string.band_desc_theta
        Band.ALPHA -> R.string.band_desc_alpha
        Band.BETA -> R.string.band_desc_beta
        Band.GAMMA -> R.string.band_desc_gamma
    },
)

@Composable
private fun bandName(band: Band): String = stringResource(
    when (band) {
        Band.DELTA -> R.string.band_name_delta
        Band.THETA -> R.string.band_name_theta
        Band.ALPHA -> R.string.band_name_alpha
        Band.BETA -> R.string.band_name_beta
        Band.GAMMA -> R.string.band_name_gamma
    },
)

private fun regionNameRes(e: Electrode): Int = when (e) {
    Electrode.TP9 -> R.string.area_left_temporal
    Electrode.AF7 -> R.string.area_left_frontal
    Electrode.AF8 -> R.string.area_right_frontal
    Electrode.TP10 -> R.string.area_right_temporal
}

@Composable
fun BrainScreen(tracker: ScoreTracker, tick: Int, connected: Boolean, movement: Double?, contact: Map<Electrode, Double>, advanced: Boolean) {
    val context = LocalContext.current
    val brain = remember { BitmapFactory.decodeResource(context.resources, R.drawable.brain_top) }
    var band by remember { mutableStateOf(Band.ALPHA) }
    var selected by remember { mutableStateOf<BrainRegion?>(null) }
    // The tick parameter makes this screen redraw once a second, as the scores do.
    val values: Map<Electrode, Float> = if (advanced) {
        tracker.activation[band]?.mapValues { it.value.toFloat() }.orEmpty()
    } else {
        tracker.activity()
    }
    val hasBad = contact.values.any { it >= 4.0 }

    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
                if (advanced) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 8.dp).horizontalScroll(rememberScrollState())) {
                Band.entries.forEach { b ->
                    BrandButton(onClick = { band = b }) { Text(if (b == band) "● ${bandName(b)}" else bandName(b)) }
                }
            }
            Text(
                "${bandRanges[band.ordinal]} · ${bandMeaning(band)} · ${stringResource(R.string.brain_tap_hint)}",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 4.dp),
            )
        } else {
            Text(
                stringResource(R.string.brain_overall),
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 8.dp),
            )
        }

        Box(modifier = Modifier.fillMaxWidth().height(340.dp).padding(top = 12.dp)) {
            BrainMap(brain, values, contact, onPick = { selected = it })
            val message = when {
                !connected -> stringResource(R.string.brain_connect)
                (movement ?: 0.0) > Capture.MOVEMENT_LIMIT -> stringResource(R.string.brain_hold_still)
                hasBad -> stringResource(R.string.brain_adjust)
                else -> null
            }
            if (message != null) {
                Text(
                    message,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.align(Alignment.TopCenter).card().padding(horizontal = 14.dp, vertical = 8.dp),
                )
            }
        }

        Legend()
        selected?.let { RegionCard(it, values) }
        if (advanced) SensorCards(values, contact)
    }
}

/// The brain drawn as a picture shaded by activity, with failed sensors marked. Tap a region to select it.
@Composable
private fun BrainMap(brain: Bitmap, values: Map<Electrode, Float>, contact: Map<Electrode, Double>, onPick: (BrainRegion?) -> Unit) {
    val heat = remember(values, brain) { heatBitmap(brain, values).asImageBitmap() }
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }
    Canvas(
        modifier = Modifier.fillMaxSize().onSizeChanged { canvasSize = it }
            .pointerInput(Unit) {
                detectTapGestures { tap ->
                    val layout = MapLayout(canvasSize.width.toFloat(), canvasSize.height.toFloat())
                    val (x, y) = layout.head(tap)
                    onPick(if (sqrt(x * x + y * y) <= 1.05f) BrainRegion.at(x, y) else null)
                }
            },
    ) {
        val layout = MapLayout(size.width, size.height)
        val topLeft = layout.point(-1.25f, 1.25f)
        val side = 2.5f * layout.unit
        drawImage(
            heat,
            dstOffset = IntOffset(topLeft.x.roundToInt(), topLeft.y.roundToInt()),
            dstSize = IntSize(side.roundToInt(), (side * ASPECT).roundToInt()),
        )
        // Failed sensors get an alarm where they sit, not a silent gap that reads as zero.
        for (e in Electrode.entries) if ((contact[e] ?: 0.0) >= 4.0) {
            drawCircle(Color.Red, radius = 13.dp.toPx(), center = layout.point(e.x, e.y))
        }
    }
}

/// Head coordinates (x right, y nose, brain edge at 1) to the canvas. The brain is taller than wide, so y is stretched.
private class MapLayout(width: Float, height: Float) {
    val unit = minOf(width / 2.9f, height / (2.75f * ASPECT))
    private val cx = width / 2
    private val cy = height / 2 + unit * 0.08f

    fun point(x: Float, y: Float): Offset = Offset(cx + x * unit, cy - y * unit * ASPECT)

    fun head(p: Offset): Pair<Float, Float> = Pair((p.x - cx) / unit, (cy - p.y) / (unit * ASPECT))
}

/// The activity picture: the brain image in head coordinates, tinted where the activity is.
private fun heatBitmap(brain: Bitmap, values: Map<Electrode, Float>): Bitmap {
    val bw = brain.width
    val bh = brain.height
    val pixels = IntArray(bw * bh).also { brain.getPixels(it, 0, bw, 0, 0, bw, bh) }
    val out = IntArray(HEAT_SIZE * HEAT_SIZE)
    for (row in 0 until HEAT_SIZE) for (col in 0 until HEAT_SIZE) {
        val x = (col + 0.5f) / HEAT_SIZE * 2.5f - 1.25f
        val y = 1.25f - (row + 0.5f) / HEAT_SIZE * 2.5f
        val r = sqrt(x * x + y * y)
        if (r > 1.02f) continue  // outside the head: transparent
        val px = pixels[((1 - y) / 2 * bh).toInt().coerceIn(0, bh - 1) * bw + ((x + 1) / 2 * bw).toInt().coerceIn(0, bw - 1)]
        val brainAlpha = if (r <= 1f) ((px ushr 24) and 0xFF) / 255f else 0f
        // Brain over a dark scalp, then the activity colour on the brain only.
        var red = mix(0.10f, ((px shr 16) and 0xFF) / 255f, brainAlpha)
        var green = mix(0.11f, ((px shr 8) and 0xFF) / 255f, brainAlpha)
        var blue = mix(0.14f, (px and 0xFF) / 255f, brainAlpha)
        if (values.isNotEmpty()) {
            val heat = Topomap.color(Topomap.sample(values, x, y).first)
            val amount = heat.strength * brainAlpha
            red = mix(red, heat.r, amount)
            green = mix(green, heat.g, amount)
            blue = mix(blue, heat.b, amount)
        }
        out[row * HEAT_SIZE + col] = (0xFF shl 24) or ((red * 255).toInt() shl 16) or ((green * 255).toInt() shl 8) or (blue * 255).toInt()
    }
    return Bitmap.createBitmap(out, HEAT_SIZE, HEAT_SIZE, Bitmap.Config.ARGB_8888)
}

private fun mix(a: Float, b: Float, t: Float) = a + (b - a) * t

/// Blue for less active than usual, red for more. Mirrors Legend in MapScreen.swift.
@Composable
private fun Legend() {
    val colors = (0..20).map { i ->
        val heat = Topomap.color((i / 20f * 2 - 1) * Topomap.FULL_SCALE)
        Color(heat.r, heat.g, heat.b, maxOf(heat.strength, 0.08f))
    }
    Column(modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
        Box(
            modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp))
                .background(Brush.horizontalGradient(colors)),
        )
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) {
            Text(stringResource(R.string.brain_less_active), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            Text(stringResource(R.string.brain_legend_usual), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            Text(stringResource(R.string.brain_more_active), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
    }
}

/// What a selected region does, and how active it is now. Stands in for the iPhone callout.
@Composable
private fun RegionCard(region: BrainRegion, values: Map<Electrode, Float>) {
    val name = stringResource(
        when (region) {
            BrainRegion.LEFT_FRONTAL -> R.string.brain_lfl_name
            BrainRegion.RIGHT_FRONTAL -> R.string.brain_rfl_name
            BrainRegion.LEFT_TEMPORAL -> R.string.brain_ltl_name
            BrainRegion.RIGHT_TEMPORAL -> R.string.brain_rtl_name
        },
    )
    val function = stringResource(
        when (region) {
            BrainRegion.LEFT_FRONTAL -> R.string.brain_lfl_fn
            BrainRegion.RIGHT_FRONTAL -> R.string.brain_rfl_fn
            BrainRegion.LEFT_TEMPORAL -> R.string.brain_ltl_fn
            BrainRegion.RIGHT_TEMPORAL -> R.string.brain_rtl_fn
        },
    )
    val (z, confidence) = if (values.isEmpty()) Pair(0f, 0f) else Topomap.sample(values, region.centreX, region.centreY)
    val level = when {
        values.isEmpty() -> stringResource(R.string.brain_no_data)
        z > 0.5f -> stringResource(R.string.brain_more)
        z < -0.5f -> stringResource(R.string.brain_less)
        else -> stringResource(R.string.brain_usual)
    }
    val coverage = when {
        confidence > 0.6f -> stringResource(R.string.brain_measured)
        confidence > 0.2f -> stringResource(R.string.brain_estimated)
        else -> stringResource(R.string.brain_rough)
    }
    Column(modifier = Modifier.fillMaxWidth().padding(top = 12.dp).card().padding(12.dp)) {
        Text(name, fontWeight = FontWeight.SemiBold)
        Text(function, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 4.dp))
        Text(level, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 6.dp))
        Text(coverage, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
    }
}

/// One card per sensor: its activity, or "Sensor off". Advanced view only.
@Composable
private fun SensorCards(values: Map<Electrode, Float>, contact: Map<Electrode, Double>) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
        Electrode.entries.forEach { e ->
            val z = values[e]
            val bad = (contact[e] ?: 0.0) >= 4.0
            Column(modifier = Modifier.weight(1f).card().padding(8.dp)) {
                Text(e.label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
                Text(stringResource(regionNameRes(e)), style = MaterialTheme.typography.labelSmall, color = Color.Gray, maxLines = 1)
                if (bad) {
                    Text("Sensor off", color = Color.Red, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp))
                } else {
                    val tint = z?.let { Topomap.color(it) }
                    Text(
                        z?.let { String.format(java.util.Locale.US, "%+.1f σ", it) } ?: "—",
                        color = tint?.let { Color(it.r, it.g, it.b) } ?: Color.Gray,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}
