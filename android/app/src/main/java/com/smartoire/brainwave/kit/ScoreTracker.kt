package com.smartoire.brainwave.kit

// Port of the once-a-second score logic in App/Session.swift (updateMetrics) and Metric's history.

/// One score sample: seconds since the start, the score (0-100) and the smoothed z-score it came from.
data class MetricSample(val time: Double, val score: Double, val z: Double)

class ScoreTracker {
    private val baselines = Metric.entries.associateWith { Baseline(warmUp = 10, memory = 120) }
    private val smoothed = mutableMapOf<Metric, Double>()
    private val history = Metric.entries.associateWith { mutableListOf<MetricSample>() }
    private val bandBaselines = mutableMapOf<Pair<Band, Electrode>, Baseline>()

    /// Latest z-score per band and electrode, against the person's own baseline (as on iPhone).
    var activation: Map<Band, Map<Electrode, Double>> = emptyMap()
        private set

    /// Adds one reading per metric from the current band powers. `bad` are sensors not touching the skin.
    fun tick(time: Double, power: Map<Band, Map<Electrode, Double>>, bad: Set<Electrode>) {
        activation = power.mapValues { (band, byElectrode) ->
            byElectrode.mapNotNull { (e, v) ->
                bandBaselines.getOrPut(band to e) { Baseline() }.update(v)?.let { e to it }
            }.toMap()
        }.filterValues { it.isNotEmpty() }
        for (metric in Metric.entries) {
            val index = metric.index(power, bad) ?: continue
            val z = baselines.getValue(metric).update(index) ?: continue
            val previous = smoothed[metric]
            val value = if (previous == null) z else previous + 0.3 * (z - previous)  // steadier, still responsive
            smoothed[metric] = value
            val list = history.getValue(metric)
            list.add(MetricSample(time, Metric.score(value), value))
            if (list.size > 600) list.removeAt(0)
        }
    }

    /// Activation averaged over the bands that have a reading, per electrode: the everyday "overall activity".
    fun activity(): Map<Electrode, Float> = Electrode.entries.mapNotNull { e ->
        val values = activation.values.mapNotNull { it[e] }
        if (values.isEmpty()) null else e to values.average().toFloat()
    }.toMap()

    /// The latest score for a metric, or null before the baseline is ready.
    fun latest(metric: Metric): Double? = history.getValue(metric).lastOrNull()?.score

    fun samples(metric: Metric): List<MetricSample> = history.getValue(metric).toList()

    fun reset() {
        smoothed.clear()
        history.values.forEach { it.clear() }
    }
}
