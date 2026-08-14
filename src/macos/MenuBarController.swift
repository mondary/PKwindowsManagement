import AppKit
import Carbon.HIToolbox

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var launchpadHotKey: EventHotKeyRef?
    private var launchpadHotKeyHandler: EventHandlerRef?
    private var launchpadHotKeyObserver: NSObjectProtocol?
    private var hotCornerObserver: NSObjectProtocol?
    private var languageObserver: NSObjectProtocol?
    private var automaticTerminationActivity: NSObjectProtocol?
    private var hotCornerTimer: Timer?
    private var lastMouseLocation: CGPoint = .zero
    private var lastHotCornerTrigger: Date?
    private let hotCornerCooldown: TimeInterval = 1.5
    private let launchpadHotKeySignature = fourCharCode("PKLP")

    func applicationDidFinishLaunching(_ notification: Notification) {
        automaticTerminationActivity = ProcessInfo.processInfo.beginActivity(
            options: .automaticTerminationDisabled,
            reason: "Keep menu bar controls and global shortcuts active"
        )
        NSApp.setActivationPolicy(.regular)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = Self.loadMenuBarIcon()
            image.isTemplate = false
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusItem = item
        rebuildStatusMenu()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.rebuildStatusMenu() }

        registerLaunchpadTriggers()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let automaticTerminationActivity {
            ProcessInfo.processInfo.endActivity(automaticTerminationActivity)
            self.automaticTerminationActivity = nil
        }
        hotCornerTimer?.invalidate()
        hotCornerTimer = nil
        LaunchShortcutMonitor.shared.stop()
        unregisterLaunchpadHotKey()
        if let launchpadHotKeyHandler {
            RemoveEventHandler(launchpadHotKeyHandler)
            self.launchpadHotKeyHandler = nil
        }
        if let launchpadHotKeyObserver {
            NotificationCenter.default.removeObserver(launchpadHotKeyObserver)
        }
        if let hotCornerObserver {
            NotificationCenter.default.removeObserver(hotCornerObserver)
        }
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
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
        AppRuntime.shared.openSettings?()
    }

    @objc private func openLaunchpad() {
        guard let settings = AppRuntime.shared.settings else { return }
        LaunchpadOverlayController.shared.show(settings: settings)
    }

    @objc private func openBigYear() {
        BigYearOverlayController.shared.toggle()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PKwindowsManagement", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let launchpadShortcut = AppRuntime.shared.settings?.launchpadShortcut
        let launchpadItem = NSMenuItem(
            title: localizedString("Open Launchpad"),
            action: #selector(openLaunchpad),
            keyEquivalent: launchpadShortcut?.menuKeyEquivalent ?? ""
        )
        launchpadItem.target = self
        launchpadItem.keyEquivalentModifierMask = launchpadShortcut?.modifier.flags ?? []
        menu.addItem(launchpadItem)

        let bigYearItem = NSMenuItem(title: localizedString("Open Big Year"), action: #selector(openBigYear), keyEquivalent: "y")
        bigYearItem.target = self
        menu.addItem(bigYearItem)
        let preferencesItem = NSMenuItem(title: localizedString("Open Preferences"), action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        let quitItem = NSMenuItem(title: localizedString("Quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusMenu = menu
    }

    private func registerLaunchpadTriggers() {
        launchpadHotKeyObserver = NotificationCenter.default.addObserver(
            forName: .launchpadHotKeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerLaunchpadHotKey()
            self?.rebuildStatusMenu()
        }
        registerLaunchpadHotKey()

        hotCornerObserver = NotificationCenter.default.addObserver(
            forName: .launchpadHotCornerDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureHotCornerMonitoring()
        }
        configureHotCornerMonitoring()
    }

    private func configureHotCornerMonitoring() {
        hotCornerTimer?.invalidate()
        hotCornerTimer = nil
        guard let corner = AppRuntime.shared.settings?.launchpadHotCorner, corner != .disabled else { return }
        hotCornerTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.handleHotCorner()
        }
    }

    private func registerLaunchpadHotKey() {
        unregisterLaunchpadHotKey()
        guard let shortcut = AppRuntime.shared.settings?.launchpadShortcut,
              let keyCode = carbonKeyCode(for: shortcut.key)
        else { return }

        ensureLaunchpadHotKeyHandler()
        let hotKeyID = EventHotKeyID(signature: launchpadHotKeySignature, id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            shortcut.modifier.carbonFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &launchpadHotKey
        )
        if status != noErr {
            launchpadHotKey = nil
            NSLog("PKwindowsManagement: failed to register launchpad hotkey (%d)", status)
        }
    }

    private func unregisterLaunchpadHotKey() {
        if let launchpadHotKey {
            UnregisterEventHotKey(launchpadHotKey)
            self.launchpadHotKey = nil
        }
    }

    private func ensureLaunchpadHotKeyHandler() {
        guard launchpadHotKeyHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            launchpadHotKeyCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &launchpadHotKeyHandler
        )
    }

    fileprivate func handleLaunchpadHotKey() {
        guard let settings = AppRuntime.shared.settings else { return }
        LaunchpadOverlayController.shared.toggle(settings: settings)
    }

    private func handleHotCorner() {
        let mouseLocation = NSEvent.mouseLocation
        guard mouseLocation != lastMouseLocation else { return }
        lastMouseLocation = mouseLocation

        if let lastTrigger = lastHotCornerTrigger,
           Date().timeIntervalSince(lastTrigger) < hotCornerCooldown {
            return
        }

        guard let settings = AppRuntime.shared.settings,
              settings.launchpadHotCorner != .disabled,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
        else { return }
        let inset: CGFloat = 24
        let frame = screen.frame
        let cornerFrame: CGRect
        switch settings.launchpadHotCorner {
        case .disabled:
            return
        case .topLeft:
            cornerFrame = CGRect(x: frame.minX, y: frame.maxY - inset, width: inset, height: inset)
        case .topRight:
            cornerFrame = CGRect(x: frame.maxX - inset, y: frame.maxY - inset, width: inset, height: inset)
        case .bottomLeft:
            cornerFrame = CGRect(x: frame.minX, y: frame.minY, width: inset, height: inset)
        case .bottomRight:
            cornerFrame = CGRect(x: frame.maxX - inset, y: frame.minY, width: inset, height: inset)
        }
        if cornerFrame.contains(mouseLocation) {
            lastHotCornerTrigger = Date()
            LaunchpadOverlayController.shared.show(settings: settings)
        }
    }

    private static func loadMenuBarIcon() -> NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            return icon
        }
        if let named = NSImage(named: "AppIcon") {
            return named
        }
        return NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "PKwindowsManagement") ?? NSImage()
    }

    private func carbonKeyCode(for key: String) -> UInt32? {
        let keyCodes: [String: UInt32] = [
            "space": UInt32(kVK_Space),
            "return": UInt32(kVK_Return),
            "tab": UInt32(kVK_Tab),
            "delete": UInt32(kVK_Delete),
            "left": UInt32(kVK_LeftArrow),
            "right": UInt32(kVK_RightArrow),
            "up": UInt32(kVK_UpArrow),
            "down": UInt32(kVK_DownArrow),
            "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
            "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
            "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
            "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
            "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
            "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
            "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
            "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
            "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),
            "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
            "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
            "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
            "9": UInt32(kVK_ANSI_9)
        ]
        return keyCodes[key.lowercased()]
    }
}

private func launchpadHotKeyCallback(
    eventHandlerCallRef: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let controller = Unmanaged<MenuBarController>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        switch (hotKeyID.signature, hotKeyID.id) {
        case (fourCharCode("PKLP"), 1):
            controller.handleLaunchpadHotKey()
        default:
            break
        }
    }
    return noErr
}

private func fourCharCode(_ string: String) -> FourCharCode {
    string.unicodeScalars.prefix(4).reduce(0) { ($0 << 8) | ($1.value & 0xFF) }
}
