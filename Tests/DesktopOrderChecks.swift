import Foundation

@main
enum DesktopOrderChecks {
    static func main() {
        assert(DesktopOrder.moving([10, 20, 30], from: 1, to: 2) == [10, 30, 20])
        assert(DesktopOrder.moving([10, 30, 20], from: 2, to: 1) == [10, 20, 30])
        assert(DesktopOrder.moving([10, 20], from: 0, to: -1) == nil)
        assert(DesktopOrder.moving([10, 20], from: 1, to: 2) == nil)
        assert(DesktopOrder.moving([10, 10], from: 0, to: 1) == nil)
        for count in 1...16 {
            let ids = (1...count).map { UInt64($0) }
            for source in ids.indices {
                for destination in ids.indices {
                    let result = DesktopOrder.moving(ids, from: source, to: destination)!
                    assert(result[destination] == ids[source])
                    assert(result.filter { $0 != ids[source] } == ids.filter { $0 != ids[source] })
                    assert(DesktopOrder.moving(result, from: destination, to: source) == ids)
                }
            }
        }
        print("Desktop order: insertion, identity, boundaries and round trips passed")
    }
}
