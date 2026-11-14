package com.smartoire.brainwave.kit

// The last few seconds of raw EEG for each electrode, for the Signals traces. Times are epoch seconds.

// Five seconds, so the Signals view can draw four seconds ending one second behind the clock.
class TraceBuffer(private val seconds: Double = 5.0) {
    data class Point(val time: Double, val microvolts: Float)

    private val lanes = Electrode.entries.associateWith { ArrayDeque<Point>() }

    fun add(electrode: Electrode, time: Double, microvolts: Double) {
        val lane = lanes.getValue(electrode)
        lane.addLast(Point(time, microvolts.toFloat()))
        while (lane.isNotEmpty() && lane.first().time < time - seconds) lane.removeFirst()
    }

    fun snapshot(): Map<Electrode, List<Point>> = lanes.mapValues { it.value.toList() }
}
