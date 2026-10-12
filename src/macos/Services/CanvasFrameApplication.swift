import CoreGraphics

/// AX setters can return before an app has applied its new size. Keep that
/// transient state separate from a demonstrated minimum size.
enum CanvasFrameApplication {
    struct Result {
        let actual: CGRect?
        let accepted: Bool
        let confirmedHeightConstraint: Bool
        let confirmedWidthConstraint: Bool
    }

    static func sameSize(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) < 3 && abs(lhs.height - rhs.height) < 3
    }

    /// Terminal-style character grids may round down by one cell. A slightly
    /// smaller window fits; a larger one would overlap its neighbour.
    static func fitsSize(_ actual: CGSize, _ target: CGSize) -> Bool {
        actual.width <= target.width + 2 && actual.height <= target.height + 2
            && actual.width >= target.width - 32 && actual.height >= target.height - 32
    }

    static func apply(_ target: CGRect, initial: CGRect?,
                      read: () -> CGRect?, size: (CGSize) -> Bool,
                      position: (CGPoint) -> Bool, pause: (Double) -> Void,
                      valid: () -> Bool = { true }) -> Result {
        let resizing = initial.map { !fitsSize($0.size, target.size) } ?? true
        var requested = target.size
        var adjustedRounding = false
        var accepted = true
        var actual: CGRect?
        var previous: CGRect?
        var stableOversize = 0
        // Resize BEFORE moving a full-height window to the bottom row. Repeat
        // after moving for apps that constrain sizes on the old display.
        for attempt in 0...(resizing ? 3 : 0) {
            guard valid() else { return Result(actual: nil, accepted: false, confirmedHeightConstraint: false, confirmedWidthConstraint: false) }
            if resizing { accepted = size(requested) }
            accepted = position(target.origin) && accepted
            if resizing {
                accepted = size(requested) && accepted
                accepted = position(target.origin) && accepted
                pause([0.05, 0.10, 0.20, 0.30][attempt])
            }
            guard valid() else { return Result(actual: nil, accepted: false, confirmedHeightConstraint: false, confirmedWidthConstraint: false) }
            actual = read()
            if let actual, fitsSize(actual.size, target.size) { break }
            if !adjustedRounding, let actual {
                let w = actual.width - target.width, h = actual.height - target.height
                if w > 2 && w <= 24 { requested.width = max(1, target.width - w - 1); adjustedRounding = true }
                if h > 2 && h <= 24 { requested.height = max(1, target.height - h - 1); adjustedRounding = true }
            }
            if accepted, let actual, let previous, sameSize(actual.size, previous.size) {
                stableOversize += 1
            } else { stableOversize = 0 }
            previous = actual
        }
        // An unchanged original frame proves neither a minimum nor a successful
        // write. In particular, a delayed AX resize must never undo Ctrl+Shift+S.
        let stable = accepted && stableOversize >= 2
        let heightChanged = initial.map { abs((actual?.height ?? $0.height) - $0.height) >= 3 } ?? false
        let widthChanged = initial.map { abs((actual?.width ?? $0.width) - $0.width) >= 3 } ?? false
        return Result(actual: actual, accepted: accepted,
            confirmedHeightConstraint: stable && heightChanged && (actual?.height ?? 0) > target.height + 3,
            confirmedWidthConstraint: stable && widthChanged && (actual?.width ?? 0) > target.width + 3)
    }
}
