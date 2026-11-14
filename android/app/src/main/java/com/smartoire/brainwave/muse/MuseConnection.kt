package com.smartoire.brainwave.muse

// Port of App/MuseListener.swift and Session's connection code. Only this file (and the imports
// below) touches the Muse SDK; everything else sees plain Kotlin values.

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.choosemuse.libmuse.Accelerometer
import com.choosemuse.libmuse.Battery
import com.choosemuse.libmuse.ConnectionState
import com.choosemuse.libmuse.Eeg
import com.choosemuse.libmuse.Muse
import com.choosemuse.libmuse.MuseArtifactPacket
import com.choosemuse.libmuse.MuseConnectionListener
import com.choosemuse.libmuse.MuseConnectionPacket
import com.choosemuse.libmuse.MuseDataListener
import com.choosemuse.libmuse.MuseDataPacket
import com.choosemuse.libmuse.MuseDataPacketType
import com.choosemuse.libmuse.MuseListener
import com.choosemuse.libmuse.MuseManagerAndroid
import com.choosemuse.libmuse.MuseModel
import com.choosemuse.libmuse.MusePreset
import com.smartoire.brainwave.kit.Band
import com.smartoire.brainwave.kit.DemoHeadband
import com.smartoire.brainwave.kit.Electrode
import com.smartoire.brainwave.kit.TraceBuffer
import kotlin.math.abs
import kotlin.math.sqrt
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/// What the screens show. Updated on the main thread.
data class MuseState(
    val headbands: List<String> = emptyList(),
    val status: String = "Idle",
    val eeg: Map<Electrode, Double> = emptyMap(),
    val bands: Map<Band, Map<Electrode, Double>> = emptyMap(),
    /// Contact quality per electrode: 1 good, 2 ok, 4 bad (the SDK's horseshoe value).
    val contact: Map<Electrode, Double> = emptyMap(),
    val battery: Double? = null,
    /// Distance of the acceleration from gravity, in g.
    val movement: Double? = null,
)

/// Scans for headbands, connects to one, and publishes its readings as [state].
class MuseConnection(context: Context) {
    private val manager = MuseManagerAndroid.getInstance().also { it.setContext(context) }
    private val main = Handler(Looper.getMainLooper())
    private var muse: Muse? = null
    private var demo: DemoHeadband? = null
    private val _state = MutableStateFlow(MuseState())
    val state: StateFlow<MuseState> = _state.asStateFlow()

    /// Recent raw EEG for the Signals traces.
    val traces = TraceBuffer()

    private val museListener = object : MuseListener() {
        override fun museListChanged() = onMain { refreshHeadbands() }
    }

    private val connectionListener = object : MuseConnectionListener() {
        override fun receiveMuseConnectionPacket(p: MuseConnectionPacket, m: Muse) {
            val status = when (p.currentConnectionState) {
                ConnectionState.CONNECTED -> "Connected to ${m.name}"
                ConnectionState.CONNECTING -> "Connecting to ${m.name}"
                ConnectionState.DISCONNECTED -> "Disconnected"
                ConnectionState.NEEDS_UPDATE -> "${m.name} needs a firmware update"
                ConnectionState.NEEDS_LICENSE -> "${m.name} needs a licence from Interaxon"
                else -> p.currentConnectionState.toString()
            }
            onMain {
                _state.value = _state.value.copy(status = status)
                if (p.currentConnectionState == ConnectionState.DISCONNECTED) muse = null
            }
        }
    }

    private val dataListener = object : MuseDataListener() {
        override fun receiveMuseDataPacket(p: MuseDataPacket, m: Muse) = onMain { apply(p) }
        override fun receiveMuseArtifactPacket(p: MuseArtifactPacket, m: Muse) {}
    }

    /// Runs the demo headband instead of a Muse: the same state, with simulated readings.
    fun startDemo() {
        demo = DemoHeadband()
        _state.value = _state.value.copy(status = "Demo headband", contact = demoContact())
    }

    /// One demo update: band powers, contact and battery, as the Muse would report them.
    fun demoTick() {
        val d = demo ?: return
        val now = System.currentTimeMillis() / 1000.0
        for (e in Electrode.entries) for (i in 0 until 256) {
            val t = now - 1 + i / 256.0
            traces.add(e, t, d.microvolts(e, t))
        }
        d.advance()
        _state.value = _state.value.copy(
            bands = d.bandPowers(), contact = d.contact(), battery = d.battery(),
        )
    }

