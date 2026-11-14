import SwiftUI
import BrainwaveKit

// The shared look of the Android design: a soft backdrop, rounded cards, the brand gradient,
// the three state zones and the gauges. Every page is built from these pieces.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Brand and state colours, as in the Android theme.
enum Brand {
    static let gradient = LinearGradient(colors: [Color(hex: 0xF6A36B), Color(hex: 0xE94E89)],
                                         startPoint: .leading, endPoint: .trailing)
    static let cyan = Color(hex: 0x59E6FF)
    static let online = Color(hex: 0x34C759)
    static let offline = Color(hex: 0x8E8E93)
    static let accent = Color(hex: 0xE94E89)
    static let low = Color(hex: 0xE57373)
    static let steady = Color(hex: 0xF6C453)
    static let calm = Color(hex: 0x3DDC97)
    static let stressed = Color(hex: 0xE94E89)
    /// The two Compare areas: the first is cyan, the second orange.
    static let firstArea = Color(hex: 0x00E5FF)
    static let secondArea = Color(hex: 0xFF9800)

    /// Each Mind score has its own colour, as on Android.
    static func tint(_ metric: Metric) -> Color {
        switch metric {
        case .focus: Color(hex: 0xFF9F45)
        case .calm: Color(hex: 0x4CD27A)
        case .drowsiness: Color(hex: 0x9B8CFF)
        }
    }
}

/// Rounded card: translucent dark in dark mode, soft white with a shadow in light mode.
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 22

    func body(content: Content) -> some View {
        let dark = scheme == .dark
        content
            .background(dark ? Color(hex: 0x2A2F40) : .white, in: RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(dark ? 0 : 0.12), radius: 6, y: 3)
    }
}

extension View {
    func card(radius: CGFloat = 22) -> some View { modifier(CardStyle(radius: radius)) }
}

/// The app backdrop: a soft base with large translucent shapes behind the cards.
struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let dark = scheme == .dark
            let base = dark ? Color(hex: 0x1E2230) : Color(hex: 0xF3F0FF)
            let shapes = dark
                ? [Color(hex: 0x3B2F7A).opacity(0.7), Color(hex: 0x1E4450).opacity(0.6), Color(hex: 0x2A1F45).opacity(0.6)]
                : [Color(hex: 0xD9CFFF).opacity(0.7), Color(hex: 0xFFD9EC).opacity(0.6), Color(hex: 0xCFEFFF).opacity(0.6)]
            ZStack {
                base
                Circle().fill(shapes[0]).frame(width: w * 1.1, height: w * 1.1).position(x: w * 0.1, y: h * 0.12)
                Circle().fill(shapes[1]).frame(width: w * 0.9, height: w * 0.9).position(x: w * 0.95, y: h * 0.45)
                Circle().fill(shapes[2]).frame(width: w * 1.2, height: w * 1.2).position(x: w * 0.2, y: h * 0.9)
            }
        }
        .ignoresSafeArea()
    }
}

/// The main button: a gradient pill with bold white text. Grey when disabled.
struct BrandButtonStyle: ButtonStyle {
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(enabled ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.gray.opacity(0.4)), in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// A card you tap to switch an option on or off, with an On or Off pill.
struct ToggleCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline.weight(.bold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(isOn ? LocalizedStringKey("On") : LocalizedStringKey("Off"))
                    .font(.callout.weight(.bold))
                    .foregroundStyle(isOn ? Brand.online : Brand.offline)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background((isOn ? Brand.online : Brand.offline).opacity(0.18), in: Capsule())
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A card that shows a line of text and an arrow, to open something.
struct LinkCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline.weight(.bold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .card()
        }
        .buttonStyle(.plain)
    }
}

/// One choice on a slider row, with its name.
struct SliderOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: LocalizedStringKey
    var id: Value { value }
}

/// A slider with one step per level. The chosen level's name shows beside the title, and the level names sit under the track.
struct ChoiceSlider<Value: Hashable>: View {
    let title: LocalizedStringKey
    let options: [SliderOption<Value>]
    @Binding var selection: Value

