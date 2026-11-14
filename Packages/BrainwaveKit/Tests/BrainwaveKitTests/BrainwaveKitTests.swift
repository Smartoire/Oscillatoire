import Foundation
import Testing
import simd
@testable import BrainwaveKit

@Test func electrodeLayoutMatches1020System() {
    // Left electrodes on the left, frontal ones in front, temporal ones behind the ears.
    #expect(Electrode.af7.position.x < 0 && Electrode.af8.position.x > 0)
    #expect(Electrode.af7.position.y > 0.7 && Electrode.tp9.position.y < 0)
    #expect(abs(simd_length(Electrode.af7.position) - 1) < 1e-5)  // on the equator
    #expect(Electrode.reference == SIMD2(0, 1))
}

@Test func baselineReportsDeviationAfterWarmUp() {
    var baseline = Baseline(warmUp: 20, memory: 200)
    for i in 0..<19 { #expect(baseline.update(i.isMultiple(of: 2) ? 1 : -1) == nil) }
    #expect(baseline.update(1) != nil)
    for i in 0..<200 { _ = baseline.update(i.isMultiple(of: 2) ? 1 : -1) }
    #expect(baseline.update(3)! > 2)   // well above baseline → active
    #expect(baseline.update(-3)! < -2) // well below → deactivated
    #expect(baseline.update(.nan) == nil)
}

@Test func topomapIsExactAtElectrodesAndFadesFarAway() {
    let values: [Electrode: Float] = [.tp9: -2, .af7: 2, .af8: 0, .tp10: 1]
    for (electrode, z) in values {
        let s = Topomap.sample(values, at: electrode.position)
        #expect(s.z == z && s.confidence == 1)
    }
    #expect(Topomap.sample(values, at: SIMD2(0, -1)).confidence < 0.1)  // occipital: no sensor
    #expect(Topomap.sample([:], at: .zero).confidence == 0)
    #expect(Topomap.color(z: 0).strength == 0)
    let image = Topomap.image(values, size: 32)
    #expect(image.width == 32 && image.height == 32)
}

@Test func demoHeadbandProducesPlausibleData() {
    var demo = DemoHeadband()
    let samples = demo.nextSamples(256)
    #expect(samples.count == 4 && samples[.af7]!.count == 256)
    #expect(samples.values.allSatisfy { $0.allSatisfy { abs($0) < 200 } })
    let powers = demo.bandPowers()
    #expect(powers[.alpha]![.tp9]!.isFinite)
}

@Test func regionsMatchTheirElectrodes() {
    for region in BrainRegion.allCases {
        #expect(BrainRegion.at(region.centre) == region)
        #expect(BrainRegion.at(region.electrode.position) == region)
    }
    let values: [Electrode: Float] = [.tp9: 1, .af7: 1, .af8: 1, .tp10: 1]
    #expect(coverageText(confidence: Topomap.sample(values, at: BrainRegion.leftFrontal.centre).confidence).hasPrefix("Measured"))
    #expect(coverageText(confidence: Topomap.sample(values, at: SIMD2<Float>(0, -1)).confidence).hasPrefix("Not covered"))
    #expect(Topomap.image(values, size: 16, outlines: true, highlight: .rightTemporal).width == 16)
}

@Test func metricsMoveWithTheirBands() {
    func power(alpha: Double, beta: Double, theta: Double = 1) -> [Band: [Electrode: Double]] {
        let all = { (v: Double) in Dictionary(uniqueKeysWithValues: Electrode.allCases.map { ($0, v) }) }
        return [.alpha: all(alpha), .beta: all(beta), .theta: all(theta)]
    }
    let busy = power(alpha: 0.8, beta: 1.2), relaxed = power(alpha: 1.5, beta: 0.5)
    #expect(Metric.focus.index(busy)! > Metric.focus.index(relaxed)!)
    #expect(Metric.calm.index(relaxed)! > Metric.calm.index(busy)!)
    #expect(Metric.drowsiness.index(power(alpha: 0.5, beta: 1, theta: 1.5))! > Metric.drowsiness.index(relaxed)!)
    #expect(Metric.focus.index(busy, excluding: [.af7, .af8]) == nil)    // forehead only
    #expect(Metric.calm.index(busy, excluding: [.af7, .af8]) != nil)     // temporal sensors still count
    #expect(Metric.calm.index([:]) == nil)
    #expect(Metric.score(z: 0) == 50 && Metric.score(z: 2) > 85 && Metric.score(z: -2) < 15)
}

@Test func captureCSVHasOneRowPerSampleAndFixedColumns() throws {
    let sample = CaptureSample(
        time: 1.5,
        power: Array<Double?>(repeating: 0.5, count: 20),
        activation: Array<Double?>(repeating: nil, count: 20),
        scores: [60, nil, 40],
        contact: Array<ContactQuality?>(repeating: .good, count: 4),
        movement: 0.05)
    let capture = Capture(started: .now, device: "Test", duration: 2, samples: [sample, sample])
    let lines = capture.csv().split(separator: "\n", omittingEmptySubsequences: true)
    #expect(lines.count == 3)  // header + 2 samples
    #expect(lines[0].split(separator: ",").count == 1 + 20 + 20 + 3 + 4 + 1)
    #expect(lines[1].split(separator: ",", omittingEmptySubsequences: false).count == 49)
    #expect(capture.activation(.alpha, at: 0).isEmpty)
    #expect(capture.activation(.alpha, at: 9).isEmpty)

    // Survives a save and reload.
    let data = try JSONEncoder().encode(capture)
    #expect(try JSONDecoder().decode(Capture.self, from: data) == capture)
}

@Test func captureSummaryCountsTimeAboveAndMovement() {
    func sample(_ t: Double, focus: Double?, movement: Double?) -> CaptureSample {
        CaptureSample(time: t, power: Array<Double?>(repeating: nil, count: 20),
                      activation: Array<Double?>(repeating: nil, count: 20),
                      scores: [focus, nil, nil], contact: Array<ContactQuality?>(repeating: nil, count: 4),
                      movement: movement)
    }
    let capture = Capture(started: .now, device: "Test", duration: 4, samples: [
        sample(0, focus: 70, movement: 0.01),
        sample(1, focus: 70, movement: 0.5),
        sample(2, focus: 40, movement: 0.01),
        sample(3, focus: 80, movement: nil),
    ])
    #expect(capture.secondsAbove(.focus) == 2)  // 0→1 and 1→2 are above; 2→3 is below
    #expect(capture.secondsAbove(.calm) == 0)
    #expect(capture.movementShare() == 1.0 / 3.0)
    #expect(Capture(started: .now, device: "", duration: 0, samples: []).movementShare() == nil)
}

@Test func plainLanguageHelpersDescribeActivity() {
    #expect(activityLevel(1) == "More active than usual")
    #expect(activityLevel(-1) == "Less active than usual")
    #expect(activityLevel(0.1) == "About usual")
    let (left, right) = ComparisonKind.leftVsRight.areas()
    #expect(comparisonSentence(left, right, zA: 1.5, zB: 0) == "Left side is much more active than right side.")
    #expect(comparisonSentence(left, right, zA: 0, zB: 0.6) == "Right side is a little more active than left side.")
    #expect(comparisonSentence(left, right, zA: 0.2, zB: 0) == "Left side and right side are about equally active.")
}

@Test func comparisonsGroupRegionsIntoAreas() {
    let (front, temporal) = ComparisonKind.frontalVsTemporal.areas()
    #expect(front.regions == [.leftFrontal, .rightFrontal])
    #expect(temporal.regions == [.leftTemporal, .rightTemporal])
    let (leftFront, leftTemporal) = ComparisonKind.withinSide.areas(side: .left)
    #expect(leftFront.regions == [.leftFrontal] && leftTemporal.regions == [.leftTemporal])
    // Left frontal reads high and left temporal low: the left-side comparison has a clear winner.
    let values: [Electrode: Float] = [.af7: 2, .tp9: -2, .af8: 0, .tp10: 0]
    #expect(leftFront.activity(in: values).z > 1 && leftTemporal.activity(in: values).z < -1)
}

@Test func averageUsesOnlyMapsWithAValue() {
    let averaged = Topomap.average([[.tp9: 1, .af7: 2], [.tp9: 3]])
    #expect(averaged[.tp9] == 2)
    #expect(averaged[.af7] == 2)
    #expect(averaged[.af8] == nil)
}

@Test func captureActivityAveragesBands() {
    var activation = Array<Double?>(repeating: nil, count: 20)
    activation[0 * 4 + 0] = 1   // delta, TP9
    activation[2 * 4 + 0] = 3   // alpha, TP9
    let sample = CaptureSample(time: 0, power: Array<Double?>(repeating: nil, count: 20), activation: activation,
                               scores: [nil, nil, nil], contact: Array<ContactQuality?>(repeating: nil, count: 4), movement: nil)
    let capture = Capture(started: .now, device: "", duration: 1, samples: [sample])
    #expect(capture.activity(at: 0)[.tp9] == 2)
    #expect(capture.activity(at: 0)[.af7] == nil)
}

@Test func comparedSeriesTracksBothAreasAndTheirGap() {
    let (left, right) = ComparisonKind.leftVsRight.areas()
    let frames = [
        ActivityFrame(time: 0, values: [.af7: 2, .tp9: 0, .af8: 0, .tp10: 0]),   // left higher
        ActivityFrame(time: 1, values: [.af7: 0, .tp9: 0, .af8: 2, .tp10: 0]),   // right higher
        ActivityFrame(time: 2, values: [:]),                                      // no reading: skipped
        ActivityFrame(time: 3, values: [.af7: 1, .tp9: 1, .af8: 1, .tp10: 1]),   // equal
    ]
    let moments = comparedSeries(frames, left, right)
    #expect(moments.map(\.time) == [0, 1, 3])
    #expect(moments[0].difference > 0 && moments[1].difference < 0)
    #expect(abs(moments[2].difference) < 1e-6)

    let summary = ComparisonSummary(moments)
    #expect(abs(summary.firstHigherShare - 1.0 / 3.0) < 1e-6)
    #expect(ComparisonSummary([]).firstHigherShare == 0)
}

@Test func scoreChangeComparesTheEndWithTheStart() {
    func sample(_ t: Double, _ focus: Double?) -> CaptureSample {
        CaptureSample(time: t, power: Array<Double?>(repeating: nil, count: 20),
                      activation: Array<Double?>(repeating: nil, count: 20),
                      scores: [focus, nil, nil], contact: Array<ContactQuality?>(repeating: nil, count: 4), movement: nil)
    }
    let scores: [Double?] = [50, 50, 50, 50, 50, 50, 70, 70, 70]
    let capture = Capture(started: .now, device: "", duration: 9,
                          samples: scores.enumerated().map { sample(Double($0.offset), $0.element) })
    #expect(capture.scoreChange(.focus) == 20)
    #expect(capture.scoreChange(.calm) == nil)
    #expect(Capture(started: .now, device: "", duration: 1, samples: [sample(0, 50)]).scoreChange(.focus) == nil)
}

@Test func recorderOpensAddsAndClosesOneWindow() {
    func sample(_ t: Double) -> CaptureSample {
        CaptureSample(time: t, power: Array<Double?>(repeating: nil, count: 20),
                      activation: Array<Double?>(repeating: nil, count: 20),
                      scores: [nil, nil, nil], contact: Array<ContactQuality?>(repeating: nil, count: 4), movement: nil)
    }
    let t0 = Date(timeIntervalSince1970: 1_000)
    var recorder = CaptureRecorder()
    recorder.add(sample(0))                      // ignored: not recording
    #expect(recorder.stop(at: t0) == nil)

    recorder.start(at: t0, device: "Muse A")
    recorder.start(at: t0.addingTimeInterval(5), device: "Muse B")  // ignored: already open
    #expect(recorder.device == "Muse A" && recorder.started == t0)
    recorder.add(sample(1))
    recorder.add(sample(2))
    let capture = recorder.stop(at: t0.addingTimeInterval(3))
    #expect(capture?.samples.count == 2)
    #expect(capture?.duration == 3 && capture?.device == "Muse A")
    #expect(!recorder.isRecording)

    recorder.start(at: t0, device: "Muse A")     // nothing added: no capture
    #expect(recorder.stop(at: t0) == nil)
}

@Test func jsonExportNamesTheFormatAndKeepsTheSamples() throws {
    let sample = CaptureSample(time: 0, power: Array<Double?>(repeating: nil, count: 20),
                               activation: Array<Double?>(repeating: nil, count: 20),
                               scores: [60, nil, 40], contact: Array<ContactQuality?>(repeating: .ok, count: 4), movement: nil)
    let capture = Capture(started: .now, device: "Test", duration: 1, samples: [sample])
    let object = try JSONSerialization.jsonObject(with: capture.jsonExport()) as? [String: Any]
    #expect(object?["format"] as? String == "brainwave.capture")
    #expect(object?["version"] as? Int == 1)
    let inner = object?["capture"] as? [String: Any]
    #expect((inner?["samples"] as? [Any])?.count == 1)
}

@Test func alphaPeakFindsATenHertzRhythm() {
    let rate = 256.0
    let signal = (0..<1024).map { i in Float(40 + 20 * sin(2 * Double.pi * 10 * Double(i) / rate)) }
    let peak = alphaPeakFrequency(signal, sampleRate: rate)
    #expect(peak != nil && abs(peak! - 10) <= 0.25)
    #expect(alphaPeakFrequency(Array(repeating: 1, count: 1024), sampleRate: rate) == nil)
    #expect(alphaPeakFrequency(Array(repeating: 1, count: 100), sampleRate: rate) == nil)
}

@Test func balanceAveragesWhatIsKnown() {
    #expect(balanceScore(focus: 60, calm: 40) == 50)
    #expect(balanceScore(focus: nil, calm: 40) == 40)
    #expect(balanceScore(focus: nil, calm: nil) == nil)
}

@Test func calmSummaryCountsTheWeekAndTheStreak() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 18))!
    func day(_ offset: Int, minutes: Double) -> CalmSessionRecord {
        CalmSessionRecord(date: calendar.date(byAdding: .day, value: -offset, to: now)!,
                          calmSeconds: minutes * 60, totalSeconds: minutes * 60 * 2)
    }
    // Sessions today, yesterday and two days ago, and one nine days ago (outside the week).
    let records = [day(0, minutes: 5), day(1, minutes: 10), day(2, minutes: 3), day(9, minutes: 20)]
    let summary = CalmSummary(records, now: now, calendar: calendar)
    #expect(summary.sessionsThisWeek == 3)
    #expect(summary.calmMinutesThisWeek == 18)
    #expect(summary.streakDays == 3)

    // No session today yet: the streak counts from yesterday.
    let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 8))!
    let streakFromYesterday = CalmSummary([day(1, minutes: 4), day(2, minutes: 4)], now: morning, calendar: calendar)
    #expect(streakFromYesterday.streakDays == 2)
    #expect(CalmSummary([], now: now, calendar: calendar).streakDays == 0)
}
