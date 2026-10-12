import Foundation

/// Merge multiple AX lists without losing already-discovered windows when a
/// later read is partial. WindowServer IDs reveal incomplete Electron lists.
enum WindowInventoryReconciliation {
    static func collect<Element>(expected: Set<UInt32>, read: () -> [Element],
                                 id: (Element) -> UInt32?, same: (Element, Element) -> Bool,
                                 initialize: () -> [Element]) -> [Element] {
        var result: [Element] = []
        var knownIDs: Set<UInt32> = []
        func merge(_ elements: [Element]) {
            for element in elements {
                if let windowID = id(element), !knownIDs.insert(windowID).inserted { continue }
                if result.contains(where: { same($0, element) }) { continue }
                result.append(element)
            }
        }
        merge(read())
        if result.isEmpty || !expected.isSubset(of: knownIDs) {
            merge(initialize())
        }
        return result
    }
}
