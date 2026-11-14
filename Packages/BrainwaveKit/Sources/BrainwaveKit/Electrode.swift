import Foundation
import simd

/// The four Muse EEG electrodes, in the SDK's EEG1…EEG4 channel order.
public enum Electrode: Int, CaseIterable, Identifiable, Sendable {
    case tp9, af7, af8, tp10

    public var id: Int { rawValue }

    public var name: String { String(describing: self).uppercased() }

    public var region: String {
        switch self {
        case .tp9: String(localized: LocalizedStringResource("Left temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .af7: String(localized: LocalizedStringResource("Left frontal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .af8: String(localized: LocalizedStringResource("Right frontal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .tp10: String(localized: LocalizedStringResource("Right temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        }
    }

    /// International 10-20 position: angle from the vertex (Cz) and azimuth from the nose,
    /// positive towards the subject's right.
    var sphere: (polar: Float, azimuth: Float) {
        switch self {
        case .tp9: (108, -108)
        case .af7: (90, -36)
        case .af8: (90, 36)
        case .tp10: (108, 108)
        }
    }

    /// Top-down azimuthal-equidistant projection: radius 1 = the ear-to-nose equator,
    /// +x = subject's right, +y = nose. This is the standard EEG topomap layout.
    public var position: SIMD2<Float> { Self.project(polar: sphere.polar, azimuth: sphere.azimuth) }

    /// Fpz, the Muse reference electrode on the forehead.
    public static let reference = project(polar: 90, azimuth: 0)

    static func project(polar: Float, azimuth: Float) -> SIMD2<Float> {
        let r = polar / 90, a = azimuth * .pi / 180
        return SIMD2(r * sin(a), r * cos(a))
    }
}

public enum Band: Int, CaseIterable, Identifiable, Sendable {
    case delta, theta, alpha, beta, gamma

    public var id: Int { rawValue }
    public var name: String { ["Delta", "Theta", "Alpha", "Beta", "Gamma"][rawValue] }
    public var range: String { ["1–4 Hz", "4–8 Hz", "7.5–13 Hz", "13–30 Hz", "30–44 Hz"][rawValue] }
    public var meaning: String {
        [String(localized: LocalizedStringResource("Deep sleep, drowsiness", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), String(localized: LocalizedStringResource("Daydreaming, memory", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), String(localized: LocalizedStringResource("Relaxed, eyes closed", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))),
         String(localized: LocalizedStringResource("Focus, active thinking", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), String(localized: LocalizedStringResource("Intense processing", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))][rawValue]
    }
    /// Representative frequency, used by the demo headband.
    var hertz: Double { [2.5, 6, 10, 20, 38][rawValue] }
}

/// Muse's horseshoe indicator: how well an electrode touches the skin.
public enum ContactQuality: Sendable, Codable, Hashable {
    case good, ok, bad

    public var label: String { "\(self)" }

    /// From the SDK's HSI precision value (1 good, 2 ok, 4 bad).
    public init(hsi: Double) {
        self = hsi <= 1 ? .good : hsi <= 2 ? .ok : .bad
    }
}
