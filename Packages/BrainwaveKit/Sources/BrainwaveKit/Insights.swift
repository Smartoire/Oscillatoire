import Foundation

/// The alpha peak: the frequency (7–13 Hz) with the most power in a window of raw EEG from one sensor.
/// Returns nil when the window is too short or flat to say. Uses a Hann window and a direct sum at
/// each 0.25 Hz step, so it needs no FFT library. It is an estimate from one sensor.
public func alphaPeakFrequency(_ signal: [Float], sampleRate: Double) -> Double? {
    let n = signal.count
    guard n >= Int(sampleRate * 2) else { return nil }
    let mean = Double(signal.reduce(0, +)) / Double(n)
    let x = signal.enumerated().map { i, v -> Double in
        let window = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(n - 1))
        return (Double(v) - mean) * window
    }
    var best: (frequency: Double, power: Double) = (0, 0)
    for step in 0...24 {
        let frequency = 7 + Double(step) * 0.25
        var re = 0.0, im = 0.0
        for (i, value) in x.enumerated() {
            let phase = 2 * .pi * frequency * Double(i) / sampleRate
            re += value * cos(phase)
            im += value * sin(phase)
        }
        let power = re * re + im * im
        if power > best.power { best = (frequency, power) }
    }
    return best.power > 0 ? best.frequency : nil
}

/// A rough everyday balance: the average of the focus and calm scores, when both are known.
/// It is not a health measure.
public func balanceScore(focus: Double?, calm: Double?) -> Double? {
    let known = [focus, calm].compactMap { $0 }
    return known.isEmpty ? nil : known.reduce(0, +) / Double(known.count)
}

/// One finished calm session.
public struct CalmSessionRecord: Codable, Sendable, Hashable {
    public let date: Date
    /// Seconds spent with the calm score at or above the state threshold.
    public let calmSeconds: Double
    /// Length of the session in seconds.
    public let totalSeconds: Double

    public init(date: Date, calmSeconds: Double, totalSeconds: Double) {
        self.date = date
        self.calmSeconds = calmSeconds
        self.totalSeconds = totalSeconds
    }
}

/// Calm-session progress for the last week, and the streak of days with a session.
public struct CalmSummary: Sendable, Equatable {
    public let sessionsThisWeek: Int
    public let calmMinutesThisWeek: Double
    /// Consecutive days with a session, counting back from today (or from yesterday, if today has none yet).
    public let streakDays: Int

    public init(_ records: [CalmSessionRecord], now: Date, calendar: Calendar = .current) {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let thisWeek = records.filter { $0.date >= weekAgo && $0.date <= now }
        sessionsThisWeek = thisWeek.count
        calmMinutesThisWeek = thisWeek.map(\.calmSeconds).reduce(0, +) / 60

        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        streakDays = streak
    }
}
