import Foundation
import SwiftUI
import BrainwaveKit

/// Card shown next to a tapped brain region: what the region does and how it's doing now.
struct RegionCallout: View {
    let region: BrainRegion
    let close: () -> Void
    @Environment(Session.self) private var session
    @AppStorage("advanced") private var advanced = false

    var body: some View {
        let values = session.visibleActivation
        let (z, confidence) = Topomap.sample(values, at: region.centre)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(region.name).font(.headline)
                Spacer()
                Button("Close", systemImage: "xmark.circle.fill", action: close)
                    .labelStyle(.iconOnly).foregroundStyle(.secondary).buttonStyle(.plain)
            }
            Text(region.function).font(.callout).fixedSize(horizontal: false, vertical: true)
            Divider()
            if values.isEmpty {
                Text("No signal yet").font(.callout).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Circle().fill(Color(Topomap.color(z: z).rgb)).frame(width: 10, height: 10)
                    Text(activityLevel(z)).font(.callout.bold())
                }
                if advanced {
                    Text("\(session.band.name): \(String(format: "%+.1f σ", z))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text(coverageText(confidence: confidence)).font(.caption).foregroundStyle(.secondary)
            }
            if advanced {
                Text("Sensor \(region.electrode.name): \(contact(session.contact[region.electrode]))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
    }

    private func contact(_ quality: ContactQuality?) -> String {
        switch quality {
        case .good: String(localized: LocalizedStringResource("good contact", locale: AppLocale.current))
        case .ok: String(localized: LocalizedStringResource("fair contact", locale: AppLocale.current))
        case .bad: String(localized: LocalizedStringResource("not touching the skin", locale: AppLocale.current))
        case nil: String(localized: LocalizedStringResource("no signal", locale: AppLocale.current))
        }
    }
}

extension View {
    /// Places `RegionCallout` near `anchor`, kept inside the view's bounds.
    func regionCallout(_ region: Binding<BrainRegion?>, at anchor: CGPoint) -> some View {
        overlay {
            GeometryReader { geometry in
                if let selected = region.wrappedValue {
                    let size = geometry.size
                    let above = anchor.y > size.height * 0.45
                    RegionCallout(region: selected) { region.wrappedValue = nil }
                        .position(x: min(max(anchor.x, 150), size.width - 150),
                                  y: above ? max(anchor.y - 110, 100) : min(anchor.y + 110, size.height - 100))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: region.wrappedValue)
    }
}
