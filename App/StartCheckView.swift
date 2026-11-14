import Foundation
import SwiftUI
import BrainwaveKit

/// Start-up check shown when a headband starts streaming. Every sensor must touch the skin and the
/// head must be still before Start unlocks. Failed sensors show an alarm, not a blank.
/// One line of the checklist.
private enum Check {
    case pass(String), fail(String), pending

    var isPass: Bool {
        if case .pass = self { true } else { false }
    }
}

struct StartCheckView: View {
    @Environment(Session.self) private var session

    private var sensorChecks: [Electrode: Check] {
        Dictionary(uniqueKeysWithValues: Electrode.allCases.map { electrode in
            let check: Check = switch session.contact[electrode] {
            case .good?: .pass(String(localized: LocalizedStringResource("Touching skin", locale: AppLocale.current)))
            case .ok?: .pass(String(localized: LocalizedStringResource("Touching, could be better", locale: AppLocale.current)))
            case .bad?: .fail(String(localized: LocalizedStringResource("Sensor off: adjust", locale: AppLocale.current)))
            case nil: .pending
            }
            return (electrode, check)
        })
    }

    private var movementCheck: Check {
        guard let movement = session.movement else { return .pending }
        return movement <= Capture.movementLimit ? .pass(String(localized: LocalizedStringResource("Still", locale: AppLocale.current))) : .fail(String(localized: LocalizedStringResource("Too much movement: hold still", locale: AppLocale.current)))
    }

    private var canStart: Bool {
        session.status.isLive
            && Electrode.allCases.allSatisfy { [.good, .ok].contains(session.contact[$0]) }
            && movementCheck.isPass
    }

    var body: some View {
        List {
            Section {
                // Tap Start in the top bar once this says everything is working.
                Text(canStart ? "Everything is working." : "Start unlocks when all four sensors touch the skin and you're holding still.")
                    .font(.callout)
                    .foregroundStyle(canStart ? .green : .secondary)
            }
            Section("Headband") {
                row("Connected", streamingName.map { Check.pass($0) } ?? .pending)
                row("Battery", session.battery.map { level in
                    level >= 15 ? Check.pass(String(localized: LocalizedStringResource("\(Int(level))%", locale: AppLocale.current))) : Check.fail(String(localized: LocalizedStringResource("\(Int(level))%: charge it", locale: AppLocale.current)))
                } ?? .pending)
            }
            Section {
                ForEach(Electrode.allCases) { electrode in
                    row("\(electrode.name) · \(electrode.region)", sensorChecks[electrode] ?? .pending)
                }
            } header: {
                Text("Sensors")
            } footer: {
                Text("Each sensor should touch the skin. Part the hair under any sensor that shows an alarm.")
            }
            Section {
                row("Head movement", movementCheck)
            }
        }
        .navigationTitle("Before you start")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") { session.confirmStart() }
                    .bold()
                    .disabled(!canStart)
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }

    private var streamingName: String? {
        if case .streaming(let name) = session.status { name } else { nil }
    }

    @ViewBuilder
    /// Title, then the result underneath. Stacked, so long translations and large text still fit a phone.
    private func row(_ title: LocalizedStringKey, _ check: Check) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            switch check {
            case .pass(let detail):
                Label(detail, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .fail(let detail):
                Label(detail, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .pending:
                Label("Checking…", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
