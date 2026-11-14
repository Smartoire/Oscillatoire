package com.smartoire.brainwave.kit

// Port of Packages/BrainwaveKit (Swift). Pure Kotlin, no Muse SDK, so it can be unit-tested on the JVM.
// Keep these in step with the Swift files: Baseline.swift, Metric.swift, Electrode.swift,
// BrainRegion.swift, Topomap.swift and Comparison.swift.

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.log10
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/// The four Muse EEG electrodes, in the SDK's EEG1...EEG4 order.
enum class Electrode(val label: String, private val polar: Float, private val azimuth: Float, val region: String) {
    TP9("TP9", 108f, -108f, "Left temporal"),
    AF7("AF7", 90f, -36f, "Left frontal"),
    AF8("AF8", 90f, 36f, "Right frontal"),
    TP10("TP10", 108f, 108f, "Right temporal");

    /// Top-down azimuthal-equidistant projection: radius 1 is the ear-to-nose equator, +x is the subject's right, +y the nose.
    val x: Float get() = projectX(polar, azimuth)
    val y: Float get() = projectY(polar, azimuth)
}

enum class Band(val label: String) { DELTA("Delta"), THETA("Theta"), ALPHA("Alpha"), BETA("Beta"), GAMMA("Gamma") }

/// A recursion-free z-score tracker against the person's own recent baseline. Mirrors Baseline.swift.
class Baseline(val warmUp: Int = 50, val memory: Int = 600) {
    private var mean = 0.0
    private var variance = 0.0
    private var count = 0

    /// 0..1 while warming up.
    val progress: Double get() = minOf(1.0, count.toDouble() / warmUp)

    /// Adds a reading and returns its z-score (clamped to -3..3), or null while warming up.
    fun update(value: Double): Double? {
        if (!value.isFinite()) return null
        count += 1
        // Exact running mean and variance at first, then an exponential moving window.
        val alpha = 1.0 / minOf(count, memory).toDouble()
        val delta = value - mean
        mean += alpha * delta
        variance = (1 - alpha) * (variance + alpha * delta * delta)
        if (count < warmUp || variance <= 1e-12) return null
        return ((value - mean) / sqrt(variance)).coerceIn(-3.0, 3.0)
    }
}

/// Mental-state indices from band-power ratios. Mirrors Metric.swift.
enum class Metric(val label: String) {
    FOCUS("Focus"), CALM("Calm"), SLEEPINESS("Sleepiness");

    /// Focus uses the forehead; the others use every electrode.
    val electrodes: List<Electrode>
        get() = if (this == FOCUS) listOf(Electrode.AF7, Electrode.AF8) else Electrode.entries

    /// log10 of the ratio, averaged over usable electrodes. Null if none has the bands needed.
    /// power: absolute band powers in log10 µV², per band and electrode.
    fun index(power: Map<Band, Map<Electrode, Double>>, excluding: Set<Electrode> = emptySet()): Double? {
        val values = electrodes.filter { it !in excluding }.mapNotNull { e ->
            val a = power[Band.ALPHA]?.get(e)
            val b = power[Band.BETA]?.get(e)
            val t = power[Band.THETA]?.get(e)
            if (a == null || b == null || t == null || !a.isFinite() || !b.isFinite() || !t.isFinite()) return@mapNotNull null
            when (this) {
                FOCUS -> b - log10(10.0.pow(a) + 10.0.pow(t))
                CALM -> a - b
                SLEEPINESS -> t - a
            }
        }
        return if (values.isEmpty()) null else values.sum() / values.size
    }

    companion object {
        /// Scores at or above this count as "in the state".
        const val STATE_THRESHOLD = 65.0

        /// 0-100 score from a z-score against the personal baseline: 50 is your usual level.
        fun score(z: Double): Double = 100.0 / (1.0 + exp(-1.2 * z))
    }

    /// Short status for a score: the high or low word, or "Steady" in between.
    fun label(score: Double): String = when {
        score >= STATE_THRESHOLD -> high
        score <= 35 -> low
        else -> "Steady"
    }

    val high: String get() = when (this) { FOCUS -> "Focused"; CALM -> "Calm"; SLEEPINESS -> "Sleepy" }
    val low: String get() = when (this) { FOCUS -> "Distracted"; CALM -> "Stressed"; SLEEPINESS -> "Alert" }
}

/// Four regions of the brain. Mirrors BrainRegion.swift.
enum class BrainRegion(val centreX: Float, val centreY: Float, val electrode: Electrode) {
    LEFT_FRONTAL(-0.4f, 0.5f, Electrode.AF7),
    RIGHT_FRONTAL(0.4f, 0.5f, Electrode.AF8),
    LEFT_TEMPORAL(-0.7f, -0.4f, Electrode.TP9),
    RIGHT_TEMPORAL(0.7f, -0.4f, Electrode.TP10);

