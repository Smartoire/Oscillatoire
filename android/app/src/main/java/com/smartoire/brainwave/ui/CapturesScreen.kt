package com.smartoire.brainwave.ui

// Port of App/CaptureViews.swift: the saved captures, a timeline review of one, and the
// Save / Cancel / Download review shown when a recording stops. The brain map and Compare link
// are not ported yet.

import android.content.ClipData
import android.content.Context
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.draw.alpha
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material3.Icon
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import com.smartoire.brainwave.R
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.smartoire.brainwave.kit.Capture
import com.smartoire.brainwave.kit.CaptureStore
import com.smartoire.brainwave.kit.Electrode
import com.smartoire.brainwave.kit.Metric
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

private val gridColor = Color(0x33888888)

/// The saved captures, newest first. Tap one to review it.
@Composable
fun CapturesScreen(
    captures: List<Capture>,
    message: String?,
    recordingSeconds: Double?,
    connected: Boolean,
    onToggleRecording: () -> Unit,
    onImport: () -> Unit,
    onDelete: (Capture) -> Unit,
) {
    val context = LocalContext.current
    var viewing by remember { mutableStateOf<Capture?>(null) }
    var pendingDelete by remember { mutableStateOf<Capture?>(null) }

    viewing?.let { capture ->
        BackHandler { viewing = null }
        CaptureDetail(capture, toolbar = {
            TextButton(onClick = { viewing = null }) { Text(stringResource(R.string.cap_back)) }
            Spacer(Modifier.weight(1f))
            BrandButton(onClick = { shareCapture(context, capture) }) { Text(stringResource(R.string.cap_share)) }
        })
        return
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState())) {
        message?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 8.dp)) }

        if (captures.isNotEmpty()) {
            Text(
                "${captures.size} saved",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.padding(top = 16.dp, bottom = 4.dp),
            )
        }
        if (captures.isEmpty()) {
            Text(
                stringResource(R.string.cap_none),
                color = Color.Gray,
                modifier = Modifier.padding(top = 16.dp).fillMaxWidth().card().padding(16.dp),
            )
        }
        captures.forEach { capture ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).clip(RoundedCornerShape(14.dp))
                    .card().clickable { viewing = capture }.padding(12.dp),
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(formatDate(capture.started), fontWeight = FontWeight.SemiBold)
                    Text("${clock(capture.duration)} · ${capture.device}", style = MaterialTheme.typography.bodySmall)
                }
                TextButton(onClick = { pendingDelete = capture }) { Text(stringResource(R.string.cap_delete), color = MaterialTheme.colorScheme.error) }
            }
        }
    }

    pendingDelete?.let { target ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text(stringResource(R.string.cap_delete_q)) },
            text = { Text(stringResource(R.string.cap_delete_body)) },
            confirmButton = {
                TextButton(onClick = { onDelete(target); pendingDelete = null }) { Text(stringResource(R.string.cap_delete), color = Color.Red) }
            },
            dismissButton = { TextButton(onClick = { pendingDelete = null }) { Text(stringResource(R.string.cap_cancel)) } },
        )
    }
}

/// Shown when a recording stops. Not saved yet: Save keeps it, Cancel throws it away, Download writes a JSON file.
@Composable
fun FinishedCaptureScreen(capture: Capture, onCancel: () -> Unit, onSave: () -> Unit, onDownload: () -> Unit) {
    CaptureDetail(capture, note = stringResource(R.string.cap_not_saved), toolbar = {
        TextButton(onClick = onCancel) { Text(stringResource(R.string.cap_cancel)) }
        Spacer(Modifier.weight(1f))
        TextButton(onClick = onDownload) { Text(stringResource(R.string.cap_download)) }
        BrandButton(onClick = onSave) { Text(stringResource(R.string.cap_save)) }
    })
}

