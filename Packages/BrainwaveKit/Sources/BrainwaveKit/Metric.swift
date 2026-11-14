import Foundation

/// Mental-state indices from band-power ratios, each scored against the person's own baseline.
///
/// - Focus: engagement index β / (α + θ) (Pope, Bogart & Bartolome, 1995) at the forehead.
/// - Calm: α / β. Alpha rises and beta falls as the body settles. The low end, where beta
///   dominates, is what people feel as tension, so it is labelled Stressed.
/// - Sleepiness: θ / α. As you drift towards sleep, alpha fades and theta takes over.
public enum Metric: Int, CaseIterable, Identifiable, Sendable {
    case focus, calm, drowsiness

    public var id: Int { rawValue }

    /// Plain names for everyday use.
    public var name: String { ["Focus", "Calm", "Sleepiness"][rawValue] }

    /// The name shown on screen. `name` stays English for the CSV columns.
    public var title: String {
        switch self {
        case .focus: String(localized: LocalizedStringResource("Focus", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .calm: String(localized: LocalizedStringResource("Calm", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .drowsiness: String(localized: LocalizedStringResource("Sleepiness", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        }
    }
    public var symbol: String { ["scope", "leaf", "moon.zzz"][rawValue] }
    public var high: String { [String(localized: LocalizedStringResource("Focused", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), String(localized: LocalizedStringResource("Calm", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), String(localized: LocalizedStringResource("Sleepy", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))][rawValue] }
    public var low: String { [String(localized: LocalizedStringResource("Distracted", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), String(localized: LocalizedStringResource("Stressed", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), String(localized: LocalizedStringResource("Alert", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))][rawValue] }
    /// The signal behind the score. Shown in advanced view only.
    public var formula: String { ["beta ÷ (alpha + theta)", "alpha ÷ beta", "theta ÷ alpha"][rawValue] }

    public var explanation: String {
        switch self {
        case .focus:
            String(localized: LocalizedStringResource("How engaged your attention is. It drops when your mind wanders or you are relaxing. Measured at the forehead, so blinking and frowning can move it.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .calm:
            String(localized: LocalizedStringResource("How settled you are. Calm rises when you relax with a clear mind, as in meditation. It falls when you feel tense, busy or restless, shown as Stressed.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .drowsiness:
            String(localized: LocalizedStringResource("How sleepy you are. Rises as you drift towards sleep, for example while reading when tired. Keep your eyes open for a fair reading.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        }
    }

    /// Focus uses the forehead, where engagement is measured; the others use every good electrode.
    public var electrodes: [Electrode] { self == .focus ? [.af7, .af8] : Electrode.allCases }

    /// log10 of the ratio, averaged over usable electrodes; nil if none has the bands needed.
    /// - power: libmuse absolute band powers (log10 µV²).
    public func index(_ power: [Band: [Electrode: Double]], excluding bad: Set<Electrode> = []) -> Double? {
        let values = electrodes.filter { !bad.contains($0) }.compactMap { e -> Double? in
            guard let a = power[.alpha]?[e], let b = power[.beta]?[e], let t = power[.theta]?[e],
                  a.isFinite, b.isFinite, t.isFinite else { return nil }
            switch self {
            case .focus: return b - log10(pow(10, a) + pow(10, t))
            case .calm: return a - b
            case .drowsiness: return t - a
            }
        }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// 0–100 score from a z-score against the personal baseline: 50 is your usual level.
    public static func score(z: Double) -> Double { 100 / (1 + exp(-1.2 * z)) }

    /// Scores at or above this count as "in the state" (focused, calm, sleepy).
    public static let stateThreshold = 65.0

    /// Short status for a score: the high or low word, or "Steady" in between.
    public func label(_ score: Double) -> String {
        score >= Self.stateThreshold ? high : score <= 35 ? low : String(localized: LocalizedStringResource("Steady", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
    }
}
