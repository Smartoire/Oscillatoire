/// Turns a stream of band powers into "activation": how far the current value sits from
/// this person's own recent baseline, in standard deviations (z-score).
///
/// Positive means more power than usual in that band at that electrode ("active"), negative
/// means less ("deactivated"). Absolute EEG power varies a lot between people and sessions,
/// so comparing against a personal baseline is the standard way to show this honestly.
public struct Baseline: Sendable {
    /// Readings needed before a z-score is reported.
    public let warmUp: Int
    /// Effective memory of the baseline, in readings. Muse emits band powers at ~10 Hz,
    /// so 600 readings ≈ one minute.
    public let memory: Int

    private var mean = 0.0, variance = 0.0, count = 0

    public init(warmUp: Int = 50, memory: Int = 600) {
        self.warmUp = warmUp
        self.memory = memory
    }

    /// 0…1 while warming up.
    public var progress: Double { min(1, Double(count) / Double(warmUp)) }

    /// Adds a reading and returns its z-score, or nil while warming up.
    public mutating func update(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        count += 1
        // Exact running mean/variance at first, then an exponential moving window.
        let alpha = 1 / Double(min(count, memory))
        let delta = value - mean
        mean += alpha * delta
        variance = (1 - alpha) * (variance + alpha * delta * delta)
        guard count >= warmUp, variance > 1e-12 else { return nil }
        return max(-3, min(3, (value - mean) / variance.squareRoot()))
    }
}
