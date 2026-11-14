import SwiftUI
import BrainwaveKit

@main
struct BrainwaveApp: App {
    @State private var session = Session()
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        // A single main window, so the menu-bar item can bring it back instead of opening another.
        Window("Brainwave", id: "main") {
            RootView()
                .environment(session)
                .appLook()
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 1200, height: 800)
        MenuBarItem(session: session)
        Settings {
            NavigationStack { SettingsPage() }.environment(session).appLook()
        }
        #else
        WindowGroup {
            RootView().environment(session).appLook()
        }
        #endif
    }
}

/// The app shell, as on Android: a top bar with Record, Calm and Headband, the current page,
/// and the navigation fan that opens from the menu button.
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(\.colorScheme) private var scheme
    @State private var page = AppPage.mind
    @State private var showingCalm = false
    @State private var fanOpen = false
    /// Where the Headband page came from, so connecting returns there.
    @State private var returnPage = AppPage.mind
    @State private var returnToCalm = false
    /// Set by the Mac menu-bar panel to open a page; cleared once it is taken.
    @AppStorage("requestedPage") private var requestedPage = ""

    var body: some View {
        GeometryReader { geo in
            let fan = FanGeometry(size: geo.size)
            ZStack {
                AppBackdrop()
                VStack(spacing: 0) {
                    topBar(landscape: fan.landscape)
                    // Keep page content clear of the menu button: a right margin in landscape, a bottom margin in portrait.
                    pageContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, fan.landscape ? 0 : 88)
                        .padding(.trailing, fan.landscape ? 72 : 0)
                }
                NavFan(items: FanItem.all, current: page, pageMarked: !showingCalm, connected: session.status.isLive,
                       geometry: fan, open: $fanOpen) { picked in
                    showingCalm = false
                    page = picked
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "shell")
        }
        .sheet(isPresented: Bindable(session).showingStartCheck) {
            NavigationStack { StartCheckView() }
                .interactiveDismissDisabled()
        }
        .sheet(item: Bindable(session).finishedCapture) { capture in
            FinishedCaptureSheet(capture: capture)
                .environment(session)
        }
        .overlayPreferenceValue(WalkthroughAnchorKey.self) { Walkthrough(targets: $0) }
        .onAppear { session.launch() }
        .onChange(of: session.showingConnect) { _, wanted in
            if wanted {
                session.showingConnect = false
                openHeadband()
            }
        }
        .onChange(of: requestedPage) { _, raw in
            guard let target = AppPage(rawValue: raw) else { return }
            requestedPage = ""
            showingCalm = false
            page = target
        }
        .onChange(of: session.status.isLive) { _, live in
            // Connecting from the Headband page goes back to where the user came from.
            if live && page == .connect { returnFromHeadband() }
        }
    }

    // MARK: Top bar

    private func topBar(landscape: Bool) -> some View {
        let calmTint = scheme == .dark ? Color(hex: 0xB8A9FF) : Color(hex: 0x6750A4)
        let recording = session.isRecording
        return HStack(alignment: .center) {
            Spacer()
            if page == .advanced || page == .connect {
                TopAction(label: "Back", tint: nil, action: {
                    showingCalm = false
                    page = .settings
                }) {
                    Image(systemName: "chevron.backward").font(.system(size: 20, weight: .semibold))
                }
            } else {
                TopAction(label: recording ? "Stop" : "Record", tint: recording ? .red : nil, action: {
                    if recording { session.stopRecording() } else { session.startRecording() }
                }) {
                    Image(systemName: recording ? "stop.circle.fill" : "circle.fill").font(.system(size: 20))
                }
            }
            Spacer()
            if showingCalm {
                TopAction(label: "Back", tint: nil, action: {
                    showingCalm = false
                }) {
                    Image(systemName: "chevron.backward").font(.system(size: 20, weight: .semibold))
                }
            } else {
                TopAction(label: "Calm", tint: calmTint, action: {
                    showingCalm = true
                }) {
                    LotusGlyph().fill(calmTint).frame(width: 24, height: 24)
                }
                .walkthroughTarget("calm")
            }
            Spacer()
            TopAction(label: "Headband", tint: session.status.isLive ? Brand.online : nil, action: {
                openHeadband()
            }) {
                Image(systemName: "headphones").font(.system(size: 20))
            }
            .walkthroughTarget("headband")
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: Pages

    @ViewBuilder
    private var pageContent: some View {
        if showingCalm {
            CalmPage()
        } else {
            switch page {
            case .mind: MindPage()
            case .compare: ComparePage()
            case .captures:
                NavigationStack {
                    CapturesView()
                        #if os(iOS)
                        .toolbar(.hidden, for: .navigationBar)
                        #endif
                }
            case .settings: SettingsPage()
            case .advanced: AdvancedPage()
            case .connect: ConnectView()
            }
        }
    }

    /// Opens the Headband page, remembering the page the user is on.
    private func openHeadband() {
        if !(page == .connect && !showingCalm) {
            returnPage = page
            returnToCalm = showingCalm
        }
        showingCalm = false
        page = .connect
    }

    private func returnFromHeadband() {
        if returnToCalm {
            showingCalm = true
            page = .mind
        } else {
            page = returnPage == .connect ? .mind : returnPage
        }
        returnToCalm = false
    }
}

/// One labelled action in the top bar: an icon with its name under it.
private struct TopAction<Icon: View>: View {
    let label: LocalizedStringKey
    let tint: Color?
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                icon().frame(height: 24)
                Text(label).font(.caption2).lineLimit(1)
            }
            .foregroundStyle(tint ?? .secondary)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The system focus box stayed on the last button clicked and looked like a selected page.
        .focusEffectDisabled()
    }
}

extension Color {
    static let canvas = Color(light: (0.96, 0.97, 0.99), dark: (0.04, 0.05, 0.09))
    static let panel = Color.primary.opacity(0.06)

    init(_ rgb: SIMD3<Float>) {
        self.init(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }

    /// One fixed colour per electrode, shared by every chart.
    static func of(_ electrode: Electrode) -> Color {
        [Color(red: 0.45, green: 0.75, blue: 1.0), Color(red: 0.55, green: 0.95, blue: 0.65),
         Color(red: 1.0, green: 0.78, blue: 0.40), Color(red: 0.95, green: 0.55, blue: 0.85)][electrode.rawValue]
    }
}
