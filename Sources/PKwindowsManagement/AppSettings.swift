import AppKit
import Foundation

final class AppSettings: ObservableObject {
    private enum Keys {
        static let shortcuts = "keyboard-shortcuts"
        static let clipboardDrawerEdge = "clipboard-drawer-edge"
        static let launchRecents = "launch-recents"
        static let launchShortcuts = "launch-shortcuts"
    }

    private let defaults: UserDefaults

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcutSetting]

    @Published var clipboardDrawerEdge: ClipboardDrawerEdge {
        didSet { defaults.set(clipboardDrawerEdge.rawValue, forKey: Keys.clipboardDrawerEdge) }
    }

    @Published private(set) var recentBundleIDs: [String]
    @Published private(set) var launchShortcuts: [String: KeyboardShortcutSetting]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let edgeRaw = defaults.string(forKey: Keys.clipboardDrawerEdge) ?? ClipboardDrawerEdge.top.rawValue
        clipboardDrawerEdge = ClipboardDrawerEdge(rawValue: edgeRaw) ?? .top
        shortcuts = Self.loadShortcuts(from: defaults)
        recentBundleIDs = defaults.stringArray(forKey: Keys.launchRecents) ?? []
        launchShortcuts = Self.loadLaunchShortcuts(from: defaults)
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

    private static func loadLaunchShortcuts(from defaults: UserDefaults) -> [String: KeyboardShortcutSetting] {
        guard let data = defaults.data(forKey: Keys.launchShortcuts),
              let shortcuts = try? JSONDecoder().decode([String: KeyboardShortcutSetting].self, from: data)
        else { return [:] }
        return shortcuts
    }
}

enum ClipboardDrawerEdge: String, CaseIterable, Identifiable {
    case top
    case bottom
    case left
    case right

    var id: String { rawValue }
}
