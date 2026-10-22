import Foundation

/// Ask one app to quit, then observe. A save dialog can legitimately delay it.
enum WindowQuitRequest {
    enum Result: Equatable { case quit, pending, failed, cancelled }

    static func run(isCancelled: () -> Bool, validate: () -> Bool,
                    terminate: () -> Bool, isTerminated: () -> Bool,
                    pause: () -> Void) -> Result {
        guard !isCancelled() else { return .cancelled }
        guard validate() else { return .failed }
        guard terminate() else { return .failed }
        for _ in 0..<40 {
            guard !isCancelled() else { return .cancelled }
            if isTerminated() { return .quit }
            pause()
        }
        return isCancelled() ? .cancelled : .pending
    }
}