    var body: some View {
        let index = Double(options.firstIndex { $0.value == selection } ?? 0)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline.weight(.bold))
                Spacer()
                Text(options[Int(index)].label).font(.callout.weight(.bold)).foregroundStyle(Brand.accent)
            }
            Slider(value: Binding(
                get: { index },
                set: { newValue in
                    let i = min(max(Int(newValue.rounded()), 0), options.count - 1)
                    selection = options[i].value
                }
            ), in: 0...Double(max(options.count - 1, 1)), step: 1)
            HStack {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    Text(option.label)
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : (i == options.count - 1 ? .trailing : .center))
                }
            }
        }
    }
}

// MARK: - Gauges

/// Adds a closed arc from `a0` to `a1` degrees (0 is 3 o'clock, 90 is 6 o'clock, 270 is 12 o'clock).
/// Points are sampled, so the direction never depends on platform arc conventions.
nonisolated func addArc(_ path: inout Path, centre: CGPoint, radius: CGFloat, from a0: Double, to a1: Double) {
    let steps = max(2, Int(abs(a1 - a0) * 2))
    for i in 0...steps {
        let a = (a0 + (a1 - a0) * Double(i) / Double(steps)) * .pi / 180
        let point = CGPoint(x: centre.x + radius * CGFloat(cos(a)), y: centre.y + radius * CGFloat(sin(a)))
        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
}

/// A half-circle gauge with a needle, 0 at the left and 100 at the right. The three state zones
/// along the arc are bright where the score is; the others are faint.
struct ScoreGauge: View, Animatable {
    var value: Double
    var tint: Color

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let stroke: CGFloat = 12
            let radius = min((size.width - stroke) / 2, size.height - stroke / 2)
            let centre = CGPoint(x: size.width / 2, y: size.height - stroke / 2)
            let score = min(max(value, 0), 100)
            let lowOn = score <= 35
            let highOn = score >= 65

            func zone(_ from: Double, _ to: Double, _ colour: Color, _ on: Bool) {
                var path = Path()
                addArc(&path, centre: centre, radius: radius, from: 180 + 180 * from / 100, to: 180 + 180 * to / 100)
                context.stroke(path, with: .color(colour.opacity(on ? 0.95 : 0.22)), style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
            }
            zone(0, 35, Brand.low, lowOn)
            zone(35, 65, Brand.steady, !lowOn && !highOn)
            zone(65, 100, tint, highOn)

            let angle = Double.pi * (1 - score / 100)
            let tip = CGPoint(x: centre.x + radius * 0.85 * CGFloat(cos(angle)), y: centre.y - radius * 0.85 * CGFloat(sin(angle)))
            var needle = Path()
            needle.move(to: centre)
            needle.addLine(to: tip)
            context.stroke(needle, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: centre.x - 5, y: centre.y - 5, width: 10, height: 10)), with: .color(.white))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
    }
}

/// The Compare gauge: the left half in the first area's colour, the right half in the second's.
/// The needle points straight up when the areas are level, and swings toward the more active one.
struct CompareGauge: View, Animatable {
    /// The share of time the first area was higher, 0 to 1. 0.5 is level.
    var share: Double
    var animatableData: Double {
        get { share }
        set { share = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let stroke: CGFloat = 12
            let radius = min((size.width - stroke) / 2, size.height - stroke / 2)
            let centre = CGPoint(x: size.width / 2, y: size.height - stroke / 2)
            var left = Path(), right = Path()
            addArc(&left, centre: centre, radius: radius, from: 180, to: 270)
            addArc(&right, centre: centre, radius: radius, from: 270, to: 360)
            context.stroke(left, with: .color(Brand.firstArea.opacity(0.85)), style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
            context.stroke(right, with: .color(Brand.secondArea.opacity(0.85)), style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
            let angle = Double.pi * (1 - min(max(share, 0), 1))
            let tip = CGPoint(x: centre.x + radius * 0.85 * CGFloat(cos(angle)), y: centre.y - radius * 0.85 * CGFloat(sin(angle)))
            var needle = Path()
            needle.move(to: centre)
            needle.addLine(to: tip)
            context.stroke(needle, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: centre.x - 5, y: centre.y - 5, width: 10, height: 10)), with: .color(.white))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
    }
}

// MARK: - Graph helpers

/// Clock times along a time axis: round times, hidden at the ends. Each label slides with the window.
enum GraphClock {
    /// The gap between labels: the smallest round gap that keeps the labels to `maxLabels` across the window.
    static func step(for span: Double, maxLabels: Int) -> Double {
        [5.0, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600].first { span / $0 <= Double(maxLabels) } ?? 3600
    }

