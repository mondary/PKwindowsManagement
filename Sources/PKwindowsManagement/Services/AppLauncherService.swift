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
            return snippet.faviconData == nil ? "globe" : nil
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
        let items = installedApplications().map { app -> SortableInstalledApp in
            let bundleID = app.bundleID ?? app.url.path
            return SortableInstalledApp(
                app: LaunchableApp(
                    id: bundleID,
                    name: app.displayName,
                    bundleID: bundleID,
                    url: app.url,
                    icon: app.icon,
                    shortcut: shortcut(for: app.bundleID, settings: settings),
                    snippet: nil
                ),
                recentIndex: settings.recentBundleIDs.firstIndex(of: bundleID),
                colorSignature: app.icon.launchpadColorSignature(name: app.displayName)
            )
        }

        switch settings.launchpadAppSortMode {
        case .recent:
            return items.sorted { lhs, rhs in
                sortByRecent(lhs, rhs)
            }.map(\.app)
        case .name:
            return items.sorted { lhs, rhs in
                lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
            }.map(\.app)
        case .color:
            return items.sorted { lhs, rhs in
                if lhs.colorSignature != rhs.colorSignature {
                    return lhs.colorSignature < rhs.colorSignature
                }
                return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
            }.map(\.app)
        }
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

    private func icon(for snippet: SnippetDefinition) -> NSImage {
        if let faviconImage = snippet.faviconImage {
            return faviconImage
        }

        let iconName = snippet.kind == .url ? "globe" : "terminal"
        let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: snippet.title) ?? NSImage()
        icon.size = NSSize(width: 64, height: 64)
        return icon
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

    private func sortByRecent(_ lhs: SortableInstalledApp, _ rhs: SortableInstalledApp) -> Bool {
        switch (lhs.recentIndex, rhs.recentIndex) {
        case let (left?, right?):
            if left != right { return left < right }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }
        return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
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
