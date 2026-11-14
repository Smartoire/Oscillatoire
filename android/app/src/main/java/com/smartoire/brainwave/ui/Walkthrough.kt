package com.smartoire.brainwave.ui

// A short introduction the first time Brainwave opens. Each step dims the screen except the control
// it describes, so the user sees where to tap. Shown once; Settings can show it again.

import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateMap
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.R

/// The places on screen the walkthrough can point at, by name. Filled in as the screen lays out.
val LocalWalkthroughTargets = staticCompositionLocalOf<SnapshotStateMap<String, Rect>> { mutableStateMapOf() }

/// Marks a control so the walkthrough can highlight it.
@Composable
fun Modifier.walkthroughTarget(name: String): Modifier {
    val targets = LocalWalkthroughTargets.current
    return this.onGloballyPositioned { targets[name] = it.boundsInRoot() }
}

private class WalkPage(val target: String?, val title: Int, val text: Int)

@Composable
fun Walkthrough() {
    val context = LocalContext.current
    var done by remember { mutableStateOf(Prefs.flag(context, "walkthroughDone", false)) }
    if (done) return
    val targets = LocalWalkthroughTargets.current
    var step by remember { mutableIntStateOf(0) }
    val pages = remember {
        listOf(
            WalkPage(null, R.string.walk_welcome_title, R.string.walk_welcome_text),
            WalkPage("mind", R.string.walk_mind_title, R.string.walk_mind_text),
            WalkPage("headband", R.string.walk_headband_title, R.string.walk_headband_text),
            WalkPage("calm", R.string.walk_calm_title, R.string.walk_calm_text),
            WalkPage("menu", R.string.walk_menu_title, R.string.walk_menu_text),
        )
    }
    val page = pages[step]
    val finish = {
        Prefs.setFlag(context, "walkthroughDone", true)
        done = true
    }
    val density = LocalDensity.current

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val spot: Rect? = page.target?.let { targets[it] }
        val onTop = spot != null && spot.center.y > with(density) { maxHeight.toPx() } / 2
        val pad = with(density) { 10.dp.toPx() }

        // Dims the whole screen, with a clear window around the control this step describes. Taps on the dim are ignored.
        // The ring is drawn here too: Modifier.offset is mirrored in right-to-left layouts, which would move it.
        val ring = MaterialTheme.colorScheme.primary
        Canvas(
            Modifier
                .fillMaxSize()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                .pointerInput(Unit) { detectTapGestures {} },
        ) {
            drawRect(Color.Black.copy(alpha = 0.62f))
            if (spot != null) {
                drawRoundRect(
                    color = Color.Black,
                    topLeft = Offset(spot.left - pad, spot.top - pad),
                    size = Size(spot.width + 2 * pad, spot.height + 2 * pad),
                    cornerRadius = CornerRadius(16.dp.toPx()),
                    blendMode = BlendMode.Clear,
                )
                drawRoundRect(
                    color = ring,
                    topLeft = Offset(spot.left - pad, spot.top - pad),
                    size = Size(spot.width + 2 * pad, spot.height + 2 * pad),
                    cornerRadius = CornerRadius(16.dp.toPx()),
                    style = Stroke(width = 3.dp.toPx()),
                )
            }
        }

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .padding(20.dp)
                .widthIn(max = 420.dp)
                .fillMaxWidth()
                .align(if (onTop) Alignment.TopCenter else Alignment.BottomCenter),
        ) {
            Column(modifier = Modifier.padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.End) {
                    TextButton(onClick = finish) { Text(stringResource(R.string.walk_skip)) }
                }
                Text(
                    stringResource(page.title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(10.dp))
                Text(
                    stringResource(page.text),
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
                    pages.indices.forEach { i ->
                        Box(
                            Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(if (i == step) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.4f)),
                        )
                    }
                }
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(12.dp)) {
                    if (step > 0) {
                        OutlinedButton(onClick = { step -= 1 }) { Text(stringResource(R.string.walk_back)) }
                    }
                    Button(onClick = { if (step == pages.size - 1) finish() else step += 1 }) {
                        Text(stringResource(if (step == pages.size - 1) R.string.walk_start else R.string.walk_next))
                    }
                }
            }
        }
    }
}
