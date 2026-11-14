import Foundation
import SwiftUI
import BrainwaveKit

/// The activation map (2D topomap or 3D brain). The everyday view shows overall activity in plain terms.
/// Advanced view adds the frequency band picker and the per-sensor readings.
struct MapScreen: View {
    @Environment(Session.self) private var session
    @AppStorage("advanced") private var advanced = false
    @State private var selected: BrainRegion?

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 16) {
            if advanced {
                Picker("Band", selection: $session.band) {
                    ForEach(Band.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 520)
                Text("\(session.band.range) · \(session.band.meaning) · Tap a region for details")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Overall activity right now. Tap an area to see what it does.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            ZStack(alignment: .top) {
                TopomapView(selected: $selected)
                StatusBanner()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Legend()
            if advanced { ElectrodeStrip() }
        }
        .padding()
        .navigationTitle("Brain")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Explains what's on screen when the map can't show anything meaningful yet.
private struct StatusBanner: View {
    @Environment(Session.self) private var session

    var body: some View {
        if let message {
            Label(message.text, systemImage: message.icon)
                .font(.callout)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.opacity)
        }
    }

    private var message: (text: String, icon: String)? {
        switch session.status {
        case .idle: return (String(localized: LocalizedStringResource("Tap Connect at the top right to begin", locale: AppLocale.current)), "dot.radiowaves.left.and.right")
        case .searching: return (String(localized: LocalizedStringResource("Looking for your headband…", locale: AppLocale.current)), "antenna.radiowaves.left.and.right")
        case .failed(let message): return (message, "exclamationmark.triangle")
        case .connecting: return (String(localized: LocalizedStringResource("Connecting…", locale: AppLocale.current)), "antenna.radiowaves.left.and.right")
        case .streaming, .demo: break
        }
        if session.calibration < 1 {
            return (String(localized: LocalizedStringResource("Learning your usual level… \(Int(session.calibration * 100))%", locale: AppLocale.current)), "hourglass")
        }
        if (session.movement ?? 0) > Capture.movementLimit {
            return (String(localized: LocalizedStringResource("Hold still: movement is affecting the readings", locale: AppLocale.current)), "figure.walk")
        }
        if session.contact.values.contains(.bad) {
            return (String(localized: LocalizedStringResource("Adjust the headband: some sensors aren't touching the skin", locale: AppLocale.current)), "exclamationmark.triangle")
        }
        return nil
    }
}

private struct Legend: View {
    var body: some View {
        VStack(spacing: 4) {
            LinearGradient(
                stops: stride(from: -1.0, through: 1.0, by: 0.1).map { t in
                    let (rgb, strength) = Topomap.color(z: Float(t) * Topomap.fullScale)
                    return .init(color: Color(rgb).opacity(Double(max(strength, 0.08))), location: (t + 1) / 2)
                },
                startPoint: .leading, endPoint: .trailing)
            .frame(height: 8)
            .clipShape(Capsule())
            HStack {
                Text("Less active")
                Spacer()
                Text("Usual")
                Spacer()
                Text("More active")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: 520)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Colour scale: blue is less active than usual, red is more active.")
    }
}

/// One card per sensor: contact quality and activation. Advanced view only.
private struct ElectrodeStrip: View {
    @Environment(Session.self) private var session

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Electrode.allCases) { electrode in
                let z = session.activation[session.band]?[electrode] ?? nil
                let contact = session.contact[electrode]
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle().fill(contactColor(contact)).frame(width: 6, height: 6)
                        Text(electrode.name).font(.caption.bold())
                    }
                    Text(electrode.region).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                    if contact == .bad {
                        Text("Sensor off").font(.callout.bold()).foregroundStyle(.red)
                    } else {
                        Text(z.map { String(format: "%+.1f σ", $0) } ?? "—")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(z.map { Color(Topomap.color(z: $0).rgb) } ?? .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: 640)
    }

    private func contactColor(_ quality: ContactQuality?) -> Color {
        switch quality {
        case .good: .green
        case .ok: .yellow
        case .bad: .red
        case nil: .gray
        }
    }
}
