import AppKit
import ApplicationServices

@main
enum CanvasAccessibilityThreadChecks {
    static func main() {
        _ = NSApplication.shared
        let local = AXUIElementCreateApplication(getpid())
        let external = AXUIElementCreateApplication(1)
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 500, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let original = window.frame
        let axWindow = CanvasWindowAccess.windows(pid: getpid()).first {
            CanvasWindowAccess.id($0) == CGWindowID(window.windowNumber)
        }
        // Real AppKit geometry, without showing a window or touching the user's
        // desktop. This is the same in-process dispatch boundary used by AX.
        CanvasWindowAccess.onAccessibilityThread(local) {
            precondition(Thread.isMainThread, "main caller must execute inline without deadlocking")
        }
        var complete = false // main-thread owned
        DispatchQueue(label: "canvas.ax.regression").async {
            if let axWindow, let initial = CanvasWindowAccess.frame(axWindow) {
                let half = CGRect(x: initial.minX, y: initial.minY, width: initial.width, height: initial.height / 2)
                let resized = CanvasWindowAccess.applyCanvasFrame(half, window: axWindow, valid: { true })
                precondition(resized.accepted && resized.actual.map { CanvasFrameApplication.fitsSize($0.size, half.size) } == true)
                precondition(CanvasWindowAccess.setFrame(initial, window: axWindow))
                print("Real self-process AX resize and restoration passed")
            } else {
                print("Hidden window not exposed through AX; testing native AppKit thread boundary")
            }
            CanvasWindowAccess.onAccessibilityThread(external) {
                precondition(!Thread.isMainThread, "external AX must stay on its worker")
            }
            var heartbeat = false // main-thread owned
            let target = CGRect(x: 140, y: 150, width: 500, height: 300)
            let result = CanvasFrameApplication.apply(target, initial: original,
                read: { CanvasWindowAccess.onAccessibilityThread(local) {
                    precondition(Thread.isMainThread)
                    return window.frame
                } }, size: { size in CanvasWindowAccess.onAccessibilityThread(local) {
                    precondition(Thread.isMainThread)
                    var frame = window.frame
                    frame.size = size
                    window.setFrame(frame, display: false)
                    return true
                } }, position: { point in CanvasWindowAccess.onAccessibilityThread(local) {
                    precondition(Thread.isMainThread)
                    window.setFrameOrigin(point)
                    return true
                } }, pause: { delay in
                    precondition(!Thread.isMainThread, "AX retry must never sleep on main")
                    DispatchQueue.main.async { heartbeat = true }
                    Thread.sleep(forTimeInterval: delay)
                })
            precondition(result.accepted && result.actual == target)
            CanvasWindowAccess.onAccessibilityThread(local) {
                precondition(heartbeat, "main must service events during resize waits")
                window.setFrame(original, display: false)
                precondition(window.frame == original && !window.isVisible)
                window.close()
                complete = true
            }
        }
        let deadline = Date().addingTimeInterval(5)
        while !complete && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        precondition(complete, "Canvas/main dispatch deadlocked")
        print("Canvas thread checks passed: local AppKit resize/restore on main, external AX and waits on worker, responsive main loop")
    }
}
