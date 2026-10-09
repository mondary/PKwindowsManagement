import AppKit

/// Do not return terminateLater when cleanup dispatches back to the main
/// queue: AppKit's nested termination loop may never service that callback.
/// Cancel this attempt, finish cleanup in the ordinary run loop, then retry.
final class ApplicationTerminationCoordinator {
    private var preparing = false
    private var ready = false

    func request(_ app: NSApplication, prepare: (@escaping () -> Void) -> Void) -> NSApplication.TerminateReply {
        precondition(Thread.isMainThread)
        if ready { return .terminateNow }
        guard !preparing else { return .terminateCancel }
        preparing = true
        prepare { [self] in
            DispatchQueue.main.async {
                self.ready = true
                app.terminate(nil)
            }
        }
        return .terminateCancel
    }
}
