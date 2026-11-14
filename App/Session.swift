import Foundation
import Observation
import BrainwaveKit

/// Everything the screens show: connection state, raw EEG, band powers and activation.
///
/// libmuse calls back hundreds of times a second (one packet per EEG sample), so incoming data
/// lands in unobserved buffers and is published to SwiftUI on a fixed display tick.
@Observable
final class Session {
    enum Status: Equatable {
        case idle, searching, demo
        case connecting(String), streaming(String)
        case failed(String)

        /// Connected, or about to be: the headband is (or is being) streamed.
        var isLive: Bool {
            switch self {
            case .connecting, .streaming, .demo: true
            default: false
            }
        }
    }

    static let traceSeconds = 4.0

    private(set) var status = Status.idle
    private(set) var headbands: [IXNMuse] = []
    private(set) var battery: Double?
    var band = Band.alpha
    /// Shows the Connect sheet (opened from the top-right button, or the Mac menu bar).
    var showingConnect = false
    /// Start-up check, shown when a headband starts streaming, until the user confirms it.
    var showingStartCheck = false
    private(set) var checkPassed = false
    /// Advanced view shows frequency bands, sensors and raw signals. Everyday view is plain language.
    static var advancedView: Bool { UserDefaults.standard.bool(forKey: "advanced") }
    /// What the maps call the activity they show.
    var bandLabel: String { Self.advancedView ? band.name : "Overall" }

    // Published on the display tick.
    private(set) var traces: [Electrode: [Float]] = [:]
    private(set) var power: [Band: [Electrode: Double]] = [:]       // log10 µV², as libmuse reports
    private(set) var activation: [Band: [Electrode: Float]] = [:]  // z-score vs. personal baseline
    private(set) var contact: [Electrode: ContactQuality] = [:]
    private(set) var calibration = 0.0
    /// Mental-state scores (0–100, 50 = your baseline) once per second for the last 10 minutes.
    private(set) var metrics: [Metric: [MetricSample]] = [:]

    struct MetricSample: Identifiable {
        let date: Date
        let score: Double
        /// The smoothed z-score the score was made from.
        let z: Double
        var id: Date { date }
    }

    @ObservationIgnored private var traceBuffer: [Electrode: [Float]] = [:]
    @ObservationIgnored private var powerBuffer: [Band: [Electrode: Double]] = [:]
    @ObservationIgnored private var activationBuffer: [Band: [Electrode: Float]] = [:]
    @ObservationIgnored private var baselines: [Band: [Electrode: Baseline]] = [:]
    @ObservationIgnored private var metricBaselines: [Metric: Baseline] = [:]
    @ObservationIgnored private var smoothedMetrics: [Metric: Double] = [:]
    @ObservationIgnored private var muse: IXNMuse?
    @ObservationIgnored private var tick: Task<Void, Never>?
    @ObservationIgnored private var launched = false
    @ObservationIgnored private var movementBuffer: Double?
    /// How far the headband's acceleration is from gravity, in g. Nil until reported.
    private(set) var movement: Double?
    /// Alpha peak in Hz, estimated from the front-left sensor every few seconds. Nil until there is enough signal.
    private(set) var alphaPeak: Double?

    // Captures
    /// The open capture window, if any. Samples are added once a second while it is open.
    private(set) var recorder = CaptureRecorder()
    var recordingStarted: Date? { recorder.started }
    /// The capture that just finished. The app shows it for review.
    var finishedCapture: Capture?
    /// Recent overall activity, one frame a second, for the live Compare chart (about 10 minutes).
    private(set) var activityHistory: [ActivityFrame] = []
    @ObservationIgnored private(set) var historyStart = Date.now

    var isRecording: Bool { recorder.isRecording }
    /// A rough everyday balance: the average of focus and calm. Not a health measure.
    var balance: Double? { balanceScore(focus: metrics[.focus]?.last?.score, calm: metrics[.calm]?.last?.score) }

    @ObservationIgnored var lastHeadband: String? {
        get { UserDefaults.standard.string(forKey: "lastHeadband") }
        set { UserDefaults.standard.set(newValue, forKey: "lastHeadband") }
    }
    @ObservationIgnored private lazy var listener = MuseListener(session: self)
    @ObservationIgnored private lazy var manager: any IXNMuseManager = {
        #if os(iOS)
        let manager = IXNMuseManagerIos.sharedManager()!
        #else
        let manager = IXNMuseManagerMac.sharedManager()!
        #endif
        manager.setMuseListener(listener)
        manager.removeFromList(after: 10)  // drop headbands not seen for 10 s
        return manager
    }()

