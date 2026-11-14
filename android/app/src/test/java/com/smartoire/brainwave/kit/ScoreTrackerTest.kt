package com.smartoire.brainwave.kit

import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScoreTrackerTest {
    private fun power(alpha: Double, beta: Double, theta: Double) = mapOf(
        Band.ALPHA to Electrode.entries.associateWith { alpha },
        Band.BETA to Electrode.entries.associateWith { beta },
        Band.THETA to Electrode.entries.associateWith { theta },
    )

    @Test fun noScoreBeforeTheBaselineIsReady() {
        val t = ScoreTracker()
        t.tick(0.0, power(1.0, 0.5, 0.2), emptySet())
        assertNull(t.latest(Metric.CALM))
    }

    @Test fun scoreAppearsAfterWarmUpAndStaysInRange() {
        val t = ScoreTracker()
        for (i in 0 until 40) t.tick(i.toDouble(), power(1.0 + 0.01 * (i % 3), 0.5, 0.2), emptySet())
        val score = t.latest(Metric.CALM)
        assertTrue(score != null && score in 0.0..100.0)
    }
}
