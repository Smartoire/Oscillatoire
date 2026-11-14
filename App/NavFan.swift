import SwiftUI

// The navigation fan, as on Android. Press the menu button and the pages open in an arc above it.
// Slide the finger over a page to highlight it, then lift to go there. A quick tap keeps the arc open.
// In landscape the arc opens to the left of the button, which sits at the middle of the right edge.

/// The pages the menu opens.
enum AppPage: String, CaseIterable, Identifiable {
    case mind, compare, captures, settings, advanced, connect

    var id: Self { self }
}

/// One page on the fan.
struct FanItem: Identifiable {
    let page: AppPage
    let title: LocalizedStringKey
    let symbol: String
    var id: AppPage { page }

    static let all: [FanItem] = [
        FanItem(page: .mind, title: "Mind", symbol: "brain.head.profile"),
        FanItem(page: .compare, title: "Compare", symbol: "arrow.left.and.right"),
        FanItem(page: .captures, title: "Captures", symbol: "folder"),
        FanItem(page: .settings, title: "Settings", symbol: "gearshape"),
        FanItem(page: .advanced, title: "Advanced", symbol: "slider.horizontal.3"),
    ]
}

/// The geometry of the fan, shared by the arc, the pages on it and the menu button.
struct FanGeometry {
    static let button: CGFloat = 56
    static let radius: CGFloat = 150
    static let bottom: CGFloat = 24
    static let edge: CGFloat = 16
    /// How close the finger must be to a page to highlight it.
    static let reach: CGFloat = 36

    let size: CGSize
    let landscape: Bool

    init(size: CGSize) {
        self.size = size
        landscape = size.width > size.height
    }

    /// The centre of the menu button.
    var anchor: CGPoint {
        landscape
            ? CGPoint(x: size.width - (Self.edge + Self.button / 2), y: size.height / 2)
            : CGPoint(x: size.width / 2, y: size.height - (Self.bottom + Self.button / 2))
    }

    /// Where page `i` of `count` sits on the arc, relative to the anchor.
    func offset(_ i: Int, of count: Int) -> CGPoint {
        let a = Double.pi * (0.84 - 0.68 * Double(i) / Double(max(count - 1, 1)))
        let r = Self.radius
        return landscape
            ? CGPoint(x: -r * CGFloat(sin(a)), y: r * CGFloat(cos(a)))
            : CGPoint(x: r * CGFloat(cos(a)), y: -r * CGFloat(sin(a)))
    }

    /// The page centre on screen.
    func point(_ i: Int, of count: Int) -> CGPoint {
        let o = offset(i, of: count)
        return CGPoint(x: anchor.x + o.x, y: anchor.y + o.y)
    }
}

/// The menu button and the arc of pages above it. Owns the press-and-slide gesture.
struct NavFan: View {
    let items: [FanItem]
    let current: AppPage
    /// True while a page from the fan is open; the menu button then shows that page's icon.
    let pageMarked: Bool
    let connected: Bool
    let geometry: FanGeometry
    @Binding var open: Bool
    let onPick: (AppPage) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var hovered = -1
    @State private var dragging = false
    @State private var wasOpen = false
    @State private var moved = false
    @State private var pressStart = CGPoint.zero

    var body: some View {
        ZStack {
            if open {
                // Dims the page; tapping outside the fan closes it.
                Color.black.opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture { open = false }
                    .transition(.opacity)
                arc
                    .transition(.opacity.combined(with: .scale(scale: 0.5, anchor: .bottom)))
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    pageItem(i, item)
                }
            }
            menuButton
        }
        .animation(.easeOut(duration: 0.2), value: open)
        .animation(.easeOut(duration: 0.15), value: hovered)
    }

    private var surface: Color { scheme == .dark ? Color(hex: 0x1E2230) : Color(hex: 0xF7F8FB) }

    /// The half disc behind the pages, and a thin ring where they sit.
    private var arc: some View {
        Canvas { context, _ in
            let centre = geometry.anchor
            let start: Double = geometry.landscape ? 90 : 180
            let end: Double = geometry.landscape ? 270 : 360
            let backdrop = FanGeometry.radius + 26
            var disc = Path()
            disc.move(to: centre)
            addArc(&disc, centre: centre, radius: backdrop, from: start, to: end)
            disc.closeSubpath()
            context.fill(disc, with: .color(surface.opacity(0.96)))
            var ring = Path()
            addArc(&ring, centre: centre, radius: FanGeometry.radius, from: start, to: end)
            context.stroke(ring, with: .color(.gray.opacity(0.25)), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }

    private func pageItem(_ i: Int, _ item: FanItem) -> some View {
        let p = geometry.point(i, of: items.count)
        let isHover = hovered == i
        let selected = current == item.page
        let fill: Color = isHover
            ? (scheme == .dark ? Color(hex: 0xB8A9FF) : Color(hex: 0x6750A4))
            : (selected ? Brand.accent.opacity(0.3) : surface)
        let tint: Color = isHover ? (scheme == .dark ? Color(hex: 0x1B1140) : .white) : .primary
        return VStack(spacing: 4) {
            Image(systemName: item.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(fill, in: Circle())
            Text(item.title)
                .font(.caption2.weight(isHover ? .bold : .regular))
                .lineLimit(1)
        }
        .frame(width: 64)
        .scaleEffect(isHover ? 1.22 : 1)
        .contentShape(Rectangle())
        .position(p)
        // A click or tap on a page goes there, so the menu works with a mouse as well as a finger.
        .onTapGesture {
            onPick(item.page)
            open = false
        }
    }

    private var menuButton: some View {
        let a = geometry.anchor
        return ZStack(alignment: .topTrailing) {
            Group {
                if pageMarked, let item = items.first(where: { $0.page == current }) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(scheme == .dark ? Color(hex: 0xB8A9FF) : Color(hex: 0x6750A4))
                } else {
                    BrandMarkImage()
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                }
            }
            .frame(width: FanGeometry.button, height: FanGeometry.button)
                .background(scheme == .dark ? Color(hex: 0x4B3FA3) : Color(hex: 0xEADDFF), in: Circle())
            Circle()
                .fill(connected ? Brand.online : Brand.offline)
                .frame(width: 10, height: 10)
        }
        .frame(width: FanGeometry.button, height: FanGeometry.button)
        .walkthroughTarget("menu")
        .contentShape(Circle())
        .position(a)
        .accessibilityLabel("Menu")
        .gesture(pressAndSlide)
    }

    /// Press to open, slide to a page, lift to go there. A quick tap toggles the arc.
    private var pressAndSlide: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("shell"))
            .onChanged { value in
                if !dragging {
                    dragging = true
                    wasOpen = open
                    moved = false
                    pressStart = value.startLocation
                    open = true
                }
                if hypot(value.location.x - pressStart.x, value.location.y - pressStart.y) > 8 { moved = true }
                hovered = nearest(to: value.location)
            }
            .onEnded { value in
                let chosen = nearest(to: value.location)
                dragging = false
                hovered = -1
                if chosen >= 0 {
                    onPick(items[chosen].page)
                    open = false
                } else if !moved {
                    open = !wasOpen
                } else {
                    open = false
                }
            }
    }

    private func nearest(to point: CGPoint) -> Int {
        var best = -1
        var bestDistance = FanGeometry.reach
        for i in items.indices {
            let target = geometry.point(i, of: items.count)
            let d = hypot(target.x - point.x, target.y - point.y)
            if d < bestDistance {
                bestDistance = d
                best = i
            }
        }
        return best
    }
}

/// The brand mark on the menu button.
struct BrandMarkImage: View {
    var body: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
