import AppKit
import Carbon.HIToolbox
import CoreGraphics
import SwiftUI

struct ShortcutRecorderField: View {
    let shortcut: Binding<KeyboardShortcutSetting>
    var modifierWidth: CGFloat = 190
    var keyWidth: CGFloat = 72
    var recordWidth: CGFloat = 76

    @StateObject private var recorder = ShortcutRecorderController()
    @State private var keyText = ""
    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Picker("", selection: shortcut.modifier) {
                    ForEach(ShortcutModifierPreset.allCases) { modifier in
                        Text(modifier.displayName).tag(modifier)
                    }
                }
                .labelsHidden()
                .frame(width: modifierWidth)

                TextField("Key", text: $keyText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .frame(width: keyWidth)
                    .focused($isKeyFieldFocused)
                    .onChange(of: keyText) { newValue in
                        let lower = newValue.lowercased()
                        if lower == "space" || lower == "espace" {
                            setKey("space")
                        }
                    }
                    .onChange(of: isKeyFieldFocused) { focused in
                        if !focused {
                            commitKeyText()
                        }
                    }
                    .onSubmit {
                        commitKeyText()
                    }

                Button(localizedString(recorder.isRecording ? "Stop" : "Record")) {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        recorder.start(shortcut: shortcut)
                    }
                }
                .frame(width: recordWidth)
                .buttonStyle(.bordered)
                .tint(recorder.isRecording ? .orange : .accentColor)
            }

            HStack(spacing: 4) {
                ForEach(specialKeys, id: \.value) { item in
                    Button(item.label) { setKey(item.value) }
                        .buttonStyle(.bordered)
                        .font(.system(size: 10))
                        .controlSize(.mini)
                        .help(item.value)
                }
            }
        }
        .onAppear {
            keyText = displayKey(shortcut.wrappedValue.key)
        }
        .onChange(of: shortcut.wrappedValue.key) { newKey in
            if !isKeyFieldFocused {
                keyText = displayKey(newKey)
            }
        }
        .onDisappear {
            recorder.stop()
        }
    }

    private struct SpecialKey {
        let value: String
        let label: String
    }

    private var specialKeys: [SpecialKey] {
        [
            .init(value: "space", label: "Space \u{2423}"),
            .init(value: "return", label: "Return \u{21B5}"),
            .init(value: "tab", label: "Tab \u{21E5}"),
            .init(value: "delete", label: "Delete \u{232B}"),
            .init(value: "left", label: "Left \u{2190}"),
            .init(value: "right", label: "Right \u{2192}"),
            .init(value: "up", label: "Up \u{2191}"),
            .init(value: "down", label: "Down \u{2193}"),
        ]
    }

    private func setKey(_ key: String) {
        var current = shortcut.wrappedValue
        current.key = key
        shortcut.wrappedValue = current
        keyText = displayKey(key)
        isKeyFieldFocused = false
    }

    private func commitKeyText() {
        let normalized = normalizedKey(from: keyText)
        var current = shortcut.wrappedValue
        current.key = normalized
        shortcut.wrappedValue = current
        keyText = displayKey(normalized)
    }

    private func displayKey(_ key: String) -> String {
        switch key {
        case "space": return localizedString("Space")
        case "return": return "\u{21B5}"
        case "tab": return "\u{21E5}"
        case "delete": return "\u{232B}"
        case "left": return "\u{2190}"
        case "right": return "\u{2192}"
        case "up": return "\u{2191}"
        case "down": return "\u{2193}"
        default: return key.uppercased()
        }
    }

    private func normalizedKey(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare("space") == .orderedSame
            || trimmed.caseInsensitiveCompare("espace") == .orderedSame {
            return "space"
        }
        guard !trimmed.isEmpty else { return shortcut.wrappedValue.key }
        return String(trimmed.suffix(1)).lowercased()
    }
}

final class ShortcutRecorderController: ObservableObject {
    @Published private(set) var isRecording = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var captureState = ShortcutCaptureState()
    private var shortcutBinding: Binding<KeyboardShortcutSetting>?

    func start(shortcut: Binding<KeyboardShortcutSetting>) {
        guard !isRecording else { return }
        shortcutBinding = shortcut
        captureState = ShortcutCaptureState()

        if startEventTap() {
            isRecording = true
        } else {
            startLocalMonitor()
            isRecording = true
        }
    }

    func stop() {
        isRecording = false
        captureState = ShortcutCaptureState()

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        shortcutBinding = nil
    }

    private func startEventTap() -> Bool {
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        let callback: CGEventTapCallBack = { _, type, cgEvent, refcon in
            guard let refcon else { return Unmanaged.passUnretained(cgEvent) }
            let controller = Unmanaged<ShortcutRecorderController>.fromOpaque(refcon).takeUnretainedValue()
            return controller.handleGlobalEvent(type: type, cgEvent: cgEvent)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func startLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            return self.handleLocalEvent(event)
        }
    }

