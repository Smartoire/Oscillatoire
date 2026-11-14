package com.smartoire.brainwave.ui

// The start screen: the Brainwave icon with its name appears in the middle, then the icon shrinks and
// moves down into the menu button's place, and the app appears straight away.

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.R
import kotlinx.coroutines.delay

@Composable
fun Splash(onDone: () -> Unit) {
    val appear = remember { Animatable(0f) }
    val move = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        appear.animateTo(1f, tween(700))
        delay(1100)
        move.animateTo(1f, tween(900, easing = FastOutSlowInEasing))
        onDone()
    }
    // The same backdrop as the app, so the splash follows the light or dark setting.
    BoxWithConstraints(
        Modifier.fillMaxSize().appBackground(),
    ) {
        val density = LocalDensity.current
        // The icon's centre travels from the middle of the screen to the menu button, 52 dp above the bottom.
        val travelPx = with(density) { (maxHeight / 2f - 52.dp).toPx() }
        val startSize = 160.dp
        val endSize = 38.dp
        val p = move.value
        val scale = 1f + (endSize / startSize - 1f) * p
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .align(Alignment.Center)
                .graphicsLayer {
                    translationY = travelPx * p
                    scaleX = scale
                    scaleY = scale
                    alpha = appear.value
                },
        ) {
            Image(
                painter = painterResource(R.drawable.brand_splash),
                contentDescription = "Brainwave",
                contentScale = ContentScale.Fit,
                modifier = Modifier.size(startSize),
            )
            Spacer(Modifier.height(16.dp))
            Text(
                "Brainwave",
                // The same colours as the wave in the logo: cyan, green, yellow, orange, pink.
                style = MaterialTheme.typography.headlineMedium.copy(
                    brush = Brush.horizontalGradient(
                        listOf(Color(0xFF4DD0E1), Color(0xFFA5E08A), Color(0xFFF5C84C), Color(0xFFF5894C), Color(0xFFE94E89)),
                    ),
                ),
                modifier = Modifier.graphicsLayer { alpha = 1f - p },
            )
        }
    }
}
