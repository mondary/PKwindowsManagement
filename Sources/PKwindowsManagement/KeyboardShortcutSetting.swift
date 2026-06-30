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
        case .windowNextDisplay: localizedString("Next Display")
        case .windowPreviousDisplay: localizedString("Previous Display")
        }
    }

    var group: String { localizedString("Window") }

    var defaultShortcut: KeyboardShortcutSetting {
        switch self {
        case .windowLeftHalf: .init(key: "h", modifier: .controlOption)
        case .windowRightHalf: .init(key: "l", modifier: .controlOption)
        case .windowTopHalf: .init(key: "k", modifier: .controlOption)
        case .windowBottomHalf: .init(key: "j", modifier: .controlOption)
        case .windowMaximize: .init(key: "m", modifier: .controlOption)
        case .windowCenter: .init(key: "c", modifier: .controlOption)
        case .windowTopLeft: .init(key: "u", modifier: .controlOption)
        case .windowTopRight: .init(key: "i", modifier: .controlOption)
        case .windowBottomLeft: .init(key: "n", modifier: .controlOption)
        case .windowBottomRight: .init(key: "o", modifier: .controlOption)
        case .windowFirstThird: .init(key: "1", modifier: .controlOption)
        case .windowCenterThird: .init(key: "2", modifier: .controlOption)
        case .windowLastThird: .init(key: "3", modifier: .controlOption)
        case .windowNextDisplay: .init(key: "]", modifier: .controlOption)
        case .windowPreviousDisplay: .init(key: "[", modifier: .controlOption)
        }
    }
}
