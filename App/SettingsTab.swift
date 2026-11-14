import SwiftUI
import BrainwaveKit

/// The Settings page, as on Android: every choice is a card. Appearance, language, the calm session,
/// the advanced view, the Muse SDK credits and About.
struct SettingsPage: View {
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @AppStorage("language") private var language = AppLanguage.english.rawValue
    @AppStorage("advanced") private var advanced = false
    @AppStorage("calmSound") private var calmSound = true
    @AppStorage("calmVolume") private var calmVolume = CalmVolume.medium.rawValue
    @AppStorage("calmSoundType") private var calmSoundType = CalmSound.drone.rawValue
    @AppStorage("calmPace") private var calmPace = BreathPace.standard.rawValue
    @AppStorage("lastHeadband") private var remembered: String?  // same key as Session.lastHeadband
    @AppStorage("walkthroughDone") private var walkthroughDone = false  // Walkthrough.swift shows it again when false
    @State private var showingLanguages = false
    @State private var showingInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings").font(.title2.weight(.bold))

                section("Appearance") {
                    VStack(spacing: 10) {
                        Picker("Appearance", selection: $appearance) {
                            ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .card()
                }

                section("Language") {
                    LinkCard(title: LocalizedStringKey(languageName), subtitle: "Tap to change language") {
                        showingLanguages = true
                    }
                }

                section("Calm session") {
                    ToggleCard(title: "Soundscape", subtitle: "A soft scale on each breath", isOn: calmSound) {
                        calmSound.toggle()
                    }
                    optionCard {
                        ChoiceSlider(title: "Sound type",
                                     options: CalmSound.allCases.map { SliderOption(value: $0.rawValue, label: $0.title) },
                                     selection: $calmSoundType)
                    }
                    optionCard {
                        ChoiceSlider(title: "Sound level",
                                     options: CalmVolume.allCases.map { SliderOption(value: $0.rawValue, label: $0.title) },
                                     selection: $calmVolume)
                    }
                    optionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ChoiceSlider(title: "Breathing pace",
                                         options: BreathPace.allCases.map { SliderOption(value: $0.rawValue, label: $0.title) },
                                         selection: $calmPace)
                            Text("Standard is six breaths a minute. Slow is five, quick is seven and a half.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                #if os(macOS)
                section("Menu bar") {
                    optionCard { MenuBarSettings() }
                }
                #endif

                section("Advanced") {
                    ToggleCard(title: "Advanced view",
                               subtitle: "Brain map, band picker and raw signals",
                               isOn: advanced) {
                        advanced.toggle()
                    }
                }

                section("Works with the Muse SDK") {
                    optionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Brainwave reads Muse headbands through the Muse SDK.")
                                .font(.body)
                            HStack {
                                LogoBadge(file: "logo_vg", label: "Vahid Ghafarpour", url: "https://vahid.ghafarpour.com/")
                                LogoBadge(file: "logo_smartoire", label: "Smartoire", url: "https://smartoire.com/")
                                LogoBadge(file: "logo_bcai", label: "BC+AI Lifescience", url: "https://bc-ai.ca/communities/life-sciences-ai")
                                LogoBadge(file: "logo_muse", label: "Muse", url: "https://choosemuse.com/pages/developers")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                if let remembered {
                    section("Headband") {
                        optionCard {
                            HStack {
                                Text("Remembered headband")
                                Spacer()
                                Text(remembered).foregroundStyle(.secondary)
                                Button("Forget") { self.remembered = nil }
                            }
                        }
                    }
                }

                section("Introduction") {
                    optionCard {
                        Button("Show the introduction again") { walkthroughDone = false }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                section("About") {
                    optionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                Image("BrandMark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Brainwave").font(.title3.weight(.bold))
                                    Text("Formerly Oscillatoire").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text("Brainwave has no accounts and sends nothing to a server. Your captures and history stay on this device, and you choose when to share a file.")
                                .font(.callout)
                            Text("Brainwave is for education and curiosity. It is not a medical device, not medical advice, and not for research or clinical use.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Credits and licences") { showingInfo = true }
                                .font(.callout)
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showingLanguages) {
            LanguageList(selection: $language)
        }
        .sheet(isPresented: $showingInfo) {
            NavigationStack { InfoView() }
        }
    }

    /// A section title over one card, as on Android.
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline.weight(.bold)).padding(.top, 6)
            content()
        }
    }

    /// A plain card around a control.
    private func optionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
    }

    private var languageName: String {
        (AppLanguage(rawValue: language) ?? .english).name
    }
}

/// The languages, each named in its own language. The chosen one has a tick.
private struct LanguageList: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        selection = option.rawValue
                        dismiss()
                    } label: {
                        HStack {
                            Text(verbatim: option.name)
                            Spacer()
                            if option.rawValue == selection {
                                Image(systemName: "checkmark").foregroundStyle(Brand.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Language")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// One Muse SDK partner logo. Tapping it opens the site.
private struct LogoBadge: View {
    let file: String
    let label: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            Group {
                if let image {
                    image.resizable().scaledToFit().padding(10)
                } else {
                    Text(verbatim: label).font(.caption2)
                }
            }
            .frame(width: 74, height: 64)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel(label)
    }

    /// The logo from the app bundle, if it is there.
    private var image: Image? {
        guard let url = Bundle.main.url(forResource: file, withExtension: "png") else { return nil }
        #if os(macOS)
        guard let picture = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: picture)
        #else
        guard let picture = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: picture)
        #endif
    }
}

/// Brain and Signals, one page, chosen with a switch at the top.
struct AdvancedPage: View {
    @State private var part = 0  // 0 Brain, 1 Signals

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $part) {
                Text("Brain").tag(0)
                Text("Signals").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16).padding(.vertical, 8)
            if part == 0 {
                MapScreen()
            } else {
                SignalsView()
            }
        }
    }
}
