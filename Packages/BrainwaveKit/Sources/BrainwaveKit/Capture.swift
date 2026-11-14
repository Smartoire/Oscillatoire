import Foundation

/// One second of a recording: every value the maps and scores show, so a capture can be replayed.
///
/// Arrays use fixed layouts to keep files small. Bands × electrodes are flattened as
/// `band.rawValue * 4 + electrode.rawValue`; metrics follow `Metric.allCases`; electrodes
/// follow `Electrode.allCases`. `nil` means no reading at that moment.
public struct CaptureSample: Codable, Sendable, Hashable {
    /// Seconds since the capture started.
    public let time: Double
    /// Band power, log10 µV² (as libmuse reports it).
    public let power: [Double?]
    /// Activation: z-score against the personal baseline.
    public let activation: [Double?]
    /// Focus, Calm and Drowsiness scores, 0–100.
    public let scores: [Double?]
    /// Contact quality per electrode.
    public let contact: [ContactQuality?]
    /// Movement: how far the accelerometer's magnitude is from gravity (1 g), in g. Nil if not reported.
    public let movement: Double?

    public init(time: Double, power: [Double?], activation: [Double?], scores: [Double?],
                contact: [ContactQuality?], movement: Double?) {
        self.time = time
        self.power = power
        self.activation = activation
        self.scores = scores
        self.contact = contact
        self.movement = movement
    }
}

/// A recorded time window from one headband, with everything needed to preview and export it.
public struct Capture: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let started: Date
    /// Name of the headband, or "Demo headband".
    public let device: String
    /// Length of the window in seconds.
    public let duration: Double
    public let samples: [CaptureSample]

    public init(id: UUID = UUID(), started: Date, device: String, duration: Double, samples: [CaptureSample]) {
        self.id = id
        self.started = started
        self.device = device
        self.duration = duration
        self.samples = samples
    }

    /// Activation map for `band` at one sample. Empty where there is no reading.
    public func activation(_ band: Band, at index: Int) -> [Electrode: Float] {
        guard samples.indices.contains(index) else { return [:] }
        var map: [Electrode: Float] = [:]
        for electrode in Electrode.allCases {
            if let z = samples[index].activation[band.rawValue * Electrode.allCases.count + electrode.rawValue] {
                map[electrode] = Float(z)
            }
        }
        return map
    }

    /// Activation averaged over all bands at one sample: the everyday "overall activity" map.
    public func activity(at index: Int) -> [Electrode: Float] {
        Topomap.average(Band.allCases.map { activation($0, at: index) }.filter { !$0.isEmpty })
    }

    /// Seconds spent with `metric` at or above `threshold`, counted between consecutive samples.
    public func secondsAbove(_ metric: Metric, threshold: Double = Metric.stateThreshold) -> Double {
        var total = 0.0
        for (previous, current) in zip(samples, samples.dropFirst()) {
            if let score = previous.scores[metric.rawValue], score >= threshold {
                total += current.time - previous.time
            }
        }
        return total
    }

    /// Share of the window with movement above `limit` g, from 0 to 1 (nil if no movement was recorded).
    public func movementShare(above limit: Double = Capture.movementLimit) -> Double? {
        let readings = samples.compactMap(\.movement)
        guard !readings.isEmpty else { return nil }
        return Double(readings.filter { $0 > limit }.count) / Double(readings.count)
    }

    /// How a score changed over the capture: the average of the last third minus the first third, in points.
    /// Nil when there are too few readings to compare.
    public func scoreChange(_ metric: Metric) -> Double? {
        let values = samples.compactMap { $0.scores[metric.rawValue] }
        guard values.count >= 6 else { return nil }
        let third = values.count / 3
        let early = values.prefix(third).reduce(0, +) / Double(third)
        let late = values.suffix(third).reduce(0, +) / Double(third)
        return late - early
    }

    /// Movement above this (g) makes the scores unreliable: blinks, head turns and walking.
    public static let movementLimit = 0.15

    /// Comma-separated values with a header row: one row per sample, one column per value.
    public func csv() -> String {
        var columns = ["time_s"]
        for band in Band.allCases {
            columns += Electrode.allCases.map { "power_\(band.name.lowercased())_\($0.name.lowercased())" }
        }
        for band in Band.allCases {
            columns += Electrode.allCases.map { "activation_\(band.name.lowercased())_\($0.name.lowercased())" }
        }
        columns += Metric.allCases.map { "score_\($0.name.lowercased())" }
        columns += Electrode.allCases.map { "contact_\($0.name.lowercased())" }
        columns.append("movement_g")

        func number(_ value: Double?) -> String { value.map { String(format: "%.4f", $0) } ?? "" }
        var lines = [columns.joined(separator: ",")]
        for sample in samples {
            var cells = [String(format: "%.2f", sample.time)]
            cells += sample.power.map(number)
            cells += sample.activation.map(number)
            cells += sample.scores.map(number)
            cells += sample.contact.map { $0?.label ?? "" }
            cells.append(number(sample.movement))
            lines.append(cells.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

extension Capture {
    /// The capture as JSON for analysis tools and agents: a format name and version, then the capture itself.
    /// Dates are ISO 8601 and missing readings are null. See docs/CAPTURE_FORMAT.md.
    public func jsonExport() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(CaptureExport(capture: self))
    }
}

/// The JSON wrapper: says what the file is, so a tool or agent can recognise it.
struct CaptureExport: Encodable {
    let format = "brainwave.capture"
    let version = 1
    let capture: Capture
}

/// Collects one capture window: open it, add a sample each second, then close it to get the capture.
/// Kept free of the headband so the recording rules can be tested.
public struct CaptureRecorder: Sendable {
    /// When the open window started; nil when not recording.
    public private(set) var started: Date?
    public private(set) var device = ""
    private var samples: [CaptureSample] = []

    public init() {}

    public var isRecording: Bool { started != nil }

    /// Opens a window. Does nothing if one is already open.
    public mutating func start(at date: Date, device: String) {
        guard started == nil else { return }
        started = date
        self.device = device
        samples = []
    }

    /// Adds a sample to the open window. Ignored when not recording.
    public mutating func add(_ sample: CaptureSample) {
        guard started != nil else { return }
        samples.append(sample)
    }

    /// Closes the window. Returns the capture, or nil if nothing was recorded.
    public mutating func stop(at date: Date) -> Capture? {
        guard let started else { return nil }
        let recorded = samples
        self.started = nil
        samples = []
        guard !recorded.isEmpty else { return nil }
        return Capture(started: started, device: device, duration: date.timeIntervalSince(started), samples: recorded)
    }
}
