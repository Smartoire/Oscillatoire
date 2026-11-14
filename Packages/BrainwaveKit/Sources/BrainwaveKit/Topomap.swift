import CoreGraphics
import Foundation
import simd

/// Spreads per-electrode activation across the scalp and turns it into an image.
///
/// Muse has only four scalp electrodes, so far from them the map is a guess. Confidence
/// falls off with distance to the nearest electrode and the colour fades out with it, so
/// the picture never claims more than the sensors can see.
public enum Topomap {
    /// z-score that maps to full colour.
    public static let fullScale: Float = 2.5
    /// Distance (in head radii) over which confidence fades.
    static let reach: Float = 0.55
    /// Head-coordinate half-width covered by the rendered field (1 = the brain's edge).
    public static let extent: Float = 1.25

    /// Inverse-distance-weighted activation and 0…1 confidence at `point`.
    public static func sample(_ values: [Electrode: Float], at point: SIMD2<Float>) -> (z: Float, confidence: Float) {
        var weighted: Float = 0, total: Float = 0, nearest = Float.infinity
        for (electrode, z) in values {
            let d2 = simd_distance_squared(point, electrode.position)
            if d2 < 1e-8 { return (z, 1) }
            weighted += z / d2
            total += 1 / d2
            nearest = min(nearest, d2)
        }
        guard total > 0 else { return (0, 0) }
        return (weighted / total, exp(-nearest / (2 * reach * reach)))
    }

    /// Diverging colour for a z-score plus how strongly to apply it (0 at baseline).
    public static func color(z: Float) -> (rgb: SIMD3<Float>, strength: Float) {
        let t = min(1, abs(z) / fullScale)
        let rgb = z >= 0
            ? simd_mix(SIMD3(1.0, 0.80, 0.25), SIMD3(0.95, 0.12, 0.30), SIMD3(repeating: t))  // amber → crimson
            : simd_mix(SIMD3(0.35, 0.90, 1.0), SIMD3(0.25, 0.30, 1.0), SIMD3(repeating: t))   // cyan → indigo
        return (rgb, min(1, t * 2))
    }

    /// Per-electrode mean of several maps. An electrode counts only in the maps where it has a value.
    public static func average(_ maps: [[Electrode: Float]]) -> [Electrode: Float] {
        var sums: [Electrode: (total: Float, count: Float)] = [:]
        for map in maps {
            for (electrode, z) in map {
                let sum = sums[electrode] ?? (0, 0)
                sums[electrode] = (sum.total + z, sum.count + 1)
            }
        }
        return sums.mapValues { $0.total / $0.count }
    }

    /// Renders a square image covering `-extent…extent` in head coordinates (nose up).
    /// - background: opaque base colour (e.g. brain tissue). Nil gives a transparent overlay.
    /// - clipRadius: pixels further than this from the centre are left empty.
    /// - outlines: draw the borders between `BrainRegion`s.
    /// - highlight: lighten one region (the selected one).
    public static func image(
        _ values: [Electrode: Float], size: Int,
        clipRadius: Float = .infinity, background: SIMD3<Float>? = nil,
        outlines: Bool = false, highlight: BrainRegion? = nil
    ) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let extent = Self.extent
        let scale = 2 * extent / Float(size)
        let line: SIMD3<Float> = background == nil ? [1, 1, 1] : [0.12, 0.10, 0.12]
        for row in 0..<size {
            for column in 0..<size {
                let p = SIMD2((Float(column) + 0.5) * scale - extent, extent - (Float(row) + 0.5) * scale)
                guard simd_length(p) <= clipRadius else { continue }
                let (z, confidence) = sample(values, at: p)
                let (heat, strength) = color(z: z)
                let a = strength * confidence
                // Premultiplied RGBA.
                var (rgb, alpha) = background.map { (simd_mix($0, heat, SIMD3(repeating: a)), Float(1)) } ?? (heat * a, a)
                func over(_ color: SIMD3<Float>, _ opacity: Float) {
                    rgb = rgb * (1 - opacity) + color * opacity
                    alpha = alpha * (1 - opacity) + opacity
                }
                if outlines || highlight != nil {
                    let region = BrainRegion.at(p)
                    if region == highlight { over([1, 1, 1], 0.14) }
                    if outlines, region != BrainRegion.at(p + [scale, 0]) || region != BrainRegion.at(p + [0, scale]) {
                        over(line, 0.4)
                    }
                }
                let i = (row * size + column) * 4
                pixels[i] = UInt8(rgb.x * 255)
                pixels[i + 1] = UInt8(rgb.y * 255)
                pixels[i + 2] = UInt8(rgb.z * 255)
                pixels[i + 3] = UInt8(alpha * 255)
            }
        }
        return CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(pixels) as CFData)!,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }
}
