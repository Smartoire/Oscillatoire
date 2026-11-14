package com.smartoire.brainwave.ui

// A simple sensor icon: a ring with a small wave line inside, in the style of the brain logo.
// It takes the tint of the surrounding Icon, so it can show the connection colour.

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

val HeadsetIcon: ImageVector by lazy {
    ImageVector.Builder(
        name = "Sensor",
        defaultWidth = 24.dp,
        defaultHeight = 24.dp,
        viewportWidth = 24f,
        viewportHeight = 24f,
    )
        // The ring.
        .addPath(
            pathData = addPathNodes("M12 2.5 A9.5 9.5 0 1 1 11.99 2.5 Z"),
            stroke = SolidColor(Color.Black),
            strokeLineWidth = 2f,
        )
        // The wave inside the ring.
        .addPath(
            pathData = addPathNodes("M5.5 12 Q7.75 8 10 12 T14.5 12 T19 12"),
            stroke = SolidColor(Color.Black),
            strokeLineWidth = 2f,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round,
        )
        .build()
}
