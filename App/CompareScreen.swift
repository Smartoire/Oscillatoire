import SwiftUI
import BrainwaveKit

// The Compare page, as on Android: four tiles with a brain outline, a time range, a gauge summary,
// the two areas over time and one plain sentence. It shows the live headband, from the last hour kept.

/// The four comparisons, in the order of the Android tiles.
private enum CompareTile: CaseIterable, Identifiable {
    case leftRight, frontTemporal, leftSide, rightSide

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .leftRight: "Left vs right"
        case .frontTemporal: "Front vs temporal"
        case .leftSide: "Left side"
        case .rightSide: "Right side"
        }
    }

    var kind: ComparisonKind {
        switch self {
        case .leftRight: .leftVsRight
        case .frontTemporal: .frontalVsTemporal
        case .leftSide, .rightSide: .withinSide
        }
    }

    var side: Side { self == .rightSide ? .right : .left }

    /// Quarters from top-left, top-right, bottom-left, bottom-right: the first area's colour, the second's, or none.
    var quarters: [Color?] {
        let a = Brand.firstArea, b = Brand.secondArea
        switch self {
        case .leftRight: return [a, b, a, b]
        case .frontTemporal: return [a, a, b, b]
        case .leftSide: return [a, nil, b, nil]
        case .rightSide: return [nil, a, nil, b]
        }
    }
}

/// How much history the graph shows.
private enum CompareSpan: CaseIterable, Identifiable {
    case minute, quarterHour, hour, all

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .minute: "1 m"
        case .quarterHour: "15 m"
        case .hour: "1 h"
        case .all: "All"
        }
    }

    /// Seconds on screen, or nil for everything recorded so far.
    var seconds: Double? {
        switch self {
        case .minute: 60
        case .quarterHour: 900
        case .hour: 3600
        case .all: nil
        }
    }
}

struct ComparePage: View {
    @Environment(Session.self) private var session
    @State private var tile = CompareTile.leftRight
    @State private var span = CompareSpan.minute

