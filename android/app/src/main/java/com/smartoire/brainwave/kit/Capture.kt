package com.smartoire.brainwave.kit

// Port of Packages/BrainwaveKit Capture.swift and App/CaptureStore.swift: one recorded window,
// its CSV and JSON exports, and the file store. Format: docs/CAPTURE_FORMAT.md.

import java.time.Instant
import java.util.Locale
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

/// One second of a recording. Power and activation are flattened as band * 4 + electrode;
/// scores follow Metric order; contact follows Electrode order ("good", "ok", "bad" or null).
data class CaptureSample(
    val time: Double,
    val power: List<Double?>,
    val activation: List<Double?>,
    val scores: List<Double?>,
    val contact: List<String?>,
    val movement: Double?,
)

data class Capture(
    val id: String,
    /// Epoch milliseconds.
    val started: Long,
    val device: String,
    /// Length of the window in seconds.
    val duration: Double,
    val samples: List<CaptureSample>,
) {
    /// Activation for one band at one sample. Empty where there is no reading.
    fun activation(band: Band, index: Int): Map<Electrode, Float> {
        val sample = samples.getOrNull(index) ?: return emptyMap()
        return Electrode.entries.mapNotNull { e ->
            sample.activation[band.ordinal * 4 + e.ordinal]?.let { e to it.toFloat() }
        }.toMap()
    }

    /// Activation averaged over the bands that have a reading: the everyday "overall activity".
    fun activity(index: Int): Map<Electrode, Float> {
        val perBand = Band.entries.map { activation(it, index) }.filter { it.isNotEmpty() }
        return Electrode.entries.mapNotNull { e ->
            val values = perBand.mapNotNull { it[e] }
            if (values.isEmpty()) null else e to values.average().toFloat()
        }.toMap()
    }

    /// Seconds with the score at or above the threshold, counted between consecutive samples.
    fun secondsAbove(metric: Metric, threshold: Double = Metric.STATE_THRESHOLD): Double =
        samples.zipWithNext().sumOf { (previous, current) ->
            val score = previous.scores[metric.ordinal]
            if (score != null && score >= threshold) current.time - previous.time else 0.0
        }

    /// Share of readings with movement above the limit, 0 to 1. Null if no movement was recorded.
    fun movementShare(limit: Double = MOVEMENT_LIMIT): Double? {
        val readings = samples.mapNotNull { it.movement }
        if (readings.isEmpty()) return null
        return readings.count { it > limit }.toDouble() / readings.size
    }

    /// Last third minus first third of a score, in points. Null with too few readings.
    fun scoreChange(metric: Metric): Double? {
        val values = samples.mapNotNull { it.scores[metric.ordinal] }
        if (values.size < 6) return null
        val third = values.size / 3
        return values.takeLast(third).average() - values.take(third).average()
    }

    fun csv(): String {
        val header = mutableListOf("time_s")
        Band.entries.forEach { b -> Electrode.entries.forEach { e -> header += "power_${b.name.lowercase()}_${e.name.lowercase()}" } }
        Band.entries.forEach { b -> Electrode.entries.forEach { e -> header += "activation_${b.name.lowercase()}_${e.name.lowercase()}" } }
        Metric.entries.forEach { header += "score_${it.name.lowercase()}" }
        Electrode.entries.forEach { header += "contact_${it.name.lowercase()}" }
        header += "movement_g"

        fun num(v: Double?) = v?.let { String.format(Locale.US, "%.4f", it) } ?: ""
        val lines = mutableListOf(header.joinToString(","))
        for (s in samples) {
            val cells = mutableListOf(String.format(Locale.US, "%.2f", s.time))
            s.power.forEach { cells += num(it) }
            s.activation.forEach { cells += num(it) }
            s.scores.forEach { cells += num(it) }
            s.contact.forEach { cells += it ?: "" }
            cells += num(s.movement)
            lines += cells.joinToString(",")
        }
        return lines.joinToString("\n") + "\n"
    }

    /// The export wrapper from docs/CAPTURE_FORMAT.md: what the file is, then the capture.
    fun toJson(): JSONObject = JSONObject()
        .put("format", "brainwave.capture")
        .put("version", 1)
        .put(
            "capture", JSONObject()
                .put("id", id)
                .put("started", Instant.ofEpochMilli(started).toString())
                .put("device", device)
                .put("duration", duration)
                .put("samples", JSONArray().also { array ->
                    samples.forEach { s ->
                        array.put(
                            JSONObject()
                                .put("time", s.time)
                                .put("power", s.power.toJsonArray())
                                .put("activation", s.activation.toJsonArray())
                                .put("scores", s.scores.toJsonArray())
                                .put("contact", s.contact.toJsonArray())
                                .put("movement", s.movement ?: JSONObject.NULL)
                        )
                    }
                })
        )

    companion object {
        /// Movement above this (g) makes the scores unreliable.
        const val MOVEMENT_LIMIT = 0.15
    }
}

/// Opens a window, takes one sample a second, and closes it into a [Capture].
/// Times are seconds on the app clock; [start] also takes the wall-clock time for the file.
class CaptureRecorder {
    var startedAt: Double? = null
        private set
    var device = ""
        private set
    private var wallStart = 0L
    private val samples = mutableListOf<CaptureSample>()

    val isRecording: Boolean get() = startedAt != null

    fun start(now: Double, wallMillis: Long, device: String) {
        if (startedAt != null) return
        startedAt = now
        wallStart = wallMillis
        this.device = device
        samples.clear()
    }

    /// Seconds since the window opened, for the sample's time.
    fun elapsed(now: Double): Double = now - (startedAt ?: now)

    fun add(sample: CaptureSample) {
        if (startedAt != null) samples += sample
    }

    /// Closes the window. Null if nothing was recorded.
    fun stop(now: Double): Capture? {
        val begin = startedAt ?: return null
        val recorded = samples.toList()
        startedAt = null
        samples.clear()
        if (recorded.isEmpty()) return null
        return Capture(UUID.randomUUID().toString(), wallStart, device, now - begin, recorded)
    }
}

/// Reads a capture from its export JSON (the wrapper, or a bare capture).
fun parseCapture(text: String): Capture? = try {
    val root = JSONObject(text)
    val c = if (root.has("capture")) root.getJSONObject("capture") else root
    val array = c.getJSONArray("samples")
    Capture(
        id = c.optString("id", UUID.randomUUID().toString()),
        started = Instant.parse(c.getString("started")).toEpochMilli(),
        device = c.optString("device", "Muse"),
        duration = c.getDouble("duration"),
        samples = (0 until array.length()).map { array.getJSONObject(it).toSample() },
    )
} catch (e: Exception) {
    null
}

private fun JSONObject.toSample() = CaptureSample(
    time = getDouble("time"),
    power = doubles("power"),
    activation = doubles("activation"),
    scores = doubles("scores"),
    contact = getJSONArray("contact").let { a -> (0 until a.length()).map { if (a.isNull(it)) null else a.getString(it) } },
    movement = if (isNull("movement")) null else getDouble("movement"),
)

private fun JSONObject.doubles(key: String): List<Double?> =
    getJSONArray(key).let { a -> (0 until a.length()).map { if (a.isNull(it)) null else a.getDouble(it) } }

private fun List<Any?>.toJsonArray(): JSONArray = JSONArray().also { array ->
    forEach { array.put(it ?: JSONObject.NULL) }
}
