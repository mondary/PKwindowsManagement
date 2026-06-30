import AppKit
import Carbon.HIToolbox
import Foundation

enum LauncherCommand: String, CaseIterable, Identifiable {
    case emptyTrash = "empty trash"
    case eject = "eject"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emptyTrash: localizedString("Empty Trash")
        case .eject: localizedString("Eject")
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
        return snippet.launchpadSymbolName
    }
}

final class AppLauncherService {
    private static var cachedInstalledApps: [InstalledApp]?
    private static var cachedInstalledAppsTimestamp: Date = .distantPast
    // Rebuilding NSWorkspace icons repeatedly grows IconServices' internal
    // caches. Installed applications change rarely, so keep this cache stable.
    private static let installedAppsCacheTTL: TimeInterval = 6 * 60 * 60
    private static let placeholderIcon = NSImage(size: NSSize(width: 1, height: 1))

    static func invalidateInstalledAppsCache() {
        cachedInstalledApps = nil
        cachedInstalledAppsTimestamp = .distantPast
    }

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
        Self.invalidateInstalledAppsCache()
    }

    func loadApps(settings: AppSettings) -> [LaunchableApp] {
        let apps = installedApplications(loadIcons: true).map { app -> LaunchableApp in
            let bundleID = app.bundleID ?? app.url.path
            return LaunchableApp(
                id: bundleID,
                name: app.displayName,
                bundleID: bundleID,
                url: app.url,
                icon: app.icon,
                shortcut: shortcut(for: app.bundleID, settings: settings),
                snippet: nil
            )
        }

        switch settings.launchpadAppSortMode {
        case .recent:
            return apps.sorted { lhs, rhs in
                sortByRecent(lhs, rhs, settings: settings)
            }
        case .name:
            return apps.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .color:
            let items = apps.map { app in
                SortableInstalledApp(
                    app: app,
                    recentIndex: settings.recentBundleIDs.firstIndex(of: app.bundleID),
                    colorSignature: app.icon.launchpadColorSignature(name: app.name)
                )
            }
            return items.sorted { lhs, rhs in
                if lhs.colorSignature != rhs.colorSignature {
                    return lhs.colorSignature < rhs.colorSignature
                }
                return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
            }.map(\.app)
        }
    }

    func loadShortcutTargets(settings: AppSettings) -> [LaunchableApp] {
        let shortcutIDs = Set(settings.launchShortcuts.keys)
        let shortcutApps = installedApplications(loadIcons: false).compactMap { app -> LaunchableApp? in
            let bundleID = app.bundleID ?? app.url.path
            guard shortcutIDs.contains(bundleID) else { return nil }
            return LaunchableApp(
                id: bundleID,
                name: app.displayName,
                bundleID: bundleID,
                url: app.url,
                icon: app.icon,
                shortcut: shortcut(for: app.bundleID, settings: settings),
                snippet: nil
            )
        }

        return launcherCommands()
            + loadSnippets(settings: settings).filter { shortcutIDs.contains($0.bundleID) }
            + shortcutApps
    }

    func launcherCommands() -> [LaunchableApp] {
        [
            makeCommand(id: LauncherCommand.emptyTrash.rawValue, name: LauncherCommand.emptyTrash.title, iconName: "trash"),
            makeCommand(id: LauncherCommand.eject.rawValue, name: LauncherCommand.eject.title, iconName: "eject")
        ]
    }

    func loadSnippets(settings: AppSettings) -> [LaunchableApp] {
        return settings.snippets.filter(\.isEnabled).map { snippet in
            let icon = icon(for: snippet)
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
        .sorted { (lhs: LaunchableApp, rhs: LaunchableApp) in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func refreshURLSnippetIcons(settings: AppSettings) {
        for snippet in settings.snippets where snippet.kind == .url && snippet.faviconData == nil {
            guard let normalizedURL = normalizedURL(snippet.urlString) else { continue }
            Task {
                guard await FaviconRefreshTracker.shared.begin(id: snippet.id) else { return }
                defer { Task { await FaviconRefreshTracker.shared.finish(id: snippet.id) } }

                guard let faviconData = await fetchFaviconData(for: normalizedURL) else { return }

                await MainActor.run {
                    guard let current = settings.snippet(for: snippet.id),
                          current.faviconData == nil,
                          current.kind == .url,
                          current.urlString == snippet.urlString
                    else { return }

                    var updated = current
                    updated.faviconData = faviconData
                    settings.updateSnippet(updated)
                }
            }
        }
    }

    func launch(_ app: LaunchableApp, settings: AppSettings) -> String? {
        if let feedback = handleCommandLaunch(app) { return feedback }
        if let snippet = app.snippet {
            launch(snippet: snippet)
            settings.markLaunched(bundleID: app.bundleID)
            return nil
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, _ in }
        settings.markLaunched(bundleID: app.bundleID)
        return nil
    }

    private func shortcut(for bundleID: String?, settings: AppSettings) -> KeyboardShortcutSetting? {
        guard let bundleID else { return nil }
        return settings.launchShortcut(for: bundleID)
    }

    private func icon(for snippet: SnippetDefinition) -> NSImage {
        if let faviconImage = snippet.faviconImage {
            return faviconImage
        }

        let iconName = snippet.launchpadSymbolName ?? "terminal"
        let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: snippet.title) ?? NSImage()
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }

    private func installedApplications(loadIcons: Bool) -> [InstalledApp] {
        if loadIcons {
            if let cached = Self.cachedInstalledApps,
               Date().timeIntervalSince(Self.cachedInstalledAppsTimestamp) < Self.installedAppsCacheTTL {
                return cached
            }
        }

        let urls = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var seen = Set<String>()
        let result = urls.flatMap { folder -> [InstalledApp] in
            applications(in: folder, loadIcons: loadIcons)
        }
        .filter { app in
            guard !seen.contains(app.bundleID ?? app.url.path) else { return false }
            seen.insert(app.bundleID ?? app.url.path)
            return true
        }

        if loadIcons {
            Self.cachedInstalledApps = result
            Self.cachedInstalledAppsTimestamp = Date()
        }
        return result
    }

    private func applications(in folder: URL, loadIcons: Bool) -> [InstalledApp] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.localizedNameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        return enumerator.compactMap { item in
            autoreleasepool {
                guard let url = item as? URL, url.pathExtension == "app" else { return nil }
                let values = try? url.resourceValues(forKeys: [.localizedNameKey])
                let name = values?.localizedName ?? url.deletingPathExtension().lastPathComponent
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
                let icon: NSImage
                if loadIcons {
                    icon = NSWorkspace.shared.icon(forFile: url.path).rasterized(to: NSSize(width: 96, height: 96))
                } else {
                    icon = Self.placeholderIcon
                }
                return InstalledApp(url: url, displayName: name, bundleID: bundleID, icon: icon)
            }
        }
    }

    private func handleCommandLaunch(_ app: LaunchableApp) -> String? {
        switch app.id {
        case LauncherCommand.emptyTrash.rawValue:
            return emptyTrash()
        case LauncherCommand.eject.rawValue:
            ejectMountedVolumes()
            return nil
        default:
            return nil
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
        let ext = script.hasPrefix("#!/bin/bash") ? "bash" : "sh"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pk_snippet_\(UUID().uuidString).\(ext)")
        do {
            try script.write(to: tempURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: tempURL.path
            )
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ext == "bash" ? "/bin/bash" : "/bin/sh")
            process.arguments = [tempURL.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { proc in
                try? FileManager.default.removeItem(at: tempURL)
                proc.waitUntilExit()
            }
            try process.run()
        } catch {
            NSLog("PKwindowsManagement: snippet execution failed: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
        }
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

    private func fetchFaviconData(for url: URL) async -> Data? {
        let candidates = faviconCandidates(for: url)
        for candidate in candidates {
            if let data = await fetchData(from: candidate), NSImage(data: data) != nil {
                return data
            }
        }

        guard let htmlURL = originURL(for: url),
              let htmlData = await fetchData(from: htmlURL),
              let html = String(data: htmlData, encoding: .utf8),
              let iconURL = extractIconURL(from: html, baseURL: htmlURL)
        else {
            return nil
        }

        if let data = await fetchData(from: iconURL), NSImage(data: data) != nil {
            return data
        }

        return nil
    }

    private func fetchData(from url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  !data.isEmpty
            else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func faviconCandidates(for url: URL) -> [URL] {
        guard let origin = originURL(for: url) else { return [] }
        return [
            origin.appendingPathComponent("favicon.ico"),
            origin.appendingPathComponent("apple-touch-icon.png"),
            origin.appendingPathComponent("apple-touch-icon-precomposed.png")
        ]
    }

    private func originURL(for url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              let host = components.host
        else { return nil }

        var origin = URLComponents()
        origin.scheme = scheme
        origin.host = host
        origin.port = components.port
        return origin.url
    }

    private func extractIconURL(from html: String, baseURL: URL) -> URL? {
        let pattern = #"<link[^>]*rel=["'][^"']*(?:icon|shortcut icon|apple-touch-icon)[^"']*["'][^>]*href=["']([^"']+)["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let hrefRange = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        let href = String(html[hrefRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !href.isEmpty else { return nil }
        return URL(string: href, relativeTo: baseURL)?.absoluteURL
    }

    private func ejectMountedVolumes() {
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeURLForRemountingKey], options: [.skipHiddenVolumes]) ?? []
        for volume in mounted {
            guard volume.path != "/" else { continue }
            try? NSWorkspace.shared.unmountAndEjectDevice(at: volume)
        }
    }

    private func emptyTrash() -> String? {
        let script = """
        ignoring application responses
            tell application "Finder"
                empty trash
            end tell
        end ignoring
        """
        var errorInfo: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return nil }

        let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
        NSLog("PKwindowsManagement: empty trash failed (%d): %@", number, errorInfo)

        if number == -1743 || number == -1719 {
            return localizedString("macOS blocked Finder automation. Relaunch this packaged app and allow PKwindowsManagement to control Finder when prompted.")
        }
        if number == -128 {
            return nil
        }
        let message = (errorInfo[NSAppleScript.errorBriefMessage] as? String)
            ?? (errorInfo[NSAppleScript.errorMessage] as? String)
            ?? localizedFormat("Finder returned error %d.", number)
        return localizedFormat("Trash could not be emptied: %@", message)
    }

    private func makeCommand(id: String, name: String, iconName: String) -> LaunchableApp {
        let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: name) ?? NSImage()
        icon.size = NSSize(width: 64, height: 64)
        return LaunchableApp(id: id, name: name, bundleID: id, url: URL(fileURLWithPath: "/"), icon: icon, shortcut: nil, snippet: nil)
    }

    private func sortByRecent(_ lhs: LaunchableApp, _ rhs: LaunchableApp, settings: AppSettings) -> Bool {
        switch (settings.recentBundleIDs.firstIndex(of: lhs.bundleID), settings.recentBundleIDs.firstIndex(of: rhs.bundleID)) {
        case let (left?, right?):
            if left != right { return left < right }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private struct SortableInstalledApp {
    let app: LaunchableApp
    let recentIndex: Int?
    let colorSignature: LaunchpadColorSignature
}

private struct LaunchpadColorSignature: Equatable, Comparable {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
    let name: String

    static func < (lhs: LaunchpadColorSignature, rhs: LaunchpadColorSignature) -> Bool {
        if lhs.hue != rhs.hue { return lhs.hue < rhs.hue }
        if lhs.saturation != rhs.saturation { return lhs.saturation < rhs.saturation }
        if lhs.brightness != rhs.brightness { return lhs.brightness < rhs.brightness }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private extension NSImage {
    func rasterized(to targetSize: NSSize) -> NSImage {
        let result = NSImage(size: targetSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        result.unlockFocus()
        return result
    }

    func launchpadColorSignature(name: String) -> LaunchpadColorSignature {
        guard let color = averageLaunchpadColor()?.usingColorSpace(.deviceRGB) else {
            return LaunchpadColorSignature(hue: 1, saturation: 0, brightness: 1, name: name)
        }

        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        let maxComponent = max(red, green, blue)
        let minComponent = min(red, green, blue)
        let delta = maxComponent - minComponent

        var hue: CGFloat = 0
        if delta > 0 {
            if maxComponent == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxComponent == green {
                hue = ((blue - red) / delta) + 2
            } else {
                hue = ((red - green) / delta) + 4
            }
            hue /= 6
            if hue < 0 {
                hue += 1
            }
        }

        let saturation = maxComponent == 0 ? 0 : delta / maxComponent
        let brightness = maxComponent
        return LaunchpadColorSignature(hue: hue, saturation: saturation, brightness: brightness, name: name)
    }

    func averageLaunchpadColor() -> NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = pixel.withUnsafeMutableBytes({ buffer -> CGContext? in
            CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return NSColor(
            deviceRed: CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[2]) / 255.0,
            alpha: CGFloat(pixel[3]) / 255.0
        )
    }
}

actor FaviconRefreshTracker {
    static let shared = FaviconRefreshTracker()

    private var inFlightIDs: Set<String> = []

    func begin(id: String) -> Bool {
        guard !inFlightIDs.contains(id) else { return false }
        inFlightIDs.insert(id)
        return true
    }

    func finish(id: String) {
        inFlightIDs.remove(id)
    }
}

enum AppLauncherError: LocalizedError {
    case uninstallNotAllowed

    var errorDescription: String? {
        switch self {
        case .uninstallNotAllowed:
            localizedString("This application cannot be moved to the Trash.")
        }
    }
}

private struct InstalledApp {
    let url: URL
    let displayName: String
    let bundleID: String?
    let icon: NSImage
}
