package com.smartoire.brainwave.ui

// Port of App/MindStateView.swift: three score cards and the graph of the selected score.

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.smartoire.brainwave.R
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.withFrameMillis
import com.smartoire.brainwave.kit.Metric
import com.smartoire.brainwave.kit.MetricSample
import com.smartoire.brainwave.kit.ScoreTracker
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.delay

/// Card and graph colours, as on iPhone.
fun tint(metric: Metric): Color = when (metric) {
    Metric.FOCUS -> Color(0xFFFF9F45)
    Metric.CALM -> Color(0xFF4CD27A)
    Metric.SLEEPINESS -> Color(0xFF9B8CFF)
}

private const val WINDOW_SECONDS = 600.0   // ten minutes, as on iPhone
private const val RENDER_DELAY = 1.0       // the line is drawn one second behind the clock

/// Plain-language explanation under the graph, as on iPhone (English for now).

@Composable
private fun metricName(m: Metric): String = stringResource(
    when (m) {
        Metric.FOCUS -> R.string.metric_focus
        Metric.CALM -> R.string.metric_calm
        Metric.SLEEPINESS -> R.string.metric_sleepiness
    },
)

/// The state word for a score: the high or low word of that metric, or Steady in between.
@Composable
private fun stateWord(m: Metric, score: Double): String = stringResource(
    when {
        score >= Metric.STATE_THRESHOLD -> when (m) { Metric.FOCUS -> R.string.state_focused; Metric.CALM -> R.string.state_calm; Metric.SLEEPINESS -> R.string.state_sleepy }
        score <= 35 -> when (m) { Metric.FOCUS -> R.string.state_distracted; Metric.CALM -> R.string.state_stressed; Metric.SLEEPINESS -> R.string.state_alert }
        else -> R.string.state_steady
    },
)

@Composable
private fun explanationText(m: Metric): String = stringResource(
    when (m) {
        Metric.FOCUS -> R.string.explain_focus
        Metric.CALM -> R.string.explain_calm
        Metric.SLEEPINESS -> R.string.explain_sleepiness
    },
)

@Composable
fun MindScreen(tracker: ScoreTracker, scores: Map<Metric, Double?>, tick: Int, connected: Boolean, clockStart: Long) {
    var selected by remember { mutableStateOf(Metric.FOCUS) }
    BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        if (maxWidth > maxHeight) {
            // Landscape: the three state cards stacked on the left, the description and graph on the right.
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxSize()) {
                Column(
                    modifier = Modifier.weight(0.4f).fillMaxHeight().walkthroughTarget("mind"),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(stringResource(R.string.mind_title), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    // All three cards visible at once: each takes an equal share of the height, in a compact layout.
                    Metric.entries.forEach { metric ->
                        ScoreCard(
                            metric = metric,
                            score = scores[metric],
                            selected = metric == selected,
                            connected = connected,
                            modifier = Modifier.fillMaxWidth().weight(1f).clickable { selected = metric },
                            compact = true,
                        )
                    }
                }
                Column(modifier = Modifier.weight(0.6f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                    Text(metricName(selected), style = MaterialTheme.typography.titleMedium, color = tint(selected), fontWeight = FontWeight.SemiBold)
                                        Spacer(Modifier.height(12.dp))
                    Graph(samples = tracker.samples(selected), tint = tint(selected), clockStart = clockStart)
                }
            }
        } else {
            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                Text(stringResource(R.string.mind_title), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.walkthroughTarget("mind")) {
                    Metric.entries.forEach { metric ->
                        ScoreCard(
                            metric = metric,
                            score = scores[metric],
                            selected = metric == selected,
                            connected = connected,
                            modifier = Modifier.weight(1f).clickable { selected = metric },
                        )
                    }
                }
                Spacer(Modifier.height(16.dp))
                Text(metricName(selected), style = MaterialTheme.typography.titleMedium, color = tint(selected), fontWeight = FontWeight.SemiBold)
                                Spacer(Modifier.height(12.dp))
                Graph(samples = tracker.samples(selected), tint = tint(selected), clockStart = clockStart)
            }
        }
    }
}

