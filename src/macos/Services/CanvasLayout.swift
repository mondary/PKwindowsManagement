import CoreGraphics
import Foundation

/// Pure strip geometry, shared by keyboard navigation and continuous scrolling.
enum CanvasLayout {
    static let gap: CGFloat = 16
    static let peek: CGFloat = 12

    static func origins(widths: [CGFloat]) -> [CGFloat] {
        var x: CGFloat = 0
        return widths.map { width in
            defer { x += width + gap }
            return x
        }
    }

    static func maximumOffset(widths: [CGFloat], viewport: CGFloat) -> CGFloat {
        max(0, widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * gap - viewport)
    }

    static func clampedOffset(_ offset: CGFloat, widths: [CGFloat], viewport: CGFloat) -> CGFloat {
        min(max(0, offset), maximumOffset(widths: widths, viewport: viewport))
    }

    static func reveal(_ index: Int, widths: [CGFloat], viewport: CGFloat, offset: CGFloat) -> CGFloat {
        guard widths.indices.contains(index) else { return clampedOffset(offset, widths: widths, viewport: viewport) }
        let x = origins(widths: widths)[index]
        var result = offset
        if x < offset { result = x }
        if x + widths[index] > result + viewport { result = x + widths[index] - viewport }
        return clampedOffset(result, widths: widths, viewport: viewport)
    }

    static func nearest(widths: [CGFloat], viewport: CGFloat, offset: CGFloat) -> Int? {
        let xs = origins(widths: widths)
        return widths.indices.min { abs(xs[$0] + widths[$0] / 2 - offset - viewport / 2) < abs(xs[$1] + widths[$1] / 2 - offset - viewport / 2) }
    }

    struct Placement {
        let frame: CGRect
        let parked: Bool
    }

    static func placements(widths: [CGFloat], area: CGRect, offset: CGFloat, otherDisplays: [CGRect]) -> [Placement] {
        let offset = clampedOffset(offset, widths: widths, viewport: area.width)
        return zip(origins(widths: widths), widths).map { origin, width in
            let x = area.minX + origin - offset
            let visible = x + width > area.minX && x < area.maxX
            let boundedX = max(area.minX - width + peek, min(x, area.maxX - peek))
            var frame = CGRect(x: boundedX, y: area.minY, width: width, height: area.height)
            var parked = !visible
            // Native windows cannot be clipped at a monitor seam. Park behind
            // the visible strip instead of leaking onto a neighboring monitor.
            if otherDisplays.contains(where: { $0.intersects(frame) }) {
                frame.origin = CGPoint(x: area.minX, y: area.maxY - peek)
                if otherDisplays.contains(where: { $0.intersects(frame) }) {
                    frame.origin.y = area.minY
                }
                parked = true
            }
            return Placement(frame: frame, parked: parked)
        }
    }
}