/// Timeline review of one capture: summary, the scores over time with a scrubber, and the activity at that moment.
@Composable
fun CaptureDetail(capture: Capture, note: String? = null, toolbar: @Composable RowScope.() -> Unit) {
    val samples = capture.samples
    var position by remember(capture) { mutableFloatStateOf(0f) }
    var metric by remember { mutableStateOf(Metric.FOCUS) }
    val index = position.toInt().coerceIn(0, (samples.size - 1).coerceAtLeast(0))
    val current = samples.getOrNull(index)

    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) { toolbar() }
        note?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Color.Gray, modifier = Modifier.padding(top = 4.dp)) }
        Text(formatDate(capture.started), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
        Text("${clock(capture.duration)} · ${capture.device}", style = MaterialTheme.typography.bodySmall)

        if (samples.isEmpty()) {
            Text(stringResource(R.string.cap_no_data), color = Color.Gray, modifier = Modifier.padding(top = 16.dp))
            return@Column
        }

        Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
            Metric.entries.forEach { m -> Stat(m.high, clock(capture.secondsAbove(m)), Modifier.weight(1f)) }
            capture.movementShare()?.let { Stat(stringResource(R.string.cap_moving), "${(it * 100).roundToInt()}%", Modifier.weight(1f)) }
        }
        Metric.entries.forEach { m ->
            capture.scoreChange(m)?.let { Text(trend(m, it), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 8.dp)) }
        }
        Text(
            stringResource(R.string.cap_state_note),
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(top = 4.dp),
        )

        Column(modifier = Modifier.fillMaxWidth().padding(top = 16.dp).card().padding(12.dp)) {
            Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp)) {
                Metric.entries.forEach { m ->
                    BrandButton(onClick = { metric = m }) { Text(if (m == metric) "● ${m.label}" else m.label) }
                }
            }
            Row(modifier = Modifier.fillMaxWidth().height(200.dp).padding(top = 12.dp)) {
                Canvas(modifier = Modifier.weight(1f).fillMaxHeight()) {
                    val total = maxOf(capture.duration, 1.0)
                    fun x(t: Double) = (t / total * size.width).toFloat()
                    fun y(v: Double) = (size.height * (1 - v / 100)).toFloat()
                    val dash = PathEffect.dashPathEffect(floatArrayOf(10f, 10f))
                    listOf(0.0, 25.0, 50.0, 75.0, 100.0).forEach { v ->
                        drawLine(gridColor, Offset(0f, y(v)), Offset(size.width, y(v)), strokeWidth = 1f,
                            pathEffect = if (v == 50.0) dash else null)
                    }
                    val points = samples.mapNotNull { s -> s.scores[metric.ordinal]?.let { s.time to it } }
                    if (points.size >= 2) {
                        val path = Path()
                        points.forEachIndexed { i, (t, v) -> if (i == 0) path.moveTo(x(t), y(v)) else path.lineTo(x(t), y(v)) }
                        drawPath(path, tint(metric), style = Stroke(width = 4f))
                    }
                    current?.let { c ->
                        drawLine(Color.White.copy(alpha = 0.7f), Offset(x(c.time), 0f), Offset(x(c.time), size.height), strokeWidth = 2f)
                    }
                }
                Column(
                    modifier = Modifier.fillMaxHeight().padding(start = 6.dp),
                    verticalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
                ) {
                    listOf(100, 75, 50, 25, 0).forEach { Text("$it", style = MaterialTheme.typography.labelSmall, color = Color.Gray) }
                }
            }
            Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                (0..4).forEach { i -> Text(clock(capture.duration * i / 4), style = MaterialTheme.typography.labelSmall, color = Color.Gray) }
            }
            Slider(
                value = position,
                onValueChange = { position = it },
                valueRange = 0f..maxOf(samples.size - 1, 1).toFloat(),
                modifier = Modifier.padding(top = 4.dp),
            )
            Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text(clock(current?.time ?: 0.0), style = MaterialTheme.typography.labelSmall)
                Text(clock(capture.duration), style = MaterialTheme.typography.labelSmall)
            }
        }

        Column(modifier = Modifier.fillMaxWidth().padding(top = 16.dp).card().padding(12.dp)) {
            Text("Overall activity at this moment", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            val values = capture.activity(index)
            if (values.isEmpty()) {
                Text(stringResource(R.string.cap_no_reading), modifier = Modifier.padding(top = 8.dp))
            } else {
                Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                    Electrode.entries.forEach { e ->
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(e.label, fontWeight = FontWeight.Bold)
                            Text(values[e]?.let { String.format(Locale.US, "%+.1f σ", it) } ?: "—")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Stat(title: String, value: String, modifier: Modifier) {
    Column(modifier = modifier.card().padding(8.dp)) {
        Text(title, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    }
}

/// How one score moved over a capture, in plain words.
private fun trend(metric: Metric, change: Double): String = when {
    change < -5 -> "${metric.label} eased over the session, by about ${(-change).toInt()} points."
    change >= 5 -> "${metric.label} rose over the session, by about ${change.toInt()} points."
    else -> "${metric.label} held about steady over the session."
}

/// Opens the share sheet with the CSV and JSON copies of one capture.
fun shareCapture(context: Context, capture: Capture) {
    val uris = CaptureStore.exportFiles(context, capture).map {
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", it)
    }
    val clip = ClipData.newUri(context.contentResolver, "Capture", uris.first())
    uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
    val send = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
        type = "*/*"
        putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        clipData = clip
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(send, context.getString(R.string.cap_share_title)))
}

/// "1:05" or "1:02:03".
fun clock(seconds: Double): String {
    val total = seconds.toLong()
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s) else String.format(Locale.US, "%d:%02d", m, s)
}

private fun formatDate(millis: Long): String =
    SimpleDateFormat("d MMM yyyy, HH:mm", Locale.getDefault()).format(Date(millis))
