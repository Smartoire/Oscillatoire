import Foundation
import Charts
import SwiftUI
import UniformTypeIdentifiers
import BrainwaveKit

/// The saved captures, newest first. Opens to a timeline review.
struct CapturesView: View {
    @Environment(Session.self) private var session
    @State private var captures: [Capture] = []
    @State private var pendingDelete: Capture?

    var body: some View {
        List {
            if captures.isEmpty {
                Text("No captures yet. Press Record at the top to capture a time window.")
                    .foregroundStyle(.secondary)
            }
            ForEach(captures) { capture in
                HStack(spacing: 12) {
                    NavigationLink(value: capture) {
                        HStack {
                            CaptureRow(capture: capture)
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity)
                    Button(role: .destructive) { pendingDelete = capture } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete this capture")
                }
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = capture }
                }
            }
            .onDelete { offsets in
                for index in offsets { pendingDelete = captures[index] }
            }
        }
        .navigationDestination(for: Capture.self) { CaptureDetailView(capture: $0) }
        .confirmationDialog("Delete this capture?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    CaptureStore.delete(pendingDelete)
                    captures.removeAll { $0.id == pendingDelete.id }
                }
                pendingDelete = nil
            }
        } message: {
            Text("It is removed from this device and cannot be undone.")
        }
        .task(id: session.finishedCapture?.id) { captures = CaptureStore.loadAll() }
    }
}

/// Shown when a recording stops. The capture is not saved yet: Save keeps it in the Captures tab,
/// Cancel throws it away, and Download writes a JSON file wherever you choose.
struct FinishedCaptureSheet: View {
    let capture: Capture
    @Environment(Session.self) private var session
    @State private var downloading = false

    var body: some View {
        NavigationStack {
            CaptureDetailView(capture: capture)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { session.finishedCapture = nil }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Download", systemImage: "arrow.down.circle") { downloading = true }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            try? CaptureStore.save(capture)
                            session.finishedCapture = nil
                        }
                        .bold()
                    }
                }
        }
        .interactiveDismissDisabled()  // leaving by swipe would silently discard the capture
        .fileExporter(isPresented: $downloading, document: CaptureDocument(data: (try? capture.jsonExport()) ?? Data()),
                      contentType: .json, defaultFilename: "Brainwave capture") { _ in }
    }
}

/// A capture as a JSON file, for Download.
struct CaptureDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// One line in the list of saved captures.
struct CaptureRow: View {
    let capture: Capture

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(capture.started.formatted(date: .abbreviated, time: .shortened))
            Text("\(clock(capture.duration)) · \(capture.device)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Timeline review of one capture: the emotional states over time, a scrubber, and the brain map at that moment.
struct CaptureDetailView: View {
    let capture: Capture
    @AppStorage("advanced") private var advanced = false
    @State private var position = 0.0
    @State private var metric = Metric.focus
    @State private var band = Band.alpha
    @State private var exportFiles: [URL] = []

    private var index: Int { min(Int(position), max(capture.samples.count - 1, 0)) }
    private var current: CaptureSample? {
        capture.samples.indices.contains(index) ? capture.samples[index] : nil
    }
    /// Overall activity, or the chosen band in advanced view.
    private var values: [Electrode: Float] {
        advanced ? capture.activation(band, at: index) : capture.activity(at: index)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summary
                if capture.samples.isEmpty {
                    Text("This capture has no data.").foregroundStyle(.secondary)
                } else {
                    timeline
                    map
                }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Capture")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { CompareView(fixed: capture) } label: {
                    Label("Compare", systemImage: "arrow.left.and.right")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                // One share button for both files (CSV and JSON), not one per file.
                if !exportFiles.isEmpty {
                    ShareLink(items: exportFiles) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            let csv = try? CaptureStore.exportFile(for: capture)
            let json = try? CaptureStore.jsonFile(for: capture)
            exportFiles = [csv, json].compactMap { $0 }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(capture.started.formatted(date: .long, time: .shortened)).font(.headline)
            Text("\(clock(capture.duration)) · \(capture.device)").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Metric.allCases) { metric in
                    stat(LocalizedStringKey(stringLiteral: metric.high), clock(capture.secondsAbove(metric)))
                }
                if let moving = capture.movementShare() {
                    stat("Moving", "\(Int((moving * 100).rounded()))%")
                }
            }
            ForEach(Metric.allCases) { metric in
                if let change = capture.scoreChange(metric) {
                    Text(trendSentence(metric, change))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Text("Time in each state counts the seconds with the score at 65 or above.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Score", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(Array(capture.samples.enumerated()), id: \.offset) { _, sample in
                    if let score = sample.scores[metric.rawValue] {
                        LineMark(x: .value("Time", sample.time), y: .value(metric.title, score))
                            .interpolationMethod(.monotone)
                    }
                }
                RuleMark(y: .value("Usual", 50))
                    .foregroundStyle(.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                RuleMark(x: .value("Now", current?.time ?? 0))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .chartYScale(domain: 0...100)
            .chartXAxisLabel("Seconds into capture")
            .frame(height: 200)

            Slider(value: $position, in: 0...Double(max(capture.samples.count - 1, 1)), step: 1)
            HStack {
                Text(clock(current?.time ?? 0))
                Spacer()
                Text(clock(capture.duration))
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private var map: some View {
        VStack(alignment: .leading, spacing: 12) {
            if advanced {
                Picker("Band", selection: $band) {
                    ForEach(Band.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
            } else {
                Text("Overall activity at this moment").font(.caption).foregroundStyle(.secondary)
            }

            if values.isEmpty {
                Text("No reading at this moment.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Image(decorative: Topomap.image(values, size: 256,
                                                background: SIMD3<Float>(0.10, 0.11, 0.14), outlines: true),
                      scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
            }

            if advanced {
                HStack {
                    ForEach(Electrode.allCases) { electrode in
                        VStack(spacing: 2) {
                            Text(electrode.name).font(.caption.bold())
                            Text(values[electrode].map { String(format: "%+.1f σ", $0) } ?? "—")
                                .font(.caption.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// How one score moved over a capture, in plain words.
private func trendSentence(_ metric: Metric, _ change: Double) -> String {
    switch change {
    case ..<(-5): String(localized: LocalizedStringResource("\(metric.title) eased over the session, by about \(Int(-change)) points.", locale: AppLocale.current))
    case 5...: String(localized: LocalizedStringResource("\(metric.title) rose over the session, by about \(Int(change)) points.", locale: AppLocale.current))
    default: String(localized: LocalizedStringResource("\(metric.title) held about steady over the session.", locale: AppLocale.current))
    }
}

/// "1:05" or "1:02:03", for the lengths and times in a capture.
private func clock(_ seconds: Double) -> String {
    Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow))
}
