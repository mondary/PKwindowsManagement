import SwiftUI

@main
struct PKwindowsManagementApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup("PKwindowsManagement") {
            WindowShortcutsPreferencesView(settings: settings)
                .frame(minWidth: 760, minHeight: 720)
        }
    }
}
