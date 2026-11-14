import Foundation

/// The language the app is shown in. `String(localized:)` alone follows the system language, so text
/// built in code uses this instead, which matches the language chosen in Settings.
public enum AppLocale {
    public static var current: Locale {
        Locale(identifier: UserDefaults.standard.string(forKey: "language") ?? Locale.current.identifier)
    }
}
