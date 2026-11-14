import SwiftUI
import BrainwaveKit

/// The Mind page, as on Android: three score cards with gauges, and the graph of the chosen score.
/// Landscape puts the cards in a column on the left and the graph on the right.
struct MindPage: View {
    @Environment(Session.self) private var session
    @State private var selected = Metric.focus

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            if wide {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mind").font(.headline.weight(.bold))
                        ForEach(Metric.allCases) { metric in
                            compactCard(metric)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: geo.size.width * 0.4)
                    .walkthroughTarget("mind")
                    ScrollView {
                        graphPanel
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mind").font(.title2.weight(.bold))
                        HStack(spacing: 8) {
                            ForEach(Metric.allCases) { metric in
                                scoreCard(metric)
                            }
                        }
                        .walkthroughTarget("mind")
                        graphPanel
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(16)
    }

    private var connected: Bool { session.status.isLive }

    // MARK: Cards

    private func scoreCard(_ metric: Metric) -> some View {
        let score = session.metrics[metric]?.last?.score
        return VStack(alignment: .leading, spacing: 4) {
            Text(metric.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Brand.tint(metric))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            // A fixed slot for the number, so its width and the values changing do not move the gauge.
            Text(score.map { "\(Int($0.rounded()))" } ?? "—")
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .frame(height: 56, alignment: .leading)
            ScoreGauge(value: score ?? 0, tint: Brand.tint(metric))
                .animation(.easeOut(duration: 0.9), value: score)
            // A fixed two-line slot for the caption, so a longer or shorter one does not move the card.
            // Up to two full lines, never cut off with "…"; the slot is at least two lines tall so cards line up.
            Text(caption(metric, score))
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 34, alignment: .top)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected == metric ? Brand.tint(metric) : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { selected = metric }
        .accessibilityAddTraits(selected == metric ? .isSelected : [])
    }

    /// The landscape card: the name and number on the left, the gauge on the right, no caption.
    private func compactCard(_ metric: Metric) -> some View {
        let score = session.metrics[metric]?.last?.score
        return HStack(spacing: 8) {
            VStack(alignment: .leading) {
                Text(metric.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Brand.tint(metric))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(score.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
            }
            ScoreGauge(value: score ?? 0, tint: Brand.tint(metric))
                .animation(.easeOut(duration: 0.9), value: score)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected == metric ? Brand.tint(metric) : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { selected = metric }
    }

    private func caption(_ metric: Metric, _ score: Double?) -> String {
        if let score { return metric.label(score) }
        return connected
            ? String(localized: LocalizedStringResource("Learning your baseline…", locale: AppLocale.current))
            : String(localized: LocalizedStringResource("Connect a headband", locale: AppLocale.current))
    }

    // MARK: Graph

    private var graphPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selected.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Brand.tint(selected))
            MindGraph(samples: session.metrics[selected] ?? [], tint: Brand.tint(selected))
                .frame(height: 210)
                .card()
        }
    }
}

/// The last ten minutes of one score: a 0 to 100 scale, a dashed usual level at 50, clock times along the bottom.
/// Drawn every frame, so the line glides between seconds.
struct MindGraph: View {
    let samples: [Session.MetricSample]
    let tint: Color

    /// How far behind the clock the line is drawn: one second, so the newest part is always between two samples.
    private static let renderDelay = 1.0
    /// Ten minutes on screen, the same as the history kept.
    private static let window = 600.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate - Self.renderDelay
            let points = Self.shown(Self.smoothed(samples), at: now)
            Canvas { context, size in
                let plot = CGRect(x: 12, y: 12, width: max(size.width - 56, 1), height: max(size.height - 46, 1))
                for v in [0.0, 25, 50, 75, 100] {
                    let y = plot.minY + plot.height * CGFloat(1 - v / 100)
                    if v == 50 {
                        drawDashedLine(context, from: CGPoint(x: plot.minX, y: y), to: CGPoint(x: plot.maxX, y: y))
                    } else {
                        var line = Path()
                        line.move(to: CGPoint(x: plot.minX, y: y))
                        line.addLine(to: CGPoint(x: plot.maxX, y: y))
                        context.stroke(line, with: .color(.gray.opacity(0.2)), lineWidth: 1)
                    }
                }
                if points.count >= 2 {
                    var path = Path()
                    for (i, point) in points.enumerated() {
                        let x = plot.minX + plot.width * CGFloat((point.time - (now - Self.window)) / Self.window)
                        let y = plot.minY + plot.height * CGFloat(1 - point.score / 100)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    // Three colours by level, matching the gauge zones: the metric colour high, amber steady, red low.
                    let levels = GraphicsContext.Shading.linearGradient(
                        Gradient(stops: [.init(color: tint, location: 0), .init(color: Brand.steady, location: 0.5), .init(color: Brand.low, location: 1)]),
                        startPoint: CGPoint(x: 0, y: plot.minY), endPoint: CGPoint(x: 0, y: plot.maxY))
                    context.stroke(path, with: levels, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                GraphClock.drawPercentLabels(context, plot: plot)
                GraphClock.draw(context, plot: plot, left: now - Self.window, right: now, bottom: plot.maxY + 8) {
                    Date(timeIntervalSinceReferenceDate: $0)
                }
            }
            .overlay {
                if samples.isEmpty {
                    // A solid panel behind the words, so the gridlines do not run through them.
                    Text("The graph starts after about 10 seconds of signal.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)
                }
            }
        }
    }

    /// Each score averaged with the four seconds before it, so the line glides and a point never changes once drawn.
    private static func smoothed(_ samples: [Session.MetricSample]) -> [Point] {
        samples.indices.map { index in
            let window = max(0, index - 4)...index
            let score = window.reduce(0.0) { $0 + samples[$1].score } / Double(window.count)
            return Point(time: samples[index].date.timeIntervalSinceReferenceDate, score: score)
        }
    }

    /// The line up to time `t`, ending exactly at `t` by interpolating between the two samples around it.
    private static func shown(_ points: [Point], at t: Double) -> [Point] {
        let past = points.filter { $0.time <= t }
        guard let before = past.last, let after = points.first(where: { $0.time > t }), after.time > before.time else {
            return past
        }
        let f = (t - before.time) / (after.time - before.time)
        return past + [Point(time: t, score: before.score + (after.score - before.score) * f)]
    }

    private struct Point {
        let time: Double
        let score: Double
    }
}
