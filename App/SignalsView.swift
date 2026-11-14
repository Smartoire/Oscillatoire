import Charts
import SwiftUI
import BrainwaveKit

/// Raw EEG traces and the share of power in each frequency band.
struct SignalsView: View {
    @Environment(Session.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Raw EEG", subtitle: "Last \(Int(Session.traceSeconds)) seconds, ±100 µV per lane") {
                    Traces(traces: session.traces).frame(height: 280)
                }
                section("Band power", subtitle: "Share of total power per electrode") {
                    BandChart(power: session.power).frame(height: 260)
                }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Signals")
    }

    private func section(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            content()
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct Traces: View {
    let traces: [Electrode: [Float]]

    var body: some View {
        Canvas { context, size in
            let lane = size.height / CGFloat(Electrode.allCases.count)
            let capacity = Session.traceSeconds * DemoHeadband.sampleRate
            for electrode in Electrode.allCases {
                let mid = lane * (CGFloat(electrode.rawValue) + 0.5)
                context.draw(Text(electrode.name).font(.caption2.bold()).foregroundStyle(Color.of(electrode)),
                             at: CGPoint(x: 4, y: mid - lane * 0.35), anchor: .leading)
                guard let samples = traces[electrode], samples.count > 1 else { continue }
                let mean = samples.reduce(0, +) / Float(samples.count)  // libmuse EEG sits on a ~800 µV offset
                let dx = size.width / CGFloat(capacity)
                let startX = size.width - CGFloat(samples.count) * dx
                var path = Path()
                for (i, value) in samples.enumerated() {
                    let y = mid - CGFloat(max(-100, min(100, value - mean))) / 100 * lane / 2
                    let p = CGPoint(x: startX + CGFloat(i) * dx, y: y)
                    i == 0 ? path.move(to: p) : path.addLine(to: p)
                }
                context.stroke(path, with: .color(Color.of(electrode)), lineWidth: 1)
            }
        }
        .accessibilityLabel("Raw EEG traces for four electrodes")
    }
}

private struct BandChart: View {
    let power: [Band: [Electrode: Double]]

    var body: some View {
        Chart {
            ForEach(Electrode.allCases) { electrode in
                let linear = Band.allCases.map { pow(10, power[$0]?[electrode] ?? -.infinity) }
                let total = linear.reduce(0, +)
                ForEach(Band.allCases) { band in
                    BarMark(x: .value("Band", band.name),
                            y: .value("Share", total > 0 ? linear[band.rawValue] / total : 0))
                        .foregroundStyle(by: .value("Electrode", electrode.name))
                        .position(by: .value("Electrode", electrode.name))
                }
            }
        }
        .chartForegroundStyleScale(domain: Electrode.allCases.map(\.name), range: Electrode.allCases.map(Color.of))
        .chartYAxis { AxisMarks(format: FloatingPointFormatStyle<Double>.Percent()) }
        .chartYScale(domain: 0...1)
    }
}
