package com.smartoire.brainwave.ui

// Port of App/CompareView.swift (live headband only): how two areas of the head compare over time.
// The saved-capture review and the advanced band picker are not ported yet.

import androidx.compose.ui.res.stringResource
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.offset
import kotlin.math.ceil
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.smartoire.brainwave.R
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.kit.Area
import com.smartoire.brainwave.kit.BrainRegion
import com.smartoire.brainwave.kit.ActivityFrame
import com.smartoire.brainwave.kit.ComparedMoment
import com.smartoire.brainwave.kit.ComparisonSummary
import com.smartoire.brainwave.kit.comparedSeries
import java.util.Date
import java.util.Locale
import java.text.SimpleDateFormat
import kotlin.math.abs

private val firstColor = Color(0xFF00E5FF)   // cyan, as on iPhone
private val secondColor = Color(0xFFFF9800)  // orange
private const val RENDER_DELAY = 1.0          // the lines are drawn one second behind the clock

/// The four comparisons, in the order of the iPhone tiles.
enum class Comparison(val title: String) {
    LEFT_RIGHT("Left vs right"), FRONT_TEMPORAL("Front vs back"), LEFT_SIDE("Left side"), RIGHT_SIDE("Right side");

    /// The two areas set against each other. Mirrors ComparisonKind.areas in BrainRegion.swift.
    fun areas(): Pair<Area, Area> = when (this) {
        LEFT_RIGHT -> Area("Left side", listOf(BrainRegion.LEFT_FRONTAL, BrainRegion.LEFT_TEMPORAL)) to
            Area("Right side", listOf(BrainRegion.RIGHT_FRONTAL, BrainRegion.RIGHT_TEMPORAL))
        FRONT_TEMPORAL -> Area("Frontal", listOf(BrainRegion.LEFT_FRONTAL, BrainRegion.RIGHT_FRONTAL)) to
            Area("Temporal", listOf(BrainRegion.LEFT_TEMPORAL, BrainRegion.RIGHT_TEMPORAL))
        LEFT_SIDE -> Area("Left frontal", listOf(BrainRegion.LEFT_FRONTAL)) to Area("Left temporal", listOf(BrainRegion.LEFT_TEMPORAL))
        RIGHT_SIDE -> Area("Right frontal", listOf(BrainRegion.RIGHT_FRONTAL)) to Area("Right temporal", listOf(BrainRegion.RIGHT_TEMPORAL))
    }

    /// Quarters from top-left, top-right, bottom-left, bottom-right: cyan is the first area, orange the second.
    val quarters: List<Color?>
        get() = when (this) {
            LEFT_RIGHT -> listOf(firstColor, secondColor, firstColor, secondColor)
            FRONT_TEMPORAL -> listOf(firstColor, firstColor, secondColor, secondColor)
            LEFT_SIDE -> listOf(firstColor, null, secondColor, null)
            RIGHT_SIDE -> listOf(null, firstColor, null, secondColor)
        }
}

/// How much history the chart shows. Mirrors TimeSpan in CompareView.swift.
enum class Span(val label: String, val seconds: Double?) {
    MINUTE("1 m", 60.0), QUARTER_HOUR("15 m", 900.0), HOUR("1 h", 3600.0), ALL("All", null)
}

private data class Smoothed(val time: Double, val first: Double, val second: Double)

