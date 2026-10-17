import CoreGraphics

/// Reflow after AX refuses a cell: never leave a reserved, unoccupied slot.
/// All callbacks run on the tiling worker; the pure geometry is also testable
/// with simulated application minimum sizes and disappearing windows.
enum BentoTiling {
    enum Scope { case currentDesktop, allDesktops }

    /// A window shared by several Spaces cannot be resized on just one of
    /// them. Unknown membership must never broaden a current-desktop command.
    static func desktop(for membership: [UInt64]?, scope: Scope,
                        current: UInt64?, userDesktops: Set<UInt64>) -> UInt64? {
        guard let membership, membership.count == 1, let desktop = membership.first,
              userDesktops.contains(desktop) else { return nil }
        return scope == .allDesktops || desktop == current ? desktop : nil
    }

    static func arrange(in area: CGRect, count: Int,
                        apply: (Int, CGRect) -> CGRect?,
                        restore: (Int) -> Void,
                        valid: () -> Bool = { true }) -> [Int] {
        var remaining = Array(0..<min(max(0, count), CanvasLayout.maximumBentoWindows))
        var minimums = Array(repeating: CGSize.zero, count: remaining.count)
        var touched = Set<Int>()
        for _ in 0..<(CanvasLayout.maximumBentoWindows * 2) {
            guard valid() else { return [] }
            let frames = CanvasLayout.bentoPlan(in: area, minimumSizes: remaining.map { minimums[$0] })
            if frames.isEmpty {
                guard !remaining.isEmpty else { break }
                // Even a full display cannot fit this window. Keep working
                // with the others instead of abandoning the whole screen.
                remaining.removeFirst()
                continue
            }
            let selected = Array(remaining.prefix(frames.count))
            for index in touched.subtracting(selected).sorted() {
                guard valid() else { return [] }
                restore(index)
                touched.remove(index)
            }
            var retry = false
            for (index, target) in zip(selected, frames) {
                guard valid() else { return [] }
                touched.insert(index)
                guard let actual = apply(index, target) else {
                    remaining.removeAll { $0 == index }
                    retry = true
                    break
                }
                let oversized = actual.width > target.width + 2 || actual.height > target.height + 2
                if oversized {
                    if actual.width > target.width + 2 { minimums[index].width = actual.width }
                    if actual.height > target.height + 2 { minimums[index].height = actual.height }
                    retry = true
                    break
                }
                // A failed move or a fixed maximum size also cannot fill a cell.
                if abs(actual.minX - target.minX) > 2 || abs(actual.minY - target.minY) > 2
                    || abs(actual.width - target.width) > 2 || abs(actual.height - target.height) > 2 {
                    remaining.removeAll { $0 == index }
                    retry = true
                    break
                }
            }
            if !retry { return selected }
        }
        for index in touched.sorted() {
            guard valid() else { return [] }
            restore(index)
        }
        return []
    }
}
