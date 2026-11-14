import SwiftUI
import BrainwaveKit

// MARK: - Pointing at controls

/// The on-screen frames of the controls the walkthrough can point at, by name.
struct WalkthroughAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks this view as something the walkthrough can point at.
    func walkthroughTarget(_ name: String) -> some View {
        anchorPreference(key: WalkthroughAnchorKey.self, value: .bounds) { [name: $0] }
    }
}

// MARK: - The walkthrough

/// A short introduction the first time Brainwave opens. Each step dims the screen except the control it
/// describes, so the user sees where to tap. Shown once on this device; Settings can show it again.
struct Walkthrough: View {
    let targets: [String: Anchor<CGRect>]
    @AppStorage("walkthroughDone") private var done = false
    @State private var step = 0

    private struct Page {
        let icon: String?
        let target: String?
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(icon: "sparkles", target: nil,
             title: "Welcome to Brainwave",
             text: "Brainwave shows how your attention and calm change, using the signals from a Muse headband. Nothing is saved unless you record it."),
        Page(icon: nil, target: "mind",
             title: "Mind",
             text: "These three cards show Focus, Calm and Sleepiness. Each gauge moves as its score changes. The graph below shows the last ten minutes."),
        Page(icon: nil, target: "headband",
             title: "Connect your headband",
             text: "Tap Headband at the top to find your Muse. No headband yet? Try the demo from the same screen."),
        Page(icon: nil, target: "calm",
             title: "Calm",
             text: "Tap Calm to start slow breathing. The lotus opens as you breathe in and closes as you breathe out. Choose a soft sound in Settings."),
        Page(icon: nil, target: "menu",
             title: "The menu",
             text: "Tap the brain button to open the menu. Choose Compare to see the two sides of the brain over time, or Captures for saved recordings."),
    ]

    var body: some View {
        if done {
            EmptyView()
        } else {
            GeometryReader { geo in
                let page = pages[step]
                let spot = page.target.flatMap { targets[$0] }.map { geo[$0] }
                let onTop = (spot?.midY ?? 0) > geo.size.height / 2
                ZStack {
                    // Dims the whole screen, with a clear window around the control this step describes.
                    Canvas { context, size in
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.62)))
                        if let spot {
                            context.blendMode = .clear
                            context.fill(Path(roundedRect: spot.insetBy(dx: -10, dy: -10), cornerRadius: 16), with: .color(.black))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {}

                    if let spot {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Brand.accent, lineWidth: 3)
                            .frame(width: spot.width + 20, height: spot.height + 20)
                            .position(x: spot.midX, y: spot.midY)
                            .allowsHitTesting(false)
                    }

                    card(page)
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 20)
                        .padding(.top, 20 + geo.safeAreaInsets.top)
                        .padding(.bottom, 20 + geo.safeAreaInsets.bottom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: onTop ? .top : .bottom)
                }
            }
            // The dim, the cut-out and the ring share one coordinate space only if the whole overlay ignores the safe area.
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    private func card(_ page: Page) -> some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Button("Skip") { done = true }
                    .foregroundStyle(.secondary)
            }
            if let icon = page.icon {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Brand.accent)
                    .frame(height: 48)
            }
            Text(page.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(page.text)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Brand.accent : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            HStack(spacing: 12) {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.bordered)
                }
                Button(step == pages.count - 1 ? "Start" : "Next") {
                    if step == pages.count - 1 { done = true } else { step += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}