    var body: some View {
        let (first, second) = tile.kind.areas(side: tile.side)
        let moments = comparedSeries(session.activityHistory, first, second)
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                // Landscape: the tiles, time range and summary on the left, the graph on the right.
                HStack(alignment: .top, spacing: 16) {
                    ScrollView {
                        VStack(spacing: 10) {
                            tileList
                            spanPicker
                            summaryCard(first, second, moments)
                            sentence(first, second, moments)
                        }
                    }
                    .frame(width: geo.size.width * 0.4)
                    ScrollView {
                        graphCard(first, second, moments, height: 220)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Portrait: the same order as landscape, one column: tiles, time range, summary, graph, sentence.
                ScrollView {
                    VStack(spacing: 10) {
                        tileRow
                        spanPicker
                        summaryCard(first, second, moments)
                        graphCard(first, second, moments, height: 170)
                        sentence(first, second, moments)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(16)
    }

    // MARK: Tiles and range

    private var tileRow: some View {
        HStack(spacing: 8) {
            ForEach(CompareTile.allCases) { option in
                tileView(option)
            }
        }
    }

    private var tileList: some View {
        VStack(spacing: 8) {
            ForEach(CompareTile.allCases) { option in
                tileView(option)
            }
        }
    }

    private func tileView(_ option: CompareTile) -> some View {
        let selected = tile == option
        return VStack(spacing: 4) {
            brainTile(option.quarters, selected: selected)
                .frame(width: 56, height: 56)
            Text(option.title)
                .font(.caption2.weight(selected ? .bold : .regular))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            // A plain bar marks the chosen comparison: no border, so it does not look like a Mind card.
            BrandRule().opacity(selected ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 6)
        .card(radius: 22)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.clear), lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { tile = option }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The brain outline, faint, with its four quarters coloured inside it.
    private func brainTile(_ quarters: [Color?], selected: Bool) -> some View {
        func quarter(_ colour: Color?) -> some View {
            Rectangle().fill(colour?.opacity(selected ? 1 : 0.55) ?? Color.clear)
        }
        return ZStack {
            Image("BrainTop").resizable().scaledToFit().opacity(0.3)
            VStack(spacing: 0) {
                HStack(spacing: 0) { quarter(quarters[0]); quarter(quarters[1]) }
                HStack(spacing: 0) { quarter(quarters[2]); quarter(quarters[3]) }
            }
            .mask(Image("BrainTop").resizable().scaledToFit())
        }
    }

    private var spanPicker: some View {
        Picker("Time range", selection: $span) {
            ForEach(CompareSpan.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: Summary

    /// The gauge at rest with the connect message, or the real summary once data arrives.
    @ViewBuilder
    private func summaryCard(_ first: Area, _ second: Area, _ moments: [ComparedMoment]) -> some View {
        if moments.isEmpty {
            HStack(spacing: 12) {
                CompareGauge(share: 0.5).frame(maxWidth: .infinity)
                Text("Connect a headband, or try the demo, to compare areas over time.")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .card(radius: 14)
        } else {
            let summary = ComparisonSummary(moments)
            let percent = Int((summary.firstHigherShare * 100).rounded())
            let lead: String = {
                switch abs(summary.averageDifference) {
                case ..<0.2: return String(localized: LocalizedStringResource("On average the two were about level.", locale: AppLocale.current))
                case ..<0.6: return String(localized: LocalizedStringResource("On average \(summary.averageDifference > 0 ? first.name.lowercased() : second.name.lowercased()) was a little ahead.", locale: AppLocale.current))
                default: return String(localized: LocalizedStringResource("On average \(summary.averageDifference > 0 ? first.name.lowercased() : second.name.lowercased()) was clearly ahead.", locale: AppLocale.current))
                }
            }()
            HStack(spacing: 12) {
                // The needle sits at the share of time the first area was the more active one.
                CompareGauge(share: summary.firstHigherShare).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(first.name) was the more active one \(percent)% of the time.")
                        .font(.callout.weight(.semibold))
                    Text("Otherwise \(second.name.lowercased()) was higher or level. \(lead)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .card(radius: 14)
        }
    }

    // MARK: Graph

    private func graphCard(_ first: Area, _ second: Area, _ moments: [ComparedMoment], height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Activity over time").font(.headline)
            HStack(spacing: 12) {
                LegendDot(name: first.name, colour: Brand.firstArea)
                LegendDot(name: second.name, colour: Brand.secondArea)
            }
            Text("Compared with usual").font(.caption2).foregroundStyle(.secondary)
            CompareGraph(moments: moments, first: first, second: second,
                         origin: session.historyStart, span: span)
                .frame(height: height)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 14)
    }

    @ViewBuilder
    private func sentence(_ first: Area, _ second: Area, _ moments: [ComparedMoment]) -> some View {
        if let latest = moments.last {
            Text(comparisonSentence(first, second, zA: Float(latest.first), zB: Float(latest.second)))
                .font(.headline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LegendDot: View {
    let name: String
    let colour: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(colour).frame(width: 10, height: 10)
            Text(verbatim: name).font(.caption.weight(.semibold))
        }
    }
}

/// Both areas over time, each in its colour, with the usual level at zero.
private struct CompareGraph: View {
    let moments: [ComparedMoment]
    let first: Area
    let second: Area
    let origin: Date
    let span: CompareSpan

    /// The lines are drawn one second behind the clock, so the newest part is always between two recorded seconds.
    private static let renderDelay = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(origin) - Self.renderDelay
            let (left, right) = window(at: t)
            let points = shown(smoothed(moments), at: t)
            Canvas { context, size in
                let plot = CGRect(x: 4, y: 4, width: max(size.width - 8, 1), height: max(size.height - 24, 1))
                let zero = plot.minY + plot.height / 2
                drawDashedLine(context, from: CGPoint(x: plot.minX, y: zero), to: CGPoint(x: plot.maxX, y: zero))
                func x(_ time: Double) -> CGFloat { plot.minX + plot.width * CGFloat((time - left) / (right - left)) }
                func y(_ z: Double) -> CGFloat { plot.minY + plot.height * CGFloat(1 - (z + 3) / 6) }
                if points.count >= 2 {
                    var a = Path(), b = Path()
                    for (i, p) in points.enumerated() {
                        if i == 0 {
                            a.move(to: CGPoint(x: x(p.time), y: y(p.first)))
                            b.move(to: CGPoint(x: x(p.time), y: y(p.second)))
                        } else {
                            a.addLine(to: CGPoint(x: x(p.time), y: y(p.first)))
                            b.addLine(to: CGPoint(x: x(p.time), y: y(p.second)))
                        }
                    }
                    context.stroke(a, with: .color(Brand.firstArea), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    context.stroke(b, with: .color(Brand.secondArea), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                GraphClock.draw(context, plot: plot, left: left, right: right, bottom: plot.maxY + 4) {
                    origin.addingTimeInterval($0)
                }
            }
            .overlay {
                if moments.isEmpty {
                    Text("Connect a headband, or try the demo, to compare areas over time.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
    }

    /// The visible window: the last span, or everything recorded so far.
    private func window(at t: Double) -> (Double, Double) {
        if let seconds = span.seconds { return (t - seconds, t) }
        let left = moments.first?.time ?? 0
        return (left, max(t, left + 1))
    }

    private struct Point {
        let time: Double
        let first: Double
        let second: Double
    }

    /// Each point averaged with up to four seconds before it, so the lines glide.
    private func smoothed(_ moments: [ComparedMoment]) -> [Point] {
        moments.indices.map { i in
            let from = max(0, i - 4)
            let count = Double(i - from + 1)
            var first = 0.0, second = 0.0
            for j in from...i {
                first += moments[j].first
                second += moments[j].second
            }
            return Point(time: moments[i].time, first: first / count, second: second / count)
        }
    }

    /// The lines up to time `t`, ending exactly at `t` by interpolating between the two seconds around it.
    private func shown(_ points: [Point], at t: Double) -> [Point] {
        let past = points.filter { $0.time <= t }
        guard let before = past.last, let after = points.first(where: { $0.time > t }), after.time > before.time else {
            return past
        }
        let f = (t - before.time) / (after.time - before.time)
        return past + [Point(time: t,
                             first: before.first + (after.first - before.first) * f,
                             second: before.second + (after.second - before.second) * f)]
    }
}
