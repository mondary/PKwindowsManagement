import AppKit

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var launchpadHotKeyMonitor: Any?
    private var hotCornerTimer: Timer?
    private var lastMouseLocation: CGPoint = .zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "PKwindowsManagement")
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PKwindowsManagement", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Launchpad", action: #selector(openLaunchpad), keyEquivalent: " "))
        menu.addItem(NSMenuItem(title: "Open Preferences", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusMenu = menu
        statusItem = item

        registerLaunchpadTriggers()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            guard let statusMenu else { return }
            statusItem?.menu = statusMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
            return
        }

        guard let settings = AppRuntime.shared.settings else { return }
        LaunchpadOverlayController.shared.toggle(settings: settings)
    }

    @objc private func openPreferences() {
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLaunchpad() {
        guard let settings = AppRuntime.shared.settings else { return }
        LaunchpadOverlayController.shared.show(settings: settings)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func registerLaunchpadTriggers() {
        launchpadHotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return }
            self.handleGlobalKey(event)
        }

        hotCornerTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.handleHotCorner()
        }
    }

    private func handleGlobalKey(_ event: NSEvent) {
        guard event.type == .keyDown else { return }
        guard event.keyCode == 49 else { return } // space
        guard event.modifierFlags.contains(.option) else { return }
        guard let settings = AppRuntime.shared.settings else { return }
        LaunchpadOverlayController.shared.toggle(settings: settings)
    }

    private func handleHotCorner() {
        let mouseLocation = NSEvent.mouseLocation
        guard mouseLocation != lastMouseLocation else { return }
        lastMouseLocation = mouseLocation

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else { return }
        let inset: CGFloat = 24
        let frame = screen.frame
        let topLeft = CGRect(x: frame.minX, y: frame.maxY - inset, width: inset, height: inset)
        if topLeft.contains(mouseLocation), let settings = AppRuntime.shared.settings {
            LaunchpadOverlayController.shared.show(settings: settings)
        }
    }
}