    private func handleGlobalEvent(type: CGEventType, cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(cgEvent)

        case .flagsChanged:
            let keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)
            captureState.update(keyCode: keyCode, flags: cgEvent.flags)
            return Unmanaged.passUnretained(cgEvent)

        case .keyDown:
            let keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == Int64(kVK_Escape) {
                stop()
                return nil
            }

            if let special = Self.keyName(for: keyCode) {
                recordShortcut(key: special)
                return nil
            }

            if let nsEvent = NSEvent(cgEvent: cgEvent),
               let chars = nsEvent.charactersIgnoringModifiers, !chars.isEmpty {
                let key = String(chars.lowercased().suffix(1))
                recordShortcut(key: key)
                return nil
            }

            return Unmanaged.passUnretained(cgEvent)

        default:
            return Unmanaged.passUnretained(cgEvent)
        }
    }

    private func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .flagsChanged:
            captureState.update(keyCode: Int64(event.keyCode), flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
            return nil

        case .keyDown:
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
                return nil
            }
            if let special = Self.keyName(for: Int64(event.keyCode)) {
                recordShortcut(key: special)
                return nil
            }
            if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                recordShortcut(key: String(chars.lowercased().suffix(1)))
                return nil
            }
            return event

        default:
            return event
        }
    }

    private func recordShortcut(key: String) {
        guard let binding = shortcutBinding else { return }
        let modifier = captureState.resolvedModifier(fallback: binding.wrappedValue.modifier)
        binding.wrappedValue = KeyboardShortcutSetting(key: key, modifier: modifier)
        stop()
    }

    private static func keyName(for keyCode: Int64) -> String? {
        switch keyCode {
        case Int64(kVK_Space): return "space"
        case Int64(kVK_Return): return "return"
        case Int64(kVK_Tab): return "tab"
        case Int64(kVK_Delete): return "delete"
        case Int64(kVK_LeftArrow): return "left"
        case Int64(kVK_RightArrow): return "right"
        case Int64(kVK_UpArrow): return "up"
        case Int64(kVK_DownArrow): return "down"
        case Int64(kVK_ANSI_1): return "1"
        case Int64(kVK_ANSI_2): return "2"
        case Int64(kVK_ANSI_3): return "3"
        case Int64(kVK_ANSI_4): return "4"
        case Int64(kVK_ANSI_5): return "5"
        case Int64(kVK_ANSI_6): return "6"
        case Int64(kVK_ANSI_7): return "7"
        case Int64(kVK_ANSI_8): return "8"
        case Int64(kVK_ANSI_9): return "9"
        case Int64(kVK_ANSI_0): return "0"
        default: return nil
        }
    }
}

private struct ShortcutCaptureState {
    var control = false
    var leftCommand = false
    var rightCommand = false
    var leftOption = false
    var rightOption = false
    var leftShift = false
    var rightShift = false
    var fn = false

    mutating func update(keyCode: Int64, flags: CGEventFlags) {
        switch keyCode {
        case 59, 62: control = flags.contains(.maskControl)
        case 54: rightCommand = flags.contains(.maskCommand)
        case 55: leftCommand = flags.contains(.maskCommand)
        case 58: leftOption = flags.contains(.maskAlternate)
        case 61: rightOption = flags.contains(.maskAlternate)
        case 56: leftShift = flags.contains(.maskShift)
        case 60: rightShift = flags.contains(.maskShift)
        case 63: fn = flags.contains(.maskSecondaryFn)
        default: break
        }
    }

    func resolvedModifier(fallback: ShortcutModifierPreset) -> ShortcutModifierPreset {
        let commandPressed = leftCommand || rightCommand
        let controlPressed = control
        let optionPressed = leftOption || rightOption
        let shiftPressed = leftShift || rightShift

        if fn && shiftPressed {
            return .fnShift
        }
        if controlPressed && optionPressed && !commandPressed && !shiftPressed {
            return .controlOption
        }
        if controlPressed && shiftPressed && !commandPressed && !optionPressed {
            return .controlShift
        }
        if commandPressed && !controlPressed && !optionPressed && !shiftPressed {
            return leftCommand != rightCommand ? (leftCommand ? .leftCommand : .rightCommand) : .command
        }
        if optionPressed && !controlPressed && !commandPressed && !shiftPressed {
            return leftOption != rightOption ? (leftOption ? .leftOption : .rightOption) : .option
        }
        if shiftPressed && !controlPressed && !commandPressed && !optionPressed {
            return leftShift != rightShift ? (leftShift ? .leftShift : .rightShift) : .shift
        }
        return fallback
    }
}
