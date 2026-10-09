import AppKit

/// Exercises the actual AppKit termination run loop, with no windows, settings,
/// or user documents. --legacy reproduces the old terminateLater deadlock.
final class TerminationFixture: NSObject, NSApplicationDelegate {
    let coordinator = ApplicationTerminationCoordinator()
    var preparations = 0
    var cleaned = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let prepare: (@escaping () -> Void) -> Void = { done in
            self.preparations += 1
            DispatchQueue.global().async {
                DispatchQueue.main.async {
                    self.cleaned = true
                    done()
                }
            }
        }
        if CommandLine.arguments.contains("--legacy") {
            prepare { sender.reply(toApplicationShouldTerminate: true) }
            return .terminateLater
        }
        return coordinator.request(sender, prepare: prepare)
    }

    func applicationWillTerminate(_ notification: Notification) {
        precondition(cleaned && preparations == 1)
        print("AppKit termination: asynchronous cleanup completed exactly once and app exited")
    }
}

@main
enum ApplicationTerminationChecks {
    static func main() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            FileHandle.standardError.write(Data("Termination timed out\n".utf8))
            _exit(2)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let delegate = TerminationFixture()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
