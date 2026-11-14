package com.smartoire.brainwave.ui

// A lotus icon for the Calm session: three petals rising from a flat base on the water.
// It takes the tint of the surrounding Icon.

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

val LotusIcon: ImageVector by lazy {
    ImageVector.Builder(
        name = "Lotus",
        defaultWidth = 24.dp,
        defaultHeight = 24.dp,
        viewportWidth = 24f,
        viewportHeight = 24f,
    )
        // The tall centre petal.
        .addPath(
            pathData = addPathNodes("M12 3 C9.2 6.5 9.2 11.5 12 14.5 C14.8 11.5 14.8 6.5 12 3 Z"),
            fill = SolidColor(Color.Black),
        )
        // The left petal.
        .addPath(
            pathData = addPathNodes("M11 14 C7.5 13.5 4.8 10.8 5 6.8 C8.4 7.2 10.6 10 11 14 Z"),
            fill = SolidColor(Color.Black),
        )
        // The right petal.
        .addPath(
            pathData = addPathNodes("M13 14 C16.5 13.5 19.2 10.8 19 6.8 C15.6 7.2 13.4 10 13 14 Z"),
            fill = SolidColor(Color.Black),
        )
        // The water line under the flower.
        .addPath(
            pathData = addPathNodes("M3.5 17 C7 15.4 9.5 15.4 12 16.6 C14.5 15.4 17 15.4 20.5 17 C17.5 19.8 6.5 19.8 3.5 17 Z"),
            fill = SolidColor(Color.Black),
        )
        .build()
}
