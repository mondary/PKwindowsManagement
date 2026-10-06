import Foundation
import FoundationXML
import Sparkle

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
    @Published private(set) var latestStableVersion: String?
    @Published private(set) var latestDevVersion: String?

    var channel: UpdateChannel {
        get {
            UpdateChannel(rawValue: UserDefaults.standard.string(forKey: Self.channelKey) ?? UpdateChannel.stable.rawValue) ?? .stable
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.channelKey)
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
    func feedURLString(for updater: SPUUpdater) -> String {
        UserDefaults.standard.string(forKey: UpdaterManager.channelKey) == UpdateChannel.dev.rawValue
            ? UpdaterManager.devFeedURL
            : UpdaterManager.stableFeedURL
    }
}
