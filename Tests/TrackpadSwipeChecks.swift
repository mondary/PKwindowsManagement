import Foundation

@main
struct TrackpadSwipeChecks {
    static func main() {
        var detector = TrackpadSwipeDetector()
        detector.cooldown = 0.6
        detector.minimumTravel = 0.10

        // Two fingers never open Exposé.
        precondition(!detector.update(fingers: 2, y: 0.2, time: 0))
        precondition(!detector.update(fingers: 2, y: 0.8, time: 0.1))

        // A four-finger upward swipe fires exactly once (default setting).
        precondition(!detector.update(fingers: 4, y: 0.20, time: 1.0))
        precondition(!detector.update(fingers: 4, y: 0.25, time: 1.05))
        precondition(detector.update(fingers: 4, y: 0.35, time: 1.10))
        // Still touching: no repeat.
        precondition(!detector.update(fingers: 4, y: 0.60, time: 1.15))
        // Release rearms.
        precondition(!detector.update(fingers: 0, y: 0, time: 1.20))
        // Cooldown blocks an immediate second swipe.
        precondition(!detector.update(fingers: 4, y: 0.20, time: 1.30))
        precondition(!detector.update(fingers: 4, y: 0.45, time: 1.40))
        // After the cooldown a fresh swipe works again.
        precondition(!detector.update(fingers: 0, y: 0, time: 1.95))
        precondition(!detector.update(fingers: 4, y: 0.20, time: 2.0))
        precondition(detector.update(fingers: 4, y: 0.40, time: 2.1))

        // Downward movement never triggers.
        var down = TrackpadSwipeDetector()
        precondition(!down.update(fingers: 4, y: 0.80, time: 0))
        precondition(!down.update(fingers: 4, y: 0.60, time: 0.1))
        precondition(!down.update(fingers: 4, y: 0.30, time: 0.2))

        // A slow gesture times out instead of firing.
        var slow = TrackpadSwipeDetector()
        precondition(!slow.update(fingers: 4, y: 0.10, time: 0))
        precondition(!slow.update(fingers: 4, y: 0.15, time: 0.5))
        // Past the maximum duration: the gesture is abandoned, not fired.
        precondition(!slow.update(fingers: 4, y: 0.60, time: 1.0))
        precondition(!slow.update(fingers: 4, y: 0.90, time: 1.1))

        // Impossible coordinates (struct layout mismatch) are ignored.
        var invalid = TrackpadSwipeDetector()
        precondition(!invalid.update(fingers: 4, y: 42, time: 0))
        precondition(!invalid.update(fingers: 4, y: -3, time: 0.1))
        precondition(!invalid.update(fingers: 4, y: .nan, time: 0.2))

        // The finger count is an EXACT match: with the 3-finger setting a
        // 4-finger swipe stays with the system, and the other way around.
        var three = TrackpadSwipeDetector()
        three.requiredFingers = 3
        precondition(!three.update(fingers: 4, y: 0.2, time: 0))
        precondition(!three.update(fingers: 4, y: 0.5, time: 0.1))
        precondition(!three.update(fingers: 3, y: 0.2, time: 0.3))
        precondition(three.update(fingers: 3, y: 0.4, time: 0.4))
        var four = TrackpadSwipeDetector()
        four.requiredFingers = 4
        precondition(!four.update(fingers: 3, y: 0.2, time: 0))
        precondition(!four.update(fingers: 3, y: 0.9, time: 0.3))
        precondition(!four.update(fingers: 4, y: 0.2, time: 0.5))
        precondition(four.update(fingers: 4, y: 0.4, time: 0.6))
        // Default is the documented four-finger behaviour.
        precondition(TrackpadSwipeDetector().requiredFingers == 4)

        // Read the native CFArray as raw device references, without trying
        // to bridge its entries into Swift pointer objects. No real device
        // is started by these checks.
        let deviceA = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        let deviceB = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        defer { deviceA.deallocate(); deviceB.deallocate() }
        var references: [UnsafeRawPointer?] = [UnsafeRawPointer(deviceA), UnsafeRawPointer(deviceB)]
        let list = references.withUnsafeMutableBufferPointer {
            CFArrayCreate(kCFAllocatorDefault, $0.baseAddress, $0.count, nil)!
        }
        precondition(TrackpadSwipeMonitor.devicePointers(in: list) == [deviceA, deviceB])
        // Recovery decisions for cold launch, reconnect, wake and stopped
        // devices; an idle but healthy trackpad must keep its registration.
        func plan(_ old: [Int], _ new: [Int], wake: Bool = false, stopped: Set<Int> = []) -> ([Int], [Int]) {
            TrackpadSwipeMonitor.deviceChanges(old: old, current: new, afterWake: wake, running: { !stopped.contains($0) })
        }
        precondition(plan([], [1]) == ([], [1]))
        precondition(plan([1], [1]) == ([], []))
        precondition(plan([1], []) == ([1], []))
        precondition(plan([1,2], [2,3]) == ([1], [3]))
        precondition(plan([1,2], [1,2], stopped: [2]) == ([2], [2]))
        precondition(plan([1], [1], wake: true) == ([1], [1]))
        let empty = CFArrayCreate(kCFAllocatorDefault, nil, 0, nil)!
        precondition(TrackpadSwipeMonitor.devicePointers(in: empty).isEmpty)

        let contacts = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<TrackpadSwipeMonitor.Contact>.size,
            alignment: MemoryLayout<TrackpadSwipeMonitor.Contact>.alignment
        )
        defer { contacts.deallocate() }
        contacts.storeBytes(of: Float(0.42),
                            toByteOffset: TrackpadSwipeMonitor.contactPositionYOffset, as: Float.self)
        precondition(abs(TrackpadSwipeMonitor.contactY(from: contacts, count: 4) - 0.42) < 0.001)
        precondition(TrackpadSwipeMonitor.contactY(from: nil, count: 0) == 0)
        precondition(TrackpadSwipeMonitor.contactY(from: contacts, count: 0) == 0)

