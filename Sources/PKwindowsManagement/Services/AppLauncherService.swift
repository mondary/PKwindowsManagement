import AppKit
import Carbon.HIToolbox
import Foundation

enum LauncherCommand: String, CaseIterable, Identifiable {
    case emptyTrash = "empty trash"
    case eject = "eject"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emptyTrash: "Empty Trash"
        case .eject: "Eject"
        }
    }
}

struct LaunchableApp: Identifiable {
    let id: String
    let name: String
    let bundleID: String
    let url: URL
    let icon: NSImage
    let shortcut: KeyboardShortcutSetting?
    let snippet: SnippetDefinition?

    var commandSymbolName: String? {
        switch id {
        case LauncherCommand.emptyTrash.rawValue: "trash"
        case LauncherCommand.eject.rawValue: "eject"
        default: nil
        }
    }

    var launchpadSymbolName: String? {
        if let commandSymbolName { return commandSymbolName }
        guard let snippet else { return nil }
        switch snippet.kind {
        case .script:
            return "terminal"
        case .url:
            return "globe"
        }
    }
}

final class AppLauncherService {
    func canUninstall(_ app: LaunchableApp) -> Bool {
        let path = app.url.standardizedFileURL.path
        guard app.url.pathExtension == "app",
              !path.hasPrefix("/System/"),
              path != Bundle.main.bundleURL.standardizedFileURL.path
        else { return false }
        return path.hasPrefix("/Applications/") || path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/")
    }

    func moveToTrash(_ app: LaunchableApp) throws {
        guard canUninstall(app) else {
            throw AppLauncherError.uninstallNotAllowed
        }
        try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
    }

    func loadApps(settings: AppSettings) -> [LaunchableApp] {
        let items = installedApplications()
        return items.map { app in
            LaunchableApp(
                id: app.bundleID ?? app.url.path,
                name: app.displayName,
                bundleID: app.bundleID ?? app.url.path,
                url: app.url,
                icon: app.icon,
                shortcut: shortcut(for: app.bundleID, settings: settings),
                snippet: nil
            )
        }
        .sorted {
            if settings.recentBundleIDs.firstIndex(of: $0.bundleID) != nil,
               settings.recentBundleIDs.firstIndex(of: $1.bundleID) == nil { return true }
            if settings.recentBundleIDs.firstIndex(of: $0.bundleID) == nil,
               settings.recentBundleIDs.firstIndex(of: $1.bundleID) != nil { return false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func launcherCommands() -> [LaunchableApp] {
        [
            makeCommand(id: LauncherCommand.emptyTrash.rawValue, name: LauncherCommand.emptyTrash.title, iconName: "trash"),
            makeCommand(id: LauncherCommand.eject.rawValue, name: LauncherCommand.eject.title, iconName: "eject")
        ]
    }

    func loadSnippets(settings: AppSettings) -> [LaunchableApp] {
        settings.snippets.filter(\.isEnabled).map { snippet in
            let iconName = snippet.kind == .url ? "globe" : "terminal"
            let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: snippet.title) ?? NSImage()
            icon.size = NSSize(width: 64, height: 64)
            return LaunchableApp(
                id: snippet.id,
                name: snippet.title,
                bundleID: snippet.id,
                url: URL(fileURLWithPath: "/"),
                icon: icon,
                shortcut: settings.launchShortcut(for: snippet.id),
                snippet: snippet
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func launch(_ app: LaunchableApp, settings: AppSettings) {
        if handleCommandLaunch(app) { return }
        if let snippet = app.snippet {
            launch(snippet: snippet)
            settings.markLaunched(bundleID: app.bundleID)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, _ in }
        settings.markLaunched(bundleID: app.bundleID)
    }

    private func shortcut(for bundleID: String?, settings: AppSettings) -> KeyboardShortcutSetting? {
        guard let bundleID else { return nil }
        return settings.launchShortcut(for: bundleID)
    }

    private func installedApplications() -> [InstalledApp] {
        let urls = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var seen = Set<String>()
        return urls.flatMap { folder -> [InstalledApp] in
            applications(in: folder)
        }
        .filter { app in
            guard !seen.contains(app.bundleID ?? app.url.path) else { return false }
            seen.insert(app.bundleID ?? app.url.path)
            return true
        }
    }

    private func applications(in folder: URL) -> [InstalledApp] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.localizedNameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "app" else { return nil }
            let values = try? url.resourceValues(forKeys: [.localizedNameKey])
            let name = values?.localizedName ?? url.deletingPathExtension().lastPathComponent
            let bundleID = Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 96, height: 96)
            return InstalledApp(url: url, displayName: name, bundleID: bundleID, icon: icon)
        }
    }

    private func handleCommandLaunch(_ app: LaunchableApp) -> Bool {
        switch app.id {
        case LauncherCommand.emptyTrash.rawValue:
            emptyTrash()
            return true
        case LauncherCommand.eject.rawValue:
            ejectMountedVolumes()
            return true
        default:
            return false
        }
    }

    private func launch(snippet: SnippetDefinition) {
        switch snippet.kind {
        case .script:
            executeSnippet(snippet.body)
        case .url:
            openURL(snippet.urlString, inBrowserBundleID: snippet.browserBundleID)
        }
    }

    private func executeSnippet(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private func openURL(_ rawURL: String, inBrowserBundleID browserBundleID: String?) {
        guard let url = normalizedURL(rawURL) else { return }
        if let browserBundleID,
           let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: configuration) { _, _ in }
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func normalizedURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private func ejectMountedVolumes() {
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeURLForRemountingKey], options: [.skipHiddenVolumes]) ?? []
        for volume in mounted {
            guard volume.path != "/" else { continue }
            try? NSWorkspace.shared.unmountAndEjectDevice(at: volume)
        }
    }

    private func emptyTrash() {
        let script = """
        tell application "Finder"
            empty trash
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }

    private func makeCommand(id: String, name: String, iconName: String) -> LaunchableApp {
        let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: name) ?? NSImage()
        icon.size = NSSize(width: 64, height: 64)
        return LaunchableApp(id: id, name: name, bundleID: id, url: URL(fileURLWithPath: "/"), icon: icon, shortcut: nil, snippet: nil)
    }
}

enum AppLauncherError: LocalizedError {
    case uninstallNotAllowed

    var errorDescription: String? {
        switch self {
        case .uninstallNotAllowed:
            "This application cannot be moved to the Trash."
        }
    }
}

private struct InstalledApp {
    let url: URL
    let displayName: String
    let bundleID: String?
    let icon: NSImage
}
