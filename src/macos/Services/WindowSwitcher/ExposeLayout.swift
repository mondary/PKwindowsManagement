import Foundation
import CoreGraphics

/// Geometry for visual replicas only. Never writes an AX window frame.
enum ExposeLayout {
    enum Mode: String, CaseIterable { case islands, strip }
    struct ClickSelection {
        private var pressed: WindowSwitcherID?
        mutating func press(_ id: WindowSwitcherID?) -> Bool { pressed = id; return id != nil }
        mutating func release(over id: WindowSwitcherID?) -> WindowSwitcherID? {
            let captured = pressed
            pressed = nil
            return captured != nil && captured == id ? captured : nil
        }
        var hasPress: Bool { pressed != nil }
    }
    struct Group: Identifiable, Equatable {
        let id: String
        let name: String
        var windows: [WindowSwitcherItem]
    }
    struct Display {
        let name: String
        /// Global Quartz coordinates (origin at the primary display's top left).
        let frame: CGRect
    }
    struct Placement: Identifiable, Equatable {
        let item: WindowSwitcherItem
        let frame: CGRect
        let caption: CGRect
        var id: WindowSwitcherID { item.id }
    }
    struct Heading: Identifiable, Equatable {
        let id: String
        let name: String
        let pid: Int32
        let count: Int
        let frame: CGRect
        let bounds: CGRect
    }
    struct Overview: Equatable {
        var windows: [Placement] = []
        var headings: [Heading] = []
        var scale: CGFloat = 1
        var contentWidth: CGFloat = 0
    }

    /// Bundle identity merges instances, never unrelated apps sharing a name.
    static func groups(_ items: [WindowSwitcherItem], identities: [Int32: String]) -> [Group] {
        var groups: [Group] = []
        var indices: [String: Int] = [:]
        var seen = Set<WindowSwitcherID>()
        for item in items where !item.isProcess && seen.insert(item.id).inserted {
            let key = identities[item.id.pid] ?? "pid:\(item.id.pid)"
            if let index = indices[key] { groups[index].windows.append(item) }
            else {
                indices[key] = groups.count
                groups.append(Group(id: key, name: item.appName, windows: [item]))
            }
        }
        return groups
    }

