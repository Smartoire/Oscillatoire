import Foundation
import Charts
import SwiftUI
import BrainwaveKit

/// Compares two areas over time: how each one moves, and which one is ahead at each moment.
/// Shows the live headband (its last hour), or a saved capture when opened from the Captures tab.
struct CompareView: View {
    @Environment(Session.self) private var session
    @AppStorage("advanced") private var advanced = false
    @State private var comparison = Comparison.leftRight
    @State private var position = 0.0
    @State private var span = TimeSpan.minute
    /// A saved capture to compare. Nil compares the live headband.
    var fixed: Capture? = nil

    private var capture: Capture? { fixed }
    private var archive: Bool { fixed != nil }

    var body: some View {
        @Bindable var session = session
        let (first, second) = comparison.kind.areas(side: comparison.side)
        let source: [ActivityFrame] = archive ? frames(capture) : session.activityHistory
        let moments = comparedSeries(source, first, second)
        let summary = ComparisonSummary(moments)
        let index = min(Int(position), max(moments.count - 1, 0))
        let current: ComparedMoment? = archive
            ? (moments.indices.contains(index) ? moments[index] : nil)
            : moments.last
        // Local clock time: live charts start at the session's start, archived captures at their own start.
        let origin = archive ? (capture?.started ?? session.historyStart) : session.historyStart
        let firstTime = moments.first?.time ?? 0
        let window: (Double) -> ClosedRange<Date> = { end in
            if let seconds = span.seconds {
                let right = origin.addingTimeInterval(end)
                return right.addingTimeInterval(-seconds)...right
            }
            return origin.addingTimeInterval(firstTime)...origin.addingTimeInterval(max(end, firstTime + 1))
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    ForEach(Comparison.allCases) { option in
                        ComparisonTile(option: option, selected: option == comparison) { comparison = option }
                    }
                }

                Picker("Time window", selection: $span) {
                    ForEach(TimeSpan.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if advanced {
                    Picker("Band", selection: $session.band) {
                        ForEach(Band.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if moments.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    // The graph comes first; the sentence and summary read off it.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Activity over time").font(.headline)
                        TimelineView(.animation(paused: archive)) { context in
                            // Live: the clock minus a second, so the newest part is always between two recorded seconds.
                            let t = archive ? (current?.time ?? 0) : context.date.timeIntervalSince(origin) - Self.renderDelay
                            activityChart(smoothed(moments), first, second, at: t,
                                          origin: origin, domain: window(t))
                                .frame(height: 220)
                        }
                    }
                    .padding(12)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))

                    if archive {
                        Slider(value: $position, in: 0...Double(max(moments.count - 1, 1)), step: 1)
                        Text(origin.addingTimeInterval(current?.time ?? 0).formatted(date: .omitted, time: .standard))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }

                    if let current {
                        Text(comparisonSentence(first, second, zA: Float(current.first), zB: Float(current.second)))
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    summaryCard(summary, first, second)
                }

                Text("Each area is compared with your own usual level. Areas that Muse's sensors don't reach are rough estimates.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(fixed == nil ? "Compare" : "Compare capture")
    }

    private var emptyMessage: String {
        if archive { return String(localized: LocalizedStringResource("This capture has no readings to compare.", locale: AppLocale.current)) }
        return String(localized: LocalizedStringResource("Connect a headband, or try the demo, to compare areas over time.", locale: AppLocale.current))
    }

    /// Frames of a saved capture: its samples, one per recorded second.
    private func frames(_ capture: Capture?) -> [ActivityFrame] {
        guard let capture else { return [] }
        return capture.samples.indices.map { index in
            let values = advanced ? capture.activation(session.band, at: index) : capture.activity(at: index)
            return ActivityFrame(time: capture.samples[index].time, values: values)
        }
    }

    // MARK: Summary

    private func summaryCard(_ summary: ComparisonSummary, _ first: Area, _ second: Area) -> some View {
        let percent = Int((summary.firstHigherShare * 100).rounded())
        let lead: String
        switch abs(summary.averageDifference) {
        case ..<0.2: lead = String(localized: LocalizedStringResource("On average the two were about level.", locale: AppLocale.current))
        case ..<0.6: lead = String(localized: LocalizedStringResource("On average \(summary.averageDifference > 0 ? first.name.lowercased() : second.name.lowercased()) was a little ahead.", locale: AppLocale.current))
        default: lead = String(localized: LocalizedStringResource("On average \(summary.averageDifference > 0 ? first.name.lowercased() : second.name.lowercased()) was clearly ahead.", locale: AppLocale.current))
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(first.name) was the more active one \(percent)% of the time.")
                .font(.callout.weight(.semibold))
            Text("Otherwise \(second.name.lowercased()) was higher or level. \(lead)")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Charts

    /// Both areas over time, in their own colours, with the usual level at zero.
    private func activityChart(_ smoothedPoints: [Smoothed], _ first: Area, _ second: Area, at t: Double,
                               origin: Date, domain: ClosedRange<Date>) -> some View {
        let points = shownPoints(smoothedPoints, at: t)
        return Chart {
            RuleMark(y: .value("Usual", 0))
                .foregroundStyle(.white.opacity(0.25))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            ForEach(points) { moment in
                LineMark(x: .value("Time", origin.addingTimeInterval(moment.time)), y: .value("Activity", moment.first),
                         series: .value("Area", first.name))
                    .foregroundStyle(by: .value("Area", first.name))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", origin.addingTimeInterval(moment.time)), y: .value("Activity", moment.second),
                         series: .value("Area", second.name))
                    .foregroundStyle(by: .value("Area", second.name))
                    .interpolationMethod(.monotone)
            }
        }
        .chartForegroundStyleScale([first.name: Color.cyan, second.name: Color.orange])
        .chartYScale(domain: -3...3)
        .chartYAxisLabel("Compared with usual")
        .chartXScale(domain: domain)
        .chartXAxis(.hidden)
        .chartPlotStyle { plot in plot.clipped() }  // lines never run past the frame
        .chartOverlay { proxy in clockLabels(proxy, domain: domain) }
        .chartLegend(position: .top, alignment: .leading)
        .accessibilityLabel("Activity over time for \(first.name) and \(second.name), compared with usual")
    }

    // MARK: Helpers

    /// Local clock times under the plot. Drawn by hand at the same positions as the lines, so the
    /// numbers move with the data every frame instead of being re-laid out by the chart.
    private func clockLabels(_ proxy: ChartProxy, domain: ClosedRange<Date>) -> some View {
        GeometryReader { geometry in
            // Fit the labels to the width: each label needs about 70 points, so a phone gets fewer.
            let width = proxy.plotSize.width
            let step = tickStep(for: domain.upperBound.timeIntervalSince(domain.lowerBound), width: width)
            let compact = step >= 60  // whole minutes only, so labels are shorter
            ForEach(clockTicks(domain, step: step), id: \.self) { date in
                Text(date.formatted(compact ? .dateTime.hour().minute() : .dateTime.hour().minute().second()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .position(x: proxy.position(forX: date) ?? 0, y: proxy.plotSize.height + 12)
            }
        }
    }

    /// The smallest clock step that leaves room for each label across the plot.
    private func tickStep(for span: TimeInterval, width: CGFloat) -> TimeInterval {
        let steps: [TimeInterval] = [5, 10, 30, 60, 120, 300, 600, 900, 1800, 3600]
        let maxLabels = max(2, Double(width) / 70)
        return steps.first { span / $0 <= maxLabels } ?? 3600
    }

    /// Whole clock steps inside the window, so ticks stay on clock times.
    private func clockTicks(_ domain: ClosedRange<Date>, step: TimeInterval) -> [Date] {
        var t = (domain.lowerBound.timeIntervalSinceReferenceDate / step).rounded(.up) * step
        var out: [Date] = []
        while t <= domain.upperBound.timeIntervalSinceReferenceDate {
            out.append(Date(timeIntervalSinceReferenceDate: t))
            t += step
        }
        return out
    }

    /// A moment averaged with the seconds before it (about 5 seconds), so the lines glide instead of stepping.
    private struct Smoothed: Identifiable {
        let id: Int
        let time: Double
        let first: Double
        let second: Double
    }

    /// The lines up to time `t`, ending exactly at `t` by interpolating between the two recorded seconds
    /// around it. Because `t` moves every frame, the line and the axis move together, with no steps.
    private func shownPoints(_ points: [Smoothed], at t: Double) -> [Smoothed] {
        let past = points.filter { $0.time <= t }
        guard let before = past.last, let after = points.first(where: { $0.time > t }), after.time > before.time else {
            return past
        }
        let f = (t - before.time) / (after.time - before.time)
        let head = Smoothed(id: -1, time: t,
                            first: before.first + (after.first - before.first) * f,
                            second: before.second + (after.second - before.second) * f)
        return past + [head]
    }

    /// How far behind the clock the live lines are drawn: one recording interval.
    private static let renderDelay = 1.0

    private func smoothed(_ moments: [ComparedMoment], radius: Int = 2) -> [Smoothed] {
        moments.indices.map { index in
            // Only the seconds before each point, so a point never changes once it has been drawn.
            let window = max(0, index - 2 * radius)...index
            let count = Double(window.count)
            let first = window.reduce(0.0) { $0 + moments[$1].first } / count
            let second = window.reduce(0.0) { $0 + moments[$1].second } / count
            return Smoothed(id: index, time: moments[index].time, first: first, second: second)
        }
    }
}

/// How much history the Compare charts show at once.
private enum TimeSpan: CaseIterable, Identifiable {
    case minute, quarterHour, hour, all

    var id: Self { self }

    var seconds: Double? {
        switch self {
        case .minute: 60
        case .quarterHour: 900
        case .hour: 3600
        case .all: nil
        }
    }

    var label: String {
        switch self {
        case .minute: "1 m"
        case .quarterHour: "15 m"
        case .hour: "1 h"
        case .all: "All"
        }
    }
}

/// The four comparisons, each drawn as an icon.
private enum Comparison: CaseIterable, Identifiable {
    case leftRight, frontTemporal, leftSide, rightSide

    var id: Self { self }

    var kind: ComparisonKind {
        switch self {
        case .leftRight: .leftVsRight
        case .frontTemporal: .frontalVsTemporal
        case .leftSide, .rightSide: .withinSide
        }
    }

    var side: Side { self == .rightSide ? .right : .left }

    var title: String {
        switch self {
        case .leftRight: String(localized: LocalizedStringResource("Left vs right", locale: AppLocale.current))
        case .frontTemporal: String(localized: LocalizedStringResource("Front vs back", locale: AppLocale.current))
        case .leftSide: String(localized: LocalizedStringResource("Left side", locale: AppLocale.current))
        case .rightSide: String(localized: LocalizedStringResource("Right side", locale: AppLocale.current))
        }
    }
}

/// One comparison as a small top-down head: blue is the first area, orange the second.
private struct ComparisonTile: View {
    let option: Comparison
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ComparisonIcon(option: option, selected: selected)
                    .frame(width: 72, height: 72)
                // A plain dot under the chosen brain: no border or box, so it doesn't look like a Mind card.
                Circle()
                    .fill(selected ? Color.primary : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .help(option.title)  // tooltip
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The brain from above, split into quarters by colour: blue is the first area, orange the second.
private struct ComparisonIcon: View {
    let option: Comparison
    let selected: Bool

    /// Top-left, top-right, bottom-left, bottom-right.
    private var quarters: [Color] {
        let neutral = Color.white.opacity(0.1)
        switch option {
        case .leftRight: return [.cyan, .orange, .cyan, .orange]
        case .frontTemporal: return [.cyan, .cyan, .orange, .orange]
        case .leftSide: return [.cyan, neutral, .orange, neutral]
        case .rightSide: return [neutral, .cyan, neutral, .orange]
        }
    }

    var body: some View {
        ZStack {
            Image("BrainTop").resizable().scaledToFit().opacity(0.3)
            VStack(spacing: 0) {
                HStack(spacing: 0) { quarters[0]; quarters[1] }
                HStack(spacing: 0) { quarters[2]; quarters[3] }
            }
            .opacity(selected ? 1 : 0.55)
            .mask(Image("BrainTop").resizable().scaledToFit())
        }
    }
}
