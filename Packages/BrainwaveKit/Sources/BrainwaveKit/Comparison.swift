import Foundation

/// The overall (or band) activation at one moment: seconds since the start, and a z-score per electrode.
public struct ActivityFrame: Sendable {
    public let time: Double
    public let values: [Electrode: Float]

    public init(time: Double, values: [Electrode: Float]) {
        self.time = time
        self.values = values
    }
}

/// Two areas compared at one moment.
public struct ComparedMoment: Sendable, Hashable {
    public let time: Double
    /// Activity of the first area, as a z-score.
    public let first: Double
    /// Activity of the second area, as a z-score.
    public let second: Double

    /// Positive when the first area is the more active one.
    public var difference: Double { first - second }
}

/// Both areas' activity over time. Frames with no readings are skipped.
public func comparedSeries(_ frames: [ActivityFrame], _ first: Area, _ second: Area) -> [ComparedMoment] {
    frames.compactMap { frame in
        guard !frame.values.isEmpty else { return nil }
        return ComparedMoment(time: frame.time,
                              first: Double(first.activity(in: frame.values).z),
                              second: Double(second.activity(in: frame.values).z))
    }
}

/// How the two areas relate over a stretch of time.
public struct ComparisonSummary: Sendable, Equatable {
    /// Share of moments (0 to 1) when the first area was the more active one.
    public let firstHigherShare: Double
    /// Average of (first − second) over the moments. Positive means the first area led on average.
    public let averageDifference: Double

    public init(_ moments: [ComparedMoment]) {
        guard !moments.isEmpty else {
            firstHigherShare = 0
            averageDifference = 0
            return
        }
        firstHigherShare = Double(moments.filter { $0.difference > 0 }.count) / Double(moments.count)
        averageDifference = moments.map(\.difference).reduce(0, +) / Double(moments.count)
    }
}
