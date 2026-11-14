package com.smartoire.brainwave.ui

// Port of App/SettingsTab.swift and AppSettings.swift: appearance, language, calm options, Muse SDK and About.
// Each option is a card. Switches are cards that show On or Off by colour.

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.R

/// Saved settings, as on iPhone (UserDefaults there, SharedPreferences here).
object Prefs {
    private const val FILE = "brainwave"
    fun get(context: Context, key: String, default: String): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(key, default) ?: default
    fun set(context: Context, key: String, value: String) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putString(key, value).apply()
    fun flag(context: Context, key: String, default: Boolean): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(key, default)
    fun setFlag(context: Context, key: String, value: Boolean) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean(key, value).apply()
}

private val languages = listOf(
    "en" to "English", "fa" to "فارسی", "fr" to "Français", "nl" to "Nederlands", "ar" to "العربية",
    "zh-Hans" to "中文（简体）", "hi" to "हिन्दी", "es" to "Español", "ru" to "Русский", "de" to "Deutsch", "ja" to "日本語",
)
private val onColour = Color(0xFF34C759)
private val offColour = Color(0xFF8E8E93)
private val accent = Color(0xFFE94E89)

@Composable
fun SettingsScreen(advanced: Boolean, onAdvanced: (Boolean) -> Unit, onAppearance: (String) -> Unit = {}, onOpenAdvanced: () -> Unit = {}, onLanguage: (String) -> Unit = {}) {
    val context = LocalContext.current
    var appearance by remember { mutableStateOf(Prefs.get(context, "appearance", "dark")) }
    var language by remember { mutableStateOf(Prefs.get(context, "language", "en")) }
    var sound by remember { mutableStateOf(Prefs.flag(context, "calmSound", true)) }
    var volume by remember { mutableStateOf(Prefs.get(context, "calmVolume", "medium")) }
    var pace by remember { mutableStateOf(Prefs.get(context, "calmPace", "standard")) }
    var kind by remember { mutableStateOf(Prefs.get(context, "calmKind", "tones")) }
    val kindLevels = listOf(
        "tones" to stringResource(R.string.sound_tones),
        "sea" to stringResource(R.string.sound_sea),
        "wind" to stringResource(R.string.sound_wind),
        "birds" to stringResource(R.string.sound_birds),
    )
    var showLanguages by remember { mutableStateOf(false) }
    val volumeLevels = listOf("soft" to stringResource(R.string.level_soft), "medium" to stringResource(R.string.level_medium), "full" to stringResource(R.string.level_full))
    val paceLevels = listOf("slow" to stringResource(R.string.pace_slow), "standard" to stringResource(R.string.pace_standard), "quick" to stringResource(R.string.pace_quick))

    BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(start = 16.dp, end = 16.dp, top = 24.dp, bottom = 16.dp)) {
        val wide = maxWidth > maxHeight
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(stringResource(R.string.settings_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            if (wide) {
                // Landscape: two columns, so each one fits the height of the phone.
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionTitle(stringResource(R.string.section_appearance))
        Card {
            Segmented(
                options = listOf("dark" to stringResource(R.string.appearance_dark), "light" to stringResource(R.string.appearance_light), "system" to stringResource(R.string.appearance_system)),
                selected = appearance,
                onSelect = { appearance = it; Prefs.set(context, "appearance", it); onAppearance(it) },
            )
        }

        SectionTitle(stringResource(R.string.section_language))
        LinkCard(
            title = languages.firstOrNull { it.first == language }?.second ?: stringResource(R.string.settings_english),
            subtitle = stringResource(R.string.language_tap),
            onClick = { showLanguages = true },
        )

        SectionTitle(stringResource(R.string.section_calm))
        ToggleCard(
            title = stringResource(R.string.soundscape),
            subtitle = stringResource(R.string.soundscape_subtitle),
            enabled = sound,
            onClick = { sound = !sound; Prefs.setFlag(context, "calmSound", sound) },
        )
        Card {
            SliderRow(
                title = stringResource(R.string.sound_kind),
                options = kindLevels,
                selected = kind,
                onSelect = { kind = it; Prefs.set(context, "calmKind", it) },
            )
        }
        Card {
            SliderRow(
                title = stringResource(R.string.sound_level),
                options = volumeLevels,
                selected = volume,
                onSelect = { volume = it; Prefs.set(context, "calmVolume", it) },
            )
        }
        Card {
            SliderRow(
                title = stringResource(R.string.breathing_pace),
                options = paceLevels,
                selected = pace,
                onSelect = { pace = it; Prefs.set(context, "calmPace", it) },
            )
            Text(
                stringResource(R.string.pace_note),
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray,
            )
        }

                    }
                    Column(modifier = Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionTitle(stringResource(R.string.section_advanced))
        ToggleCard(
            title = stringResource(R.string.advanced_view),
            subtitle = stringResource(R.string.advanced_view_subtitle),
            enabled = advanced,
            onClick = { onAdvanced(!advanced) },
        )

        SectionTitle(stringResource(R.string.section_muse))
        Card {
            Text(stringResource(R.string.muse_sdk_line), style = MaterialTheme.typography.bodyMedium)
            Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                LogoBadge(R.drawable.logo_vg, "Vahid Ghafarpour", "https://vahid.ghafarpour.com/")
                LogoBadge(R.drawable.logo_smartoire, "Smartoire", "https://smartoire.com/")
                LogoBadge(R.drawable.logo_bcai, "BC+AI Lifescience", "https://bc-ai.ca/communities/life-sciences-ai")
                LogoBadge(R.drawable.logo_muse, "Muse", "https://choosemuse.com/pages/developers")
            }
        }

        SectionTitle(stringResource(R.string.walk_intro_title))
        LinkCard(title = stringResource(R.string.walk_again), subtitle = "") { Prefs.setFlag(context, "walkthroughDone", false) }

        SectionTitle(stringResource(R.string.section_about))
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(
                    painter = painterResource(R.drawable.brand_mark),
                    contentDescription = null,
                    modifier = Modifier.size(56.dp).clip(CircleShape),
                )
                Column(modifier = Modifier.padding(start = 14.dp)) {
                    Text("Brainwave", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.about_formerly), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                }
            }
            Text(stringResource(R.string.about_vibe), style = MaterialTheme.typography.bodySmall)
            Text(
                stringResource(R.string.about_disclaimer),
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray,
            )
        }
                    }
                }
            } else {
                Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionTitle(stringResource(R.string.section_appearance))
        Card {
            Segmented(
                options = listOf("dark" to stringResource(R.string.appearance_dark), "light" to stringResource(R.string.appearance_light), "system" to stringResource(R.string.appearance_system)),
                selected = appearance,
                onSelect = { appearance = it; Prefs.set(context, "appearance", it); onAppearance(it) },
            )
        }

        SectionTitle(stringResource(R.string.section_language))
        LinkCard(
            title = languages.firstOrNull { it.first == language }?.second ?: stringResource(R.string.settings_english),
            subtitle = stringResource(R.string.language_tap),
            onClick = { showLanguages = true },
        )

        SectionTitle(stringResource(R.string.section_calm))
        ToggleCard(
            title = stringResource(R.string.soundscape),
            subtitle = stringResource(R.string.soundscape_subtitle),
            enabled = sound,
            onClick = { sound = !sound; Prefs.setFlag(context, "calmSound", sound) },
        )
        Card {
            SliderRow(
                title = stringResource(R.string.sound_kind),
                options = kindLevels,
                selected = kind,
                onSelect = { kind = it; Prefs.set(context, "calmKind", it) },
            )
        }
        Card {
            SliderRow(
                title = stringResource(R.string.sound_level),
                options = volumeLevels,
                selected = volume,
                onSelect = { volume = it; Prefs.set(context, "calmVolume", it) },
            )
        }
        Card {
            SliderRow(
                title = stringResource(R.string.breathing_pace),
                options = paceLevels,
                selected = pace,
                onSelect = { pace = it; Prefs.set(context, "calmPace", it) },
            )
            Text(
                stringResource(R.string.pace_note),
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray,
            )
        }

        SectionTitle(stringResource(R.string.section_advanced))
        ToggleCard(
            title = stringResource(R.string.advanced_view),
            subtitle = stringResource(R.string.advanced_view_subtitle),
            enabled = advanced,
            onClick = { onAdvanced(!advanced) },
        )

        SectionTitle(stringResource(R.string.section_muse))
        Card {
            Text(stringResource(R.string.muse_sdk_line), style = MaterialTheme.typography.bodyMedium)
            Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                LogoBadge(R.drawable.logo_vg, "Vahid Ghafarpour", "https://vahid.ghafarpour.com/")
                LogoBadge(R.drawable.logo_smartoire, "Smartoire", "https://smartoire.com/")
                LogoBadge(R.drawable.logo_bcai, "BC+AI Lifescience", "https://bc-ai.ca/communities/life-sciences-ai")
                LogoBadge(R.drawable.logo_muse, "Muse", "https://choosemuse.com/pages/developers")
            }
        }

        SectionTitle(stringResource(R.string.walk_intro_title))
        LinkCard(title = stringResource(R.string.walk_again), subtitle = "") { Prefs.setFlag(context, "walkthroughDone", false) }

        SectionTitle(stringResource(R.string.section_about))
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(
                    painter = painterResource(R.drawable.brand_mark),
                    contentDescription = null,
                    modifier = Modifier.size(56.dp).clip(CircleShape),
                )
                Column(modifier = Modifier.padding(start = 14.dp)) {
                    Text("Brainwave", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.about_formerly), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                }
            }
            Text(stringResource(R.string.about_vibe), style = MaterialTheme.typography.bodySmall)
            Text(
                stringResource(R.string.about_disclaimer),
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray,
            )
        }
                }
            }
        }
    }

    if (showLanguages) {
        AlertDialog(
            onDismissRequest = { showLanguages = false },
            title = { Text(stringResource(R.string.language_title), fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    languages.forEach { (code, name) ->
                        val chosen = code == language
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                                .clip(RoundedCornerShape(14.dp))
                                .background(if (chosen) accent.copy(alpha = 0.18f) else Color.Transparent)
                                .clickable {
                                    language = code
                                    Prefs.set(context, "language", code)
                                    onLanguage(code)
                                    showLanguages = false
                                }
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                        ) {
                            Text(name, modifier = Modifier.weight(1f), fontWeight = if (chosen) FontWeight.Bold else null)
                            if (chosen) Icon(Icons.Filled.Check, contentDescription = stringResource(R.string.settings_selected), tint = accent)
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { showLanguages = false }) { Text(stringResource(R.string.close)) } },
        )
    }
}

