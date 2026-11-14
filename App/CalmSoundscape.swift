import AVFoundation
import SwiftUI
import os

/// A gentle sound made on the device while a calm session runs. No recordings or licensed tracks.
/// Its level follows your calm score, so the sound fills out as you settle.
@MainActor
final class CalmSoundscape {
    private let engine = AVAudioEngine()
    private let synth = Synth()
    private var attached = false

    func start(_ sound: CalmSound = .drone) {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        synth.setSound(sound)
        if !attached {
            let format = engine.outputNode.outputFormat(forBus: 0)
            let node = Self.makeSource(format: format, synth: synth)
            engine.attach(node)
            if #available(iOS 27, macOS 27, *) {
                try? engine.connectNode(node, to: engine.mainMixerNode, format: format)
            } else {
                engine.connect(node, to: engine.mainMixerNode, format: format)  // older systems
            }
            attached = true
        }
        try? engine.start()
    }

    func stop() {
        engine.stop()
    }

    /// Built outside the main actor: the render block runs on the audio thread, where main-actor code
    /// trips a dispatch assertion and crashes the app.
    nonisolated private static func makeSource(format: AVAudioFormat, synth: Synth) -> AVAudioSourceNode {
        let sampleRate = format.sampleRate
        return AVAudioSourceNode(format: format) { _, _, frameCount, buffers in
            synth.render(frames: Int(frameCount), sampleRate: sampleRate, into: buffers)
            return noErr
        }
    }

    /// 0 is silent, 1 is full. Changes are smoothed, so the sound never clicks.
    func setLevel(_ level: Double) {
        synth.setLevel(Float(level))
    }
}

/// The sounds a calm session can use.
nonisolated enum CalmSound: String, CaseIterable, Identifiable, Sendable {
    /// An open chord that swells with each breath.
    case drone
    /// Soft, slow noise like a distant shore.
    case waves
    /// Filtered noise with gusts that rise and fall.
    case wind
    /// A quiet air hush, with bird songs at random moments.
    case birds
    /// One warm, steady note.
    case tone

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .drone: "Drone"
        case .waves: "Waves"
        case .wind: "Wind"
        case .birds: "Birds"
        case .tone: "Single tone"
        }
    }
}

/// Runs on the audio thread. The target level and the chosen sound are shared with the main thread behind locks.
nonisolated final class Synth: @unchecked Sendable {
    private let target = OSAllocatedUnfairLock(initialState: Float(0.5))
    private let sound = OSAllocatedUnfairLock(initialState: CalmSound.drone)
    private var gain = 0.0
    private var time = 0.0
    private var phases = [0.0, 0.0, 0.0]
    private var brown = 0.0
    /// Filtered noise for the wind and the birds' air hush.
    private var soft = 0.0
    /// The bird song being sung: its sample index, length, phase and sweep (in Hz).
    private var chirpIndex = 0
    private var chirpLength = 0
    private var chirpPhase = 0.0
    private var chirpStart = 0.0
    private var chirpEnd = 0.0
    /// Samples until the next song.
    private var untilChirp = 0
    /// A2, E3 and A3: a consonant, open chord.
    private let frequencies = [110.0, 164.81, 220.0]

    func setLevel(_ value: Float) {
        target.withLock { $0 = min(max(value, 0), 1) }
    }

    func setSound(_ value: CalmSound) {
        sound.withLock { $0 = value }
    }

    func render(frames: Int, sampleRate: Double, into buffers: UnsafeMutablePointer<AudioBufferList>) {
        let list = UnsafeMutableAudioBufferListPointer(buffers)
        let level = Double(target.withLock { $0 })
        let kind = sound.withLock { $0 }
        for frame in 0..<frames {
            time += 1 / sampleRate
            var sample = 0.0
            switch kind {
            case .drone:
                for i in frequencies.indices {
                    phases[i] += 2 * .pi * frequencies[i] / sampleRate
                    if phases[i] > 2 * .pi { phases[i] -= 2 * .pi }
                    sample += sin(phases[i]) / Double(frequencies.count)
                }
                // A slow swell, about one breath in ten seconds.
                sample *= 0.6 + 0.4 * sin(2 * .pi * 0.1 * time)
            case .waves:
                // Brown noise, a slow random walk, swelling every twenty seconds or so.
                brown = min(max(brown * 0.999 + Double.random(in: -0.04...0.04), -1), 1)
                sample = brown * 1.6 * (0.5 + 0.5 * sin(2 * .pi * 0.05 * time))
            case .wind:
                // Soft noise, with two gusts rising and falling at different speeds.
                soft += 0.02 * (Double.random(in: -1...1) - soft)
                let gust = 0.5 + 0.3 * sin(2 * .pi * 0.08 * time) + 0.2 * sin(2 * .pi * 0.23 * time + 1.3)
                sample = soft * 6 * (0.15 + 0.85 * min(max(gust, 0), 1))
            case .birds:
                // The air hush, with a short song sung every one to four seconds.
                soft += 0.01 * (Double.random(in: -1...1) - soft)
                sample = soft * 2
                if chirpIndex < chirpLength {
                    let u = Double(chirpIndex) / Double(chirpLength)
                    chirpPhase += 2 * .pi * (chirpStart + (chirpEnd - chirpStart) * u) / sampleRate
                    sample += sin(chirpPhase) * sin(.pi * u) * 0.5
                    chirpIndex += 1
                } else {
                    untilChirp -= 1
                    if untilChirp <= 0 {
                        // A short run of notes, sweeping up or down.
                        chirpIndex = 0
                        chirpLength = Int(sampleRate * Double.random(in: 0.06...0.18))
                        chirpStart = Double.random(in: 1800...4000)
                        let sweep = Double.random(in: 1.2...1.6)
                        chirpEnd = Bool.random() ? chirpStart * sweep : chirpStart / sweep
                        untilChirp = Int(sampleRate * Double.random(in: 1...4))
                    }
                }
            case .tone:
                phases[0] += 2 * .pi * 220 / sampleRate
                if phases[0] > 2 * .pi { phases[0] -= 2 * .pi }
                sample = sin(phases[0])
            }
            gain += (level - gain) * 0.0005
            let value = Float(sample * gain * 0.2)
            for buffer in list {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
            }
        }
    }
}
