import CoreGraphics
import Foundation

@main
enum CanvasLayoutChecks {
    static func main() {
        let area = CGRect(x: 0, y: 0, width: 1800, height: 1000)
        let geometry = CanvasLayout.Geometry(area: area, rows: 2)

        // Page shape: 3×2 on wide displays (the external screen), 2×2 on MacBooks.
        assert(CanvasLayout.preferredColumns(forAreaWidth: 1800) == 3)
        assert(CanvasLayout.preferredColumns(forAreaWidth: 1799) == 2)
        assert(CanvasLayout.columnCount(windows: 0, rows: 2) == 1)
        assert(CanvasLayout.columnCount(windows: 1, rows: 2) == 1)
        assert(CanvasLayout.columnCount(windows: 6, rows: 2) == 3)
        assert(CanvasLayout.columnCount(windows: 7, rows: 2) == 4)
        let heights = [false, true, true, false, true, false, true, true, true, true]
        let mixed = CanvasLayout.columns(halfHeight: heights)
        assert(mixed.map(\.rows) == [1, 2, 1, 2, 1, 2, 2])
        assert(mixed.map(\.windows) == [[0], [1, 2], [3], [4], [5], [6, 7], [8, 9]])
        assert(CanvasLayout.columns(halfHeight: []).isEmpty)
        for index in heights.indices {
            let slot = CanvasLayout.slot(index: index, columns: mixed)!
            assert(CanvasLayout.index(column: slot.column, row: slot.row, columns: mixed) == index)
            let cell = CanvasLayout.placement(column: slot.column, row: slot.row,
                widths: Array(repeating: 300, count: mixed.count), geometry: geometry,
                viewport: 0, otherDisplays: [], rows: mixed[slot.column].rows)
            let expectedHeight = heights[index] ? geometry.rowHeight : area.height
            assert(cell.frame.height == expectedHeight)
        }
        // A full-height window after an unpaired half must not occupy its empty cell.
        assert(CanvasLayout.slot(index: 5, columns: mixed)?.column == 4)
        assert(CanvasLayout.index(column: 3, row: 1, columns: mixed) == 4)
        assert(CanvasLayout.index(column: 1, row: -1, columns: mixed) == 1)
        var changed = [true, true, false]
        assert(CanvasLayout.columns(halfHeight: changed).map(\.windows) == [[0, 1], [2]])
        changed[0] = false
        assert(CanvasLayout.columns(halfHeight: changed).map(\.windows) == [[0], [1], [2]])
        changed[2] = true
        assert(CanvasLayout.columns(halfHeight: changed).map(\.windows) == [[0], [1, 2]])
        // All full/half combinations through ten windows: no window disappears,
        // changes order, shares a full-height cell, or occupies an empty half.
        for count in 0...10 {
            for mask in 0..<(1 << count) {
                let choices = (0..<count).map { mask & (1 << $0) != 0 }
                let columns = CanvasLayout.columns(halfHeight: choices)
                assert(columns.flatMap(\.windows) == Array(0..<count))
                for column in columns {
                    assert(column.windows.count <= column.rows)
                    for index in column.windows {
                        assert(column.rows == (choices[index] ? 2 : 1))
                        let slot = CanvasLayout.slot(index: index, columns: columns)!
                        assert(CanvasLayout.index(column: slot.column, row: slot.row, columns: columns) == index)
                    }
                }
            }
        }

        let width = geometry.defaultColumnWidth(columns: 3)
        let widths = Array(repeating: width, count: 4)
        // A full page spans the content region; the rows span the area.
        assert(abs(3 * width + 2 * CanvasLayout.gap - geometry.contentWidth) < 0.01)
        assert(abs(2 * geometry.rowHeight + CanvasLayout.gap - area.height) < 0.01)

        // Regression (Dev 52 "wave"): every row keeps ONE baseline, visible or
        // parked, whatever the viewport; the selected column becomes fully
        // visible after fit.
        for start in stride(from: CGFloat(0), through: 3000, by: 137) {
            for column in widths.indices {
                let viewport = CanvasLayout.fitViewport(index: column, widths: widths, geometry: geometry, current: start)
                for row in 0..<2 {
                    let placement = CanvasLayout.placement(
                        column: column, row: row, widths: widths,
                        geometry: geometry, viewport: viewport, otherDisplays: []
                    )
                    assert(placement.frame.minY == geometry.cellY(row: row))
                    if placement.parked == nil {
                        assert(placement.frame.minX >= geometry.contentMinX - 0.01)
                        assert(placement.frame.maxX <= geometry.contentMaxX + 0.01)
                        assert(placement.frame.height == geometry.rowHeight)
                    }
                }
            }
        }

        // One row per column: full-height Paneru-classic strip.
        let single = CanvasLayout.Geometry(area: area, rows: 1)
        assert(single.rowHeight == area.height)
        assert(CanvasLayout.columnCount(windows: 3, rows: 1) == 3)
        let singleWidths = Array(repeating: single.defaultColumnWidth(columns: 3), count: 5)
        for column in singleWidths.indices {
            let viewport = CanvasLayout.fitViewport(index: column, widths: singleWidths, geometry: single, current: 999)
            let placement = CanvasLayout.placement(
                column: column, row: 0, widths: singleWidths,
                geometry: single, viewport: viewport, otherDisplays: []
            )
            if placement.parked == nil {
                assert(placement.frame.height == area.height)
                assert(placement.frame.minY == area.minY)
                assert(placement.frame.minX >= single.contentMinX - 0.01)
                assert(placement.frame.maxX <= single.contentMaxX + 0.01)
            }
        }

        // An app-min width larger than the page aligns its leading edge.
        let oversized = [geometry.contentWidth + 300]
        let oversizedViewport = CanvasLayout.fitViewport(index: 0, widths: oversized, geometry: geometry, current: 0)
        let oversizedPlacement = CanvasLayout.placement(
            column: 0, row: 0, widths: oversized,
            geometry: geometry, viewport: oversizedViewport, otherDisplays: []
        )
        assert(oversizedPlacement.parked == nil && oversizedPlacement.frame.minX >= geometry.contentMinX)

        // Parked slivers stay on their own display. With vertical neighbors
        // (the Samsung-above topology) nothing ever leaks at all; horizontal
        // neighbors keep Paneru's documented limitation — a column partially
        // scrolled past the edge bleeds onto the neighbor, exactly like the
        // reference engine.
        let left = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let right = CGRect(x: 1800, y: 0, width: 1440, height: 900)
        let above = CGRect(x: 0, y: -900, width: 1800, height: 900)
        let below = CGRect(x: 0, y: 1000, width: 1800, height: 900)
        func check(
            _ neighbors: [CGRect], viewport: CGFloat, column: Int, row: Int,
            when condition: (CanvasLayout.Placement) -> Bool
        ) {
            let placement = CanvasLayout.placement(
                column: column, row: row, widths: widths,
                geometry: geometry, viewport: viewport, otherDisplays: neighbors
            )
            guard condition(placement) else { return }
            for neighbor in neighbors {
                assert(!placement.frame.intersects(neighbor))
            }
        }
        for viewport in stride(from: CGFloat(0), through: 3000, by: 97) {
            for column in 0..<4 {
                for row in 0..<2 {
                    // Vertical neighbors (the Samsung-above topology): nothing
                    // ever leaks — visible cells stay inside the display.
                    check([above, below], viewport: viewport, column: column, row: row, when: { _ in true })
                    // Horizontal neighbors: only PARKED columns must stay on
                    // their own display; a partially scrolled column bleeds
                    // onto the neighbor, Paneru's documented limitation.
                    check([left], viewport: viewport, column: column, row: row, when: { $0.parked != nil })
                    check([right], viewport: viewport, column: column, row: row, when: { $0.parked != nil })
                    check([left, right, above, below], viewport: viewport, column: column, row: row, when: { $0.parked != nil })
                }
            }
        }

        // The viewport never scrolls past the strip's trailing margin.
        assert(CanvasLayout.maxViewport(widths: [], viewport: geometry.contentWidth) == 0)
        let maximum = CanvasLayout.maxViewport(widths: widths, viewport: geometry.contentWidth)
        assert(CanvasLayout.clampViewport(maximum + 500, widths: widths, viewport: geometry.contentWidth) == maximum)

        print("Canvas grid: page shape, row baselines, fit visibility, oversized columns and monitor seams passed")
    }
}
