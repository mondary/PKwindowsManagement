import AppKit
import SwiftUI

// Uses the production views. Catalog injection only happens in the temporary
// copy of CompactLaunchpadView; no app delegate, launcher, or global monitor runs.
@main
struct StoreCapture {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .aqua)
        let suite = "Store2Capture-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.autoBackupEnabled = false
        settings.bigYearSystemCalendarEnabled = false
        settings.bigYearBirthdays = "11.02,Alex\n14.06,Sam\n21.09,Charlie"
        settings.bigYearEvents = "10.08-21.08,Vacances\n12.10-16.10,Projet Atlas"
        for language in [AppLanguage.french, .english] {
            UserDefaults.standard.setVolatileDomain(["app-language": language.rawValue], forName: UserDefaults.argumentDomain)
            settings.appLanguage = language
            settings.compactLaunchpadTheme = .light
            try render(CompactLaunchpadRootView(settings: settings), size: NSSize(width: 580, height: 410), name: "launchpad-\(language.rawValue)", output: output)
            try render(WindowShortcutsPreferencesView(settings: settings).padding(24).background(Color.white).environment(\.locale, language.locale), size: NSSize(width: 1050, height: 800), name: "windows-\(language.rawValue)", output: output)
        }
        for theme in [BigYearTheme.pastel, .poster, .catppuccinMocha] {
            settings.bigYearTheme = theme
            try render(BigYearRootView(year: 2026, settings: settings, onClose: {}), size: NSSize(width: 1440, height: 900), name: "year-\(theme.rawValue)", output: output)
        }
        print("Native captures written to \(output.path)")
    }

    @MainActor static func render<V: View>(_ view: V, size: NSSize, name: String, output: URL) throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: view.environment(\.colorScheme, .light))
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        let content = window.contentView!
        content.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        content.layoutSubtreeIfNeeded()
        let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
        content.cacheDisplay(in: content.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
    }
}

enum CaptureFixtures {
    static var apps: [LaunchableApp] {
        [("Safari", "com.apple.Safari"), ("Notes", "com.apple.Notes"), ("Calendar", "com.apple.iCal"), ("Mail", "com.apple.mail"), ("TextEdit", "com.apple.TextEdit")].enumerated().map { index, app in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.1) ?? URL(fileURLWithPath: "/System/Applications")
            return LaunchableApp(id: app.1, name: app.0, bundleID: app.1, url: url, icon: NSWorkspace.shared.icon(forFile: url.path), shortcut: KeyboardShortcutSetting(key: String(index + 1), modifier: .rightCommand), snippet: nil)
        }
    }
}
