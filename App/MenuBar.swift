import Foundation
#if os(macOS)
import AppKit
import SwiftUI
import BrainwaveKit

/// What the menu-bar icon shows.
enum MenuBarParameter: Int, CaseIterable, Identifiable {
    case focus, calm, drowsiness, brainMap

    var id: Int { rawValue }
    var metric: Metric? { Metric(rawValue: rawValue) }
    var shortName: String { [String(localized: LocalizedStringResource("Focus", locale: AppLocale.current)), String(localized: LocalizedStringResource("Calm", locale: AppLocale.current)), String(localized: LocalizedStringResource("Drowsy", locale: AppLocale.current)), String(localized: LocalizedStringResource("Map", locale: AppLocale.current))][rawValue] }
    var name: String { metric?.title ?? String(localized: LocalizedStringResource("Brain map", locale: AppLocale.current)) }
}

/// Mac menu-bar item: a brain glyph coloured live by the chosen parameter, with a panel of controls.
struct MenuBarItem: Scene {
    let session: Session
    @AppStorage("menuBarShown") private var shown = true

    var body: some Scene {
        MenuBarExtra(isInserted: $shown) {
            MenuBarPanel().environment(session).appLook()
        } label: {
            MenuBarLabel(session: session)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let session: Session
    @AppStorage("menuBarItem") private var item = MenuBarParameter.focus.rawValue

    var body: some View {
        let parameter = MenuBarParameter(rawValue: item) ?? .focus
        let score = parameter.metric.flatMap { session.metrics[$0]?.last?.score }
        HStack(spacing: 3) {
            Image(nsImage: BrainGlyph.image(session: session, parameter: parameter, height: 16))
            if let score { Text("\(Int(score.rounded()))").monospacedDigit() }
        }
        .accessibilityLabel(score.map { "\(parameter.name) \(Int($0))" } ?? String(localized: LocalizedStringResource("Brainwave", locale: AppLocale.current)))
    }
}

/// Draws the brain's top view, tinted by a metric score or by the live activation map.
enum BrainGlyph {
    @MainActor
    static func image(session: Session, parameter: MenuBarParameter, height: CGFloat) -> NSImage {
        let live = session.status == .demo || { if case .streaming = session.status { true } else { false } }()
        let heat: Heat? = switch parameter {
        case _ where !live: nil
        case .brainMap: .map(session.visibleActivation)
        default: parameter.metric.flatMap { session.metrics[$0]?.last?.z }.map { .z($0) }
        }
        return image(heat, height: height, dimmed: !live)
    }

    enum Heat { case z(Double), map([Electrode: Float]) }

    static func image(_ heat: Heat?, height: CGFloat, dimmed: Bool) -> NSImage {
        let brain = NSImage(named: "BrainTop")!
        let size = NSSize(width: height * brain.size.width / brain.size.height, height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            brain.draw(in: rect, from: .zero, operation: .sourceOver, fraction: dimmed ? 0.45 : 1)
            switch heat {
            case .z(let z):
                let (rgb, strength) = Topomap.color(z: Float(z))
                NSColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: CGFloat(max(strength, 0.15))).setFill()
                rect.fill(using: .sourceAtop)
            case .map(let values):
                let field = NSImage(cgImage: Topomap.image(values, size: 64), size: .zero)
                // The field spans -extent…extent but the brain only fills -1…1: grow the rect to match.
                let grow = CGFloat(Topomap.extent - 1) / 2
                field.draw(in: rect.insetBy(dx: -rect.width * grow, dy: -rect.height * grow),
                           from: .zero, operation: .sourceAtop, fraction: 1)
            case nil: break
            }
            brain.draw(in: rect, from: .zero, operation: .multiply, fraction: 0.6)  // folds back on top
            return true
        }
        image.isTemplate = false  // keep the colours in the menu bar
        return image
    }
}

/// The panel that opens from the menu-bar icon.
private struct MenuBarPanel: View {
    @Environment(Session.self) private var session
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("menuBarItem") private var item = MenuBarParameter.focus.rawValue
    @AppStorage("requestedPage") private var requestedPage = ""  // read by RootView, then cleared

    var body: some View {
        let parameter = MenuBarParameter(rawValue: item) ?? .focus
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Brainwave").font(.headline)
                Spacer()
                ConnectionLabel().font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            HStack(spacing: 14) {
                Image(nsImage: BrainGlyph.image(session: session, parameter: parameter, height: 88))
                VStack(alignment: .leading, spacing: 2) {
                    Text(parameter.name).font(.caption).foregroundStyle(.secondary)
                    if let metric = parameter.metric {
                        let score = session.metrics[metric]?.last?.score
                        Text(score.map { "\(Int($0.rounded()))" } ?? "—")
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        Text(score.map { metric.label($0) } ?? "Waiting for signal")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(session.band.name).font(.title2.bold())
                        Text("vs. your baseline").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Picker("Show", selection: $item) {
                ForEach(MenuBarParameter.allCases) { Text($0.shortName).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()
            VStack(alignment: .leading, spacing: 2) {
                row("Open Brainwave", "macwindow") { open(page: nil) }
                if session.status.isLive {
                    row("Disconnect", "xmark.circle") { session.disconnect() }
                } else {
                    row("Connect headband…", "dot.radiowaves.left.and.right") { session.showingConnect = true; open(page: nil) }
                }
                row("Settings…", "gearshape") {
                    openSettings()
                    NSApp.activate()
                }
                row("Info", "info.circle") { open(page: .settings) }
                Divider().padding(.vertical, 4)
                row("Quit Brainwave", "power") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func open(page newPage: AppPage?) {
        if let newPage { requestedPage = newPage.rawValue }
        openWindow(id: "main")
        NSApp.activate()
    }

    private func row(_ title: LocalizedStringKey, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

/// Mac Settings window (⌘,).
/// The menu-bar choices, part of the Settings tab on the Mac.
struct MenuBarSettings: View {
    @AppStorage("menuBarShown") private var menuBarShown = true
    @AppStorage("menuBarItem") private var item = MenuBarParameter.focus.rawValue

    var body: some View {
        Section("Menu bar") {
            Toggle("Show Brainwave in the menu bar", isOn: $menuBarShown)
            Picker("Icon shows", selection: $item) {
                ForEach(MenuBarParameter.allCases) { Text($0.name).tag($0.rawValue) }
            }
            .disabled(!menuBarShown)
        }
    }
}

/// Keeps the app (and the menu-bar item) running when the main window is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
#endif
