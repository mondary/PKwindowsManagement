import AppKit
import Foundation

final class AppSettings: ObservableObject {
    private enum Keys {
        static let shortcuts = "keyboard-shortcuts"
        static let clipboardDrawerEdge = "clipboard-drawer-edge"
        static let launchRecents = "launch-recents"
        static let launchShortcuts = "launch-shortcuts"
        static let snippets = "snippets"
        static let snippetsEnabled = "snippets-enabled"
        static let launchpadShortcut = "launchpad-shortcut"
        static let launchpadHotCorner = "launchpad-hot-corner"
        static let launchpadGridColumns = "launchpad-grid-columns"
        static let launchpadGridRows = "launchpad-grid-rows"
        static let launchpadDisplayProfiles = "launchpad-display-profiles"
        static let launchpadGridNavigation = "launchpad-grid-navigation"
        static let launchpadIconSize = "launchpad-icon-size"
        static let launchpadColumnSpacing = "launchpad-column-spacing"
        static let launchpadRowSpacing = "launchpad-row-spacing"
        static let autoBackupFolder = "auto-backup-folder"
        static let autoBackupEnabled = "auto-backup-enabled"
    }

    private let defaults: UserDefaults
    private var backupDebounceTimer: Timer?

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcutSetting]

    @Published var clipboardDrawerEdge: ClipboardDrawerEdge {
        didSet { defaults.set(clipboardDrawerEdge.rawValue, forKey: Keys.clipboardDrawerEdge) }
    }

    @Published private(set) var recentBundleIDs: [String]
    @Published private(set) var launchShortcuts: [String: KeyboardShortcutSetting]
    @Published private(set) var snippets: [SnippetDefinition]
    @Published private(set) var launchpadDisplayProfiles: [LaunchpadDisplayProfile]
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
            let clamped = min(max(launchpadGridColumns, 4), 20)
            guard launchpadGridColumns == clamped else {
                launchpadGridColumns = clamped
                return
            }
            defaults.set(launchpadGridColumns, forKey: Keys.launchpadGridColumns)
        }
    }
    @Published var launchpadGridRows: Int {
        didSet {
            let clamped = min(max(launchpadGridRows, 3), 20)
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
    @Published var autoBackupFolder: URL? {
        didSet {
            if let url = autoBackupFolder {
                defaults.set(url.path, forKey: Keys.autoBackupFolder)
            } else {
                defaults.removeObject(forKey: Keys.autoBackupFolder)
            }
        }
    }
    @Published var autoBackupEnabled: Bool {
        didSet { defaults.set(autoBackupEnabled, forKey: Keys.autoBackupEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let edgeRaw = defaults.string(forKey: Keys.clipboardDrawerEdge) ?? ClipboardDrawerEdge.top.rawValue
        clipboardDrawerEdge = ClipboardDrawerEdge(rawValue: edgeRaw) ?? .top
        shortcuts = Self.loadShortcuts(from: defaults)
        recentBundleIDs = defaults.stringArray(forKey: Keys.launchRecents) ?? []
        launchShortcuts = Self.loadLaunchShortcuts(from: defaults)
        let hadStoredSnippets = defaults.object(forKey: Keys.snippets) != nil
        let loadedSnippets = Self.loadSnippets(from: defaults)
        let shouldSeedDefaultSnippets = !hadStoredSnippets && loadedSnippets.isEmpty
        snippets = shouldSeedDefaultSnippets ? Self.defaultSnippets() : loadedSnippets
        launchpadDisplayProfiles = Self.loadLaunchpadDisplayProfiles(from: defaults)
        launchpadShortcut = Self.loadLaunchpadShortcut(from: defaults)
        let hotCornerRaw = defaults.string(forKey: Keys.launchpadHotCorner) ?? LaunchpadHotCorner.topLeft.rawValue
        launchpadHotCorner = LaunchpadHotCorner(rawValue: hotCornerRaw) ?? .topLeft
        launchpadGridColumns = min(max(defaults.object(forKey: Keys.launchpadGridColumns) as? Int ?? 7, 4), 20)
        launchpadGridRows = min(max(defaults.object(forKey: Keys.launchpadGridRows) as? Int ?? 5, 3), 20)
        let navigationRaw = defaults.string(forKey: Keys.launchpadGridNavigation) ?? LaunchpadGridNavigation.vertical.rawValue
        launchpadGridNavigation = LaunchpadGridNavigation(rawValue: navigationRaw) ?? .vertical
        launchpadIconSize = min(max(defaults.object(forKey: Keys.launchpadIconSize) as? Int ?? 48, 28), 96)
        launchpadColumnSpacing = min(max(defaults.object(forKey: Keys.launchpadColumnSpacing) as? Int ?? 16, 4), 48)
        launchpadRowSpacing = min(max(defaults.object(forKey: Keys.launchpadRowSpacing) as? Int ?? 12, 4), 48)
        if let folderPath = defaults.string(forKey: Keys.autoBackupFolder) {
            autoBackupFolder = URL(fileURLWithPath: folderPath)
        } else {
            autoBackupFolder = nil
        }
        autoBackupEnabled = defaults.bool(forKey: Keys.autoBackupEnabled)

        if shouldSeedDefaultSnippets {
            saveSnippets()
        }
        seedDefaultSnippetShortcuts()
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

    func snippet(for id: String) -> SnippetDefinition? {
        snippets.first { $0.id == id }
    }

    func addSnippet(_ snippet: SnippetDefinition = SnippetDefinition(title: "New Snippet", body: "")) -> SnippetDefinition {
        snippets.insert(snippet, at: 0)
        saveSnippets()
        return snippet
    }

    func updateSnippet(_ snippet: SnippetDefinition) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        saveSnippets()
    }

    func deleteSnippet(_ snippet: SnippetDefinition) {
        snippets.removeAll { $0.id == snippet.id }
        launchShortcuts.removeValue(forKey: snippet.id)
        saveSnippets()
        saveLaunchShortcuts()
    }

    func setSnippetEnabled(_ enabled: Bool, for id: String) {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[index].isEnabled = enabled
        saveSnippets()
    }

    func launchpadGridConfiguration(for displayID: CGDirectDisplayID?) -> LaunchpadGridConfiguration {
        guard let displayID,
              let profile = launchpadDisplayProfiles.first(where: { $0.displayID == displayID })
        else {
            return .init(columns: launchpadGridColumns, rows: launchpadGridRows)
        }
        return .init(columns: profile.columns, rows: profile.rows)
    }

    func launchpadDisplayProfile(for displayID: CGDirectDisplayID) -> LaunchpadDisplayProfile? {
        launchpadDisplayProfiles.first(where: { $0.displayID == displayID })
    }

    func setLaunchpadDisplayProfile(_ profile: LaunchpadDisplayProfile) {
        let clamped = profile.clamped()
        if let index = launchpadDisplayProfiles.firstIndex(where: { $0.displayID == clamped.displayID }) {
            launchpadDisplayProfiles[index] = clamped
        } else {
            launchpadDisplayProfiles.append(clamped)
        }
        saveLaunchpadDisplayProfiles()
    }

    func removeLaunchpadDisplayProfile(for displayID: CGDirectDisplayID) {
        launchpadDisplayProfiles.removeAll { $0.displayID == displayID }
        saveLaunchpadDisplayProfiles()
    }

    func exportBackup() throws -> Data {
        let backup = SettingsBackup(
            version: 5,
            windowShortcuts: Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) }),
            launchShortcuts: launchShortcuts,
            snippets: snippets,
            recentBundleIDs: recentBundleIDs,
            clipboardDrawerEdge: clipboardDrawerEdge,
            launchpadShortcut: launchpadShortcut,
            launchpadHotCorner: launchpadHotCorner,
            launchpadGridColumns: launchpadGridColumns,
            launchpadGridRows: launchpadGridRows,
            launchpadDisplayProfiles: launchpadDisplayProfiles,
            launchpadGridNavigation: launchpadGridNavigation,
            launchpadIconSize: launchpadIconSize,
            launchpadColumnSpacing: launchpadColumnSpacing,
            launchpadRowSpacing: launchpadRowSpacing
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    func performAutoBackup() {
        guard autoBackupEnabled, let folder = autoBackupFolder else { return }
        do {
            let data = try exportBackup()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let filename = "PKwindowsManagement-backup-\(formatter.string(from: Date())).json"
            let url = folder.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("PKwindowsManagement: auto-backup failed: %@", error.localizedDescription)
        }
    }

    func scheduleAutoBackup() {
        backupDebounceTimer?.invalidate()
        backupDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.performAutoBackup()
        }
    }

    func importBackup(_ data: Data) throws {
        let backup = try JSONDecoder().decode(SettingsBackup.self, from: data)
        guard backup.version == 1 || backup.version == 2 || backup.version == 3 || backup.version == 4 || backup.version == 5 else { throw SettingsBackupError.unsupportedVersion }

        shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { action in
            (action, backup.windowShortcuts[action.rawValue] ?? action.defaultShortcut)
        })
        launchShortcuts = backup.launchShortcuts
        snippets = backup.snippets ?? []
        if snippets.isEmpty && backup.version == 1 {
            snippets = Self.defaultSnippets()
        }
        recentBundleIDs = backup.recentBundleIDs
        clipboardDrawerEdge = backup.clipboardDrawerEdge
        launchpadShortcut = backup.launchpadShortcut
        launchpadHotCorner = backup.launchpadHotCorner
        launchpadGridColumns = backup.launchpadGridColumns
        launchpadGridRows = backup.launchpadGridRows
        launchpadDisplayProfiles = backup.launchpadDisplayProfiles?.map { $0.clamped() } ?? []
        launchpadGridNavigation = backup.launchpadGridNavigation
        launchpadIconSize = backup.launchpadIconSize ?? 48
        launchpadColumnSpacing = backup.launchpadColumnSpacing ?? 16
        launchpadRowSpacing = backup.launchpadRowSpacing ?? 12

        saveShortcuts()
        saveLaunchShortcuts()
        saveSnippets()
        saveLaunchpadDisplayProfiles()
        defaults.set(recentBundleIDs, forKey: Keys.launchRecents)
    }

    private func saveShortcuts() {
        let rawShortcuts = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(rawShortcuts) else { return }
        defaults.set(data, forKey: Keys.shortcuts)
        scheduleAutoBackup()
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
        scheduleAutoBackup()
    }

    private func saveSnippets() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        defaults.set(data, forKey: Keys.snippets)
        scheduleAutoBackup()
    }

    private func saveLaunchpadDisplayProfiles() {
        guard let data = try? JSONEncoder().encode(launchpadDisplayProfiles) else { return }
        defaults.set(data, forKey: Keys.launchpadDisplayProfiles)
        scheduleAutoBackup()
    }

    private func saveLaunchpadShortcut() {
        guard let data = try? JSONEncoder().encode(launchpadShortcut) else { return }
        defaults.set(data, forKey: Keys.launchpadShortcut)
        scheduleAutoBackup()
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

    private static func loadSnippets(from defaults: UserDefaults) -> [SnippetDefinition] {
        guard let data = defaults.data(forKey: Keys.snippets),
              let snippets = try? JSONDecoder().decode([SnippetDefinition].self, from: data)
        else { return [] }
        return snippets
    }

    private func seedDefaultSnippetShortcuts() {
        guard defaults.object(forKey: Keys.snippets) == nil else { return }

        let defaultsByID: [String: KeyboardShortcutSetting] = Dictionary(uniqueKeysWithValues: Self.defaultSnippets().map {
            ($0.id, Self.defaultShortcut(forSnippetID: $0.id))
        })

        var changed = false
        for (id, shortcut) in defaultsByID where launchShortcuts[id] == nil {
            launchShortcuts[id] = shortcut
            changed = true
        }

        if changed {
            saveLaunchShortcuts()
        }
    }

    private static func defaultSnippets() -> [SnippetDefinition] {
        [
            SnippetDefinition(
                id: "snippet.finder",
                title: "Finder",
                body: "open -a Finder",
                isEnabled: true
            ),
            SnippetDefinition(
                id: "snippet.applications",
                title: "Applications",
                body: "open -a Finder /Applications",
                isEnabled: true
            ),
            SnippetDefinition(
                id: "snippet.home",
                title: "Home",
                body: "open -a Finder ~",
                isEnabled: true
            ),
            SnippetDefinition(
                id: "snippet.documents",
                title: "Documents",
                body: "open -a Finder ~/Documents",
                isEnabled: true
            )
        ]
    }

    private static func defaultShortcut(forSnippetID id: String) -> KeyboardShortcutSetting {
        switch id {
        case "snippet.finder": .init(key: "f", modifier: .rightCommand)
        case "snippet.applications": .init(key: "a", modifier: .rightCommand)
        case "snippet.home": .init(key: "h", modifier: .rightCommand)
        case "snippet.documents": .init(key: "d", modifier: .rightCommand)
        default: .init(key: "s", modifier: .command)
        }
    }

    private static func loadLaunchpadDisplayProfiles(from defaults: UserDefaults) -> [LaunchpadDisplayProfile] {
        guard let data = defaults.data(forKey: Keys.launchpadDisplayProfiles),
              let profiles = try? JSONDecoder().decode([LaunchpadDisplayProfile].self, from: data)
        else { return [] }
        return profiles.map { $0.clamped() }
    }
}

private struct SettingsBackup: Codable {
    let version: Int
    let windowShortcuts: [String: KeyboardShortcutSetting]
    let launchShortcuts: [String: KeyboardShortcutSetting]
    let snippets: [SnippetDefinition]?
    let recentBundleIDs: [String]
    let clipboardDrawerEdge: ClipboardDrawerEdge
    let launchpadShortcut: KeyboardShortcutSetting
    let launchpadHotCorner: LaunchpadHotCorner
    let launchpadGridColumns: Int
    let launchpadGridRows: Int
    let launchpadDisplayProfiles: [LaunchpadDisplayProfile]?
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

struct LaunchpadGridConfiguration {
    let columns: Int
    let rows: Int
}

struct LaunchpadDisplayProfile: Codable, Equatable, Hashable, Identifiable {
    let displayID: CGDirectDisplayID
    var displayName: String
    var columns: Int
    var rows: Int

    var id: CGDirectDisplayID { displayID }

    func clamped() -> LaunchpadDisplayProfile {
        .init(
            displayID: displayID,
            displayName: displayName,
            columns: min(max(columns, 4), 20),
            rows: min(max(rows, 3), 20)
        )
    }
}
