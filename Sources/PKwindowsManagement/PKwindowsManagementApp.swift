import SwiftUI

@main
struct PKwindowsManagementApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController
    @StateObject private var settings = AppSettings()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("PKwindowsManagement", id: "settings") {
            RootDashboardView(settings: settings)
                .frame(minWidth: 900, minHeight: 620)
                .onAppear {
                    AppRuntime.shared.settings = settings
                    AppRuntime.shared.openSettings = {
                        LaunchpadOverlayController.shared.hide()
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    let launcher = AppLauncherService()
                    launcher.refreshURLSnippetIcons(settings: settings)
                    let apps = launcher.loadShortcutTargets(settings: settings)
                    LaunchShortcutMonitor.shared.start(settings: settings, apps: apps) { app in
                        _ = launcher.launch(app, settings: settings)
                    }
                }
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
                Button("Settings...") {
                    AppRuntime.shared.openSettings?()
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
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
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
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
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
                case .snippets:
                    SnippetsSettingsView(settings: settings)
                case .urls:
                    URLSnippetsSettingsView(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case windows
    case launchpad
    case appearance
    case snippets
    case urls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .windows: "Windows"
        case .launchpad: "Launchpad"
        case .appearance: "Appearance"
        case .snippets: "Snippets"
        case .urls: "URLs"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .windows: "rectangle.split.2x1"
        case .launchpad: "rectangle.3.group"
        case .appearance: "paintbrush"
        case .snippets: "doc.on.doc"
        case .urls: "link"
        }
    }
}
