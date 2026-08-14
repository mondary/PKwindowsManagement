import SwiftUI

@main
struct PKwindowsManagementApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController
    @StateObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

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
                .onAppear {
                    AppRuntime.shared.openSettings = {
                        LaunchpadOverlayController.shared.hide()
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
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
    @State private var sidebarWidth: CGFloat = 210
    @State private var sidebarDragStart: CGFloat = 0

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
                    .frame(width: sidebarWidth)
                    .clipped()

                sidebarDivider
            } else {
                sidebarRevealStrip
                Divider()
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color(NSColor.separatorColor))
            .frame(width: 1)
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 6)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if sidebarDragStart == 0 {
                                    sidebarDragStart = sidebarWidth
                                }
                                sidebarWidth = min(320, max(170, sidebarDragStart + value.translation.width))
                            }
                            .onEnded { _ in
                                sidebarDragStart = 0
                            }
                    )
                    .onHover { inside in
                        if inside {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            )
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
            case .bigYear:
                BigYearSettingsView(settings: settings)
            case .appearance:
                AppearanceSettingsView(settings: settings)
            case .snippets:
                SnippetsSettingsView(settings: settings)
            case .urls:
                URLSnippetsSettingsView(settings: settings)
            case .about:
                AboutSettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case .about: "info.circle"
        }
    }
}
