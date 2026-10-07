import SwiftUI

@main
struct PKwindowsManagementApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController
    @StateObject private var settings: AppSettings

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        AppRuntime.shared.settings = settings

        let launcher = AppLauncherService()
        launcher.prewarmApps(settings: settings)
        launcher.refreshURLSnippetIcons(settings: settings)
        LaunchShortcutMonitor.shared.start(
            settings: settings,
            apps: launcher.loadShortcutTargets(settings: settings),
            launchHandler: { app in _ = launcher.launch(app, settings: settings) },
            windowHandler: { action in WindowSnapService().perform(action, preset: settings.windowMarginPreset) }
        )
    }

    var body: some Scene {
        WindowGroup("PKwindowsManagement", id: "settings") {
            RootDashboardView(settings: settings)
                .frame(minWidth: 900, minHeight: 620)
                .environment(\.locale, settings.appLanguage.locale)
                .id(settings.appLanguage)
                .onChange(of: settings.snippets) { _ in
                    let launcher = AppLauncherService()
                    launcher.refreshURLSnippetIcons(settings: settings)
                    let apps = launcher.loadShortcutTargets(settings: settings)
                    LaunchShortcutMonitor.shared.refreshApps(apps)
                }
                .onChange(of: settings.launchShortcuts) { _ in
                    let launcher = AppLauncherService()
                    let apps = launcher.loadShortcutTargets(settings: settings)
                    LaunchShortcutMonitor.shared.refreshApps(apps)
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(localizedString("Settings...")) {
                    LaunchpadOverlayController.shared.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

private struct RootDashboardView: View {
    @ObservedObject var settings: AppSettings
    @State private var selection: SettingsSection? = .general

    static var appIcon: NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        return NSImage(named: "AppIcon")
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .background(.regularMaterial)

            Divider()

            Group {
                switch selection ?? .general {
                case .general:
                    GeneralSettingsView(settings: settings)
                case .windows:
                    WindowShortcutsPreferencesView(settings: settings)
                case .launchpad:
                    LaunchpadView(settings: settings)
                case .appearance:
                    AppearanceSettingsView(settings: settings)
                case .bigYear:
                    BigYearSettingsView(settings: settings)
                case .snippets:
                    SnippetsSettingsView(settings: settings)
                case .urls:
                    URLSnippetsSettingsView(settings: settings)
                case .ai:
                    AISettingsView()
                case .support:
                    SupportSettingsView()
                case .library:
                    ProjectLibraryView()
                case .about:
                    AboutSettingsView()
                case .credits:
                    CreditsInspirationsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Sidebar (PKMonitor pattern: header, search, grouped rows)

    @State private var searchText = ""

    private var filteredSections: [SettingsSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return SettingsSection.allCases }
        return SettingsSection.allCases.filter { $0.keywords.contains(query) }
    }

    private var groupedSections: [(String, [SettingsSection])] {
        let grouped = Dictionary(grouping: filteredSections, by: \.category)
        return SettingsSection.categoryOrder.compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            return (key, values)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let icon = Self.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("PKwindowsManagement")
                        .font(.headline)
                    Text(localizedString("Window management"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Text(localizedString("Settings").uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(localizedString("Search settings"), text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if let first = filteredSections.first { selection = first }
                    }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            VStack(spacing: 3) {
                ForEach(groupedSections, id: \.0) { group, sections in
                    Text(group.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    ForEach(sections) { section in
                        sidebarRow(section)
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach([AppLanguage.french, .english, .spanish, .german]) { language in
                    languageFlag(language)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Text(appVersionLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
    }

    private func isActiveLanguage(_ language: AppLanguage) -> Bool {
        if settings.appLanguage == .system {
            return settings.appLanguage.resolvedCode == language.rawValue
        }
        return settings.appLanguage == language
    }

    private func languageFlag(_ language: AppLanguage) -> some View {
        Button {
            settings.appLanguage = language
        } label: {
            Text(language.flagEmoji)
                .font(.system(size: 15))
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActiveLanguage(language) ? Color.accentColor.opacity(0.15) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isActiveLanguage(language) ? Color.accentColor : .clear, lineWidth: 1)
                )
                .opacity(isActiveLanguage(language) ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .help(language.displayName)
    }

    private func sidebarRow(_ section: SettingsSection) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 11) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(section.iconTint ?? (selection == section ? Color.primary : Color.secondary))
                Text(section.title)
                    .font(.system(size: 13, weight: selection == section ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(selection == section ? .primary : .secondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                selection == section ? Color.accentColor.opacity(0.13) : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }

    private var appVersionLabel: String {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "v\(raw)"
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case windows
    case launchpad
    case appearance
    case bigYear
    case snippets
    case urls
    case ai
    case credits
    case library
    case support
    case about

    var id: String { rawValue }

    /// Sidebar grouping; Apparence sits right after Launchpad because it is
    /// the Launchpad's appearance.
    static let categoryOrder = ["APP", "FEATURES", "AI", "PK PROJECTS"]

    var category: String {
        switch self {
        case .general: "APP"
        case .windows, .launchpad, .appearance, .bigYear, .snippets, .urls: "FEATURES"
        case .ai: "AI"
        case .library, .support, .about, .credits: "PK PROJECTS"
        }
    }

    var categoryLabel: String {
        switch category {
        case "APP": localizedString("App")
        case "FEATURES": localizedString("Features")
        case "AI": localizedString("Local AI")
        default: localizedString("PK Projects")
        }
    }

    var keywords: String {
        "\(title) \(rawValue) \(categoryLabel)".lowercased()
    }

    var title: String {
        switch self {
        case .general: localizedString("General")
        case .windows: localizedString("Windows")
        case .launchpad: "Launchpad"
        case .bigYear: "Big Year"
        case .appearance: localizedString("Appearance")
        case .snippets: localizedString("Snippets")
        case .urls: "URLs"
        case .ai: localizedString("Local AI")
        case .library: localizedString("Project Library")
        case .support: localizedString("Support")
        case .about: localizedString("About")
        case .credits: localizedString("Credits & inspirations")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .windows: "rectangle.split.2x1"
        case .launchpad: "rectangle.3.group"
        case .bigYear: "calendar"
        case .appearance: "paintbrush"
        case .snippets: "doc.on.doc"
        case .urls: "link"
        case .ai: "sparkles"
        case .support: "heart.fill"
        case .library: "square.grid.2x2"
        case .about: "info.circle"
        case .credits: "text.quote"
        }
    }

    var iconTint: Color? {
        switch self {
        case .support: Color(red: 1.0, green: 0.37, blue: 0.36)
        case .about: .accentColor
        default: nil
        }
    }
}
