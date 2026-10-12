import Foundation

/// A newer build timestamp cannot turn an older product version into an update.
/// Downgrades are offered only for an explicit Stable/Dev channel change.
enum UpdateVersionPolicy {
    enum Decision { case update, current, installedAhead, channelSwitch }

    static func decision(installed: String, build: Int64, offered: String, offeredBuild: Int64) -> Decision {
        let installedDev = installed.hasSuffix("-dev")
        let offeredDev = offered.hasSuffix("-dev")
        if installedDev != offeredDev { return .channelSwitch }
        switch offered.compare(installed, options: .numeric) {
        case .orderedAscending: return .installedAhead
        case .orderedDescending: return .update
        case .orderedSame:
            if offeredBuild > build { return .update }
            return offeredBuild == build ? .current : .installedAhead
        }
    }
}
