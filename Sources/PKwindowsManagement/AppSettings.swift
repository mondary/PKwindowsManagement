import AppKit
import Foundation

final class AppSettings: ObservableObject {
    private enum Keys {
        static let shortcuts = "keyboard-shortcuts"
        static let clipboardDrawerEdge = "clipboard-drawer-edge"
        static let launchRecents = "launch-recents"
        static let launchShortcuts = "launch-shortcuts"
        static let launchpadShortcut = "launchpad-shortcut"
        static let launchpadHotCorner = "launchpad-hot-corner"
        static let launchpadGridColumns = "launchpad-grid-columns"
        static let launchpadGridRows = "launchpad-grid-rows"
        static let launchpadGridNavigation = "launchpad-grid-navigation"
        static let launchpadIconSize = "launchpad-icon-size"
        static let launchpadColumnSpacing = "launchpad-column-spacing"
        static let launchpadRowSpacing = "launchpad-row-spacing"
    }

    private let defaults: UserDefaults

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcutSetting]

    @Published var clipboardDrawerEdge: ClipboardDrawerEdge {
        didSet { defaults.set(clipboardDrawerEdge.rawValue, forKey: Keys.clipboardDrawerEdge) }
    }

    @Published private(set) var recentBundleIDs: [String]
    @Published private(set) var launchShortcuts: [String: KeyboardShortcutSetting]
    @Published var launchpadShortcut: KeyboardShortcutSetting {
        didSet {
            saveLaunchpadShortcut()
            NotificationCenter.default.post(name: .launchpadHotKeyDidChange, object: nil)
        }
    }
    @Published var launchpadHotCorner: LaunchpadHotCorner {
        didSet { defaults.set(launchpadHotCorner.rawValue, forKey: Keys.launchpadHotCorner) }
    }
    @Published var launchpadGridColumns: Int {
        didSet {
            let clamped = min(max(launchpadGridColumns, 4), 14)
            guard launchpadGridColumns == clamped else {
                launchpadGridColumns = clamped
                return
            }
            defaults.set(launchpadGridColumns, forKey: Keys.launchpadGridColumns)
        }
    }
    @Published var launchpadGridRows: Int {
        didSet {
            let clamped = min(max(launchpadGridRows, 3), 10)
            guard launchpadGridRows == clamped else {
                launchpadGridRows = clamped
                return
            }
            defaults.set(launchpadGridRows, forKey: Keys.launchpadGridRows)
        }
    }
    @Published var launchpadGridNavigation: LaunchpadGridNavigation {
        didSet { defaults.set(launchpadGridNavigation.rawValue, forKey: Keys.launchpadGridNavigation) }
    }
    @Published var launchpadIconSize: Int {
        didSet {
            let clamped = min(max(launchpadIconSize, 28), 96)
            guard launchpadIconSize == clamped else {
                launchpadIconSize = clamped
                return
            }
            defaults.set(launchpadIconSize, forKey: Keys.launchpadIconSize)
        }
    }
    @Published var launchpadColumnSpacing: Int {
        didSet {
            let clamped = min(max(launchpadColumnSpacing, 4), 48)
            guard launchpadColumnSpacing == clamped else {
                launchpadColumnSpacing = clamped
                return
            }
            defaults.set(launchpadColumnSpacing, forKey: Keys.launchpadColumnSpacing)
        }
    }
    @Published var launchpadRowSpacing: Int {
        didSet {
            let clamped = min(max(launchpadRowSpacing, 4), 48)
            guard launchpadRowSpacing == clamped else {
                launchpadRowSpacing = clamped
                return
            }
            defaults.set(launchpadRowSpacing, forKey: Keys.launchpadRowSpacing)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let edgeRaw = defaults.string(forKey: Keys.clipboardDrawerEdge) ?? ClipboardDrawerEdge.top.rawValue
        clipboardDrawerEdge = ClipboardDrawerEdge(rawValue: edgeRaw) ?? .top
        shortcuts = Self.loadShortcuts(from: defaults)
        recentBundleIDs = defaults.stringArray(forKey: Keys.launchRecents) ?? []
        launchShortcuts = Self.loadLaunchShortcuts(from: defaults)
        launchpadShortcut = Self.loadLaunchpadShortcut(from: defaults)
        let hotCornerRaw = defaults.string(forKey: Keys.launchpadHotCorner) ?? LaunchpadHotCorner.topLeft.rawValue
        launchpadHotCorner = LaunchpadHotCorner(rawValue: hotCornerRaw) ?? .topLeft
        launchpadGridColumns = min(max(defaults.object(forKey: Keys.launchpadGridColumns) as? Int ?? 7, 4), 14)
        launchpadGridRows = min(max(defaults.object(forKey: Keys.launchpadGridRows) as? Int ?? 5, 3), 10)
        let navigationRaw = defaults.string(forKey: Keys.launchpadGridNavigation) ?? LaunchpadGridNavigation.vertical.rawValue
        launchpadGridNavigation = LaunchpadGridNavigation(rawValue: navigationRaw) ?? .vertical
        launchpadIconSize = min(max(defaults.object(forKey: Keys.launchpadIconSize) as? Int ?? 48, 28), 96)
        launchpadColumnSpacing = min(max(defaults.object(forKey: Keys.launchpadColumnSpacing) as? Int ?? 16, 4), 48)
        launchpadRowSpacing = min(max(defaults.object(forKey: Keys.launchpadRowSpacing) as? Int ?? 12, 4), 48)
    }

    func shortcut(for action: ShortcutAction) -> KeyboardShortcutSetting {
        shortcuts[action] ?? action.defaultShortcut
    }

    func setShortcut(_ shortcut: KeyboardShortcutSetting, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        saveShortcuts()
    }

    func resetShortcut(for action: ShortcutAction) {
        shortcuts[action] = action.defaultShortcut
        saveShortcuts()
    }

    func markLaunched(bundleID: String) {
        recentBundleIDs.removeAll { $0 == bundleID }
        recentBundleIDs.insert(bundleID, at: 0)
        recentBundleIDs = Array(recentBundleIDs.prefix(12))
        defaults.set(recentBundleIDs, forKey: Keys.launchRecents)
    }

    func launchShortcut(for bundleID: String) -> KeyboardShortcutSetting? {
        launchShortcuts[bundleID]
    }

    func setLaunchShortcut(_ shortcut: KeyboardShortcutSetting?, for bundleID: String) {
        if let shortcut {
            launchShortcuts[bundleID] = shortcut
        } else {
            launchShortcuts.removeValue(forKey: bundleID)
        }
        saveLaunchShortcuts()
    }

    func exportBackup() throws -> Data {
        let backup = SettingsBackup(
            version: 1,
            windowShortcuts: Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) }),
            launchShortcuts: launchShortcuts,
            recentBundleIDs: recentBundleIDs,
            clipboardDrawerEdge: clipboardDrawerEdge,
            launchpadShortcut: launchpadShortcut,
            launchpadHotCorner: launchpadHotCorner,
            launchpadGridColumns: launchpadGridColumns,
            launchpadGridRows: launchpadGridRows,
            launchpadGridNavigation: launchpadGridNavigation,
            launchpadIconSize: launchpadIconSize,
            launchpadColumnSpacing: launchpadColumnSpacing,
            launchpadRowSpacing: launchpadRowSpacing
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    func importBackup(_ data: Data) throws {
        let backup = try JSONDecoder().decode(SettingsBackup.self, from: data)
        guard backup.version == 1 else { throw SettingsBackupError.unsupportedVersion }

        shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { action in
            (action, backup.windowShortcuts[action.rawValue] ?? action.defaultShortcut)
        })
        launchShortcuts = backup.launchShortcuts
        recentBundleIDs = backup.recentBundleIDs
        clipboardDrawerEdge = backup.clipboardDrawerEdge
        launchpadShortcut = backup.launchpadShortcut
        launchpadHotCorner = backup.launchpadHotCorner
        launchpadGridColumns = backup.launchpadGridColumns
        launchpadGridRows = backup.launchpadGridRows
        launchpadGridNavigation = backup.launchpadGridNavigation
        launchpadIconSize = backup.launchpadIconSize ?? 48
        launchpadColumnSpacing = backup.launchpadColumnSpacing ?? 16
        launchpadRowSpacing = backup.launchpadRowSpacing ?? 12

        saveShortcuts()
        saveLaunchShortcuts()
        defaults.set(recentBundleIDs, forKey: Keys.launchRecents)
    }

    private func saveShortcuts() {
        let rawShortcuts = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(rawShortcuts) else { return }
        defaults.set(data, forKey: Keys.shortcuts)
    }

    private static func loadShortcuts(from defaults: UserDefaults) -> [ShortcutAction: KeyboardShortcutSetting] {
        var shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, $0.defaultShortcut) })
        guard let data = defaults.data(forKey: Keys.shortcuts),
              let rawShortcuts = try? JSONDecoder().decode([String: KeyboardShortcutSetting].self, from: data)
        else { return shortcuts }
        for (rawAction, shortcut) in rawShortcuts {
            guard let action = ShortcutAction(rawValue: rawAction) else { continue }
            shortcuts[action] = shortcut
        }
        return shortcuts
    }

    private func saveLaunchShortcuts() {
        guard let data = try? JSONEncoder().encode(launchShortcuts) else { return }
        defaults.set(data, forKey: Keys.launchShortcuts)
    }

    private func saveLaunchpadShortcut() {
        guard let data = try? JSONEncoder().encode(launchpadShortcut) else { return }
        defaults.set(data, forKey: Keys.launchpadShortcut)
    }

    private static func loadLaunchpadShortcut(from defaults: UserDefaults) -> KeyboardShortcutSetting {
        guard let data = defaults.data(forKey: Keys.launchpadShortcut),
              let shortcut = try? JSONDecoder().decode(KeyboardShortcutSetting.self, from: data)
        else { return .init(key: "space", modifier: .option) }
        return shortcut
    }

    private static func loadLaunchShortcuts(from defaults: UserDefaults) -> [String: KeyboardShortcutSetting] {
        guard let data = defaults.data(forKey: Keys.launchShortcuts),
              let shortcuts = try? JSONDecoder().decode([String: KeyboardShortcutSetting].self, from: data)
        else { return [:] }
        return shortcuts
    }
}

