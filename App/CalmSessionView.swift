import Foundation
import SwiftUI
import BrainwaveKit

/// The Calm page, as on Android: a lotus that opens and closes with the breath, a big IN or OUT,
/// the session time, and a bar that shows how much of the session was calm, steady or stressed.
/// It has no Done button: the Calm button in the top bar closes it.
struct CalmPage: View {
    @Environment(Session.self) private var session
    @State private var soundscape = CalmSoundscape()
    @State private var start = Date.now
    @State private var elapsed = 0
    @State private var calmSeconds = 0
    @State private var steadySeconds = 0
    @State private var stressedSeconds = 0
    @State private var calmScore: Double?
    @AppStorage("calmSound") private var sound = true
    @AppStorage("calmVolume") private var volume = CalmVolume.medium.rawValue
    @AppStorage("calmSoundType") private var soundType = CalmSound.drone.rawValue
    @AppStorage("calmPace") private var pace = BreathPace.standard.rawValue

    private var gain: Double { (CalmVolume(rawValue: volume) ?? .medium).gain }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            Group {
                if wide {
                    // Landscape: the lotus on the left, the timer and bar on the right.
                    HStack(spacing: 16) {
                        breathing.frame(maxWidth: .infinity, maxHeight: .infinity)
                        status.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    // Portrait: the lotus above, the timer and bar below.
                    VStack(spacing: 16) {
                        breathing.frame(height: min(geo.size.height * 0.55, 340))
                        status
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(16)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task {
            if sound { soundscape.start(CalmSound(rawValue: soundType) ?? .drone) }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsed += 1
                calmScore = session.metrics[.calm]?.last?.score
                // Each second with a score goes into one of three states: calm, steady or stressed.
                if let calmScore {
                    if calmScore >= Metric.stateThreshold { calmSeconds += 1 }
                    else if calmScore <= 35 { stressedSeconds += 1 }
                    else { steadySeconds += 1 }
                }
                // Quieter when the score is low, fuller as you settle.
                soundscape.setLevel((0.2 + 0.8 * (calmScore ?? 50) / 100) * gain)
            }
        }
        .onDisappear {
            soundscape.stop()
            finish()
        }
    }

    // MARK: Lotus and breath

    /// The lotus with a big IN or OUT on top of it. Its petals open and close with the breath:
    /// closed at the start of a breath, fully open at the peak, closed again at the end.
    private var breathing: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let half = Double(pace)  // seconds in, and the same out
            let cycle = 2 * half
            let phase = t.truncatingRemainder(dividingBy: cycle) / cycle
            let inhale = 0.5 - 0.5 * cos(2 * .pi * phase)
            // The word changes only at the peak, after the petals have finished growing.
            let breathingIn = phase < 0.5
            ZStack(alignment: .top) {
                Canvas { context, size in
                    drawLotus(context, size: size, inhale: inhale)
                }
                Text(breathingIn ? LocalizedStringKey("IN") : LocalizedStringKey("OUT"))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF6A36B), Color(hex: 0xE94E89), Brand.cyan],
                                                    startPoint: .leading, endPoint: .trailing))
                    .frame(width: 220, height: 96)
                    .padding(.top, 8)
                    .accessibilityLabel(breathingIn ? "Breathe in" : "Breathe out")
            }
        }
    }

    private func drawLotus(_ context: GraphicsContext, size: CGSize, inhale: Double) {
        let centre = CGPoint(x: size.width / 2, y: size.height * 0.74)
        let r = min(size.width, size.height) / 2 * (0.5 + 0.15 * inhale)
        // A soft glow behind the flower.
        let glow = CGRect(x: centre.x - r * 1.6, y: centre.y - r * 1.6, width: r * 3.2, height: r * 3.2)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [Brand.cyan.opacity(0.35), Brand.cyan.opacity(0)]),
            center: centre, startRadius: 0, endRadius: r * 1.6))
        let spread = (22 + 22 * inhale) * Double.pi / 180
        let length = r * (0.85 + 0.25 * inhale)
        let width = length * 0.36
        // Five petals, each drawn from the centre point and turned about it.
        for k in -2...2 {
            var petal = Path()
            petal.move(to: .zero)
            petal.addCurve(to: CGPoint(x: 0, y: -length), control1: CGPoint(x: width, y: -length * 0.3), control2: CGPoint(x: width, y: -length * 0.8))
            petal.addCurve(to: .zero, control1: CGPoint(x: -width, y: -length * 0.8), control2: CGPoint(x: -width, y: -length * 0.3))
            petal.closeSubpath()
            var turned = context
            turned.translateBy(x: centre.x, y: centre.y)
            turned.rotate(by: .radians(Double(k) * spread))
            turned.fill(petal, with: .color(Brand.cyan.opacity(k == 0 ? 0.85 : 0.6)))
        }
    }

    // MARK: Timer and state bar

    private var status: some View {
        let total = calmSeconds + steadySeconds + stressedSeconds
        return VStack(spacing: 0) {
            Text("Session time")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            // A fixed slot for the counter, so the digits changing do not move the bar below.
            Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                .frame(width: 240, height: 64)
            Spacer().frame(height: 20)
            if total == 0 {
                // No data yet: a grey bar and a note, until the first scores arrive.
                Capsule().fill(Color.gray.opacity(0.35)).frame(height: 22)
                Text("Learning your usual level. Keep breathing with the circle.")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(.top, 10)
            } else {
                stateBar(total: total)
                HStack {
                    Text("Calm").foregroundStyle(Brand.calm)
                    Spacer()
                    Text("Steady").foregroundStyle(Brand.steady)
                    Spacer()
                    Text("Stressed").foregroundStyle(Brand.stressed)
                }
                .font(.callout.weight(.bold))
                .padding(.top, 10)
            }
            // The status line always has its space, so it appearing does not move anything.
            Text(statusLine ?? " ")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func stateBar(total: Int) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Brand.calm).frame(width: geo.size.width * CGFloat(calmSeconds) / CGFloat(total))
                Rectangle().fill(Brand.steady).frame(width: geo.size.width * CGFloat(steadySeconds) / CGFloat(total))
                Rectangle().fill(Brand.stressed).frame(width: geo.size.width * CGFloat(stressedSeconds) / CGFloat(total))
            }
            .frame(maxHeight: .infinity)
            .background(Color.gray.opacity(0.25))
            .clipShape(Capsule())
        }
        .frame(height: 22)
    }

    /// What the score says right now. Nothing is shown without a headband: the breathing guide still runs.
    private var statusLine: String? {
        guard session.status.isLive, let calmScore else { return nil }
        return calmScore >= Metric.stateThreshold
            ? String(localized: LocalizedStringResource("You are settling. The sound is filling out.", locale: AppLocale.current))
            : String(localized: LocalizedStringResource("Let the breath slow down. The sound will soften until you settle.", locale: AppLocale.current))
    }

    /// Keeps the session in the calm log, and in Apple Health on iPhone. Runs once, when the page closes.
    private func finish() {
        guard elapsed > 0 else { return }
        let now = Date.now
        CalmLogStore.add(CalmSessionRecord(date: now, calmSeconds: Double(calmSeconds), totalSeconds: Double(elapsed)))
        #if os(iOS)
        let start = now.addingTimeInterval(-Double(elapsed))
        Task { await HealthSync.saveMindfulSession(start: start, end: now) }
        #endif
        elapsed = 0  // a second close does nothing
    }
}
