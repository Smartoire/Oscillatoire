package com.smartoire.brainwave.ui

// Port of App/CalmSessionView.swift: a breathing guide, the calm time, and a Done button.
// The soundscape is not ported yet.

import androidx.compose.animation.core.LinearEasing
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.smartoire.brainwave.R
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.kit.Metric
import kotlinx.coroutines.delay

private val cyan = Color(0xFF59E6FF)

@Composable
fun CalmScreen(calmScore: Double?, onDone: () -> Unit) {
    val context = LocalContext.current
    val pace = when (Prefs.get(context, "calmPace", "standard")) { "slow" -> 6000; "quick" -> 4000; else -> 5000 }
    // The soundscape plays while this page is open, if Settings has it on.
    DisposableEffect(Unit) {
        val sound = CalmSound(
            when (Prefs.get(context, "calmVolume", "medium")) { "soft" -> 0.3f; "full" -> 1f; else -> 0.6f },
            cycleSeconds = pace * 2 / 1000.0,
            kind = CalmKind.of(Prefs.get(context, "calmKind", "tones")),
        )
        if (Prefs.flag(context, "calmSound", true)) sound.start()
        onDispose { sound.stop() }
    }
    var elapsed by remember { mutableIntStateOf(0) }
    var calm by remember { mutableIntStateOf(0) }
    var steady by remember { mutableIntStateOf(0) }
    var stressed by remember { mutableIntStateOf(0) }
    val latest by rememberUpdatedState(calmScore)
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            elapsed += 1
            // Each second with a score goes into one of three states: calm, steady or stressed.
            when (val s = latest) {
                null -> Unit
                else -> when {
                    s >= Metric.STATE_THRESHOLD -> calm += 1
                    s <= 35.0 -> stressed += 1
                    else -> steady += 1
                }
            }
        }
    }
    val transition = rememberInfiniteTransition(label = "breath")
    // One breath cycle: 0 to 1 is the breath in (the petals grow), 1 back to 0 is the breath out (they close).
    val phase by transition.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(pace * 2, easing = LinearEasing), RepeatMode.Restart),
        label = "phase",
    )
    // Smooth size: closed at the start, fully open at the peak, closed again at the end of the cycle.
    val inhale = 0.5f - 0.5f * kotlin.math.cos(2f * kotlin.math.PI.toFloat() * phase)
    // The label changes only at the peak, after the petals have finished growing.
    val breathingIn = phase < 0.5f

    val total = (calm + steady + stressed).coerceAtLeast(0)
    val calmShare = if (total > 0) calm.toFloat() / total else 1f / 3f
    val steadyShare = if (total > 0) steady.toFloat() / total else 1f / 3f
    val stressedShare = if (total > 0) stressed.toFloat() / total else 1f / 3f
    val calmColour = Color(0xFF3DDC97)
    val steadyColour = Color(0xFFF6C453)
    val stressedColour = Color(0xFFE94E89)
    val wordBrush = Brush.horizontalGradient(listOf(Color(0xFFF6A36B), Color(0xFFE94E89), Color(0xFF59E6FF)))

    // The lotus with a big coloured IN or OUT on top of it.
    val lotus: @Composable (Modifier) -> Unit = { modifier ->
        Box(modifier = modifier, contentAlignment = Alignment.Center) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val centre = Offset(size.width / 2, size.height * 0.74f)
                val r = size.minDimension / 2 * (0.5f + 0.15f * inhale)
                drawCircle(brush = Brush.radialGradient(listOf(cyan.copy(alpha = 0.35f), Color.Transparent), center = centre, radius = r * 1.6f), radius = r * 1.6f, center = centre)
                val spread = (22f + 22f * inhale) * Math.PI.toFloat() / 180f
                val length = r * (0.85f + 0.25f * inhale)
                val width = length * 0.36f
                listOf(-2, -1, 0, 1, 2).forEach { k ->
                    val a = k * spread
                    fun pt(x: Float, y: Float) = Offset(
                        centre.x + x * kotlin.math.cos(a) - y * kotlin.math.sin(a),
                        centre.y + x * kotlin.math.sin(a) + y * kotlin.math.cos(a),
                    )
                    val petal = androidx.compose.ui.graphics.Path().apply {
                        val base = pt(0f, 0f)
                        moveTo(base.x, base.y)
                        val c1 = pt(width, -length * 0.3f); val c2 = pt(width, -length * 0.8f); val tip = pt(0f, -length)
                        cubicTo(c1.x, c1.y, c2.x, c2.y, tip.x, tip.y)
                        val c3 = pt(-width, -length * 0.8f); val c4 = pt(-width, -length * 0.3f)
                        cubicTo(c3.x, c3.y, c4.x, c4.y, base.x, base.y)
                        close()
                    }
                    drawPath(petal, color = cyan.copy(alpha = if (k == 0) 0.85f else 0.6f))
                }
            }
            // A fixed slot, so IN and OUT never move the lotus.
            Box(modifier = Modifier.align(Alignment.TopCenter).width(220.dp).height(96.dp), contentAlignment = Alignment.Center) {
                Text(
                    if (breathingIn) stringResource(R.string.calm_in) else stringResource(R.string.calm_out),
                    style = MaterialTheme.typography.displayLarge.copy(brush = wordBrush, fontWeight = FontWeight.Black),
                )
            }
        }
    }

    // The timer as a large counter, and the calm / steady / stressed bar with the state names.
    val statusPanel: @Composable (Modifier) -> Unit = { modifier ->
        Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(stringResource(R.string.calm_session_time), style = MaterialTheme.typography.labelLarge, color = Color.Gray)
            // A fixed slot for the counter, so the digits changing do not move the bar below.
            Box(modifier = Modifier.width(240.dp).height(64.dp), contentAlignment = Alignment.Center) {
                Text(
                    "${elapsed / 60}:${"%02d".format(elapsed % 60)}",
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
            Spacer(Modifier.height(20.dp))
            if (total == 0) {
                // No data yet: a grey bar and a note, until the first scores arrive.
                Row(
                    modifier = Modifier.fillMaxWidth().height(22.dp).clip(RoundedCornerShape(11.dp)).background(Color.Gray.copy(alpha = 0.35f)),
                ) {}
                Spacer(Modifier.height(10.dp))
                Text(stringResource(R.string.calm_collecting), color = Color.Gray, style = MaterialTheme.typography.bodyMedium)
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth().height(22.dp).clip(RoundedCornerShape(11.dp)).background(Color.Gray.copy(alpha = 0.25f)),
                ) {
                    if (calmShare > 0f) Box(Modifier.weight(calmShare).fillMaxHeight().background(calmColour))
                    if (steadyShare > 0f) Box(Modifier.weight(steadyShare).fillMaxHeight().background(steadyColour))
                    if (stressedShare > 0f) Box(Modifier.weight(stressedShare).fillMaxHeight().background(stressedColour))
                }
                Spacer(Modifier.height(10.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.state_calm), color = calmColour, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.state_steady), color = steadyColour, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.state_stressed), color = stressedColour, fontWeight = FontWeight.Bold)
                }
            }
            // The status line always has its space, so it appearing does not move anything.
            Box(modifier = Modifier.fillMaxWidth().height(44.dp).padding(top = 12.dp), contentAlignment = Alignment.TopCenter) {
                if (calmScore != null) {
                    Text(
                        if (calmScore >= Metric.STATE_THRESHOLD) stringResource(R.string.calm_settling) else stringResource(R.string.calm_slow),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }

    BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        if (maxWidth > maxHeight) {
            // Landscape: the lotus on the left, the timer and bar on the right.
            Row(modifier = Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                lotus(Modifier.weight(1f).fillMaxHeight())
                statusPanel(Modifier.weight(1f).fillMaxHeight().padding(start = 16.dp))
            }
        } else {
            // Portrait: the lotus above, the timer and bar below.
            Column(modifier = Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                lotus(Modifier.fillMaxWidth().height(320.dp))
                Spacer(Modifier.height(16.dp))
                statusPanel(Modifier.fillMaxWidth())
            }
        }
    }
}
