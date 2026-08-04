import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case french = "fr"
    case english = "en"
    case spanish = "es"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: localizedString("Automatic (System)")
        case .french: "Français"
        case .english: "English"
        case .spanish: "Español"
        case .german: "Deutsch"
        }
    }

    var resolvedCode: String {
        guard self == .system else { return rawValue }
        let preferred = Locale.preferredLanguages.first ?? "en"
        let languageCode = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
        return Self.supportedCodes.contains(languageCode) ? languageCode : "en"
    }

    var locale: Locale { Locale(identifier: resolvedCode) }

    private static let supportedCodes: Set<String> = ["fr", "en", "es", "de"]
}

enum AppLocalization {
    static let defaultsKey = "app-language"

    static var currentLanguage: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: defaultsKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: rawValue) ?? .system
    }

    static var locale: Locale { currentLanguage.locale }

    static func bundle(for language: AppLanguage = currentLanguage) -> Bundle {
        let code = language.resolvedCode
        let candidates = [Bundle.main, Bundle.module]
        for candidate in candidates {
            if let path = candidate.path(forResource: code, ofType: "lproj"),
               let localizedBundle = Bundle(path: path) {
                return localizedBundle
            }
        }
        return Bundle.module
    }
}

func localizedString(_ key: String) -> String {
    AppLocalization.bundle().localizedString(forKey: key, value: key, table: nil)
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedString(key), locale: AppLocalization.locale, arguments: arguments)
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
