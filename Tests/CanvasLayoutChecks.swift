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

        // Column width kinds: share of the content region, clamped by real
        // minimums, including apps wider than one page.
        let content: CGFloat = 1800
        assert(CanvasLayout.columnWidth(kind: .third, contentWidth: content, minimum: 0) == 600)
        assert(CanvasLayout.columnWidth(kind: .half, contentWidth: content, minimum: 0) == 900)
        assert(CanvasLayout.columnWidth(kind: .twoThirds, contentWidth: content, minimum: 0) == 1200)
        assert(CanvasLayout.columnWidth(kind: .full, contentWidth: content, minimum: 0) == content)
        assert(CanvasLayout.columnWidth(kind: .third, contentWidth: content, minimum: 700) == 700)
        assert(CanvasLayout.columnWidth(kind: .full, contentWidth: content, minimum: 9999) == 9999)
        assert(CanvasLayout.columnWidth(kind: .half, contentWidth: 0, minimum: 320) == 320)
        assert(CanvasLayout.ColumnWidthKind.third.next == .half)
        assert(CanvasLayout.ColumnWidthKind.half.next == .twoThirds)
        assert(CanvasLayout.ColumnWidthKind.twoThirds.next == .full)
        assert(CanvasLayout.ColumnWidthKind.full.next == .third)
        assert(CanvasLayout.ColumnWidthKind.widest(.third, .twoThirds) == .twoThirds)
        assert(CanvasLayout.ColumnWidthKind.widest(.full, .half) == .full)
        // Preference selection and asynchronous persistence acknowledgements.
        var prefs = CanvasLayout.WidthPreferences()
        prefs.reload(["a": "third", "b": "twoThirds", "invalid": "unknown"])
        assert(prefs.kind(for: ["a"]) == .third)
        assert(prefs.kind(for: ["a", "b"]) == .twoThirds)
        assert(prefs.kind(for: ["a", nil]) == .twoThirds) // Unstored apps default to ⅔.
        assert(prefs.kind(for: ["invalid"]) == .twoThirds)
        assert(prefs.kind(for: []) == .twoThirds)
        let olderWrite = prefs.set(.full, for: ["a", "b"])
        prefs.reload(["a": "third", "b": "twoThirds"])
        assert(prefs.kind(for: ["a", "b"]) == .full)
        let latestWrite = prefs.set(.third, for: ["a", "b"])
        prefs.reload(["a": "third", "b": "third"]) // Same value, not yet acknowledged.
        prefs.acknowledge(olderWrite)
        prefs.reload(["a": "full", "b": "full"])
        assert(prefs.kind(for: ["a", "b"]) == .third)
        prefs.acknowledge(latestWrite)
        prefs.reload([:]) // Acknowledged values may be reset/imported later.
        assert(prefs.kind(for: ["a", "b"]) == .twoThirds)

        // Manual resize adoption ignores our own accepted sizes, moves, height
        // changes, live drags, parked windows and unconfirmed AX frames.
        let applied = CGRect(x: 44, y: 24, width: 900, height: 1000)
        func resized(_ width: CGFloat, parked: Bool = false, down: Bool = false,
                     baseline: CGRect? = applied) -> CGFloat? {
            CanvasLayout.manualResizeWidth(
                actual: CGRect(x: -100, y: 30, width: width, height: 500),
                applied: baseline, parked: parked, pointerDown: down, contentWidth: content)
        }
        assert(resized(1200) == 1200)
        assert(resized(600) == 600)
        assert(resized(1800) == 1800)
        assert(resized(2000) == 1800) // Reserved edge lanes stay available.
        assert(resized(900) == nil && resized(902) == nil)
        assert(resized(1200, parked: true) == nil)
        assert(resized(1200, down: true) == nil)
        assert(resized(1200, baseline: nil) == nil)
        assert(resized(.nan) == nil && resized(.infinity) == nil && resized(0) == nil)
        assert(resized(1200, baseline: CGRect(x: 44, y: 24, width: 1200, height: 1000)) == nil)
        assert(CanvasLayout.resolvedColumnWidth(preferred: .full, manualWidths: [600],
            contentWidth: content, minimum: 0) == 600) // Shrink beats app preference.
        assert(CanvasLayout.resolvedColumnWidth(preferred: .half, manualWidths: [600, 1200],
            contentWidth: content, minimum: 0) == 1200) // Paired halves share a width.
        assert(CanvasLayout.resolvedColumnWidth(preferred: .third, manualWidths: [600],
            contentWidth: content, minimum: 750) == 750) // Real app constraints win.
        assert(CanvasLayout.resolvedColumnWidth(preferred: .half, manualWidths: [],
            contentWidth: content, minimum: 0) == 900) // Other windows keep defaults.

        // Repeated grow/shrink operations, odd viewport sizes and negative
        // display origins: later columns reflow, visible columns never overlap.
        for areaWidth: CGFloat in [1024, 1441, 2560] {
            let g = CanvasLayout.Geometry(area: CGRect(x: -2560, y: -900,
                width: areaWidth, height: 800), rows: 2)
            for requested: CGFloat in [333, g.contentWidth * 2 / 3, g.contentWidth, 450] {
                let widths = [g.contentWidth / 3,
                    CanvasLayout.resolvedColumnWidth(preferred: .half, manualWidths: [requested],
                        contentWidth: g.contentWidth, minimum: 320), g.contentWidth / 2]
                let origins = CanvasLayout.canvasOrigins(widths: widths)
                for i in 1..<widths.count {
                    assert(abs(origins[i] - origins[i - 1] - widths[i - 1] - CanvasLayout.gap) < 0.001)
                }
                for selected in widths.indices {
                    let viewport = CanvasLayout.fitViewport(index: selected, widths: widths, geometry: g, current: 9999)
                    let placements = widths.indices.map {
                        CanvasLayout.placement(column: $0, row: 0, widths: widths,
                            geometry: g, viewport: viewport, otherDisplays: [], rows: 2)
                    }
                    assert(placements[selected].parked == nil)
                    let visible = placements.filter { $0.parked == nil }
                    for i in visible.indices {
                        for j in visible.indices where j > i {
                            assert(!visible[i].frame.intersects(visible[j].frame))
                        }
                    }
                    let bottom = CanvasLayout.placement(column: selected, row: 1, widths: widths,
                        geometry: g, viewport: viewport, otherDisplays: [], rows: 2)
                    assert(bottom.frame.width == placements[selected].frame.width)
                    assert(!bottom.frame.intersects(placements[selected].frame))
                }
            }
        }

        // Mixed widths keep origins, parking and viewport maths intact.
        let mixedWidths: [CGFloat] = [
            CanvasLayout.columnWidth(kind: .third, contentWidth: content, minimum: 0),
            CanvasLayout.columnWidth(kind: .full, contentWidth: content, minimum: 0),
            CanvasLayout.columnWidth(kind: .twoThirds, contentWidth: content, minimum: 0)
        ]
        let mixedOrigins = CanvasLayout.canvasOrigins(widths: mixedWidths)
        assert(mixedOrigins[1] == mixedOrigins[0] + mixedWidths[0] + CanvasLayout.gap)
        let wideGeometry = CanvasLayout.Geometry(
            area: CGRect(x: 0, y: 0, width: content + 2 * CanvasLayout.peek, height: 1000), rows: 2)
        let fullViewport = CanvasLayout.fitViewport(index: 1, widths: mixedWidths,
            geometry: wideGeometry, current: 0)
        assert(fullViewport >= mixedOrigins[1] - CanvasLayout.gap)
        assert(fullViewport <= mixedOrigins[1] + CanvasLayout.gap)

        print("Canvas grid: page shape, row baselines, fit visibility, oversized columns, monitor seams and per-app column widths passed")
    }
}
