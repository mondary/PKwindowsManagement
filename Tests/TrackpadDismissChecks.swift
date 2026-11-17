import Foundation

@main
enum TrackpadDismissChecks {
    static func main() {
        var down = TrackpadSwipeDetector(direction: .down)
        precondition(!down.update(fingers: 4, y: 0.8, time: 0))
        precondition(!down.update(fingers: 4, y: 0.75, time: 0.02))
        precondition(down.update(fingers: 4, y: 0.6, time: 0.04))
        precondition(!down.update(fingers: 4, y: 0.3, time: 0.06))

        // The opposite direction must never satisfy the current intent.
        var upward = TrackpadSwipeDetector(direction: .down)
        precondition(!upward.update(fingers: 4, y: 0.2, time: 0))
        precondition(!upward.update(fingers: 4, y: 0.8, time: 0.1))
        var immediate = TrackpadSwipeDetector()
        precondition(!immediate.update(fingers: 4, y: 0.2, time: 0))
        precondition(immediate.update(fingers: 4, y: 0.4, time: 0.1))
        precondition(!immediate.update(fingers: 0, y: 0, time: 0.12))
        immediate.setDirection(.down)
        precondition(!immediate.update(fingers: 4, y: 0.8, time: 0.15))
        precondition(immediate.update(fingers: 4, y: 0.6, time: 0.2))

        let monitor = TrackpadSwipeMonitor()
        var open = false
        var enabled = true
        var fingers = 4
        var openings = 0
        var cancellations = 0
        monitor.isEnabled = { precondition(Thread.isMainThread); return enabled }
        monitor.requiredFingers = { fingers }
        monitor.isExposePresented = { precondition(Thread.isMainThread); return open }
        monitor.onSwipeUp = { open = true; openings += 1 }
        monitor.onSwipeDown = { open = false; cancellations += 1 }
        func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        func frame(_ count: Int, _ y: Float, _ time: Double) {
            monitor.receive(fingers: count, y: y, timestamp: time)
        }

        // Down outside Exposé does nothing.
        frame(4, 0.8, 0); frame(4, 0.5, 0.1); drain()
        precondition(openings == 0 && cancellations == 0)
        frame(0, 0, 0.11)

        frame(4, 0.2, 1); frame(4, 0.4, 1.1); drain()
        precondition(open && openings == 1)
        // Reversing the SAME touch must not cancel the view just opened.
        frame(4, 0.1, 1.12); frame(4, 0.0, 1.14); drain()
        precondition(open && cancellations == 0)
        frame(0, 0, 1.15)

        // A fresh downward gesture cancels promptly, inside the old up
        // cooldown; no window selection or activation callback is involved.
        frame(4, 0.8, 1.2); frame(4, 0.6, 1.3); drain()
        precondition(!open && cancellations == 1)
        frame(0, 0, 1.31)
        frame(4, 0.8, 1.4); frame(4, 0.6, 1.5); drain()
        precondition(!open && openings == 1 && cancellations == 1)
        frame(0, 0, 1.51)

        frame(4, 0.2, 2); frame(4, 0.4, 2.1); drain()
        precondition(open && openings == 2)
        frame(0, 0, 2.11)
        // Up while already exposed is not a toggle/close.
        frame(4, 0.2, 2.2); frame(4, 0.4, 2.3); drain()
        precondition(open && openings == 2 && cancellations == 1)
        frame(0, 0, 2.31)
        frame(3, 0.8, 2.4); frame(3, 0.5, 2.5); drain()
        precondition(open && cancellations == 1)
        frame(0, 0, 2.51)

        enabled = false
        frame(4, 0.8, 3); frame(4, 0.5, 3.1); drain()
        precondition(open && cancellations == 1)
        enabled = true
        frame(0, 0, 3.11)
        frame(4, 0.8, 3.2); frame(4, 0.5, 3.3); drain()
        precondition(!open && cancellations == 2)
        frame(0, 0, 3.31)

        // The same inverse gesture follows the optional three-finger choice.
        fingers = 3
        frame(3, 0.2, 4); frame(3, 0.4, 4.1); drain()
        precondition(open && openings == 3)
        frame(0, 0, 4.11)
        frame(3, 0.8, 4.2); frame(3, 0.5, 4.3); drain()
        precondition(!open && cancellations == 3)

        // Source integration checks only: do not focus/capture real windows.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let controller = try! String(contentsOf: root.appendingPathComponent(
            "src/macos/Services/WindowSwitcher/WindowSwitcherController.swift"), encoding: .utf8)
        let showStart = controller.range(of: "private func showExposePanels(")!.lowerBound
        let endStart = controller.range(of: "private func endExpose(")!.lowerBound
        let show = String(controller[showStart..<endStart])
        precondition(show.range(of: "model.focusedCandidate")!.lowerBound
                     < show.range(of: "NSApp.activate")!.lowerBound)
        let endFinish = controller.range(of: "private func restoreExposeOrigin(")!.lowerBound
        let end = String(controller[endStart..<endFinish])
        precondition(end.contains("id == nil ? exposeOriginApp : nil"))
        precondition(end.contains("id == nil ? exposeOriginWindow : nil"))
        precondition(end.range(of: "self.hide()")!.lowerBound
                     < end.range(of: "self.restoreExposeOrigin(")!.lowerBound)
        precondition(!end.contains("model.selectedID"))
        precondition(controller.contains("guard isExposePresented else { return }"))
        precondition(controller.contains("case 53: endExpose()"))
        precondition(controller.contains("guard let app, !app.isTerminated else { return }"))

        print("Trackpad dismiss checks passed: up opens/down cancels, immediate inverse, same-touch lock, no toggle, no down-open, exact 3/4, disabled state and origin-before-activation/hide-before-restore integration")
    }
}
