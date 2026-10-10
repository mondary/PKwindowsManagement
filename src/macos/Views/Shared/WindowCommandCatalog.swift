import SwiftUI

/// Une commande de fenêtre configurable : libellé, icône et action associée.
struct WindowCommandSpec: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let fraction: CGRect?
    let action: ShortcutAction

    static func bound(_ title: String, _ symbol: String?, _ action: ShortcutAction, fraction: CGRect? = nil) -> Self {
        .init(id: title, title: title, symbol: symbol ?? "", fraction: fraction, action: action)
    }

    var family: WindowCommandFamily { WindowCommandFamily(of: action) }
}

/// Familles teintées de la carte clavier et de la légende.
enum WindowCommandFamily: String, CaseIterable, Identifiable {
    case placement
    case arrange
    case display
    case desktop
    case canvas

    var id: String { rawValue }

    init(of action: ShortcutAction) {
        switch action {
        case .windowLeftHalf, .windowRightHalf, .windowTopHalf, .windowBottomHalf,
             .windowTopLeft, .windowTopRight, .windowBottomLeft, .windowBottomRight,
             .windowFirstThird, .windowCenterThird, .windowLastThird,
             .windowTopFirstSixth, .windowTopCenterSixth, .windowTopLastSixth,
             .windowBottomFirstSixth, .windowBottomCenterSixth, .windowBottomLastSixth,
             .windowTopThird, .windowBottomThird, .windowTopTwoThirds, .windowBottomTwoThirds,
             .windowFirstTwoThirds, .windowCenterTwoThirds, .windowLastTwoThirds,
             .windowFirstFourth, .windowSecondFourth, .windowThirdFourth, .windowLastFourth,
             .windowFirstThreeFourths, .windowCenterThreeFourths, .windowLastThreeFourths:
            self = .placement
        case .windowMaximize, .windowMaximizeAll, .windowMaximizeAllInApp, .windowCenter,
             .windowFullScreen, .windowToggleFullScreen, .windowMaximizeHeight, .windowMaximizeWidth,
             .windowMakeLarger, .windowMakeSmaller, .windowReasonableSize, .windowRestore,
             .windowMoveLeft, .windowMoveRight, .windowMoveUp, .windowMoveDown, .windowTileAll:
            self = .arrange
        case .windowNextDisplay, .windowPreviousDisplay:
            self = .display
        case .desktopCreate, .desktopCloseCurrent, .windowNextDesktop, .windowPreviousDesktop,
             .desktopMoveLeft, .desktopMoveRight:
            self = .desktop
        case .canvasToggle, .canvasPrevious, .canvasNext, .canvasRestore:
            self = .canvas
        }
    }

    var title: String {
        switch self {
        case .placement: localizedString("Placement")
        case .arrange: localizedString("Size & Position")
        case .display: localizedString("Displays")
        case .desktop: localizedString("Desktops")
        case .canvas: localizedString("Horizontal Canvas")
        }
    }

    var tint: Color {
        switch self {
        case .placement: .accentColor
        case .arrange: .orange
        case .display: .purple
        case .desktop: .green
        case .canvas: .teal
        }
    }
}

/// Source unique des commandes affichées dans les réglages et la carte clavier.
enum WindowCommandCatalog {
    static let halves: [WindowCommandSpec] = [
        .bound("Left Half", "rectangle.lefthalf.inset.filled", .windowLeftHalf),
        .bound("Right Half", "rectangle.righthalf.inset.filled", .windowRightHalf),
        .bound("Top Half", "rectangle.tophalf.inset.filled", .windowTopHalf),
        .bound("Bottom Half", "rectangle.bottomhalf.inset.filled", .windowBottomHalf),
    ]

    static let move: [WindowCommandSpec] = [
        .bound("Move Left", "arrow.left.to.line.compact", .windowMoveLeft),
        .bound("Move Right", "arrow.right.to.line.compact", .windowMoveRight),
        .bound("Move Up", "arrow.up.to.line.compact", .windowMoveUp),
        .bound("Move Down", "arrow.down.to.line.compact", .windowMoveDown),
    ]

