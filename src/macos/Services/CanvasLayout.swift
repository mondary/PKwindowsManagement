import CoreGraphics
import Foundation

/// Grid strip geometry, ported from Paneru's model (MIT, see Credits): windows
/// fill a `columns × rows` grid page; the viewport slides column by column over
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
        otherDisplays: [CGRect]
    ) -> Placement {
        let origins = canvasOrigins(widths: widths)
        guard widths.indices.contains(column) else {
            return Placement(frame: .null, parked: nil)
        }
        let x = geometry.contentMinX + origins[column] - viewport
        let width = widths[column]
        let frame = CGRect(x: x, y: geometry.cellY(row: row), width: width, height: geometry.rowHeight)
        guard x < geometry.contentMaxX, x + width > geometry.contentMinX else {
            let side: ParkSide = x <= geometry.contentMinX ? .left : .right
            var parked = sliverFrame(side: side, width: width, geometry: geometry, row: row)
            if otherDisplays.contains(where: { $0.intersects(parked) }) {
                let flipped = sliverFrame(side: side == .left ? .right : .left, width: width, geometry: geometry, row: row)
                if !otherDisplays.contains(where: { $0.intersects(flipped) }) {
                    parked = flipped
                } else {
                    parked = CGRect(
                        x: side == .left ? geometry.area.minX : geometry.area.maxX - peek,
                        y: geometry.cellY(row: row),
                        width: peek,
                        height: geometry.rowHeight
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
