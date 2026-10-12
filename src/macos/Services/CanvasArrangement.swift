import Foundation

/// Session-local columns identified by window IDs, not by an implicit grid.
/// Pairing survives discovery, closure and unrelated height changes.
struct CanvasArrangement {
    struct Column: Equatable {
        var windows: [UInt32]
        var halfHeight: Bool
    }
    private(set) var columns: [Column] = []

    mutating func synchronize(_ windows: [UInt32]) {
        let live = Set(windows)
        columns = columns.compactMap { column in
            let remaining = column.windows.filter { live.contains($0) }
            return remaining.isEmpty ? nil : Column(windows: remaining, halfHeight: column.halfHeight)
        }
        var known = Set(columns.flatMap(\.windows))
        for id in windows where known.insert(id).inserted {
            columns.append(Column(windows: [id], halfHeight: false))
        }
    }

    func isHalfHeight(_ id: UInt32) -> Bool {
        columns.first(where: { $0.windows.contains(id) })?.halfHeight == true
    }

    mutating func setHalfHeight(_ id: UInt32) {
        guard let source = columns.firstIndex(where: { $0.windows.contains(id) }),
              !columns[source].halfHeight else { return }
        columns.remove(at: source)
        if let target = columns.firstIndex(where: { $0.halfHeight && $0.windows.count == 1 }) {
            // The previously chosen window stays on top, even if this window
            // used to be to its left or several columns away.
            columns[target].windows.append(id)
        } else {
            columns.insert(Column(windows: [id], halfHeight: true), at: source)
        }
    }

    mutating func setFullHeight(_ id: UInt32) {
        guard let source = columns.firstIndex(where: { $0.windows.contains(id) }),
              columns[source].halfHeight else { return }
        let row = columns[source].windows.firstIndex(of: id)!
        columns[source].windows.removeAll { $0 == id }
        if columns[source].windows.isEmpty {
            columns[source] = Column(windows: [id], halfHeight: false)
        } else {
            columns.insert(Column(windows: [id], halfHeight: false), at: source + row)
        }
    }
}