    private fun demoContact() = demo?.contact() ?: emptyMap()

    /// Start looking for headbands. Needs Bluetooth scan permission first.
    fun startSearching() {
        manager.setMuseListener(museListener)
        manager.stopListening()
        manager.startListening()
        refreshHeadbands()
    }

    fun stopSearching() = manager.stopListening()

    fun connect(name: String) {
        demo = null
        val chosen = manager.muses.firstOrNull { it.name == name } ?: return
        disconnect()
        manager.stopListening()
        muse = chosen
        chosen.unregisterAllListeners()
        chosen.registerConnectionListener(connectionListener)
        chosen.registerDataListener(dataListener, MuseDataPacketType.EEG)
        chosen.registerDataListener(dataListener, MuseDataPacketType.HSI_PRECISION)
        chosen.registerDataListener(dataListener, MuseDataPacketType.BATTERY)
        chosen.registerDataListener(dataListener, MuseDataPacketType.ACCELEROMETER)
        for (type in BAND_TYPES.keys) chosen.registerDataListener(dataListener, type)
        // Athena has its own preset family; 4-channel EEG keeps bandwidth low.
        chosen.setPreset(if (chosen.model == MuseModel.MS_03) MusePreset.PRESET_1021 else MusePreset.PRESET_21)
        chosen.runAsynchronously()
        _state.value = _state.value.copy(status = "Connecting to $name")
    }

    fun disconnect() {
        muse?.unregisterAllListeners()
        muse?.disconnect()
        muse = null
    }

    private fun refreshHeadbands() {
        _state.value = _state.value.copy(headbands = manager.muses.map { it.name })
    }

    /// Runs the SDK callbacks' work on the main thread, so the screens read consistent values.
    private fun onMain(work: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) work() else main.post(work)
    }

    private fun apply(p: MuseDataPacket) {
        val s = _state.value
        when (p.packetType()) {
            MuseDataPacketType.EEG -> {
                val raw = channels(p)
                _state.value = s.copy(eeg = raw)
                val now = System.currentTimeMillis() / 1000.0
                raw.forEach { (electrode, value) -> traces.add(electrode, now, value) }
            }
            MuseDataPacketType.HSI_PRECISION -> _state.value = s.copy(contact = channels(p))
            MuseDataPacketType.BATTERY -> _state.value = s.copy(battery = p.getBatteryValue(Battery.CHARGE_PERCENTAGE_REMAINING))
            MuseDataPacketType.ACCELEROMETER -> {
                val x = p.getAccelerometerValue(Accelerometer.X)
                val y = p.getAccelerometerValue(Accelerometer.Y)
                val z = p.getAccelerometerValue(Accelerometer.Z)
                _state.value = s.copy(movement = abs(sqrt(x * x + y * y + z * z) - 1))
            }
            else -> BAND_TYPES[p.packetType()]?.let { band ->
                _state.value = s.copy(bands = s.bands + (band to channels(p)))
            }
        }
    }

    /// The four Muse sensors (TP9, AF7, AF8, TP10) in the SDK's EEG1...EEG4 order.
    private fun channels(p: MuseDataPacket): Map<Electrode, Double> = mapOf(
        Electrode.TP9 to p.getEegChannelValue(Eeg.EEG1),
        Electrode.AF7 to p.getEegChannelValue(Eeg.EEG2),
        Electrode.AF8 to p.getEegChannelValue(Eeg.EEG3),
        Electrode.TP10 to p.getEegChannelValue(Eeg.EEG4),
    )

    companion object {
        private val BAND_TYPES = mapOf(
            MuseDataPacketType.DELTA_ABSOLUTE to Band.DELTA,
            MuseDataPacketType.THETA_ABSOLUTE to Band.THETA,
            MuseDataPacketType.ALPHA_ABSOLUTE to Band.ALPHA,
            MuseDataPacketType.BETA_ABSOLUTE to Band.BETA,
            MuseDataPacketType.GAMMA_ABSOLUTE to Band.GAMMA,
        )
    }
}
