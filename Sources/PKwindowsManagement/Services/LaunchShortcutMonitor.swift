import AppKit
import ApplicationServices
import CoreGraphics

final class LaunchShortcutMonitor {
    static let shared = LaunchShortcutMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var settings: AppSettings?
    private var launchHandler: ((LaunchableApp) -> Void)?
    private var modifierState = ModifierState()
    private var appsByBundleID: [String: LaunchableApp] = [:]
    private var retryTimer: Timer?
    private var didRequestAccessibility = false

    func start(settings: AppSettings, apps: [LaunchableApp], launchHandler: @escaping (LaunchableApp) -> Void) {
        self.settings = settings
        self.launchHandler = launchHandler
        self.appsByBundleID = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })

        requestAccessibilityOnce()
        installEventTap()
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }

    deinit {
        stop()
    }

    private func requestAccessibilityOnce() {
        guard !didRequestAccessibility else { return }
        didRequestAccessibility = true
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func installEventTap() {
        guard eventTap == nil else { return }
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<LaunchShortcutMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(eventType: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: refcon) else {
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
    }

    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.installEventTap()
        }
    }

    func refreshApps(_ apps: [LaunchableApp]) {
        appsByBundleID = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch eventType {
        case .flagsChanged:
            modifierState.update(with: event)
            return .passUnretained(event)
        case .keyDown:
            guard let app = match(event: event) else { return .passUnretained(event) }
            launchHandler?(app)
            return nil
        default:
            return .passUnretained(event)
        }
    }

    private func match(event: CGEvent) -> LaunchableApp? {
        guard let settings else { return nil }
        guard let char = NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.lowercased().first else { return nil }
        let flags = event.flags

        guard let bundleID = settings.launchShortcuts.first(where: { _, shortcut in
            guard shortcut.key.lowercased().first == char else { return false }
            return modifierState.matches(shortcut.modifier, flags: flags)
        })?.key else { return nil }

        return appsByBundleID[bundleID]
    }
}

private struct ModifierState {
    var leftCommand = false
    var rightCommand = false
    var leftOption = false
    var rightOption = false
    var leftShift = false
    var rightShift = false
    var fn = false

    mutating func update(with event: CGEvent) {
        let isPressed = event.flags.contains(flag(for: event.getIntegerValueField(.keyboardEventKeycode)))
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 54: rightCommand = isPressed
        case 55: leftCommand = isPressed
        case 58: leftOption = isPressed
        case 61: rightOption = isPressed
        case 56: leftShift = isPressed
        case 60: rightShift = isPressed
        case 63: fn = event.flags.contains(.maskSecondaryFn)
        default: break
        }
    }

    func matches(_ preset: ShortcutModifierPreset, flags: CGEventFlags) -> Bool {
        switch preset {
        case .controlOption:
            return flags.contains(.maskControl) && flags.contains(.maskAlternate)
        case .command:
            return flags.contains(.maskCommand)
        case .leftCommand:
            return leftCommand
        case .rightCommand:
            return rightCommand
        case .option:
            return flags.contains(.maskAlternate)
        case .leftOption:
            return leftOption
        case .rightOption:
            return rightOption
        case .shift:
            return flags.contains(.maskShift)
        case .leftShift:
            return leftShift
        case .rightShift:
            return rightShift
        case .fnShift:
            return fn && (flags.contains(.maskShift) || leftShift || rightShift)
        }
    }

    private func flag(for keyCode: Int64) -> CGEventFlags {
        switch keyCode {
        case 54, 55: .maskCommand
        case 58, 61: .maskAlternate
        case 56, 60: .maskShift
        case 63: .maskSecondaryFn
        default: []
        }
    }
}
