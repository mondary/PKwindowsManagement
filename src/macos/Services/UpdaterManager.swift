import AppKit
import Foundation
import Sparkle

/// Offer shown when a manual check finds nothing newer but the selected
/// channel's latest build differs from the running one (e.g. going back from
/// a dev build to the last stable release).
struct ChannelSwitchOffer: Identifiable {
    let id = UUID()
    let channel: UpdateChannel
    let version: String
    let url: URL
    let isUpdate: Bool
}

/// Sparkle auto-updates with two channels (pattern proven in Macos_PKmonitor):
/// - stable: `appcast.xml`, fed by `v*` tag releases;
/// - dev: `appcast-dev.xml`, one fresh item per push on main, installed
///   silently.
/// The feed URL must come from the updater delegate (SPUUpdater.feedURL is
/// read-only), so a small dedicated object provides it from the shared
/// `updateChannel` preference.
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    static let channelKey = "updateChannel"
    static let stableFeedURL = "https://raw.githubusercontent.com/mondary/PKwindowsManagement/main/appcast.xml"
    static let devFeedURL = "https://raw.githubusercontent.com/mondary/PKwindowsManagement/main/appcast-dev.xml"

    private let feedProvider = ChannelFeedProvider()
    private var controller: SPUStandardUpdaterController?
    @Published private(set) var selectedChannel: UpdateChannel
    @Published private(set) var latestStableVersion: String?
    @Published private(set) var latestDevVersion: String?
    @Published private(set) var availableUpdateVersion: String?
    @Published private(set) var switchOffer: ChannelSwitchOffer?
    @Published private(set) var installingSwitch = false
    @Published private(set) var switchErrorMessage: String?
    private var stableInfo: AppcastInfo?
    private var devInfo: AppcastInfo?
    private var versionRefreshTimer: Timer?

    static let availabilityDidChange = Notification.Name("PKwindowsManagement.updateAvailabilityDidChange")

    private init() {
        selectedChannel = UpdateChannel(
            rawValue: UserDefaults.standard.string(forKey: Self.channelKey) ?? UpdateChannel.stable.rawValue
        ) ?? .stable
        feedProvider.onNoUpdate = { [weak self] userInitiated, item in
            self?.handleNoUpdate(userInitiated: userInitiated, item: item)
        }
    }

    var channel: UpdateChannel {
        get { selectedChannel }
        set {
            guard selectedChannel != newValue else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.channelKey)
            selectedChannel = newValue
            applyChannelBehavior()
            refreshUpdateAvailability()
        }
    }

    func start() {
        guard controller == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: feedProvider,
            userDriverDelegate: nil
        )
        self.controller = controller
        applyChannelBehavior()
        controller.startUpdater()
        refreshAvailableVersions()
        versionRefreshTimer?.invalidate()
        versionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            self?.refreshAvailableVersions()
        }
    }

    func checkForUpdates() {
        checkForUpdatesOrSwitch()
    }

    func refreshAvailableVersions() {
        Task {
            let versions = await (
                Self.latestInfo(at: Self.stableFeedURL),
                Self.latestInfo(at: Self.devFeedURL)
            )
            await MainActor.run {
                self.latestStableVersion = versions.0?.short
                self.latestDevVersion = versions.1?.short
                self.stableInfo = versions.0
                self.devInfo = versions.1
                self.refreshUpdateAvailability()
            }
        }
    }

    /// Refresh both feeds, then install from the verified enclosure directly.
    /// This avoids Sparkle presenting a stale CDN copy of an appcast. A channel
    /// switch to an older build is also offered when the short version differs.
    func checkForUpdatesOrSwitch() {
        Task {
            let versions = await (
                Self.latestInfo(at: Self.stableFeedURL),
                Self.latestInfo(at: Self.devFeedURL)
            )
            await MainActor.run {
                self.latestStableVersion = versions.0?.short
                self.latestDevVersion = versions.1?.short
                self.stableInfo = versions.0
                self.devInfo = versions.1
                self.refreshUpdateAvailability()

                let target = channel == .dev ? versions.1 : versions.0
                guard let target,
                      let enclosure = target.enclosure,
                      let installedShort = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                      let installedTechnical = Int64(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""),
                      let feedTechnical = Int64(target.technical)
                else {
                    controller?.checkForUpdates(nil)
                    return
                }

                if feedTechnical > installedTechnical {
                    // The fresh feed check is authoritative. Do not hand this
                    // result back to Sparkle, whose CDN response may be stale.
                    switchOffer = ChannelSwitchOffer(
                        channel: channel,
                        version: target.short,
                        url: enclosure,
                        isUpdate: true
                    )
                } else if target.short != installedShort {
                    switchOffer = ChannelSwitchOffer(
                        channel: channel,
                        version: target.short,
                        url: enclosure,
                        isUpdate: false
                    )
                } else {
                    controller?.checkForUpdates(nil)
                }
            }
        }
    }

    private static func latestInfo(at address: String) async -> AppcastInfo? {
        guard let url = freshFeedURL(address) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        let parser = AppcastVersionParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return nil }
        return parser.info
    }

    /// GitHub's raw-content CDN may keep serving an older appcast at a stable
    /// URL for several minutes. A unique query value bypasses that intermediary
    /// cache for both our version display and Sparkle's feed request.
    fileprivate static func freshFeedURL(_ address: String) -> URL? {
        guard var components = URLComponents(string: address) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "_pk_refresh", value: UUID().uuidString))
        components.queryItems = items
        return components.url
    }

    private func refreshUpdateAvailability() {
        let previousVersion = availableUpdateVersion
        let info = channel == .dev ? devInfo : stableInfo
        let installedTechnical = Int64(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
        let feedTechnical = info.flatMap { Int64($0.technical) }
        if let info, let installedTechnical, let feedTechnical, feedTechnical > installedTechnical {
            availableUpdateVersion = info.short
        } else {
            availableUpdateVersion = nil
        }
        if availableUpdateVersion != previousVersion {
            NotificationCenter.default.post(name: Self.availabilityDidChange, object: self)
        }
    }

    /// Dev builds install silently; stable builds ask first.
    private func applyChannelBehavior() {
        controller?.updater.automaticallyDownloadsUpdates = (channel == .dev)
    }

    /// Sparkle never offers an older version, but switching channel is a
    /// legitimate "install that channel's latest, whatever its number" move.
    /// When a manual check finds nothing newer and the feed's latest build
    /// differs from the running one, offer that switch.
    private func handleNoUpdate(userInitiated: Bool, item: SUAppcastItem?) {
        guard userInitiated,
              !installingSwitch,
              let item,
              let fileURL = item.fileURL,
              let installed = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return }
        let target = item.displayVersionString
        guard !target.isEmpty, target != installed else { return }
        switchOffer = ChannelSwitchOffer(channel: channel, version: target, url: fileURL, isUpdate: false)
    }

    func cancelSwitchOffer() {
        switchOffer = nil
    }

    func performSwitchInstall() {
        guard let offer = switchOffer else { return }
        switchOffer = nil
        installingSwitch = true
        switchErrorMessage = nil
        Task {
            do {
                try await installChannelBuild(from: offer.url, expectedVersion: offer.version)
                await MainActor.run {
                    installingSwitch = false
                    NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run {
                    installingSwitch = false
                    switchErrorMessage = String(
                        format: localizedString("Install failed: %@"),
                        error.localizedDescription
                    )
                }
            }
        }
    }

    /// Downloads the channel's published zip, checks it really is the offered
    /// version, then hands over to a detached script that swaps the bundle and
    /// relaunches the app once this instance has quit.
    private func installChannelBuild(from url: URL, expectedVersion: String) async throws {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("PKwindowsManagement-switch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty else {
            throw NSError(
                domain: "PKwindowsManagement.Switch", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"]
            )
        }
        let zipURL = work.appendingPathComponent("app.zip")
        try data.write(to: zipURL)

        try await runProcess("/usr/bin/ditto", ["-x", "-k", "--sequesterRsrc", zipURL.path, work.path])
        let extractedApp = work.appendingPathComponent("PKwindowsManagement.app")
        let extractedVersion = NSDictionary(
            contentsOf: extractedApp.appendingPathComponent("Contents/Info.plist")
        )?["CFBundleShortVersionString"] as? String
        guard extractedVersion == expectedVersion else {
            throw NSError(
                domain: "PKwindowsManagement.Switch", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "unexpected bundle version"]
            )
        }

        let scriptURL = work.appendingPathComponent("install.sh")
        try """
        #!/bin/bash
        sleep 2
        rm -rf '/Applications/PKwindowsManagement.app'
        /usr/bin/ditto '\(extractedApp.path)' '/Applications/PKwindowsManagement.app'
        open '/Applications/PKwindowsManagement.app'
        rm -rf '\(work.path)'
        """.write(to: scriptURL, atomically: true, encoding: .utf8)

        let installer = Process()
        installer.executableURL = URL(fileURLWithPath: "/bin/bash")
        installer.arguments = [scriptURL.path]
        installer.qualityOfService = .userInitiated
        try installer.run()
    }

    private func runProcess(_ path: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "PKwindowsManagement.Switch", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "\(path) exited with \(process.terminationStatus)"]
            )
        }
    }
}

