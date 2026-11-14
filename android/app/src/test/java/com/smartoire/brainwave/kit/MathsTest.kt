package com.smartoire.brainwave.kit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MathsTest {
    private val tolerance = 1e-4

    @Test fun baselineIsSilentDuringWarmUp() {
        val b = Baseline(warmUp = 10, memory = 600)
        repeat(9) { assertNull(b.update(it.toDouble())) }
    }

    @Test fun baselineClampsToThreeStandardDeviations() {
        val b = Baseline(warmUp = 5, memory = 600)
        listOf(0.0, 0.1, -0.1, 0.0, 0.1, -0.1).forEach { b.update(it) }
        val z = b.update(100.0)!!
        assertTrue("z should be clamped to at most 3, was $z", z <= 3.0 + tolerance)
        assertTrue("a large jump should still read as high, was $z", z > 1.0)
    }

    @Test fun baselineIgnoresNonFinite() {
        val b = Baseline()
        assertNull(b.update(Double.NaN))
        assertNull(b.update(Double.POSITIVE_INFINITY))
    }

    @Test fun scoreIsFiftyAtUsualLevel() {
        assertEquals(50.0, Metric.score(0.0), tolerance)
    }

    @Test fun scoreRisesAndFallsWithZ() {
        assertTrue(Metric.score(1.0) > 65)
        assertTrue(Metric.score(-1.0) < 35)
    }

    @Test fun labelsFollowThresholds() {
        assertEquals("Focused", Metric.FOCUS.label(70.0))
        assertEquals("Distracted", Metric.FOCUS.label(30.0))
        assertEquals("Steady", Metric.FOCUS.label(50.0))
    }

    @Test fun focusUsesForeheadOnly() {
        assertEquals(listOf(Electrode.AF7, Electrode.AF8), Metric.FOCUS.electrodes)
        assertEquals(4, Metric.CALM.electrodes.size)
    }

    @Test fun calmIndexIsAlphaMinusBeta() {
        val power = mapOf(
            Band.ALPHA to Electrode.entries.associateWith { 1.0 },
            Band.BETA to Electrode.entries.associateWith { 0.25 },
            Band.THETA to Electrode.entries.associateWith { 0.0 },
        )
        assertEquals(0.75, Metric.CALM.index(power)!!, tolerance)
    }

    @Test fun indexSkipsBadElectrodes() {
        val power = mapOf(
            Band.ALPHA to mapOf(Electrode.AF7 to 1.0, Electrode.AF8 to 2.0),
            Band.BETA to mapOf(Electrode.AF7 to 0.0, Electrode.AF8 to 0.0),
            Band.THETA to mapOf(Electrode.AF7 to 0.0, Electrode.AF8 to 0.0),
        )
        assertEquals(2.0, Metric.CALM.index(power, excluding = setOf(Electrode.AF7))!!, tolerance)
    }

    @Test fun electrodePositionsAreMirrored() {
        assertEquals(-Electrode.AF7.x, Electrode.AF8.x, 1e-4f)
        assertEquals(Electrode.AF7.y, Electrode.AF8.y, 1e-4f)
        assertEquals(-Electrode.TP9.x, Electrode.TP10.x, 1e-4f)
    }

    @Test fun regionsFollowPosition() {
        assertEquals(BrainRegion.LEFT_FRONTAL, BrainRegion.at(-0.4f, 0.5f))
        assertEquals(BrainRegion.RIGHT_TEMPORAL, BrainRegion.at(0.7f, -0.4f))
    }

    @Test fun topomapReturnsExactValueAtASensor() {
        val values = mapOf(Electrode.AF7 to 1.5f, Electrode.AF8 to -1f)
        val (z, confidence) = Topomap.sample(values, Electrode.AF7.x, Electrode.AF7.y)
        assertEquals(1.5f, z, 1e-4f)
        assertEquals(1f, confidence, 1e-4f)
    }

    @Test fun comparisonSummaryCountsShareAndAverage() {
        val s = ComparisonSummary.of(listOf(ComparedMoment(0.0, 1.0, 0.0), ComparedMoment(1.0, 0.0, 1.0)))
        assertEquals(0.5, s.firstHigherShare, tolerance)
        assertEquals(0.0, s.averageDifference, tolerance)
    }

    @Test fun comparedSeriesSkipsEmptyFrames() {
        val left = Area("Left", listOf(BrainRegion.LEFT_FRONTAL))
        val right = Area("Right", listOf(BrainRegion.RIGHT_FRONTAL))
        val frames = listOf(ActivityFrame(0.0, emptyMap()), ActivityFrame(1.0, mapOf(Electrode.AF7 to 2f, Electrode.AF8 to 0f)))
        val series = comparedSeries(frames, left, right)
        assertEquals(1, series.size)
        assertTrue(series[0].difference > 0)
    }

    @Test fun balanceIsTheMeanOfKnownScores() {
        assertEquals(60.0, balanceScore(70.0, 50.0)!!, tolerance)
        assertEquals(70.0, balanceScore(70.0, null)!!, tolerance)
        assertNull(balanceScore(null, null))
    }
}
