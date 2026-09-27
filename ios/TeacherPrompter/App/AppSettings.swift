import SwiftUI

enum SettingsKey {
    static let appearance = "appearance"
    static let uiLanguage = "uiLanguage"
    static let fontSize = "promptFontSize"
    static let previewNext = "previewNext"
    static let hideCompleted = "hideCompleted"
    static let strikeCompleted = "strikeCompleted"
    static let showPrevious = "showPrevious"
    static let focusMode = "focusMode"
    static let didSeedSample = "didSeedSample"
}

enum SettingsDefaults {
    static let fontSize: Double = 44
    static let fontRange: ClosedRange<Double> = 24...110
    static let fontStep: Double = 4
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum UILanguagePreference: String, CaseIterable, Identifiable {
    case system, de, en

    var id: String { rawValue }

    var resolved: UILanguage {
        switch self {
        case .de: return .de
        case .en: return .en
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "de"
            return preferred.hasPrefix("en") ? .en : .de
        }
    }
}

/// Applies UI language and appearance. Used at the root and on every sheet / full-screen cover.
struct AppEnvironment: ViewModifier {
    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system
    @AppStorage(SettingsKey.uiLanguage) private var uiLanguage: UILanguagePreference = .system

    func body(content: Content) -> some View {
        content
            .environment(\.loc, Localizer(language: uiLanguage.resolved))
            .environment(\.locale, Locale(identifier: uiLanguage.resolved.rawValue))
            .preferredColorScheme(appearance.colorScheme)
    }
}

extension View {
    func appEnvironment() -> some View {
        modifier(AppEnvironment())
    }
}
