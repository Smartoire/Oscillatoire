import CoreBluetooth
import SwiftUI
import BrainwaveKit

/// The Headband page, as on Android: a status card with the battery, then one card with the demo
/// headband and the nearby Muse headbands. Connecting goes back to the page the user came from.
struct ConnectView: View {
    @Environment(Session.self) private var session

    private var connected: Bool { session.status.isLive }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Headband").font(.title2.weight(.bold))
                statusCard
                if [.denied, .restricted].contains(CBManager.authorization) {
                    Label("Bluetooth access is off for Brainwave. Turn it on in Settings › Privacy & Security › Bluetooth.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 14)
                }
                if case .failed(let message) = session.status {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 14)
                }
                if connected {
                    HStack {
                        Spacer()
                        Button { session.disconnect() } label: {
                            Label("Disconnect", systemImage: "stop.circle.fill")
                                .font(.headline)
                                .foregroundStyle(Color(hex: 0xE94E89))
                                .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .card()
                } else {
                    controlsCard
                }
            }
            .padding(16)
        }
        .onAppear { session.startSearching() }
        .onDisappear { session.stopSearching() }
    }

    /// The headband icon, the state and the battery, as on the Mind cards.
    private var statusCard: some View {
        let tint = connected ? Brand.online : Color.secondary
        return HStack(spacing: 14) {
            Image(systemName: "headphones")
                .font(.system(size: 40))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                Text(connected ? LocalizedStringKey("Ready") : LocalizedStringKey("Not connected"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let battery = session.battery {
                Text("\(Int(battery))%")
                    .font(.headline.monospacedDigit())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var statusTitle: String {
        switch session.status {
        case .streaming(let name): name
        case .connecting(let name): String(localized: "Connecting \(name)…")
        case .demo: String(localized: "Demo headband")
        default: String(localized: "Not connected")
        }
    }

    /// The demo headband first, then the nearby headbands. Shown only while disconnected.
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.headbands.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Looking for your headband…")
                        .font(.body)
                }
                Text("Turn on your Muse and keep it close. Close the Muse app on your phone: a headband connects to one device at a time.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Nearby headbands").font(.headline.weight(.bold))
            }
            Button("Try the demo headband") { session.startDemo() }
                .buttonStyle(BrandButtonStyle())
            ForEach(session.headbands, id: \.self) { headband in
                Button {
                    session.connect(headband)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(headband.getName())
                            Text(model(headband.getModel())).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "wifi", variableValue: signal(headband.getRssi()))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func signal(_ rssi: Double) -> Double { min(1, max(0, (rssi + 95) / 45)) }

    private func model(_ model: IXNMuseModel) -> String {
        switch model {
        case .mu01: "Muse (2014)"
        case .mu02: "Muse (2016)"
        case .mu03: "Muse 2"
        case .mu04: "Muse S"
        case .mu05: "Muse S (Gen 2)"
        case .mu06: "Muse 2 (USB-C)"
        case .ms03: "Muse S Athena"
        @unknown default: "Muse"
        }
    }
}

/// Toolbar summary of the connection.
struct ConnectionLabel: View {
    @Environment(Session.self) private var session

    var body: some View {
        switch session.status {
        case .streaming(let name):
            Label(session.battery.map { "\(name) · \(Int($0))%" } ?? name, systemImage: "dot.radiowaves.left.and.right")
        case .connecting(let name): Label("Connecting \(name)…", systemImage: "antenna.radiowaves.left.and.right")
        case .demo: Label("Demo", systemImage: "sparkles")
        default: Label("Connect headband", systemImage: "headphones")
        }
    }
}