    companion object {
        /// The region a point belongs to: left if x < 0, frontal if y >= 0.
        fun at(x: Float, y: Float): BrainRegion = when {
            x < 0 && y >= 0 -> LEFT_FRONTAL
            x >= 0 && y >= 0 -> RIGHT_FRONTAL
            x < 0 -> LEFT_TEMPORAL
            else -> RIGHT_TEMPORAL
        }
    }
}

/// Inverse-distance interpolation of electrode z-scores across the head. Mirrors Topomap.sample in Topomap.swift.
object Topomap {
    private const val REACH = 0.55f

    /// Returns the interpolated z-score at (x, y), and a confidence from the nearest sensor's distance.
    fun sample(values: Map<Electrode, Float>, x: Float, y: Float): Pair<Float, Float> {
        var weighted = 0f
        var total = 0f
        var nearest = Float.POSITIVE_INFINITY
        for ((electrode, z) in values) {
            val dx = x - electrode.x
            val dy = y - electrode.y
            val d2 = dx * dx + dy * dy
            if (d2 < 1e-8f) return Pair(z, 1f)
            weighted += z / d2
            total += 1 / d2
            nearest = minOf(nearest, d2)
        }
        if (total <= 0f) return Pair(0f, 0f)
        return Pair(weighted / total, exp((-nearest / (2 * REACH * REACH)).toDouble()).toFloat())
    }

    /// z-score that gives the strongest colour.
    const val FULL_SCALE = 2.5f

    /// Colour and strength for a z-score: amber to crimson above usual, cyan to indigo below. Mirrors Topomap.color.
    fun color(z: Float): Heat {
        val t = minOf(1f, abs(z) / FULL_SCALE)
        val strength = minOf(1f, t * 2)
        return if (z >= 0) Heat(mix(1f, 0.95f, t), mix(0.80f, 0.12f, t), mix(0.25f, 0.30f, t), strength)
        else Heat(mix(0.35f, 0.25f, t), mix(0.90f, 0.30f, t), 1f, strength)
    }

    private fun mix(a: Float, b: Float, t: Float) = a + (b - a) * t
}

/// A colour for activity: red, green, blue as 0 to 1, and how strongly to show it.
data class Heat(val r: Float, val g: Float, val b: Float, val strength: Float)

/// A set of regions treated as one area, such as "Left side". Mirrors Area in BrainRegion.swift.
data class Area(val name: String, val regions: List<BrainRegion>) {
    /// Average activation over the area's regions, with the lowest confidence among them.
    fun activity(values: Map<Electrode, Float>): Pair<Float, Float> {
        val readings = regions.map { Topomap.sample(values, it.centreX, it.centreY) }
        val z = readings.map { it.first }.sum() / readings.size
        val confidence = readings.minOfOrNull { it.second } ?: 0f
        return Pair(z, confidence)
    }
}

/// One moment of activation: seconds since the start, and a z-score per electrode. Mirrors ActivityFrame.
data class ActivityFrame(val time: Double, val values: Map<Electrode, Float>)

/// Two areas compared at one moment. Mirrors ComparedMoment.
data class ComparedMoment(val time: Double, val first: Double, val second: Double) {
    /// Positive when the first area is the more active one.
    val difference: Double get() = first - second
}

/// Both areas' activity over time. Frames with no readings are skipped. Mirrors comparedSeries.
fun comparedSeries(frames: List<ActivityFrame>, first: Area, second: Area): List<ComparedMoment> =
    frames.filter { it.values.isNotEmpty() }.map { frame ->
        ComparedMoment(frame.time, first.activity(frame.values).first.toDouble(), second.activity(frame.values).first.toDouble())
    }

/// How the two areas relate over a stretch of time. Mirrors ComparisonSummary.
data class ComparisonSummary(val firstHigherShare: Double, val averageDifference: Double) {
    companion object {
        fun of(moments: List<ComparedMoment>): ComparisonSummary {
            if (moments.isEmpty()) return ComparisonSummary(0.0, 0.0)
            val higher = moments.count { it.difference > 0 }.toDouble() / moments.size
            return ComparisonSummary(higher, moments.map { it.difference }.sum() / moments.size)
        }
    }
}

/// Mean of the focus and calm scores, when either is known. Mirrors balanceScore in Insights.swift.
fun balanceScore(focus: Double?, calm: Double?): Double? {
    val known = listOfNotNull(focus, calm)
    return if (known.isEmpty()) null else known.sum() / known.size
}

private fun projectX(polar: Float, azimuth: Float): Float {
    val r = polar / 90f
    return r * sin(azimuth * Math.PI.toFloat() / 180f)
}

private fun projectY(polar: Float, azimuth: Float): Float {
    val r = polar / 90f
    return r * cos(azimuth * Math.PI.toFloat() / 180f)
}