@Composable
private fun ScoreCard(metric: Metric, score: Double?, selected: Boolean, connected: Boolean, modifier: Modifier, compact: Boolean = false) {
    // A moving average of the score: the number and the gauge glide, instead of following every update.
    val average = remember { DoubleArray(1) { Double.NaN } }
    if (score != null) average[0] = if (average[0].isNaN()) score else average[0] + (score - average[0]) * 0.05
    // The first score appears at once; only later changes glide.
    val anim = remember { androidx.compose.animation.core.Animatable(0f) }
    val target = if (average[0].isNaN()) 0f else average[0].toFloat()
    var seen by remember { mutableStateOf(false) }
    LaunchedEffect(target) {
        if (!seen && target > 0f) {
            anim.snapTo(target)
            seen = true
        } else {
            anim.animateTo(target, tween(1500))
        }
    }
    val shown = anim.value
    val frame = modifier
        .card()
        .border(if (selected) BorderStroke(2.dp, tint(metric)) else BorderStroke(0.dp, Color.Transparent), RoundedCornerShape(14.dp))
        .padding(horizontal = 12.dp, vertical = if (compact) 8.dp else 12.dp)
    if (compact) {
        // Landscape: the name and number on the left, the gauge on the right, no caption.
        Row(modifier = frame.padding(horizontal = 0.dp, vertical = 0.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.Center) {
                Text(metricName(metric), color = tint(metric), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge, maxLines = 1)
                Text(
                    if (score == null) "—" else "${shown.toInt()}",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
            ScoreGauge(value = shown, tint = tint(metric), modifier = Modifier.weight(1f))
        }
        return
    }
    Column(modifier = frame) {
        Text(metricName(metric), color = tint(metric), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall, maxLines = 1)
        // A fixed slot for the number, so its width and the values changing do not move the gauge.
        Box(modifier = Modifier.fillMaxWidth().height(60.dp).padding(top = 4.dp), contentAlignment = Alignment.CenterStart) {
            Text(
                if (score == null) "—" else "${shown.toInt()}",
                fontSize = 44.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        ScoreGauge(value = shown, tint = tint(metric), modifier = Modifier.padding(top = 4.dp))
        // A fixed two-line slot for the caption, so a longer or shorter caption does not move the card.
        Box(modifier = Modifier.fillMaxWidth().height(36.dp)) {
            Text(
                score?.let { stateWord(metric, it) } ?: if (connected) stringResource(R.string.learning_baseline) else stringResource(R.string.connect_headband_short),
                style = MaterialTheme.typography.bodySmall,
                maxLines = 2,
            )
        }
    }
}

/// Smoothing as on iPhone: each point averages itself with the four before it.
private fun smoothed(samples: List<MetricSample>): List<Pair<Double, Double>> =
    samples.indices.map { i ->
        val window = maxOf(0, i - 4)..i
        val score = window.sumOf { samples[it].score } / window.count()
        samples[i].time to score
    }

/// The line up to time t, ending exactly at t by interpolating between the two samples around it.
private fun shown(points: List<Pair<Double, Double>>, t: Double): List<Pair<Double, Double>> {
    val past = points.filter { it.first <= t }
    val before = past.lastOrNull() ?: return emptyList()
    val after = points.firstOrNull { it.first > t } ?: return past
    if (after.first <= before.first) return past
    val f = (t - before.first) / (after.first - before.first)
    return past + (t to (before.second + (after.second - before.second) * f))
}

/// The last ten minutes of one score: a 0-100 scale on the right, a dashed baseline at 50,
/// clock times along the bottom. Drawn every frame, so the line glides between seconds.
@Composable
internal fun Graph(samples: List<MetricSample>, tint: Color, clockStart: Long) {
    var now by remember { mutableStateOf(0.0) }
    LaunchedEffect(Unit) {
        while (true) {
            withFrameMillis { now = (System.currentTimeMillis() - clockStart) / 1000.0 }
        }
    }
    val t = now - RENDER_DELAY
    val left = t - WINDOW_SECONDS
    val points = remember(samples) { smoothed(samples) }
    val line = shown(points, t)
    val clockFormat = remember { SimpleDateFormat("HH:mm:ss", Locale.getDefault()) }
    val labelStyle = MaterialTheme.typography.labelSmall

    Box(modifier = Modifier.fillMaxWidth().height(210.dp).card()) {
        Canvas(modifier = Modifier.fillMaxSize().padding(start = 12.dp, top = 12.dp, end = 44.dp, bottom = 34.dp)) {
            val dash = PathEffect.dashPathEffect(floatArrayOf(10f, 10f))
            val grid = Color(0x33888888)
            listOf(0.0, 25.0, 50.0, 75.0, 100.0).forEach { v ->
                val y = (size.height * (1 - v / 100)).toFloat()
                drawLine(grid, Offset(0f, y), Offset(size.width, y), strokeWidth = 1f,
                    pathEffect = if (v == 50.0) dash else null)
            }
            if (line.size >= 2) {
                val path = Path()
                line.forEachIndexed { i, (time, score) ->
                    val x = ((time - left) / WINDOW_SECONDS * size.width).toFloat()
                    val y = (size.height * (1 - score / 100)).toFloat()
                    if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                // Three colours by level, matching the gauge zones: the metric colour for high, amber for steady, red for low.
                    val levels = Brush.verticalGradient(
                        colorStops = arrayOf(0f to tint, 0.5f to Color(0xFFF6C453), 1f to Color(0xFFE57373)),
                        startY = 0f,
                        endY = size.height,
                    )
                    drawPath(path, levels, style = Stroke(width = 4f))
            }
        }
        // Y labels on the right, as on iPhone.
        listOf(0, 25, 50, 75, 100).forEach { v ->
            Text(
                "$v",
                style = labelStyle,
                color = Color.Gray,
                modifier = Modifier.align(Alignment.TopEnd).padding(top = 12.dp, end = 6.dp)
                    .offset(y = (260 - 46 - 12) .dp * (1f - v / 100f) - 6.dp),
            )
        }
        // Clock labels along the bottom, five across the window.
        SlidingClockLabels(
            left, t, clockStart,
            Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(start = 12.dp, end = 44.dp, bottom = 8.dp),
        )
        // Drawn last so it sits above the grid while the graph is empty.
        if (samples.isEmpty()) {
            Text(
                stringResource(R.string.graph_starts_mind),
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray,
                textAlign = TextAlign.Center,
                modifier = Modifier.align(Alignment.Center).padding(horizontal = 24.dp),
            )
        }
    }
}
