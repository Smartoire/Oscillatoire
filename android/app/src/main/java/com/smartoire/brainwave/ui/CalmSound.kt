package com.smartoire.brainwave.ui

// The calm soundscape. "Tones" plays a soft scale in the rhythm of the breath: on each breath in
// one scale rises, on each breath out it falls. "Sea", "Wind" and "Birds" are natural loops
// made from noise and chirps, generated once and repeated without a seam.

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

enum class CalmKind(val key: String) {
    TONES("tones"), SEA("sea"), WIND("wind"), BIRDS("birds");

    companion object {
        fun of(key: String): CalmKind = entries.firstOrNull { it.key == key } ?: TONES
    }
}

/// [level] is the volume (0..1). [cycleSeconds] is one full breath: in, then out (used by the tones).
class CalmSound(private val level: Float, private val cycleSeconds: Double, private val kind: CalmKind = CalmKind.TONES) {
    private val rate = 22050
    private var track: AudioTrack? = null

    // C major pentatonic, from C4 up to C5.
    private val scale = doubleArrayOf(261.63, 293.66, 329.63, 392.00, 440.00, 523.25)

    /// One breath cycle as PCM: the scale rising across the breath in, falling across the breath out.
    private fun cycle(): ShortArray {
        val n = (rate * cycleSeconds).toInt()
        val out = DoubleArray(n)
        val half = cycleSeconds / 2
        val step = half / scale.size
        val noteLength = 0.8                       // seconds; short enough that each note ends before the next breath
        for (k in scale.indices) {
            // Breath in: notes go up. Breath out: the same notes come back down.
            addNote(out, scale[k], start = k * step, length = noteLength)
            addNote(out, scale[scale.size - 1 - k], start = half + k * step, length = noteLength)
        }
        return ShortArray(n) { i -> (out[i].coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort() }
    }

    private fun addNote(out: DoubleArray, freq: Double, start: Double, length: Double) {
        val first = (start * rate).toInt()
        val count = (length * rate).toInt()
        for (j in 0 until count) {
            val i = first + j
            if (i >= out.size) break
            val t = j.toDouble() / rate
            val attack = min(t / 0.03, 1.0)
            val decay = exp(-4.0 * t)
            val tone = sin(2 * PI * freq * t) + 0.3 * sin(4 * PI * freq * t)   // soft, with a gentle overtone
            out[i] += tone * attack * decay * level * 0.35
        }
    }

    /// A natural loop of [LOOP_SECONDS]: noise shaped by a slow envelope, or chirps over a quiet hush.
    /// The end is blended into the start, so the repeat has no click.
    private fun natural(): ShortArray {
        val n = (rate * LOOP_SECONDS).toInt()
        val fade = (rate * FADE_SECONDS).toInt()
        val x = DoubleArray(n + fade)
        val rnd = java.util.Random(kind.ordinal.toLong() + 7)
        when (kind) {
            CalmKind.SEA -> {
                // Brown noise (a slow low rumble), swelling twice per loop, with a little hiss on top of each wave.
                var brown = 0.0
                var hiss = 0.0
                for (i in x.indices) {
                    val t = i.toDouble() / rate
                    brown += 0.03 * (rnd.nextDouble() * 2 - 1 - brown)
                    hiss += 0.5 * ((rnd.nextDouble() * 2 - 1) - hiss)
                    val swell = 0.2 + 0.8 * (0.5 - 0.5 * cos(2 * PI * t / 6.0)).pow(2)
                    x[i] = brown * 6.0 * swell + hiss * 0.04 * swell
                }
            }
            CalmKind.WIND -> {
                // Soft filtered noise with gusts: two slow rises and falls that fit the loop exactly.
                var low = 0.0
                for (i in x.indices) {
                    val t = i.toDouble() / rate
                    low += 0.04 * ((rnd.nextDouble() * 2 - 1) - low)
                    val gust = 0.5 + 0.5 * sin(2 * PI * t / 12.0 + 0.6) * 0.6 + 0.5 * sin(2 * PI * t / 4.0 + 1.9) * 0.4
                    x[i] = low * 8.0 * (0.15 + 0.85 * gust.coerceIn(0.0, 1.0))
                }
            }
            CalmKind.BIRDS -> {
                // A quiet air hush, with bird songs at random moments through the loop.
                var low = 0.0
                for (i in x.indices) {
                    low += 0.02 * ((rnd.nextDouble() * 2 - 1) - low)
                    x[i] = low * 2.0
                }
                repeat(16) { addSong(x, start = rnd.nextDouble() * (LOOP_SECONDS - 1.5), rnd = rnd) }
            }
            CalmKind.TONES -> Unit
        }
        // Blend the tail (which continues past the loop) into the head, so the repeat is seamless.
        val out = DoubleArray(n) { i -> if (i < fade) x[n + i] * cos(PI / 2 * i / fade) + x[i] * sin(PI / 2 * i / fade) else x[i] }
        val peak = out.maxOf { kotlin.math.abs(it) }.coerceAtLeast(1e-6)
        return ShortArray(n) { i -> (out[i] / peak * 0.9 * Short.MAX_VALUE).toInt().toShort() }
    }

    /// One bird song: a few short notes, each a quick upward or downward sweep.
    private fun addSong(x: DoubleArray, start: Double, rnd: java.util.Random) {
        var t = start
        val notes = 1 + rnd.nextInt(4)
        val baseHz = 1800 + rnd.nextDouble() * 2200
        val rising = rnd.nextBoolean()
        for (k in 0 until notes) {
            val dur = 0.06 + rnd.nextDouble() * 0.12
            val sweep = 1.2 + rnd.nextDouble() * 0.5
            val f0 = baseHz * (1 + 0.1 * k)
            val f1 = if (rising) f0 * sweep else f0 / sweep
            val first = (t * rate).toInt()
            val count = (dur * rate).toInt()
            var phase = 0.0
            for (j in 0 until count) {
                val i = first + j
                if (i >= x.size) break
                val u = j.toDouble() / count
                val f = f0 + (f1 - f0) * u
                phase += 2 * PI * f / rate
                x[i] += sin(phase) * sin(PI * u) * 0.5
            }
            t += dur + 0.03 + rnd.nextDouble() * 0.08
        }
    }

    fun start() {
        if (track != null) return
        val samples = if (kind == CalmKind.TONES) cycle() else natural()
        val gain = if (kind == CalmKind.TONES) 1f else level * 0.6f
        val pcm = if (kind == CalmKind.TONES) samples else ShortArray(samples.size) { i -> (samples[i] * gain).toInt().toShort() }
        val at = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setAudioFormat(AudioFormat.Builder().setSampleRate(rate).setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setBufferSizeInBytes(pcm.size * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        at.write(pcm, 0, pcm.size)
        at.setLoopPoints(0, pcm.size, -1)       // repeat the loop for as long as the page is open
        track = at
        at.play()
    }

    fun stop() {
        track?.let { runCatching { it.stop() }; it.release() }
        track = null
    }

    private companion object {
        const val LOOP_SECONDS = 12.0            // a whole number of sea swells, gusts and bird calls
        const val FADE_SECONDS = 1.5
    }
}
