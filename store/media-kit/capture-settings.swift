import AppKit
import SwiftUI

/// Real settings views, disposable preferences, no app delegate or global hooks.
@main
struct SettingsCapture {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .aqua)
        let suite = "SettingsCapture-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.autoBackupEnabled = false
        settings.bigYearSystemCalendarEnabled = false
        settings.launchpadGroupedByCategory = true
        settings.launchpadStyle = .compact
        for language in [AppLanguage.french, .english] {
            UserDefaults.standard.setVolatileDomain(["app-language": language.rawValue], forName: UserDefaults.argumentDomain)
            settings.appLanguage = language
            try render(WindowShortcutsPreferencesView(settings: settings), language: language, name: "windows", output: output)
            try render(AppearanceSettingsView(settings: settings), language: language, name: "appearance", output: output)
        }
    }

    @MainActor static func render<V: View>(_ view: V, language: AppLanguage, name: String, output: URL) throws {
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1050, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)).environment(\.locale, language.locale).environment(\.colorScheme, .light))
        window.orderBack(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let content = window.contentView!
        content.layoutSubtreeIfNeeded()
        let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
        content.cacheDisplay(in: content.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name)-\(language.rawValue).png"))
        window.orderOut(nil)
    }
}
