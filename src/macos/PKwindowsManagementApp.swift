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
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 198, ideal: 210, max: 240)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        List(SettingsSection.allCases, selection: $selection) { section in
            Label(section.title, systemImage: section.icon)
                .tag(section)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                if let icon = Self.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Text("PKwindowsManagement")
                    .font(.headline)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text(appVersionLabel)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
        }
    }

    private var appVersionLabel: String {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "v\(raw)"
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .general {
        case .general:
            GeneralSettingsView(settings: settings)
        case .windows:
            WindowShortcutsPreferencesView(settings: settings)
        case .launchpad:
            LaunchpadView(settings: settings)
        case .bigYear:
            BigYearSettingsView(settings: settings)
        case .appearance:
            AppearanceSettingsView(settings: settings)
        case .snippets:
            SnippetsSettingsView(settings: settings)
        case .urls:
            URLSnippetsSettingsView(settings: settings)
        case .support:
            SupportSettingsView()
        case .store:
            StoreSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case windows
    case launchpad
    case bigYear
    case appearance
    case snippets
    case urls
    case support
    case store
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: localizedString("General")
        case .windows: localizedString("Windows")
        case .launchpad: "Launchpad"
        case .bigYear: "Big Year"
        case .appearance: localizedString("Appearance")
        case .snippets: localizedString("Snippets")
        case .urls: "URLs"
        case .support: localizedString("Support")
        case .store: localizedString("Store")
        case .about: localizedString("About")
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
        case .support: "heart.fill"
        case .store: "bag"
        case .about: "info.circle"
        }
    }
}
