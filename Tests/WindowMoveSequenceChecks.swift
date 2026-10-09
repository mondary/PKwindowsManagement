import Foundation

@main
enum WindowMoveSequenceChecks {
    static func main() {
        let sequence = WindowMoveSequence<Int>()
        let first = sequence.ticket()
        let queuedRight = sequence.ticket()
        let queuedLeft = sequence.ticket()
        assert(sequence.retain(101, for: first))
        // Dock may report window 202 after arrival; consecutive moves must
        // continue to use 101, including after focus restoration failed.
        for ticket in [queuedRight, queuedLeft, sequence.ticket()] {
            assert(sequence.isCurrent(ticket))
            assert(sequence.target(for: ticket) == 101)
        }
        // A click during the transition cancels pending work, including work
        // waiting for Canvas release. The old task cannot re-pin its target.
        sequence.reset()
        assert(!sequence.isCurrent(queuedRight))
        assert(sequence.target(for: first) == nil)
        assert(!sequence.retain(101, for: first))
        let afterClick = sequence.ticket()
        assert(sequence.target(for: afterClick) == nil)
        assert(sequence.retain(202, for: afterClick))
        assert(sequence.target(for: afterClick) == 202)
        // Stress concurrent invalidations: no lost generations or stale writes.
        DispatchQueue.concurrentPerform(iterations: 1000) { _ in sequence.reset() }
        assert(sequence.ticket() == afterClick + 1000)
        assert(!sequence.retain(202, for: afterClick))
        print("Window move sequence: rapid moves, focus loss, click cancellation and concurrent invalidation passed")
    }
}
