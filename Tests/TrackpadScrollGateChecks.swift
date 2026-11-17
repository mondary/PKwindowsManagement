import Foundation

@main
enum TrackpadScrollGateChecks {
    static func configured(_ fingers: Int = 4) -> TrackpadScrollGate {
        var gate = TrackpadScrollGate()
        gate.configure(enabled: true, requiredFingers: fingers)
        return gate
    }

    static func main() {
        var two = configured()
        two.updateContacts(fingers: 2, time: 0)
        precondition(!two.shouldSuppress(isContinuous: true, isMomentum: false, time: 0.01))
        two.updateContacts(fingers: 0, time: 0.02)
        precondition(!two.shouldSuppress(isContinuous: true, isMomentum: true, time: 0.03))

        // No travel threshold: the first event is consumed as soon as the
        // configured fingers touch, before Exposé has been recognized.
        var four = configured()
        four.updateContacts(fingers: 4, time: 1)
        precondition(four.shouldSuppress(isContinuous: true, isMomentum: false, time: 1.001))
        precondition(!four.shouldSuppress(isContinuous: false, isMomentum: false, time: 1.002))
        four.updateContacts(fingers: 4, time: 1.03)
        precondition(four.shouldSuppress(isContinuous: true, isMomentum: false, time: 1.04))

        // Lifting fingers one by one remains part of the claimed gesture.
        four.updateContacts(fingers: 3, time: 1.05)
        precondition(four.shouldSuppress(isContinuous: true, isMomentum: false, time: 1.051))
        four.updateContacts(fingers: 2, time: 1.06)
        precondition(four.shouldSuppress(isContinuous: true, isMomentum: false, time: 1.061))
        four.updateContacts(fingers: 0, time: 1.07)
        precondition(four.shouldSuppress(isContinuous: true, isMomentum: false, time: 1.08))
        precondition(four.shouldSuppress(isContinuous: true, isMomentum: true, time: 1.18))
        precondition(four.shouldSuppress(isContinuous: true, isMomentum: true, time: 1.28))

        // Fresh two-finger scrolling immediately cancels the old momentum
        // claim, even if it starts while that inertia would still be active.
        four.updateContacts(fingers: 2, time: 1.29)
        precondition(!four.shouldSuppress(isContinuous: true, isMomentum: false, time: 1.291))
        four.updateContacts(fingers: 0, time: 1.30)
        precondition(!four.shouldSuppress(isContinuous: true, isMomentum: true, time: 1.31))

        // The other count passes. Three-finger PK remains supported, while
        // a native four-finger touch is not stolen on its partial release.
        var three = configured(3)
        three.updateContacts(fingers: 4, time: 2)
        precondition(!three.shouldSuppress(isContinuous: true, isMomentum: false, time: 2.01))
        three.updateContacts(fingers: 3, time: 2.02)
        precondition(!three.shouldSuppress(isContinuous: true, isMomentum: false, time: 2.03))
        three.updateContacts(fingers: 0, time: 2.04)
        three.updateContacts(fingers: 3, time: 2.05)
        precondition(three.shouldSuppress(isContinuous: true, isMomentum: false, time: 2.06))
        three.configure(enabled: false, requiredFingers: 3)
        precondition(!three.shouldSuppress(isContinuous: true, isMomentum: false, time: 2.07))

        var changed = configured()
        changed.updateContacts(fingers: 4, time: 3)
        changed.configure(enabled: true, requiredFingers: 3)
        precondition(!changed.shouldSuppress(isContinuous: true, isMomentum: false, time: 3.01))

        // No stuck page scroll after a missing release frame, stale device,
        // long momentum silence or malformed timestamps.
        var stale = configured()
        stale.updateContacts(fingers: 4, time: 4)
        precondition(!stale.shouldSuppress(isContinuous: true, isMomentum: false, time: 4.3))
        var quiet = configured()
        quiet.updateContacts(fingers: 4, time: 5)
        quiet.updateContacts(fingers: 0, time: 5.01)
        precondition(!quiet.shouldSuppress(isContinuous: true, isMomentum: true, time: 5.3))
        var bounded = configured()
        bounded.updateContacts(fingers: 4, time: 6)
        bounded.updateContacts(fingers: 0, time: 6.01)
        for tick in 1...29 {
            precondition(bounded.shouldSuppress(isContinuous: true, isMomentum: true,
                                               time: 6.01 + Double(tick) * 0.1))
        }
        precondition(!bounded.shouldSuppress(isContinuous: true, isMomentum: true, time: 9.02))
        bounded.updateContacts(fingers: -1, time: .nan)
        precondition(!bounded.shouldSuppress(isContinuous: true, isMomentum: false, time: 9.03))

        // Real monitor integration, but no hardware start or generated input:
        // the callback thread publishes the claim BEFORE the main-loop hop.
        let monitor = TrackpadSwipeMonitor()
        monitor.configureScrollSuppression(enabled: true, requiredFingers: 4)
        let group = DispatchGroup()
        var claimedBeforeMain = false
        var releasedBeforeMain = false
        group.enter()
        DispatchQueue.global().async {
            monitor.receive(fingers: 4, y: 0.2, timestamp: 10)
            claimedBeforeMain = monitor.shouldSuppressScroll(isContinuous: true, isMomentum: false)
            monitor.receive(fingers: 0, y: 0, timestamp: 10.01)
            monitor.receive(fingers: 2, y: 0.3, timestamp: 10.02)
            releasedBeforeMain = !monitor.shouldSuppressScroll(isContinuous: true, isMomentum: false)
            group.leave()
        }
        precondition(group.wait(timeout: .now() + 2) == .success)
        precondition(claimedBeforeMain && releasedBeforeMain)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        precondition(!monitor.shouldSuppressScroll(isContinuous: true, isMomentum: false))
        monitor.stop()
        precondition(!monitor.shouldSuppressScroll(isContinuous: true, isMomentum: true))

        // Source guards for the production event path, without constructing
        // or posting any input event on the user's desktop.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let launch = try! String(contentsOf: root.appendingPathComponent("src/macos/Services/LaunchShortcutMonitor.swift"), encoding: .utf8)
        let handlerStart = launch.range(of: "private func handleScroll(event: CGEvent)")!.lowerBound
        let handlerEnd = launch.range(of: "private func rearmEventTapIfNeeded", range: handlerStart..<launch.endIndex)!.lowerBound
        let handler = String(launch[handlerStart..<handlerEnd])
        let filter = handler.range(of: "if TrackpadSwipeMonitor.shared.shouldSuppressScroll(")!.lowerBound
        precondition(filter < handler.range(of: "if WindowSwitcherController.shared.isVisible")!.lowerBound)
        precondition(filter < handler.range(of: "HorizontalCanvasService.shared.scroll")!.lowerBound)
        precondition(handler.contains(".scrollWheelEventIsContinuous"))
        precondition(handler.contains(".scrollWheelEventMomentumPhase"))
        precondition(handler.contains("axisLock = ScrollAxisLock()"))

        let raw = try! String(contentsOf: root.appendingPathComponent("src/macos/Services/TrackpadSwipeMonitor.swift"), encoding: .utf8)
        let receiveStart = raw.range(of: "func receive(fingers: Int")!.lowerBound
        let receiveEnd = raw.range(of: "private func processContacts", range: receiveStart..<raw.endIndex)!.lowerBound
        let receiver = String(raw[receiveStart..<receiveEnd])
        precondition(receiver.range(of: "scrollGate.updateContacts")!.lowerBound
                     < receiver.range(of: "DispatchQueue.main.async")!.lowerBound)

        print("Trackpad scroll gate checks passed: first event, exact 3/4 count, two-finger scroll, mouse wheel, partial lift, inertia, fresh touch, fail-open timeout, disable, raw-before-main and gate-before-Canvas/overlay integration")
    }
}
