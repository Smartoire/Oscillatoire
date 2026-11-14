package com.smartoire.brainwave.ui

// Material 3 theme shared by every screen: light, dark, or the system setting, as chosen in Settings.

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import android.app.Activity
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.clickable
import androidx.compose.ui.Alignment

private val brandPurple = Color(0xFF8E7CFF)

@Composable
fun BrainwaveTheme(appearance: String, content: @Composable () -> Unit) {
    val dark = when (appearance) {
        "light" -> false
        "system" -> isSystemInDarkTheme()
        else -> true  // dark is the default, as on iPhone
    }
    val scheme = if (dark) {
        darkColorScheme(primary = Color(0xFFB8A9FF), onPrimary = Color(0xFF1B1140), surface = Color(0xFF1E2230), background = Color(0xFF1E2230), onSurface = Color(0xFFF2F3F7), onBackground = Color(0xFFF2F3F7))
    } else {
        lightColorScheme(primary = Color(0xFF6750A4), surface = Color(0xFFF7F8FB), background = Color(0xFFF7F8FB))
    }
    // Dark status-bar icons on light screens, light icons on dark screens.
    val view = LocalView.current
    SideEffect {
        (view.context as? Activity)?.window?.let { window ->
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !dark
        }
    }
    // Default text colour follows the theme: light text on dark screens, dark text on light screens.
    CompositionLocalProvider(LocalContentColor provides scheme.onBackground) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

@Composable
private fun isDark(): Boolean = MaterialTheme.colorScheme.background.luminance() < 0.5f

/// Background for a card: a soft white card in light mode, a translucent dark card in dark mode.
@Composable
fun panelColor(): Color =
    if (isDark()) Color(0xFF2A2F40) else Color.White

/// Every card: rounded, with a soft shadow in light mode. Use instead of clip + background.
@Composable
fun Modifier.card(radius: Dp = 22.dp): Modifier {
    val shape = RoundedCornerShape(radius)
    val color = panelColor()
    return this.shadow(elevation = if (isDark()) 0.dp else 6.dp, shape = shape, clip = false)
        .clip(shape)
        .background(color)
}

/// The app backdrop: a soft base colour with large translucent shapes behind the cards, as in the design references.
@Composable
fun Modifier.appBackground(): Modifier {
    val dark = isDark()
    val base = if (dark) Color(0xFF1E2230) else Color(0xFFF3F0FF)
    val shapes = if (dark) {
        listOf(Color(0xFF3B2F7A), Color(0xFF1E4450), Color(0xFF2A1F45))
    } else {
        listOf(Color(0xFFD9CFFF), Color(0xFFFFD9EC), Color(0xFFCFEFFF))
    }
    return this.drawBehind {
        drawRect(base)
        val w = size.width
        val h = size.height
        drawCircle(shapes[0].copy(alpha = 0.7f), radius = w * 0.55f, center = Offset(w * 0.1f, h * 0.12f))
        drawCircle(shapes[1].copy(alpha = 0.6f), radius = w * 0.45f, center = Offset(w * 0.95f, h * 0.45f))
        drawCircle(shapes[2].copy(alpha = 0.6f), radius = w * 0.6f, center = Offset(w * 0.2f, h * 0.9f))
    }
}

/// A row of connected choices, one selected. Used for every "pick one of a few" control.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> Segmented(options: List<Pair<T, String>>, selected: T, onSelect: (T) -> Unit, modifier: Modifier = Modifier) {
    SingleChoiceSegmentedButtonRow(modifier = modifier.fillMaxWidth()) {
        options.forEachIndexed { i, (value, label) ->
            SegmentedButton(
                selected = value == selected,
                onClick = { onSelect(value) },
                shape = SegmentedButtonDefaults.itemShape(index = i, count = options.size),
            ) { Text(label, maxLines = 1) }
        }
    }
}

/// The app's main button: a gradient pill with white bold text, matching the Calm card. Greyed when disabled.
@Composable
fun BrandButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    val fill = if (enabled) Brush.horizontalGradient(listOf(Color(0xFFF6A36B), Color(0xFFE94E89)))
    else Brush.horizontalGradient(listOf(Color.Gray.copy(alpha = 0.4f), Color.Gray.copy(alpha = 0.4f)))
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(fill)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 24.dp, vertical = 14.dp),
        content = {
            androidx.compose.material3.ProvideTextStyle(MaterialTheme.typography.titleMedium.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)) {
                androidx.compose.material3.LocalContentColor.current
                content()
            }
        },
    )
}