    /// Activation shown on the maps, only at electrodes touching the skin. Everyday view averages the
    /// bands into one overall picture; advanced view shows the selected band.
    var visibleActivation: [Electrode: Float] {
        let usable = { (map: [Electrode: Float]) in map.filter { self.contact[$0.key] != .bad } }
        if Self.advancedView { return usable(activation[band] ?? [:]) }
        return usable(Topomap.average(Band.allCases.compactMap { activation[$0] }))
    }

    // MARK: Connection

    /// Runs once per app launch. Nothing streams until the user picks a headband on the start page.
    func launch() {
        guard !launched else { return }
        launched = true
        if UserDefaults.standard.bool(forKey: "demo") { startDemo() }  // `-demo YES` (screenshots, UI tests)
    }

    func startSearching() {
        guard muse == nil else { return }  // scan even during the demo, so a real headband can replace it
        if status != .demo { status = .searching }
        manager.startListening()
        headbands = manager.getMuses()
    }

    func stopSearching() {
        manager.stopListening()
        if status == .searching { status = .idle }
    }

    func connect(_ headband: IXNMuse) {
        disconnect()
        lastHeadband = headband.getName()
        manager.stopListening()
        muse = headband
        checkPassed = false
        status = .connecting(headband.getName())
        headband.unregisterAllListeners()
        headband.register(listener)
        for type in MuseListener.dataTypes { headband.register(listener, type: type) }
        // Muse S 2025 (Athena) has its own preset family; 4-channel EEG keeps bandwidth low.
        headband.setPreset(headband.getModel() == .ms03 ? .preset1021 : .preset21)
        headband.runAsynchronously()
        startTick()
    }

    /// The user has seen every sensor pass and pressed Start.
    func confirmStart() {
        checkPassed = true
        showingStartCheck = false
    }

    func startDemo() {
        disconnect()
        manager.stopListening()
        status = .demo
        startTick(demo: true)
    }

    func disconnect() {
        if isRecording { stopRecording() }  // keep what was captured before the link drops
        muse?.unregisterAllListeners()
        muse?.disconnect()
        muse = nil
        showingStartCheck = false
        tick?.cancel()
        tick = nil
        reset()
        status = .idle
    }

    private func reset() {
        traceBuffer = [:]; powerBuffer = [:]; activationBuffer = [:]; baselines = [:]
        metricBaselines = [:]; smoothedMetrics = [:]; metrics = [:]
        traces = [:]; power = [:]; activation = [:]; contact = [:]
        calibration = 0; battery = nil
        movement = nil; movementBuffer = nil; alphaPeak = nil
        activityHistory = []; historyStart = .now
    }

    // MARK: SDK callbacks (main thread)

    func headbandsChanged() {
        headbands = manager.getMuses()
    }

    func connectionChanged(_ state: IXNConnectionState, name: String) {
        switch state {
        case .connected:
            status = .streaming(name)
            if !checkPassed { showingStartCheck = true }
        case .needsUpdate: fail(String(localized: LocalizedStringResource("\(name) needs a firmware update. Update it in the Muse app first.", locale: AppLocale.current)))
        case .needsLicense: fail(String(localized: LocalizedStringResource("\(name) needs a licence from Interaxon.", locale: AppLocale.current)))
        case .disconnected where muse != nil:
            fail(status == .connecting(name) ? String(localized: LocalizedStringResource("Couldn't connect to \(name).", locale: AppLocale.current)) : String(localized: LocalizedStringResource("\(name) disconnected.", locale: AppLocale.current)))
        default: break
        }
    }

    private func fail(_ message: String) {
        disconnect()
        status = .failed(message)
    }

    func receive(eeg values: [Electrode: Float]) {
        let capacity = Int(Self.traceSeconds * DemoHeadband.sampleRate)
        for (electrode, value) in values {
            traceBuffer[electrode, default: []].append(value)
            if traceBuffer[electrode]!.count > capacity { traceBuffer[electrode]!.removeFirst() }
        }
    }

