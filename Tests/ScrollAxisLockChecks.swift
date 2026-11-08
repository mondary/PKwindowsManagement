import Foundation

@main
enum ScrollAxisLockChecks {
    static func main() {
        // A pure vertical scroll with stray horizontal noise stays on the page
        // for the whole gesture, momentum included.
        var page = ScrollAxisLock()
        for (i, y) in [8, 14, 22, 30, 18, 9, 4].enumerated() {
            let axis = page.update(xDelta: i % 3 == 0 ? 1 : 0, yDelta: y, option: false, time: Double(i) * 0.016)
            if i < 1 { precondition(axis == nil) } else { precondition(axis == .page) }
        }
        // Momentum events keep the lock (0.2 s gap is still the same gesture).
        precondition(page.update(xDelta: 1, yDelta: 6, option: false, time: 0.3) == .page)

        // A pure horizontal swipe commits to the strip and swallows the stray
        // vertical component.
        var strip = ScrollAxisLock()
        precondition(strip.update(xDelta: 5, yDelta: 0, option: false, time: 0) == nil)
        precondition(strip.update(xDelta: 8, yDelta: 0, option: false, time: 0.016) == .strip)
        precondition(strip.update(xDelta: 3, yDelta: 2, option: false, time: 0.032) == .strip)
        precondition(strip.update(xDelta: 0, yDelta: 4, option: false, time: 0.048) == .strip)

        // Option maps vertical motion to the strip immediately.
        var optionScroll = ScrollAxisLock()
        precondition(optionScroll.update(xDelta: 0, yDelta: 3, option: true, time: 0) == .strip)
        precondition(optionScroll.update(xDelta: 2, yDelta: 8, option: true, time: 0.02) == .strip)

        // A diagonal leans to its dominant axis: y wins here.
        var diagonal = ScrollAxisLock()
        precondition(diagonal.update(xDelta: 7, yDelta: 9, option: false, time: 0) == nil)
        precondition(diagonal.update(xDelta: 6, yDelta: 10, option: false, time: 0.016) == .page)
        // And x wins when horizontal motion dominates.
        var diagonalX = ScrollAxisLock()
        precondition(diagonalX.update(xDelta: 9, yDelta: 4, option: false, time: 0) == nil)
        precondition(diagonalX.update(xDelta: 9, yDelta: 3, option: false, time: 0.016) == .strip)

        // After a silence longer than the gesture timeout the lock clears and
        // the next gesture may choose the other axis.
        var renew = ScrollAxisLock()
        _ = renew.update(xDelta: 0, yDelta: 30, option: false, time: 0)
        precondition(renew.update(xDelta: 0, yDelta: 2, option: false, time: 0.1) == .page)
        precondition(renew.update(xDelta: 14, yDelta: 0, option: false, time: 2.0) == .strip)

        print("Scroll axis lock checks passed: page vs strip engagement, option mapping, momentum hold, silence reset")
    }
}
