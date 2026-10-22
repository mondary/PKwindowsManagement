import Foundation

@main
enum WindowQuitRequestChecks {
    static func main() {
        var terminateCalls = 0
        var pauseCalls = 0

        // A cancelled interaction never touches the target app.
        precondition(WindowQuitRequest.run(
            isCancelled: { true }, validate: { true },
            terminate: { terminateCalls += 1; return true },
            isTerminated: { true }, pause: { pauseCalls += 1 }
        ) == .cancelled)
        precondition(terminateCalls == 0 && pauseCalls == 0)

        // A stale candidate (relaunched app or closed window) is rejected.
        precondition(WindowQuitRequest.run(
            isCancelled: { false }, validate: { false },
            terminate: { terminateCalls += 1; return true },
            isTerminated: { true }, pause: { pauseCalls += 1 }
        ) == .failed)
        precondition(terminateCalls == 0)

        // The app refused or ignored the quit request.
        precondition(WindowQuitRequest.run(
            isCancelled: { false }, validate: { true },
            terminate: { false }, isTerminated: { true }, pause: { pauseCalls += 1 }
        ) == .failed)
        precondition(pauseCalls == 0)

        // A graceful quit can take a few polling ticks.
        var checks = 0
        precondition(WindowQuitRequest.run(
            isCancelled: { false }, validate: { true },
            terminate: { true },
            isTerminated: { checks += 1; return checks >= 3 },
            pause: { pauseCalls += 1 }
        ) == .quit)
        precondition(checks == 3 && pauseCalls == 2)

        // A save dialog can keep the app alive past the observation window.
        checks = 0
        pauseCalls = 0
        precondition(WindowQuitRequest.run(
            isCancelled: { false }, validate: { true },
            terminate: { true }, isTerminated: { checks += 1; return false },
            pause: { pauseCalls += 1 }
        ) == .pending)
        precondition(checks == 40 && pauseCalls == 40)

        // Closing the picker cancels an in-flight observation.
        checks = 0
        var cancelled = false
        precondition(WindowQuitRequest.run(
            isCancelled: { cancelled }, validate: { true },
            terminate: { true },
            isTerminated: { checks += 1; cancelled = checks == 2; return false },
            pause: { pauseCalls += 1 }
        ) == .cancelled)
        precondition(checks == 2)

        print("Window quit checks passed: cancellation, stale candidate, refused quit, graceful quit and save-dialog timeout")
    }
}
