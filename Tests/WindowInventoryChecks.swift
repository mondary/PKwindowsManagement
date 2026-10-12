import Foundation

@main
enum WindowInventoryChecks {
    static func main() {
        for count in [14, 24, 64] {
            let expected = Set((1...count).map(UInt32.init))
            var reads = 0
            let windows = WindowInventoryReconciliation.collect(expected: expected, read: {
                reads += 1
                // Electron exposes all but two windows initially. Its second
                // response contains only the missing windows plus a duplicate.
                return (1...(count - 2)).map(UInt32.init) + [1]
            }, id: { $0 }, same: { $0 == $1 }, initialize: {
                reads += 1
                return [UInt32(count - 1), UInt32(count), 1]
            })
            precondition(Set(windows) == expected && windows.count == count && reads == 2)
        }
        var refreshes = 0
        let full = WindowInventoryReconciliation.collect(expected: [1, 2], read: { [UInt32(1), 2, 1] },
            id: { $0 }, same: { $0 == $1 }, initialize: { refreshes += 1; return [] })
        precondition(full == [1, 2] && refreshes == 0)
        let failed = WindowInventoryReconciliation.collect(expected: [1, 2, 3], read: { [UInt32(1), 2] },
            id: { $0 }, same: { $0 == $1 }, initialize: { [] })
        precondition(failed == [1, 2], "an unavailable retry must not lose the initial list")
        let empty = WindowInventoryReconciliation.collect(expected: [], read: { [UInt32]() },
            id: { $0 }, same: { $0 == $1 }, initialize: { refreshes += 1; return [] })
        precondition(empty.isEmpty && refreshes == 1)
        print("Window inventory passed: partial 14/24/64-window inventories, duplicates, empty and failed retries")
    }
}
