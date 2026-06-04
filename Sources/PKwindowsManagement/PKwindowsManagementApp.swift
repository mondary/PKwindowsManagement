import SwiftUI

@main
struct PKwindowsManagementApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController
    @StateObject private var settings = AppSettings()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("PKwindowsManagement", id: "settings") {
            RootDashboardView(settings: settings)
                .frame(minWidth: 760, minHeight: 720)
                .onAppear {
                    AppRuntime.shared.settings = settings
                    AppRuntime.shared.openSettings = {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    let launcher = AppLauncherService()
                    let apps = launcher.launcherCommands() + launcher.loadApps(settings: settings)
                    LaunchShortcutMonitor.shared.start(settings: settings, apps: apps) { app in
                        launcher.launch(app, settings: settings)
                    }
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
    @State private var section: DashboardSection = .windows

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                ForEach(DashboardSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)

            Divider()

            Group {
                switch section {
                case .windows:
                    WindowShortcutsPreferencesView(settings: settings)
                case .launchpad:
                    LaunchpadView(settings: settings)
                }
            }
        }
    }
}

private enum DashboardSection: String, CaseIterable, Identifiable {
    case windows
    case launchpad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windows: "Windows"
        case .launchpad: "Launchpad"
        }
    }
}
