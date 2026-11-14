import Foundation
import BrainwaveKit

/// Bridges libmuse's Objective-C listener callbacks into `Session`.
/// Packets are read where they arrive; only plain values cross to the main actor.
nonisolated final class MuseListener: NSObject, IXNMuseListener, IXNMuseConnectionListener, IXNMuseDataListener {
    static let bandTypes: [IXNMuseDataPacketType: Band] = [
        .deltaAbsolute: .delta, .thetaAbsolute: .theta, .alphaAbsolute: .alpha,
        .betaAbsolute: .beta, .gammaAbsolute: .gamma,
    ]
    static let dataTypes: [IXNMuseDataPacketType] = [.eeg, .hsiPrecision, .battery, .accelerometer] + bandTypes.keys

    private static let channels: [Electrode: IXNEeg] = [.tp9: .EEG1, .af7: .EEG2, .af8: .EEG3, .tp10: .EEG4]

    private weak let session: Session?

    init(session: Session) { self.session = session }

    private func onMain(_ work: @escaping @MainActor @Sendable (Session) -> Void) {
        let deliver = { @Sendable [weak session] in
            MainActor.assumeIsolated { if let session { work(session) } }
        }
        Thread.isMainThread ? deliver() : DispatchQueue.main.async(execute: deliver)
    }

    func museListChanged() {
        onMain { $0.headbandsChanged() }
    }

    func receive(_ packet: IXNMuseConnectionPacket, muse: IXNMuse?) {
        let state = packet.currentConnectionState, name = muse?.getName() ?? "Muse"
        onMain { $0.connectionChanged(state, name: name) }
    }

    func receive(_ packet: IXNMuseDataPacket?, muse: IXNMuse?) {
        guard let packet else { return }
        switch packet.packetType() {
        case .eeg:
            let eeg = Self.channelValues(packet).mapValues(Float.init)
            onMain { $0.receive(eeg: eeg) }
        case .hsiPrecision:
            let contact = Self.channelValues(packet).mapValues(ContactQuality.init(hsi:))
            onMain { $0.receive(contact: contact) }
        case .battery:
            let percent = packet.getBatteryValue(.chargePercentageRemaining)
            onMain { $0.receive(battery: percent) }
        case .accelerometer:
            let x = packet.getAccelerometerValue(.X), y = packet.getAccelerometerValue(.Y), z = packet.getAccelerometerValue(.Z)
            let deviation = abs((x * x + y * y + z * z).squareRoot() - 1)  // distance from gravity, in g
            onMain { $0.receive(movement: deviation) }
        case let type:
            guard let band = Self.bandTypes[type] else { return }
            let power = Self.channelValues(packet)
            onMain { $0.receive(band: band, power: power) }
        }
    }

    /// Per-electrode values. Only valid for EEG-shaped packets (raw, HSI, band powers):
    /// libmuse aborts the process if asked for channel values of any other packet type.
    private static func channelValues(_ packet: IXNMuseDataPacket) -> [Electrode: Double] {
        var out: [Electrode: Double] = [:]
        for (electrode, channel) in channels { out[electrode] = packet.getEegChannelValue(channel) }
        return out
    }

    func receive(_ packet: IXNMuseArtifactPacket, muse: IXNMuse?) {}
}