/// Live comparison of two areas, from the activity history the Root keeps (about one hour).
@Composable
fun CompareScreen(frames: List<ActivityFrame>, origin: Long) {
    var comparison by remember { mutableStateOf(Comparison.LEFT_RIGHT) }
    var span by remember { mutableStateOf(Span.MINUTE) }
    var now by remember { mutableStateOf(0.0) }
    LaunchedEffect(Unit) {
        while (true) {
            withFrameMillis { now = (System.currentTimeMillis() - origin) / 1000.0 }
        }
    }

    val (first, second) = comparison.areas()
    val moments = remember(frames, comparison) { comparedSeries(frames, first, second) }
    val points = remember(moments) { smoothed(moments) }
    val t = now - RENDER_DELAY
    val line = shown(points, t)

    // The visible window in seconds: the last span, or everything recorded so far.
    val left: Double
    val right: Double
    val seconds = span.seconds
    if (seconds != null) {
        left = t - seconds
        right = t
    } else {
        left = moments.firstOrNull()?.time ?: 0.0
        right = maxOf(t, left + 1)
    }

    BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        val landscape = maxWidth > maxHeight
        val tilesPanel: @Composable (Boolean) -> Unit = { vertical ->
            if (vertical) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    Comparison.entries.forEach { option ->
                        ComparisonTile(option, selected = option == comparison, modifier = Modifier.fillMaxWidth()) { comparison = option }
                    }
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    Comparison.entries.forEach { option ->
                        ComparisonTile(option, selected = option == comparison, modifier = Modifier.weight(1f)) { comparison = option }
                    }
                }
            }
        }
        val seg: @Composable () -> Unit = {
            Segmented(
                options = Span.entries.map { it to spanLabel(it) },
                selected = span,
                onSelect = { span = it },
                modifier = Modifier.fillMaxWidth(),
            )
        }
        // The summary card: the gauge at rest with the connect message, or the real summary once data arrives.
        val summary: @Composable () -> Unit = {
            if (moments.isEmpty()) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().card().padding(12.dp),
                ) {
                    CompareGauge(firstShare = 0.5f, firstColour = firstColor, secondColour = secondColor, modifier = Modifier.weight(0.42f))
                    Text(
                        stringResource(R.string.compare_connect_hint),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(0.58f).padding(start = 8.dp),
                    )
                }
            } else {
                SummaryCard(ComparisonSummary.of(moments), first, second)
            }
        }
        // The graph: the same as the Mind page when empty, and the two areas over time when data arrives.
        val graphPanel: @Composable (Modifier, Dp) -> Unit = { mod, canvasHeight ->
            if (moments.isEmpty()) {
                Graph(samples = emptyList(), tint = firstColor, clockStart = origin)
            } else {
                Column(modifier = mod.card().padding(12.dp)) {
                    Text(stringResource(R.string.compare_activity), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(top = 4.dp)) {
                        LegendDot(areaLabel(first.name), firstColor)
                        LegendDot(areaLabel(second.name), secondColor)
                    }
                    Text(stringResource(R.string.compare_usual), style = MaterialTheme.typography.labelSmall, color = Color.Gray, modifier = Modifier.padding(top = 4.dp))
                    Canvas(modifier = Modifier.fillMaxWidth().height(canvasHeight).padding(top = 4.dp)) {
                        fun x(time: Double) = ((time - left) / (right - left) * size.width).toFloat()
                        fun y(z: Double) = (size.height * (1 - (z + 3) / 6)).toFloat()
                        drawLine(
                            Color(0x55FFFFFF), Offset(0f, y(0.0)), Offset(size.width, y(0.0)), strokeWidth = 1f,
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 10f)),
                        )
                        if (line.size >= 2) {
                            val a = Path()
                            val b = Path()
                            line.forEachIndexed { i, p ->
                                if (i == 0) {
                                    a.moveTo(x(p.time), y(p.first)); b.moveTo(x(p.time), y(p.second))
                                } else {
                                    a.lineTo(x(p.time), y(p.first)); b.lineTo(x(p.time), y(p.second))
                                }
                            }
                            drawPath(a, firstColor, style = Stroke(width = 4f))
                            drawPath(b, secondColor, style = Stroke(width = 4f))
                        }
                    }
                    SlidingClockLabels(left, right, origin, Modifier.fillMaxWidth())
                }
            }
        }
        val sentence: @Composable () -> Unit = {
            if (moments.isNotEmpty()) {
                moments.last().let { latest ->
                    Text(
                        comparisonSentence(first, second, latest.first, latest.second),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
        val note: @Composable () -> Unit = {
            Text(
                stringResource(R.string.compare_note),
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray,
            )
        }
        if (landscape) {
            // Landscape: the tiles, time range and summary on the left, the graph on the right.
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxSize()) {
                Column(modifier = Modifier.weight(0.4f).fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    tilesPanel(true)
                    seg()
                    summary()
                    sentence()
                    note()
                }
                Column(modifier = Modifier.weight(0.6f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                    graphPanel(Modifier.fillMaxWidth(), 220.dp)
                }
            }
        } else {
            // Portrait: one page, no scrolling. The same order for empty and data: tiles, time range, summary, graph, sentence.
            Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                tilesPanel(false)
                seg()
                summary()
                graphPanel(Modifier.fillMaxWidth(), 150.dp)
                sentence()
            }
        }
    }
}

/// The tile title for a comparison, read from the resources.
@Composable
private fun comparisonTitle(option: Comparison): String = stringResource(
    when (option) {
        Comparison.LEFT_RIGHT -> R.string.compare_tile_lr
        Comparison.FRONT_TEMPORAL -> R.string.compare_tile_ft
        Comparison.LEFT_SIDE -> R.string.compare_tile_ls
        Comparison.RIGHT_SIDE -> R.string.compare_tile_rs
    },
)

/// The time-range label for a span, read from the resources.
@Composable
private fun spanLabel(span: Span): String = stringResource(
    when (span) {
        Span.MINUTE -> R.string.compare_span_1m
        Span.QUARTER_HOUR -> R.string.compare_span_15m
        Span.HOUR -> R.string.compare_span_1h
        Span.ALL -> R.string.compare_span_all
    },
)

/// An area name, read from the resources. Unknown names are shown as they are.
@Composable
private fun areaLabel(name: String): String = when (name) {
    "Frontal" -> stringResource(R.string.area_frontal)
    "Temporal" -> stringResource(R.string.area_temporal)
    "Left side" -> stringResource(R.string.area_left_side)
    "Right side" -> stringResource(R.string.area_right_side)
    "Left frontal" -> stringResource(R.string.area_left_frontal)
    "Left temporal" -> stringResource(R.string.area_left_temporal)
    "Right frontal" -> stringResource(R.string.area_right_frontal)
    "Right temporal" -> stringResource(R.string.area_right_temporal)
    else -> name
}

@Composable
private fun ComparisonTile(option: Comparison, selected: Boolean, modifier: androidx.compose.ui.Modifier, onPick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.card().then(if (selected) Modifier.border(2.dp, Brush.horizontalGradient(listOf(Color(0xFFF6A36B), Color(0xFFE94E89))), RoundedCornerShape(22.dp)) else Modifier).clickable(onClick = onPick).padding(vertical = 8.dp),
    ) {
        // As on iPhone: a faint brain outline, with the four coloured quarters masked to the brain shape.
        val mask = ImageBitmap.imageResource(R.drawable.brain_top)
        Box(modifier = Modifier.size(56.dp)) {
            Image(
                painter = painterResource(R.drawable.brain_top),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxSize(),
                alpha = 0.3f,
            )
            Canvas(modifier = Modifier.fillMaxSize().graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)) {
                val half = size.width / 2
                option.quarters.forEachIndexed { i, color ->
                    if (color != null) {
                        val x = if (i % 2 == 0) 0f else half
                        val y = if (i < 2) 0f else half
                        drawRect(color.copy(alpha = if (selected) 1f else 0.55f), Offset(x, y), Size(half, half))
                    }
                }
                val scale = minOf(size.width / mask.width, size.height / mask.height)
                val w = mask.width * scale
                val h = mask.height * scale
                val left = (size.width - w) / 2f
                val top = (size.height - h) / 2f
                drawImage(
                    image = mask,
                    dstOffset = IntOffset(left.toInt(), top.toInt()),
                    dstSize = IntSize(w.toInt(), h.toInt()),
                    blendMode = BlendMode.DstIn,
                )
                // DstIn only clears inside the brain image's rectangle, so clear the margins too.
                drawRect(Color.Black, Offset.Zero, Size(size.width, top), blendMode = BlendMode.Clear)
                drawRect(Color.Black, Offset(0f, top + h), Size(size.width, size.height - top - h), blendMode = BlendMode.Clear)
                drawRect(Color.Black, Offset.Zero, Size(left, size.height), blendMode = BlendMode.Clear)
                drawRect(Color.Black, Offset(left + w, 0f), Size(size.width - left - w, size.height), blendMode = BlendMode.Clear)
            }
        }
        Text(comparisonTitle(option), style = MaterialTheme.typography.labelSmall, fontWeight = if (selected) FontWeight.Bold else null, maxLines = 2, modifier = Modifier.padding(top = 4.dp))
        // A plain dot marks the chosen comparison: no border, so it does not look like a Mind card.
        Box(
            modifier = Modifier.padding(top = 4.dp).size(width = 30.dp, height = 4.dp).clip(RoundedCornerShape(2.dp))
                .background(if (selected) Brush.horizontalGradient(listOf(Color(0xFFF6A36B), Color(0xFFE94E89))) else Brush.horizontalGradient(listOf(Color.Transparent, Color.Transparent))),
        )
    }
}

