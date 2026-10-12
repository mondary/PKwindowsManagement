import Foundation

@main
enum CanvasStateChecks {
    static func main() {
        let ids = (1...10).map(UInt32.init)
        var arrangement = CanvasArrangement()
        arrangement.synchronize(ids)
        assert(arrangement.columns.count == 10)
        assert(arrangement.columns.allSatisfy { !$0.halfHeight })
        arrangement.setHalfHeight(8)
        arrangement.setHalfHeight(2)
        assert(arrangement.columns.contains { $0.windows == [8, 2] && $0.halfHeight })
        arrangement.setHalfHeight(10)
        arrangement.setHalfHeight(4)
        assert(arrangement.columns.contains { $0.windows == [10, 4] })
        arrangement.setFullHeight(8)
        assert(arrangement.columns.contains { $0.windows == [2] && $0.halfHeight })
        assert(arrangement.columns.contains { $0.windows == [10, 4] })
        arrangement.setHalfHeight(7)
        assert(arrangement.columns.contains { $0.windows == [2, 7] })
        arrangement.setFullHeight(7)
        assert(arrangement.columns.contains { $0.windows == [7] && !$0.halfHeight })
        // Discovery order cannot destroy user-chosen pairs; closed windows leave
        // a half-height cell available, newly discovered windows start full.
        arrangement.synchronize(Array(ids.reversed()) + [11])
        assert(arrangement.columns.contains { $0.windows == [10, 4] })
        arrangement.synchronize(ids.filter { $0 != 10 } + [11])
        assert(arrangement.columns.contains { $0.windows == [4] && $0.halfHeight })
        assert(!arrangement.isHalfHeight(11))
        // Each choice order (including right-to-left) pairs the second BELOW
        // the first, independently of the discovery/spatial order.
        for first in ids {
            for second in ids where second != first {
                var sample = CanvasArrangement()
                sample.synchronize(ids)
                sample.setHalfHeight(first)
                sample.setHalfHeight(second)
                assert(sample.columns.contains { $0.windows == [first, second] })
                assert(Set(sample.columns.flatMap(\.windows)) == Set(ids))
                assert(sample.columns.flatMap(\.windows).count == 10)
                sample.setFullHeight(second)
                assert(sample.columns.count == 10)
                sample.setHalfHeight(second)
                assert(sample.columns.contains { $0.windows == [first, second] })
            }
        }
        let a = CanvasWorkspace(displayID: 1, spaceID: 101)
        for count in [14, 24, 64] {
            let many = (1...count).map(UInt32.init)
            var sample = CanvasArrangement()
            sample.synchronize(many)
            precondition(sample.columns.count == count)
            for id in many { sample.setHalfHeight(id) }
            precondition(sample.columns.count == count / 2)
            precondition(Set(sample.columns.flatMap(\.windows)) == Set(many))
            for id in many { sample.setFullHeight(id) }
            precondition(sample.columns.count == count)
            precondition(Set(sample.columns.flatMap(\.windows)) == Set(many))
        }
        let b = CanvasWorkspace(displayID: 1, spaceID: 102)
        let c = CanvasWorkspace(displayID: 2, spaceID: 101)
        assert(Set([a, b, c]).count == 3)
        for _ in 0..<20 {
            assert(CanvasWorkspacePolicy.state(ownedSpace: 101, currentSpace: 102, displayConnected: true) == .suspended)
            assert(CanvasWorkspacePolicy.state(ownedSpace: 101, currentSpace: nil, displayConnected: true) == .suspended)
            assert(CanvasWorkspacePolicy.state(ownedSpace: 101, currentSpace: 101, displayConnected: true) == .active)
        }
        assert(CanvasWorkspacePolicy.state(ownedSpace: 101, currentSpace: nil, displayConnected: false) == .disconnected)
        // Deactivation must not lose half-height cuts: the arrangement is kept
        // aside and reapplied to the rediscovered windows.
        var kept = CanvasArrangement()
        kept.synchronize(ids)
        kept.setHalfHeight(3)
        kept.setHalfHeight(9)
        var revived = CanvasArrangement()
        revived = kept
        revived.synchronize(ids)
        precondition(revived.columns.contains { $0.windows == [3, 9] && $0.halfHeight })
        print("Canvas state checks passed: 90 pairing orders, 14/24/64 windows, cuts kept across toggle, membership, splits and desktop lifecycle")
    }
}
