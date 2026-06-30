import AppKit
import SwiftUI

struct ShortcutRecorderField: View {
    let shortcut: Binding<KeyboardShortcutSetting>
    var modifierWidth: CGFloat = 190
    var keyWidth: CGFloat = 72
    var recordWidth: CGFloat = 76

    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var captureState = ShortcutCaptureState()

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: shortcut.modifier) {
                ForEach(ShortcutModifierPreset.allCases) { modifier in
                    Text(modifier.displayName).tag(modifier)
                }
            }
            .labelsHidden()
            .frame(width: modifierWidth)

            TextField("Key", text: shortcutKeyBinding)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .frame(width: keyWidth)

            Button(localizedString(isRecording ? "Stop" : "Record")) {
                isRecording ? stopRecording() : startRecording()
            }
            .frame(width: recordWidth)
            .buttonStyle(.bordered)
            .tint(isRecording ? .orange : .accentColor)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var shortcutKeyBinding: Binding<String> {
        Binding(
            get: {
                displayKey(shortcut.wrappedValue.key)
            },
            set: { value in
                var current = shortcut.wrappedValue
                current.key = normalizedKey(from: value)
                shortcut.wrappedValue = current
            }
        )
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        captureState = ShortcutCaptureState()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            guard self.isRecording else { return event }

            switch event.type {
            case .flagsChanged:
                self.captureState.update(with: event)
                return nil

            case .keyDown:
                if event.keyCode == 53 {
                    self.stopRecording()
                    return nil
                }

                guard let key = shortcutKey(from: event) else { return nil }
                let modifier = self.captureState.resolvedModifier(fallback: self.shortcut.wrappedValue.modifier)
                self.shortcut.wrappedValue = KeyboardShortcutSetting(key: key, modifier: modifier)
                self.stopRecording()
                return nil

            default:
                return event
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        captureState = ShortcutCaptureState()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func displayKey(_ key: String) -> String {
        key == "space" ? localizedString("Space") : key.uppercased()
    }

    private func normalizedKey(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return shortcut.wrappedValue.key }
        if trimmed.caseInsensitiveCompare("space") == .orderedSame {
            return "space"
        }
        return String(trimmed.suffix(1)).lowercased()
    }

    private func shortcutKey(from event: NSEvent) -> String? {
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return nil }
        if characters == " " {
            return "space"
        }
        return String(characters.lowercased().suffix(1))
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

    mutating func update(with event: NSEvent) {
        let isPressed = event.modifierFlags.contains(flag(for: event.keyCode))
        switch event.keyCode {
        case 59, 62: control = isPressed
        case 54: rightCommand = isPressed
        case 55: leftCommand = isPressed
        case 58: leftOption = isPressed
        case 61: rightOption = isPressed
        case 56: leftShift = isPressed
        case 60: rightShift = isPressed
        case 63: fn = event.modifierFlags.contains(.function)
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

    private func flag(for keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 59, 62: .control
        case 54, 55: .command
        case 58, 61: .option
        case 56, 60: .shift
        case 63: .function
        default: []
        }
    }
}
