package com.smartoire.brainwave.ui

// The navigation fan. Press the menu button and the screens open in an arc above it. Slide the finger
// over a screen to highlight it, then lift to go there. A quick tap keeps the arc open until you choose.

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.Icon
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import com.smartoire.brainwave.R
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import android.content.res.Configuration
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.sin

private const val BUTTON_DP = 56f
private const val RADIUS_DP = 150f
private const val BOTTOM_DP = 24f
private const val EDGE_DP = 16f

@Composable
fun BoxScope.NavFan(
    items: List<Pair<String, ImageVector>>,
    current: String,
    connected: Boolean,
    open: Boolean,
    onOpenChange: (Boolean) -> Unit,
    onPick: (String) -> Unit,
    labels: Map<String, String> = emptyMap(),
) {
    val density = LocalDensity.current
    val landscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
    val arcColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f)
    val radiusPx = with(density) { RADIUS_DP.dp.toPx() }
    val hitPx = with(density) { 36.dp.toPx() }
    val touchSlop = LocalViewConfiguration.current.touchSlop
    var hovered by remember { mutableIntStateOf(-1) }
    val isOpen by rememberUpdatedState(open)
    val pick by rememberUpdatedState(onPick)
    val setOpen by rememberUpdatedState(onOpenChange)

    // Each screen sits on an arc from the upper left to the upper right, above the button.
    fun angleOf(i: Int): Double = Math.PI * (0.84 - 0.68 * i.toDouble() / (items.size - 1))
    // Portrait: the arc goes over the button. Landscape: the arc goes to the left of the button, which sits at the
    // middle of the right edge, so the screens run from above to below it.
    fun targetOf(i: Int): Offset {
        val a = angleOf(i)
        return if (landscape) Offset((-radiusPx * sin(a)).toFloat(), (radiusPx * cos(a)).toFloat())
        else Offset((radiusPx * cos(a)).toFloat(), (-radiusPx * sin(a)).toFloat())
    }

    AnimatedVisibility(
        visible = open,
        modifier = Modifier.fillMaxSize(),
        enter = fadeIn(tween(220)) + scaleIn(tween(300), initialScale = 0.5f, transformOrigin = TransformOrigin(0.5f, 1f)),
        exit = fadeOut(tween(180)) + scaleOut(tween(220), targetScale = 0.5f, transformOrigin = TransformOrigin(0.5f, 1f)),
    ) {
        // Dims the screen; tapping outside the fan closes it.
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)).clickable { setOpen(false) })
        Canvas(Modifier.fillMaxSize()) {
            // The anchor is the centre of the menu button: the bottom padding plus half the button.
            val c = if (landscape) Offset(size.width - (EDGE_DP + BUTTON_DP / 2f) * density.density, size.height / 2f)
                else Offset(size.width / 2f, size.height - (BOTTOM_DP + BUTTON_DP / 2f) * density.density)
            val backdrop = radiusPx + 26f * density.density
            drawArc(
                color = arcColor,
                startAngle = if (landscape) 90f else 180f,
                sweepAngle = 180f,
                useCenter = true,
                topLeft = Offset(c.x - backdrop, c.y - backdrop),
                size = Size(backdrop * 2f, backdrop * 2f),
            )
            drawArc(
                color = Color.Gray.copy(alpha = 0.25f),
                startAngle = if (landscape) 90f else 180f,
                sweepAngle = 180f,
                useCenter = false,
                topLeft = Offset(c.x - radiusPx, c.y - radiusPx),
                size = Size(radiusPx * 2f, radiusPx * 2f),
                style = Stroke(width = 1.5f * density.density),
            )
        }
        // The screens on the arc. The one under the finger grows and fills in.
        // Laid out left-to-right: Modifier.offset is mirrored in right-to-left, which would flip the arc away from the finger's hit test.
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        BoxWithConstraints(
            Modifier.fillMaxSize().padding(bottom = if (landscape) 0.dp else (BOTTOM_DP + BUTTON_DP / 2f).dp),
            // Landscape offsets are absolute, so the items start at the top left. Portrait keeps the bottom centre.
            contentAlignment = if (landscape) Alignment.TopStart else Alignment.BottomCenter,
        ) {
            items.forEachIndexed { i, (title, icon) ->
                val t = targetOf(i)
                val isHover = hovered == i
                val scale by animateFloatAsState(if (isHover) 1.22f else 1f, label = "fanScale")
                val selected = current == title
                val fill = when {
                    isHover -> MaterialTheme.colorScheme.primary
                    selected -> MaterialTheme.colorScheme.primaryContainer
                    else -> MaterialTheme.colorScheme.surface
                }
                val tint = if (isHover) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
                // The circle centre sits on the arc point; the label hangs below it.
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .width(64.dp)
                        .then(
                            if (landscape) {
                                Modifier.offset(
                                    x = maxWidth - (EDGE_DP + BUTTON_DP / 2f).dp - 32.dp + with(density) { t.x.toDp() },
                                    y = maxHeight / 2f - 26.dp + with(density) { t.y.toDp() },
                                )
                            } else {
                                Modifier.offset(x = with(density) { t.x.toDp() }, y = with(density) { t.y.toDp() } + 50.dp)
                            },
                        )
                        .graphicsLayer(scaleX = scale, scaleY = scale),
                ) {
                    Box(
                        Modifier.size(52.dp).clip(CircleShape).background(fill),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(icon, contentDescription = title, tint = tint)
                    }
                    Text(
                        labels[title] ?: title,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = if (isHover) FontWeight.Bold else null,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
        }
    }

    // The menu button. Press to open, slide to a screen, lift to go there. A quick tap toggles the arc.
    Box(
        Modifier
            .align(if (landscape) Alignment.CenterEnd else Alignment.BottomCenter)
            .padding(end = if (landscape) EDGE_DP.dp else 0.dp)
            .padding(bottom = if (landscape) 0.dp else BOTTOM_DP.dp)
            .size(BUTTON_DP.dp)
            .walkthroughTarget("menu")
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primaryContainer)
            .pointerInput(items) {
                awaitPointerEventScope {
                    while (true) {
                        val down = awaitFirstDown()
                        val wasOpen = isOpen
                        val start = down.position
                        var moved = false
                        hovered = -1
                        setOpen(true)
                        while (true) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull() ?: break
                            if ((change.position - start).getDistance() > touchSlop) moved = true
                            // The nearest screen within reach of the finger is highlighted.
                            val anchorX = if (landscape) size.width - (EDGE_DP + BUTTON_DP / 2f) * density.density else size.width / 2f
                            val rel = change.position - Offset(anchorX, size.height / 2f)
                            var best = -1
                            var bestDist = hitPx
                            items.indices.forEach { i ->
                                val d = (targetOf(i) - rel).getDistance()
                                if (d < bestDist) {
                                    bestDist = d
                                    best = i
                                }
                            }
                            hovered = best
                            if (!change.pressed) break
                        }
                        val chosen = hovered
                        hovered = -1
                        when {
                            chosen >= 0 -> {
                                pick(items[chosen].first)
                                setOpen(false)
                            }
                            !moved && wasOpen -> setOpen(false)
                            !moved -> setOpen(true)
                            else -> setOpen(false)
                        }
                    }
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Image(painterResource(R.drawable.brand_mark), contentDescription = "Menu", modifier = Modifier.size(38.dp).clip(CircleShape))
        // A small dot shows the headband status: green when connected, grey when not.
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .size(10.dp)
                .clip(CircleShape)
                .background(if (connected) Color(0xFF34C759) else Color.Gray),
        )
    }
}
