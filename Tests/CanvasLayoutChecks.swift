import Foundation

@main
enum CanvasLayoutChecks {
    static func main() {
        let area = CGRect(x: 12, y: 40, width: 1000, height: 700)
        let widths: [CGFloat] = [600, 600, 600, 600]
        assert(CanvasLayout.maximumOffset(widths: [], viewport: 1000) == 0)
        assert(CanvasLayout.maximumOffset(widths: [600], viewport: 1000) == 0)
        assert(CanvasLayout.nearest(widths: [], viewport: 1000, offset: 0) == nil)
        assert(CanvasLayout.reveal(3, widths: widths, viewport: 1000, offset: 0) == 1448)
        assert(CanvasLayout.reveal(0, widths: widths, viewport: 1000, offset: 1448) == 0)
        for count in 1...30 {
            let ws = (0..<count).map { CGFloat(320 + ($0 * 137) % 650) }
            for index in ws.indices {
                let offset = CanvasLayout.reveal(index, widths: ws, viewport: area.width, offset: 800)
                let x = CanvasLayout.origins(widths: ws)[index] - offset
                assert(x >= -0.01 && x + ws[index] <= area.width + 0.01)
                assert(offset >= 0 && offset <= CanvasLayout.maximumOffset(widths: ws, viewport: area.width))
            }
        }
        let parked = CanvasLayout.placements(widths: widths, area: area, offset: 0, otherDisplays: [])
        assert(!parked[0].parked && parked[3].parked)
        assert(parked[3].frame.minX == area.maxX - CanvasLayout.peek)
        // A right-hand display must never receive overflow from this strip.
        let neighbor = CGRect(x: 1024, y: 0, width: 1440, height: 900)
        let safe = CanvasLayout.placements(widths: widths, area: area, offset: 0, otherDisplays: [neighbor])
        assert(safe.allSatisfy { !$0.frame.intersects(neighbor) })
        // Also protect bottom/right seams in a three-screen arrangement.
        let below = CGRect(x: 0, y: 768, width: 1024, height: 768)
        let surrounded = CanvasLayout.placements(widths: widths, area: area, offset: 0, otherDisplays: [neighbor, below])
        assert(surrounded.allSatisfy { !$0.frame.intersects(neighbor) && !$0.frame.intersects(below) })
        let left = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let above = CGRect(x: 0, y: -900, width: 1024, height: 900)
        // Regression: Dev 52 parked windows at maxY - peek. Every window must
        // stay on the exact same baseline, regardless of offset or topology.
        for neighbors in [[], [neighbor], [left], [neighbor, below], [left, neighbor, above, below]] {
            for offset in stride(from: CGFloat(0), through: 1500, by: 37) {
                let placements = CanvasLayout.placements(widths: widths, area: area, offset: offset, otherDisplays: neighbors)
                assert(placements.allSatisfy { $0.frame.minY == area.minY && $0.frame.height == area.height })
                assert(placements.allSatisfy { placement in !neighbors.contains { $0.intersects(placement.frame) } })
            }
            for index in widths.indices {
                let offset = CanvasLayout.reveal(index, widths: widths, viewport: area.width, offset: 0)
                let selected = CanvasLayout.placements(widths: widths, area: area, offset: offset, otherDisplays: neighbors)[index]
                assert(!selected.parked && area.contains(selected.frame))
            }
        }
        // A minimum width larger than the display keeps its leading edge
        // accessible rather than shifting the titlebar off to the left.
        assert(CanvasLayout.reveal(1, widths: [600, 1200], viewport: 1000, offset: 0) == 616)
        print("Canvas geometry: visibility, bounds, empty strips and monitor seams passed")
    }
}
