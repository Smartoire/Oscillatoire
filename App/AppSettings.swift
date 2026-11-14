import SwiftUI

/// Dark, light or the system's choice. The app is dark by default.
enum Appearance: String, CaseIterable, Identifiable {
    case dark, light, system

    var id: Self { self }

    var scheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "System"
        }
    }
}

/// The languages the app is offered in. Each is named in its own language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en", persian = "fa", french = "fr", dutch = "nl", arabic = "ar", chinese = "zh-Hans",
         hindi = "hi", spanish = "es", russian = "ru", german = "de", japanese = "ja"

    var id: Self { self }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Persian and Arabic read right to left.
    var direction: LayoutDirection { self == .persian || self == .arabic ? .rightToLeft : .leftToRight }

    var name: String {
        switch self {
        case .english: "English"
        case .persian: "فارسی"
        case .french: "Français"
        case .dutch: "Nederlands"
        case .arabic: "العربية"
        case .chinese: "中文（简体）"
        case .hindi: "हिन्दी"
        case .spanish: "Español"
        case .russian: "Русский"
        case .german: "Deutsch"
        case .japanese: "日本語"
        }
    }
}

/// Applies the saved appearance and language to a window, sheet or menu-bar panel.
struct AppLook: ViewModifier {
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @AppStorage("language") private var language = AppLanguage.english.rawValue

    func body(content: Content) -> some View {
        let lang = AppLanguage(rawValue: language) ?? .english
        content
            .preferredColorScheme(Appearance(rawValue: appearance)?.scheme ?? .dark)
            .environment(\.locale, lang.locale)
            .environment(\.layoutDirection, lang.direction)
            // Larger text across the app: the default sizes were hard to read.
            .dynamicTypeSize(.xLarge)
            // Text built in code is read once when a view is drawn, so rebuild the whole window on change.
            .id(language)
    }
}

extension View {
    func appLook() -> some View { modifier(AppLook()) }
}

/// The Appearance and Language choices, for any settings screen.
struct AppPreferences: View {
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @AppStorage("language") private var language = AppLanguage.english.rawValue

    var body: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()  // the section header already names it
        }
        Section("Language") {
            Picker("Language", selection: $language) {
                ForEach(AppLanguage.allCases) { Text($0.name).tag($0.rawValue) }
            }
            .pickerStyle(.inline)  // a full list with every language name, not a small pop-up
            .labelsHidden()  // the section header already names it
        }
    }
}

extension Color {
    /// A colour that follows the appearance: `light` in light mode, `dark` in dark mode.
    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }
}

/// How loud the calm session's soundscape is.
enum CalmVolume: String, CaseIterable, Identifiable {
    case soft, medium, full

    var id: Self { self }

    var gain: Double {
        switch self {
        case .soft: 0.5
        case .medium: 0.8
        case .full: 1
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .soft: "Soft"
        case .medium: "Medium"
        case .full: "Full"
        }
    }
}

/// Seconds for each half of a breath (in or out). Five seconds each is six breaths a minute.
enum BreathPace: Int, CaseIterable, Identifiable {
    case slow = 6, standard = 5, quick = 4

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .slow: "Slow"
        case .standard: "Standard"
        case .quick: "Quick"
        }
    }
}
