import AppKit
import Carbon.HIToolbox
import Foundation

enum ShortcutModifierPreset: String, CaseIterable, Codable, Identifiable {
    case controlOption
    case command
    case leftCommand
    case rightCommand
    case option
    case leftOption
    case rightOption
    case shift
    case leftShift
    case rightShift
    case fnShift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .controlOption: localizedString("Control + Option")
        case .command: localizedString("Command")
        case .leftCommand: localizedString("Left Command")
        case .rightCommand: localizedString("Right Command")
        case .option: localizedString("Option")
        case .leftOption: localizedString("Left Option")
        case .rightOption: localizedString("Right Option")
        case .shift: localizedString("Shift")
        case .leftShift: localizedString("Left Shift")
        case .rightShift: localizedString("Right Shift")
        case .fnShift: localizedString("Fn + Shift")
        }
    }

    var symbolPrefix: String {
        switch self {
        case .controlOption: "⌃⌥"
        case .command: "⌘"
        case .leftCommand: "⌘L"
        case .rightCommand: "⌘R"
        case .option: "⌥"
        case .leftOption: "⌥L"
        case .rightOption: "⌥R"
        case .shift: "⇧"
        case .leftShift: "⇧L"
        case .rightShift: "⇧R"
        case .fnShift: "Fn⇧"
        }
    }

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .controlOption: [.control, .option]
        case .command, .leftCommand, .rightCommand: [.command]
        case .option, .leftOption, .rightOption: [.option]
        case .shift, .leftShift, .rightShift: [.shift]
        case .fnShift: [.function, .shift]
        }
    }

    var carbonFlags: UInt32 {
        switch self {
        case .controlOption: UInt32(controlKey | optionKey)
        case .command, .leftCommand, .rightCommand: UInt32(cmdKey)
        case .option, .leftOption, .rightOption: UInt32(optionKey)
        case .shift, .leftShift, .rightShift: UInt32(shiftKey)
        case .fnShift: UInt32(shiftKey | alphaLock)
        }
    }

    var keySymbols: [String] {
        switch self {
        case .controlOption: ["⌃", "⌥"]
        case .command: ["⌘"]
        case .leftCommand: ["⌘L"]
        case .rightCommand: ["⌘R"]
        case .option: ["⌥"]
        case .leftOption: ["⌥L"]
        case .rightOption: ["⌥R"]
        case .shift: ["⇧"]
        case .leftShift: ["⇧L"]
        case .rightShift: ["⇧R"]
        case .fnShift: ["fn", "⇧"]
        }
    }
}

struct KeyboardShortcutSetting: Codable, Equatable, Hashable {
    var key: String
    var modifier: ShortcutModifierPreset

    var keyDisplayName: String {
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

    var menuKeyEquivalent: String {
        switch key {
        case "space": return " "
        case "return": return "\r"
        case "tab": return "\t"
        case "delete": return "\u{8}"
        case "left": return String(NSLeftArrowFunctionKey)
        case "right": return String(NSRightArrowFunctionKey)
        case "up": return String(NSUpArrowFunctionKey)
        case "down": return String(NSDownArrowFunctionKey)
        default: return key
        }
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case windowLeftHalf
    case windowRightHalf
    case windowTopHalf
    case windowBottomHalf
    case windowMaximize
    case windowCenter
    case windowTopLeft
    case windowTopRight
    case windowBottomLeft
    case windowBottomRight
    case windowFirstThird
    case windowCenterThird
    case windowLastThird
    case windowTopFirstSixth
    case windowTopCenterSixth
    case windowTopLastSixth
    case windowBottomFirstSixth
    case windowBottomCenterSixth
    case windowBottomLastSixth
    case windowFullScreen
    case windowNextDisplay
    case windowPreviousDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windowLeftHalf: localizedString("Left Half")
        case .windowRightHalf: localizedString("Right Half")
        case .windowTopHalf: localizedString("Top Half")
        case .windowBottomHalf: localizedString("Bottom Half")
        case .windowMaximize: localizedString("Maximize")
        case .windowCenter: localizedString("Center")
        case .windowTopLeft: localizedString("Top Left")
        case .windowTopRight: localizedString("Top Right")
        case .windowBottomLeft: localizedString("Bottom Left")
        case .windowBottomRight: localizedString("Bottom Right")
        case .windowFirstThird: localizedString("First Third")
        case .windowCenterThird: localizedString("Center Third")
        case .windowLastThird: localizedString("Last Third")
        case .windowTopFirstSixth: localizedString("Top Left Sixth")
        case .windowTopCenterSixth: localizedString("Top Center Sixth")
        case .windowTopLastSixth: localizedString("Top Right Sixth")
        case .windowBottomFirstSixth: localizedString("Bottom Left Sixth")
        case .windowBottomCenterSixth: localizedString("Bottom Center Sixth")
        case .windowBottomLastSixth: localizedString("Bottom Right Sixth")
        case .windowFullScreen: localizedString("Fullscreen")
        case .windowNextDisplay: localizedString("Next Display")
        case .windowPreviousDisplay: localizedString("Previous Display")
        }
    }

    var group: String { localizedString("Window") }

    var defaultShortcut: KeyboardShortcutSetting {
        switch self {
        case .windowLeftHalf: .init(key: "left", modifier: .controlOption)
        case .windowRightHalf: .init(key: "right", modifier: .controlOption)
        case .windowTopHalf: .init(key: "up", modifier: .controlOption)
        case .windowBottomHalf: .init(key: "down", modifier: .controlOption)
        case .windowMaximize: .init(key: "f", modifier: .controlOption)
        case .windowCenter: .init(key: "c", modifier: .controlOption)
        case .windowTopLeft: .init(key: "y", modifier: .controlOption)
        case .windowTopRight: .init(key: "p", modifier: .controlOption)
        case .windowBottomLeft: .init(key: "h", modifier: .controlOption)
        case .windowBottomRight: .init(key: "m", modifier: .controlOption)
        case .windowFirstThird: .init(key: "1", modifier: .controlOption)
        case .windowCenterThird: .init(key: "2", modifier: .controlOption)
        case .windowLastThird: .init(key: "3", modifier: .controlOption)
        case .windowTopFirstSixth: .init(key: "u", modifier: .controlOption)
        case .windowTopCenterSixth: .init(key: "i", modifier: .controlOption)
        case .windowTopLastSixth: .init(key: "o", modifier: .controlOption)
        case .windowBottomFirstSixth: .init(key: "j", modifier: .controlOption)
        case .windowBottomCenterSixth: .init(key: "k", modifier: .controlOption)
        case .windowBottomLastSixth: .init(key: "l", modifier: .controlOption)
        case .windowFullScreen: .init(key: "return", modifier: .controlOption)
        case .windowNextDisplay: .init(key: "space", modifier: .controlOption)
        case .windowPreviousDisplay: .init(key: "[", modifier: .controlOption)
        }
    }
}
