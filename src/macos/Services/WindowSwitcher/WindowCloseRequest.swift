import Foundation

/// Press once, then only observe. A timeout can be an app's save dialog.
enum WindowCloseRequest {
    enum Result: Equatable { case closed, pending, unavailable, failed, cancelled }

    static func run(isCancelled: () -> Bool, validate: () -> Bool,
                    press: () -> Bool, isClosed: () -> Bool,
                    pause: () -> Void) -> Result {
        guard !isCancelled() else { return .cancelled }
        guard validate() else { return .unavailable }
        guard !isCancelled() else { return .cancelled }
        guard press() else { return .failed }
        for _ in 0..<16 {
            guard !isCancelled() else { return .cancelled }
            if isClosed() { return .closed }
            pause()
        }
        return isCancelled() ? .cancelled : .pending
    }
}
