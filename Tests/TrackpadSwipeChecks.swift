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

        print("Trackpad swipe checks passed: finger count, direction, single fire, rearm, cooldown, slow/invalid gestures")
    }
}
