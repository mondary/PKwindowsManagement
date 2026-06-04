import AppKit
import CoreGraphics

final class LaunchShortcutMonitor {
    static let shared = LaunchShortcutMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var settings: AppSettings?
    private var launchHandler: ((LaunchableApp) -> Void)?
    private var modifierState = ModifierState()
    private var appsByShortcut: [ShortcutSignature: LaunchableApp] = [:]

    func start(settings: AppSettings, apps: [LaunchableApp], launchHandler: @escaping (LaunchableApp) -> Void) {
        self.settings = settings
        self.launchHandler = launchHandler
        self.appsByShortcut = Dictionary(uniqueKeysWithValues: apps.compactMap { app in
            guard let shortcut = app.shortcut else { return nil }
            return (ShortcutSignature(shortcut: shortcut), app)
        })

        guard eventTap == nil else { return }
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<LaunchShortcutMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(eventType: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: refcon) else {
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func refreshApps(_ apps: [LaunchableApp]) {
        appsByShortcut = Dictionary(uniqueKeysWithValues: apps.compactMap { app in
            guard let shortcut = app.shortcut else { return nil }
            return (ShortcutSignature(shortcut: shortcut), app)
        })
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
        guard let char = NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.lowercased().first else { return nil }
        let signature = ShortcutSignature(character: char, modifiers: modifierState)
        return appsByShortcut.first(where: { $0.key.matches(signature) })?.value
    }
}

private struct ShortcutSignature: Hashable {
    let character: Character
    let modifier: ShortcutModifierPreset

    init(shortcut: KeyboardShortcutSetting) {
        character = Character(shortcut.key.lowercased())
        modifier = shortcut.modifier
    }

    init(character: Character, modifiers: ModifierState) {
        self.character = character
        self.modifier = modifiers.preferredPreset
    }

    func matches(_ other: ShortcutSignature) -> Bool {
        guard character == other.character else { return false }
        switch modifier {
        case .command:
            return other.modifier == .command || other.modifier == .leftCommand || other.modifier == .rightCommand
        case .option:
            return other.modifier == .option || other.modifier == .leftOption || other.modifier == .rightOption
        default:
            return modifier == other.modifier
        }
    }
}

private struct ModifierState {
    var leftCommand = false
    var rightCommand = false
    var leftOption = false
    var rightOption = false
    var shift = false
    var fn = false

    var preferredPreset: ShortcutModifierPreset {
        if leftCommand { return .leftCommand }
        if rightCommand { return .rightCommand }
        if leftOption { return .leftOption }
        if rightOption { return .rightOption }
        if fn && shift { return .fnShift }
        return .command
    }

    mutating func update(with event: CGEvent) {
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 54: rightCommand.toggle()
        case 55: leftCommand.toggle()
        case 58: leftOption.toggle()
        case 61: rightOption.toggle()
        case 56, 60: shift.toggle()
        case 63: fn.toggle()
        default: break
        }
    }
}
