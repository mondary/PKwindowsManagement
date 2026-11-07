import CoreGraphics
import Foundation

/// OmniWM-style minimap for the horizontal Canvas: the whole column strip
/// scaled down into a thin top bar. Pure geometry only — column segments and
/// the visible viewport expressed as fractions of the strip extent, plus the
/// reverse mapping that turns a click on the bar back into a column index.
/// The UI layer never reads worker-owned strips; it renders these snapshots.
enum CanvasMinimap {
    struct Segment: Equatable {
        /// Leading edge of the column, as a fraction of the strip extent.
        let start: CGFloat
        /// Column width, as a fraction of the strip extent.
        let length: CGFloat
        /// 1 = full-height window, 2 = two stacked half-height windows.
        let rows: Int
        /// Window IDs in that column, row order (discovery indices).
        let windowIDs: [CGWindowID]
        /// Owning processes, parallel to windowIDs: the bar resolves app
        /// icons from them on the main thread (NSRunningApplication).
        let pids: [pid_t]

        /// No minimum width expansion: even very dense strips retain disjoint
        /// hit targets and cannot spill over their neighboring app icons.
        func frame(in size: CGSize) -> CGRect {
            let span = max(0, length * size.width)
            let inset = min(1.5, span / 4)
            return CGRect(x: start * size.width + inset, y: 0,
                          width: max(0, span - 2 * inset), height: max(0, size.height))
        }

        init(start: CGFloat, length: CGFloat, rows: Int, windowIDs: [CGWindowID], pids: [pid_t] = []) {
            self.start = start
            self.length = length
            self.rows = rows
            self.windowIDs = windowIDs
            self.pids = pids
        }
    }

    struct Model: Equatable {
        let displayID: CGDirectDisplayID
        let segments: [Segment]
        let selectedWindowID: CGWindowID?
        /// Visible zone of the strip, fractions of the extent (start < end).
        let viewportStart: CGFloat
        let viewportEnd: CGFloat

        /// Column holding the selected window, whatever its row.
        var selectedColumn: Int? {
            guard let id = selectedWindowID else { return nil }
            return segments.firstIndex { $0.windowIDs.contains(id) }
        }
    }

    /// Snapshot of one active strip. `windowIDs` parallels the discovery
    /// order that CanvasLayout.Column window indices refer to.
    static func model(
        displayID: CGDirectDisplayID,
        widths: [CGFloat],
        columns: [CanvasLayout.Column],
        windowIDs: [CGWindowID],
        pids: [pid_t] = [],
        selected: CGWindowID?,
        viewport: CGFloat,
        contentWidth: CGFloat
    ) -> Model? {
        guard !widths.isEmpty, widths.count == columns.count, widths.count > 0 else { return nil }
        let extent = CanvasLayout.stripExtent(widths: widths)
        guard extent > 0 else { return nil }
        let origins = CanvasLayout.canvasOrigins(widths: widths)
        let segments = zip(zip(origins, widths), columns).map { position, column in
            Segment(
                start: position.0 / extent,
                length: position.1 / extent,
                rows: column.rows,
                windowIDs: column.windows.compactMap { windowIDs.indices.contains($0) ? windowIDs[$0] : nil },
                pids: column.windows.compactMap { pids.indices.contains($0) ? pids[$0] : 0 }
            )
        }
        return Model(
            displayID: displayID,
            segments: segments,
            selectedWindowID: selected,
            viewportStart: min(max(0, viewport / extent), 1),
            viewportEnd: min(max(0, (viewport + contentWidth) / extent), 1)
        )
    }

    /// Drop target for a drag at `fraction` of the bar. Same gap rule as
    /// clicks: a point between two segments belongs to the segment before it,
    /// so every drop position answers with a column — dropping a segment onto
    /// itself is a no-op the caller can detect.
    static func reorderTarget(at fraction: CGFloat, segments: [Segment]) -> Int? {
        guard !segments.isEmpty else { return nil }
        let position = min(max(0, fraction), 1)
        var result = 0
        for (index, segment) in segments.enumerated() where position >= segment.start {
            result = index
        }
        return result
    }

    /// Reverse mapping for clicks on the bar. A position in the gap between
    /// two columns or in the trailing margin belongs to the column before it,
    /// so every point of the bar answers with a column.
    static func columnIndex(at fraction: CGFloat, widths: [CGFloat]) -> Int? {
        guard !widths.isEmpty else { return nil }
        let extent = CanvasLayout.stripExtent(widths: widths)
        guard extent > 0 else { return nil }
        let position = min(max(0, fraction), 1) * extent
        let origins = CanvasLayout.canvasOrigins(widths: widths)
        var result = 0
        for (index, origin) in origins.enumerated() where position >= origin {
            result = index
        }
        return result
    }
}
