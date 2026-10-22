import AppKit
import Combine
import CoreGraphics

/// Takes over ⌘⇥ only while the user opts in. The tap is installed at the
/// head of the session stream so the system switcher never sees the keystroke;
/// disabling the preference removes it and restores the native behaviour.
final class CommandTabMonitor {
    static let shared = CommandTabMonitor()

    private var settings: AppSettings?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthTimer: Timer?
    private var retryTimer: Timer?
    private var cancellable: AnyCancellable?

    func start(settings: AppSettings) {
        guard self.settings == nil else { return }
        self.settings = settings
        cancellable = settings.$windowSwitcherUsesCommandTab
            .removeDuplicates()
            .sink { [weak self] enabled in
                DispatchQueue.main.async { self?.setEnabled(enabled) }
            }
        setEnabled(settings.windowSwitcherUsesCommandTab)
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
        settings = nil
        setEnabled(false)
    }

    private func setEnabled(_ enabled: Bool) {
        if enabled { installTap() } else { removeTap() }
    }

    private func installTap() {
        guard settings?.windowSwitcherUsesCommandTab == true, eventTap == nil else { return }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<CommandTabMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(eventType: type, event: event)
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback, userInfo: refcon) else {
            scheduleRetry()
            return
        }
        retryTimer?.invalidate()
        retryTimer = nil
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        startHealthCheck()
        NSLog("PKwindowsManagement: ⌘Tab window switcher enabled")
    }

    private func removeTap() {
        healthTimer?.invalidate()
        healthTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            if CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: false)
            }
            self.eventTap = nil
        }
    }

    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.installTap()
        }
    }

    private func startHealthCheck() {
        guard healthTimer == nil else { return }
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.settings?.windowSwitcherUsesCommandTab == true else { return }
            if let tap = self.eventTap {
                if CFMachPortIsValid(tap) {
                    if !CGEvent.tapIsEnabled(tap: tap) {
                        NSLog("PKwindowsManagement: re-enabling ⌘Tab window switcher")
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return
                }
                self.removeTap()
            }
            self.installTap()
        }
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap, CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == 48 else { return Unmanaged.passUnretained(event) }
            let flags = event.flags
            guard flags.contains(.maskCommand),
                  !flags.contains(.maskControl),
                  !flags.contains(.maskAlternate) else { return Unmanaged.passUnretained(event) }
            let backwards = flags.contains(.maskShift)
            if Thread.isMainThread {
                WindowSwitcherController.shared.handleCommandTab(backwards: backwards)
            } else {
                DispatchQueue.main.async {
                    WindowSwitcherController.shared.handleCommandTab(backwards: backwards)
                }
            }
            return nil
        case .flagsChanged:
            guard WindowSwitcherController.shared.isVisible,
                  !event.flags.contains(.maskCommand) else { return Unmanaged.passUnretained(event) }
            if Thread.isMainThread {
                WindowSwitcherController.shared.commitCommandTab()
            } else {
                DispatchQueue.main.async {
                    WindowSwitcherController.shared.commitCommandTab()
                }
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
