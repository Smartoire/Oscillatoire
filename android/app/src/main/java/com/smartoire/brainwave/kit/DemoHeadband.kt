package com.smartoire.brainwave.kit

// Port of Packages/BrainwaveKit/.../DemoHeadband.swift: a synthetic headband for running the app
// without hardware. Each electrode's band amplitudes drift slowly and independently.

import kotlin.math.PI
import kotlin.math.log10
import kotlin.math.sin
import kotlin.random.Random

class DemoHeadband {
    private var time = 0.0
    private val random = Random.Default

    /// Amplitude (µV) of a band at an electrode at time t.
    private fun amplitude(band: Band, electrode: Electrode, t: Double): Double {
        val base = listOf(12.0, 8.0, 10.0, 5.0, 2.0)[band.ordinal]
        val period = 9.0 + band.ordinal * 3.7 + electrode.ordinal * 2.3
        val phase = electrode.ordinal * Math.PI / 2 + band.ordinal * 1.3  // electrodes out of step
        return base * (1 + 0.6 * sin(2 * Math.PI * t / period + phase))
    }

    /// Absolute band power (log10 µV²) for the current time, as libmuse reports it.
    fun bandPowers(): Map<Band, Map<Electrode, Double>> = Band.entries.associateWith { band ->
        Electrode.entries.associateWith { electrode ->
            val a = amplitude(band, electrode, time)
            log10(a * a / 2) + random.nextDouble(-0.03, 0.03)
        }
    }

    /// Simulated raw EEG in µV at time t (epoch seconds): a slow wave and a faster one, with a little noise.
    fun microvolts(electrode: Electrode, t: Double): Double {
        val phase = electrode.ordinal * 1.1
        return 800 + 30 * sin(2 * PI * 10 * t + phase) + 12 * sin(2 * PI * 21 * t + 0.7 * phase) + random.nextDouble(-4.0, 4.0)
    }

    /// Moves the simulated clock on by one second.
    fun advance(seconds: Double = 1.0) {
        time += seconds
    }

    /// Simulated contact: all four sensors good, as a headband on a forehead would show.
    fun contact(): Map<Electrode, Double> = Electrode.entries.associateWith { 1.0 }

    /// Simulated battery level, slowly falling.
    fun battery(): Double = (100.0 - time / 600.0).coerceAtLeast(0.0)
}