private fun open(context: Context, url: String) {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 6.dp))
}

/// A rounded card in the same style as the rest of the app.
@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().card().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
}

/// A card you can tap to switch an option on or off. The pill shows On in green or Off in grey.
@Composable
private fun ToggleCard(title: String, subtitle: String, enabled: Boolean, onClick: () -> Unit) {
    val state = if (enabled) onColour else offColour
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().card().clickable(onClick = onClick).padding(16.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.clip(RoundedCornerShape(50)).background(state.copy(alpha = 0.18f)).padding(horizontal = 12.dp, vertical = 6.dp),
        ) {
            Text(if (enabled) stringResource(R.string.settings_on) else stringResource(R.string.settings_off), color = state, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge)
        }
    }
}

/// A card you can tap to open something.
@Composable
private fun LinkCard(title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().card().clickable(onClick = onClick).padding(16.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
        Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, tint = Color.Gray)
    }
}

/// A slider with one step per level. The chosen level's name shows beside the title.
@Composable
private fun SliderRow(title: String, options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    val index = options.indexOfFirst { it.first == selected }.coerceAtLeast(0)
    var position by remember(selected) { mutableFloatStateOf(index.toFloat()) }
    val shown = options[position.toInt().coerceIn(0, options.lastIndex)].second
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Text(shown, color = accent, fontWeight = FontWeight.Bold)
        }
        Slider(
            value = position,
            onValueChange = { position = it },
            onValueChangeFinished = { onSelect(options[position.toInt().coerceIn(0, options.lastIndex)].first) },
            valueRange = 0f..options.lastIndex.toFloat(),
            steps = options.size - 2,
        )
        Row(modifier = Modifier.fillMaxWidth()) {
            options.forEachIndexed { i, (_, label) ->
                Text(
                    label,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Gray,
                    textAlign = when (i) {
                        0 -> TextAlign.Start
                        options.lastIndex -> TextAlign.End
                        else -> TextAlign.Center
                    },
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

/// One logo from the site's own favicon. Tapping it opens the site.
@Composable
private fun LogoBadge(logo: Int, description: String, url: String) {
    val context = LocalContext.current
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.size(width = 74.dp, height = 64.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.9f))
            .clickable { open(context, url) },
    ) {
        Image(
            painter = painterResource(logo),
            contentDescription = description,
            modifier = Modifier.size(40.dp),
        )
    }
}