    static let quarters: [WindowCommandSpec] = [
        .bound("Top Left", nil, .windowTopLeft, fraction: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
        .bound("Top Right", nil, .windowTopRight, fraction: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)),
        .bound("Bottom Left", nil, .windowBottomLeft, fraction: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)),
        .bound("Bottom Right", nil, .windowBottomRight, fraction: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
    ]

    static let fourths: [WindowCommandSpec] = [
        .bound("First Fourth", nil, .windowFirstFourth, fraction: CGRect(x: 0, y: 0, width: 0.25, height: 1)),
        .bound("Second Fourth", nil, .windowSecondFourth, fraction: CGRect(x: 0.25, y: 0, width: 0.25, height: 1)),
        .bound("Third Fourth", nil, .windowThirdFourth, fraction: CGRect(x: 0.5, y: 0, width: 0.25, height: 1)),
        .bound("Last Fourth", nil, .windowLastFourth, fraction: CGRect(x: 0.75, y: 0, width: 0.25, height: 1)),
    ]

    static let thirds: [WindowCommandSpec] = [
        .bound("First Third", nil, .windowFirstThird, fraction: CGRect(x: 0, y: 0, width: 0.3334, height: 1)),
        .bound("Center Third", nil, .windowCenterThird, fraction: CGRect(x: 0.3333, y: 0, width: 0.3334, height: 1)),
        .bound("Last Third", nil, .windowLastThird, fraction: CGRect(x: 0.6667, y: 0, width: 0.3333, height: 1)),
    ]

    static let twoThirds: [WindowCommandSpec] = [
        .bound("First Two Thirds", nil, .windowFirstTwoThirds, fraction: CGRect(x: 0, y: 0, width: 0.6667, height: 1)),
        .bound("Center Two Thirds", nil, .windowCenterTwoThirds, fraction: CGRect(x: 0.1667, y: 0, width: 0.6666, height: 1)),
        .bound("Last Two Thirds", nil, .windowLastTwoThirds, fraction: CGRect(x: 0.3333, y: 0, width: 0.6667, height: 1)),
    ]

    static let threeFourths: [WindowCommandSpec] = [
        .bound("First Three Fourths", nil, .windowFirstThreeFourths, fraction: CGRect(x: 0, y: 0, width: 0.75, height: 1)),
        .bound("Center Three Fourths", nil, .windowCenterThreeFourths, fraction: CGRect(x: 0.125, y: 0, width: 0.75, height: 1)),
        .bound("Last Three Fourths", nil, .windowLastThreeFourths, fraction: CGRect(x: 0.25, y: 0, width: 0.75, height: 1)),
    ]

    static let horizontal: [WindowCommandSpec] = [
        .bound("Top Third", nil, .windowTopThird, fraction: CGRect(x: 0, y: 0, width: 1, height: 0.3334)),
        .bound("Bottom Third", nil, .windowBottomThird, fraction: CGRect(x: 0, y: 0.6667, width: 1, height: 0.3333)),
        .bound("Top Two Thirds", nil, .windowTopTwoThirds, fraction: CGRect(x: 0, y: 0, width: 1, height: 0.6667)),
        .bound("Bottom Two Thirds", nil, .windowBottomTwoThirds, fraction: CGRect(x: 0, y: 0.3333, width: 1, height: 0.6667)),
    ]

    static let sixths: [WindowCommandSpec] = [
        .bound("Top Left Sixth", nil, .windowTopFirstSixth, fraction: CGRect(x: 0, y: 0, width: 0.3334, height: 0.5)),
        .bound("Top Center Sixth", nil, .windowTopCenterSixth, fraction: CGRect(x: 0.3333, y: 0, width: 0.3334, height: 0.5)),
        .bound("Top Right Sixth", nil, .windowTopLastSixth, fraction: CGRect(x: 0.6667, y: 0, width: 0.3333, height: 0.5)),
        .bound("Bottom Left Sixth", nil, .windowBottomFirstSixth, fraction: CGRect(x: 0, y: 0.5, width: 0.3334, height: 0.5)),
        .bound("Bottom Center Sixth", nil, .windowBottomCenterSixth, fraction: CGRect(x: 0.3333, y: 0.5, width: 0.3334, height: 0.5)),
        .bound("Bottom Right Sixth", nil, .windowBottomLastSixth, fraction: CGRect(x: 0.6667, y: 0.5, width: 0.3333, height: 0.5)),
    ]

