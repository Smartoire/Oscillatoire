import Foundation
import SwiftUI
import simd
import BrainwaveKit

/// Top-down map (nose up): the brain shaded by activity, with the four regions outlined.
/// Tap a region for details.
struct TopomapView: View {
    @Environment(Session.self) private var session
    @Binding var selected: BrainRegion?

    var body: some View {
        let values = session.visibleActivation
        let heat = Image(decorative: Topomap.image(values, size: 128, clipRadius: 1.02,
                                                   outlines: true, highlight: selected), scale: 1)
        GeometryReader { geometry in
            let layout = Layout(size: geometry.size)
            Canvas { context, _ in
                draw(in: &context, layout: layout, heat: heat)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let p = layout.head(location)
                selected = simd_length(p) <= 1.05 ? BrainRegion.at(p) : nil
            }
            .regionCallout($selected, at: selected.map { layout.point($0.centre) } ?? .zero)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary(values))
        .accessibilityActions {
            ForEach(BrainRegion.allCases) { region in
                Button(region.name) { selected = region }
            }
        }
    }

    /// Maps head coordinates (x right, y nose; the brain's edge at radius 1) to the view.
    /// The brain is longer than it is wide, so y is stretched by the render's aspect ratio.
    struct Layout {
        static let aspect: CGFloat = 768.0 / 618.0  // BrainTop render, height / width
        let centre: CGPoint, unit: CGFloat

        init(size: CGSize) {
            unit = min(size.width / 2.9, size.height / (2.75 * Self.aspect))
            centre = CGPoint(x: size.width / 2, y: size.height / 2 + unit * 0.08)
        }

        func point(_ p: SIMD2<Float>) -> CGPoint {
            CGPoint(x: centre.x + CGFloat(p.x) * unit, y: centre.y - CGFloat(p.y) * unit * Self.aspect)
        }

        func head(_ point: CGPoint) -> SIMD2<Float> {
            SIMD2(Float((point.x - centre.x) / unit), Float((centre.y - point.y) / (unit * Self.aspect)))
        }

        func rect(radius r: CGFloat) -> CGRect {
            CGRect(x: centre.x - r * unit, y: centre.y - r * unit * Self.aspect, width: 2 * r * unit, height: 2 * r * unit * Self.aspect)
        }
    }

    private func draw(in context: inout GraphicsContext, layout: Layout, heat: Image) {
        let outline = GraphicsContext.Shading.color(.white.opacity(0.3))
        let scalp = layout.rect(radius: 1.22)

        // Head: nose, ears, scalp.
        var nose = Path()
        nose.move(to: layout.point([-0.14, 1.2]))
        nose.addLine(to: layout.point([0, 1.34]))
        nose.addLine(to: layout.point([0.14, 1.2]))
        context.stroke(nose, with: outline, lineWidth: 2)
        for side: Float in [-1, 1] {
            let top = layout.point([side * 1.22 - 0.07, 0.2]), bottom = layout.point([side * 1.22 + 0.07, -0.2])
            context.stroke(Path(ellipseIn: CGRect(x: min(top.x, bottom.x), y: top.y, width: abs(bottom.x - top.x), height: bottom.y - top.y)),
                           with: outline, lineWidth: 2)
        }
        context.fill(Path(ellipseIn: scalp), with: .radialGradient(
            Gradient(colors: [Color(white: 0.14), Color(white: 0.07)]),
            center: layout.centre, startRadius: 0, endRadius: scalp.height / 2))
        context.stroke(Path(ellipseIn: scalp), with: outline, lineWidth: 2)

        // Brain, tinted by activity only where there is brain, then its folds multiplied back in.
        let brain = Image("BrainTop")
        let brainRect = layout.rect(radius: 1)
        context.drawLayer { layer in
            layer.draw(brain, in: brainRect)
            layer.blendMode = .sourceAtop
            layer.draw(heat, in: layout.rect(radius: CGFloat(Topomap.extent)))
        }
        var folds = context
        folds.blendMode = .multiply
        folds.opacity = 0.55
        folds.draw(brain, in: brainRect)

        // Region names.
        for region in BrainRegion.allCases {
            var label = context
            label.addFilter(.shadow(color: .black.opacity(0.8), radius: 2))
            label.draw(Text(region.shortName).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.85)),
                       at: layout.point(region.centre))
        }

        // Failed sensors get an alarm where they sit, not a silent gap that reads as zero.
        for electrode in Electrode.allCases where session.contact[electrode] == .bad {
            let p = layout.point(electrode.position), r: CGFloat = 13
            context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(.red))
            context.draw(Text("!").font(.callout.bold()).foregroundStyle(.white), at: p)
            context.draw(Text("Sensor off").font(.caption2.weight(.bold)).foregroundStyle(.red),
                         at: CGPoint(x: p.x, y: p.y + r + 8))
        }
    }

    private func accessibilitySummary(_ values: [Electrode: Float]) -> String {
        guard !values.isEmpty else { return String(localized: LocalizedStringResource("Brain map, no data yet", locale: AppLocale.current)) }
        return String(localized: LocalizedStringResource("\(session.bandLabel) activity.", locale: AppLocale.current)) + " " + BrainRegion.allCases.map { region in
            String(localized: LocalizedStringResource("\(region.name): \(activityLevel(Topomap.sample(values, at: region.centre).z))", locale: AppLocale.current))
        }.joined(separator: ", ")
    }
}