    /// Weighted spatial islands use the entire available rectangle. Each app
    /// chooses its own grid/thumbnail scale instead of one large app shrinking
    /// every other app. The partition has gutters, never overlapping groups.
    static func overview(groups: [Group], in area: CGRect) -> Overview {
        let groups = groups.filter { !$0.windows.isEmpty }
        guard !groups.isEmpty, valid(area) else { return Overview() }
        // Groups whose every window is minimized dock into a bottom band, so
        // a parked app never claims a full weighted region for one thumbnail.
        // Too-small areas keep the historical single-partition layout.
        let dormantIndices = groups.indices.filter { index in
            groups[index].windows.allSatisfy { $0.isMinimized }
        }
        let dockCandidate = min(max(88, area.height * 0.14), 148)
        let dockGap = min(14, area.height * 0.02)
        let useDock = !dormantIndices.isEmpty
            && area.height - dockCandidate - dockGap >= 200
        let dockBand = useDock
            ? CGRect(x: area.minX, y: area.maxY - dockCandidate, width: area.width, height: dockCandidate)
            : CGRect.null
        let activeArea = useDock
            ? CGRect(x: area.minX, y: area.minY, width: area.width,
                     height: area.height - dockCandidate - dockGap)
            : area
        func packCount(_ index: Int) -> Int {
            useDock ? groups[index].windows.filter { !$0.isMinimized }.count
                    : groups[index].windows.count
        }
        let partitionIndices = useDock
            ? groups.indices.filter { !dormantIndices.contains($0) }
            : Array(groups.indices)
        let ordered = partitionIndices.sorted {
            packCount($0) == packCount($1) ? $0 < $1 : packCount($0) > packCount($1)
        }
        let weights = groups.indices.map { sqrt(Double(packCount($0))) }
        var regions: [Int: CGRect] = [:]
        func partition(_ indices: ArraySlice<Int>, _ rect: CGRect) {
            guard indices.count > 1 else {
                if let index = indices.first { regions[index] = rect }
                return
            }
            let sum = indices.reduce(0.0) { $0 + weights[$1] }
            var running = 0.0, best = Double.infinity, split = 1
            for (offset, index) in indices.dropLast().enumerated() {
                running += weights[index]
                if abs(sum / 2 - running) < best { best = abs(sum / 2 - running); split = offset + 1 }
            }
            let left = indices.prefix(split), right = indices.dropFirst(split)
            let fraction = CGFloat(left.reduce(0.0) { $0 + weights[$1] } / sum)
            let horizontal = rect.width >= rect.height
            let extent = horizontal ? rect.width : rect.height
            let gutter = min(18, extent * min(fraction, 1 - fraction) * 0.25)
            if horizontal {
                let first = extent * fraction - gutter / 2
                partition(left, CGRect(x: rect.minX, y: rect.minY, width: first, height: rect.height))
                partition(right, CGRect(x: rect.minX + first + gutter, y: rect.minY,
                                        width: extent - first - gutter, height: rect.height))
            } else {
                let first = extent * fraction - gutter / 2
                partition(left, CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: first))
                partition(right, CGRect(x: rect.minX, y: rect.minY + first + gutter,
                                        width: rect.width, height: extent - first - gutter))
            }
        }
        partition(ordered[...], activeArea)
        var result = Overview(contentWidth: area.width)
        for index in groups.indices {
            guard let region = regions[index] else { continue }
            let group = groups[index]
            let header = min(26, region.height * 0.10)
            let headerGap = min(6, region.height * 0.02)
            let grid = CGRect(x: region.minX, y: region.minY + header + headerGap,
                              width: region.width, height: region.height - header - headerGap)
            let open = group.windows.filter { !$0.isMinimized }
            let minimized = group.windows.filter { $0.isMinimized }
            // Dimmed presentation (islands): minimized windows keep their
            // app group but pack into a small shelf on the card's bottom
            // edge instead of competing with open windows for grid cells.
            // Groups without minimized windows, and regions too small for a
            // readable shelf, keep the historical inline packing unchanged.
            let shelfHeight = minimized.isEmpty ? 0 : min(max(52, grid.height * 0.24), 112)
            let shelfGap = minimized.isEmpty ? 0 : min(8, grid.height * 0.02)
            let hasShelf = !minimized.isEmpty && shelfHeight >= 40 && shelfGap >= 3
            var placements: [Placement]
            if hasShelf, grid.height - shelfHeight - shelfGap >= 96 {
                let main = CGRect(x: grid.minX, y: grid.minY, width: grid.width,
                                  height: grid.height - shelfHeight - shelfGap)
                let shelf = CGRect(x: grid.minX, y: grid.maxY - shelfHeight,
                                   width: grid.width, height: shelfHeight)
                placements = open.isEmpty ? [] : bestPacking(open, in: main)
                placements += packShelf(minimized, in: shelf)
            } else {
                placements = bestPacking(group.windows, in: grid)
            }
            result.headings.append(Heading(id: group.id, name: group.name, pid: group.windows[0].id.pid,
                count: group.windows.count, frame: CGRect(x: region.minX, y: region.minY, width: region.width, height: header), bounds: region))
            result.windows.append(contentsOf: placements)
        }
        // Dock band: each all-minimized group keeps its own enclosure — app
        // name on top, small faded thumbnails side by side below it.
        if !dockBand.isNull {
            let dormant = dormantIndices.map { groups[$0] }
            let count = dormant.count
            let gap = min(12, dockBand.width / CGFloat(count * 14))
            let slotWidth = (dockBand.width - CGFloat(count - 1) * gap) / CGFloat(count)
            let headerHeight = min(20, dockBand.height * 0.22)
            let captionHeight = min(13, dockBand.height * 0.16)
            for (ordinal, group) in dormant.enumerated() {
                let slot = CGRect(x: dockBand.minX + CGFloat(ordinal) * (slotWidth + gap),
                                  y: dockBand.minY, width: slotWidth, height: dockBand.height)
                result.headings.append(Heading(id: group.id, name: group.name,
                    pid: group.windows[0].id.pid, count: group.windows.count,
                    frame: CGRect(x: slot.minX, y: slot.minY, width: slotWidth, height: headerHeight),
                    bounds: slot))
                let thumbs = CGRect(x: slot.minX, y: slot.minY + headerHeight, width: slotWidth,
                                    height: dockBand.height - headerHeight - captionHeight)
                let n = group.windows.count
                let thumbGap = min(6, thumbs.width / CGFloat(max(n, 1) * 10))
                let thumbWidth = (thumbs.width - CGFloat(n - 1) * thumbGap) / CGFloat(n)
                for (position, item) in group.windows.enumerated() {
                    let thumb = CGRect(x: thumbs.minX + CGFloat(position) * (thumbWidth + thumbGap),
                                       y: thumbs.minY, width: thumbWidth, height: thumbs.height)
                    result.windows.append(Placement(item: item, frame: fitted(item, in: thumb),
                        caption: CGRect(x: thumb.minX, y: thumbs.maxY, width: thumbWidth, height: captionHeight)))
                }
            }
        }
        return result
    }

    /// Best column count by total preview area (historical heuristic).
    private static func bestPacking(_ items: [WindowSwitcherItem], in grid: CGRect) -> [Placement] {
        guard !items.isEmpty, valid(grid) else { return [] }
        var best: [Placement] = [], score: CGFloat = -1
        let count = items.count
        let candidates = count <= 3 && grid.width / grid.height >= 1.25 ? [count] : Array(1...count)
        for columns in candidates {
            let candidate = pack(items, columns: columns, in: grid)
            let area = candidate.reduce(CGFloat(0)) { $0 + $1.frame.width * $1.frame.height }
            if area > score { best = candidate; score = area }
        }
        return best
    }

    private static func pack(_ items: [WindowSwitcherItem], columns: Int, in grid: CGRect) -> [Placement] {
        let count = items.count
        let rows = (count + columns - 1) / columns
        let gap = min(10, grid.width / CGFloat(columns * 12), grid.height / CGFloat(rows * 12))
        let cellHeight = (grid.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        let captionHeight = min(20, cellHeight * 0.14)
        let captionGap = min(5, cellHeight * 0.04)
        return items.enumerated().map { ordinal, item in
            let row = ordinal / columns, col = ordinal % columns
            let rowCount = min(columns, count - row * columns)
            let width = (grid.width - CGFloat(rowCount - 1) * gap) / CGFloat(rowCount)
            let slot = CGRect(x: grid.minX + CGFloat(col) * (width + gap),
                y: grid.minY + CGFloat(row) * (cellHeight + gap), width: width,
                height: cellHeight - captionHeight - captionGap)
            return Placement(item: item, frame: fitted(item, in: slot),
                caption: CGRect(x: slot.minX, y: slot.maxY + captionGap, width: width, height: captionHeight))
        }
    }

    /// Small dimmed thumbnails along the group card's bottom edge. Captions
    /// live inside each slot, so frame+caption unions stay disjoint between
    /// neighbouring shelf items and with the main grid above.
    private static func packShelf(_ items: [WindowSwitcherItem], in shelf: CGRect) -> [Placement] {
        let count = items.count
        let gap = min(8, shelf.width / CGFloat(count * 12))
        let captionHeight = min(13, shelf.height * 0.32)
        let slotWidth = (shelf.width - CGFloat(count - 1) * gap) / CGFloat(count)
        return items.enumerated().map { ordinal, item in
            let slot = CGRect(x: shelf.minX + CGFloat(ordinal) * (slotWidth + gap), y: shelf.minY,
                width: slotWidth, height: shelf.height)
            return Placement(item: item, frame: fitted(item, in: slot),
                caption: CGRect(x: slot.minX, y: slot.maxY - captionHeight, width: slotWidth, height: captionHeight))
        }
    }

    /// Full-display Android-style recents: large windows sized by their own
    /// aspect ratio. A portrait window takes a narrower card instead of leaving
    /// huge empty side bands that hid the strip's continuity. Cards tile the
    /// full height; scrolling translates only replicas, never real windows.
    static func strip(groups: [Group], in area: CGRect) -> Overview {
        let groups = groups.filter { !$0.windows.isEmpty }
        guard valid(area), !groups.isEmpty else { return Overview() }
        let header = min(34, area.height * 0.1), caption = min(26, area.height * 0.08)
        let gap = min(8, area.height * 0.025)
        let gutter = min(32, area.width * 0.03)
        func cardWidth(for item: WindowSwitcherItem) -> CGFloat {
            guard let frame = item.frame, valid(frame), frame.width > 0 else { return area.width * 0.82 }
            let aspect = frame.width / frame.height
            if aspect >= 1.05 { return area.width * 0.82 }   // landscape: nearly full card
            if aspect >= 0.8 { return area.width * 0.68 }    // squarish
            return area.width * 0.54                         // portrait/tall column
        }
        let widths = groups.flatMap { $0.windows }.map(cardWidth)
        let total = widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * gutter
        let leading = total <= area.width ? (area.width - total) / 2 : min(24, area.width * 0.02)
        var result = Overview()
        var x = area.minX + leading
        for group in groups {
            for item in group.windows {
                let width = cardWidth(for: item)
                let slot = CGRect(x: x, y: area.minY + header + gap, width: width,
                                  height: area.height - header - caption - 2 * gap)
                result.headings.append(Heading(id: "\(group.id)/\(item.id.pid)/\(item.id.windowID)",
                    name: group.name, pid: item.id.pid, count: group.windows.count,
                    frame: CGRect(x: x, y: area.minY, width: width, height: header),
                    bounds: CGRect(x: x, y: area.minY, width: width, height: area.height)))
                result.windows.append(Placement(item: item, frame: fitted(item, in: slot),
                    caption: CGRect(x: x, y: slot.maxY + gap, width: width, height: caption)))
                x += width + gutter
            }
        }
        result.contentWidth = 2 * leading + total
        return result
    }

    private static func fitted(_ item: WindowSwitcherItem, in slot: CGRect) -> CGRect {
        let size = item.frame.flatMap { valid($0) ? $0.size : nil } ?? CGSize(width: 1600, height: 1000)
        let fit = min(slot.width / size.width, slot.height / size.height)
        return CGRect(x: slot.midX - size.width * fit / 2, y: slot.midY - size.height * fit / 2,
                      width: size.width * fit, height: size.height * fit)
    }

    static func clampedOffset(_ offset: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        guard offset.isFinite else { return 0 }
        return min(max(0, offset), max(0, contentWidth - viewportWidth))
    }

    static func quartzPoint(fromLocal point: CGPoint, on display: CGRect) -> CGPoint {
        CGPoint(x: display.minX + point.x, y: display.minY + display.height - point.y)
    }

    static func hitTest(_ point: CGPoint, in overview: Overview, offset: CGFloat, visibleArea: CGRect) -> WindowSwitcherID? {
        guard visibleArea.contains(point) else { return nil }
        let contentPoint = CGPoint(x: point.x + offset, y: point.y)
        return overview.windows.first { $0.frame.union($0.caption).contains(contentPoint) }?.id
    }

    static func valid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0 && !rect.isNull
    }

    /// CG and SwiftUI both use top-left coordinates. Subtract this display's
    /// Quartz origin; do NOT flip through NSScreen or the union of displays.
    static func local(_ frame: CGRect, on display: CGRect) -> CGRect {
        frame.offsetBy(dx: -display.minX, dy: -display.minY)
    }

    static func sourceFrame(for item: WindowSwitcherItem, on activeDisplay: CGRect) -> CGRect {
        if item.isOnScreen, !item.isHidden, !item.isMinimized, let frame = item.frame, valid(frame) { return frame }
        // Minimized/other-Space windows have no visible desktop origin. Emerge
        // from the bottom rather than inventing a fullscreen source window.
        return CGRect(x: activeDisplay.midX, y: activeDisplay.maxY - 8, width: 1, height: 1)
    }

    static func displayName(for frame: CGRect?, displays: [Display]) -> String? {
        guard let frame, valid(frame) else { return nil }
        var bestArea: CGFloat = 0
        var result: String?
        for display in displays {
            let overlap = frame.intersection(display.frame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea { bestArea = area; result = display.name }
        }
        return result
    }

    static func adjacentGroup(in groups: [Group], selected: WindowSwitcherID?, delta: Int) -> WindowSwitcherID? {
        guard !groups.isEmpty else { return nil }
        let current = groups.firstIndex { $0.windows.contains { $0.id == selected } } ?? 0
        let next = ((current + delta) % groups.count + groups.count) % groups.count
        return groups[next].windows.first?.id
    }
}