private struct SettingsBackup: Codable {
    let version: Int
    let windowShortcuts: [String: KeyboardShortcutSetting]
    let launchShortcuts: [String: KeyboardShortcutSetting]
    let recentBundleIDs: [String]
    let clipboardDrawerEdge: ClipboardDrawerEdge
    let launchpadShortcut: KeyboardShortcutSetting
    let launchpadHotCorner: LaunchpadHotCorner
    let launchpadGridColumns: Int
    let launchpadGridRows: Int
    let launchpadGridNavigation: LaunchpadGridNavigation
    let launchpadIconSize: Int?
    let launchpadColumnSpacing: Int?
    let launchpadRowSpacing: Int?
}

enum SettingsBackupError: LocalizedError {
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This settings backup version is not supported."
        }
    }
}

enum LaunchpadGridNavigation: String, CaseIterable, Identifiable, Codable {
    case vertical
    case horizontalPages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: "Vertical Scroll"
        case .horizontalPages: "Horizontal Pages"
        }
    }
}

enum LaunchpadHotCorner: String, CaseIterable, Identifiable, Codable {
    case disabled
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: "Disabled"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        }
    }
}

enum ClipboardDrawerEdge: String, CaseIterable, Identifiable, Codable {
    case top
    case bottom
    case left
    case right

    var id: String { rawValue }
}
