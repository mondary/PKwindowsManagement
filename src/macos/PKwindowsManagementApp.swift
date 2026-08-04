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
                .environment(\.locale, settings.appLanguage.locale)
                .id(settings.appLanguage)
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
                    } windowHandler: { action in
                        WindowSnapService().perform(action, preset: settings.windowMarginPreset)
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
                Button(localizedString("Settings...")) {
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
    @State private var isSidebarVisible = true

    static var appIcon: NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        return NSImage(named: "AppIcon")
    }

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .frame(width: 210)
                Divider()
            } else {
                sidebarRevealStrip
                Divider()
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sidebar: some View {
        List(SettingsSection.allCases, selection: $selection) { section in
            Label(section.title, systemImage: section.icon)
                .tag(section)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                sidebarToggleButton
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

    private var sidebarRevealStrip: some View {
        VStack {
            sidebarToggleButton
                .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .frame(width: 24)
        .background(.regularMaterial)
    }

    private var sidebarToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isSidebarVisible.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(localizedString("Show / Hide Sidebar"))
    }

    private var detail: some View {
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
        case .general: localizedString("General")
        case .windows: localizedString("Windows")
        case .launchpad: "Launchpad"
        case .appearance: localizedString("Appearance")
        case .snippets: localizedString("Snippets")
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
