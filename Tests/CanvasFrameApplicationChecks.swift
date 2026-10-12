import Foundation
import CoreGraphics

@main
enum CanvasFrameApplicationChecks {
    static func main() {
        let full = CGRect(x: 600, y: 30, width: 500, height: 960)
        let half = CGRect(x: 20, y: 520, width: 500, height: 470)
        var writes: [String] = []
        var pauses: [Double] = []
        var reads = 0
        let delayed = CanvasFrameApplication.apply(half, initial: full, read: {
            reads += 1
            return reads < 3 ? full : half
        }, size: { _ in writes.append("size"); return true }, position: { _ in writes.append("position"); return true }, pause: { pauses.append($0) })
        assert(delayed.actual == half && !delayed.confirmedHeightConstraint)
        assert(writes.prefix(4) == ["size", "position", "size", "position"])
        assert(pauses == [0.05, 0.10, 0.20])
        let unchanged = CanvasFrameApplication.apply(half, initial: full, read: { full }, size: { _ in true }, position: { _ in true }, pause: { _ in })
        assert(!unchanged.confirmedHeightConstraint, "stale full height must not undo the requested pairing")
        let minimum = CGRect(x: half.minX, y: half.minY, width: 500, height: 600)
        let constrained = CanvasFrameApplication.apply(half, initial: full, read: { minimum }, size: { _ in true }, position: { _ in true }, pause: { _ in })
        assert(constrained.confirmedHeightConstraint)
        let rejected = CanvasFrameApplication.apply(half, initial: full, read: { minimum }, size: { _ in false }, position: { _ in true }, pause: { _ in })
        assert(!rejected.confirmedHeightConstraint && !rejected.accepted)
        let unavailable = CanvasFrameApplication.apply(half, initial: full, read: { nil }, size: { _ in true }, position: { _ in true }, pause: { _ in })
        assert(!unavailable.confirmedHeightConstraint)
        var rounded = full
        let quantized = CanvasFrameApplication.apply(half, initial: full, read: { rounded }, size: { requested in
            rounded = CGRect(origin: half.origin, size: CGSize(width: requested.width, height: ceil(requested.height / 16) * 16))
            return true
        }, position: { _ in true }, pause: { _ in })
        assert(!quantized.confirmedHeightConstraint && quantized.actual!.height <= half.height)
        var scrolled = half
        scrolled.origin.x += 50
        var sizeWrites = 0
        _ = CanvasFrameApplication.apply(scrolled, initial: half, read: { scrolled }, size: { _ in sizeWrites += 1; return true }, position: { _ in true }, pause: { _ in fatalError("scroll must not sleep") })
        assert(sizeWrites == 0)
        var valid = true
        var count = 0
        let interrupted = CanvasFrameApplication.apply(half, initial: full, read: { half }, size: { _ in count += 1; return true }, position: { _ in true }, pause: { _ in valid = false }, valid: { valid })
        assert(count == 2 && !interrupted.accepted && !interrupted.confirmedHeightConstraint)
        precondition(CanvasFrameApplication.restored(full, full))
        var grid = full
        grid.size.width -= 2 // character-grid rounding must not orphan the journal
        grid.size.height += 16
        precondition(CanvasFrameApplication.restored(grid, full))
        var moved = full
        moved.origin.x += 40
        precondition(!CanvasFrameApplication.restored(moved, full))
        var shrunk = full
        shrunk.size.height = full.height / 2
        precondition(!CanvasFrameApplication.restored(shrunk, full))
        print("Canvas AX checks passed: bottom-row ordering, delayed resize, stale/rejected reads, minimum, scroll, Space interruption and journal adoption")
    }
}