/// Clock times along a time axis. Each label is pinned to a round clock time and slides as the window moves;
/// a label is hidden once it would run past either end.
@Composable
fun SlidingClockLabels(left: Double, right: Double, origin: Long, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier = modifier.height(16.dp)) {
        val span = right - left
        val step = listOf(5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0).firstOrNull { it * 5 >= span } ?: 3600.0
        var t = ceil(left / step) * step
        while (t <= right) {
            val fraction = ((t - left) / span).toFloat()
            if (fraction in 0.06f..0.92f) {
                Text(
                    clockLabel(origin, t),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Gray,
                    modifier = Modifier.offset(x = maxWidth * fraction - 20.dp),
                )
            }
            t += step
        }
    }
}

@Composable
private fun LegendDot(name: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(modifier = Modifier.size(10.dp).clip(RoundedCornerShape(5.dp)).background(color))
        Spacer(Modifier.width(4.dp))
        Text(name, style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
private fun SummaryCard(summary: ComparisonSummary, first: Area, second: Area) {
    val percent = (summary.firstHigherShare * 100).toInt()
    val lead = when {
        abs(summary.averageDifference) < 0.2 -> stringResource(R.string.lead_level)
        else -> {
            val who = areaLabel(if (summary.averageDifference > 0) first.name else second.name).lowercase()
            if (abs(summary.averageDifference) < 0.6) stringResource(R.string.lead_little, who)
            else stringResource(R.string.lead_clear, who)
        }
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(top = 16.dp).card().padding(12.dp),
    ) {
        // The gauge shows how often the first area led: the needle sits at that share.
        CompareGauge(firstShare = summary.firstHigherShare.toFloat(), firstColour = firstColor, secondColour = secondColor, modifier = Modifier.weight(0.42f))
        Column(modifier = Modifier.weight(0.58f).padding(start = 8.dp)) {
            Text(stringResource(R.string.summary_more, areaLabel(first.name), percent), fontWeight = FontWeight.SemiBold)
            Text(
                stringResource(R.string.summary_otherwise, areaLabel(second.name).lowercase(), lead),
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}

/// One plain sentence comparing two areas, from the resources. Mirrors comparisonSentence in BrainRegion.swift.
@Composable
private fun comparisonSentence(a: Area, b: Area, zA: Double, zB: Double): String {
    val difference = zA - zB
    val less = if (difference > 0) b else a
    val more = if (difference > 0) a else b
    val lessName = areaLabel(less.name).lowercase()
    return when {
        abs(difference) <= 0.4 -> stringResource(R.string.sent_equal, areaLabel(a.name), areaLabel(b.name).lowercase())
        abs(difference) > 1 -> stringResource(R.string.sent_much, areaLabel(more.name), lessName)
        else -> stringResource(R.string.sent_little, areaLabel(more.name), lessName)
    }
}

/// Each point averaged with up to four seconds before it, so the lines glide. Mirrors CompareView.smoothed.
private fun smoothed(moments: List<ComparedMoment>): List<Smoothed> = moments.indices.map { i ->
    val from = maxOf(0, i - 4)
    val count = (i - from + 1).toDouble()
    var first = 0.0
    var second = 0.0
    for (j in from..i) {
        first += moments[j].first
        second += moments[j].second
    }
    Smoothed(moments[i].time, first / count, second / count)
}

/// The lines up to time t, ending exactly at t by interpolating between the two seconds around it.
private fun shown(points: List<Smoothed>, t: Double): List<Smoothed> {
    val past = points.filter { it.time <= t }
    val before = past.lastOrNull() ?: return emptyList()
    val after = points.firstOrNull { it.time > t } ?: return past
    if (after.time <= before.time) return past
    val f = (t - before.time) / (after.time - before.time)
    return past + Smoothed(t, before.first + (after.first - before.first) * f, before.second + (after.second - before.second) * f)
}

private fun clockLabel(origin: Long, seconds: Double): String =
    SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(origin + (seconds * 1000).toLong()))
