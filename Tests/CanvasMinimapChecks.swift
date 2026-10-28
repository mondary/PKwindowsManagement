import CoreGraphics
import Foundation

@main
enum CanvasMinimapChecks {
    static func main() {
        // Two single-row columns of 300 and 600 px: extent = 8 + 300 + 8 + 600 + 8 = 924.
        let widths: [CGFloat] = [300, 600]
        let columns = [
            CanvasLayout.Column(windows: [0], rows: 1),
            CanvasLayout.Column(windows: [1], rows: 1)
        ]
        let ids: [CGWindowID] = [101, 202]

        // Proportions: starts and lengths are fractions of the strip extent.
        let model = CanvasMinimap.model(
            displayID: 7, widths: widths, columns: columns, windowIDs: ids,
            selected: 202, viewport: 0, contentWidth: 300
        )
        assert(model != nil)
        let minimap = model!
        assert(minimap.segments.count == 2)
        assert(abs(minimap.segments[0].start - 8.0 / 924.0) < 1e-9)
        assert(abs(minimap.segments[1].start - 316.0 / 924.0) < 1e-9)
        assert(abs(minimap.segments[0].length - 300.0 / 924.0) < 1e-9)
        assert(abs(minimap.segments[1].length - 600.0 / 924.0) < 1e-9)
        assert(minimap.segments.allSatisfy { ($0.start + $0.length) <= 1.000001 })

        // Viewport: visible zone starts at the leading edge and is clamped to 1.
        assert(abs(minimap.viewportStart) < 1e-9)
        assert(abs(minimap.viewportEnd - 300.0 / 924.0) < 1e-9)
        let scrolled = CanvasMinimap.model(
            displayID: 7, widths: widths, columns: columns, windowIDs: ids,
            selected: 202, viewport: 924, contentWidth: 300
        )!
        assert(scrolled.viewportStart <= 1 && scrolled.viewportEnd <= 1)
        assert(scrolled.viewportEnd > scrolled.viewportStart || scrolled.viewportEnd == scrolled.viewportStart)

        // Two-row columns carry both window IDs; selection resolves by row member.
        let paired = [
            CanvasLayout.Column(windows: [0], rows: 1),
            CanvasLayout.Column(windows: [1, 2], rows: 2)
        ]
        let pairIDs: [CGWindowID] = [101, 202, 303]
        let bottom = CanvasMinimap.model(
            displayID: 7, widths: [300, 300], columns: paired, windowIDs: pairIDs,
            selected: 303, viewport: 0, contentWidth: 300
        )!
        assert(bottom.segments[1].rows == 2)
        assert(bottom.segments[1].windowIDs == [202, 303])
        assert(bottom.selectedColumn == 1)
        let top = CanvasMinimap.model(
            displayID: 7, widths: [300, 300], columns: paired, windowIDs: pairIDs,
            selected: 101, viewport: 0, contentWidth: 300
        )!
        assert(top.selectedColumn == 0)
        assert(CanvasMinimap.model(
            displayID: 7, widths: [300, 300], columns: paired, windowIDs: pairIDs,
            selected: nil, viewport: 0, contentWidth: 300
        )!.selectedColumn == nil)

        // Click mapping: inside columns, in gaps, and at both bar extremities.
        assert(CanvasMinimap.columnIndex(at: 0, widths: widths) == 0)
        assert(CanvasMinimap.columnIndex(at: 8.0 / 924.0, widths: widths) == 0)
        assert(CanvasMinimap.columnIndex(at: 316.0 / 924.0, widths: widths) == 1)
        assert(CanvasMinimap.columnIndex(at: 0.999, widths: widths) == 1)
        // Gap after the first column: still answers with the leading column.
        assert(CanvasMinimap.columnIndex(at: 311.0 / 924.0, widths: widths) == 0)
        // Out-of-range fractions clamp instead of crashing.
        assert(CanvasMinimap.columnIndex(at: -1, widths: widths) == 0)
        assert(CanvasMinimap.columnIndex(at: 2, widths: widths) == 1)
        assert(CanvasMinimap.columnIndex(at: 0.5, widths: []) == nil)

        // A single column fills the whole bar; empty strips produce no model.
        let single = CanvasMinimap.model(
            displayID: 3, widths: [500], columns: [CanvasLayout.Column(windows: [0], rows: 1)],
            windowIDs: [42], selected: 42, viewport: 0, contentWidth: 500
        )!
        assert(single.segments.count == 1)
        assert(abs(single.segments[0].length - 500.0 / 516.0) < 1e-9)
        assert(single.selectedColumn == 0)
        assert(CanvasMinimap.model(
            displayID: 3, widths: [], columns: [], windowIDs: [], selected: nil,
            viewport: 0, contentWidth: 500
        ) == nil)
        // Column/window mismatch (stale arrangement) is rejected, not rendered.
        assert(CanvasMinimap.model(
            displayID: 3, widths: [500, 500], columns: [CanvasLayout.Column(windows: [0], rows: 1)],
            windowIDs: [42], selected: 42, viewport: 0, contentWidth: 500
        ) == nil)

        print("Canvas minimap checks passed: proportions, viewport clamp, paired columns, click mapping and guards")
    }
}
