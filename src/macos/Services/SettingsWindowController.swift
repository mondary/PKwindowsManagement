import AppKit

/// Own the settings window independently of SwiftUI's scene/reopen lifecycle.
/// Closing hides the retained window; every entry point can show it again.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    static let roomsRequested = Notification.Name("PKShowRoomsSettings")

    func showRooms() {
        showSettings()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.roomsRequested, object: nil)
        }
    }
    var makeContent: (() -> NSViewController)?

    private init() { super.init(window: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func prepareWindow() {
        precondition(Thread.isMainThread)
        if window == nil {
            guard let content = makeContent?() else { return }
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "PKwindowsManagement"
            window.identifier = NSUserInterfaceItemIdentifier("settings")
            window.isReleasedWhenClosed = false
            window.contentViewController = content
            window.contentMinSize = NSSize(width: 900, height: 620)
            window.center()
            window.setFrameAutosaveName("PKwindowsManagement.Settings")
            self.window = window
        }
    }

    func showSettings() {
        precondition(Thread.isMainThread)
        prepareWindow()
        guard let window else { return }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized { window.deminiaturize(nil) }
        // Bring the settings to the desktop on which the menu was used.
        let behavior = window.collectionBehavior
        window.collectionBehavior.insert(.moveToActiveSpace)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = behavior
    }
}
