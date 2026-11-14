import Foundation
import simd

/// The four areas the app talks about: the left and right frontal and temporal lobes.
///
/// Each region has a centre in head coordinates (the same as `Electrode.position`: +x is the
/// subject's right, +y is the nose). A point belongs to the side it sits on (x below 0 is left)
/// and to frontal (y at or above 0, towards the nose) or temporal (below it, towards the ears).
public enum BrainRegion: Int, CaseIterable, Identifiable, Sendable {
    case leftFrontal, rightFrontal, leftTemporal, rightTemporal

    public var id: Int { rawValue }

    public var centre: SIMD2<Float> {
        switch self {
        case .leftFrontal: [-0.4, 0.5]
        case .rightFrontal: [0.4, 0.5]
        case .leftTemporal: [-0.7, -0.4]
        case .rightTemporal: [0.7, -0.4]
        }
    }

    public var name: String {
        switch self {
        case .leftFrontal: String(localized: LocalizedStringResource("Left frontal lobe", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .rightFrontal: String(localized: LocalizedStringResource("Right frontal lobe", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .leftTemporal: String(localized: LocalizedStringResource("Left temporal lobe", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .rightTemporal: String(localized: LocalizedStringResource("Right temporal lobe", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        }
    }

    /// Label drawn on the map.
    public var shortName: String {
        switch self {
        case .leftFrontal: String(localized: LocalizedStringResource("Left frontal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .rightFrontal: String(localized: LocalizedStringResource("Right frontal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .leftTemporal: String(localized: LocalizedStringResource("Left temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .rightTemporal: String(localized: LocalizedStringResource("Right temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        }
    }

    /// Plain-language summary of what the region is best known for.
    public var function: String {
        switch self {
        case .leftFrontal:
            String(localized: LocalizedStringResource("Planning, decisions and speech production. Linked with positive, approach-oriented mood.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .rightFrontal:
            String(localized: LocalizedStringResource("Attention, impulse control and regulating emotions. Linked with cautious, withdrawal-oriented mood.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .leftTemporal:
            String(localized: LocalizedStringResource("Understanding language, verbal memory and hearing.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .rightTemporal:
            String(localized: LocalizedStringResource("Recognising faces, voices, music and the emotional tone of speech.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        }
    }

    /// The Muse sensor closest to this region, used in advanced view.
    public var electrode: Electrode {
        switch self {
        case .leftFrontal: .af7
        case .rightFrontal: .af8
        case .leftTemporal: .tp9
        case .rightTemporal: .tp10
        }
    }

    public static func at(_ point: SIMD2<Float>) -> BrainRegion {
        switch (point.x < 0, point.y >= 0) {
        case (true, true): .leftFrontal
        case (false, true): .rightFrontal
        case (true, false): .leftTemporal
        case (false, false): .rightTemporal
        }
    }
}

/// Left or right half of the head.
public enum Side: Sendable, CaseIterable {
    case left, right
}

/// A group of regions that a comparison treats as one area, such as String(localized: LocalizedStringResource("Left side", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))).
public struct Area: Sendable, Equatable {
    public let name: String
    public let regions: [BrainRegion]

    public init(name: String, regions: [BrainRegion]) {
        self.name = name
        self.regions = regions
    }

    /// Average activation over the area's regions, with the lowest coverage among them.
    public func activity(in values: [Electrode: Float]) -> (z: Float, confidence: Float) {
        let readings = regions.map { Topomap.sample(values, at: $0.centre) }
        let z = readings.map { $0.z }.reduce(0, +) / Float(readings.count)
        let confidence = readings.map { $0.confidence }.min() ?? 0
        return (z, confidence)
    }
}

/// The comparisons offered in the app.
public enum ComparisonKind: CaseIterable, Sendable {
    case leftVsRight, frontalVsTemporal, withinSide

    public var title: String {
        switch self {
        case .leftVsRight: String(localized: LocalizedStringResource("Left vs right", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .frontalVsTemporal: String(localized: LocalizedStringResource("Front vs temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        case .withinSide: String(localized: LocalizedStringResource("Within one side", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        }
    }

    /// The two areas this comparison sets against each other. `side` is used by `withinSide` only.
    public func areas(side: Side = .left) -> (Area, Area) {
        switch self {
        case .leftVsRight:
            (Area(name: String(localized: LocalizedStringResource("Left side", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.leftFrontal, .leftTemporal]),
             Area(name: String(localized: LocalizedStringResource("Right side", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.rightFrontal, .rightTemporal]))
        case .frontalVsTemporal:
            (Area(name: String(localized: LocalizedStringResource("Frontal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.leftFrontal, .rightFrontal]),
             Area(name: String(localized: LocalizedStringResource("Temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.leftTemporal, .rightTemporal]))
        case .withinSide:
            side == .left
                ? (Area(name: String(localized: LocalizedStringResource("Left frontal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.leftFrontal]),
                   Area(name: String(localized: LocalizedStringResource("Left temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.leftTemporal]))
                : (Area(name: String(localized: LocalizedStringResource("Right frontal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.rightFrontal]),
                   Area(name: String(localized: LocalizedStringResource("Right temporal", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))), regions: [.rightTemporal]))
        }
    }
}

/// Plain-language level of an activation z-score, for everyday views.
public func activityLevel(_ z: Float) -> String {
    z > 0.5 ? String(localized: LocalizedStringResource("More active than usual", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))) : z < -0.5 ? String(localized: LocalizedStringResource("Less active than usual", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL))) : String(localized: LocalizedStringResource("About usual", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
}

/// One plain sentence comparing two areas, e.g. "Left side is much more active than right side."
public func comparisonSentence(_ a: Area, _ b: Area, zA: Float, zB: Float) -> String {
    let difference = zA - zB
    let less = difference > 0 ? b : a, more = difference > 0 ? a : b
    let lessName = less.name.lowercased()
    guard abs(difference) > 0.4 else {
        return String(localized: LocalizedStringResource("\(a.name) and \(b.name.lowercased()) are about equally active.", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
    }
    if abs(difference) > 1 {
        return String(localized: LocalizedStringResource("\(more.name) is much more active than \(lessName).", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
    }
    return String(localized: LocalizedStringResource("\(more.name) is a little more active than \(lessName).", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
}

/// How much to trust the map at a point, from the topomap confidence there.
public func coverageText(confidence: Float) -> String {
    confidence > 0.6 ? String(localized: LocalizedStringResource("Measured by a nearby sensor", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        : confidence > 0.2 ? String(localized: LocalizedStringResource("Estimated from nearby sensors", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
        : String(localized: LocalizedStringResource("Not covered by Muse's sensors, rough estimate", locale: AppLocale.current, bundle: .atURL(Bundle.module.bundleURL)))
}
