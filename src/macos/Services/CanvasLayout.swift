import CoreGraphics
import Foundation

/// Grid strip geometry, ported from Paneru's model (MIT, see Credits): windows
/// fill a sequence of one/two-row columns; the viewport slides over
/// an endless strip of those columns; columns fully outside the content region
/// park as thin slivers inside reserved edge lanes, because macOS reassigns
/// windows that leave the screen entirely.
enum CanvasLayout {
    static let gap: CGFloat = 8
    static let peek: CGFloat = 44

    struct Geometry {
        let area: CGRect
        let contentMinX: CGFloat
        let contentMaxX: CGFloat
        let contentWidth: CGFloat
        let rows: Int
        let rowHeight: CGFloat

        init(area: CGRect, rows: Int) {
            self.area = area
            self.rows = max(1, rows)
            contentMinX = area.minX + peek
            contentMaxX = area.maxX - peek
            contentWidth = max(1, contentMaxX - contentMinX)
            rowHeight = (area.height - CGFloat(self.rows - 1) * gap) / CGFloat(self.rows)
        }

        func cellY(row: Int) -> CGFloat {
            area.minY + CGFloat(row) * (rowHeight + gap)
        }

        /// Equal width for a full page of `columns` columns.
        func defaultColumnWidth(columns: Int) -> CGFloat {
            let count = CGFloat(max(1, columns))
            return (contentWidth - (count - 1) * gap) / count
        }
    }

    static func canvasOrigins(widths: [CGFloat]) -> [CGFloat] {
        var x: CGFloat = gap
        return widths.map { width in
            defer { x += width + gap }
            return x
        }
    }

    static func stripExtent(widths: [CGFloat]) -> CGFloat {
        guard let width = widths.last else { return 0 }
        let origins = canvasOrigins(widths: widths)
        return origins[origins.count - 1] + width + gap
    }

    static func maxViewport(widths: [CGFloat], viewport: CGFloat) -> CGFloat {
        max(0, stripExtent(widths: widths) - viewport)
    }

    static func clampViewport(_ value: CGFloat, widths: [CGFloat], viewport: CGFloat) -> CGFloat {
        min(max(0, value), maxViewport(widths: widths, viewport: viewport))
    }

    static func columnCount(windows: Int, rows: Int) -> Int {
        max(1, (max(0, windows) + rows - 1) / rows)
    }

    static let maximumBentoWindows = 12
    static let comfortableBentoSize = CGSize(width: 420, height: 280)

    /// Deliberate compositions, not an incomplete rectangular grid. The first
    /// windows get the largest cells. Four stays 2×2; denser layouts mix sizes.
    /// Shared, rounded boundaries ensure adjacent cells meet even on odd sizes.
    static func bentoFrames(in area: CGRect, windows count: Int, transposed: Bool = false) -> [CGRect] {
        guard count > 0, area.width > 0, area.height > 0 else { return [] }
        let patterns = [
            [1], [1, 1], [1, 2], [2, 2], [1, 2, 2], [2, 2, 2],
            [2, 2, 3], [2, 3, 3], [2, 3, 4], [3, 3, 4],
            [2, 3, 3, 3], [2, 3, 3, 4]
        ]
        let rows = patterns[min(count, maximumBentoWindows) - 1]
        let width = transposed ? area.height : area.width
        let height = transposed ? area.width : area.height
        func boundary(_ extent: CGFloat, _ index: Int, _ total: Int) -> CGFloat {
            index == total ? extent : (extent * CGFloat(index) / CGFloat(total)).rounded()
        }
        var frames: [CGRect] = []
        for (column, rowCount) in rows.enumerated() {
            let x = boundary(width, column, rows.count)
            let right = boundary(width, column + 1, rows.count)
            for row in 0..<rowCount {
                let y = boundary(height, row, rowCount)
                let bottom = boundary(height, row + 1, rowCount)
                frames.append(transposed
                    ? CGRect(x: area.minX + y, y: area.minY + x, width: bottom - y, height: right - x)
                    : CGRect(x: area.minX + x, y: area.minY + y, width: right - x, height: bottom - y))
            }
        }
        return frames
    }

    /// Use fewer windows when the screen or an application's minimum size
    /// cannot accommodate the composition. Excess windows stay behind it.
    static func bentoPlan(in area: CGRect, minimumSizes: [CGSize]) -> [CGRect] {
        let limit = min(minimumSizes.count, maximumBentoWindows)
        guard limit > 0, area.width > 0, area.height > 0 else { return [] }
        for count in stride(from: limit, through: 1, by: -1) {
            let upright: [CGRect] = bentoFrames(in: area, windows: count, transposed: false)
            let rotated: [CGRect] = bentoFrames(in: area, windows: count, transposed: true)
            let layouts: [[CGRect]] = [upright, rotated]
            let candidates: [[CGRect]] = layouts.filter { frames in
                fitsBento(frames, minimumSizes: minimumSizes, count: count)
            }
            // Prefer useful landscape cells, including on portrait monitors.
            if let best = candidates.min(by: { bentoScore($0) < bentoScore($1) }) { return best }
        }
        return []
    }