    static let displays: [WindowCommandSpec] = [
        .bound("Next Display", "arrow.forward.square", .windowNextDisplay),
        .bound("Previous Display", "arrow.backward.square", .windowPreviousDisplay),
    ]

    static let desktops: [WindowCommandSpec] = [
        .bound("New Desktop", "plus.rectangle.on.rectangle", .desktopCreate),
        .bound("Close Current Desktop", "minus.rectangle", .desktopCloseCurrent),
        .bound("Move Window to Next Desktop", "arrow.right.square", .windowNextDesktop),
        .bound("Move Window to Previous Desktop", "arrow.left.square", .windowPreviousDesktop),
        .bound("Move Desktop Left", "rectangle.stack.badge.minus", .desktopMoveLeft),
        .bound("Move Desktop Right", "rectangle.stack.badge.plus", .desktopMoveRight),
    ]

    static let canvas: [WindowCommandSpec] = [
        .bound("Toggle Horizontal Canvas", "rectangle.split.3x1", .canvasToggle),
        .bound("Previous Canvas Window", "arrow.left", .canvasPrevious),
        .bound("Next Canvas Window", "arrow.right", .canvasNext),
        .bound("Restore Canvas", "arrow.uturn.backward", .canvasRestore),
    ]

    enum size {
        static let fullScreen = WindowCommandSpec.bound("Fullscreen", "arrow.up.left.and.arrow.down.right", .windowFullScreen)
        static let toggleFullScreen = WindowCommandSpec.bound("Toggle Fullscreen", "rectangle.inset.fill", .windowToggleFullScreen)
        static let almostMaximize = WindowCommandSpec.bound("Almost Maximize", nil, .windowMaximize, fraction: CGRect(x: 0.045, y: 0.045, width: 0.91, height: 0.91))
        static let maximizeAll = WindowCommandSpec.bound("Maximize All Windows", "rectangle.on.rectangle", .windowMaximizeAll)
        static let maximizeAllInApp = WindowCommandSpec.bound("Maximize All Windows (Current App)", "rectangle.stack", .windowMaximizeAllInApp)
        static let tileAll = WindowCommandSpec.bound("Tile All Windows", nil, .windowTileAll, fraction: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        static let maximizeHeight = WindowCommandSpec.bound("Maximize Height", "arrow.up.and.down", .windowMaximizeHeight)
        static let maximizeWidth = WindowCommandSpec.bound("Maximize Width", "arrow.left.and.right", .windowMaximizeWidth)
        static let reasonableSize = WindowCommandSpec.bound("Reasonable Size", nil, .windowReasonableSize, fraction: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6))
        static let restore = WindowCommandSpec.bound("Restore", "arrow.uturn.backward", .windowRestore)
        static let makeLarger = WindowCommandSpec.bound("Make Larger", "arrow.up.left.and.arrow.down.right", .windowMakeLarger)
        static let makeSmaller = WindowCommandSpec.bound("Make Smaller", "arrow.down.right.and.arrow.up.left", .windowMakeSmaller)
        static let center = WindowCommandSpec.bound("Center", "circle.grid.cross", .windowCenter)

        static let all: [WindowCommandSpec] = [
            fullScreen, toggleFullScreen, almostMaximize, maximizeAll, maximizeAllInApp, tileAll,
            maximizeHeight, maximizeWidth, reasonableSize, restore, makeLarger, makeSmaller, center,
        ]
    }

    /// Toutes les commandes dont la carte clavier suit la liaison.
    static let all: [WindowCommandSpec] =
        halves + move + quarters + fourths + thirds + twoThirds + threeFourths + horizontal
        + sixths + displays + desktops + size.all + canvas

    // Touches enregistrables, en rangées de clavier ANSI compactes.
    static let numberRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
    static let topRow = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]"]
    static let homeRow = ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"]
    static let bottomRow = ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
    static let specialRow = ["tab", "space", "left", "up", "down", "right", "return", "delete"]

    static let rows: [[String]] = [numberRow, topRow, homeRow, bottomRow, specialRow]
}
