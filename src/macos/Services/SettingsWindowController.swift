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
    private var artifactObservers: [NSObjectProtocol] = []

    private init() { super.init(window: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// SwiftUI's dummy `Settings { EmptyView() }` scene opens its own tiny
    /// window titled "<App> Settings". It is not our custom settings window
    /// (identifier "settings", title without the suffix).
    static func isSwiftUISettingsArtifact(_ window: NSWindow) -> Bool {
        window.title.hasSuffix(" Settings") && window.identifier?.rawValue != "settings"
    }

    /// Keep the real settings window and silently retire the SwiftUI artifact.
    func startArtifactCleanup() {
        hideSwiftUISettingsArtifacts()
        guard artifactObservers.isEmpty else { return }
        let names = [NSWindow.didBecomeKeyNotification,
                     NSWindow.didBecomeMainNotification,
                     NSApplication.didBecomeActiveNotification]
        artifactObservers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { self?.hideSwiftUISettingsArtifacts() }
            }
        }
    }

    func stopArtifactCleanup() {
        for observer in artifactObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        artifactObservers.removeAll()
    }

    func hideSwiftUISettingsArtifacts() {
        for window in NSApp.windows where Self.isSwiftUISettingsArtifact(window) {
            window.isExcludedFromWindowsMenu = true
            window.orderOut(nil)
        }
    }

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
