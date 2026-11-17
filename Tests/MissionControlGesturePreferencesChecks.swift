import Foundation

@main
enum MissionControlGesturePreferencesChecks {
    final class MemoryStore {
        var values: [String: Int] = [:]
        var writes = 0
        var syncs = 0
        var failingSyncs: Set<Int> = []
        var ignoreNextZero = false

        static func address(_ domain: String, _ key: String) -> String { domain + "/" + key }

        func fixture() -> MissionControlGesturePreferences {
            MissionControlGesturePreferences(store: .init(
                read: { [self] domain, key in values[Self.address(domain, key)] },
                write: { [self] domain, key, value in
                    writes += 1
                    if ignoreNextZero && value == 0 { ignoreNextZero = false; return }
                    values[Self.address(domain, key)] = value
                },
                synchronize: { [self] _ in
                    syncs += 1
                    return !failingSyncs.contains(syncs)
                }
            ))
        }
    }

    static func main() throws {
        let domains = MissionControlGesturePreferences.domains
        precondition(domains.count == 2)
        let three = MissionControlGesturePreferences.key(for: 3)
        let four = MissionControlGesturePreferences.key(for: 4)
        let memory = MemoryStore()
        let preferences = memory.fixture()
        precondition(preferences.status(pkFingers: 4) == .unknown)
        precondition(memory.writes == 0 && memory.syncs == 0)

        memory.values[MemoryStore.address(domains[0], four)] = 0
        precondition(preferences.status(pkFingers: 4) == .unknown)
        // Unrecognized modes must not be called safely released or a known
        // Mission Control collision.
        memory.values[MemoryStore.address(domains[1], four)] = 1
        precondition(preferences.status(pkFingers: 4) == .unknown)
        memory.values[MemoryStore.address(domains[1], four)] = 2
        precondition(preferences.status(pkFingers: 4) == .conflict)
        memory.values[MemoryStore.address(domains[1], four)] = 0
        precondition(preferences.status(pkFingers: 4) == .released)
        precondition(memory.writes == 0)

        // Default system state observed in the user's report: BOTH counts
        // are enabled, even though System Settings shows "three fingers".
        for domain in domains {
            memory.values[MemoryStore.address(domain, three)] = 2
            memory.values[MemoryStore.address(domain, four)] = 2
        }
        memory.values["unrelated/horizontalSpaces"] = 17
        precondition(preferences.status(pkFingers: 4) == .conflict)
        try preferences.apply(pkFingers: 4)
        for domain in domains {
            precondition(memory.values[MemoryStore.address(domain, three)] == 2)
            precondition(memory.values[MemoryStore.address(domain, four)] == 0)
        }
        precondition(preferences.status(pkFingers: 4) == .released)
        precondition(memory.writes == 4 && memory.syncs == 2)
        precondition(memory.values["unrelated/horizontalSpaces"] == 17)

        try preferences.apply(pkFingers: 3)
        for domain in domains {
            precondition(memory.values[MemoryStore.address(domain, three)] == 0)
            precondition(memory.values[MemoryStore.address(domain, four)] == 2)
        }
        precondition(preferences.status(pkFingers: 3) == .released)
        precondition(MissionControlGesturePreferences.plan(pkFingers: 99)
            == MissionControlGesturePreferences.plan(pkFingers: 4))

        // A partial flush failure restores every old value, including absence.
        let failed = MemoryStore()
        failed.values[MemoryStore.address(domains[0], three)] = 1
        failed.values["unrelated/setting"] = 42
        let original = failed.values
        failed.failingSyncs = [2]
        do {
            try failed.fixture().apply(pkFingers: 4)
            preconditionFailure("Expected a save failure")
        } catch MissionControlGesturePreferences.SaveError.saveFailed {}
        precondition(failed.values == original)
        precondition(failed.syncs == 4) // Both domains flushed during rollback.

        // A successful flush is insufficient: all values are read back.
        let ignored = MemoryStore()
        ignored.values[MemoryStore.address(domains[0], four)] = 2
        let ignoredOriginal = ignored.values
        ignored.ignoreNextZero = true
        do {
            try ignored.fixture().apply(pkFingers: 4)
            preconditionFailure("Expected readback failure")
        } catch MissionControlGesturePreferences.SaveError.saveFailed {}
        precondition(ignored.values == ignoredOriginal)

        let rollbackFailed = MemoryStore()
        rollbackFailed.failingSyncs = [1, 3]
        do {
            try rollbackFailed.fixture().apply(pkFingers: 4)
            preconditionFailure("Expected rollback failure")
        } catch MissionControlGesturePreferences.SaveError.rollbackFailed {}

        print("Mission Control gesture checks passed: conflict detection, exact 3/4 mapping, both domains, no implicit writes, readback and rollback (no system preferences touched)")
    }
}
