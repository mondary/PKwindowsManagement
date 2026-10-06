import Foundation
import Sparkle

/// Sparkle auto-updates with two channels (pattern proven in Macos_PKmonitor):
/// - stable: `appcast.xml`, fed by `v*` tag releases;
/// - dev: `appcast-dev.xml`, one fresh item per push on main, installed
///   silently.
/// The feed URL must come from the updater delegate (SPUUpdater.feedURL is
/// read-only), so a small dedicated object provides it from the shared
/// `updateChannel` preference.
final class UpdaterManager {
    static let shared = UpdaterManager()

    static let channelKey = "updateChannel"
    static let stableFeedURL = "https://raw.githubusercontent.com/mondary/PKwindowsManagement/main/appcast.xml"
    static let devFeedURL = "https://raw.githubusercontent.com/mondary/PKwindowsManagement/main/appcast-dev.xml"

    private let feedProvider = ChannelFeedProvider()
    private var controller: SPUStandardUpdaterController?

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

    /// Dev builds install silently; stable builds ask first.
    private func applyChannelBehavior() {
        controller?.updater.automaticallyDownloadsUpdates = (channel == .dev)
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
