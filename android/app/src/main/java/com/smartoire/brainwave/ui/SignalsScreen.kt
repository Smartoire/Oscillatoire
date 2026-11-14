package com.smartoire.brainwave.ui

// Port of App/SignalsView.swift: raw EEG traces for the last four seconds, and the share of power in each band.

import com.smartoire.brainwave.R
import androidx.compose.ui.res.stringResource
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.kit.Band
import com.smartoire.brainwave.kit.Electrode
import com.smartoire.brainwave.kit.TraceBuffer
import kotlin.math.pow

private const val WINDOW_SECONDS = 4.0

/// One colour per electrode, shared by the traces and the bars. Mirrors Color.of in App/BrainwaveApp.swift.
private fun electrodeColor(e: Electrode): Color = when (e) {
    Electrode.TP9 -> Color(0.45f, 0.75f, 1.0f)
    Electrode.AF7 -> Color(0.55f, 0.95f, 0.65f)
    Electrode.AF8 -> Color(1.0f, 0.78f, 0.40f)
    Electrode.TP10 -> Color(0.95f, 0.55f, 0.85f)
}

@Composable
fun SignalsScreen(traces: Map<Electrode, List<TraceBuffer.Point>>, bands: Map<Band, Map<Electrode, Double>>) {
    // Read the clock every frame so the window glides instead of stepping on each data update.
    var now by remember { mutableStateOf(System.currentTimeMillis() / 1000.0) }
    val baseline = remember { DoubleArray(Electrode.entries.size) { Double.NaN } }
    LaunchedEffect(Unit) {
        while (true) {
            withFrameMillis { now = System.currentTimeMillis() / 1000.0 }
        }
    }
    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
                Section(stringResource(R.string.signals_raw), stringResource(R.string.signals_raw_sub)) {
            Legend()
            Canvas(modifier = Modifier.fillMaxWidth().height(240.dp).padding(top = 8.dp)) {
                val lane = size.height / Electrode.entries.size
                // Drawn one second behind the clock, so the samples have arrived before they are shown.
                val start = now - 1.0 - WINDOW_SECONDS
                Electrode.entries.forEachIndexed { i, e ->
                    if (i > 0) drawLine(Color(0x33888888), Offset(0f, lane * i), Offset(size.width, lane * i), strokeWidth = 1f)
                    val points = traces[e].orEmpty()
                    if (points.size < 2) return@forEachIndexed
                    val mid = lane * (i + 0.5f)
                    // Centre on a slowly moving average, so the line does not jump when points enter or leave the window.
                    val windowMean = points.map { it.microvolts }.average()
                    baseline[i] = if (baseline[i].isNaN()) windowMean else baseline[i] + (windowMean - baseline[i]) * 0.05
                    val mean = baseline[i].toFloat()
                    val path = Path()
                    points.forEachIndexed { k, p ->
                        val x = ((p.time - start) / WINDOW_SECONDS * size.width).toFloat()
                        val y = mid - (p.microvolts - mean).coerceIn(-100f, 100f) / 100f * lane / 2
                        if (k == 0) path.moveTo(x, y) else path.lineTo(x, y)
                    }
                    drawPath(path, electrodeColor(e), style = Stroke(width = 1.5f))
                }
            }
        }
        Section(stringResource(R.string.signals_power), stringResource(R.string.signals_power_sub)) {
            Legend()
            BandBars(bands)
        }
    }
}

@Composable
private fun Section(title: String, subtitle: String, content: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(top = 16.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Text(subtitle, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        Column(modifier = Modifier.fillMaxWidth().padding(top = 4.dp).card().padding(12.dp)) {
            content()
        }
    }
}

@Composable
private fun Legend() {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Electrode.entries.forEach { e -> Text(e.label, style = MaterialTheme.typography.labelMedium, color = electrodeColor(e), fontWeight = FontWeight.Bold) }
    }
}

/// For each band, four bars: one per electrode, the share of that electrode's total power.
@Composable
private fun BandBars(bands: Map<Band, Map<Electrode, Double>>) {
    val shares: Map<Electrode, List<Float>> = Electrode.entries.associateWith { e ->
        val linear = Band.entries.map { b -> 10.0.pow(bands[b]?.get(e) ?: Double.NEGATIVE_INFINITY) }
        val total = linear.sum()
        linear.map { if (total > 0) (it / total).toFloat() else 0f }
    }
    // Bars glide toward each new share instead of jumping on every data update.
    val shown = remember { Array(Electrode.entries.size) { FloatArray(Band.entries.size) } }
    var frame by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        while (true) {
            withFrameMillis { frame = it }
        }
    }
    Canvas(modifier = Modifier.fillMaxWidth().height(200.dp)) {
        frame // read so the bars are redrawn every frame
        val group = size.width / Band.entries.size
        val bar = group / 5f
        Band.entries.forEachIndexed { b, _ ->
            Electrode.entries.forEachIndexed { k, e ->
                val target = shares[e]?.get(b) ?: 0f
                val current = shown[e.ordinal][b] + (target - shown[e.ordinal][b]) * 0.12f
                shown[e.ordinal][b] = current
                val h = current * size.height
                drawRect(electrodeColor(e), topLeft = Offset(b * group + bar * (k + 0.5f), size.height - h), size = Size(bar * 0.8f, h))
            }
        }
    }
    Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) {
        Band.entries.forEach { b -> Text(b.label, style = MaterialTheme.typography.labelSmall, color = Color.Gray) }
    }
}
