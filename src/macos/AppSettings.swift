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
        static let launchpadStyle = "launchpad-style"
        static let compactLaunchpadTheme = "compact-launchpad-theme"
        static let launchpadAppSortMode = "launchpad-app-sort-mode"
        static let launchpadIconSize = "launchpad-icon-size"
        static let launchpadColumnSpacing = "launchpad-column-spacing"
        static let launchpadRowSpacing = "launchpad-row-spacing"
        static let autoBackupFolder = "auto-backup-folder"
        static let autoBackupEnabled = "auto-backup-enabled"
        static let appLanguage = AppLocalization.defaultsKey
        static let windowMarginGeneral = "window-margin-general"
        static let windowMarginAlmost = "window-margin-almost"
        static let windowMarginCenter = "window-margin-center"
        static let clearedWindowShortcuts = "cleared-window-shortcuts"
        static let archiveSnippetMigration = "migrated-snippet-archive-v1"
        static let archiveSnippetBodyMigration = "migrated-snippet-archive-body-v7"
        static let archiveDuplicateMigration = "migrated-snippet-archive-dedup-v3"
        static let downloadsToDesktopSnippetMigration = "migrated-snippet-dl2desk-v1"
        static let windowShortcutDefaultsVersion = "window-shortcut-defaults-v5"
        static let bigYearBirthdays = "big-year-birthdays"
        static let bigYearSchoolZone = "big-year-school-zone"
    }

    private let defaults: UserDefaults
    private var backupDebounceTimer: Timer?

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcutSetting]
    @Published private(set) var clearedWindowShortcuts: [String]

    @Published var clipboardDrawerEdge: ClipboardDrawerEdge {
        didSet { defaults.set(clipboardDrawerEdge.rawValue, forKey: Keys.clipboardDrawerEdge) }
    }

    @Published private(set) var recentBundleIDs: [String]
    @Published private(set) var launchShortcuts: [String: KeyboardShortcutSetting]
    @Published private(set) var snippets: [SnippetDefinition]
    @Published private(set) var launchpadDisplayProfiles: [LaunchpadDisplayProfile]
    @Published var launchpadAppSortMode: LaunchpadAppSortMode {
        didSet { defaults.set(launchpadAppSortMode.rawValue, forKey: Keys.launchpadAppSortMode) }
    }
    @Published var launchpadShortcut: KeyboardShortcutSetting {
        didSet {
            saveLaunchpadShortcut()
            NotificationCenter.default.post(name: .launchpadHotKeyDidChange, object: nil)
        }
    }
    @Published var launchpadHotCorner: LaunchpadHotCorner {
        didSet {
            defaults.set(launchpadHotCorner.rawValue, forKey: Keys.launchpadHotCorner)
            NotificationCenter.default.post(name: .launchpadHotCornerDidChange, object: nil)
        }
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
    @Published var launchpadStyle: LaunchpadStyle {
        didSet { defaults.set(launchpadStyle.rawValue, forKey: Keys.launchpadStyle) }
    }
    @Published var compactLaunchpadTheme: CompactLaunchpadTheme {
        didSet { defaults.set(compactLaunchpadTheme.rawValue, forKey: Keys.compactLaunchpadTheme) }
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
    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            NotificationCenter.default.post(name: .appLanguageDidChange, object: appLanguage)
            scheduleAutoBackup()
        }
    }

    @Published var generalMargins: WindowMargins {
        didSet { saveMargins(generalMargins, forKey: Keys.windowMarginGeneral) }
    }

    @Published var almostFullMargins: WindowMargins {
        didSet { saveMargins(almostFullMargins, forKey: Keys.windowMarginAlmost) }
    }

    @Published var centerMargins: WindowMargins {
        didSet { saveMargins(centerMargins, forKey: Keys.windowMarginCenter) }
    }

    @Published var bigYearBirthdays: String {
        didSet { defaults.set(bigYearBirthdays, forKey: Keys.bigYearBirthdays) }
    }

    @Published var bigYearSchoolZone: String {
        didSet { defaults.set(bigYearSchoolZone, forKey: Keys.bigYearSchoolZone) }
    }

    var windowMarginPreset: WindowMarginPreset {
        .init(general: generalMargins, almostFull: almostFullMargins, center: centerMargins)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let edgeRaw = defaults.string(forKey: Keys.clipboardDrawerEdge) ?? ClipboardDrawerEdge.top.rawValue
        clipboardDrawerEdge = ClipboardDrawerEdge(rawValue: edgeRaw) ?? .top
        shortcuts = Self.loadShortcuts(from: defaults)
        clearedWindowShortcuts = defaults.stringArray(forKey: Keys.clearedWindowShortcuts) ?? []
        recentBundleIDs = defaults.stringArray(forKey: Keys.launchRecents) ?? []
        let loadedLaunchShortcuts = Self.loadLaunchShortcuts(from: defaults)
        launchShortcuts = loadedLaunchShortcuts
        let hadStoredSnippets = defaults.object(forKey: Keys.snippets) != nil
        let loadedSnippets = Self.loadSnippets(from: defaults)
        let shouldSeedDefaultSnippets = !hadStoredSnippets && loadedSnippets.isEmpty
        var migratedSnippets = shouldSeedDefaultSnippets ? Self.defaultSnippets() : loadedSnippets
        var migratedLaunchShortcuts = loadedLaunchShortcuts
        let archiveResult = Self.ensureArchiveSnippet(
            in: migratedSnippets,
            defaults: defaults,
            launchShortcuts: &migratedLaunchShortcuts
        )
        migratedSnippets = archiveResult.snippets
        let archiveMergeResult = Self.mergeArchiveDuplicates(
            in: migratedSnippets,
            defaults: defaults,
            launchShortcuts: &migratedLaunchShortcuts
        )
        migratedSnippets = archiveMergeResult.snippets
        let downloadsResult = Self.ensureDownloadsToDesktopSnippet(
            in: migratedSnippets,
            defaults: defaults,
            launchShortcuts: &migratedLaunchShortcuts
        )
        migratedSnippets = downloadsResult.snippets
        snippets = migratedSnippets
        let launchShortcutsChanged = migratedLaunchShortcuts != loadedLaunchShortcuts
        if launchShortcutsChanged {
            launchShortcuts = migratedLaunchShortcuts
        }
        launchpadDisplayProfiles = Self.loadLaunchpadDisplayProfiles(from: defaults)
        let sortModeRaw = defaults.string(forKey: Keys.launchpadAppSortMode) ?? LaunchpadAppSortMode.recent.rawValue
        launchpadAppSortMode = LaunchpadAppSortMode(rawValue: sortModeRaw) ?? .recent
        launchpadShortcut = Self.loadLaunchpadShortcut(from: defaults)
        let hotCornerRaw = defaults.string(forKey: Keys.launchpadHotCorner) ?? LaunchpadHotCorner.topLeft.rawValue
        launchpadHotCorner = LaunchpadHotCorner(rawValue: hotCornerRaw) ?? .topLeft
        launchpadGridColumns = min(max(defaults.object(forKey: Keys.launchpadGridColumns) as? Int ?? 7, 4), 20)
        launchpadGridRows = min(max(defaults.object(forKey: Keys.launchpadGridRows) as? Int ?? 5, 3), 20)
        let navigationRaw = defaults.string(forKey: Keys.launchpadGridNavigation) ?? LaunchpadGridNavigation.vertical.rawValue
        launchpadGridNavigation = LaunchpadGridNavigation(rawValue: navigationRaw) ?? .vertical
        let styleRaw = defaults.string(forKey: Keys.launchpadStyle) ?? LaunchpadStyle.fullscreen.rawValue
        launchpadStyle = LaunchpadStyle(rawValue: styleRaw) ?? .fullscreen
        let themeRaw = defaults.string(forKey: Keys.compactLaunchpadTheme) ?? CompactLaunchpadTheme.dark.rawValue
        compactLaunchpadTheme = CompactLaunchpadTheme(rawValue: themeRaw) ?? .dark
        launchpadIconSize = min(max(defaults.object(forKey: Keys.launchpadIconSize) as? Int ?? 48, 28), 96)
        launchpadColumnSpacing = min(max(defaults.object(forKey: Keys.launchpadColumnSpacing) as? Int ?? 16, 4), 48)
        launchpadRowSpacing = min(max(defaults.object(forKey: Keys.launchpadRowSpacing) as? Int ?? 12, 4), 48)
        if let folderPath = defaults.string(forKey: Keys.autoBackupFolder) {
            autoBackupFolder = URL(fileURLWithPath: folderPath)
        } else {
            autoBackupFolder = nil
        }
        autoBackupEnabled = defaults.bool(forKey: Keys.autoBackupEnabled)
        let languageRaw = defaults.string(forKey: Keys.appLanguage) ?? AppLanguage.system.rawValue
        appLanguage = AppLanguage(rawValue: languageRaw) ?? .system
        generalMargins = Self.loadMargins(Keys.windowMarginGeneral, from: defaults, fallback: .init(top: 1, bottom: 1, left: 1, right: 1))
        almostFullMargins = Self.loadMargins(Keys.windowMarginAlmost, from: defaults, fallback: .init(top: 10, bottom: 10, left: 10, right: 10))
        centerMargins = Self.loadMargins(Keys.windowMarginCenter, from: defaults, fallback: .zero)
        bigYearBirthdays = defaults.string(forKey: Keys.bigYearBirthdays) ?? ""
        bigYearSchoolZone = defaults.string(forKey: Keys.bigYearSchoolZone) ?? "A"

        if shouldSeedDefaultSnippets || archiveResult.didChange || archiveMergeResult.didChange || downloadsResult.didChange {
            saveSnippets()
        }
        if launchShortcutsChanged {
            saveLaunchShortcuts()
        }
        seedDefaultSnippetShortcuts()

        if defaults.bool(forKey: Keys.windowShortcutDefaultsVersion) == false {
            shortcuts = Self.defaultShortcuts()
            saveShortcuts()
            defaults.set(true, forKey: Keys.windowShortcutDefaultsVersion)
        }
    }

    private static func ensureArchiveSnippet(
        in snippets: [SnippetDefinition],
        defaults: UserDefaults,
        launchShortcuts: inout [String: KeyboardShortcutSetting]
    ) -> (snippets: [SnippetDefinition], didChange: Bool) {
        guard let archiveDefault = defaultSnippets().first(where: { $0.id == SnippetDefinition.archiveID }) else {
            return (snippets, false)
        }
        let canonicalID = SnippetDefinition.archiveID

        if let index = snippets.firstIndex(where: { $0.id == canonicalID }) {
            guard !defaults.bool(forKey: Keys.archiveSnippetBodyMigration) else {
                return (snippets, false)
            }
            var result = snippets
            let didChangeBody = result[index].body != archiveDefault.body
            if didChangeBody {
                result[index].body = archiveDefault.body
            }
            defaults.set(true, forKey: Keys.archiveSnippetBodyMigration)
            return (result, didChangeBody)
        }

        if let manualIndex = snippets.firstIndex(where: {
            $0.kind == .script
                && $0.id != canonicalID
                && $0.title.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Archive") == .orderedSame
        }) {
            var result = snippets
            let oldID = result[manualIndex].id
            var adopted = archiveDefault
            adopted.isEnabled = result[manualIndex].isEnabled
            result[manualIndex] = adopted
            if let sc = launchShortcuts[oldID] {
                launchShortcuts[canonicalID] = sc
                launchShortcuts.removeValue(forKey: oldID)
            } else if launchShortcuts[canonicalID] == nil {
                launchShortcuts[canonicalID] = defaultShortcut(forSnippetID: canonicalID)
            }
            defaults.set(true, forKey: Keys.archiveSnippetMigration)
            defaults.set(true, forKey: Keys.archiveSnippetBodyMigration)
            return (result, true)
        }

        guard !defaults.bool(forKey: Keys.archiveSnippetMigration) else {
            return (snippets, false)
        }

        var result = snippets
        if let documentsIndex = result.lastIndex(where: { $0.id == "snippet.documents" && $0.kind == .script }) {
            result.insert(archiveDefault, at: documentsIndex + 1)
        } else {
            result.append(archiveDefault)
        }
        defaults.set(true, forKey: Keys.archiveSnippetMigration)
        defaults.set(true, forKey: Keys.archiveSnippetBodyMigration)
        if launchShortcuts[canonicalID] == nil {
            launchShortcuts[canonicalID] = defaultShortcut(forSnippetID: canonicalID)
        }
        return (result, true)
    }

    private static func mergeArchiveDuplicates(
        in snippets: [SnippetDefinition],
        defaults: UserDefaults,
        launchShortcuts: inout [String: KeyboardShortcutSetting]
    ) -> (snippets: [SnippetDefinition], didChange: Bool) {
        guard !defaults.bool(forKey: Keys.archiveDuplicateMigration) else {
            return (snippets, false)
        }
        defaults.set(true, forKey: Keys.archiveDuplicateMigration)

        let canonicalID = SnippetDefinition.archiveID
        guard snippets.contains(where: { $0.id == canonicalID }) else {
            return (snippets, false)
        }

        var result = snippets
        var indexesToRemove: [Int] = []
        var didChange = false

        for (index, snippet) in result.enumerated() {
            guard snippet.kind == .script,
                  snippet.id != canonicalID,
                  snippet.title.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Archive") == .orderedSame
            else { continue }
            if let dupShortcut = launchShortcuts[snippet.id] {
                launchShortcuts[canonicalID] = dupShortcut
            }
            launchShortcuts.removeValue(forKey: snippet.id)
            indexesToRemove.append(index)
            didChange = true
        }

        guard !indexesToRemove.isEmpty else { return (result, didChange) }
        for index in indexesToRemove.sorted(by: >) {
            result.remove(at: index)
        }
        return (result, didChange)
    }

    private static func ensureDownloadsToDesktopSnippet(
        in snippets: [SnippetDefinition],
        defaults: UserDefaults,
        launchShortcuts: inout [String: KeyboardShortcutSetting]
    ) -> (snippets: [SnippetDefinition], didChange: Bool) {
        guard !defaults.bool(forKey: Keys.downloadsToDesktopSnippetMigration),
              let defaultSnippet = defaultSnippets().first(where: { $0.id == SnippetDefinition.downloadsToDesktopID }),
              !snippets.contains(where: { $0.id == SnippetDefinition.downloadsToDesktopID })
        else {
            return (snippets, false)
        }

        var result = snippets
        if let archiveIndex = result.firstIndex(where: { $0.id == SnippetDefinition.archiveID }) {
            result.insert(defaultSnippet, at: archiveIndex + 1)
        } else {
            result.append(defaultSnippet)
        }
        defaults.set(true, forKey: Keys.downloadsToDesktopSnippetMigration)
        if launchShortcuts[SnippetDefinition.downloadsToDesktopID] == nil {
            launchShortcuts[SnippetDefinition.downloadsToDesktopID] = defaultShortcut(forSnippetID: SnippetDefinition.downloadsToDesktopID)
        }
        return (result, true)
    }

    func shortcut(for action: ShortcutAction) -> KeyboardShortcutSetting? {
        if clearedWindowShortcuts.contains(action.rawValue) { return nil }
        return shortcuts[action] ?? action.defaultShortcut
    }

    func setShortcut(_ shortcut: KeyboardShortcutSetting, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        clearedWindowShortcuts.removeAll { $0 == action.rawValue }
        saveShortcuts()
        saveClearedShortcuts()
    }

    func resetShortcut(for action: ShortcutAction) {
        if let defaultShortcut = action.defaultShortcut {
            shortcuts[action] = defaultShortcut
        } else {
            shortcuts.removeValue(forKey: action)
        }
        clearedWindowShortcuts.removeAll { $0 == action.rawValue }
        saveShortcuts()
        saveClearedShortcuts()
    }

    func clearShortcut(for action: ShortcutAction) {
        if !clearedWindowShortcuts.contains(action.rawValue) {
            clearedWindowShortcuts.append(action.rawValue)
            saveClearedShortcuts()
        }
    }

    private func saveClearedShortcuts() {
        defaults.set(clearedWindowShortcuts, forKey: Keys.clearedWindowShortcuts)
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

    func addSnippet(_ snippet: SnippetDefinition = SnippetDefinition(title: localizedString("New Snippet"), body: "")) -> SnippetDefinition {
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
            version: 8,
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
            launchpadAppSortMode: launchpadAppSortMode,
            launchpadIconSize: launchpadIconSize,
            launchpadColumnSpacing: launchpadColumnSpacing,
            launchpadRowSpacing: launchpadRowSpacing,
            appLanguage: appLanguage,
            bigYearBirthdays: bigYearBirthdays,
            bigYearSchoolZone: bigYearSchoolZone
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
        guard (1...8).contains(backup.version) else { throw SettingsBackupError.unsupportedVersion }

        shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.compactMap { action in
            backup.windowShortcuts[action.rawValue].map { (action, $0) } ?? action.defaultShortcut.map { (action, $0) }
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
        launchpadAppSortMode = backup.launchpadAppSortMode ?? .recent
        launchpadIconSize = backup.launchpadIconSize ?? 48
        launchpadColumnSpacing = backup.launchpadColumnSpacing ?? 16
        launchpadRowSpacing = backup.launchpadRowSpacing ?? 12
        appLanguage = backup.appLanguage ?? appLanguage
        bigYearBirthdays = backup.bigYearBirthdays ?? bigYearBirthdays
        bigYearSchoolZone = backup.bigYearSchoolZone ?? bigYearSchoolZone

        saveShortcuts()
        clearedWindowShortcuts = []
        saveClearedShortcuts()
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

    private static func defaultShortcuts() -> [ShortcutAction: KeyboardShortcutSetting] {
        Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.compactMap { action in
            action.defaultShortcut.map { (action, $0) }
        })
    }

    private static func loadShortcuts(from defaults: UserDefaults) -> [ShortcutAction: KeyboardShortcutSetting] {
        var shortcuts = Self.defaultShortcuts()
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

    private static func loadMargins(_ key: String, from defaults: UserDefaults, fallback: WindowMargins) -> WindowMargins {
        guard let data = defaults.data(forKey: key),
              let margins = try? JSONDecoder().decode(WindowMargins.self, from: data)
        else { return fallback }
        return margins
    }

    private func saveMargins(_ margins: WindowMargins, forKey key: String) {
        if let data = try? JSONEncoder().encode(margins) {
            defaults.set(data, forKey: key)
        }
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
            ),
            SnippetDefinition(
                id: SnippetDefinition.downloadsToDesktopID,
                title: "DL2desk",
                body: """
                #!/bin/bash
                set -euo pipefail

                SOURCE_DIR="$HOME/Downloads"
                DEST_DIR="$HOME/Desktop"

                unique_dest() {
                  local dir="$1" filename="$2" base ext counter=2 candidate
                  if [[ "$filename" == *.* ]]; then
                    base="${filename%.*}"
                    ext=".${filename##*.}"
                  else
                    base="$filename"
                    ext=""
                  fi
                  candidate="${dir}/${filename}"
                  while [[ -e "$candidate" || -L "$candidate" ]]; do
                    candidate="${dir}/${base} ${counter}${ext}"
                    counter=$((counter + 1))
                  done
                  printf '%s' "$candidate"
                }

                moved=0
                shopt -s nullglob dotglob
                for item in "$SOURCE_DIR"/*; do
                  name="$(basename "$item")"
                  [[ "$name" == ".DS_Store" ]] && continue
                  [[ "$name" == *.tmp || "$name" == *.crdownload || "$name" == *.download ]] && continue
                  dest="$(unique_dest "$DEST_DIR" "$name")"
                  mv "$item" "$dest"
                  moved=$((moved + 1))
                done

                echo "Déplacé : ${moved} élément(s) -> ${DEST_DIR}"
                """,
                isEnabled: true
            ),
            SnippetDefinition(
                id: "snippet.archive",
                title: "Archive",
                body: """
                #!/bin/bash
                set -euo pipefail

                # ═══════════════════════════════════════════════════
                # CONFIGURATION
                # ═══════════════════════════════════════════════════
                SOURCE_DIR="$HOME/Desktop"
                # Archive locale : un mv sur le même disque est instantané (renommage),
                # même pour de gros dossiers. Rien n'est jamais ignoré, le Mac ne fige pas.
                LOCAL_ARCHIVE_BASE="$HOME/.pk-desktoparchive"
                # Recopie en arrière-plan vers le cloud (0 = désactivée).
                CLOUD_SYNC_ENABLED=1
                CLOUD_BWLIMIT_KB=4000          # débit max (Ko/s) pour ménager le montage cloud
                DEST_BASE_DIR=""               # vide = auto-détection Google Drive
                # ═══════════════════════════════════════════════════

                unique_dest() {
                  local dir="$1" filename="$2" base ext counter=2 candidate
                  if [[ "$filename" == *.* ]]; then
                    base="${filename%.*}"
                    ext=".${filename##*.}"
                  else
                    base="$filename"
                    ext=""
                  fi
                  candidate="${dir}/${filename}"
                  while [[ -e "$candidate" || -L "$candidate" ]]; do
                    candidate="${dir}/${base} ${counter}${ext}"
                    counter=$((counter + 1))
                  done
                  printf '%s' "$candidate"
                }

                resolve_cloud_path() {
                  local preferred legacy subs mount sub out=""
                  if [[ -n "$DEST_BASE_DIR" ]]; then
                    out="$DEST_BASE_DIR"
                  elif [[ -n "${ARCHIVE_PATH:-}" ]]; then
                    out="$ARCHIVE_PATH"
                  else
                    preferred="$HOME/Cloud.noindex/Google Drive.localized"
                    legacy="$HOME/Library/Application Support/Mountain Duck/Volumes.noindex"
                    subs=("# BACKUPS" "My Drive/# BACKUPS" "Mon Drive/# BACKUPS")
                    mount=""
                    if [[ -d "$preferred" ]]; then
                      mount="$preferred"
                    elif [[ -d "$legacy" ]]; then
                      for c in "$legacy"/*Google\\ Drive* "$legacy"/*Drive* "$legacy"/*/*.localized; do
                        [[ -d "$c" ]] && mount="$c" && break
                      done
                    fi
                    if [[ -n "$mount" ]]; then
                      for sub in "${subs[@]}"; do
                        if [[ -d "${mount}/${sub}" ]]; then
                          out="${mount}/${sub}/DesktopArchive"
                          break
                        fi
                      done
                    fi
                  fi
                  printf '%s' "$out"
                }

                SOURCE_NAME="$(basename "$SOURCE_DIR")"
                LINK_NAME="${SOURCE_NAME}Archive"
                LINK_PATH="${SOURCE_DIR}/${LINK_NAME}"
                month_number="$(date +%m)"
                year_number="$(date +%Y)"
                case "$month_number" in
                  01) month_name="janvier" ;;
                  02) month_name="février" ;;
                  03) month_name="mars" ;;
                  04) month_name="avril" ;;
                  05) month_name="mai" ;;
                  06) month_name="juin" ;;
                  07) month_name="juillet" ;;
                  08) month_name="août" ;;
                  09) month_name="septembre" ;;
                  10) month_name="octobre" ;;
                  11) month_name="novembre" ;;
                  12) month_name="décembre" ;;
                esac
                month_label="${year_number}_${month_number}_${month_name}"

                mkdir -p "$LOCAL_ARCHIVE_BASE"
                local_month="$LOCAL_ARCHIVE_BASE/$month_label"
                mkdir -p "$local_month"

                cloud_path=""
                if [[ "$CLOUD_SYNC_ENABLED" == "1" ]]; then
                  cloud_path="$(resolve_cloud_path)"
                  [[ -n "$cloud_path" ]] && mkdir -p "$cloud_path"
                fi

                # 1) ARCHIVAGE LOCAL — instantané (même volume = renommage), rien ignoré.
                moved=0
                shopt -s nullglob
                for file in "${SOURCE_DIR}"/*; do
                  [[ "$(basename "$file")" == "$LINK_NAME" ]] && continue
                  tags=$(mdls -name kMDItemUserTags -raw "$file" 2>/dev/null || true)
                  [[ -n "$tags" && "$tags" == *"Bureau"* ]] && continue
                  filename="$(basename "$file")"
                  dest="$(unique_dest "$local_month" "$filename")"
                  mv "$file" "$dest"
                  moved=$((moved + 1))
                done

                # 2) Raccourci Bureau -> archive cloud si détectée, sinon archive locale.
                if [[ -e "$LINK_PATH" && ! -L "$LINK_PATH" ]]; then
                  mv "$LINK_PATH" "${LINK_PATH}.local-backup-$(date +%Y%m%d-%H%M%S)"
                fi
                link_target="$LOCAL_ARCHIVE_BASE"
                [[ -n "$cloud_path" ]] && link_target="$cloud_path"
                ln -sfn "$link_target" "$LINK_PATH"

                # 3) Recopie en arrière-plan vers Google Drive (throttée, non bloquante).
                if [[ -n "$cloud_path" ]]; then
                  nohup nice -n 19 rsync -a --update --bwlimit="$CLOUD_BWLIMIT_KB" \
                    "$LOCAL_ARCHIVE_BASE/" "$cloud_path/" >/dev/null 2>&1 &
                  disown 2>/dev/null || true
                fi

                echo "Archivé : ${moved} élément(s) -> ${local_month}"
                """,
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
        case SnippetDefinition.downloadsToDesktopID: .init(key: "l", modifier: .rightCommand)
        case "snippet.archive": .init(key: "r", modifier: .rightCommand)
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
    let launchpadAppSortMode: LaunchpadAppSortMode?
    let launchpadIconSize: Int?
    let launchpadColumnSpacing: Int?
    let launchpadRowSpacing: Int?
    let appLanguage: AppLanguage?
    let bigYearBirthdays: String?
    let bigYearSchoolZone: String?
}

enum SettingsBackupError: LocalizedError {
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: localizedString("This settings backup version is not supported.")
        }
    }
}

enum LaunchpadGridNavigation: String, CaseIterable, Identifiable, Codable {
    case vertical
    case horizontalPages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: localizedString("Vertical Scroll")
        case .horizontalPages: localizedString("Horizontal Pages")
        }
    }
}

enum LaunchpadStyle: String, CaseIterable, Identifiable, Codable {
    case fullscreen
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullscreen: localizedString("Fullscreen")
        case .compact: localizedString("Compact")
        }
    }
}

enum CompactLaunchpadTheme: String, CaseIterable, Identifiable, Codable {
    case light
    case dark
    case catpuccin
    case glass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: localizedString("Light")
        case .dark: localizedString("Dark")
        case .catpuccin: localizedString("Catpuccin")
        case .glass: localizedString("Glass")
        }
    }
}

enum LaunchpadAppSortMode: String, CaseIterable, Identifiable, Codable {
    case recent
    case name
    case color

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: localizedString("Last Used")
        case .name: localizedString("Name")
        case .color: localizedString("Icon Color")
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
        case .disabled: localizedString("Disabled")
        case .topLeft: localizedString("Top Left")
        case .topRight: localizedString("Top Right")
        case .bottomLeft: localizedString("Bottom Left")
        case .bottomRight: localizedString("Bottom Right")
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
