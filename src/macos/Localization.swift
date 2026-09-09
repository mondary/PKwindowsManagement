import AppKit
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

    /// SwiftPM resource bundle, looked up manually: the generated `Bundle.module`
    /// calls fatalError when the bundle is missing or malformed (crash on launch).
    private static let moduleResources: Bundle? = {
        let name = "PKwindowsManagement_PKwindowsManagement"
        let dirs = [
            Bundle.main.resourceURL,
            URL(fileURLWithPath: Bundle.main.bundlePath).deletingLastPathComponent(),
        ]
        for dir in dirs {
            if let url = dir?.appendingPathComponent(name + ".bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    static var currentLanguage: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: defaultsKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: rawValue) ?? .system
    }

    static var locale: Locale { currentLanguage.locale }

    /// Bundle holding SwiftPM-processed assets (images, strings).
    static var assetBundle: Bundle { moduleResources ?? .main }

    /// Loads an image from the SwiftPM resource bundle (falls back to the main bundle).
    static func assetImage(_ name: String) -> NSImage? {
        NSImage(named: name) ?? assetBundle.image(forResource: name)
    }

    static func bundle(for language: AppLanguage = currentLanguage) -> Bundle {
        let code = language.resolvedCode
        for candidate in [moduleResources, Bundle.main] {
            if let path = candidate?.path(forResource: code, ofType: "lproj"),
               let localizedBundle = Bundle(path: path) {
                return localizedBundle
            }
        }
        return Bundle.main
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