    func receive(band: Band, power values: [Electrode: Double]) {
        for (electrode, value) in values where value.isFinite {
            powerBuffer[band, default: [:]][electrode] = value
        }
        var bandBaselines = baselines[band] ?? [:]
        for (electrode, value) in values {
            let z = bandBaselines[electrode, default: Baseline()].update(value)
            activationBuffer[band, default: [:]][electrode] = z.map(Float.init)
        }
        baselines[band] = bandBaselines
    }

    func receive(contact values: [Electrode: ContactQuality]) { contact = values }
    func receive(battery percent: Double) { battery = percent }
    func receive(movement deviation: Double) { movementBuffer = deviation }

    // MARK: Captures

    /// Opens a capture window. One sample is taken per second until `stopRecording()`.
    func startRecording() {
        guard status.isLive else { return }
        let device = switch status {
        case .streaming(let name), .connecting(let name): name
        default: "Demo headband"
        }
        recorder.start(at: .now, device: device)
    }

    /// Closes the capture window, saves it, and offers it for review.
    @discardableResult
    func stopRecording() -> Capture? {
        guard let capture = recorder.stop(at: .now) else { return nil }
        // Not saved yet: the review sheet asks whether to save, discard or download it.
        finishedCapture = capture
        return capture
    }

    private func recordActivityFrame() {
        let values = visibleActivation
        guard !values.isEmpty else { return }
        activityHistory.append(ActivityFrame(time: Date.now.timeIntervalSince(historyStart), values: values))
        if activityHistory.count > 3600 { activityHistory.removeFirst() }  // one hour at ~1 Hz
    }

    private func appendSample() {
        guard let started = recordingStarted else { return }
        let powers: [Double?] = Band.allCases.flatMap { band in Electrode.allCases.map { power[band]?[$0] } }
        let activations: [Double?] = Band.allCases.flatMap { band in
            Electrode.allCases.map { activation[band]?[$0].map { Double($0) } }
        }
        let scores: [Double?] = Metric.allCases.map { metrics[$0]?.last?.score }
        let contacts: [ContactQuality?] = Electrode.allCases.map { contact[$0] }
        recorder.add(CaptureSample(
            time: Date.now.timeIntervalSince(started), power: powers, activation: activations,
            scores: scores, contact: contacts, movement: movement))
    }

    private func updateMetrics() {
        let bad = Set(contact.filter { $0.value == .bad }.keys)
        for metric in Metric.allCases {
            guard let index = metric.index(powerBuffer, excluding: bad),
                  // 1 reading/s: 10 s warm-up, ~2 min memory.
                  let z = metricBaselines[metric, default: Baseline(warmUp: 10, memory: 120)].update(index) else { continue }
            let smoothed = smoothedMetrics[metric].map { $0 + 0.3 * (z - $0) } ?? z  // steadier line, still responsive
            smoothedMetrics[metric] = smoothed
            metrics[metric, default: []].append(MetricSample(date: .now, score: Metric.score(z: smoothed), z: smoothed))
            if metrics[metric]!.count > 600 { metrics[metric]!.removeFirst() }
        }
    }

    // MARK: Display tick

    private func startTick(demo: Bool = false) {
        tick?.cancel()
        tick = Task { [weak self] in
            var headband = DemoHeadband()
            var frame = 0
            while !Task.isCancelled {
                guard let self else { return }
                if demo {
                    let samples = headband.nextSamples(Int(DemoHeadband.sampleRate / 30))
                    for i in 0..<samples[.tp9]!.count {
                        receive(eeg: samples.mapValues { Float($0[i]) })
                    }
                    if frame % 3 == 0 {
                        for (band, values) in headband.bandPowers() { receive(band: band, power: values) }
                        contact = Dictionary(uniqueKeysWithValues: Electrode.allCases.map { ($0, .good) })
                        battery = 87
                    }
                }
                traces = traceBuffer
                if frame % 3 == 0 { power = powerBuffer }  // 10 Hz, as libmuse updates band powers
                if frame % 10 == 0 {  // ~3 Hz: enough for the maps, and each update redraws them
                    movement = movementBuffer
                    activation = activationBuffer
                    calibration = baselines[band]?.values.map(\.progress).min() ?? 0
                }
                if frame % 30 == 0 {  // ~1 Hz
                    updateMetrics()
                    recordActivityFrame()
                    if isRecording { appendSample() }
                }
                if frame % 90 == 0 {  // ~every 3 seconds
                    alphaPeak = alphaPeakFrequency(traceBuffer[.af7] ?? [], sampleRate: DemoHeadband.sampleRate)
                }
                frame += 1
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }
}