    private static func fitsBento(_ frames: [CGRect], minimumSizes: [CGSize], count: Int) -> Bool {
        for (frame, minimum) in zip(frames, minimumSizes) {
            guard frame.width + 2 >= minimum.width, frame.height + 2 >= minimum.height else { return false }
            guard count == 1
                || (frame.width >= comfortableBentoSize.width && frame.height >= comfortableBentoSize.height)
            else { return false }
        }
        return true
    }

    private static func bentoScore(_ frames: [CGRect]) -> Double {
        frames.reduce(0) { score, frame in
            let deviation = log(Double(frame.width / frame.height) / 1.5)
            return score + deviation * deviation
        }
    }

    struct Column: Equatable {
        var windows: [Int]
        let rows: Int
    }

    /// Auto-tile from each WINDOW's choice, preserving strip order. A lone
    /// half-height window reserves a second cell; the next half can fill it.
    /// Full-height windows are never resized just to fill a neighboring gap.
    static func columns(halfHeight: [Bool]) -> [Column] {
        var result: [Column] = []
        for (index, half) in halfHeight.enumerated() {
            if half, let last = result.last, last.rows == 2, last.windows.count == 1 {
                result[result.count - 1].windows.append(index)
            } else {
                result.append(Column(windows: [index], rows: half ? 2 : 1))
            }
        }
        return result
    }

    static func slot(index: Int, columns: [Column]) -> (column: Int, row: Int)? {
        for (column, cell) in columns.enumerated() {
            if let row = cell.windows.firstIndex(of: index) { return (column, row) }
        }
        return nil
    }

    static func index(column: Int, row: Int, columns: [Column]) -> Int? {
        guard columns.indices.contains(column), !columns[column].windows.isEmpty else { return nil }
        let windows = columns[column].windows
        return windows[min(max(0, row), windows.count - 1)]
    }

    /// 3×2 pages on wide displays (the external screen), 2×2 on smaller ones.
    static func preferredColumns(forAreaWidth width: CGFloat) -> Int {
        width >= 1800 ? 3 : 2
    }

    /// "fit": scroll the minimum needed so the whole column is inside the
    /// content region; an oversized column aligns its leading edge.
    static func fitViewport(index: Int, widths: [CGFloat], geometry: Geometry, current: CGFloat) -> CGFloat {
        guard widths.indices.contains(index) else { return current }
        let x = canvasOrigins(widths: widths)[index]
        let width = widths[index]
        var target = current
        if width >= geometry.contentWidth || x - gap < current {
            target = x - gap
        } else if x + width + gap > current + geometry.contentWidth {
            target = x + width + gap - geometry.contentWidth
        } else {
            return current
        }
        return clampViewport(target, widths: widths, viewport: geometry.contentWidth)
    }

    enum ParkSide {
        case left, right
    }

    struct Placement {
        let frame: CGRect
        let parked: ParkSide?
    }

    /// Where a cell sits for the current viewport. Columns fully outside the
    /// content region park as a sliver in their side's lane; a lane that would
    /// leak onto a neighboring monitor is flipped or kept inside the display.
    static func placement(
        column: Int,
        row: Int,
        widths: [CGFloat],
        geometry: Geometry,
        viewport: CGFloat,
        otherDisplays: [CGRect],
        rows: Int? = nil
    ) -> Placement {
        let origins = canvasOrigins(widths: widths)
        guard widths.indices.contains(column) else {
            return Placement(frame: .null, parked: nil)
        }
        let x = geometry.contentMinX + origins[column] - viewport
        let width = widths[column]
        let columnGeometry = rows.map { Geometry(area: geometry.area, rows: $0) } ?? geometry
        let frame = CGRect(x: x, y: columnGeometry.cellY(row: row), width: width, height: columnGeometry.rowHeight)
        guard x < geometry.contentMaxX, x + width > geometry.contentMinX else {
            let side: ParkSide = x <= geometry.contentMinX ? .left : .right
            var parked = sliverFrame(side: side, width: width, geometry: columnGeometry, row: row)
            if otherDisplays.contains(where: { $0.intersects(parked) }) {
                let flipped = sliverFrame(side: side == .left ? .right : .left, width: width, geometry: columnGeometry, row: row)
                if !otherDisplays.contains(where: { $0.intersects(flipped) }) {
                    parked = flipped
                } else {
                    parked = CGRect(
                        x: side == .left ? geometry.area.minX : geometry.area.maxX - peek,
                        y: columnGeometry.cellY(row: row),
                        width: peek,
                        height: columnGeometry.rowHeight
                    )
                }
            }
            return Placement(frame: parked, parked: side)
        }
        return Placement(frame: frame, parked: nil)
    }

    private static func sliverFrame(side: ParkSide, width: CGFloat, geometry: Geometry, row: Int) -> CGRect {
        let x = side == .left ? geometry.area.minX - width + peek : geometry.area.maxX - peek
        return CGRect(x: x, y: geometry.cellY(row: row), width: width, height: geometry.rowHeight)
    }
}
