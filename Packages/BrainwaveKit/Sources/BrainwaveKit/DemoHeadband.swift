import Foundation

/// A synthetic headband for running the app without hardware (simulator, screenshots,
/// App Review). Each electrode's band amplitudes drift slowly and independently, so the
/// maps move the way real recordings do.
public struct DemoHeadband: Sendable {
    /// Muse's EEG sampling rate (Hz), also used for the simulated signal.
    public static let sampleRate = 256.0
    private var time = 0.0
    private var noise = SystemRandomNumberGenerator()

    public init() {}

    /// Amplitude (µV) of `band` at `electrode` at time `t`.
    func amplitude(_ band: Band, _ electrode: Electrode, at t: Double) -> Double {
        let base = [12.0, 8, 10, 5, 2][band.rawValue]
        let period = 9.0 + Double(band.rawValue) * 3.7 + Double(electrode.rawValue) * 2.3
        let phase = Double(electrode.rawValue) * .pi / 2 + Double(band.rawValue) * 1.3  // electrodes out of step
        return base * (1 + 0.6 * sin(2 * .pi * t / period + phase))
    }

    /// Advances by `count` samples and returns raw EEG (µV) per electrode.
    public mutating func nextSamples(_ count: Int) -> [Electrode: [Double]] {
        var out: [Electrode: [Double]] = [:]
        for electrode in Electrode.allCases {
            out[electrode] = (0..<count).map { i in
                let t = time + Double(i) / Self.sampleRate
                return Band.allCases.reduce(Double.random(in: -3...3, using: &noise)) { sum, band in
                    sum + amplitude(band, electrode, at: t) * sin(2 * .pi * band.hertz * t + Double(electrode.rawValue))
                }
            }
        }
        time += Double(count) / Self.sampleRate
        return out
    }

    /// Absolute band power (log10 µV², as libmuse reports it) for the current time.
    public mutating func bandPowers() -> [Band: [Electrode: Double]] {
        Dictionary(uniqueKeysWithValues: Band.allCases.map { band in
            (band, Dictionary(uniqueKeysWithValues: Electrode.allCases.map { electrode in
                let a = amplitude(band, electrode, at: time)
                return (electrode, log10(a * a / 2) + Double.random(in: -0.03...0.03, using: &noise))
            }))
        })
    }
}