    /// Draws the clock times under a plot whose bottom edge is at `bottom`. `date` turns a window time into a clock time.
    static func draw(_ context: GraphicsContext, plot: CGRect, left: Double, right: Double, bottom: CGFloat, date: (Double) -> Date) {
        let span = right - left
        guard span > 0 else { return }
        // Labels about 80 points apart, so a narrow phone gets fewer labels and they never run together.
        let step = step(for: span, maxLabels: max(2, Int(plot.width / 80)))
        var t = ceil(left / step) * step
        while t <= right {
            let fraction = (t - left) / span
            if (0.06...0.92).contains(fraction) {
                let x = plot.minX + plot.width * CGFloat(fraction)
                // Under a minute apart, minute labels repeat, so show seconds.
                let text = Text(date(t).formatted(step < 60 ? .dateTime.hour().minute().second() : .dateTime.hour().minute()))
                    .font(.caption2).foregroundStyle(.secondary)
                context.draw(text, at: CGPoint(x: x, y: bottom), anchor: .top)
            }
            t += step
        }
    }

    /// Y labels on the right of the plot, for a 0 to 100 scale.
    static func drawPercentLabels(_ context: GraphicsContext, plot: CGRect) {
        for v in [0, 25, 50, 75, 100] {
            let y = plot.minY + plot.height * CGFloat(1 - Double(v) / 100)
            context.draw(Text("\(v)").font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: plot.maxX + 8, y: y), anchor: .leading)
        }
    }
}

/// A dashed line across the plot at `y`, used for the usual level.
func drawDashedLine(_ context: GraphicsContext, from: CGPoint, to: CGPoint) {
    var line = Path()
    line.move(to: from)
    line.addLine(to: to)
    context.stroke(line, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [10, 10]))
}

/// A thin brand-gradient bar used to mark the chosen Compare tile.
struct BrandRule: View {
    var body: some View {
        Capsule().fill(Brand.gradient).frame(width: 30, height: 4)
    }
}

// MARK: - Lotus icon

/// The lotus icon, as the Android design: a centre petal, two side petals and the water line.
/// Drawn in a 24 by 24 box, so it takes the tint of the surrounding view.
nonisolated struct LotusGlyph: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24, sy = rect.height / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        // The tall centre petal.
        path.move(to: p(12, 3))
        path.addCurve(to: p(12, 14.5), control1: p(9.2, 6.5), control2: p(9.2, 11.5))
        path.addCurve(to: p(12, 3), control1: p(14.8, 11.5), control2: p(14.8, 6.5))
        path.closeSubpath()
        // The left petal.
        path.move(to: p(11, 14))
        path.addCurve(to: p(5, 6.8), control1: p(7.5, 13.5), control2: p(4.8, 10.8))
        path.addCurve(to: p(11, 14), control1: p(8.4, 7.2), control2: p(10.6, 10))
        path.closeSubpath()
        // The right petal.
        path.move(to: p(13, 14))
        path.addCurve(to: p(19, 6.8), control1: p(16.5, 13.5), control2: p(19.2, 10.8))
        path.addCurve(to: p(13, 14), control1: p(15.6, 7.2), control2: p(13.4, 10))
        path.closeSubpath()
        // The water line under the flower.
        path.move(to: p(3.5, 17))
        path.addCurve(to: p(12, 16.6), control1: p(7, 15.4), control2: p(9.5, 15.4))
        path.addCurve(to: p(20.5, 17), control1: p(14.5, 15.4), control2: p(17, 15.4))
        path.addCurve(to: p(3.5, 17), control1: p(17.5, 19.8), control2: p(6.5, 19.8))
        path.closeSubpath()
        return path
    }
}
