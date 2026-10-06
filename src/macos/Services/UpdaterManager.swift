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
    @Published private(set) var switchOffer: ChannelSwitchOffer?
    @Published private(set) var installingSwitch = false
    @Published private(set) var switchErrorMessage: String?

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
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    func refreshAvailableVersions() {
        Task {
            async let stable = Self.latestVersion(at: Self.stableFeedURL)
            async let dev = Self.latestVersion(at: Self.devFeedURL)
            let versions = await (stable, dev)
            await MainActor.run {
                self.latestStableVersion = versions.0
                self.latestDevVersion = versions.1
            }
        }
    }

    private static func latestVersion(at address: String) async -> String? {
        guard let url = URL(string: address),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        let parser = AppcastVersionParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return nil }
        return parser.version
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
        switchOffer = ChannelSwitchOffer(channel: channel, version: target, url: fileURL)
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
    private(set) var version: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "sparkle:shortVersionString" || qName == "sparkle:shortVersionString" {
            insideShortVersion = true
            currentText = ""
        } else if elementName == "sparkle:version" || qName == "sparkle:version" {
            insideSparkleVersion = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideShortVersion || insideSparkleVersion { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if insideShortVersion && (elementName == "sparkle:shortVersionString" || qName == "sparkle:shortVersionString") {
            version = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            insideShortVersion = false
        } else if insideSparkleVersion && (elementName == "sparkle:version" || qName == "sparkle:version") {
            if version == nil { version = currentText.trimmingCharacters(in: .whitespacesAndNewlines) }
            insideSparkleVersion = false
        }
    }
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
        UserDefaults.standard.string(forKey: UpdaterManager.channelKey) == UpdateChannel.dev.rawValue
            ? UpdaterManager.devFeedURL
            : UpdaterManager.stableFeedURL
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: NSError) {
        let info = error.userInfo
        let userInitiated = (info[SPUNoUpdateFoundUserInitiatedKey] as? Bool) ?? false
        let item = info[SPULatestAppcastItemFoundKey] as? SUAppcastItem
        onNoUpdate?(userInitiated, item)
    }
}
