import CoreGraphics

/// Computes tidy window frames with even gaps, for any layout kind.
/// The diagram preview and the real screen arrangement both call this, so what
/// the preview shows is what the screen gets.
///
/// Geometry ported and simplified from Rooms by Sara Gordić (MIT) — see
/// vendors/rooms/Sources/RoomsCore/Layout.swift.
enum RoomTiler {
    /// Space between windows and around the edge of the screen.
    static let gap: CGFloat = 16
    /// How much of each stacked window's title bar stays visible.
    static let peek: CGFloat = 32
    /// Below this, a tiled window stops being pleasant to work in.
    static let comfortable = CGSize(width: 480, height: 360)

    /// Frames for `n` windows in `area` (AX coordinates, y down). `.auto`
    /// resolves against the given area, so pass the real screen area for real
    /// layouts and keep previews honest by resolving separately.
    static func frames(count n: Int, kind: RoomLayoutKind, in area: CGRect, gap: CGFloat = gap) -> [CGRect] {
        guard n > 0 else { return [] }
        let a = area.insetBy(dx: gap, dy: gap)
        switch kind {
        case .auto:
            return frames(count: n, kind: autoKind(count: n, in: area, gap: gap), in: area, gap: gap)
        case .focus:
            return focus(n, in: a, gap: gap)
        case .columns:
            return grid(n, columns: min(n, 4), in: a, gap: gap)
        case .grid:
            let columns = max(1, Int(Double(n).squareRoot().rounded(.up)))
            return grid(n, columns: columns, in: a, gap: gap)
        case .stack:
            return stack(n, in: a, gap: gap).map { clamp($0, into: a) }
        }
    }

    /// What Auto means on this screen: tile when every window gets a comfortable
    /// size, otherwise stack.
    static func autoKind(count n: Int, in area: CGRect, gap: CGFloat = gap) -> RoomLayoutKind {
        guard n > 1 else { return .focus }
        let a = area.insetBy(dx: gap, dy: gap)
        let order: [RoomLayoutKind] = n <= 4 ? [.focus, .columns, .grid] : [.grid, .columns, .focus]
        for kind in order {
            let rects = baseFrames(count: n, kind: kind, in: a, gap: gap)
            if rects.allSatisfy({ $0.width >= comfortable.width - 1 && $0.height >= comfortable.height - 1 }) {
                return kind
            }
        }
        return .stack
    }

    private static func baseFrames(count n: Int, kind: RoomLayoutKind, in a: CGRect, gap: CGFloat) -> [CGRect] {
        switch kind {
        case .focus: return focus(n, in: a, gap: gap)
        case .columns: return grid(n, columns: min(n, 4), in: a, gap: gap)
        case .grid:
            let columns = max(1, Int(Double(n).squareRoot().rounded(.up)))
            return grid(n, columns: columns, in: a, gap: gap)
        default: return []
        }
    }

    /// The first window large on the left; the rest share the right side.
    private static func focus(_ n: Int, in a: CGRect, gap: CGFloat) -> [CGRect] {
        guard n > 1 else { return [a] }
        let widths = distribute(a.width, gap: gap, weights: [0.6, 0.4])
        let hero = CGRect(x: a.minX, y: a.minY, width: widths[0], height: a.height)
        let sideArea = CGRect(x: a.minX + widths[0] + gap, y: a.minY, width: widths[1], height: a.height)
        let sideCount = n - 1
        let sideColumns = sideCount > 3 ? 2 : 1
        return [hero] + grid(sideCount, columns: sideColumns, in: sideArea, gap: gap)
    }

    /// Rows of `columns`; a short last row stretches to fill the width.
    private static func grid(_ n: Int, columns: Int, in r: CGRect, gap: CGFloat) -> [CGRect] {
        let columns = max(1, min(columns, n))
        let rows = Int((Double(n) / Double(columns)).rounded(.up))
        let rowItems = (0..<rows).map { row in Array((row * columns)..<min(n, (row + 1) * columns)) }
        let heights = distribute(r.height, gap: gap, weights: Array(repeating: 1, count: rows))
        var out: [CGRect] = []
        var y = r.minY
        for (row, items) in rowItems.enumerated() {
            let widths = distribute(r.width, gap: gap, weights: Array(repeating: 1, count: items.count))
            var x = r.minX
            for w in widths {
                out.append(CGRect(x: x.rounded(), y: y.rounded(), width: w, height: heights[row]))
                x += w + gap
            }
            y += heights[row] + gap
        }
        return out
    }

    /// Hero on the left; side cards offset so their title bars stay visible.
    private static func stack(_ n: Int, in a: CGRect, gap: CGFloat) -> [CGRect] {
        guard n > 1 else { return [a] }
        let widths = distribute(a.width, gap: gap, weights: [0.6, 0.4])
        let hero = CGRect(x: a.minX, y: a.minY, width: widths[0], height: a.height)
        let m = n - 1
        let peek = min(Self.peek, a.height / CGFloat(max(1, m - 1)))
        let height = a.height - peek * CGFloat(m - 1)
        let x = hero.maxX + gap
        return [hero] + (0..<m).map { k in
            CGRect(x: x, y: a.minY + peek * CGFloat(m - 1 - k), width: widths[1], height: height)
        }
    }

    /// Splits `total` (minus gaps) by `weights`. Rounded so the pieces still add
    /// up to the space exactly.
    static func distribute(_ total: CGFloat, gap: CGFloat, weights: [CGFloat]) -> [CGFloat] {
        let n = weights.count
        guard n > 0 else { return [] }
        let available = total - gap * CGFloat(n - 1)
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0, available > 0 else {
            return Array(repeating: max(0, available) / CGFloat(n), count: n)
        }
        let sizes = weights.map { available * $0 / totalWeight }
        var rounded = sizes.map { $0.rounded(.down) }
        var spare = available - rounded.reduce(0, +)
        for i in sizes.indices.sorted(by: { sizes[$0] - rounded[$0] > sizes[$1] - rounded[$1] }) where spare >= 1 {
            rounded[i] += 1
            spare -= 1
        }
        return rounded
    }

    /// Moves a rectangle back inside the area (it keeps its size).
    static func clamp(_ r: CGRect, into a: CGRect) -> CGRect {
        var r = r
        if r.maxX > a.maxX { r.origin.x = max(a.minX, a.maxX - r.width) }
        if r.maxY > a.maxY { r.origin.y = max(a.minY, a.maxY - r.height) }
        r.origin.x = max(a.minX, r.origin.x)
        r.origin.y = max(a.minY, r.origin.y)
        return r
    }
}