private final class AppcastVersionParser: NSObject, XMLParserDelegate {
    private var insideShortVersion = false
    private var insideSparkleVersion = false
    private var currentText = ""
    private var shortVersion: String?
    private var technicalVersion: String?
    private var enclosureURL: URL?

    var info: AppcastInfo? {
        guard let shortVersion else { return nil }
        return AppcastInfo(short: shortVersion, technical: technicalVersion ?? shortVersion, enclosure: enclosureURL)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "sparkle:shortVersionString" || qName == "sparkle:shortVersionString" {
            insideShortVersion = true
            currentText = ""
        } else if elementName == "sparkle:version" || qName == "sparkle:version" {
            insideSparkleVersion = true
            currentText = ""
        } else if elementName == "enclosure" || qName == "enclosure" {
            if let address = attributeDict["url"], let url = URL(string: address) {
                enclosureURL = url
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideShortVersion || insideSparkleVersion { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if insideShortVersion && (elementName == "sparkle:shortVersionString" || qName == "sparkle:shortVersionString") {
            shortVersion = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            insideShortVersion = false
        } else if insideSparkleVersion && (elementName == "sparkle:version" || qName == "sparkle:version") {
            if technicalVersion == nil { technicalVersion = currentText.trimmingCharacters(in: .whitespacesAndNewlines) }
            insideSparkleVersion = false
        }
    }
}

/// What the appcast of one channel publishes: display version, Sparkle
/// technical version, and the downloadable zip.
struct AppcastInfo {
    let short: String
    let technical: String
    let enclosure: URL?
}

enum UpdateChannel: String, CaseIterable, Identifiable {
    case stable
    case dev

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stable: return localizedString("Stable")
        case .dev: return localizedString("Dev")
        }
    }

    var detail: String {
        switch self {
        case .stable: return localizedString("Versioned releases only, tested.")
        case .dev: return localizedString("Every push on main, installed silently.")
        }
    }
}

/// Separate delegate object (never captures the manager): SPUUpdaterDelegate
/// methods are called nonisolated, and `updaterDelegate` must outlive the
/// controller.
private final class ChannelFeedProvider: NSObject, SPUUpdaterDelegate {
    var onNoUpdate: ((Bool, SUAppcastItem?) -> Void)?

    func feedURLString(for updater: SPUUpdater) -> String? {
        let address = UserDefaults.standard.string(forKey: UpdaterManager.channelKey) == UpdateChannel.dev.rawValue
            ? UpdaterManager.devFeedURL
            : UpdaterManager.stableFeedURL
        return UpdaterManager.freshFeedURL(address)?.absoluteString ?? address
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: NSError) {
        let info = error.userInfo
        let userInitiated = (info[SPUNoUpdateFoundUserInitiatedKey] as? Bool) ?? false
        let item = info[SPULatestAppcastItemFoundKey] as? SUAppcastItem
        onNoUpdate?(userInitiated, item)
    }
}
