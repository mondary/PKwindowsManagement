import Foundation

/// Axis lock for trackpad scrolls: one gesture serves EITHER the page
/// (vertical) OR the strip (horizontal) — never a drifting mix. The dominant
/// axis is measured on cumulative motion once an engagement threshold is
/// passed; earlier events go to the system, like a scroll view's own delay.
/// Holding Option maps vertical motion to the strip and locks it at once.
struct ScrollAxisLock {
    enum Axis { case page, strip }
    private var axis: Axis?
    private var x: Int = 0
    private var y: Int = 0
    private var lastAt: TimeInterval = -.infinity
    /// Cumulative points before the gesture commits to an axis.
    var engagement: Int = 12
    /// Silence (seconds) that ends a gesture and clears the lock — long enough
    /// to ride out momentum scrolling, short enough to switch intent quickly.
    var gestureTimeout: TimeInterval = 0.35

    /// Axis this event belongs to after the gesture update; nil while the
    /// gesture is still too small to commit (pass such events through).
    mutating func update(xDelta: Int, yDelta: Int, option: Bool, time: TimeInterval) -> Axis? {
        if time - lastAt > gestureTimeout {
            axis = nil
            x = 0
            y = 0
        }
        lastAt = time
        x += abs(xDelta)
        y += abs(yDelta)
        if option {
            axis = .strip
            return axis
        }
        if let locked = axis { return locked }
        if x >= engagement || y >= engagement {
            axis = x > y ? .strip : .page
        }
        return axis
    }
}