        // A zero-contact callback must rearm the next identical gesture.
        var repeated = TrackpadSwipeDetector()
        for gesture in 0..<20 {
            let time = Double(gesture)
            precondition(!repeated.update(fingers: 4, y: 0.2, time: time))
            precondition(repeated.update(fingers: 4, y: 0.4, time: time + 0.1))
            precondition(!repeated.update(
                fingers: 0, y: TrackpadSwipeMonitor.contactY(from: nil, count: 0), time: time + 0.2
            ))
        }

        // Run the real callback-processing path without starting hardware,
        // opening windows or accessing any user's preferences.
        let monitor = TrackpadSwipeMonitor()
        var enabled = true
        var selectedFingers = 4
        var fired = 0
        monitor.isEnabled = { precondition(Thread.isMainThread); return enabled }
        monitor.requiredFingers = { precondition(Thread.isMainThread); return selectedFingers }
        monitor.onSwipeUp = { precondition(Thread.isMainThread); fired += 1 }
        func drain() {
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        monitor.receive(fingers: 4, y: 0.2, timestamp: 0)
        monitor.receive(fingers: 4, y: 0.4, timestamp: 0.1)
        drain()
        precondition(fired == 1)
        monitor.receive(fingers: 0, y: 0, timestamp: 0.2)
        monitor.receive(fingers: 4, y: 0.2, timestamp: 1)
        monitor.receive(fingers: 4, y: 0.4, timestamp: 1.1)
        drain()
        precondition(fired == 2)

        // Changing the selected count rearms, rather than inheriting an
        // already-fired four-finger session.
        selectedFingers = 3
        monitor.receive(fingers: 3, y: 0.2, timestamp: 2)
        monitor.receive(fingers: 3, y: 0.4, timestamp: 2.1)
        drain()
        precondition(fired == 3)
        enabled = false
        monitor.receive(fingers: 3, y: 0.2, timestamp: 3)
        monitor.receive(fingers: 3, y: 0.4, timestamp: 3.1)
        drain()
        precondition(fired == 3)
        enabled = true

        // Framework callbacks hop to main before reading observable settings.
        DispatchQueue.global().async {
            monitor.receive(fingers: 3, y: 0.2, timestamp: 4)
            monitor.receive(fingers: 3, y: 0.4, timestamp: 4.1)
        }
        let deadline = Date().addingTimeInterval(2)
        while fired < 4 && Date() < deadline { drain() }
        precondition(fired == 4)

        print("Trackpad swipe checks passed: exact count, repeated gestures, CFArray devices, empty frames, selection/toggle and off-main callback")
    }
}
