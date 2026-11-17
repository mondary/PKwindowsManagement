import Foundation

/// Short opacity-only transitions. Replica geometry always stays at its final
/// layout position; selecting a window never reverses a desktop-to-grid path.
enum ExposeAnimation {
    static func entryDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.06 : 0.16
    }

    static func exitDuration(activating: Bool, reduceMotion: Bool) -> TimeInterval {
        if reduceMotion { return 0.06 }
        return activating ? 0.07 : 0.10
    }
}
