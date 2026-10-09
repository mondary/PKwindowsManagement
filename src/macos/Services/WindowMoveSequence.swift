import Foundation

/// User intent survives asynchronous desktop transitions. A click (or an
/// explicit app/window command) invalidates both the target and queued moves.
final class WindowMoveSequence<Target> {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var selection: Target?

    func ticket() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    func isCurrent(_ ticket: UInt64) -> Bool { self.ticket() == ticket }

    func target(for ticket: UInt64) -> Target? {
        lock.lock()
        defer { lock.unlock() }
        return generation == ticket ? selection : nil
    }

    @discardableResult
    func retain(_ target: Target, for ticket: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard generation == ticket else { return false }
        selection = target
        return true
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        selection = nil
    }
}
