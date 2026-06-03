import AppKit
import Carbon.HIToolbox
import Foundation

enum ShortcutModifierPreset: String, CaseIterable, Codable, Identifiable {
    case controlOption

    var id: String { rawValue }

    var displayName: String { "Control + Option" }

    var symbolPrefix: String { "⌃⌥" }

    var flags: NSEvent.ModifierFlags { [.control, .option] }

    var carbonFlags: UInt32 { UInt32(controlKey | optionKey) }
}

struct KeyboardShortcutSetting: Codable, Equatable {
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
        case .windowLeftHalf: "Left Half"
        case .windowRightHalf: "Right Half"
        case .windowTopHalf: "Top Half"
        case .windowBottomHalf: "Bottom Half"
        case .windowMaximize: "Maximize"
        case .windowCenter: "Center"
        case .windowTopLeft: "Top Left"
        case .windowTopRight: "Top Right"
        case .windowBottomLeft: "Bottom Left"
        case .windowBottomRight: "Bottom Right"
        case .windowFirstThird: "First Third"
        case .windowCenterThird: "Center Third"
        case .windowLastThird: "Last Third"
        case .windowNextDisplay: "Next Display"
        case .windowPreviousDisplay: "Previous Display"
        }
    }

    var group: String { "Window" }

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
